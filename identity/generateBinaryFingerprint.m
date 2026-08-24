function pufModel = generateBinaryFingerprint(features, coreIds, cfg, ...
    identityModel, metadata, validationFeatures, validationCoreIds, ...
    validationMetadata)
%GENERATEBINARYFINGERPRINT Enroll validation-screened differential bits.
%   Thresholds and core references use enrollment data only. Validation
%   repetitions screen candidates for repeat and worst-condition stability.

if nargin < 4
    identityModel = [];
end
if nargin < 5
    metadata = [];
end
if nargin < 6
    validationFeatures = [];
end
if nargin < 7
    validationCoreIds = [];
end
if nargin < 8
    validationMetadata = [];
end
coreIds = coreIds(:);
if size(features,1) ~= numel(coreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature rows and identity labels must have equal counts.');
end

if isempty(identityModel)
    [embedding,mu,sigma,active] = standardizeFeatures(features);
    transformMode = 'standalone';
    if ~isempty(validationFeatures)
        validationEmbedding = standardizeFeatures(validationFeatures,mu,sigma,active);
    else
        validationEmbedding = [];
    end
else
    embedding = transformIdentityFeatures(identityModel,features,metadata);
    mu = [];
    sigma = [];
    active = [];
    transformMode = 'identity_embedding';
    if ~isempty(validationFeatures)
        validationEmbedding = transformIdentityFeatures(identityModel, ...
            validationFeatures,validationMetadata);
    else
        validationEmbedding = [];
    end
end

[firstIndex,secondIndex] = localCandidateDefinitions(size(embedding,2));
candidateValues = localCandidateValues(embedding,firstIndex,secondIndex);
labels = unique(coreIds(:))';
numCores = numel(labels);
numCandidates = size(candidateValues,2);
coreMedians = zeros(numCores,numCandidates);
for k = 1:numCores
    coreMedians(k,:) = median(candidateValues(coreIds == labels(k),:),1);
end
thresholds = median(coreMedians,1);
referenceBitsAll = coreMedians > thresholds;

reliabilityByCore = zeros(numCores,numCandidates);
for k = 1:numCores
    sampleBits = candidateValues(coreIds == labels(k),:) > thresholds;
    reliabilityByCore(k,:) = mean(sampleBits == referenceBitsAll(k,:),1);
end
meanEnrollmentReliability = mean(reliabilityByCore,1);

[meanValidationReliability,worstConditionReliability, ...
    validationReliabilityByCore] = localValidationReliability( ...
    validationEmbedding,validationCoreIds,validationMetadata,firstIndex, ...
    secondIndex,thresholds,labels,referenceBitsAll,meanEnrollmentReliability);

bitAlias = mean(referenceBitsAll,1);
candidateMedian = median(candidateValues,1);
robustScale = median(abs(candidateValues-candidateMedian),1)/0.6744897501960817;
robustScale = max(robustScale,1e-6);
normalizedMargin = mean(abs(coreMedians-thresholds)./robustScale,1);
aliasRange = cfg.puf.bitAliasRange;
balanced = bitAlias >= aliasRange(1) & bitAlias <= aliasRange(2);
eligible = meanEnrollmentReliability >= cfg.puf.minimumBitReliability & ...
    meanValidationReliability >= cfg.puf.minimumValidationReliability & ...
    worstConditionReliability >= cfg.puf.minimumWorstConditionReliability & ...
    balanced;
selectionReliability = min([meanEnrollmentReliability; ...
    meanValidationReliability;worstConditionReliability],[],1);
selectionScore = 0.30*meanEnrollmentReliability + ...
    0.45*meanValidationReliability + 0.25*worstConditionReliability - ...
    0.50*abs(bitAlias-0.5) + 0.05*min(normalizedMargin,4);

preferred = localRank(find(eligible),selectionScore);
balancedBackup = localRank(find(balanced & ~eligible),selectionScore);
remainingBackup = localRank(find(~balanced),selectionScore);
maximumBits = min(cfg.puf.maximumSelectedBits,numCandidates);
minimumBits = min(cfg.puf.minimumSelectedBits,maximumBits);

% Stop after the genuinely eligible set. Backups are used only to satisfy
% the minimum response length; the V2 implementation incorrectly continued
% filling every response to the configured maximum.
selectedIndices = localExtendSelection(referenceBitsAll,preferred,[], ...
    maximumBits,cfg.puf.maximumReferenceCorrelation);
if numel(selectedIndices) < minimumBits
    selectedIndices = localExtendSelection(referenceBitsAll,balancedBackup, ...
        selectedIndices,minimumBits,cfg.puf.maximumReferenceCorrelation);
end
if numel(selectedIndices) < minimumBits
    fallback = [balancedBackup remainingBackup];
    fallback = setdiff(fallback,selectedIndices,'stable');
    needed = min(minimumBits-numel(selectedIndices),numel(fallback));
    selectedIndices = [selectedIndices fallback(1:needed)];
end

selectedBits = false(1,numCandidates);
selectedBits(selectedIndices) = true;
pufModel.transformMode = transformMode;
pufModel.identityModel = identityModel;
pufModel.featureMean = mu;
pufModel.featureStd = sigma;
pufModel.activeFeatures = active;
pufModel.coreIds = labels;
pufModel.candidateFirstIndex = firstIndex;
pufModel.candidateSecondIndex = secondIndex;
pufModel.thresholds = thresholds;
pufModel.selectedBits = selectedBits;
pufModel.referenceBits = referenceBitsAll(:,selectedBits);
pufModel.enrollmentReliability = reliabilityByCore(:,selectedBits);
pufModel.validationReliability = validationReliabilityByCore(:,selectedBits);
pufModel.meanValidationReliability = meanValidationReliability(selectedBits);
pufModel.worstConditionReliability = worstConditionReliability(selectedBits);
pufModel.selectionReliability = selectionReliability(selectedBits);
pufModel.bitAliasEnrollment = bitAlias(selectedBits);
pufModel.selectionScore = selectionScore(selectedBits);
end

function [meanReliability,worstReliability,reliabilityByCore] = ...
    localValidationReliability(embedding,coreIds,metadata,firstIndex, ...
    secondIndex,thresholds,labels,referenceBits,fallbackReliability)
numCores = numel(labels);
numCandidates = numel(thresholds);
if isempty(embedding)
    meanReliability = fallbackReliability;
    worstReliability = fallbackReliability;
    reliabilityByCore = repmat(fallbackReliability,numCores,1);
    return;
end
coreIds = coreIds(:);
if size(embedding,1) ~= numel(coreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'Validation features and identity labels must have equal counts.');
end

values = localCandidateValues(embedding,firstIndex,secondIndex);
bits = values > thresholds;
agreement = false(size(bits));
reliabilityByCore = zeros(numCores,numCandidates);
for k = 1:numCores
    selected = coreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:MissingValidationCore', ...
            'Every enrolled core must appear in PUF validation data.');
    end
    agreement(selected,:) = bits(selected,:) == referenceBits(k,:);
    reliabilityByCore(k,:) = mean(agreement(selected,:),1);
end
meanReliability = mean(agreement,1);

if istable(metadata) && height(metadata) == size(bits,1) && ...
        any(strcmp(metadata.Properties.VariableNames,'ConditionId'))
    conditions = unique(metadata.ConditionId);
    conditionReliability = zeros(numel(conditions),numCandidates);
    for k = 1:numel(conditions)
        selected = metadata.ConditionId == conditions(k);
        conditionReliability(k,:) = mean(agreement(selected,:),1);
    end
    worstReliability = min(conditionReliability,[],1);
else
    worstReliability = meanReliability;
end
end

function ranking = localRank(indices,score)
indices = indices(:)';
[~,order] = sort(score(indices),'descend');
ranking = indices(order);
end

function [firstIndex,secondIndex] = localCandidateDefinitions(dimension)
firstIndex = 1:dimension;
secondIndex = zeros(1,dimension);
for first = 1:dimension-1
    for second = first+1:dimension
        firstIndex(end+1) = first; %#ok<AGROW>
        secondIndex(end+1) = second; %#ok<AGROW>
    end
end
end

function values = localCandidateValues(embedding,firstIndex,secondIndex)
values = embedding(:,firstIndex);
paired = secondIndex > 0;
if any(paired)
    values(:,paired) = values(:,paired)-embedding(:,secondIndex(paired));
end
end

function selected = localExtendSelection(referenceBits,ranking,selected, ...
    limit,maximumCorrelation)
for candidate = ranking
    if numel(selected) >= limit
        break;
    end
    isRedundant = false;
    for retained = selected
        correlation = localBinaryCorrelation(referenceBits(:,candidate), ...
            referenceBits(:,retained));
        if abs(correlation) > maximumCorrelation
            isRedundant = true;
            break;
        end
    end
    if ~isRedundant
        selected(end+1) = candidate; %#ok<AGROW>
    end
end
end

function value = localBinaryCorrelation(first,second)
first = double(first(:));
second = double(second(:));
first = first-mean(first);
second = second-mean(second);
denominator = sqrt(sum(first.^2)*sum(second.^2));
if denominator <= eps
    value = 1;
else
    value = sum(first.*second)/denominator;
end
end
