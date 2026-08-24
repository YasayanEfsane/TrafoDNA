function pufModel = generateBinaryFingerprint(features, coreIds, cfg, identityModel, metadata)
%GENERATEBINARYFINGERPRINT Enroll stable differential magnetic fingerprints.
%   Candidate bits include unary identity coordinates and pairwise coordinate
%   differences. Enrollment reliability, population balance, margin, and
%   reference-bit correlation determine the selected response positions.

if nargin < 4
    identityModel = [];
end
if nargin < 5
    metadata = [];
end
coreIds = coreIds(:);
if size(features,1) ~= numel(coreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'Feature rows and identity labels must have equal counts.');
end

if isempty(identityModel)
    [embedding, mu, sigma, active] = standardizeFeatures(features);
    transformMode = 'standalone';
else
    embedding = transformIdentityFeatures(identityModel, features, metadata);
    mu = [];
    sigma = [];
    active = [];
    transformMode = 'identity_embedding';
end

[firstIndex, secondIndex] = localCandidateDefinitions(size(embedding,2));
candidateValues = localCandidateValues(embedding, firstIndex, secondIndex);
labels = unique(coreIds(:))';
numCores = numel(labels);
numCandidates = size(candidateValues,2);
coreMedians = zeros(numCores, numCandidates);
for k = 1:numCores
    coreMedians(k,:) = median(candidateValues(coreIds == labels(k),:), 1);
end
thresholds = median(coreMedians, 1);
referenceBitsAll = coreMedians > thresholds;

reliabilityByCore = zeros(numCores, numCandidates);
for k = 1:numCores
    sampleBits = candidateValues(coreIds == labels(k),:) > thresholds;
    reliabilityByCore(k,:) = mean(sampleBits == referenceBitsAll(k,:), 1);
end
meanReliability = mean(reliabilityByCore,1);
bitAlias = mean(referenceBitsAll,1);

candidateMedian = median(candidateValues,1);
robustScale = median(abs(candidateValues-candidateMedian),1) / 0.6744897501960817;
robustScale = max(robustScale, 1e-6);
normalizedMargin = mean(abs(coreMedians-thresholds) ./ robustScale, 1);
aliasRange = cfg.puf.bitAliasRange;
balanced = bitAlias >= aliasRange(1) & bitAlias <= aliasRange(2);
eligible = meanReliability >= cfg.puf.minimumBitReliability & balanced;
selectionScore = meanReliability - 0.50*abs(bitAlias-0.5) + ...
    0.05*min(normalizedMargin,4);

preferred = find(eligible);
[~, order] = sort(selectionScore(preferred), 'descend');
preferred = preferred(order);
preferred = preferred(:)';
allCandidates = find(balanced);
[~, order] = sort(selectionScore(allCandidates), 'descend');
allCandidates = allCandidates(order);
allCandidates = allCandidates(:)';
ranking = [preferred setdiff(allCandidates, preferred, 'stable')];
if numel(ranking) < cfg.puf.minimumSelectedBits
    [~, order] = sort(selectionScore, 'descend');
    ranking = [ranking setdiff(order(:)', ranking, 'stable')];
end

maximumBits = min(cfg.puf.maximumSelectedBits, numCandidates);
minimumBits = min(cfg.puf.minimumSelectedBits, maximumBits);
selectedIndices = localSelectLowCorrelation(referenceBitsAll, ranking, ...
    minimumBits, maximumBits, cfg.puf.maximumReferenceCorrelation);
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
pufModel.bitAliasEnrollment = bitAlias(selectedBits);
pufModel.selectionScore = selectionScore(selectedBits);
end

function [firstIndex, secondIndex] = localCandidateDefinitions(dimension)
firstIndex = 1:dimension;
secondIndex = zeros(1,dimension);
for first = 1:dimension-1
    for second = first+1:dimension
        firstIndex(end+1) = first; %#ok<AGROW>
        secondIndex(end+1) = second; %#ok<AGROW>
    end
end
end

function values = localCandidateValues(embedding, firstIndex, secondIndex)
values = embedding(:,firstIndex);
paired = secondIndex > 0;
if any(paired)
    values(:,paired) = values(:,paired) - embedding(:,secondIndex(paired));
end
end

function selected = localSelectLowCorrelation(referenceBits, ranking, ...
    minimumBits, maximumBits, maximumCorrelation)
selected = zeros(1,0);
deferred = zeros(1,0);
for candidate = ranking
    if numel(selected) >= maximumBits
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
    if isRedundant
        deferred(end+1) = candidate; %#ok<AGROW>
    else
        selected(end+1) = candidate; %#ok<AGROW>
    end
end
if numel(selected) < minimumBits
    needed = minimumBits-numel(selected);
    selected = [selected deferred(1:min(needed,numel(deferred)))];
end
end

function value = localBinaryCorrelation(first, second)
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
