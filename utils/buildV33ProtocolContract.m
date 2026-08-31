function contract = buildV33ProtocolContract(cfg)
%BUILDV33PROTOCOLCONTRACT Extract the frozen V3.3 audit contract.
%   Runtime paths and display settings are intentionally omitted.

contract.studyName = cfg.study.name;
contract.protocolVersion = cfg.study.protocolVersion;
contract.studyStatus = cfg.study.status;
contract.numCohorts = cfg.v33.numCohorts;
contract.cohortSeeds = cfg.v33.cohortSeeds;
contract.knownScenarioCount = cfg.v33.knownScenarioCount;
contract.developmentScenarioCount = cfg.v33.developmentScenarioCount;
contract.finalScenarioCount = cfg.v33.finalScenarioCount;
contract.scenariosPerCohort = cfg.v33.scenariosPerCohort;
contract.scenarioHaltonStartIndices = ...
    cfg.v33.scenarioHaltonStartIndices;
contract.scenarioIdBases = cfg.v33.scenarioIdBases;
contract.requiredPassingCohorts = cfg.v33.requiredPassingCohorts;
contract.requiredPassRate = cfg.v33.requiredPassRate;
contract.evaluateEveryFinalCohort = cfg.v33.evaluateEveryFinalCohort;
contract.numCores = cfg.dataset.numCores;
contract.repetitions = cfg.dataset.repetitions;
contract.trainRepeats = cfg.dataset.trainRepeats;
contract.validationRepeats = cfg.dataset.validationRepeats;
contract.testRepeats = cfg.dataset.testRepeats;
contract.seedByConditionId = cfg.dataset.seedByConditionId;
contract.signal = cfg.signal;
contract.sensor = cfg.sensor;
contract.active = cfg.active;
contract.identity = cfg.identity;
contract.puf = cfg.puf;
contract.session = cfg.session;
contract.projection = cfg.v32.projection;
contract.targets = cfg.benchmark.v32Targets;

cohortTemplate = struct('index',0,'seed',0,'haltonIndices',[], ...
    'scenarioIds',[],'unseenConditionIds',[], ...
    'finalHoldoutConditionIds',[],'conditions',struct([]));
contract.cohorts = repmat(cohortTemplate,cfg.v33.numCohorts,1);
for k = 1:cfg.v33.numCohorts
    cohortCfg = buildV33CohortConfig(cfg,k);
    contract.cohorts(k).index = k;
    contract.cohorts(k).seed = cohortCfg.rngSeed;
    contract.cohorts(k).haltonIndices = ...
        cohortCfg.v33.currentHaltonIndices;
    contract.cohorts(k).scenarioIds = cohortCfg.v33.currentScenarioIds;
    contract.cohorts(k).unseenConditionIds = ...
        cohortCfg.dataset.unseenConditionIds;
    contract.cohorts(k).finalHoldoutConditionIds = ...
        cohortCfg.dataset.finalHoldoutConditionIds;
    contract.cohorts(k).conditions = cohortCfg.dataset.conditions;
end
end
