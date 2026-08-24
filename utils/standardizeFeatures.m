function [normalized, mu, sigma, active] = standardizeFeatures(features, mu, sigma, active)
%STANDARDIZEFEATURES Standardize columns with an optional fitted transform.
%   [Z,MU,SIGMA,ACTIVE] = STANDARDIZEFEATURES(X) fits the transform.
%   Z = STANDARDIZEFEATURES(X,MU,SIGMA,ACTIVE) applies a fitted transform.

if nargin < 2 || isempty(mu)
    mu = mean(features, 1);
    sigma = std(features, 0, 1);
    active = sigma > 1e-12 & all(isfinite(features), 1);
    if ~any(active)
        error('TrafoDNA:NoUsableFeatures', 'No variable feature columns were found.');
    end
    sigma(~active) = 1;
elseif nargin < 4
    active = true(1, size(features,2));
end

if size(features,2) ~= numel(mu)
    error('TrafoDNA:FeatureDimensionMismatch', ...
        'Input feature count does not match fitted standardization.');
end
normalized = (features(:,active) - mu(active)) ./ sigma(active);
normalized(~isfinite(normalized)) = 0;
end
