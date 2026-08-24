function analysisResults = main(cfg)
%MAIN Run the complete TrafoDNA simulation and analysis workflow.
%   RESULTS = MAIN() uses DEFAULTCONFIG. RESULTS = MAIN(CFG) accepts a
%   modified configuration, which is useful for quick studies.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
if nargin < 1 || isempty(cfg)
    cfg = defaultConfig();
end
localEnsureDirectories(cfg);
rng(cfg.rngSeed, 'twister');

if cfg.runtime.verbose
    fprintf('Starting TrafoDNA: %d cores, %d conditions, %d repetitions.\n', ...
        cfg.dataset.numCores, cfg.dataset.numConditions, cfg.dataset.repetitions);
    fprintf('MATLAB version: %s\n', version);
end

cores = repmat(createVirtualCore(1, cfg), cfg.dataset.numCores, 1);
for coreId = 1:cfg.dataset.numCores
    cores(coreId) = createVirtualCore(coreId, cfg);
end

dataset = generateDataset(cores, cfg);
splits = splitDataset(dataset.metadata, cfg);

identityModel = tuneIdentityModel(dataset.features(splits.train, :), ...
    dataset.metadata.CoreId(splits.train), dataset.metadata(splits.train,:), ...
    dataset.features(splits.validation, :), ...
    dataset.metadata.CoreId(splits.validation), ...
    dataset.metadata(splits.validation,:), cfg);
[validationPrediction, validationConfidence, validationDistances] = ...
    predictIdentity(identityModel, dataset.features(splits.validation, :), ...
    dataset.metadata(splits.validation,:));
validationMetrics = computeVerificationMetrics(validationPrediction, ...
    dataset.metadata.CoreId(splits.validation), validationConfidence, ...
    validationDistances, identityModel.coreIds);
[testPrediction, testConfidence, testDistances] = predictIdentity(identityModel, ...
    dataset.features(splits.test, :), dataset.metadata(splits.test,:));
testMetrics = computeVerificationMetrics(testPrediction, ...
    dataset.metadata.CoreId(splits.test), testConfidence, testDistances, ...
    identityModel.coreIds);

[unseenPrediction, unseenConfidence, unseenDistances] = predictIdentity(identityModel, ...
    dataset.features(splits.unseen, :), dataset.metadata(splits.unseen,:));
unseenMetrics = computeVerificationMetrics(unseenPrediction, ...
    dataset.metadata.CoreId(splits.unseen), unseenConfidence, unseenDistances, ...
    identityModel.coreIds);
testMetrics = localApplyCalibratedThreshold(testMetrics,validationMetrics.eerThreshold);
unseenMetrics = localApplyCalibratedThreshold(unseenMetrics,validationMetrics.eerThreshold);

pufModel = generateBinaryFingerprint(dataset.features(splits.train, :), ...
    dataset.metadata.CoreId(splits.train), cfg, identityModel, ...
    dataset.metadata(splits.train,:),dataset.features(splits.validation,:), ...
    dataset.metadata.CoreId(splits.validation), ...
    dataset.metadata(splits.validation,:));
pufMetrics = evaluatePUF(pufModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen), ...
    dataset.metadata(splits.test | splits.unseen,:));

[healthModel, trainHealthCoordinates] = separateIdentityAndHealth( ...
    dataset.features(splits.train, :), dataset.metadata.CoreId(splits.train), ...
    dataset.metadata.HealthState(splits.train), cfg);
[healthPrediction, healthMetrics, healthDistances, testHealthCoordinates] = ...
    evaluateHealthState(healthModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen), ...
    dataset.metadata.HealthState(splits.test | splits.unseen));

healthEvaluationMask = splits.test | splits.unseen;
[identityPredictionByHealth,~,~] = predictIdentity(identityModel, ...
    dataset.features(healthEvaluationMask,:), dataset.metadata(healthEvaluationMask,:));
identityAccuracyByHealth = localAccuracyByHealth( ...
    dataset.metadata.HealthState(healthEvaluationMask), identityPredictionByHealth, ...
    dataset.metadata.CoreId(healthEvaluationMask));
benchmark = compareAgainstBaseline(testMetrics, unseenMetrics, pufMetrics, ...
    healthMetrics, cfg);

analysisResults.cfg = cfg;
analysisResults.cores = cores;
analysisResults.featureNames = dataset.featureNames;
analysisResults.metadata = dataset.metadata;
analysisResults.features = dataset.features;
analysisResults.splits = splits;
analysisResults.identityModel = identityModel;
analysisResults.validationMetrics = validationMetrics;
analysisResults.testMetrics = testMetrics;
analysisResults.unseenMetrics = unseenMetrics;
analysisResults.pufModel = pufModel;
analysisResults.pufMetrics = pufMetrics;
analysisResults.healthModel = healthModel;
analysisResults.healthMetrics = healthMetrics;
analysisResults.testPrediction = testPrediction;
analysisResults.validationPrediction = validationPrediction;
analysisResults.unseenPrediction = unseenPrediction;
analysisResults.healthPrediction = healthPrediction;
analysisResults.healthDistances = healthDistances;
analysisResults.identityAccuracyByHealth = identityAccuracyByHealth;
analysisResults.benchmark = benchmark;
analysisResults.trainHealthCoordinates = trainHealthCoordinates;
analysisResults.testHealthCoordinates = testHealthCoordinates;
analysisResults.rawExamples = dataset.rawExamples;

if cfg.runtime.createFigures
    createAllFigures(dataset, splits, identityModel, testMetrics, unseenMetrics, ...
        pufModel, pufMetrics, healthModel, analysisResults, cfg);
end

if cfg.runtime.saveMatFile
    save(fullfile(cfg.runtime.resultsDirectory, 'trafodna_results.mat'), ...
        'analysisResults', '-v7.3');
end
if cfg.runtime.saveCsvFile
    featureTable = array2table(dataset.features, 'VariableNames', dataset.featureNames);
    outputTable = [dataset.metadata featureTable];
    writetable(outputTable, fullfile(cfg.runtime.resultsDirectory, 'trafodna_features.csv'));
    writetable(identityAccuracyByHealth, fullfile(cfg.runtime.resultsDirectory, ...
        'identity_accuracy_by_health.csv'));
    writetable(benchmark, fullfile(cfg.runtime.resultsDirectory, ...
        'benchmark_comparison.csv'));
end

localPrintSummary(validationMetrics, testMetrics, unseenMetrics, pufMetrics, ...
    healthMetrics, benchmark, identityModel, cfg);
end

function resultTable = localAccuracyByHealth(healthLabels,predictedIds,trueIds)
classes = unique(healthLabels(:),'stable');
accuracy = zeros(numel(classes),1);
sampleCount = zeros(numel(classes),1);
for k = 1:numel(classes)
    selected = strcmp(healthLabels,classes{k});
    sampleCount(k) = sum(selected);
    accuracy(k) = mean(predictedIds(selected) == trueIds(selected));
end
resultTable = table(classes,accuracy,sampleCount, ...
    'VariableNames',{'HealthState','IdentityAccuracy','SampleCount'});
end

function metrics = localApplyCalibratedThreshold(metrics,threshold)
metrics.calibratedThreshold = threshold;
metrics.calibratedFAR = mean(metrics.impostorDistances <= threshold);
metrics.calibratedFRR = mean(metrics.genuineDistances > threshold);
end

function localEnsureDirectories(cfg)
if ~exist(cfg.runtime.resultsDirectory, 'dir')
    mkdir(cfg.runtime.resultsDirectory);
end
if ~exist(cfg.runtime.figureDirectory, 'dir')
    mkdir(cfg.runtime.figureDirectory);
end
end

function localPrintSummary(validationMetrics, testMetrics, unseenMetrics, ...
    pufMetrics, healthMetrics, benchmark, identityModel, cfg)
fprintf('\n--- TrafoDNA Result Summary ---\n');
fprintf('Known-condition identity accuracy : %.2f %%\n', 100*testMetrics.accuracy);
fprintf('Unseen-condition identity accuracy: %.2f %%\n', 100*unseenMetrics.accuracy);
fprintf('Validation EER                    : %.4f\n', validationMetrics.eer);
fprintf('Unseen-condition EER              : %.4f\n', unseenMetrics.eer);
fprintf('PUF reliability                   : %.4f\n', pufMetrics.reliability);
fprintf('PUF validation reliability        : %.4f\n', ...
    pufMetrics.meanValidationReliability);
fprintf('PUF worst-condition reliability   : %.4f\n', ...
    pufMetrics.meanWorstConditionReliability);
fprintf('PUF uniqueness                    : %.4f\n', pufMetrics.uniqueness);
fprintf('Selected stable bits              : %d\n', pufMetrics.numSelectedBits);
fprintf('Health classification accuracy    : %.2f %%\n', 100*healthMetrics.accuracy);
fprintf('Selected identity features        : %d\n', numel(identityModel.selectedFeatures));
fprintf('Removed nuisance components       : %d\n', identityModel.nuisanceComponents);
fprintf('Identity tuning strategy          : %s\n', identityModel.tuningStrategy);
fprintf('Covariance regularization         : %.2f\n', ...
    identityModel.covarianceRegularization);
fprintf('V2 acceptance checks passed       : %d/%d\n', ...
    sum(benchmark.Passed), height(benchmark));
fprintf('Results directory                 : %s\n', cfg.runtime.resultsDirectory);
fprintf('Note: Results are numerical feasibility evidence, not experimental validation.\n');
end
