function preparedV33 = main_v33_prepare(cfg)
%MAIN_V33_PREPARE Fit five independent cohorts while every final is sealed.
%   The prepared bundle is checkpointed after each cohort. Re-running the
%   function resumes at the first unfinished cohort without regenerating
%   completed populations. No final condition is generated or evaluated.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
if nargin < 1 || isempty(cfg)
    cfg = defaultV33Config();
end
localValidateProtocol(cfg);
localEnsureDirectories(cfg);
if isfile(cfg.runtime.finalLockFile) || ...
        isfile(cfg.runtime.finalCheckpointFile) || ...
        isfile(cfg.runtime.finalResultFile)
    error('TrafoDNA:V33FinalAlreadyOpened', ...
        'The V3.3 final audit has opened; preparation is frozen.');
end

contract = buildV33ProtocolContract(cfg);
if isfile(cfg.runtime.preparedBundleFile)
    loaded = load(cfg.runtime.preparedBundleFile,'preparedV33');
    if ~isfield(loaded,'preparedV33')
        error('TrafoDNA:InvalidV33PreparedBundle', ...
            'The preparation checkpoint does not contain preparedV33.');
    end
    preparedV33 = loaded.preparedV33;
    localValidateCheckpoint(preparedV33,contract,cfg);
else
    preparedV33.study = cfg.study.name;
    preparedV33.protocolVersion = cfg.study.protocolVersion;
    preparedV33.status = 'preparing_all_cohorts_final_sealed';
    preparedV33.contract = contract;
    preparedV33.cohorts = cell(1,cfg.v33.numCohorts);
    preparedV33.completedCohorts = 0;
    preparedV33.integrity.finalRowsGenerated = 0;
    preparedV33.integrity.finalRowsUsed = 0;
    preparedV33.integrity.finalConditionIdsPresent = zeros(1,0);
    save(cfg.runtime.preparedBundleFile,'preparedV33','-v7.3');
end

if preparedV33.completedCohorts == cfg.v33.numCohorts
    wasComplete = strcmp(preparedV33.status, ...
        'prepared_all_cohorts_final_sealed') && ...
        isfield(preparedV33,'developmentSummary') && ...
        isfield(preparedV33,'developmentReadyCount');
    if ~wasComplete
        preparedV33 = localFinalizePreparation(preparedV33,cfg,contract);
    end
    localPrintPreparation(preparedV33,cfg,wasComplete);
    return;
end

for cohortIndex = preparedV33.completedCohorts+1:cfg.v33.numCohorts
    cohortCfg = buildV33CohortConfig(cfg,cohortIndex);
    if cfg.runtime.verbose
        displayCfg = buildV32StageConfig(cohortCfg,'development');
        developmentIds = [displayCfg.dataset.conditions.id];
        fprintf(['\nPreparing V3.3 cohort %d/%d: seed %d, ' ...
            'development conditions %s.\n'],cohortIndex, ...
            cfg.v33.numCohorts,cohortCfg.rngSeed,mat2str( ...
            developmentIds));
    end
    preparedV33.cohorts{cohortIndex} = prepareV33Cohort(cohortCfg);
    preparedV33.completedCohorts = cohortIndex;
    preparedV33.status = 'preparing_all_cohorts_final_sealed';
    save(cfg.runtime.preparedBundleFile,'preparedV33','-v7.3');
    localPrintCohort(preparedV33.cohorts{cohortIndex});
end

preparedV33 = localFinalizePreparation(preparedV33,cfg,contract);
localPrintPreparation(preparedV33,cfg,false);
end

function prepared = localFinalizePreparation(prepared,cfg,contract)
prepared.status = 'prepared_all_cohorts_final_sealed';
prepared.developmentSummary = localDevelopmentSummary(prepared.cohorts);
prepared.developmentReadyCount = ...
    sum(prepared.developmentSummary.ReadyForFinal);
preparedV33 = prepared; %#ok<NASGU>
save(cfg.runtime.preparedBundleFile,'preparedV33','-v7.3');
if cfg.runtime.saveCsvFile
    writetable(prepared.developmentSummary,fullfile( ...
        cfg.runtime.developmentDirectory,'v33_development_summary.csv'));
    writetable(localScenarioTable(contract),fullfile( ...
        cfg.runtime.resultsDirectory,'v33_scenario_contract.csv'));
end
end

function localValidateProtocol(cfg)
if ~strcmp(cfg.study.protocolVersion,'3.3.0-preregistered') || ...
        ~strcmp(cfg.study.status, ...
        'preregistered_joint_robustness_final_sealed') || ...
        cfg.v33.numCohorts ~= 5 || ...
        ~isequal(cfg.v33.cohortSeeds,20260901:20260905) || ...
        ~isequal(cfg.v33.scenarioHaltonStartIndices,59+18*(0:4)) || ...
        ~isequal(cfg.v33.scenarioIdBases,300:100:700) || ...
        cfg.v33.knownScenarioCount ~= 8 || ...
        cfg.v33.developmentScenarioCount ~= 6 || ...
        cfg.v33.finalScenarioCount ~= 4 || ...
        cfg.v33.scenariosPerCohort ~= 18 || ...
        cfg.v33.requiredPassingCohorts ~= 4 || ...
        cfg.v33.requiredPassRate ~= 0.80 || ...
        ~cfg.v33.evaluateEveryFinalCohort || ...
        cfg.dataset.numCores ~= 64 || cfg.dataset.repetitions ~= 9 || ...
        ~cfg.dataset.seedByConditionId || ...
        cfg.v32.projection.randomSeed ~= 20260831
    error('TrafoDNA:InvalidV33ProtocolContract', ...
        'The frozen production V3.3 cohort or decision contract changed.');
end
end

function localValidateCheckpoint(prepared,contract,cfg)
required = {'status','contract','cohorts','completedCohorts','integrity'};
for k = 1:numel(required)
    if ~isfield(prepared,required{k})
        error('TrafoDNA:InvalidV33PreparedBundle', ...
            'Preparation checkpoint is missing field "%s".',required{k});
    end
end
if ~ismember(prepared.status,{'preparing_all_cohorts_final_sealed', ...
        'prepared_all_cohorts_final_sealed'}) || ...
        ~isequaln(prepared.contract,contract) || ...
        numel(prepared.cohorts) ~= cfg.v33.numCohorts || ...
        prepared.completedCohorts < 0 || ...
        prepared.completedCohorts > cfg.v33.numCohorts || ...
        any(cellfun(@isempty,prepared.cohorts(1:prepared.completedCohorts))) || ...
        prepared.integrity.finalRowsGenerated ~= 0 || ...
        prepared.integrity.finalRowsUsed ~= 0
    error('TrafoDNA:InvalidV33PreparationCheckpoint', ...
        'The V3.3 checkpoint is incomplete, changed, or not sealed.');
end
for cohortIndex = 1:prepared.completedCohorts
    cohortCfg = buildV33CohortConfig(cfg,cohortIndex);
    cohort = prepared.cohorts{cohortIndex};
    if cohort.index ~= cohortIndex || ...
            ~isequaln(cohort.cohortContract, ...
            buildV32ProtocolContract(cohortCfg)) || ...
            cohort.integrity.finalRowsGenerated ~= 0 || ...
            cohort.integrity.finalRowsUsed ~= 0
        error('TrafoDNA:InvalidV33PreparationCheckpoint', ...
            'Prepared cohort %d does not match the frozen contract.', ...
            cohortIndex);
    end
end
end

function summary = localDevelopmentSummary(cohorts)
count = numel(cohorts);
cohort = (1:count)';
seed = zeros(count,1);
identityAccuracy = zeros(count,1);
identityEER = zeros(count,1);
pufReliability = zeros(count,1);
pufUniqueness = zeros(count,1);
eligibleBits = zeros(count,1);
worstScenarioReliability = zeros(count,1);
sessionIdentityAccuracy = zeros(count,1);
sessionIdentityEER = zeros(count,1);
sessionPUFReliability = zeros(count,1);
maximumSelectedCorrelation = zeros(count,1);
checksPassed = zeros(count,1);
readyForFinal = false(count,1);
for k = 1:count
    item = cohorts{k};
    dev = item.development;
    seed(k) = item.seed;
    identityAccuracy(k) = dev.unseenIdentity.accuracy;
    identityEER(k) = dev.unseenIdentity.eer;
    pufReliability(k) = dev.pooledPUF.reliability;
    pufUniqueness(k) = dev.pooledPUF.uniqueness;
    eligibleBits(k) = item.pufModel.numSelectedEligibleBits;
    worstScenarioReliability(k) = ...
        dev.worstConditionPUFReliability;
    sessionIdentityAccuracy(k) = dev.sessionIdentity.accuracy;
    sessionIdentityEER(k) = dev.sessionIdentity.eer;
    sessionPUFReliability(k) = dev.sessionPUF.reliability;
    maximumSelectedCorrelation(k) = ...
        item.pufModel.maximumSelectedCorrelation;
    checksPassed(k) = sum(dev.checks.Passed);
    readyForFinal(k) = dev.readyForFinal;
end
summary = table(cohort,seed,identityAccuracy,identityEER,pufReliability, ...
    pufUniqueness,eligibleBits,worstScenarioReliability, ...
    sessionIdentityAccuracy,sessionIdentityEER,sessionPUFReliability, ...
    maximumSelectedCorrelation,checksPassed,readyForFinal, ...
    'VariableNames',{'Cohort','Seed','IdentityAccuracy','IdentityEER', ...
    'PUFReliability','PUFUniqueness','EligibleBits', ...
    'WorstScenarioReliability','SessionIdentityAccuracy', ...
    'SessionIdentityEER','SessionPUFReliability', ...
    'MaximumSelectedCorrelation','ChecksPassed','ReadyForFinal'});
end

function scenarioTable = localScenarioTable(contract)
rows = contract.numCohorts*contract.scenariosPerCohort;
cohort = zeros(rows,1);
haltonIndex = zeros(rows,1);
scenarioId = zeros(rows,1);
stage = cell(rows,1);
row = 0;
for k = 1:contract.numCohorts
    cohortContract = contract.cohorts(k);
    for position = 1:contract.scenariosPerCohort
        row = row+1;
        cohort(row) = k;
        haltonIndex(row) = cohortContract.haltonIndices(position);
        scenarioId(row) = cohortContract.scenarioIds(position);
        if position <= contract.knownScenarioCount
            stage{row} = 'known';
        elseif position <= contract.knownScenarioCount+ ...
                contract.developmentScenarioCount
            stage{row} = 'unseen_development';
        else
            stage{row} = 'locked_final';
        end
    end
end
scenarioTable = table(cohort,haltonIndex,scenarioId,stage, ...
    'VariableNames',{'Cohort','HaltonIndex','ScenarioId','Stage'});
end

function localEnsureDirectories(cfg)
directories = {cfg.runtime.resultsDirectory, ...
    cfg.runtime.developmentDirectory,cfg.runtime.finalDirectory, ...
    cfg.runtime.cohortDirectory};
for k = 1:numel(directories)
    if ~exist(directories{k},'dir')
        mkdir(directories{k});
    end
end
end

function localPrintCohort(cohort)
dev = cohort.development;
fprintf(['Cohort %d checkpointed: identity %.2f %%, EER %.4f, ' ...
    'PUF %.4f, bits %d, checks %d/10, final rows 0.\n'], ...
    cohort.index,100*dev.unseenIdentity.accuracy,dev.unseenIdentity.eer, ...
    dev.pooledPUF.reliability,cohort.pufModel.numSelectedEligibleBits, ...
    sum(dev.checks.Passed));
end

function localPrintPreparation(prepared,cfg,alreadyComplete)
fprintf('\n--- TrafoDNA V3.3 Sealed Robustness Preparation ---\n');
fprintf('Independent cohorts prepared           : %d/%d\n', ...
    prepared.completedCohorts,cfg.v33.numCohorts);
fprintf('Virtual cores per cohort               : %d\n', ...
    cfg.dataset.numCores);
fprintf('Final rows generated / used            : %d / %d\n', ...
    prepared.integrity.finalRowsGenerated, ...
    prepared.integrity.finalRowsUsed);
if isfield(prepared,'developmentReadyCount')
    fprintf('Cohorts passing development gates      : %d/%d\n', ...
        prepared.developmentReadyCount,cfg.v33.numCohorts);
end
fprintf('Prepared bundle                        : %s\n', ...
    cfg.runtime.preparedBundleFile);
if alreadyComplete
    fprintf('Status: EXISTING PREPARATION VERIFIED; FINAL REMAINS SEALED.\n');
else
    fprintf('Status: ALL COHORTS FROZEN; FINAL REMAINS SEALED.\n');
end
fprintf(['Do not run MAIN_V33_FINAL_AUDIT until the complete preparation ' ...
    'record has been reviewed and archived.\n']);
end
