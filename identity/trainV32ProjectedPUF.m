function pufModel = trainV32ProjectedPUF(features,coreIds,cfg, ...
    identityModel,metadata,validationFeatures,validationCoreIds, ...
    validationMetadata,options)
%TRAINV32PROJECTEDPUF Fit exploratory stability-weighted projection bits.
%   The projection bank is learned from enrollment rows only. Validation
%   rows screen repeatability and worst-known-condition stability. Exact and
%   complementary population patterns are collapsed before correlation
%   selection so repeated encodings cannot masquerade as extra capacity.

if nargin < 9 || isempty(options)
    options = struct();
end
options = localOptions(options,cfg);
coreIds = coreIds(:);
validationCoreIds = validationCoreIds(:);
if size(features,1) ~= numel(coreIds) || ...
        size(validationFeatures,1) ~= numel(validationCoreIds)
    error('TrafoDNA:DimensionMismatch', ...
        'V3.2 feature rows and core labels must agree.');
end
if isempty(identityModel)
    error('TrafoDNA:V32TransformRequired', ...
        'V3.2 projected bits require the enrollment-fitted PUF transform.');
end

embedding = transformIdentityFeatures(identityModel,features,metadata);
validationEmbedding = transformIdentityFeatures(identityModel, ...
    validationFeatures,validationMetadata);
labels = unique(coreIds(:))';
numCores = numel(labels);
dimension = size(embedding,2);
if numCores < 4 || dimension < 2
    error('TrafoDNA:V32InsufficientPopulation', ...
        'Projected-bit development requires at least four cores and two axes.');
end

[projectionMatrix,projectionInfo] = localProjectionBank(embedding, ...
    coreIds,labels,options);
candidateValues = embedding*projectionMatrix;
validationValues = validationEmbedding*projectionMatrix;
numCandidates = size(candidateValues,2);

coreMedians = zeros(numCores,numCandidates);
for k = 1:numCores
    selected = coreIds == labels(k);
    coreMedians(k,:) = median(candidateValues(selected,:),1);
end
thresholds = median(coreMedians,1);
referenceBitsAll = coreMedians > thresholds;

enrollmentReliabilityByCore = zeros(numCores,numCandidates);
for k = 1:numCores
    sampleBits = candidateValues(coreIds == labels(k),:) > thresholds;
    enrollmentReliabilityByCore(k,:) = mean(sampleBits == ...
        referenceBitsAll(k,:),1);
end
meanEnrollmentReliability = mean(enrollmentReliabilityByCore,1);
[meanValidationReliability,worstConditionReliability, ...
    validationReliabilityByCore] = localValidationReliability( ...
    validationValues,validationCoreIds,validationMetadata,thresholds, ...
    labels,referenceBitsAll);

bitAlias = mean(referenceBitsAll,1);
candidateMedian = median(candidateValues,1);
robustScale = median(abs(candidateValues-candidateMedian),1)/ ...
    0.6744897501960817;
robustScale = max(robustScale,1e-6);
normalizedMargin = mean(abs(coreMedians-thresholds)./robustScale,1);
aliasRange = cfg.puf.bitAliasRange;
balanced = bitAlias >= aliasRange(1) & bitAlias <= aliasRange(2);
eligible = meanEnrollmentReliability >= cfg.puf.minimumBitReliability & ...
    meanValidationReliability >= cfg.puf.minimumValidationReliability & ...
    worstConditionReliability >= ...
    cfg.puf.minimumWorstConditionReliability & balanced;
if ~any(eligible)
    error('TrafoDNA:V32NoEligibleProjectedBits', ...
        'No projected candidates passed the unchanged V3 stability gates.');
end

weights = localSelectionWeights(cfg);
selectionScore = weights.enrollmentReliability* ...
    meanEnrollmentReliability + ...
    weights.validationReliability*meanValidationReliability + ...
    weights.worstConditionReliability*worstConditionReliability - ...
    weights.aliasPenalty*abs(bitAlias-0.5) + ...
    weights.marginReward*min(normalizedMargin,4);

eligibleIndices = find(eligible);
eligibleReferenceBits = referenceBitsAll(:,eligibleIndices);
canonicalBits = eligibleReferenceBits;
flipColumns = canonicalBits(1,:);
canonicalBits(:,flipColumns) = ~canonicalBits(:,flipColumns);
[~,~,patternClass] = unique(canonicalBits','rows');
patternCount = max(patternClass);
representativeIndices = zeros(1,patternCount);
for k = 1:patternCount
    members = eligibleIndices(patternClass == k);
    memberScores = selectionScore(members);
    bestScore = max(memberScores);
    representativeIndices(k) = min(members(memberScores == bestScore));
end

maximumBits = min([options.maximumBits,numel(representativeIndices)]);
[selectedCandidateIndices,selectedCorrelation] = localCorrelationSelect( ...
    referenceBitsAll,representativeIndices,selectionScore,maximumBits, ...
    cfg.puf.maximumReferenceCorrelation);
selectedMask = false(1,numCandidates);
selectedMask(selectedCandidateIndices) = true;

if nnz(selectedCorrelation > cfg.puf.maximumReferenceCorrelation) > 0
    error('TrafoDNA:V32CorrelatedSelection', ...
        'V3.2 projection selection retained a conflicting bit pair.');
end

pufModel.transformMode = 'identity_embedding';
pufModel.candidateMode = 'linear_projection';
pufModel.identityModel = identityModel;
pufModel.projectionMatrix = projectionMatrix;
pufModel.projectionInfo = projectionInfo;
pufModel.coreIds = labels;
pufModel.thresholds = thresholds;
pufModel.selectedBits = selectedMask;
pufModel.referenceBits = referenceBitsAll(:,selectedMask);
pufModel.enrollmentReliability = ...
    enrollmentReliabilityByCore(:,selectedMask);
pufModel.validationReliability = ...
    validationReliabilityByCore(:,selectedMask);
pufModel.meanValidationReliability = ...
    meanValidationReliability(selectedMask);
pufModel.worstConditionReliability = ...
    worstConditionReliability(selectedMask);
pufModel.selectionReliability = min([ ...
    meanEnrollmentReliability(selectedMask); ...
    meanValidationReliability(selectedMask); ...
    worstConditionReliability(selectedMask)],[],1);
pufModel.bitAliasEnrollment = bitAlias(selectedMask);
pufModel.selectionScore = selectionScore(selectedMask);
pufModel.selectionWeights = weights;
pufModel.numEligibleCandidates = sum(eligible);
pufModel.numUniqueEligiblePatterns = patternCount;
pufModel.numSelectedEligibleBits = sum(selectedMask);
pufModel.numFallbackBits = 0;
pufModel.allowFallbackToMinimum = false;
pufModel.targetBits = options.targetBits;
pufModel.targetReached = sum(selectedMask) >= options.targetBits;
pufModel.maximumReferenceCorrelation = ...
    cfg.puf.maximumReferenceCorrelation;
pufModel.maximumSelectedCorrelation = max(selectedCorrelation,[],'all');
pufModel.selectedCandidateIndices = selectedCandidateIndices;
pufModel.representativeCandidateIndices = representativeIndices;
pufModel.eligibleCandidateIndices = eligibleIndices;
pufModel.eligiblePatternClass = patternClass;
pufModel.selectionMethod = ...
    'pattern_deduplicated_ranked_projection_selection';
pufModel.developmentOnly = true;
pufModel.options = options;
pufModel.selectedBitsTable = localSelectedTable(pufModel, ...
    meanEnrollmentReliability,meanValidationReliability, ...
    worstConditionReliability,bitAlias,normalizedMargin,selectionScore, ...
    referenceBitsAll,selectedCorrelation,patternClass,eligibleIndices);
end

function options = localOptions(options,cfg)
defaults.randomProjectionCount = 8192;
defaults.subspaceDimensions = 19;
defaults.withinVarianceRegularization = 0.25;
defaults.energyWeightExponent = 0.50;
defaults.randomSeed = 20260831;
defaults.targetBits = cfg.puf.minimumSelectedBits;
defaults.maximumBits = cfg.puf.maximumSelectedBits;
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
validateattributes(options.randomProjectionCount,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'});
validateattributes(options.subspaceDimensions,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
validateattributes(options.withinVarianceRegularization,{'numeric'}, ...
    {'scalar','nonnegative','finite'});
validateattributes(options.energyWeightExponent,{'numeric'}, ...
    {'scalar','nonnegative','finite'});
validateattributes(options.randomSeed,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'});
validateattributes(options.targetBits,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
validateattributes(options.maximumBits,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
end

function [projectionMatrix,info] = localProjectionBank(embedding,coreIds, ...
    labels,options)
dimension = size(embedding,2);
coreMedians = zeros(numel(labels),dimension);
within = zeros(size(embedding));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    coreMedians(k,:) = median(embedding(selected,:),1);
    within(selected,:) = embedding(selected,:)-coreMedians(k,:);
end
withinVariance = mean(within.^2,1);
positiveVariance = withinVariance(withinVariance > eps);
if isempty(positiveVariance)
    varianceFloor = 1;
else
    varianceFloor = median(positiveVariance);
end
noiseScale = sqrt(withinVariance + ...
    options.withinVarianceRegularization*max(varianceFloor,eps));
noiseScale = max(noiseScale,sqrt(eps));
whitenedCoreMedians = coreMedians./noiseScale;
centeredCoreMedians = whitenedCoreMedians-mean(whitenedCoreMedians,1);
[~,singularMatrix,rightVectors] = svd(centeredCoreMedians,'econ');
singularValues = diag(singularMatrix);
available = sum(singularValues > max(singularValues)*1e-10);
subspaceDimension = min([options.subspaceDimensions,available, ...
    size(rightVectors,2),numel(labels)-1]);
if subspaceDimension < 1
    error('TrafoDNA:V32EmptyStableSubspace', ...
        'Enrollment data produced no stable between-core subspace.');
end
basis = rightVectors(:,1:subspaceDimension);

axisCoefficients = eye(subspaceDimension);
pairCoefficients = zeros(subspaceDimension, ...
    subspaceDimension*(subspaceDimension-1));
column = 0;
for first = 1:subspaceDimension-1
    for second = first+1:subspaceDimension
        column = column+1;
        pairCoefficients(first,column) = 1/sqrt(2);
        pairCoefficients(second,column) = 1/sqrt(2);
        column = column+1;
        pairCoefficients(first,column) = 1/sqrt(2);
        pairCoefficients(second,column) = -1/sqrt(2);
    end
end

previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));
rng(options.randomSeed,'twister');
isotropicCount = floor(options.randomProjectionCount/2);
weightedCount = options.randomProjectionCount-isotropicCount;
isotropic = randn(subspaceDimension,isotropicCount);
weighted = randn(subspaceDimension,weightedCount);
energyWeight = singularValues(1:subspaceDimension);
energyWeight = energyWeight/max(energyWeight);
energyWeight = max(energyWeight,eps).^options.energyWeightExponent;
weighted = weighted.*energyWeight;
coefficients = [axisCoefficients pairCoefficients isotropic weighted];
coefficientNorm = sqrt(sum(coefficients.^2,1));
coefficients = coefficients./max(coefficientNorm,eps);
clear cleanup

scaledBasis = basis./noiseScale(:);
projectionMatrix = scaledBasis*coefficients;
projectionNorm = sqrt(sum(projectionMatrix.^2,1));
projectionMatrix = projectionMatrix./max(projectionNorm,eps);
for k = 1:size(projectionMatrix,2)
    [~,pivot] = max(abs(projectionMatrix(:,k)));
    if projectionMatrix(pivot,k) < 0
        projectionMatrix(:,k) = -projectionMatrix(:,k);
    end
end

info.embeddingDimensions = dimension;
info.subspaceDimensions = subspaceDimension;
info.axisProjectionCount = size(axisCoefficients,2);
info.pairProjectionCount = size(pairCoefficients,2);
info.randomProjectionCount = options.randomProjectionCount;
info.totalProjectionCount = size(projectionMatrix,2);
info.withinVariance = withinVariance;
info.noiseScale = noiseScale;
info.singularValues = singularValues;
info.energyWeight = energyWeight;
end

function [meanReliability,worstReliability,reliabilityByCore] = ...
    localValidationReliability(values,coreIds,metadata,thresholds,labels, ...
    referenceBits)
bits = values > thresholds;
agreement = false(size(bits));
reliabilityByCore = zeros(numel(labels),numel(thresholds));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:V32MissingValidationCore', ...
            'Every enrolled core must appear in validation.');
    end
    agreement(selected,:) = bits(selected,:) == referenceBits(k,:);
    reliabilityByCore(k,:) = mean(agreement(selected,:),1);
end
meanReliability = mean(agreement,1);
if ~istable(metadata) || ...
        ~any(strcmp(metadata.Properties.VariableNames,'ConditionId'))
    worstReliability = meanReliability;
    return;
end
conditions = unique(metadata.ConditionId);
conditionReliability = zeros(numel(conditions),numel(thresholds));
for k = 1:numel(conditions)
    selected = metadata.ConditionId == conditions(k);
    conditionReliability(k,:) = mean(agreement(selected,:),1);
end
worstReliability = min(conditionReliability,[],1);
end

function weights = localSelectionWeights(cfg)
weights.enrollmentReliability = 0.30;
weights.validationReliability = 0.45;
weights.worstConditionReliability = 0.25;
weights.aliasPenalty = 0.50;
weights.marginReward = 0.05;
if isfield(cfg.puf,'selectionWeights')
    configured = cfg.puf.selectionWeights;
    names = fieldnames(weights);
    for k = 1:numel(names)
        if isfield(configured,names{k})
            weights.(names{k}) = configured.(names{k});
        end
    end
end
total = weights.enrollmentReliability + weights.validationReliability + ...
    weights.worstConditionReliability;
weights.enrollmentReliability = weights.enrollmentReliability/total;
weights.validationReliability = weights.validationReliability/total;
weights.worstConditionReliability = weights.worstConditionReliability/total;
end

function [selected,selectedCorrelation] = localCorrelationSelect( ...
    referenceBits,representatives,score,limit,maximumCorrelation)
[~,order] = sort(score(representatives),'descend');
ranked = representatives(order);
selected = zeros(1,0);
for candidate = ranked(:)'
    if isempty(selected)
        selected = candidate;
    else
        correlation = localCrossCorrelation(referenceBits(:,candidate), ...
            referenceBits(:,selected));
        if all(abs(correlation) <= maximumCorrelation)
            selected(end+1) = candidate; %#ok<AGROW>
        end
    end
    if numel(selected) >= limit
        break;
    end
end
selectedCorrelation = abs(localCrossCorrelation( ...
    referenceBits(:,selected),referenceBits(:,selected)));
selectedCorrelation(1:size(selectedCorrelation,1)+1:end) = 0;
end

function correlation = localCrossCorrelation(first,second)
first = double(first);
second = double(second);
first = first-mean(first,1);
second = second-mean(second,1);
denominator = sqrt(sum(first.^2,1))'*sqrt(sum(second.^2,1));
correlation = (first'*second)./max(denominator,eps);
correlation(denominator <= eps) = 1;
correlation(~isfinite(correlation)) = 1;
correlation = min(max(correlation,-1),1);
end

function selectedTable = localSelectedTable(model,enrollmentReliability, ...
    validationReliability,worstReliability,alias,margin,score, ...
    referenceBits,selectedCorrelation,patternClass,eligibleIndices)
candidateIndex = model.selectedCandidateIndices(:);
eligiblePosition = zeros(numel(candidateIndex),1);
canonicalPatternClass = zeros(numel(candidateIndex),1);
for k = 1:numel(candidateIndex)
    eligiblePosition(k) = find(eligibleIndices == candidateIndex(k),1);
    canonicalPatternClass(k) = patternClass(eligiblePosition(k));
end
maximumSelectedCorrelation = max(selectedCorrelation,[],2);
referencePattern = cell(numel(candidateIndex),1);
for k = 1:numel(candidateIndex)
    referencePattern{k} = char(referenceBits(:,candidateIndex(k))'+'0');
end
selectedTable = table(candidateIndex,canonicalPatternClass,referencePattern, ...
    reshape(enrollmentReliability(candidateIndex),[],1), ...
    reshape(validationReliability(candidateIndex),[],1), ...
    reshape(worstReliability(candidateIndex),[],1), ...
    reshape(alias(candidateIndex),[],1), ...
    reshape(margin(candidateIndex),[],1), ...
    reshape(score(candidateIndex),[],1),maximumSelectedCorrelation, ...
    'VariableNames',{'CandidateIndex','CanonicalPatternClass', ...
    'ReferencePattern','EnrollmentReliability','ValidationReliability', ...
    'WorstKnownConditionReliability','EnrollmentBitAlias', ...
    'NormalizedMargin','SelectionScore','MaximumSelectedCorrelation'});
end
