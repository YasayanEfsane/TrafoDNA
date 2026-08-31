function finalV32 = main_v32_final(confirmationToken,preparedBundleFile)
%MAIN_V32_FINAL Open and evaluate the frozen V3.2 final exactly once.
%   This function is intentionally token-guarded and creates a lock marker
%   before generating scenarios 215--218. Run MAIN_V32_PREPARE first and
%   archive its output. Do not call this function during development.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
cfg = defaultV32Config();
if nargin < 1 || ~strcmp(char(confirmationToken), ...
        cfg.v32.finalConfirmationToken)
    error('TrafoDNA:V32FinalConfirmationRequired', ...
        ['V3.2 final remains sealed. Supply the exact confirmation token ' ...
        'only after archiving and reviewing preparation.']);
end
if nargin < 2 || isempty(preparedBundleFile)
    preparedBundleFile = cfg.runtime.preparedBundleFile;
end
if ~isfile(preparedBundleFile)
    error('TrafoDNA:MissingV32PreparedBundle', ...
        'The frozen V3.2 prepared bundle was not found.');
end
if isfile(cfg.runtime.finalLockFile) || isfile(cfg.runtime.finalResultFile)
    error('TrafoDNA:V32FinalAlreadyOpened', ...
        'The one-time V3.2 final evaluation has already been opened.');
end

loaded = load(preparedBundleFile,'preparedV32');
if ~isfield(loaded,'preparedV32')
    error('TrafoDNA:InvalidV32PreparedBundle', ...
        'The MAT file does not contain preparedV32.');
end
preparedV32 = loaded.preparedV32;
localValidatePreparedBundle(preparedV32,cfg);
if ~exist(cfg.runtime.finalDirectory,'dir')
    mkdir(cfg.runtime.finalDirectory);
end
localCreateFinalLock(cfg,preparedBundleFile);

finalCfg = buildV32StageConfig(cfg,'final');
dataset = generateActiveDataset(preparedV32.cores,finalCfg);
localAssertOnlyFinalRows(dataset,cfg);
if ~isequal(dataset.featureNames,preparedV32.featureNames)
    error('TrafoDNA:V32FinalFeatureContractChanged', ...
        'Final feature names differ from the frozen prepared model.');
end

[identityPrediction,identityMetrics] = localIdentityEvaluation( ...
    preparedV32.identityModel,dataset.features,dataset.metadata);
pufMetrics = evaluatePUF(preparedV32.pufModel,dataset.features, ...
    dataset.metadata.CoreId,dataset.metadata);
[worstReliability,pufByCondition] = ...
    computeWorstConditionPUFReliability(preparedV32.pufModel, ...
    dataset.features,dataset.metadata.CoreId,dataset.metadata);
readsPerDecision = cfg.session.readsPerDecision;
[sessionPrediction,sessionIdentity] = evaluateIdentitySessions( ...
    preparedV32.identityModel,dataset.features,dataset.metadata, ...
    readsPerDecision);
[sessionPUF,~] = evaluatePUFSessions(preparedV32.pufModel, ...
    dataset.features,dataset.metadata,readsPerDecision);
checks = evaluateV32Checks(identityMetrics,pufMetrics,worstReliability, ...
    sessionIdentity,sessionPUF,preparedV32.pufModel,cfg);

finalV32.study = cfg.study.name;
finalV32.protocolVersion = cfg.study.protocolVersion;
finalV32.status = 'locked_final_observed';
finalV32.contract = preparedV32.contract;
finalV32.preparedBundleFile = preparedBundleFile;
finalV32.identityModel = preparedV32.identityModel;
finalV32.pufModel = preparedV32.pufModel;
finalV32.featureNames = dataset.featureNames;
finalV32.features = dataset.features;
finalV32.metadata = dataset.metadata;
finalV32.identityPrediction = identityPrediction;
finalV32.identityMetrics = identityMetrics;
finalV32.pufMetrics = pufMetrics;
finalV32.worstConditionPUFReliability = worstReliability;
finalV32.pufByCondition = pufByCondition;
finalV32.sessionPrediction = sessionPrediction;
finalV32.sessionIdentityMetrics = sessionIdentity;
finalV32.sessionPUFMetrics = sessionPUF;
finalV32.checks = checks;
finalV32.hypothesisSupported = all(checks.Passed);
finalV32.integrity.finalRowsGenerated = height(dataset.metadata);
finalV32.integrity.finalRowsUsed = height(dataset.metadata);
finalV32.integrity.finalConditionIds = ...
    unique(dataset.metadata.ConditionId,'stable')';
finalV32.integrity.preparationFinalRowsUsed = ...
    preparedV32.integrity.finalRowsUsed;

save(cfg.runtime.finalResultFile,'finalV32','-v7.3');
if cfg.runtime.saveCsvFile
    writetable(checks,fullfile(cfg.runtime.finalDirectory, ...
        'v32_final_checks.csv'));
    writetable(pufByCondition,fullfile(cfg.runtime.finalDirectory, ...
        'v32_final_puf_by_condition.csv'));
end
localAppendFinalLock(cfg,'COMPLETED');
localPrintFinal(finalV32,cfg);
end

function localValidatePreparedBundle(prepared,cfg)
required = {'status','contract','cores','featureNames','identityModel', ...
    'pufIdentityModel','pufModel','development','integrity'};
for k = 1:numel(required)
    if ~isfield(prepared,required{k})
        error('TrafoDNA:InvalidV32PreparedBundle', ...
            'Prepared bundle is missing field "%s".',required{k});
    end
end
if ~strcmp(prepared.status,'prepared_final_sealed') || ...
        prepared.integrity.finalRowsGenerated ~= 0 || ...
        prepared.integrity.finalRowsUsed ~= 0
    error('TrafoDNA:V32PreparedBundleNotSealed', ...
        'Prepared bundle does not prove a zero-final-row state.');
end
if ~isfield(prepared.development,'readyForFinal') || ...
        ~prepared.development.readyForFinal || ...
        ~all(prepared.development.checks.Passed)
    error('TrafoDNA:V32DevelopmentNotReady', ...
        'All ten frozen development-readiness gates must pass first.');
end
currentContract = buildV32ProtocolContract(cfg);
if ~isequaln(prepared.contract,currentContract)
    error('TrafoDNA:V32ProtocolContractChanged', ...
        'Current V3.2 code/config differs from the prepared contract.');
end
if numel(prepared.cores) ~= cfg.dataset.numCores || ...
        prepared.pufModel.numSelectedEligibleBits < ...
        cfg.benchmark.v32Targets.minimumEligibleBits
    error('TrafoDNA:InvalidV32FrozenModel', ...
        'Prepared population or projected-bit model is invalid.');
end
end

function localCreateFinalLock(cfg,preparedBundleFile)
[fileId,message] = fopen(cfg.runtime.finalLockFile,'w');
if fileId < 0
    error('TrafoDNA:V32FinalLockFailed', ...
        'Could not create the final lock marker: %s',message);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId,'TrafoDNA V3.2 final opened\n');
fprintf(fileId,'Protocol: %s\n',cfg.study.protocolVersion);
fprintf(fileId,'Prepared bundle: %s\n',preparedBundleFile);
fprintf(fileId,'Status: OPENED\n');
clear cleanup
end

function localAppendFinalLock(cfg,status)
fileId = fopen(cfg.runtime.finalLockFile,'a');
if fileId >= 0
    cleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId,'Status: %s\n',status);
    clear cleanup
end
end

function localAssertOnlyFinalRows(dataset,cfg)
observedIds = unique(dataset.metadata.ConditionId,'stable')';
if ~all(dataset.metadata.IsFinalHoldoutCondition) || ...
        any(dataset.metadata.IsUnseenCondition) || ...
        ~isequal(observedIds,cfg.dataset.finalHoldoutConditionIds)
    error('TrafoDNA:V32FinalPartitionViolation', ...
        'Final generation contains missing or non-final conditions.');
end
end

function [prediction,metrics] = localIdentityEvaluation(model,features,metadata)
[prediction,confidence,distances] = predictIdentity(model,features,metadata);
metrics = computeVerificationMetrics(prediction,metadata.CoreId,confidence, ...
    distances,model.coreIds);
end

function localPrintFinal(finalResult,cfg)
fprintf('\n--- TrafoDNA V3.2 Locked Final Holdout ---\n');
fprintf('Single-sweep identity accuracy          : %.2f %%\n', ...
    100*finalResult.identityMetrics.accuracy);
fprintf('Single-sweep identity EER               : %.4f\n', ...
    finalResult.identityMetrics.eer);
fprintf('Raw projected-PUF reliability           : %.4f\n', ...
    finalResult.pufMetrics.reliability);
fprintf('Projected-PUF uniqueness                : %.4f\n', ...
    finalResult.pufMetrics.uniqueness);
fprintf('Strictly eligible projected bits        : %d\n', ...
    finalResult.pufMetrics.numSelectedEligibleBits);
fprintf('Worst-final-scenario PUF reliability    : %.4f\n', ...
    finalResult.worstConditionPUFReliability);
fprintf('Three-sweep identity accuracy           : %.2f %%\n', ...
    100*finalResult.sessionIdentityMetrics.accuracy);
fprintf('Three-sweep identity EER                : %.4f\n', ...
    finalResult.sessionIdentityMetrics.eer);
fprintf('Three-sweep PUF reliability             : %.4f\n', ...
    finalResult.sessionPUFMetrics.reliability);
fprintf('Maximum selected-bit correlation        : %.4f\n', ...
    finalResult.pufModel.maximumSelectedCorrelation);
fprintf('V3.2 final checks passed                : %d/%d\n', ...
    sum(finalResult.checks.Passed),height(finalResult.checks));
if finalResult.hypothesisSupported
    decision = 'SUPPORTED';
else
    decision = 'NOT SUPPORTED';
end
fprintf('Preregistered hypothesis decision       : %s\n',decision);
fprintf('Locked final result                     : %s\n', ...
    cfg.runtime.finalResultFile);
fprintf(['Note: This remains numerical feasibility evidence, not physical ' ...
    'or cryptographic validation.\n']);
end
