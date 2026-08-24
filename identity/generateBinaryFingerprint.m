function pufModel = generateBinaryFingerprint(features, coreIds, cfg)
%GENERATEBINARYFINGERPRINT Enroll reliable binary magnetic fingerprints.
%   A global feature threshold creates bits; unstable bits are rejected using
%   repeat measurements of every enrolled core.

[normalized, mu, sigma, active] = standardizeFeatures(features);
labels = unique(coreIds(:))';
numCores = numel(labels);
numFeatures = size(normalized,2);
coreMedians = zeros(numCores, numFeatures);
for k = 1:numCores
    coreMedians(k,:) = median(normalized(coreIds == labels(k),:), 1);
end
thresholds = median(coreMedians, 1);
referenceBitsAll = coreMedians > thresholds;

reliabilityByCore = zeros(numCores, numFeatures);
for k = 1:numCores
    sampleBits = normalized(coreIds == labels(k),:) > thresholds;
    reference = referenceBitsAll(k,:);
    reliabilityByCore(k,:) = mean(sampleBits == reference, 1);
end
meanReliability = mean(reliabilityByCore,1);
bitAlias = mean(referenceBitsAll,1);
balanced = bitAlias >= 0.10 & bitAlias <= 0.90;
selectedBits = meanReliability >= cfg.puf.minimumBitReliability & balanced;

if sum(selectedBits) < min(cfg.puf.minimumSelectedBits, numFeatures)
    selectionScore = meanReliability - 0.5*abs(bitAlias-0.5);
    [~, ranking] = sort(selectionScore, 'descend');
    selectedBits = false(1,numFeatures);
    selectedBits(ranking(1:min(cfg.puf.minimumSelectedBits,numFeatures))) = true;
end

pufModel.featureMean = mu;
pufModel.featureStd = sigma;
pufModel.activeFeatures = active;
pufModel.coreIds = labels;
pufModel.thresholds = thresholds;
pufModel.selectedBits = selectedBits;
pufModel.referenceBits = referenceBitsAll(:,selectedBits);
pufModel.enrollmentReliability = reliabilityByCore(:,selectedBits);
pufModel.bitAliasEnrollment = bitAlias(selectedBits);
end
