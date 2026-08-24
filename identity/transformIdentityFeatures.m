function embedding = transformIdentityFeatures(model, features, metadata)
%TRANSFORMIDENTITYFEATURES Apply the complete fitted identity transform.
%   The transform consists of training-only standardization, optional
%   operating-condition residualization, and Fisher-ranked feature selection.

if nargin < 3
    metadata = [];
end
normalized = standardizeFeatures(features, model.featureMean, ...
    model.featureStd, model.activeFeatures);
residualized = applyOperatingConditionNormalizer( ...
    model.conditionNormalizer, normalized, metadata);
embedding = residualized(:, model.selectedFeatures);
embedding(~isfinite(embedding)) = 0;
end
