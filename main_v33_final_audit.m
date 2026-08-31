function auditV33 = main_v33_final_audit(confirmationToken,preparedBundleFile)
%MAIN_V33_FINAL_AUDIT Open all five frozen V3.3 finals as one audit.
%   The exact token is required. A lock and checkpoint are written before
%   the first final row is generated. If MATLAB stops, call the function
%   again with the same token to resume; completed cohorts are not rerun.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
cfg = defaultV33Config();
if isempty(cfg.v33.finalConfirmationToken)
    error('TrafoDNA:V33FinalTokenNotConfigured', ...
        ['Set the local TRAFODNA_V33_FINAL_TOKEN environment variable ' ...
        'only after reviewing and archiving all five preparations.']);
end
if nargin < 1 || ~strcmp(char(confirmationToken), ...
        cfg.v33.finalConfirmationToken)
    error('TrafoDNA:V33FinalConfirmationRequired', ...
        ['V3.3 final remains sealed. Supply the exact confirmation token ' ...
        'only after all five preparations are reviewed and archived.']);
end
if nargin < 2 || isempty(preparedBundleFile)
    preparedBundleFile = cfg.runtime.preparedBundleFile;
end
if ~isfile(preparedBundleFile)
    error('TrafoDNA:MissingV33PreparedBundle', ...
        'The frozen V3.3 prepared bundle was not found.');
end
if isfile(cfg.runtime.finalResultFile)
    error('TrafoDNA:V33FinalAlreadyCompleted', ...
        'The V3.3 robustness final result already exists.');
end

loaded = load(preparedBundleFile,'preparedV33');
if ~isfield(loaded,'preparedV33')
    error('TrafoDNA:InvalidV33PreparedBundle', ...
        'The MAT file does not contain preparedV33.');
end
preparedV33 = loaded.preparedV33;
contract = buildV33ProtocolContract(cfg);
localValidatePreparedBundle(preparedV33,contract,cfg);
if ~exist(cfg.runtime.finalDirectory,'dir')
    mkdir(cfg.runtime.finalDirectory);
end

if isfile(cfg.runtime.finalCheckpointFile)
    if ~isfile(cfg.runtime.finalLockFile)
        error('TrafoDNA:V33FinalCheckpointWithoutLock', ...
            'A final checkpoint exists without its audit lock marker.');
    end
    loadedCheckpoint = load(cfg.runtime.finalCheckpointFile,'auditV33');
    if ~isfield(loadedCheckpoint,'auditV33')
        error('TrafoDNA:InvalidV33FinalCheckpoint', ...
            'The final checkpoint does not contain auditV33.');
    end
    auditV33 = loadedCheckpoint.auditV33;
    localValidateFinalCheckpoint(auditV33,contract,cfg);
else
    if isfile(cfg.runtime.finalLockFile)
        error('TrafoDNA:V33FinalLockWithoutCheckpoint', ...
            ['The final lock exists without a resumable checkpoint. ' ...
            'Do not remove the lock; preserve the state for audit.']);
    end
    localCreateFinalLock(cfg,preparedBundleFile);
    auditV33.study = cfg.study.name;
    auditV33.protocolVersion = cfg.study.protocolVersion;
    auditV33.status = 'locked_final_audit_opened';
    auditV33.contract = contract;
    auditV33.preparedBundleFile = preparedBundleFile;
    auditV33.finalCohorts = cell(1,cfg.v33.numCohorts);
    auditV33.completedCohorts = 0;
    auditV33.integrity.preparationFinalRowsGenerated = ...
        preparedV33.integrity.finalRowsGenerated;
    auditV33.integrity.preparationFinalRowsUsed = ...
        preparedV33.integrity.finalRowsUsed;
    auditV33.integrity.finalRowsGenerated = 0;
    auditV33.integrity.finalRowsUsed = 0;
    save(cfg.runtime.finalCheckpointFile,'auditV33','-v7.3');
end

for cohortIndex = auditV33.completedCohorts+1:cfg.v33.numCohorts
    cohortCfg = buildV33CohortConfig(cfg,cohortIndex);
    if cfg.runtime.verbose
        fprintf('\nOpening V3.3 locked final cohort %d/%d.\n', ...
            cohortIndex,cfg.v33.numCohorts);
    end
    auditV33.finalCohorts{cohortIndex} = evaluateV33CohortFinal( ...
        preparedV33.cohorts{cohortIndex},cohortCfg);
    auditV33.completedCohorts = cohortIndex;
    auditV33.integrity.finalRowsGenerated = ...
        localTotalFinalRows(auditV33.finalCohorts,cohortIndex);
    auditV33.integrity.finalRowsUsed = ...
        auditV33.integrity.finalRowsGenerated;
    auditV33.status = 'locked_final_audit_in_progress';
    save(cfg.runtime.finalCheckpointFile,'auditV33','-v7.3');
    localPrintFinalCohort(auditV33.finalCohorts{cohortIndex});
end

auditV33.aggregate = summarizeV33FinalAudit( ...
    auditV33.finalCohorts,cfg);
auditV33.hypothesisSupported = ...
    auditV33.aggregate.hypothesisSupported;
auditV33.status = 'locked_robustness_final_observed';
expectedRows = cfg.v33.numCohorts*cfg.dataset.numCores* ...
    cfg.v33.finalScenarioCount*cfg.dataset.repetitions;
if auditV33.integrity.finalRowsGenerated ~= expectedRows || ...
        auditV33.integrity.finalRowsUsed ~= expectedRows || ...
        auditV33.integrity.preparationFinalRowsGenerated ~= 0 || ...
        auditV33.integrity.preparationFinalRowsUsed ~= 0
    error('TrafoDNA:V33FinalRowCountChanged', ...
        'Aggregate final/preparation row counts violate the contract.');
end

save(cfg.runtime.finalResultFile,'auditV33','-v7.3');
localAppendFinalLock(cfg,'COMPLETED');
if cfg.runtime.saveCsvFile
    writetable(auditV33.aggregate.summaryTable,fullfile( ...
        cfg.runtime.finalDirectory,'v33_final_cohort_summary.csv'));
    writetable(localAggregateChecks(auditV33.aggregate),fullfile( ...
        cfg.runtime.finalDirectory,'v33_aggregate_decision_checks.csv'));
end
localPrintFinalAudit(auditV33,cfg);
end

function localValidatePreparedBundle(prepared,contract,cfg)
required = {'status','contract','cohorts','completedCohorts','integrity'};
for k = 1:numel(required)
    if ~isfield(prepared,required{k})
        error('TrafoDNA:InvalidV33PreparedBundle', ...
            'Prepared bundle is missing field "%s".',required{k});
    end
end
if ~strcmp(prepared.status,'prepared_all_cohorts_final_sealed') || ...
        prepared.completedCohorts ~= cfg.v33.numCohorts || ...
        numel(prepared.cohorts) ~= cfg.v33.numCohorts || ...
        any(cellfun(@isempty,prepared.cohorts)) || ...
        ~isequaln(prepared.contract,contract) || ...
        prepared.integrity.finalRowsGenerated ~= 0 || ...
        prepared.integrity.finalRowsUsed ~= 0
    error('TrafoDNA:V33PreparedBundleNotSealed', ...
        'All five unchanged cohorts must be prepared with zero final rows.');
end
for cohortIndex = 1:cfg.v33.numCohorts
    cohort = prepared.cohorts{cohortIndex};
    cohortCfg = buildV33CohortConfig(cfg,cohortIndex);
    if ~strcmp(cohort.status,'cohort_prepared_final_sealed') || ...
            cohort.index ~= cohortIndex || ...
            cohort.integrity.finalRowsGenerated ~= 0 || ...
            cohort.integrity.finalRowsUsed ~= 0 || ...
            ~isequaln(cohort.cohortContract, ...
            buildV32ProtocolContract(cohortCfg))
        error('TrafoDNA:InvalidV33PreparedCohort', ...
            'Prepared cohort %d is incomplete, changed, or unsealed.', ...
            cohortIndex);
    end
end
end

function localValidateFinalCheckpoint(audit,contract,cfg)
required = {'status','contract','finalCohorts','completedCohorts', ...
    'integrity'};
for k = 1:numel(required)
    if ~isfield(audit,required{k})
        error('TrafoDNA:InvalidV33FinalCheckpoint', ...
            'Final checkpoint is missing field "%s".',required{k});
    end
end
if ~ismember(audit.status,{'locked_final_audit_opened', ...
        'locked_final_audit_in_progress'}) || ...
        ~isequaln(audit.contract,contract) || ...
        numel(audit.finalCohorts) ~= cfg.v33.numCohorts || ...
        audit.completedCohorts < 0 || ...
        audit.completedCohorts > cfg.v33.numCohorts || ...
        any(cellfun(@isempty, ...
        audit.finalCohorts(1:audit.completedCohorts))) || ...
        audit.integrity.preparationFinalRowsGenerated ~= 0 || ...
        audit.integrity.preparationFinalRowsUsed ~= 0 || ...
        audit.integrity.finalRowsGenerated ~= ...
        localTotalFinalRows(audit.finalCohorts,audit.completedCohorts) || ...
        audit.integrity.finalRowsUsed ~= audit.integrity.finalRowsGenerated
    error('TrafoDNA:InvalidV33FinalCheckpoint', ...
        'The V3.3 final checkpoint is changed or internally inconsistent.');
end
end

function total = localTotalFinalRows(finalCohorts,completed)
total = 0;
for k = 1:completed
    if isempty(finalCohorts{k}) || ...
            ~isfield(finalCohorts{k},'integrity')
        error('TrafoDNA:InvalidV33FinalCheckpoint', ...
            'A completed final cohort is missing from the checkpoint.');
    end
    total = total+finalCohorts{k}.integrity.finalRowsGenerated;
end
end

function localCreateFinalLock(cfg,preparedBundleFile)
[fileId,message] = fopen(cfg.runtime.finalLockFile,'w');
if fileId < 0
    error('TrafoDNA:V33FinalLockFailed', ...
        'Could not create the V3.3 final lock marker: %s',message);
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId,'TrafoDNA V3.3 joint robustness final opened\n');
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

function checks = localAggregateChecks(aggregate)
metric = {'Passing cohorts';'Passing-cohort rate'};
current = [aggregate.passCount;aggregate.passRate];
target = {sprintf('>= %d',aggregate.requiredPassingCohorts); ...
    sprintf('>= %.2f',aggregate.requiredPassRate)};
passed = [aggregate.countGatePassed;aggregate.rateGatePassed];
checks = table(metric,current,target,passed, ...
    'VariableNames',{'Metric','Current','Target','Passed'});
end

function localPrintFinalCohort(result)
fprintf(['Cohort %d final checkpointed: identity %.2f %%, EER %.4f, ' ...
    'PUF %.4f, worst %.4f, checks %d/10, result %s.\n'], ...
    result.index,100*result.identityMetrics.accuracy, ...
    result.identityMetrics.eer,result.pufMetrics.reliability, ...
    result.worstConditionPUFReliability,sum(result.checks.Passed), ...
    localPassText(result.cohortPassed));
end

function localPrintFinalAudit(audit,cfg)
aggregate = audit.aggregate;
fprintf('\n--- TrafoDNA V3.3 Locked Robustness Final Audit ---\n');
for k = 1:height(aggregate.summaryTable)
    row = aggregate.summaryTable(k,:);
    fprintf(['Cohort %d: checks %d/10, identity %.2f %%, ' ...
        'PUF %.4f, worst %.4f, %s\n'],row.Cohort,row.ChecksPassed, ...
        100*row.IdentityAccuracy,row.PUFReliability, ...
        row.WorstScenarioReliability,localPassText(row.CohortPassed));
end
fprintf('Passing independent cohorts             : %d/%d\n', ...
    aggregate.passCount,aggregate.totalCohorts);
fprintf('Required passing cohorts                : %d/%d\n', ...
    aggregate.requiredPassingCohorts,aggregate.totalCohorts);
fprintf('Total final rows generated / used       : %d / %d\n', ...
    audit.integrity.finalRowsGenerated,audit.integrity.finalRowsUsed);
if audit.hypothesisSupported
    decision = 'SUPPORTED';
else
    decision = 'NOT SUPPORTED';
end
fprintf('Preregistered robustness decision       : %s\n',decision);
fprintf('Locked final result                     : %s\n', ...
    cfg.runtime.finalResultFile);
fprintf(['Note: This remains numerical feasibility evidence, not physical ' ...
    'or cryptographic validation.\n']);
end

function value = localPassText(passed)
if passed
    value = 'PASS';
else
    value = 'FAIL';
end
end
