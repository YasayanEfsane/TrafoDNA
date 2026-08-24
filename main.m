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
hasFinalHoldout = isfield(splits,'finalHoldout') && any(splits.finalHoldout);

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

finalEvaluation.available = hasFinalHoldout;
finalEvaluation.identityPrediction = [];
finalEvaluation.identityMetrics = [];
if hasFinalHoldout
    [finalPrediction,finalConfidence,finalDistances] = predictIdentity( ...
        identityModel,dataset.features(splits.finalHoldout,:), ...
        dataset.metadata(splits.finalHoldout,:));
    finalMetrics = computeVerificationMetrics(finalPrediction, ...
        dataset.metadata.CoreId(splits.finalHoldout),finalConfidence, ...
        finalDistances,identityModel.coreIds);
    finalMetrics = localApplyCalibratedThreshold(finalMetrics, ...
        validationMetrics.eerThreshold);
    finalEvaluation.identityPrediction = finalPrediction;
    finalEvaluation.identityMetrics = finalMetrics;
end

pufModel = generateBinaryFingerprint(dataset.features(splits.train, :), ...
    dataset.metadata.CoreId(splits.train), cfg, identityModel, ...
    dataset.metadata(splits.train,:),dataset.features(splits.validation,:), ...
    dataset.metadata.CoreId(splits.validation), ...
    dataset.metadata(splits.validation,:));
pufMetrics = evaluatePUF(pufModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen), ...
    dataset.metadata(splits.test | splits.unseen,:));
if hasFinalHoldout
    finalEvaluation.pufMetrics = evaluatePUF(pufModel, ...
        dataset.features(splits.finalHoldout,:), ...
        dataset.metadata.CoreId(splits.finalHoldout), ...
        dataset.metadata(splits.finalHoldout,:));
else
    finalEvaluation.pufMetrics = [];
end

[healthModel, trainHealthCoordinates] = separateIdentityAndHealth( ...
    dataset.features(splits.train, :), dataset.metadata.CoreId(splits.train), ...
    dataset.metadata.HealthState(splits.train), cfg);
[healthPrediction, healthMetrics, healthDistances, testHealthCoordinates] = ...
    evaluateHealthState(healthModel, dataset.features(splits.test | splits.unseen, :), ...
    dataset.metadata.CoreId(splits.test | splits.unseen), ...
    dataset.metadata.HealthState(splits.test | splits.unseen));
if hasFinalHoldout
    [finalHealthPrediction,finalHealthMetrics,finalHealthDistances, ...
        finalHealthCoordinates] = evaluateHealthState(healthModel, ...
        dataset.features(splits.finalHoldout,:), ...
        dataset.metadata.CoreId(splits.finalHoldout), ...
        dataset.metadata.HealthState(splits.finalHoldout));
    finalEvaluation.healthPrediction = finalHealthPrediction;
    finalEvaluation.healthMetrics = finalHealthMetrics;
    finalEvaluation.healthDistances = finalHealthDistances;
    finalEvaluation.healthCoordinates = finalHealthCoordinates;
else
    finalEvaluation.healthPrediction = [];
    finalEvaluation.healthMetrics = [];
    finalEvaluation.healthDistances = [];
    finalEvaluation.healthCoordinates = [];
end

% Multi-read sessions supplement rather than replace every single-read metric.
readsPerDecision = cfg.session.readsPerDecision;
sessionResults.available = localSupportsSessions( ...
    dataset.metadata(splits.validation,:),readsPerDecision) && ...
    localSupportsSessions(dataset.metadata(splits.test,:),readsPerDecision) && ...
    localSupportsSessions(dataset.metadata(splits.unseen,:),readsPerDecision);
if sessionResults.available
    [~,sessionResults.validationIdentityMetrics] = evaluateIdentitySessions( ...
        identityModel,dataset.features(splits.validation,:), ...
        dataset.metadata(splits.validation,:),readsPerDecision);
    [~,sessionResults.knownIdentityMetrics] = evaluateIdentitySessions( ...
        identityModel,dataset.features(splits.test,:), ...
        dataset.metadata(splits.test,:),readsPerDecision);
    [~,sessionResults.unseenIdentityMetrics] = evaluateIdentitySessions( ...
        identityModel,dataset.features(splits.unseen,:), ...
        dataset.metadata(splits.unseen,:),readsPerDecision);
    sessionThreshold = sessionResults.validationIdentityMetrics.eerThreshold;
    sessionResults.knownIdentityMetrics = localApplyCalibratedThreshold( ...
        sessionResults.knownIdentityMetrics,sessionThreshold);
    sessionResults.unseenIdentityMetrics = localApplyCalibratedThreshold( ...
        sessionResults.unseenIdentityMetrics,sessionThreshold);
    [sessionResults.pufMetrics,sessionResults.pufSessions] = evaluatePUFSessions( ...
        pufModel,dataset.features(splits.test | splits.unseen,:), ...
        dataset.metadata(splits.test | splits.unseen,:),readsPerDecision);
else
    sessionThreshold = NaN;
    sessionResults.validationIdentityMetrics = [];
    sessionResults.knownIdentityMetrics = [];
    sessionResults.unseenIdentityMetrics = [];
    sessionResults.pufMetrics = [];
    sessionResults.pufSessions = [];
end
finalEvaluation.sessionAvailable = hasFinalHoldout && sessionResults.available && ...
    localSupportsSessions(dataset.metadata(splits.finalHoldout,:),readsPerDecision);
if finalEvaluation.sessionAvailable
    [~,finalEvaluation.sessionIdentityMetrics] = evaluateIdentitySessions( ...
        identityModel,dataset.features(splits.finalHoldout,:), ...
        dataset.metadata(splits.finalHoldout,:),readsPerDecision);
    finalEvaluation.sessionIdentityMetrics = localApplyCalibratedThreshold( ...
        finalEvaluation.sessionIdentityMetrics,sessionThreshold);
    [finalEvaluation.sessionPUFMetrics,finalEvaluation.pufSessions] = ...
        evaluatePUFSessions(pufModel,dataset.features(splits.finalHoldout,:), ...
        dataset.metadata(splits.finalHoldout,:),readsPerDecision);
    finalEvaluation.checks = evaluateFinalHoldoutChecks( ...
        finalEvaluation.identityMetrics,finalEvaluation.pufMetrics, ...
        finalEvaluation.healthMetrics,finalEvaluation.sessionIdentityMetrics, ...
        finalEvaluation.sessionPUFMetrics,cfg);
else
    finalEvaluation.sessionIdentityMetrics = [];
    finalEvaluation.sessionPUFMetrics = [];
    finalEvaluation.pufSessions = [];
    finalEvaluation.checks = table();
end

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
analysisResults.sessionResults = sessionResults;
analysisResults.finalEvaluation = finalEvaluation;
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
    if hasFinalHoldout
        writetable(finalEvaluation.checks,fullfile(cfg.runtime.resultsDirectory, ...
            'final_holdout_checks.csv'));
    end
end

localPrintSummary(validationMetrics, testMetrics, unseenMetrics, pufMetrics, ...
    healthMetrics, benchmark, identityModel, sessionResults,finalEvaluation,cfg);
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
    pufMetrics, healthMetrics, benchmark, identityModel,sessionResults, ...
    finalEvaluation,cfg)
fprintf('\n--- TrafoDNA Result Summary ---\n');
fprintf('Known-condition identity accuracy : %.2f %%\n', 100*testMetrics.accuracy);
fprintf('Development-holdout identity accuracy: %.2f %%\n', ...
    100*unseenMetrics.accuracy);
fprintf('Validation EER                    : %.4f\n', validationMetrics.eer);
fprintf('Development-holdout EER           : %.4f\n', unseenMetrics.eer);
fprintf('PUF reliability                   : %.4f\n', pufMetrics.reliability);
fprintf('PUF validation reliability        : %.4f\n', ...
    pufMetrics.meanValidationReliability);
fprintf('PUF worst-condition reliability   : %.4f\n', ...
    pufMetrics.meanWorstConditionReliability);
fprintf('PUF uniqueness                    : %.4f\n', pufMetrics.uniqueness);
fprintf('Selected stable bits              : %d\n', pufMetrics.numSelectedBits);
fprintf('Health classification accuracy    : %.2f %%\n', 100*healthMetrics.accuracy);
if sessionResults.available
    fprintf('Three-read development accuracy    : %.2f %%\n', ...
        100*sessionResults.unseenIdentityMetrics.accuracy);
    fprintf('Three-read development EER         : %.4f\n', ...
        sessionResults.unseenIdentityMetrics.eer);
    fprintf('Three-read PUF reliability         : %.4f\n', ...
        sessionResults.pufMetrics.reliability);
end
fprintf('Selected identity features        : %d\n', numel(identityModel.selectedFeatures));
fprintf('Removed nuisance components       : %d\n', identityModel.nuisanceComponents);
fprintf('Identity tuning strategy          : %s\n', identityModel.tuningStrategy);
fprintf('Covariance regularization         : %.2f\n', ...
    identityModel.covarianceRegularization);
fprintf('V2 acceptance checks passed       : %d/%d\n', ...
    sum(benchmark.Passed), height(benchmark));
if finalEvaluation.available
    fprintf('\n--- Preregistered Final Holdout ---\n');
    fprintf('Single-read identity accuracy      : %.2f %%\n', ...
        100*finalEvaluation.identityMetrics.accuracy);
    fprintf('Single-read identity EER           : %.4f\n', ...
        finalEvaluation.identityMetrics.eer);
    fprintf('Single-read PUF reliability        : %.4f\n', ...
        finalEvaluation.pufMetrics.reliability);
    fprintf('Health classification accuracy     : %.2f %%\n', ...
        100*finalEvaluation.healthMetrics.accuracy);
    if finalEvaluation.sessionAvailable
        fprintf('Three-read identity accuracy       : %.2f %%\n', ...
            100*finalEvaluation.sessionIdentityMetrics.accuracy);
        fprintf('Three-read identity EER            : %.4f\n', ...
            finalEvaluation.sessionIdentityMetrics.eer);
        fprintf('Three-read PUF reliability         : %.4f\n', ...
            finalEvaluation.sessionPUFMetrics.reliability);
        fprintf('Final-holdout checks passed        : %d/%d\n', ...
            sum(finalEvaluation.checks.Passed),height(finalEvaluation.checks));
    end
end
fprintf('Results directory                 : %s\n', cfg.runtime.resultsDirectory);
fprintf('Note: Results are numerical feasibility evidence, not experimental validation.\n');
end

function supported = localSupportsSessions(metadata,readsPerDecision)
if isempty(metadata) || height(metadata) < readsPerDecision
    supported = false;
    return;
end
pairs = [metadata.CoreId metadata.ConditionId];
[~,~,group] = unique(pairs,'rows');
counts = accumarray(group,1);
supported = ~isempty(counts) && all(counts >= readsPerDecision);
end
