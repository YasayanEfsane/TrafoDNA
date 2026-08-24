function [worstReliability,conditionTable] = ...
    computeWorstConditionPUFReliability(pufModel,features,coreIds,metadata)
%COMPUTEWORSTCONDITIONPUFRELIABILITY Return raw reliability by condition.

if ~istable(metadata) || height(metadata) ~= size(features,1) || ...
        ~any(strcmp(metadata.Properties.VariableNames,'ConditionId'))
    error('TrafoDNA:ConditionMetadataRequired', ...
        'Condition-level PUF reliability requires matching metadata.');
end
coreIds = coreIds(:);
[bits,~,~] = encodeBinaryFingerprint(pufModel,features,metadata);
agreement = false(size(bits));
for row = 1:size(bits,1)
    corePosition = find(pufModel.coreIds == coreIds(row),1);
    if isempty(corePosition)
        error('TrafoDNA:UnknownCore','PUF query core was not enrolled.');
    end
    agreement(row,:) = bits(row,:) == pufModel.referenceBits(corePosition,:);
end

conditionIds = unique(metadata.ConditionId,'stable');
reliability = zeros(numel(conditionIds),1);
sampleCount = zeros(numel(conditionIds),1);
for k = 1:numel(conditionIds)
    selected = metadata.ConditionId == conditionIds(k);
    reliability(k) = mean(agreement(selected,:),'all');
    sampleCount(k) = sum(selected);
end
worstReliability = min(reliability);
conditionTable = table(conditionIds,reliability,sampleCount, ...
    'VariableNames',{'ConditionId','Reliability','SampleCount'});
end
