function cfg = defaultV33Config()
%DEFAULTV33CONFIG Return the sealed V3.3 robustness-audit protocol.
%   Five new virtual populations and five disjoint Halton scenario blocks
%   test the frozen V3.2 method without using V3.2 final rows for tuning.

cfg = defaultV32Config();
cfg.study.name = 'TrafoDNA V3.3 Independent Robustness Audit';
cfg.study.protocolVersion = '3.3.0-preregistered';
cfg.study.status = 'preregistered_joint_robustness_final_sealed';

cfg.v33.numCohorts = 5;
cfg.v33.cohortSeeds = 20260901:20260905;
cfg.v33.knownScenarioCount = 8;
cfg.v33.developmentScenarioCount = 6;
cfg.v33.finalScenarioCount = 4;
cfg.v33.scenariosPerCohort = 18;
cfg.v33.scenarioHaltonStartIndices = 59+18*(0:4);
cfg.v33.scenarioIdBases = 300:100:700;
cfg.v33.requiredPassingCohorts = 4;
cfg.v33.requiredPassRate = 0.80;
cfg.v33.evaluateEveryFinalCohort = true;
% The audit-opening token is a local workflow secret, not a scientific
% parameter. It is intentionally absent from the public source contract.
cfg.v33.finalConfirmationToken = getenv('TRAFODNA_V33_FINAL_TOKEN');

% Master dataset fields describe the common acquisition contract. Cohort-
% specific conditions, IDs, and acquisition seeds are built mechanically.
cfg.rngSeed = cfg.v33.cohortSeeds(1);
cfg.dataset.conditions = struct([]);
cfg.dataset.numConditions = cfg.v33.scenariosPerCohort;
cfg.dataset.unseenConditionIds = zeros(1,0);
cfg.dataset.finalHoldoutConditionIds = zeros(1,0);
cfg.dataset.seedByConditionId = true;

cfg.runtime.resultsDirectory = fullfile(cfg.projectRoot, ...
    'results_v33_robustness');
cfg.runtime.developmentDirectory = fullfile(cfg.runtime.resultsDirectory, ...
    'development');
cfg.runtime.finalDirectory = fullfile(cfg.runtime.resultsDirectory,'final');
cfg.runtime.cohortDirectory = fullfile(cfg.runtime.resultsDirectory,'cohorts');
cfg.runtime.preparedBundleFile = fullfile(cfg.runtime.resultsDirectory, ...
    'v33_prepared_bundle.mat');
cfg.runtime.finalCheckpointFile = fullfile(cfg.runtime.finalDirectory, ...
    'v33_final_checkpoint.mat');
cfg.runtime.finalResultFile = fullfile(cfg.runtime.finalDirectory, ...
    'v33_robustness_final_result.mat');
cfg.runtime.finalLockFile = fullfile(cfg.runtime.finalDirectory, ...
    'V33_FINAL_AUDIT_OPENED.lock');
end
