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
    fprintf('TrafoDNA baslatiliyor: %d nuve, %d kosul, %d tekrar.\n', ...
        cfg.dataset.numCores, cfg.dataset.numConditions, cfg.dataset.repetitions);
    fprintf('MATLAB surumu: %s\n', version);
end

cores = repmat(createVirtualCore(1, cfg), cfg.dataset.numCores, 1);
for coreId = 1:cfg.dataset.numCores
    cores(coreId) = createVirtualCore(coreId, cfg);
end

dataset = generateDataset(cores, cfg);
splits = splitDataset(dataset.metadata, cfg);

identityModel = trainIdentityModel(dataset.features(splits.train, :), ...
    dataset.metadata.CoreId(splits.train), cfg);
[validationPrediction, validationConfidence, validationDistances] = ...
    predictIdentity(identityModel, dataset.features(splits.validation, :));
validationMetrics = computeVerificationMetrics(validationPrediction, ...
    dataset.metadata.CoreId(splits.validation), validationConfidence, ...
    validationDistances, identityModel.coreIds);
[testPrediction, testConfidence, testDistances] = predictIdentity(identityModel, ...
    dataset.features(splits.test, :));
testMetrics = computeVerificationMetrics(testPrediction, ...
    dataset.metadata.CoreId(splits.test), testConfidence, testDistances, ...
    identityModel.coreIds);

[unseenPrediction, unseenConfidence, unseenDistances] = predictIdentity(identityModel, ...
    dataset.features(splits.unseen, :));
unseenMetrics = computeVerificationMetrics(unseenPrediction, ...
    dataset.metadata.CoreId(splits.unseen), unseenConfidence, unseenDistances, ...
    identityModel.coreIds);
testMetrics = localApplyCalibratedThreshold(testMetrics,validationMetrics.eerThreshold);
unseenMetrics = localApplyCalibratedThreshold(unseenMetrics,validationMetrics.eerThreshold);

pufModel = generateBinaryFingerprint(dataset.features(splits.train, :), ...
    dataset.metadata.CoreId(splits.train), cfg);
pufMetrics = evaluatePUF(pufModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen));

[healthModel, trainHealthCoordinates] = separateIdentityAndHealth( ...
    dataset.features(splits.train, :), dataset.metadata.CoreId(splits.train), ...
    dataset.metadata.HealthState(splits.train), cfg);
[healthPrediction, healthMetrics, healthDistances, testHealthCoordinates] = ...
    evaluateHealthState(healthModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen), ...
    dataset.metadata.HealthState(splits.test | splits.unseen));

healthEvaluationMask = splits.test | splits.unseen;
[identityPredictionByHealth,~,~] = predictIdentity(identityModel, ...
    dataset.features(healthEvaluationMask,:));
identityAccuracyByHealth = localAccuracyByHealth( ...
    dataset.metadata.HealthState(healthEvaluationMask), identityPredictionByHealth, ...
    dataset.metadata.CoreId(healthEvaluationMask));

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
end

localPrintSummary(testMetrics, unseenMetrics, pufMetrics, healthMetrics);
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

function localPrintSummary(testMetrics, unseenMetrics, pufMetrics, healthMetrics)
fprintf('\n--- TrafoDNA Sonuc Ozeti ---\n');
fprintf('Bilinen kosul kimlik dogrulugu : %.2f %%\n', 100*testMetrics.accuracy);
fprintf('Gorulmeyen kosul dogrulugu     : %.2f %%\n', 100*unseenMetrics.accuracy);
fprintf('Dogrulama EER                  : %.4f\n', unseenMetrics.eer);
fprintf('PUF guvenilirligi              : %.4f\n', pufMetrics.reliability);
fprintf('PUF benzersizligi              : %.4f\n', pufMetrics.uniqueness);
fprintf('Secilen kararlı bit            : %d\n', pufMetrics.numSelectedBits);
fprintf('Saglik siniflandirma dogrulugu : %.2f %%\n', 100*healthMetrics.accuracy);
fprintf('Sonuclar: %s\n', fileparts(mfilename('fullpath')));
fprintf('Not: Sonuclar sayisal fizibilitedir; deneysel dogrulama degildir.\n');
end
