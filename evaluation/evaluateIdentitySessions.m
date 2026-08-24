function [predictedIds,metrics,distances,sessions] = ...
    evaluateIdentitySessions(model,features,metadata,readsPerDecision)
%EVALUATEIDENTITYSESSIONS Evaluate median-feature multi-read decisions.
%   Single-read metrics are computed elsewhere and remain unchanged.

if size(features,1) ~= height(metadata)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature and session-metadata rows must agree.');
end
sessions = buildAcquisitionSessions(metadata,readsPerDecision);
aggregatedFeatures = zeros(sessions.numSessions,size(features,2));
for k = 1:sessions.numSessions
    aggregatedFeatures(k,:) = median(features(sessions.rows{k},:),1);
end
sessionMetadata = metadata(sessions.firstRows,:);
[predictedIds,confidence,distances] = predictIdentity(model, ...
    aggregatedFeatures,sessionMetadata);
metrics = computeVerificationMetrics(predictedIds,sessions.coreIds, ...
    confidence,distances,model.coreIds);
metrics.readsPerDecision = readsPerDecision;
metrics.numSessions = sessions.numSessions;
metrics.droppedMeasurements = sessions.droppedMeasurements;
metrics.aggregation = 'feature_median';
end
