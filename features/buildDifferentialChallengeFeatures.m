function [features,featureNames,transform] = ...
    buildDifferentialChallengeFeatures(responseTensor,responseNames, ...
    positiveMask,cfg)
%BUILDDIFFERENTIALCHALLENGEFEATURES Reference-normalize active responses.
%   Positive response coordinates use log ratios. Signed circular
%   coordinates use differences. Absolute reference coordinates are kept.

if ndims(responseTensor) ~= 3
    error('TrafoDNA:ActiveResponseDimensions', ...
        'Active responses must be samples-by-challenges-by-features.');
end
[sampleCount,challengeCount,responseCount] = size(responseTensor);
if challengeCount ~= numel(cfg.active.challenges) || ...
        responseCount ~= numel(responseNames) || ...
        responseCount ~= numel(positiveMask)
    error('TrafoDNA:ActiveResponseDimensions', ...
        'Response tensor, challenge set, and feature definitions disagree.');
end

transformed = responseTensor;
for feature = 1:responseCount
    if positiveMask(feature)
        transformed(:,:,feature) = log(max(responseTensor(:,:,feature),eps));
    end
end

challengeIds = [cfg.active.challenges.id];
referencePosition = find(challengeIds == cfg.active.referenceChallengeId,1);
if isempty(referencePosition)
    error('TrafoDNA:ActiveReferenceChallenge', ...
        'Configured reference challenge is absent from the response tensor.');
end

outputCount = responseCount*challengeCount;
features = zeros(sampleCount,outputCount);
featureNames = cell(1,outputCount);
column = 0;
for feature = 1:responseCount
    column = column+1;
    features(:,column) = transformed(:,referencePosition,feature);
    featureNames{column} = sprintf('Ref_%s',responseNames{feature});
end
for challenge = 1:challengeCount
    if challenge == referencePosition
        continue;
    end
    challengeId = cfg.active.challenges(challenge).id;
    for feature = 1:responseCount
        column = column+1;
        features(:,column) = transformed(:,challenge,feature) - ...
            transformed(:,referencePosition,feature);
        featureNames{column} = sprintf('C%02d_%s_delta', ...
            challengeId,responseNames{feature});
    end
end
if column ~= outputCount
    error('TrafoDNA:ActiveFeatureCount', ...
        'Differential challenge feature count is inconsistent.');
end
features(~isfinite(features)) = 0;

transform.referenceChallengeId = cfg.active.referenceChallengeId;
transform.referencePosition = referencePosition;
transform.responseNames = responseNames;
transform.positiveMask = logical(positiveMask);
transform.mode = 'absolute_reference_plus_challenge_deltas';
end
