function results = runAllTests()
%RUNALLTESTS Execute deterministic, leakage, metric, and fallback tests.
%   RESULTS = RUNALLTESTS() raises an assertion error on failure and returns
%   a table-like structure describing passed checks.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));
cfg = localSmallConfig(defaultConfig());
testNames = {};
passed = [];

fprintf('TrafoDNA tests are running...\n');

% 1. Deterministic signal generation.
core1 = createVirtualCore(1,cfg);
condition = cfg.dataset.conditions(1);
excitation = generateExcitation(condition,cfg);
simulationA = simulateBarkhausen(core1,condition,excitation,cfg,123456);
simulationB = simulateBarkhausen(core1,condition,excitation,cfg,123456);
assert(isequal(simulationA.signalV,simulationB.signalV), ...
    'The same seed did not reproduce the same signal.');
[testNames,passed] = localRecord(testNames,passed,'seed_reproducibility');

% 2. Different virtual cores must have different fixed parameters.
core2 = createVirtualCore(2,cfg);
parameterDifference = abs(core1.coercivityAm-core2.coercivityAm) + ...
    norm(core1.fingerprintCoefficients-core2.fingerprintCoefficients);
assert(parameterDifference > 1e-9,'Different cores received identical parameters.');
[testNames,passed] = localRecord(testNames,passed,'different_core_parameters');

% 3. Signal and feature finiteness/dimensions.
assert(all(isfinite(simulationA.signalV)),'Signal contains NaN or Inf.');
[featureRow,featureNames] = extractFeatures(simulationA.signalV,excitation,cfg);
assert(isrow(featureRow) && numel(featureRow) == numel(featureNames), ...
    'Feature names and values have inconsistent dimensions.');
assert(all(isfinite(featureRow)),'Feature vector contains NaN or Inf.');
[testNames,passed] = localRecord(testNames,passed,'finite_signal_and_features');

% 4. Miniature streamed dataset and partition leakage.
cores = repmat(core1,cfg.dataset.numCores,1);
for k = 1:cfg.dataset.numCores
    cores(k) = createVirtualCore(k,cfg);
end
dataset = generateDataset(cores,cfg);
splits = splitDataset(dataset.metadata,cfg);
membership = double(splits.train)+double(splits.validation)+ ...
    double(splits.test)+double(splits.unseen);
assert(all(membership <= 1),'Dataset leakage was detected.');
assert(isempty(intersect(dataset.metadata.SampleId(splits.train), ...
    dataset.metadata.SampleId(splits.test))),'Train/test sample overlap detected.');
[testNames,passed] = localRecord(testNames,passed,'partition_leakage');

% 5. Toolbox-free identity path and verification metrics.
identityModel = trainIdentityModel(dataset.features(splits.train,:), ...
    dataset.metadata.CoreId(splits.train),dataset.metadata(splits.train,:),cfg);
assert(~identityModel.svmAvailable,'Fallback test unexpectedly trained an SVM.');
[prediction,confidence,distances] = predictIdentity(identityModel, ...
    dataset.features(splits.test,:),dataset.metadata(splits.test,:));
metrics = computeVerificationMetrics(prediction,dataset.metadata.CoreId(splits.test), ...
    confidence,distances,identityModel.coreIds);
assert(all(metrics.far >= 0 & metrics.far <= 1),'FAR is outside [0,1].');
assert(all(metrics.frr >= 0 & metrics.frr <= 1),'FRR is outside [0,1].');
assert(median(metrics.genuineDistances) < median(metrics.impostorDistances), ...
    'Median intra-core distance is not below median inter-core distance.');
[testNames,passed] = localRecord(testNames,passed,'identity_fallback_and_distances');

% 6. EER on cleanly separated synthetic verification scores.
eerResult = computeEER([0.05;0.10;0.15;0.20],[0.70;0.80;0.90;1.00]);
assert(eerResult.eer <= 0.05,'EER calculation failed on separated scores.');
[testNames,passed] = localRecord(testNames,passed,'eer_synthetic_scores');

% 7. PUF path and bounded metrics.
pufModel = generateBinaryFingerprint(dataset.features(splits.train,:), ...
    dataset.metadata.CoreId(splits.train),cfg,identityModel, ...
    dataset.metadata(splits.train,:));
pufMetrics = evaluatePUF(pufModel,dataset.features(splits.test,:), ...
    dataset.metadata.CoreId(splits.test),dataset.metadata(splits.test,:));
assert(pufMetrics.reliability >= 0 && pufMetrics.reliability <= 1, ...
    'PUF reliability is outside [0,1].');
assert(pufMetrics.uniqueness >= 0 && pufMetrics.uniqueness <= 1, ...
    'PUF uniqueness is outside [0,1].');
assert(pufMetrics.numSelectedBits >= cfg.puf.minimumSelectedBits, ...
    'The configured minimum number of fingerprint bits was not selected.');
[testNames,passed] = localRecord(testNames,passed,'puf_metrics');

% 8. Fitted identity transform must be finite, dimensionally stable, and use
% only the explicitly configured measurable nuisance variables.
identityEmbedding = transformIdentityFeatures(identityModel, ...
    dataset.features(splits.test,:),dataset.metadata(splits.test,:));
assert(size(identityEmbedding,1) == sum(splits.test), ...
    'Identity transform changed the sample count.');
assert(size(identityEmbedding,2) == numel(identityModel.selectedFeatures), ...
    'Identity transform changed the selected feature count.');
assert(all(isfinite(identityEmbedding(:))), ...
    'Identity embedding contains NaN or Inf.');
assert(~any(strcmp(identityModel.conditionNormalizer.variableNames,'StressPa')) && ...
    ~any(strcmp(identityModel.conditionNormalizer.variableNames,'AgingLevel')), ...
    'Health variables leaked into the identity nuisance transform.');
[testNames,passed] = localRecord(testNames,passed,'condition_transform_contract');

% 9. Synthetic extrapolation test for a removable operating-condition shift.
[syntheticTrain,syntheticTrainIds,syntheticTrainMetadata, ...
    syntheticTest,syntheticTestIds,syntheticTestMetadata] = ...
    localSyntheticConditionData();
syntheticCfg = cfg;
syntheticCfg.identity.maxFeatures = size(syntheticTrain,2);
syntheticCfg.identity.nuisanceRidge = 0;
syntheticCfg.identity.covarianceRegularization = 0.50;
syntheticModel = trainIdentityModel(syntheticTrain,syntheticTrainIds, ...
    syntheticTrainMetadata,syntheticCfg);
syntheticPrediction = predictIdentity(syntheticModel,syntheticTest, ...
    syntheticTestMetadata);
assert(mean(syntheticPrediction == syntheticTestIds) >= 0.95, ...
    'Condition residualization failed the synthetic unseen-shift test.');
[testNames,passed] = localRecord(testNames,passed, ...
    'synthetic_unseen_condition_robustness');

results.names = testNames(:);
results.passed = logical(passed(:));
fprintf('All %d TrafoDNA tests passed.\n',numel(testNames));
end

function cfg = localSmallConfig(cfg)
cfg.dataset.numCores = 4;
cfg.dataset.numConditions = 5;
cfg.dataset.repetitions = 4;
cfg.dataset.trainRepeats = 1:2;
cfg.dataset.validationRepeats = 3;
cfg.dataset.testRepeats = 4;
cfg.dataset.unseenConditionIds = 5;
cfg.dataset.rawExamplesPerCore = 1;
cfg.dataset.conditions = cfg.dataset.conditions(1:5);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
end
cfg.signal.sampleRateHz = 2.5e4;
cfg.signal.cycles = 1;
cfg.sensor.highCutHz = 1.0e4;
cfg.identity.useSVMWhenAvailable = false;
cfg.runtime.verbose = false;
cfg.runtime.createFigures = false;
cfg.runtime.saveMatFile = false;
cfg.runtime.saveCsvFile = false;
end

function [names,passed] = localRecord(names,passed,name)
names{end+1} = name;
passed(end+1) = true;
fprintf('  PASS: %s\n',name);
end

function [trainFeatures,trainIds,trainMetadata,testFeatures,testIds,testMetadata] = ...
    localSyntheticConditionData()
templates = [ ...
    -1.5 -0.8  0.4  1.0 -0.6  0.2; ...
    -0.5  0.8 -1.0  0.3  1.1 -0.4; ...
     0.7 -1.1  0.9 -0.5  0.2  1.2; ...
     1.5  0.4 -0.2 -1.0 -0.8 -1.1];
conditionDirection = [1.2 -0.9 0.8 1.1 -0.7 0.6];
trainConditions = [-1 0 1];
testCondition = 2.2;
repetitions = 3;

trainCount = size(templates,1)*numel(trainConditions)*repetitions;
trainFeatures = zeros(trainCount,size(templates,2));
trainIds = zeros(trainCount,1);
trainConditionValue = zeros(trainCount,1);
row = 0;
for core = 1:size(templates,1)
    for condition = trainConditions
        for repetition = 1:repetitions
            row = row+1;
            deterministicNoise = 0.005*sin((1:size(templates,2))*(row+repetition));
            trainFeatures(row,:) = templates(core,:) + ...
                condition*conditionDirection + deterministicNoise;
            trainIds(row) = core;
            trainConditionValue(row) = condition;
        end
    end
end

testCount = size(templates,1)*repetitions;
testFeatures = zeros(testCount,size(templates,2));
testIds = zeros(testCount,1);
testConditionValue = testCondition*ones(testCount,1);
row = 0;
for core = 1:size(templates,1)
    for repetition = 1:repetitions
        row = row+1;
        deterministicNoise = 0.005*cos((1:size(templates,2))*(row+repetition));
        testFeatures(row,:) = templates(core,:) + ...
            testCondition*conditionDirection + deterministicNoise;
        testIds(row) = core;
    end
end

trainMetadata = localSyntheticMetadata(trainConditionValue);
testMetadata = localSyntheticMetadata(testConditionValue);
end

function metadata = localSyntheticMetadata(conditionValue)
count = numel(conditionValue);
TemperatureK = 293.15 + 10*conditionValue;
ExcitationAmplitudeAm = 120*ones(count,1);
ExcitationFrequencyHz = 50*ones(count,1);
NoiseStdV = 2e-5*ones(count,1);
SensorGain = ones(count,1);
metadata = table(TemperatureK,ExcitationAmplitudeAm,ExcitationFrequencyHz, ...
    NoiseStdV,SensorGain);
end
