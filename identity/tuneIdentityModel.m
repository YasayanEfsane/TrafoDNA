function model = tuneIdentityModel(trainFeatures, trainIds, trainMetadata, ...
    validationFeatures, validationIds, validationMetadata, cfg)
%TUNEIDENTITYMODEL Select feature count and covariance shrinkage on validation.
%   No test or unseen-condition observation is used during model selection.

featureGrid = unique(cfg.identity.featureCountGrid(:)');
regularizationGrid = unique(cfg.identity.covarianceRegularizationGrid(:)');
numCandidates = numel(featureGrid) * numel(regularizationGrid);
candidateFeatureCount = zeros(numCandidates,1);
candidateRegularization = zeros(numCandidates,1);
candidateAccuracy = zeros(numCandidates,1);
candidateEER = zeros(numCandidates,1);
candidateObjective = zeros(numCandidates,1);

bestObjective = -Inf;
bestEER = Inf;
bestModel = [];
row = 0;
for featureCount = featureGrid
    for regularization = regularizationGrid
        row = row + 1;
        trialCfg = cfg;
        trialCfg.identity.maxFeatures = featureCount;
        trialCfg.identity.covarianceRegularization = regularization;
        trialModel = trainIdentityModel(trainFeatures, trainIds, trainMetadata, trialCfg);
        [prediction, confidence, distances] = predictIdentity( ...
            trialModel, validationFeatures, validationMetadata);
        metrics = computeVerificationMetrics(prediction, validationIds, ...
            confidence, distances, trialModel.coreIds);
        objective = metrics.accuracy - ...
            cfg.identity.validationEERWeight * metrics.eer;

        candidateFeatureCount(row) = numel(trialModel.selectedFeatures);
        candidateRegularization(row) = regularization;
        candidateAccuracy(row) = metrics.accuracy;
        candidateEER(row) = metrics.eer;
        candidateObjective(row) = objective;

        isBetter = objective > bestObjective + 1e-12 || ...
            (abs(objective-bestObjective) <= 1e-12 && metrics.eer < bestEER);
        if isBetter
            bestObjective = objective;
            bestEER = metrics.eer;
            bestModel = trialModel;
        end
    end
end

model = bestModel;
model.tuningResults = table(candidateFeatureCount, candidateRegularization, ...
    candidateAccuracy, candidateEER, candidateObjective, ...
    'VariableNames', {'FeatureCount','CovarianceRegularization', ...
    'ValidationAccuracy','ValidationEER','Objective'});
model.tuningObjective = bestObjective;
end
