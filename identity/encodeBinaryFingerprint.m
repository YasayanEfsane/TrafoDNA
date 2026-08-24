function [bits,selectedValues,selectedThresholds] = ...
    encodeBinaryFingerprint(pufModel,features,metadata)
%ENCODEBINARYFINGERPRINT Apply a fitted PUF transform to query features.

if nargin < 3
    metadata = [];
end
if strcmp(pufModel.transformMode,'identity_embedding')
    embedding = transformIdentityFeatures(pufModel.identityModel,features,metadata);
else
    embedding = standardizeFeatures(features,pufModel.featureMean, ...
        pufModel.featureStd,pufModel.activeFeatures);
end
firstIndex = pufModel.candidateFirstIndex(pufModel.selectedBits);
secondIndex = pufModel.candidateSecondIndex(pufModel.selectedBits);
selectedValues = embedding(:,firstIndex);
paired = secondIndex > 0;
if any(paired)
    selectedValues(:,paired) = selectedValues(:,paired)- ...
        embedding(:,secondIndex(paired));
end
selectedThresholds = pufModel.thresholds(pufModel.selectedBits);
bits = selectedValues > selectedThresholds;
end
