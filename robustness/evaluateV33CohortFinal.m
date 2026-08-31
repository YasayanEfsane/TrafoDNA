function finalCohort = evaluateV33CohortFinal(preparedCohort,cohortCfg)
%EVALUATEV33COHORTFINAL Evaluate one already-frozen V3.3 cohort final.
%   No fitting or selection occurs here. The function generates exactly
%   the cohort's four final conditions and evaluates the stored models.

localValidatePreparedCohort(preparedCohort,cohortCfg);
finalCfg = buildV32StageConfig(cohortCfg,'final');
dataset = generateActiveDataset(preparedCohort.cores,finalCfg);
localAssertOnlyFinalRows(dataset,cohortCfg);
if ~isequal(dataset.featureNames,preparedCohort.featureNames)
    error('TrafoDNA:V33FinalFeatureContractChanged', ...
        'Final feature names differ from the frozen cohort model.');
end

[identityPrediction,identityMetrics] = localIdentityEvaluation( ...
    preparedCohort.identityModel,dataset.features,dataset.metadata);
pufMetrics = evaluatePUF(preparedCohort.pufModel,dataset.features, ...
    dataset.metadata.CoreId,dataset.metadata);
[worstReliability,pufByCondition] = ...
    computeWorstConditionPUFReliability(preparedCohort.pufModel, ...
    dataset.features,dataset.metadata.CoreId,dataset.metadata);
readsPerDecision = cohortCfg.session.readsPerDecision;
[sessionPrediction,sessionIdentity] = evaluateIdentitySessions( ...
    preparedCohort.identityModel,dataset.features,dataset.metadata, ...
    readsPerDecision);
[sessionPUF,~] = evaluatePUFSessions(preparedCohort.pufModel, ...
    dataset.features,dataset.metadata,readsPerDecision);
checks = evaluateV32Checks(identityMetrics,pufMetrics,worstReliability, ...
    sessionIdentity,sessionPUF,preparedCohort.pufModel,cohortCfg);

finalCohort.study = cohortCfg.study.name;
finalCohort.protocolVersion = cohortCfg.study.protocolVersion;
finalCohort.status = 'cohort_locked_final_observed';
finalCohort.index = preparedCohort.index;
finalCohort.seed = preparedCohort.seed;
finalCohort.cohortContract = preparedCohort.cohortContract;
finalCohort.featureNames = dataset.featureNames;
finalCohort.features = dataset.features;
finalCohort.metadata = dataset.metadata;
finalCohort.identityPrediction = identityPrediction;
finalCohort.identityMetrics = identityMetrics;
finalCohort.pufMetrics = pufMetrics;
finalCohort.worstConditionPUFReliability = worstReliability;
finalCohort.pufByCondition = pufByCondition;
finalCohort.sessionPrediction = sessionPrediction;
finalCohort.sessionIdentityMetrics = sessionIdentity;
finalCohort.sessionPUFMetrics = sessionPUF;
finalCohort.checks = checks;
finalCohort.cohortPassed = all(checks.Passed);
finalCohort.maximumSelectedCorrelation = ...
    preparedCohort.pufModel.maximumSelectedCorrelation;
finalCohort.integrity.finalRowsGenerated = height(dataset.metadata);
finalCohort.integrity.finalRowsUsed = height(dataset.metadata);
finalCohort.integrity.finalConditionIds = ...
    unique(dataset.metadata.ConditionId,'stable')';
finalCohort.integrity.preparationFinalRowsGenerated = ...
    preparedCohort.integrity.finalRowsGenerated;
finalCohort.integrity.preparationFinalRowsUsed = ...
    preparedCohort.integrity.finalRowsUsed;
end

function localValidatePreparedCohort(prepared,cohortCfg)
required = {'status','index','seed','cohortContract','cores', ...
    'featureNames','identityModel','pufIdentityModel','pufModel', ...
    'development','integrity'};
for k = 1:numel(required)
    if ~isfield(prepared,required{k})
        error('TrafoDNA:InvalidV33PreparedCohort', ...
            'Prepared cohort is missing field "%s".',required{k});
    end
end
if ~strcmp(prepared.status,'cohort_prepared_final_sealed') || ...
        prepared.integrity.finalRowsGenerated ~= 0 || ...
        prepared.integrity.finalRowsUsed ~= 0
    error('TrafoDNA:V33PreparedCohortNotSealed', ...
        'Prepared cohort does not prove a zero-final-row state.');
end
if prepared.index ~= cohortCfg.v33.currentCohort || ...
        prepared.seed ~= cohortCfg.rngSeed || ...
        numel(prepared.cores) ~= cohortCfg.dataset.numCores
    error('TrafoDNA:InvalidV33FrozenCohort', ...
        'Prepared cohort identity or population changed.');
end
currentContract = buildV32ProtocolContract(cohortCfg);
if ~isequaln(prepared.cohortContract,currentContract)
    error('TrafoDNA:V33CohortContractChanged', ...
        'Current cohort configuration differs from its prepared contract.');
end
end

function localAssertOnlyFinalRows(dataset,cfg)
observedIds = unique(dataset.metadata.ConditionId,'stable')';
expectedRows = cfg.dataset.numCores*cfg.v33.finalScenarioCount* ...
    cfg.dataset.repetitions;
if ~all(dataset.metadata.IsFinalHoldoutCondition) || ...
        any(dataset.metadata.IsUnseenCondition) || ...
        ~isequal(observedIds,cfg.dataset.finalHoldoutConditionIds) || ...
        height(dataset.metadata) ~= expectedRows
    error('TrafoDNA:V33FinalPartitionViolation', ...
        'Final generation contains missing, extra, or non-final rows.');
end
end

function [prediction,metrics] = localIdentityEvaluation(model,features,metadata)
[prediction,confidence,distances] = predictIdentity(model,features,metadata);
metrics = computeVerificationMetrics(prediction,metadata.CoreId,confidence, ...
    distances,model.coreIds);
end
