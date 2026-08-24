function dataset = generateDataset(cores, cfg)
%GENERATEDATASET Stream simulated signals into a compact feature dataset.
%   DATASET = GENERATEDATASET(CORES, CFG) avoids retaining every raw signal;
%   only configured examples are stored for visualization and audit.

numCores = numel(cores);
numConditions = cfg.dataset.numConditions;
numRepetitions = cfg.dataset.repetitions;
numSamples = numCores * numConditions * numRepetitions;

sampleId = zeros(numSamples,1);
coreIdColumn = zeros(numSamples,1);
conditionIdColumn = zeros(numSamples,1);
repeatIdColumn = zeros(numSamples,1);
temperatureK = zeros(numSamples,1);
excitationAmplitudeAm = zeros(numSamples,1);
excitationFrequencyHz = zeros(numSamples,1);
noiseStdV = zeros(numSamples,1);
sensorGain = zeros(numSamples,1);
stressPa = zeros(numSamples,1);
agingLevel = zeros(numSamples,1);
healthState = cell(numSamples,1);
isUnseenCondition = false(numSamples,1);
isFinalHoldoutCondition = false(numSamples,1);
sampleSeed = zeros(numSamples,1);

rawTemplate = struct('coreId',0,'conditionId',0,'repeatId',0,'t',[], ...
    'H',[],'signalV',[],'cleanSignalV',[],'eventMask',[],'eventPhaseRad',[], ...
    'sampleRateHz',0,'temperatureK',0,'noiseStdV',0,'agingLevel',0, ...
    'healthState','');
maximumRaw = numCores * cfg.dataset.rawExamplesPerCore;
rawExamples = repmat(rawTemplate, maximumRaw, 1);
rawCount = 0;
features = [];
featureNames = {};

index = 0;
for coreIndex = 1:numCores
    for conditionIndex = 1:numConditions
        condition = cfg.dataset.conditions(conditionIndex);
        excitation = generateExcitation(condition, cfg);
        for repetition = 1:numRepetitions
            index = index + 1;
            seed = cfg.rngSeed + coreIndex*1000000 + conditionIndex*1000 + repetition;
            simulation = simulateBarkhausen(cores(coreIndex), condition, ...
                excitation, cfg, seed);
            [row, currentFeatureNames] = extractFeatures(simulation.signalV, excitation, cfg);
            if index == 1
                featureNames = currentFeatureNames;
                features = zeros(numSamples, numel(row));
            elseif numel(row) ~= size(features,2)
                error('TrafoDNA:FeatureDimensionChanged', ...
                    'Feature dimension changed while generating the dataset.');
            end
            features(index,:) = row;

            sampleId(index) = index;
            coreIdColumn(index) = coreIndex;
            conditionIdColumn(index) = conditionIndex;
            repeatIdColumn(index) = repetition;
            temperatureK(index) = condition.temperatureK;
            excitationAmplitudeAm(index) = excitation.amplitudeAm;
            excitationFrequencyHz(index) = excitation.frequencyHz;
            noiseStdV(index) = cfg.sensor.baseNoiseStdV * condition.noiseScale;
            sensorGain(index) = condition.sensorGain;
            stressPa(index) = condition.stressPa;
            agingLevel(index) = condition.agingLevel;
            healthState{index} = condition.healthState;
            isUnseenCondition(index) = condition.isUnseen;
            isFinalHoldoutCondition(index) = condition.isFinalHoldout;
            sampleSeed(index) = seed;

            if conditionIndex == 1 && repetition <= cfg.dataset.rawExamplesPerCore
                rawCount = rawCount + 1;
                rawExamples(rawCount).coreId = coreIndex;
                rawExamples(rawCount).conditionId = conditionIndex;
                rawExamples(rawCount).repeatId = repetition;
                rawExamples(rawCount).t = excitation.t;
                rawExamples(rawCount).H = excitation.H;
                rawExamples(rawCount).signalV = simulation.signalV;
                rawExamples(rawCount).cleanSignalV = simulation.cleanSignalV;
                rawExamples(rawCount).eventMask = simulation.eventMask;
                rawExamples(rawCount).eventPhaseRad = simulation.eventPhaseRad;
                rawExamples(rawCount).sampleRateHz = excitation.sampleRateHz;
                rawExamples(rawCount).temperatureK = condition.temperatureK;
                rawExamples(rawCount).noiseStdV = noiseStdV(index);
                rawExamples(rawCount).agingLevel = condition.agingLevel;
                rawExamples(rawCount).healthState = condition.healthState;
            end
        end
    end
    if cfg.runtime.verbose
        fprintf('Dataset generation: completed core %d/%d.\n', coreIndex, numCores);
    end
end

metadata = table(sampleId, coreIdColumn, conditionIdColumn, repeatIdColumn, ...
    temperatureK, excitationAmplitudeAm, excitationFrequencyHz, noiseStdV, ...
    sensorGain, stressPa, agingLevel, healthState, isUnseenCondition, ...
    isFinalHoldoutCondition, sampleSeed, ...
    'VariableNames', {'SampleId','CoreId','ConditionId','RepeatId','TemperatureK', ...
    'ExcitationAmplitudeAm','ExcitationFrequencyHz','NoiseStdV','SensorGain', ...
    'StressPa','AgingLevel','HealthState','IsUnseenCondition', ...
    'IsFinalHoldoutCondition','SampleSeed'});

dataset.features = features;
dataset.featureNames = featureNames;
dataset.metadata = metadata;
dataset.rawExamples = rawExamples(1:rawCount);
end
