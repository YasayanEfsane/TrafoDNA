function contract = buildV32ProtocolContract(cfg)
%BUILDV32PROTOCOLCONTRACT Extract every result-relevant frozen V3.2 field.
%   Paths and display flags are intentionally omitted so a prepared bundle
%   can be moved without changing the scientific contract.

contract.studyName = cfg.study.name;
contract.protocolVersion = cfg.study.protocolVersion;
contract.studyStatus = cfg.study.status;
contract.rngSeed = cfg.rngSeed;
contract.numCores = cfg.dataset.numCores;
contract.repetitions = cfg.dataset.repetitions;
contract.trainRepeats = cfg.dataset.trainRepeats;
contract.validationRepeats = cfg.dataset.validationRepeats;
contract.testRepeats = cfg.dataset.testRepeats;
contract.unseenConditionIds = cfg.dataset.unseenConditionIds;
contract.finalHoldoutConditionIds = cfg.dataset.finalHoldoutConditionIds;
contract.seedByConditionId = cfg.dataset.seedByConditionId;
contract.conditions = cfg.dataset.conditions;
contract.signal = cfg.signal;
contract.sensor = cfg.sensor;
contract.active = cfg.active;
contract.identity = cfg.identity;
contract.puf = cfg.puf;
contract.session = cfg.session;
contract.projection = cfg.v32.projection;
contract.targets = cfg.benchmark.v32Targets;
end
