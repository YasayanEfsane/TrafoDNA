function [predictedLabels, metrics, distances, healthCoordinates] = evaluateHealthState(model, features, coreIds, trueLabels)
%EVALUATEHEALTHSTATE Predict health after subtracting enrolled core identity.
%   COREIDS may be true or previously predicted identities. Unknown identities
%   are rejected because no identity centroid exists for residualization.

normalized = standardizeFeatures(features, model.featureMean, ...
    model.featureStd, model.activeFeatures);
residuals = zeros(size(normalized));
for sample = 1:size(normalized,1)
    corePosition = find(model.coreIds == coreIds(sample),1);
    if isempty(corePosition)
        error('TrafoDNA:UnknownCore', 'Health analysis requires an enrolled core identity.');
    end
    residuals(sample,:) = normalized(sample,:) - model.coreCentroids(corePosition,:);
end
selectedResiduals = residuals(:,model.selectedFeatures);
healthCoordinates = (selectedResiduals-model.residualMean)*model.basis;

numClasses = numel(model.healthClasses);
distances = zeros(size(features,1),numClasses);
for k = 1:numClasses
    delta = healthCoordinates-model.healthCentroids(k,:);
    distances(:,k) = sqrt(max(sum((delta*model.inverseCovariance).*delta,2),0));
end
[~,position] = min(distances,[],2);
predictedLabels = model.healthClasses(position)';
predictedLabels = predictedLabels(:);

metrics = struct();
if nargin >= 4 && ~isempty(trueLabels)
    trueLabels = trueLabels(:);
    metrics.accuracy = mean(strcmp(predictedLabels,trueLabels));
    confusion = zeros(numClasses,numClasses);
    for sample = 1:numel(trueLabels)
        actual = find(strcmp(model.healthClasses,trueLabels{sample}),1);
        predicted = position(sample);
        if ~isempty(actual)
            confusion(actual,predicted) = confusion(actual,predicted)+1;
        end
    end
    metrics.confusionMatrix = confusion;
else
    metrics.accuracy = NaN;
    metrics.confusionMatrix = [];
end
metrics.healthClasses = model.healthClasses;
metrics.distances = distances;

healthyPosition = find(strcmp(model.healthClasses,'healthy'),1);
if isempty(healthyPosition)
    metrics.healthIndex = min(distances,[],2);
else
    metrics.healthIndex = distances(:,healthyPosition);
end
end
