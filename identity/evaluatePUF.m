function metrics = evaluatePUF(pufModel, features, coreIds)
%EVALUATEPUF Evaluate reliability, uniqueness, uniformity, and entropy.
%   METRICS also includes genuine/impostor Hamming-distance distributions.

normalized = standardizeFeatures(features, pufModel.featureMean, ...
    pufModel.featureStd, pufModel.activeFeatures);
bits = normalized(:,pufModel.selectedBits) > ...
    pufModel.thresholds(pufModel.selectedBits);
numSamples = size(bits,1);
numCores = numel(pufModel.coreIds);
intra = zeros(numSamples,1);
inter = zeros(numSamples*max(numCores-1,1),1);
interIndex = 0;

for sample = 1:numSamples
    truePosition = find(pufModel.coreIds == coreIds(sample), 1);
    if isempty(truePosition)
        error('TrafoDNA:UnknownCore', 'Test identity was not enrolled.');
    end
    intra(sample) = mean(bits(sample,:) ~= pufModel.referenceBits(truePosition,:));
    for candidate = 1:numCores
        if candidate ~= truePosition
            interIndex = interIndex + 1;
            inter(interIndex) = mean(bits(sample,:) ~= pufModel.referenceBits(candidate,:));
        end
    end
end
inter = inter(1:interIndex);

referencePairs = zeros(numCores*(numCores-1)/2,1);
pairIndex = 0;
for first = 1:numCores-1
    for second = first+1:numCores
        pairIndex = pairIndex + 1;
        referencePairs(pairIndex) = mean(pufModel.referenceBits(first,:) ~= ...
            pufModel.referenceBits(second,:));
    end
end

bitAlias = mean(pufModel.referenceBits,1);
perBitEntropy = -log2(max([bitAlias; 1-bitAlias],[],1));
metrics.reliability = 1 - mean(intra);
metrics.uniqueness = mean(referencePairs);
metrics.uniformity = mean(pufModel.referenceBits(:));
metrics.bitAliasing = bitAlias;
metrics.intraHammingDistance = intra;
metrics.interHammingDistance = inter;
metrics.referencePairDistance = referencePairs;
metrics.minEntropyBits = sum(perBitEntropy);
metrics.normalizedMinEntropy = mean(perBitEntropy);
metrics.numSelectedBits = sum(pufModel.selectedBits);
metrics.testBits = bits;
end
