function model = trainIdentityModel(features, coreIds, metadata, cfg)
%TRAINIDENTITYMODEL Fit a condition-robust, toolbox-free identity model.
%   MODEL stores training-only standardization, an optional measurable-
%   condition residualizer, Fisher-ranked features, core centroids, and a
%   regularized within-core covariance. The legacy three-input form
%   TRAINIDENTITYMODEL(FEATURES, COREIDS, CFG) remains supported.

if nargin == 3
    cfg = metadata;
    metadata = [];
elseif nargin ~= 4
    error('TrafoDNA:InvalidInputCount', ...
        'Expected features, core IDs, optional metadata, and configuration.');
end
coreIds = coreIds(:);
if size(features,1) ~= numel(coreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature rows and identity labels must have equal counts.');
end

[normalized, mu, sigma, active] = standardizeFeatures(features);
[residualized, conditionNormalizer] = ...
    fitOperatingConditionNormalizer(normalized, metadata, cfg);
labels = unique(coreIds(:))';

% Rank dimensions using training-only between-core to within-core variance.
globalMean = mean(residualized, 1);
betweenScatter = zeros(1, size(residualized,2));
withinScatter = zeros(1, size(residualized,2));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    classRows = residualized(selected,:);
    classMean = mean(classRows,1);
    betweenScatter = betweenScatter + sum(selected) * (classMean-globalMean).^2;
    withinScatter = withinScatter + sum((classRows-classMean).^2,1);
end
betweenVariance = betweenScatter / max(numel(labels)-1, 1);
withinVariance = withinScatter / max(size(residualized,1)-numel(labels), 1);
fisherScore = betweenVariance ./ max(withinVariance, eps);
fisherScore(~isfinite(fisherScore)) = 0;
[~, ranking] = sort(fisherScore, 'descend');
if isfield(cfg.identity, 'maxFeatures')
    selectedCount = min(max(1, round(cfg.identity.maxFeatures)), numel(ranking));
else
    selectedCount = numel(ranking);
end
selectedFeatures = ranking(1:selectedCount);
identityFeatures = residualized(:,selectedFeatures);

centroids = zeros(numel(labels), size(identityFeatures,2));
centeredWithinClass = zeros(size(identityFeatures));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    centroids(k,:) = mean(identityFeatures(selected,:), 1);
    centeredWithinClass(selected,:) = identityFeatures(selected,:) - centroids(k,:);
end
if size(centeredWithinClass,1) > 1
    covarianceMatrix = (centeredWithinClass' * centeredWithinClass) / ...
        max(size(centeredWithinClass,1)-numel(labels), 1);
else
    covarianceMatrix = eye(size(centeredWithinClass,2));
end
regularizer = min(max(cfg.identity.covarianceRegularization,0),1);
averageVariance = trace(covarianceMatrix) / max(size(covarianceMatrix,1),1);
covarianceMatrix = (1-regularizer)*covarianceMatrix + ...
    regularizer*max(averageVariance, eps)*eye(size(covarianceMatrix));

model.method = lower(cfg.identity.method);
model.featureMean = mu;
model.featureStd = sigma;
model.activeFeatures = active;
model.conditionNormalizer = conditionNormalizer;
model.fisherScore = fisherScore;
model.selectedFeatures = selectedFeatures;
model.coreIds = labels;
model.centroids = centroids;
model.inverseCovariance = pinv(covarianceMatrix);
model.covarianceRegularization = regularizer;
model.optionalSVM = [];
model.svmAvailable = false;

if cfg.identity.useSVMWhenAvailable && exist('fitcecoc','file') == 2
    try
        model.optionalSVM = fitcecoc(identityFeatures, coreIds);
        model.svmAvailable = true;
    catch svmError
        warning('TrafoDNA:SVMFallback', ...
            'SVM training failed; centroid model retained: %s', svmError.message);
    end
end
end
