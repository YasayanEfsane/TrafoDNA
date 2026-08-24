function [model, healthCoordinates] = separateIdentityAndHealth(features, coreIds, healthLabels, cfg)
%SEPARATEIDENTITYANDHEALTH Fit an identity-residual health representation.
%   The standardized centroid of each core is removed before PCA. Therefore,
%   the retained coordinates emphasize within-core condition changes instead
%   of manufacturing identity differences.

if size(features,1) ~= numel(coreIds) || size(features,1) ~= numel(healthLabels)
    error('TrafoDNA:DimensionMismatch', ...
        'Features, core labels, and health labels must have equal rows.');
end

[normalized, mu, sigma, active] = standardizeFeatures(features);
coreLabels = unique(coreIds(:))';
coreCentroids = zeros(numel(coreLabels),size(normalized,2));
residuals = zeros(size(normalized));
for k = 1:numel(coreLabels)
    selected = coreIds == coreLabels(k);
    coreCentroids(k,:) = mean(normalized(selected,:),1);
    residuals(selected,:) = normalized(selected,:) - coreCentroids(k,:);
end

% Supervised training-only filtering prevents high-variance identity noise
% from dominating the unsupervised PCA health coordinates.
classes = unique(healthLabels(:),'stable')';
globalResidualMean = mean(residuals,1);
betweenScatter = zeros(1,size(residuals,2));
withinScatter = zeros(1,size(residuals,2));
for k = 1:numel(classes)
    selected = strcmp(healthLabels,classes{k});
    classRows = residuals(selected,:);
    classMean = mean(classRows,1);
    betweenScatter = betweenScatter + sum(selected)*(classMean-globalResidualMean).^2;
    withinScatter = withinScatter + sum((classRows-classMean).^2,1);
end
healthFisherScore = (betweenScatter/max(numel(classes)-1,1)) ./ ...
    max(withinScatter/max(size(residuals,1)-numel(classes),1),eps);
healthFisherScore(~isfinite(healthFisherScore)) = 0;
[~,ranking] = sort(healthFisherScore,'descend');
selectedCount = min(max(1,cfg.health.maxFeatures),numel(ranking));
selectedFeatures = ranking(1:selectedCount);
selectedResiduals = residuals(:,selectedFeatures);

residualMean = mean(selectedResiduals,1);
centeredResiduals = selectedResiduals - residualMean;
[~, singularValues, rightVectors] = svd(centeredResiduals, 'econ');
variance = diag(singularValues).^2;
if isempty(variance) || sum(variance) <= eps
    componentCount = 1;
else
    cumulative = cumsum(variance)/sum(variance);
    componentCount = find(cumulative >= cfg.health.varianceToKeep,1);
end
componentCount = max(1,min([componentCount,cfg.health.maxComponents,size(rightVectors,2)]));
basis = rightVectors(:,1:componentCount);
healthCoordinates = centeredResiduals*basis;

healthCentroids = zeros(numel(classes),componentCount);
for k = 1:numel(classes)
    selected = strcmp(healthLabels,classes{k});
    healthCentroids(k,:) = mean(healthCoordinates(selected,:),1);
end

within = zeros(size(healthCoordinates));
for k = 1:numel(classes)
    selected = strcmp(healthLabels,classes{k});
    within(selected,:) = healthCoordinates(selected,:) - healthCentroids(k,:);
end
healthCovariance = (within'*within)/max(size(within,1)-numel(classes),1);
averageVariance = trace(healthCovariance)/max(size(healthCovariance,1),1);
healthCovariance = 0.90*healthCovariance + ...
    0.10*max(averageVariance,eps)*eye(size(healthCovariance));

model.featureMean = mu;
model.featureStd = sigma;
model.activeFeatures = active;
model.coreIds = coreLabels;
model.coreCentroids = coreCentroids;
model.selectedFeatures = selectedFeatures;
model.healthFisherScore = healthFisherScore;
model.residualMean = residualMean;
model.basis = basis;
model.healthClasses = classes;
model.healthCentroids = healthCentroids;
model.inverseCovariance = pinv(healthCovariance);
end
