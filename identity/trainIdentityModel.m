function model = trainIdentityModel(features, coreIds, cfg)
%TRAINIDENTITYMODEL Fit toolbox-free centroid identity models.
%   MODEL stores a fitted standardization transform, per-core centroids, a
%   regularized inverse covariance, and an optional ECOC-SVM when available.

if size(features,1) ~= numel(coreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature rows and identity labels must have equal counts.');
end
[normalized, mu, sigma, active] = standardizeFeatures(features);
labels = unique(coreIds(:))';
centroids = zeros(numel(labels), size(normalized,2));
for k = 1:numel(labels)
    centroids(k,:) = mean(normalized(coreIds == labels(k),:), 1);
end

centeredWithinClass = zeros(size(normalized));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    centeredWithinClass(selected,:) = normalized(selected,:) - centroids(k,:);
end
if size(centeredWithinClass,1) > 1
    covarianceMatrix = (centeredWithinClass' * centeredWithinClass) / ...
        max(size(centeredWithinClass,1)-numel(labels), 1);
else
    covarianceMatrix = eye(size(centeredWithinClass,2));
end
regularizer = cfg.identity.covarianceRegularization;
averageVariance = trace(covarianceMatrix) / max(size(covarianceMatrix,1),1);
covarianceMatrix = (1-regularizer)*covarianceMatrix + ...
    regularizer*max(averageVariance, eps)*eye(size(covarianceMatrix));

model.method = lower(cfg.identity.method);
model.featureMean = mu;
model.featureStd = sigma;
model.activeFeatures = active;
model.coreIds = labels;
model.centroids = centroids;
model.inverseCovariance = pinv(covarianceMatrix);
model.optionalSVM = [];
model.svmAvailable = false;

if cfg.identity.useSVMWhenAvailable && exist('fitcecoc','file') == 2
    try
        model.optionalSVM = fitcecoc(normalized, coreIds(:));
        model.svmAvailable = true;
    catch svmError
        warning('TrafoDNA:SVMFallback', ...
            'SVM training failed; centroid model retained: %s', svmError.message);
    end
end
end
