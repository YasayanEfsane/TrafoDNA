function [metrics,sessions] = evaluatePUFSessions(pufModel,features,metadata, ...
    readsPerDecision)
%EVALUATEPUFSESSIONS Evaluate median-response multi-read PUF decisions.

if size(features,1) ~= height(metadata)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature and session-metadata rows must agree.');
end
[~,selectedValues,thresholds] = encodeBinaryFingerprint( ...
    pufModel,features,metadata);
sessions = buildAcquisitionSessions(metadata,readsPerDecision);
sessionValues = zeros(sessions.numSessions,size(selectedValues,2));
for k = 1:sessions.numSessions
    sessionValues(k,:) = median(selectedValues(sessions.rows{k},:),1);
end
sessionBits = sessionValues > thresholds;
metrics = computePUFMetrics(sessionBits,sessions.coreIds,pufModel);
metrics.readsPerDecision = readsPerDecision;
metrics.numSessions = sessions.numSessions;
metrics.droppedMeasurements = sessions.droppedMeasurements;
metrics.aggregation = 'response_median';
end
