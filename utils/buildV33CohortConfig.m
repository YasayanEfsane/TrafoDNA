function cohortCfg = buildV33CohortConfig(cfg,cohortIndex)
%BUILDV33COHORTCONFIG Materialize one preregistered V3.3 cohort.

validateattributes(cohortIndex,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
if cohortIndex > cfg.v33.numCohorts
    error('TrafoDNA:InvalidV33Cohort', ...
        'Cohort index exceeds the V3.3 contract.');
end
if numel(cfg.v33.cohortSeeds) ~= cfg.v33.numCohorts || ...
        numel(cfg.v33.scenarioHaltonStartIndices) ~= cfg.v33.numCohorts || ...
        numel(cfg.v33.scenarioIdBases) ~= cfg.v33.numCohorts
    error('TrafoDNA:InvalidV33CohortDesign', ...
        'V3.3 seed, Halton, and ID arrays must match the cohort count.');
end
totalCount = cfg.v33.knownScenarioCount + ...
    cfg.v33.developmentScenarioCount + cfg.v33.finalScenarioCount;
if totalCount ~= cfg.v33.scenariosPerCohort
    error('TrafoDNA:InvalidV33ScenarioCount', ...
        'Known, development, and final counts do not match the total.');
end

cohortCfg = cfg;
cohortCfg.rngSeed = cfg.v33.cohortSeeds(cohortIndex);
startIndex = cfg.v33.scenarioHaltonStartIndices(cohortIndex);
haltonIndices = startIndex+(0:totalCount-1);
idBase = cfg.v33.scenarioIdBases(cohortIndex);
developmentPositions = cfg.v33.knownScenarioCount + ...
    (1:cfg.v33.developmentScenarioCount);
finalPositions = cfg.v33.knownScenarioCount + ...
    cfg.v33.developmentScenarioCount+(1:cfg.v33.finalScenarioCount);
cohortCfg.dataset.conditions = localBuildScenarios(haltonIndices,idBase, ...
    developmentPositions,finalPositions);
cohortCfg.dataset.numConditions = totalCount;
cohortCfg.dataset.unseenConditionIds = ...
    idBase+developmentPositions;
cohortCfg.dataset.finalHoldoutConditionIds = idBase+finalPositions;
cohortCfg.dataset.seedByConditionId = true;
cohortCfg.v33.currentCohort = cohortIndex;
cohortCfg.v33.currentHaltonIndices = haltonIndices;
cohortCfg.v33.currentScenarioIds = idBase+(1:totalCount);

cohortName = sprintf('cohort_%02d',cohortIndex);
cohortCfg.runtime.resultsDirectory = fullfile( ...
    cfg.runtime.cohortDirectory,cohortName);
cohortCfg.runtime.developmentDirectory = fullfile( ...
    cohortCfg.runtime.resultsDirectory,'development');
cohortCfg.runtime.finalDirectory = fullfile( ...
    cohortCfg.runtime.resultsDirectory,'final');
cohortCfg.runtime.figureDirectory = fullfile( ...
    cohortCfg.runtime.resultsDirectory,'figures');
cohortCfg.runtime.createFigures = false;
cohortCfg.runtime.saveMatFile = false;
cohortCfg.runtime.saveCsvFile = false;
end

function scenarios = localBuildScenarios(haltonIndices,idBase, ...
    developmentPositions,finalPositions)
haltonBases = [2 3 5 7 11 13];
unitDesign = zeros(numel(haltonIndices),numel(haltonBases));
for row = 1:size(unitDesign,1)
    for column = 1:size(unitDesign,2)
        unitDesign(row,column) = localRadicalInverse( ...
            haltonIndices(row),haltonBases(column));
    end
end

template = struct('id',0,'temperatureK',293.15,'noiseScale',1, ...
    'sensorGain',1,'resetOffsetAm',0,'stressPa',0,'agingLevel',0, ...
    'healthState','healthy','isUnseen',false,'isFinalHoldout',false);
scenarios = repmat(template,size(unitDesign,1),1);
for k = 1:numel(scenarios)
    scenarios(k).id = idBase+k;
    scenarios(k).temperatureK = 283.15+80*unitDesign(k,1);
    scenarios(k).noiseScale = 0.75+1.75*unitDesign(k,2);
    scenarios(k).sensorGain = 0.94+0.12*unitDesign(k,3);
    scenarios(k).resetOffsetAm = -6+12*unitDesign(k,4);
    scenarios(k).stressPa = -4.5e6+9.0e6*unitDesign(k,5);
    scenarios(k).agingLevel = 0.85*unitDesign(k,6);
    scenarios(k).healthState = localHealthState( ...
        scenarios(k).stressPa,scenarios(k).agingLevel);
    scenarios(k).isUnseen = ismember(k,developmentPositions);
    scenarios(k).isFinalHoldout = ismember(k,finalPositions);
end
end

function value = localRadicalInverse(index,base)
value = 0;
fraction = 1/base;
while index > 0
    digit = mod(index,base);
    value = value+digit*fraction;
    index = floor(index/base);
    fraction = fraction/base;
end
end

function state = localHealthState(stressPa,agingLevel)
hasStress = abs(stressPa) >= 1.0e6;
hasAging = agingLevel >= 0.10;
if ~hasStress && ~hasAging
    state = 'healthy';
elseif hasStress && ~hasAging
    state = 'mechanical_stress';
elseif ~hasStress && hasAging
    state = 'thermal_aging';
else
    state = 'combined';
end
end
