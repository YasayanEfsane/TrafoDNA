function metrics = computeVerificationMetrics(predictedIds, trueIds, confidence, distances, enrolledIds)
%COMPUTEVERIFICATIONMETRICS Compute identification and verification metrics.

predictedIds = predictedIds(:);
trueIds = trueIds(:);
if numel(predictedIds) ~= numel(trueIds) || size(distances,1) ~= numel(trueIds)
    error('TrafoDNA:DimensionMismatch', 'Prediction, truth, and distance rows must agree.');
end

numSamples = numel(trueIds);
numClasses = numel(enrolledIds);
confusion = zeros(numClasses,numClasses);
genuine = zeros(numSamples,1);
impostor = zeros(numSamples*max(numClasses-1,1),1);
impostorIndex = 0;

for sample = 1:numSamples
    truePosition = find(enrolledIds == trueIds(sample),1);
    predictedPosition = find(enrolledIds == predictedIds(sample),1);
    if isempty(truePosition) || isempty(predictedPosition)
        error('TrafoDNA:UnknownLabel', 'Encountered an identity outside enrollment.');
    end
    confusion(truePosition,predictedPosition) = confusion(truePosition,predictedPosition)+1;
    genuine(sample) = distances(sample,truePosition);
    for candidate = 1:numClasses
        if candidate ~= truePosition
            impostorIndex = impostorIndex+1;
            impostor(impostorIndex) = distances(sample,candidate);
        end
    end
end
impostor = impostor(1:impostorIndex);
eerResult = computeEER(genuine,impostor);

metrics.accuracy = mean(predictedIds == trueIds);
metrics.confusionMatrix = confusion;
metrics.coreIds = enrolledIds;
metrics.genuineDistances = genuine;
metrics.impostorDistances = impostor;
metrics.meanConfidence = mean(confidence);
metrics.confidence = confidence;
metrics.far = eerResult.far;
metrics.frr = eerResult.frr;
metrics.trueAcceptRate = eerResult.trueAcceptRate;
metrics.falseAcceptRate = eerResult.falseAcceptRate;
metrics.thresholds = eerResult.thresholds;
metrics.eer = eerResult.eer;
metrics.eerThreshold = eerResult.eerThreshold;
metrics.eerIndex = eerResult.eerIndex;
end
