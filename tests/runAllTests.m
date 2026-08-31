function results = runAllTests()
%RUNALLTESTS Execute deterministic, leakage, metric, and fallback tests.
%   RESULTS = RUNALLTESTS() raises an assertion error on failure and returns
%   a table-like structure describing passed checks.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));
cfg = localSmallConfig(defaultConfig());
testNames = {};
passed = [];

fprintf('TrafoDNA tests are running...\n');

% 1. Deterministic signal generation.
core1 = createVirtualCore(1,cfg);
condition = cfg.dataset.conditions(1);
excitation = generateExcitation(condition,cfg);
simulationA = simulateBarkhausen(core1,condition,excitation,cfg,123456);
simulationB = simulateBarkhausen(core1,condition,excitation,cfg,123456);
assert(isequal(simulationA.signalV,simulationB.signalV), ...
    'The same seed did not reproduce the same signal.');
[testNames,passed] = localRecord(testNames,passed,'seed_reproducibility');

% 2. Different virtual cores must have different fixed parameters.
core2 = createVirtualCore(2,cfg);
parameterDifference = abs(core1.coercivityAm-core2.coercivityAm) + ...
    norm(core1.fingerprintCoefficients-core2.fingerprintCoefficients);
assert(parameterDifference > 1e-9,'Different cores received identical parameters.');
[testNames,passed] = localRecord(testNames,passed,'different_core_parameters');

% 3. Signal and feature finiteness/dimensions.
assert(all(isfinite(simulationA.signalV)),'Signal contains NaN or Inf.');
[featureRow,featureNames] = extractFeatures(simulationA.signalV,excitation,cfg);
assert(isrow(featureRow) && numel(featureRow) == numel(featureNames), ...
    'Feature names and values have inconsistent dimensions.');
assert(all(isfinite(featureRow)),'Feature vector contains NaN or Inf.');
[testNames,passed] = localRecord(testNames,passed,'finite_signal_and_features');

% 4. Miniature streamed dataset and partition leakage.
cores = repmat(core1,cfg.dataset.numCores,1);
for k = 1:cfg.dataset.numCores
    cores(k) = createVirtualCore(k,cfg);
end
dataset = generateDataset(cores,cfg);
splits = splitDataset(dataset.metadata,cfg);
membership = double(splits.train)+double(splits.validation)+ ...
    double(splits.test)+double(splits.unseen)+double(splits.finalHoldout);
assert(all(membership <= 1),'Dataset leakage was detected.');
assert(isempty(intersect(dataset.metadata.SampleId(splits.train), ...
    dataset.metadata.SampleId(splits.test))),'Train/test sample overlap detected.');
assert(any(splits.finalHoldout),'Final-holdout partition is empty.');
[testNames,passed] = localRecord(testNames,passed,'partition_leakage');

% 5. Toolbox-free identity path and verification metrics.
identityModel = trainIdentityModel(dataset.features(splits.train,:), ...
    dataset.metadata.CoreId(splits.train),dataset.metadata(splits.train,:),cfg);
assert(~identityModel.svmAvailable,'Fallback test unexpectedly trained an SVM.');
[prediction,confidence,distances] = predictIdentity(identityModel, ...
    dataset.features(splits.test,:),dataset.metadata(splits.test,:));
metrics = computeVerificationMetrics(prediction,dataset.metadata.CoreId(splits.test), ...
    confidence,distances,identityModel.coreIds);
assert(all(metrics.far >= 0 & metrics.far <= 1),'FAR is outside [0,1].');
assert(all(metrics.frr >= 0 & metrics.frr <= 1),'FRR is outside [0,1].');
assert(median(metrics.genuineDistances) < median(metrics.impostorDistances), ...
    'Median intra-core distance is not below median inter-core distance.');
[testNames,passed] = localRecord(testNames,passed,'identity_fallback_and_distances');

% 6. EER on cleanly separated synthetic verification scores.
eerResult = computeEER([0.05;0.10;0.15;0.20],[0.70;0.80;0.90;1.00]);
assert(eerResult.eer <= 0.05,'EER calculation failed on separated scores.');
[testNames,passed] = localRecord(testNames,passed,'eer_synthetic_scores');

% 7. PUF path and bounded metrics.
pufModel = generateBinaryFingerprint(dataset.features(splits.train,:), ...
    dataset.metadata.CoreId(splits.train),cfg,identityModel, ...
    dataset.metadata(splits.train,:),dataset.features(splits.validation,:), ...
    dataset.metadata.CoreId(splits.validation), ...
    dataset.metadata(splits.validation,:));
pufMetrics = evaluatePUF(pufModel,dataset.features(splits.test,:), ...
    dataset.metadata.CoreId(splits.test),dataset.metadata(splits.test,:));
assert(pufMetrics.reliability >= 0 && pufMetrics.reliability <= 1, ...
    'PUF reliability is outside [0,1].');
assert(pufMetrics.uniqueness >= 0 && pufMetrics.uniqueness <= 1, ...
    'PUF uniqueness is outside [0,1].');
assert(pufMetrics.numSelectedBits >= cfg.puf.minimumSelectedBits, ...
    'The configured minimum number of fingerprint bits was not selected.');
assert(pufMetrics.numSelectedBits <= cfg.puf.maximumSelectedBits, ...
    'The configured maximum number of fingerprint bits was exceeded.');
assert(all(isfinite(pufModel.meanValidationReliability)), ...
    'PUF validation reliability contains NaN or Inf.');
[testNames,passed] = localRecord(testNames,passed,'puf_metrics');

% 8. Fitted identity transform must be finite, dimensionally stable, and use
% only the explicitly configured measurable nuisance variables.
identityEmbedding = transformIdentityFeatures(identityModel, ...
    dataset.features(splits.test,:),dataset.metadata(splits.test,:));
assert(size(identityEmbedding,1) == sum(splits.test), ...
    'Identity transform changed the sample count.');
assert(size(identityEmbedding,2) == numel(identityModel.selectedFeatures), ...
    'Identity transform changed the selected feature count.');
assert(all(isfinite(identityEmbedding(:))), ...
    'Identity embedding contains NaN or Inf.');
assert(~any(strcmp(identityModel.conditionNormalizer.variableNames,'StressPa')) && ...
    ~any(strcmp(identityModel.conditionNormalizer.variableNames,'AgingLevel')), ...
    'Health variables leaked into the identity nuisance transform.');
[testNames,passed] = localRecord(testNames,passed,'condition_transform_contract');

% 9. Synthetic extrapolation test for a removable operating-condition shift.
[syntheticTrain,syntheticTrainIds,syntheticTrainMetadata, ...
    syntheticTest,syntheticTestIds,syntheticTestMetadata] = ...
    localSyntheticConditionData();
syntheticCfg = cfg;
syntheticCfg.identity.maxFeatures = size(syntheticTrain,2);
syntheticCfg.identity.nuisanceRidge = 0;
syntheticCfg.identity.covarianceRegularization = 0.50;
syntheticModel = trainIdentityModel(syntheticTrain,syntheticTrainIds, ...
    syntheticTrainMetadata,syntheticCfg);
syntheticPrediction = predictIdentity(syntheticModel,syntheticTest, ...
    syntheticTestMetadata);
assert(mean(syntheticPrediction == syntheticTestIds) >= 0.95, ...
    'Condition residualization failed the synthetic unseen-shift test.');
[testNames,passed] = localRecord(testNames,passed, ...
    'synthetic_unseen_condition_robustness');

% 10. Condition-holdout tuner and nuisance-subspace contract.
tuningCfg = cfg;
tuningCfg.identity.featureCountGrid = 12;
tuningCfg.identity.covarianceRegularizationGrid = 0.25;
tuningCfg.identity.nuisanceComponentGrid = [0 2];
tunedModel = tuneIdentityModel(dataset.features(splits.train,:), ...
    dataset.metadata.CoreId(splits.train),dataset.metadata(splits.train,:), ...
    dataset.features(splits.validation,:), ...
    dataset.metadata.CoreId(splits.validation), ...
    dataset.metadata(splits.validation,:),tuningCfg);
assert(strcmp(tunedModel.tuningStrategy,'leave_one_condition_out'), ...
    'Identity tuning did not use condition holdout.');
assert(height(tunedModel.tuningResults) == 2, ...
    'Identity tuner evaluated an unexpected number of candidates.');
assert(tunedModel.nuisanceComponents == 0 || ...
    size(tunedModel.nuisanceBasis,2) == 2, ...
    'Nuisance basis does not match the selected component count.');
if ~isempty(tunedModel.nuisanceBasis)
    orthogonalityError = norm(tunedModel.nuisanceBasis'* ...
        tunedModel.nuisanceBasis-eye(tunedModel.nuisanceComponents),'fro');
    assert(orthogonalityError < 1e-8,'Nuisance basis is not orthonormal.');
end
[testNames,passed] = localRecord(testNames,passed, ...
    'condition_holdout_tuning');

% 11. Three-read session and preregistered final-holdout evaluation paths.
[~,sessionIdentityMetrics] = evaluateIdentitySessions(identityModel, ...
    dataset.features(splits.unseen,:),dataset.metadata(splits.unseen,:),3);
[sessionPUFMetrics,sessionInfo] = evaluatePUFSessions(pufModel, ...
    dataset.features(splits.unseen,:),dataset.metadata(splits.unseen,:),3);
assert(sessionIdentityMetrics.numSessions == sessionInfo.numSessions, ...
    'Identity and PUF session counts do not agree.');
assert(sessionIdentityMetrics.readsPerDecision == 3 && ...
    sessionPUFMetrics.readsPerDecision == 3, ...
    'Session evaluation did not preserve the read count.');
assert(sessionPUFMetrics.reliability >= 0 && sessionPUFMetrics.reliability <= 1, ...
    'Session PUF reliability is outside [0,1].');
[finalPrediction,finalConfidence,finalDistances] = predictIdentity(identityModel, ...
    dataset.features(splits.finalHoldout,:), ...
    dataset.metadata(splits.finalHoldout,:));
finalMetrics = computeVerificationMetrics(finalPrediction, ...
    dataset.metadata.CoreId(splits.finalHoldout),finalConfidence,finalDistances, ...
    identityModel.coreIds);
assert(isfinite(finalMetrics.accuracy) && isfinite(finalMetrics.eer), ...
    'Final-holdout identity metrics are not finite.');
[testNames,passed] = localRecord(testNames,passed, ...
    'session_and_final_holdout_paths');

% 12. V3 challenge matrix is complete, unique, and contains one reference.
fullActiveCfg = defaultActiveConfig();
challenges = fullActiveCfg.active.challenges;
assert(numel(challenges) == 24,'V3 must define exactly 24 challenges.');
assert(numel(unique({challenges.code})) == numel(challenges), ...
    'V3 challenge codes are not unique.');
referenceCount = sum([challenges.id] == ...
    fullActiveCfg.active.referenceChallengeId);
assert(referenceCount == 1,'V3 reference challenge is not unique.');
assert(fullActiveCfg.active.cyclesPerChallenge == 16, ...
    'V3 challenge averaging changed after preregistration.');
assert(fullActiveCfg.puf.transformNuisanceComponents == 20, ...
    'V3 PUF stability transform changed after preregistration.');
assert(~fullActiveCfg.puf.allowFallbackToMinimum, ...
    'V3 must not fill its response with ineligible fallback bits.');
assert(isequal(fullActiveCfg.dataset.finalHoldoutConditionIds,115:118), ...
    'V3 untouched final-scenario IDs changed after preregistration.');
[testNames,passed] = localRecord(testNames,passed,'active_challenge_contract');

% 13. Persistent pinning maps reproduce exactly and differ across cores.
activeCfg = localSmallActiveConfig(fullActiveCfg);
activeCoreA = createActiveCore(1,activeCfg);
activeCoreB = createActiveCore(1,activeCfg);
activeCoreOther = createActiveCore(2,activeCfg);
assert(isequal(activeCoreA.pinningSites.thresholdAm, ...
    activeCoreB.pinningSites.thresholdAm), ...
    'The same active core did not reproduce its pinning map.');
assert(norm(activeCoreA.pinningSites.thresholdAm- ...
    activeCoreOther.pinningSites.thresholdAm) > 1e-6, ...
    'Different active cores received identical pinning maps.');
[testNames,passed] = localRecord(testNames,passed,'persistent_pinning_map');

% 14. Compact challenge responses are deterministic by seed and finite.
activeScenario = activeCfg.dataset.conditions(1);
activeChallenge = activeCfg.active.challenges(1);
[activeResponseA,responseNames,responsePositive] = ...
    simulateChallengeResponse(activeCoreA,activeScenario,activeChallenge, ...
    activeCfg,7654321);
activeResponseB = simulateChallengeResponse(activeCoreA,activeScenario, ...
    activeChallenge,activeCfg,7654321);
assert(isequal(activeResponseA,activeResponseB), ...
    'Active challenge response was not seed reproducible.');
assert(all(isfinite(activeResponseA)) && ...
    numel(activeResponseA) == numel(responseNames), ...
    'Active challenge response is nonfinite or dimensionally invalid.');
assert(numel(responsePositive) == numel(activeResponseA), ...
    'Active positive-coordinate mask has the wrong length.');
[testNames,passed] = localRecord(testNames,passed, ...
    'active_response_reproducibility');

% 15. Differential energy coordinates cancel a common multiplicative gain.
challengeCount = numel(activeCfg.active.challenges);
responseCount = numel(responseNames);
syntheticTensor = ones(2,challengeCount,responseCount);
energyIndex = find(strcmp(responseNames,'EnergyV2'),1);
for challengeIndex = 1:challengeCount
    syntheticTensor(:,challengeIndex,energyIndex) = 1+0.1*challengeIndex;
end
scaledTensor = syntheticTensor;
scaledTensor(:,:,energyIndex) = 7*scaledTensor(:,:,energyIndex);
[baseDifferential,activeFeatureNames] = ...
    buildDifferentialChallengeFeatures(syntheticTensor,responseNames, ...
    responsePositive,activeCfg);
scaledDifferential = buildDifferentialChallengeFeatures( ...
    scaledTensor,responseNames,responsePositive,activeCfg);
energyDelta = contains(activeFeatureNames,'EnergyV2_delta');
assert(max(abs(baseDifferential(:,energyDelta)- ...
    scaledDifferential(:,energyDelta)),[],'all') < 1e-10, ...
    'Differential energy features did not cancel common gain.');
[testNames,passed] = localRecord(testNames,passed, ...
    'active_reference_gain_cancellation');

% 16. Miniature active dataset is finite and partition-disjoint.
activeCores = repmat(activeCoreA,activeCfg.dataset.numCores,1);
for k = 1:activeCfg.dataset.numCores
    activeCores(k) = createActiveCore(k,activeCfg);
end
activeDataset = generateActiveDataset(activeCores,activeCfg);
activeSplits = splitDataset(activeDataset.metadata,activeCfg);
activeMembership = double(activeSplits.train)+double(activeSplits.validation)+ ...
    double(activeSplits.test)+double(activeSplits.unseen)+ ...
    double(activeSplits.finalHoldout);
assert(all(activeMembership <= 1),'Active dataset partitions overlap.');
assert(all(isfinite(activeDataset.features(:))), ...
    'Active differential features contain NaN or Inf.');
assert(size(activeDataset.features,2) == ...
    numel(activeCfg.active.challenges)*numel(responseNames), ...
    'Active differential feature width is inconsistent.');
[testNames,passed] = localRecord(testNames,passed, ...
    'active_dataset_partition_contract');

% 17. Active identity, PUF, multi-sweep, and final-gate paths execute.
activeIdentityModel = tuneIdentityModel( ...
    activeDataset.features(activeSplits.train,:), ...
    activeDataset.metadata.CoreId(activeSplits.train), ...
    activeDataset.metadata(activeSplits.train,:), ...
    activeDataset.features(activeSplits.validation,:), ...
    activeDataset.metadata.CoreId(activeSplits.validation), ...
    activeDataset.metadata(activeSplits.validation,:),activeCfg);
[activePrediction,activeConfidence,activeDistances] = predictIdentity( ...
    activeIdentityModel,activeDataset.features(activeSplits.finalHoldout,:), ...
    activeDataset.metadata(activeSplits.finalHoldout,:));
activeIdentityMetrics = computeVerificationMetrics(activePrediction, ...
    activeDataset.metadata.CoreId(activeSplits.finalHoldout), ...
    activeConfidence,activeDistances,activeIdentityModel.coreIds);
activePUFIdentityModel = trainActivePUFTransform( ...
    activeDataset.features(activeSplits.train,:), ...
    activeDataset.metadata.CoreId(activeSplits.train), ...
    activeDataset.metadata(activeSplits.train,:),activeCfg);
assert(strcmp(activePUFIdentityModel.role,'active_puf_stability_transform'), ...
    'Active PUF transform role was not preserved.');
activePUFModel = generateBinaryFingerprint( ...
    activeDataset.features(activeSplits.train,:), ...
    activeDataset.metadata.CoreId(activeSplits.train),activeCfg, ...
    activePUFIdentityModel,activeDataset.metadata(activeSplits.train,:), ...
    activeDataset.features(activeSplits.validation,:), ...
    activeDataset.metadata.CoreId(activeSplits.validation), ...
    activeDataset.metadata(activeSplits.validation,:));
activePUFMetrics = evaluatePUF(activePUFModel, ...
    activeDataset.features(activeSplits.finalHoldout,:), ...
    activeDataset.metadata.CoreId(activeSplits.finalHoldout), ...
    activeDataset.metadata(activeSplits.finalHoldout,:));
[activeWorst,~] = computeWorstConditionPUFReliability(activePUFModel, ...
    activeDataset.features(activeSplits.finalHoldout,:), ...
    activeDataset.metadata.CoreId(activeSplits.finalHoldout), ...
    activeDataset.metadata(activeSplits.finalHoldout,:));
[~,activeSessionIdentity] = evaluateIdentitySessions(activeIdentityModel, ...
    activeDataset.features(activeSplits.finalHoldout,:), ...
    activeDataset.metadata(activeSplits.finalHoldout,:),3);
[activeSessionPUF,~] = evaluatePUFSessions(activePUFModel, ...
    activeDataset.features(activeSplits.finalHoldout,:), ...
    activeDataset.metadata(activeSplits.finalHoldout,:),3);
activeChecks = evaluateActiveFinalChecks(activeIdentityMetrics, ...
    activePUFMetrics,activeWorst,activeSessionIdentity,activeSessionPUF,activeCfg);
assert(height(activeChecks) == 10 && all(isfinite(activeChecks.Current)), ...
    'Active final-gate path returned an invalid table.');
[testNames,passed] = localRecord(testNames,passed, ...
    'active_identity_puf_final_paths');

% 18. V3.1 capacity audit reproduces the strict selector without final rows.
miniActiveResults.cfg = activeCfg;
miniActiveResults.features = activeDataset.features;
miniActiveResults.featureNames = activeDataset.featureNames;
miniActiveResults.metadata = activeDataset.metadata;
miniActiveResults.splits = activeSplits;
miniActiveResults.pufIdentityModel = activePUFIdentityModel;
miniActiveResults.pufModel = activePUFModel;
capacityOptions.targetBits = 4;
capacityOptions.maximumBits = 16;
capacityOptions.randomStarts = 8;
capacityOptions.randomDegreeWindow = 1;
capacityOptions.randomSeed = 24680;
capacityOptions.exactSearchSeconds = 0;
capacityOptions.exactSearchNodeLimit = 1000;
capacityOptions.saveResults = false;
capacityOptions.verbose = false;
capacityAudit = analyzeV31Capacity(miniActiveResults,capacityOptions);
assert(capacityAudit.integrity.finalRowsUsed == 0, ...
    'The V3.1 capacity audit consumed locked final rows.');
assert(capacityAudit.integrity.thresholdsReproduced, ...
    'The V3.1 capacity audit did not reproduce enrollment thresholds.');
assert(capacityAudit.integrity.frozenSelectionMatches, ...
    'The V3.1 audit did not reproduce the frozen strict selector.');
assert(capacityAudit.selection.frozenGreedyCount == ...
    activePUFModel.numSelectedEligibleBits, ...
    'The V3.1 frozen-greedy count changed.');
assert(capacityAudit.selection.bestCount >= ...
    capacityAudit.selection.frozenGreedyCount, ...
    'The V3.1 selector regressed below the frozen greedy lower bound.');
selectedPositions = find(ismember( ...
    capacityAudit.eligibility.eligibleCandidateIndices, ...
    capacityAudit.selection.selectedCandidateIndices));
selectedConflicts = capacityAudit.graph.conflictGraph( ...
    selectedPositions,selectedPositions);
assert(nnz(triu(selectedConflicts,1)) == 0, ...
    'The V3.1 audit retained correlated conflicting bits.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v31_capacity_graph_audit');

% 19. V3.2 representation diagnostic reconstructs only enrollment and
% validation structure, preserves frozen thresholds, and excludes final rows.
diagnosticOptions.saveResults = false;
diagnosticOptions.verbose = false;
representationDiagnostic = analyzeV32Representation( ...
    miniActiveResults,diagnosticOptions);
assert(representationDiagnostic.integrity.finalRowsUsed == 0 && ...
    representationDiagnostic.integrity.developmentRowsUsed == 0, ...
    'The V3.2 representation diagnostic consumed excluded rows.');
assert(representationDiagnostic.integrity.thresholdsReproduced, ...
    'The V3.2 diagnostic did not reproduce enrollment thresholds.');
assert(representationDiagnostic.integrity.eligibleCountReproduced, ...
    'The V3.2 diagnostic did not reproduce the eligible-candidate count.');
assert(representationDiagnostic.summary.numEligibleCandidates == ...
    height(representationDiagnostic.candidates.table), ...
    'The V3.2 candidate table has an inconsistent height.');
assert(all(~representationDiagnostic.pattern.canonicalReferenceBits(1,:)), ...
    'Canonical response patterns did not normalize complement symmetry.');
assert(representationDiagnostic.summary.numCanonicalPatterns <= ...
    representationDiagnostic.summary.numExactReferencePatterns, ...
    'Canonicalization unexpectedly increased the pattern count.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_representation_diagnostic');

% 20. V3.2 projected-bit development is deterministic, encoder-compatible,
% and excludes every locked final row from fitting and reporting.
projectionOptions.randomProjectionCount = 128;
projectionOptions.subspaceDimensions = 3;
projectionOptions.withinVarianceRegularization = 0.25;
projectionOptions.energyWeightExponent = 0.50;
projectionOptions.randomSeed = 97531;
projectionOptions.targetBits = 2;
projectionOptions.maximumBits = 3;
projectionOptions.saveResults = false;
projectionOptions.verbose = false;
projectedStudyA = analyzeV32ProjectedPUF( ...
    miniActiveResults,projectionOptions);
projectedStudyB = analyzeV32ProjectedPUF( ...
    miniActiveResults,projectionOptions);
assert(projectedStudyA.integrity.finalRowsUsed == 0, ...
    'V3.2 projected-bit development consumed locked final rows.');
assert(strcmp(projectedStudyA.pufModel.candidateMode,'linear_projection'), ...
    'V3.2 projected-bit encoder mode was not preserved.');
assert(projectedStudyA.pufModel.numSelectedEligibleBits >= ...
    projectionOptions.targetBits, ...
    'The deterministic miniature projection bank missed its target.');
assert(isequal(projectedStudyA.pufModel.selectedBits, ...
    projectedStudyB.pufModel.selectedBits) && ...
    isequal(projectedStudyA.pufModel.referenceBits, ...
    projectedStudyB.pufModel.referenceBits) && ...
    max(abs(projectedStudyA.pufModel.projectionMatrix(:)- ...
    projectedStudyB.pufModel.projectionMatrix(:))) < 1e-12, ...
    'V3.2 projected-bit development was not seed reproducible.');
assert(projectedStudyA.pufModel.maximumSelectedCorrelation <= ...
    activeCfg.puf.maximumReferenceCorrelation, ...
    'V3.2 projected bits violate the frozen correlation limit.');
defaultProjectionOptions.randomProjectionCount = 32;
defaultProjectionOptions.subspaceDimensions = 3;
defaultProjectionOptions.randomSeed = 86420;
defaultProjectionOptions.saveResults = false;
defaultProjectionOptions.verbose = false;
defaultProjectedStudy = analyzeV32ProjectedPUF( ...
    miniActiveResults,defaultProjectionOptions);
assert(defaultProjectedStudy.pufModel.targetBits == ...
    activeCfg.puf.minimumSelectedBits, ...
    'V3.2 projected development did not supply the default bit target.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_projected_puf_development');

% 21. The preregistered V3.2 contract defines a new population, separates
% development from final generation, and detects result-relevant changes.
v32Cfg = defaultV32Config();
v32DevelopmentCfg = buildV32StageConfig(v32Cfg,'development');
v32FinalCfg = buildV32StageConfig(v32Cfg,'final');
assert(v32Cfg.dataset.numCores == 64 && v32Cfg.rngSeed == 20260831, ...
    'V3.2 population size or seed changed after protocol freeze.');
assert(isequal([v32DevelopmentCfg.dataset.conditions.id],201:214), ...
    'V3.2 development stage contains unexpected conditions.');
assert(isequal([v32FinalCfg.dataset.conditions.id],215:218) && ...
    all([v32FinalCfg.dataset.conditions.isFinalHoldout]), ...
    'V3.2 final stage does not contain exactly the sealed conditions.');
assert(isempty(intersect([v32DevelopmentCfg.dataset.conditions.id], ...
    [v32FinalCfg.dataset.conditions.id])) && ...
    isempty(intersect(v32Cfg.dataset.finalHoldoutConditionIds,115:118)), ...
    'V3.2 reused an observed or development condition in final.');
assert(v32Cfg.dataset.seedByConditionId && ...
    v32Cfg.v32.projection.randomProjectionCount == 8192 && ...
    v32Cfg.v32.projection.subspaceDimensions == 19, ...
    'V3.2 acquisition or projected-bit construction changed.');
contractA = buildV32ProtocolContract(v32Cfg);
changedV32Cfg = v32Cfg;
changedV32Cfg.sensor.baseNoiseStdV = ...
    changedV32Cfg.sensor.baseNoiseStdV*1.01;
contractB = buildV32ProtocolContract(changedV32Cfg);
assert(~isequaln(contractA,contractB), ...
    'V3.2 protocol contract ignored a result-relevant sensor change.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_preregistered_stage_contract');

% 22. Condition-ID acquisition seeds remain distinct when final scenarios
% are generated separately, while the original V3 formula remains intact.
developmentScenario = v32DevelopmentCfg.dataset.conditions(1);
finalScenario = v32FinalCfg.dataset.conditions(1);
developmentSeed = activeAcquisitionSeed(v32Cfg,3, ...
    developmentScenario,1,2,7);
finalSeed = activeAcquisitionSeed(v32Cfg,3,finalScenario,1,2,7);
assert(developmentSeed ~= finalSeed && developmentSeed == ...
    activeAcquisitionSeed(v32Cfg,3,developmentScenario,1,2,7), ...
    'V3.2 condition-ID seeds collide or are not reproducible.');
legacySeed = activeAcquisitionSeed(fullActiveCfg,2, ...
    fullActiveCfg.dataset.conditions(4),4,3,5);
expectedLegacySeed = double(fullActiveCfg.rngSeed)+2e7+4e5+3000+5;
assert(legacySeed == expectedLegacySeed, ...
    'The V3.2 seed helper changed the locked legacy V3 formula.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_condition_seed_isolation');

% 23. The ten V3.2 gates accept their exact boundaries, and the final
% runner rejects every call that lacks the explicit one-time token.
gateIdentity.accuracy = 0.60;
gateIdentity.eer = 0.20;
gatePUF.reliability = 0.90;
gatePUF.uniqueness = 0.50;
gatePUF.numSelectedEligibleBits = 32;
gateSessionIdentity.accuracy = 0.70;
gateSessionIdentity.eer = 0.15;
gateSessionPUF.reliability = 0.93;
gateModel.maximumSelectedCorrelation = 0.80;
v32Checks = evaluateV32Checks(gateIdentity,gatePUF,0.85, ...
    gateSessionIdentity,gateSessionPUF,gateModel,v32Cfg);
assert(height(v32Checks) == 10 && all(v32Checks.Passed), ...
    'V3.2 gates rejected their frozen inclusive boundaries.');
confirmationRejected = false;
try
    main_v32_final('INVALID_TOKEN');
catch exception
    confirmationRejected = strcmp(exception.identifier, ...
        'TrafoDNA:V32FinalConfirmationRequired');
end
assert(confirmationRejected, ...
    'V3.2 final runner did not enforce the explicit confirmation token.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_gate_and_final_guard');

% 24. The locked-result reporter reproduces all ten checks, verifies the
% final-row contract, derives scenario/bit tables, and hashes evidence
% without fitting a model or generating a new final row.
reportCfg = v32Cfg;
reportCfg.dataset.numCores = activeCfg.dataset.numCores;
reportCfg.dataset.numConditions = activeCfg.dataset.numConditions;
reportCfg.dataset.repetitions = activeCfg.dataset.repetitions;
reportCfg.dataset.trainRepeats = activeCfg.dataset.trainRepeats;
reportCfg.dataset.validationRepeats = activeCfg.dataset.validationRepeats;
reportCfg.dataset.testRepeats = activeCfg.dataset.testRepeats;
reportCfg.dataset.unseenConditionIds = activeCfg.dataset.unseenConditionIds;
reportCfg.dataset.finalHoldoutConditionIds = ...
    activeCfg.dataset.finalHoldoutConditionIds;
reportCfg.dataset.conditions = activeCfg.dataset.conditions;
reportCfg.signal = activeCfg.signal;
reportCfg.sensor = activeCfg.sensor;
reportCfg.active = activeCfg.active;
reportCfg.identity = activeCfg.identity;
reportCfg.puf = activeCfg.puf;
reportCfg.session = activeCfg.session;

reportFinalMask = activeSplits.finalHoldout;
reportPUFMetrics = evaluatePUF(projectedStudyA.pufModel, ...
    activeDataset.features(reportFinalMask,:), ...
    activeDataset.metadata.CoreId(reportFinalMask), ...
    activeDataset.metadata(reportFinalMask,:));
[reportWorstReliability,reportPUFByCondition] = ...
    computeWorstConditionPUFReliability(projectedStudyA.pufModel, ...
    activeDataset.features(reportFinalMask,:), ...
    activeDataset.metadata.CoreId(reportFinalMask), ...
    activeDataset.metadata(reportFinalMask,:));
[reportSessionPUF,~] = evaluatePUFSessions(projectedStudyA.pufModel, ...
    activeDataset.features(reportFinalMask,:), ...
    activeDataset.metadata(reportFinalMask,:),3);
reportChecks = evaluateV32Checks(activeIdentityMetrics,reportPUFMetrics, ...
    reportWorstReliability,activeSessionIdentity,reportSessionPUF, ...
    projectedStudyA.pufModel,reportCfg);
reportContract = buildV32ProtocolContract(reportCfg);

miniPrepared.cfg = reportCfg;
miniPrepared.contract = reportContract;
miniPrepared.pufModel = projectedStudyA.pufModel;
miniPrepared.development.checks = reportChecks;
miniPrepared.integrity.developmentRowsGenerated = ...
    sum(~reportFinalMask);
miniPrepared.integrity.finalRowsGenerated = 0;
miniPrepared.integrity.finalRowsUsed = 0;

miniFinal.study = reportCfg.study.name;
miniFinal.protocolVersion = reportCfg.study.protocolVersion;
miniFinal.status = 'locked_final_observed';
miniFinal.contract = reportContract;
miniFinal.metadata = activeDataset.metadata(reportFinalMask,:);
miniFinal.identityPrediction = activePrediction;
miniFinal.identityMetrics = activeIdentityMetrics;
miniFinal.pufMetrics = reportPUFMetrics;
miniFinal.worstConditionPUFReliability = reportWorstReliability;
miniFinal.pufByCondition = reportPUFByCondition;
miniFinal.sessionIdentityMetrics = activeSessionIdentity;
miniFinal.sessionPUFMetrics = reportSessionPUF;
miniFinal.pufModel = projectedStudyA.pufModel;
miniFinal.checks = reportChecks;
miniFinal.hypothesisSupported = all(reportChecks.Passed);
miniFinal.integrity.finalRowsGenerated = sum(reportFinalMask);
miniFinal.integrity.finalRowsUsed = sum(reportFinalMask);
miniFinal.integrity.finalConditionIds = ...
    unique(miniFinal.metadata.ConditionId,'stable')';
miniFinal.integrity.preparationFinalRowsUsed = 0;

reportOptions.createFigures = false;
reportOptions.saveFiles = false;
reportOptions.verbose = false;
reportResult = createV32FinalReport(miniPrepared,miniFinal,reportOptions);
assert(reportResult.integrityVerified && ...
    reportResult.storedChecksReproduced && ...
    height(reportResult.summaryTable) == 10 && ...
    height(reportResult.scenarioTable) == 1 && ...
    height(reportResult.perBitTable) == ...
    projectedStudyA.pufModel.numSelectedEligibleBits, ...
    'V3.2 locked-result reporter returned inconsistent evidence tables.');
hashA = computeFileSHA256(fullfile(projectRoot,'README.md'));
hashB = computeFileSHA256(fullfile(projectRoot,'README.md'));
assert(numel(hashA) == 64 && strcmp(hashA,hashB), ...
    'V3.2 evidence SHA-256 is invalid or non-reproducible.');
[testNames,passed] = localRecord(testNames,passed, ...
    'v32_locked_final_reporting');

results.names = testNames(:);
results.passed = logical(passed(:));
fprintf('All %d TrafoDNA tests passed.\n',numel(testNames));
end

function cfg = localSmallConfig(cfg)
cfg.dataset.numCores = 4;
cfg.dataset.numConditions = 6;
cfg.dataset.repetitions = 4;
cfg.dataset.trainRepeats = 1:2;
cfg.dataset.validationRepeats = 3;
cfg.dataset.testRepeats = 4;
cfg.dataset.unseenConditionIds = 5;
cfg.dataset.finalHoldoutConditionIds = 6;
cfg.dataset.rawExamplesPerCore = 1;
cfg.dataset.conditions = cfg.dataset.conditions(1:6);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
    cfg.dataset.conditions(k).isFinalHoldout = (k == 6);
end
cfg.signal.sampleRateHz = 2.5e4;
cfg.signal.cycles = 1;
cfg.sensor.highCutHz = 1.0e4;
cfg.identity.useSVMWhenAvailable = false;
cfg.runtime.verbose = false;
cfg.runtime.createFigures = false;
cfg.runtime.saveMatFile = false;
cfg.runtime.saveCsvFile = false;
end

function cfg = localSmallActiveConfig(cfg)
cfg.dataset.numCores = 4;
cfg.dataset.numConditions = 6;
cfg.dataset.repetitions = 4;
cfg.dataset.trainRepeats = 1:2;
cfg.dataset.validationRepeats = 3;
cfg.dataset.testRepeats = 4;
cfg.dataset.conditions = cfg.dataset.conditions(1:6);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
    cfg.dataset.conditions(k).isFinalHoldout = (k == 6);
end
cfg.dataset.unseenConditionIds = cfg.dataset.conditions(5).id;
cfg.dataset.finalHoldoutConditionIds = cfg.dataset.conditions(6).id;

referencePosition = find([cfg.active.challenges.id] == ...
    cfg.active.referenceChallengeId,1);
selected = unique([1:min(5,numel(cfg.active.challenges)) referencePosition], ...
    'stable');
candidate = numel(cfg.active.challenges);
while numel(selected) < 6
    if ~any(selected == candidate)
        selected(end+1) = candidate; %#ok<AGROW>
    end
    candidate = candidate-1;
end
cfg.active.challenges = cfg.active.challenges(selected);
cfg.active.siteCount = 64;
cfg.active.cyclesPerChallenge = 2;
cfg.identity.featureCountGrid = 24;
cfg.identity.maxFeatures = 24;
cfg.identity.covarianceRegularizationGrid = 0.25;
cfg.identity.covarianceRegularization = 0.25;
cfg.identity.nuisanceComponentGrid = 0;
cfg.identity.nuisanceComponents = 0;
cfg.puf.minimumBitReliability = 0;
cfg.puf.minimumValidationReliability = 0;
cfg.puf.minimumWorstConditionReliability = 0;
cfg.puf.minimumSelectedBits = 8;
cfg.puf.maximumSelectedBits = 16;
cfg.puf.bitAliasRange = [0 1];
cfg.puf.allowFallbackToMinimum = true;
cfg.puf.transformFeatureCount = 24;
cfg.puf.transformNuisanceComponents = 4;
cfg.puf.transformCovarianceRegularization = 0.25;
cfg.runtime.verbose = false;
cfg.runtime.createFigures = false;
cfg.runtime.saveMatFile = false;
cfg.runtime.saveCsvFile = false;
end

function [names,passed] = localRecord(names,passed,name)
names{end+1} = name;
passed(end+1) = true;
fprintf('  PASS: %s\n',name);
end

function [trainFeatures,trainIds,trainMetadata,testFeatures,testIds,testMetadata] = ...
    localSyntheticConditionData()
templates = [ ...
    -1.5 -0.8  0.4  1.0 -0.6  0.2; ...
    -0.5  0.8 -1.0  0.3  1.1 -0.4; ...
     0.7 -1.1  0.9 -0.5  0.2  1.2; ...
     1.5  0.4 -0.2 -1.0 -0.8 -1.1];
conditionDirection = [1.2 -0.9 0.8 1.1 -0.7 0.6];
trainConditions = [-1 0 1];
testCondition = 2.2;
repetitions = 3;

trainCount = size(templates,1)*numel(trainConditions)*repetitions;
trainFeatures = zeros(trainCount,size(templates,2));
trainIds = zeros(trainCount,1);
trainConditionValue = zeros(trainCount,1);
row = 0;
for core = 1:size(templates,1)
    for condition = trainConditions
        for repetition = 1:repetitions
            row = row+1;
            deterministicNoise = 0.005*sin((1:size(templates,2))*(row+repetition));
            trainFeatures(row,:) = templates(core,:) + ...
                condition*conditionDirection + deterministicNoise;
            trainIds(row) = core;
            trainConditionValue(row) = condition;
        end
    end
end

testCount = size(templates,1)*repetitions;
testFeatures = zeros(testCount,size(templates,2));
testIds = zeros(testCount,1);
testConditionValue = testCondition*ones(testCount,1);
row = 0;
for core = 1:size(templates,1)
    for repetition = 1:repetitions
        row = row+1;
        deterministicNoise = 0.005*cos((1:size(templates,2))*(row+repetition));
        testFeatures(row,:) = templates(core,:) + ...
            testCondition*conditionDirection + deterministicNoise;
        testIds(row) = core;
    end
end

trainMetadata = localSyntheticMetadata(trainConditionValue);
testMetadata = localSyntheticMetadata(testConditionValue);
end

function metadata = localSyntheticMetadata(conditionValue)
count = numel(conditionValue);
TemperatureK = 293.15 + 10*conditionValue;
ExcitationAmplitudeAm = 120*ones(count,1);
ExcitationFrequencyHz = 50*ones(count,1);
NoiseStdV = 2e-5*ones(count,1);
SensorGain = ones(count,1);
metadata = table(TemperatureK,ExcitationAmplitudeAm,ExcitationFrequencyHz, ...
    NoiseStdV,SensorGain);
end
