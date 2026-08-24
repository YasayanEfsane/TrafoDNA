function metrics = evaluatePUF(pufModel,features,coreIds,metadata)
%EVALUATEPUF Evaluate single-read PUF reliability and separation metrics.

if nargin < 4
    metadata = [];
end
bits = encodeBinaryFingerprint(pufModel,features,metadata);
metrics = computePUFMetrics(bits,coreIds,pufModel);
metrics.meanEnrollmentReliability = mean(pufModel.enrollmentReliability(:));
metrics.meanValidationReliability = mean(pufModel.validationReliability(:));
metrics.meanWorstConditionReliability = mean(pufModel.worstConditionReliability);
metrics.readsPerDecision = 1;
metrics.numSessions = size(features,1);
metrics.droppedMeasurements = 0;
metrics.aggregation = 'none';
end
