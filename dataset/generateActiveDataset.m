function dataset = generateActiveDataset(cores,cfg)
%GENERATEACTIVEDATASET Generate complete V3 challenge-response sweeps.
%   One output row represents one full 24-challenge acquisition sweep.

coreCount = numel(cores);
scenarioCount = numel(cfg.dataset.conditions);
repeatCount = cfg.dataset.repetitions;
challengeCount = numel(cfg.active.challenges);
sampleCount = coreCount*scenarioCount*repeatCount;

sampleId = (1:sampleCount)';
coreId = zeros(sampleCount,1);
conditionId = zeros(sampleCount,1);
repeatId = zeros(sampleCount,1);
temperatureK = zeros(sampleCount,1);
noiseStdV = zeros(sampleCount,1);
sensorGain = zeros(sampleCount,1);
resetOffsetAm = zeros(sampleCount,1);
stressPa = zeros(sampleCount,1);
agingLevel = zeros(sampleCount,1);
healthState = cell(sampleCount,1);
isUnseen = false(sampleCount,1);
isFinal = false(sampleCount,1);
sessionSeed = zeros(sampleCount,1);

responseTensor = [];
responseNames = {};
positiveMask = [];
row = 0;
for coreIndex = 1:coreCount
    for scenarioIndex = 1:scenarioCount
        scenario = cfg.dataset.conditions(scenarioIndex);
        for repetition = 1:repeatCount
            row = row+1;
            for challengeIndex = 1:challengeCount
                challenge = cfg.active.challenges(challengeIndex);
                seed = cfg.rngSeed+coreIndex*1.0e7+scenarioIndex*1.0e5+ ...
                    repetition*1000+challenge.id;
                [response,currentNames,currentPositiveMask] = ...
                    simulateChallengeResponse(cores(coreIndex),scenario, ...
                    challenge,cfg,seed);
                if isempty(responseTensor)
                    responseNames = currentNames;
                    positiveMask = currentPositiveMask;
                    responseTensor = zeros(sampleCount,challengeCount,numel(response));
                elseif numel(response) ~= size(responseTensor,3) || ...
                        ~isequal(currentNames,responseNames)
                    error('TrafoDNA:ActiveResponseChanged', ...
                        'Active response dimensions changed during generation.');
                end
                responseTensor(row,challengeIndex,:) = reshape(response,1,1,[]);
            end

            coreId(row) = coreIndex;
            conditionId(row) = scenario.id;
            repeatId(row) = repetition;
            temperatureK(row) = scenario.temperatureK;
            noiseStdV(row) = cfg.sensor.baseNoiseStdV*scenario.noiseScale;
            sensorGain(row) = scenario.sensorGain;
            resetOffsetAm(row) = scenario.resetOffsetAm;
            stressPa(row) = scenario.stressPa;
            agingLevel(row) = scenario.agingLevel;
            healthState{row} = scenario.healthState;
            isUnseen(row) = scenario.isUnseen;
            isFinal(row) = scenario.isFinalHoldout;
            sessionSeed(row) = cfg.rngSeed+coreIndex*1.0e7+ ...
                scenarioIndex*1.0e5+repetition*1000;
        end
    end
    if cfg.runtime.verbose
        fprintf('Active dataset generation: completed core %d/%d.\n', ...
            coreIndex,coreCount);
    end
end

[features,featureNames,featureTransform] = ...
    buildDifferentialChallengeFeatures(responseTensor,responseNames, ...
    positiveMask,cfg);
metadata = table(sampleId,coreId,conditionId,repeatId,temperatureK, ...
    noiseStdV,sensorGain,resetOffsetAm,stressPa,agingLevel,healthState, ...
    isUnseen,isFinal,sessionSeed, ...
    'VariableNames',{'SampleId','CoreId','ConditionId','RepeatId', ...
    'TemperatureK','NoiseStdV','SensorGain','ResetOffsetAm','StressPa', ...
    'AgingLevel','HealthState','IsUnseenCondition', ...
    'IsFinalHoldoutCondition','SampleSeed'});

dataset.features = features;
dataset.featureNames = featureNames;
dataset.metadata = metadata;
dataset.responseTensor = responseTensor;
dataset.responseFeatureNames = responseNames;
dataset.responsePositiveMask = positiveMask;
dataset.featureTransform = featureTransform;
dataset.challenges = cfg.active.challenges;
end
