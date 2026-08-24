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
    dataset.metadata.CoreId(splits.train),cfg);
assert(~identityModel.svmAvailable,'Fallback test unexpectedly trained an SVM.');
[prediction,confidence,distances] = predictIdentity(identityModel, ...
    dataset.features(splits.test,:));
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
    dataset.metadata.CoreId(splits.train),cfg);
pufMetrics = evaluatePUF(pufModel,dataset.features(splits.test,:), ...
    dataset.metadata.CoreId(splits.test));
assert(pufMetrics.reliability >= 0 && pufMetrics.reliability <= 1, ...
    'PUF reliability is outside [0,1].');
assert(pufMetrics.uniqueness >= 0 && pufMetrics.uniqueness <= 1, ...
    'PUF uniqueness is outside [0,1].');
assert(pufMetrics.numSelectedBits >= 1,'No fingerprint bits were selected.');
[testNames,passed] = localRecord(testNames,passed,'puf_metrics');

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
