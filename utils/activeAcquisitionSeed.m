function seed = activeAcquisitionSeed(cfg,coreIndex,scenario, ...
    scenarioIndex,repetition,challengeId)
%ACTIVEACQUISITIONSEED Build one deterministic active-acquisition seed.
%   Legacy V3 uses the scenario position. V3.2 uses the stable condition ID
%   so separately generated final scenarios cannot reuse development noise.

scenarioKey = scenarioIndex;
if isfield(cfg.dataset,'seedByConditionId') && ...
        logical(cfg.dataset.seedByConditionId)
    scenarioKey = scenario.id;
end
seed = double(cfg.rngSeed)+double(coreIndex)*1.0e7 + ...
    double(scenarioKey)*1.0e5+double(repetition)*1000 + ...
    double(challengeId);
end
