function [predictedIds, confidence, distances] = predictIdentity(model, features, metadata)
%PREDICTIDENTITY Predict core identity and return verification distances.
%   Lower DISTANCES indicate greater similarity. CONFIDENCE is the relative
%   separation between the two nearest identities and lies in [0,1].

if nargin < 3
    metadata = [];
end
identityFeatures = transformIdentityFeatures(model, features, metadata);
numSamples = size(identityFeatures,1);
numCores = numel(model.coreIds);
distances = zeros(numSamples, numCores);

for coreIndex = 1:numCores
    delta = identityFeatures - model.centroids(coreIndex,:);
    switch lower(model.method)
        case 'mahalanobis'
            distances(:,coreIndex) = sqrt(max(sum((delta*model.inverseCovariance).*delta,2),0));
        case {'euclidean','normalized_euclidean'}
            distances(:,coreIndex) = sqrt(sum(delta.^2,2));
        otherwise
            error('TrafoDNA:UnknownIdentityMethod', ...
                'Unknown identity method "%s".', model.method);
    end
end

[sortedDistances, order] = sort(distances, 2, 'ascend');
predictedIds = model.coreIds(order(:,1))';
predictedIds = predictedIds(:);
if numCores > 1
    confidence = 1 - sortedDistances(:,1) ./ max(sortedDistances(:,2), eps);
else
    confidence = ones(numSamples,1);
end
confidence = min(max(confidence,0),1);

% The optional SVM is deliberately not used for distance-based verification;
% callers may inspect model.optionalSVM for a secondary experiment.
end
