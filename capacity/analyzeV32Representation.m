function diagnostic = analyzeV32Representation(activeResults,options)
%ANALYZEV32REPRESENTATION Diagnose the V3 raw-bit representation.
%   DIAGNOSTIC = ANALYZEV32REPRESENTATION(ACTIVERESULTS) reconstructs all
%   V3 candidate bits from enrollment and validation rows only, then
%   measures duplicate/complement patterns, correlation-graph structure,
%   effective rank, and embedding-axis reuse. It does not construct a new
%   fingerprint, tune a threshold, or evaluate any final-holdout row.
%
%   This is exploratory V3.2 development evidence. The locked V3 decision
%   remains NOT SUPPORTED and scenarios 115--118 remain observed.

if nargin < 2 || isempty(options)
    options = struct();
end
localValidateResults(activeResults);
cfg = activeResults.cfg;
options = localOptions(options,cfg);

features = activeResults.features;
metadata = activeResults.metadata;
splits = activeResults.splits;
trainMask = logical(splits.train(:));
validationMask = logical(splits.validation(:));
finalMask = logical(splits.finalHoldout(:));
if any(trainMask & validationMask) || any(trainMask & finalMask) || ...
        any(validationMask & finalMask)
    error('TrafoDNA:V32PartitionLeakage', ...
        'V3.2 diagnostic partitions overlap.');
end
if ~any(trainMask) || ~any(validationMask)
    error('TrafoDNA:V32MissingDevelopmentRows', ...
        'Enrollment and validation partitions must both be nonempty.');
end

pufTransform = activeResults.pufIdentityModel;
frozenModel = activeResults.pufModel;
trainEmbedding = transformIdentityFeatures(pufTransform, ...
    features(trainMask,:),metadata(trainMask,:));
validationEmbedding = transformIdentityFeatures(pufTransform, ...
    features(validationMask,:),metadata(validationMask,:));

firstIndex = frozenModel.candidateFirstIndex;
secondIndex = frozenModel.candidateSecondIndex;
trainValues = localCandidateValues(trainEmbedding,firstIndex,secondIndex);
validationValues = localCandidateValues(validationEmbedding, ...
    firstIndex,secondIndex);
trainCoreIds = metadata.CoreId(trainMask);
validationCoreIds = metadata.CoreId(validationMask);
validationMetadata = metadata(validationMask,:);
labels = frozenModel.coreIds(:)';
numCores = numel(labels);
numCandidates = size(trainValues,2);

coreEmbeddingMedians = zeros(numCores,size(trainEmbedding,2));
coreCandidateMedians = zeros(numCores,numCandidates);
for k = 1:numCores
    selected = trainCoreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:V32MissingEnrollmentCore', ...
            'Every PUF core must appear in enrollment.');
    end
    coreEmbeddingMedians(k,:) = median(trainEmbedding(selected,:),1);
    coreCandidateMedians(k,:) = median(trainValues(selected,:),1);
end
thresholds = median(coreCandidateMedians,1);
referenceBitsAll = coreCandidateMedians > thresholds;

enrollmentReliabilityByCore = zeros(numCores,numCandidates);
for k = 1:numCores
    sampleBits = trainValues(trainCoreIds == labels(k),:) > thresholds;
    enrollmentReliabilityByCore(k,:) = mean(sampleBits == ...
        referenceBitsAll(k,:),1);
end
meanEnrollmentReliability = mean(enrollmentReliabilityByCore,1);
[meanValidationReliability,worstConditionReliability] = ...
    localValidationReliability(validationValues,validationCoreIds, ...
    validationMetadata,thresholds,labels,referenceBitsAll);

bitAlias = mean(referenceBitsAll,1);
aliasRange = cfg.puf.bitAliasRange;
balanced = bitAlias >= aliasRange(1) & bitAlias <= aliasRange(2);
eligible = meanEnrollmentReliability >= cfg.puf.minimumBitReliability & ...
    meanValidationReliability >= cfg.puf.minimumValidationReliability & ...
    worstConditionReliability >= ...
    cfg.puf.minimumWorstConditionReliability & balanced;
eligibleIndices = find(eligible);
if isempty(eligibleIndices)
    error('TrafoDNA:V32NoEligibleCandidates', ...
        'No candidates passed the frozen V3 eligibility screen.');
end

eligibleBits = referenceBitsAll(:,eligibleIndices);
[correlationMatrix,conflictGraph] = localCorrelationGraph(eligibleBits, ...
    cfg.puf.maximumReferenceCorrelation);
conflictDegree = sum(conflictGraph,2);
[componentId,componentTable] = localComponents(conflictGraph,conflictDegree);

canonicalBits = eligibleBits;
flipColumns = canonicalBits(1,:);
canonicalBits(:,flipColumns) = ~canonicalBits(:,flipColumns);
[canonicalPatternRows,~,patternClass] = unique(canonicalBits','rows');
[exactPatternRows,~,exactPatternClass] = unique(eligibleBits','rows');
patternMultiplicity = accumarray(patternClass,1, ...
    [size(canonicalPatternRows,1) 1]);
exactMultiplicity = accumarray(exactPatternClass,1, ...
    [size(exactPatternRows,1) 1]);
patternTable = localPatternTable(canonicalPatternRows,patternClass, ...
    patternMultiplicity,eligibleIndices,conflictDegree);

embeddingRank = localEffectiveRank(coreEmbeddingMedians);
candidateRank = localEffectiveRank( ...
    coreCandidateMedians(:,eligibleIndices));
binaryRank = localEffectiveRank(double(eligibleBits));

[candidateTable,axisTable] = localProvenanceTables(activeResults, ...
    pufTransform,eligibleIndices,firstIndex,secondIndex,patternClass, ...
    patternMultiplicity,conflictDegree,correlationMatrix,componentId, ...
    meanEnrollmentReliability,meanValidationReliability, ...
    worstConditionReliability,bitAlias);

thresholdScale = max([1 abs(frozenModel.thresholds(:)')]);
thresholdDifference = max(abs(thresholds-frozenModel.thresholds));
thresholdsReproduced = thresholdDifference <= 1e-10*thresholdScale;
eligibleCountReproduced = sum(eligible) == frozenModel.numEligibleCandidates;

diagnostic.study = 'TrafoDNA V3.2 representation diagnostic';
diagnostic.status = 'exploratory_enrollment_validation_only';
diagnostic.options = options;
diagnostic.summary.numCores = numCores;
diagnostic.summary.embeddingDimensions = size(trainEmbedding,2);
diagnostic.summary.numCandidates = numCandidates;
diagnostic.summary.numEligibleCandidates = numel(eligibleIndices);
diagnostic.summary.numUnaryEligible = ...
    sum(secondIndex(eligibleIndices) == 0);
diagnostic.summary.numPairwiseEligible = ...
    sum(secondIndex(eligibleIndices) > 0);
diagnostic.summary.numExactReferencePatterns = size(exactPatternRows,1);
diagnostic.summary.numCanonicalPatterns = size(canonicalPatternRows,1);
diagnostic.summary.numComplementCollapses = ...
    size(exactPatternRows,1)-size(canonicalPatternRows,1);
diagnostic.summary.maximumCanonicalMultiplicity = max(patternMultiplicity);
diagnostic.summary.maximumExactMultiplicity = max(exactMultiplicity);
diagnostic.summary.conflictEdges = nnz(triu(conflictGraph,1));
diagnostic.summary.conflictDensity = 2*diagnostic.summary.conflictEdges/ ...
    max(numel(eligibleIndices)*(numel(eligibleIndices)-1),1);
diagnostic.summary.numConflictComponents = height(componentTable);
diagnostic.summary.largestConflictComponent = max(componentTable.Size);
diagnostic.rank.embeddingCoreMedians = embeddingRank;
diagnostic.rank.eligibleCandidateMedians = candidateRank;
diagnostic.rank.eligibleReferenceBits = binaryRank;
diagnostic.pattern.referenceBits = eligibleBits;
diagnostic.pattern.canonicalReferenceBits = canonicalBits;
diagnostic.pattern.canonicalPatternRows = canonicalPatternRows;
diagnostic.pattern.exactPatternRows = exactPatternRows;
diagnostic.pattern.classByCandidate = patternClass;
diagnostic.pattern.exactClassByCandidate = exactPatternClass;
diagnostic.pattern.table = patternTable;
diagnostic.graph.correlationMatrix = correlationMatrix;
diagnostic.graph.conflictGraph = conflictGraph;
diagnostic.graph.degree = conflictDegree;
diagnostic.graph.componentId = componentId;
diagnostic.graph.components = componentTable;
diagnostic.candidates.eligibleIndices = eligibleIndices;
diagnostic.candidates.table = candidateTable;
diagnostic.axes.table = axisTable;
diagnostic.integrity.enrollmentRowsUsed = sum(trainMask);
diagnostic.integrity.validationRowsUsed = sum(validationMask);
diagnostic.integrity.developmentRowsUsed = 0;
diagnostic.integrity.finalRowsUsed = 0;
diagnostic.integrity.thresholdDifference = thresholdDifference;
diagnostic.integrity.thresholdsReproduced = thresholdsReproduced;
diagnostic.integrity.eligibleCountReproduced = eligibleCountReproduced;
diagnostic.integrity.lockedV3Decision = 'NOT SUPPORTED';

if options.saveResults
    localSaveDiagnostic(diagnostic,cfg,options);
end
if options.verbose
    localPrintDiagnostic(diagnostic);
end
end

function localValidateResults(results)
required = {'cfg','features','featureNames','metadata','splits', ...
    'pufIdentityModel','pufModel'};
for k = 1:numel(required)
    if ~isfield(results,required{k})
        error('TrafoDNA:V32MissingResultField', ...
            'Active results are missing field "%s".',required{k});
    end
end
if ~istable(results.metadata) || ...
        height(results.metadata) ~= size(results.features,1)
    error('TrafoDNA:V32InvalidMetadata', ...
        'Active feature rows and metadata must agree.');
end
end

function options = localOptions(options,cfg)
defaults.saveResults = true;
defaults.verbose = true;
defaults.resultDirectory = fullfile(cfg.projectRoot,'results_v32');
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
options.saveResults = logical(options.saveResults);
options.verbose = logical(options.verbose);
end

function values = localCandidateValues(embedding,firstIndex,secondIndex)
values = embedding(:,firstIndex);
paired = secondIndex > 0;
if any(paired)
    values(:,paired) = values(:,paired)-embedding(:,secondIndex(paired));
end
end

function [meanReliability,worstReliability] = ...
    localValidationReliability(values,coreIds,metadata,thresholds,labels, ...
    referenceBits)
bits = values > thresholds;
agreement = false(size(bits));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:V32MissingValidationCore', ...
            'Every enrolled core must appear in validation.');
    end
    agreement(selected,:) = bits(selected,:) == referenceBits(k,:);
end
meanReliability = mean(agreement,1);
if ~any(strcmp(metadata.Properties.VariableNames,'ConditionId'))
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

function [correlation,conflict] = localCorrelationGraph(referenceBits,limit)
centered = double(referenceBits)-mean(referenceBits,1);
norms = sqrt(sum(centered.^2,1));
denominator = norms'*norms;
correlation = (centered'*centered)./max(denominator,eps);
correlation(denominator <= eps) = 1;
correlation(~isfinite(correlation)) = 1;
correlation = min(max(correlation,-1),1);
conflict = abs(correlation) > limit;
conflict(1:size(conflict,1)+1:end) = false;
end

function [componentId,componentTable] = localComponents(conflict,degree)
nodeCount = size(conflict,1);
componentId = zeros(nodeCount,1);
component = 0;
for start = 1:nodeCount
    if componentId(start) ~= 0
        continue;
    end
    component = component+1;
    queue = start;
    componentId(start) = component;
    position = 1;
    while position <= numel(queue)
        node = queue(position);
        position = position+1;
        neighbors = find(conflict(node,:));
        unseen = neighbors(componentId(neighbors) == 0);
        componentId(unseen) = component;
        queue = [queue unseen]; %#ok<AGROW>
    end
end
componentNumber = (1:component)';
componentSize = accumarray(componentId,1,[component 1]);
minimumDegree = zeros(component,1);
medianDegree = zeros(component,1);
maximumDegree = zeros(component,1);
for k = 1:component
    selectedDegree = degree(componentId == k);
    minimumDegree(k) = min(selectedDegree);
    medianDegree(k) = median(selectedDegree);
    maximumDegree(k) = max(selectedDegree);
end
componentTable = table(componentNumber,componentSize,minimumDegree, ...
    medianDegree,maximumDegree,'VariableNames', ...
    {'Component','Size','MinimumDegree','MedianDegree','MaximumDegree'});
componentTable = sortrows(componentTable,'Size','descend');
end

function rankInfo = localEffectiveRank(matrix)
centered = double(matrix)-mean(double(matrix),1);
singularValues = svd(centered,'econ');
energy = singularValues.^2;
if isempty(singularValues) || sum(energy) <= eps
    numericalRank = 0;
    entropyRank = 0;
    participationRank = 0;
    explainedByFirst = 0;
else
    tolerance = max(size(centered))*eps(max(singularValues));
    numericalRank = sum(singularValues > tolerance);
    probability = energy/sum(energy);
    positive = probability > 0;
    entropyRank = exp(-sum(probability(positive).*log(probability(positive))));
    participationRank = sum(energy)^2/sum(energy.^2);
    explainedByFirst = energy(1)/sum(energy);
end
rankInfo.numerical = numericalRank;
rankInfo.entropyEffective = entropyRank;
rankInfo.participationRatio = participationRank;
rankInfo.firstComponentEnergyFraction = explainedByFirst;
rankInfo.singularValues = singularValues;
end

function tableOut = localPatternTable(patternRows,patternClass, ...
    multiplicity,eligibleIndices,degree)
patternCount = size(patternRows,1);
pattern = cell(patternCount,1);
representativeCandidate = zeros(patternCount,1);
minimumDegree = zeros(patternCount,1);
medianDegree = zeros(patternCount,1);
maximumDegree = zeros(patternCount,1);
for k = 1:patternCount
    pattern{k} = char(patternRows(k,:)+'0');
    members = find(patternClass == k);
    representativeCandidate(k) = eligibleIndices(members(1));
    selectedDegree = degree(members);
    minimumDegree(k) = min(selectedDegree);
    medianDegree(k) = median(selectedDegree);
    maximumDegree(k) = max(selectedDegree);
end
patternClassNumber = (1:patternCount)';
tableOut = table(patternClassNumber,pattern,multiplicity, ...
    representativeCandidate,minimumDegree,medianDegree,maximumDegree, ...
    'VariableNames',{'PatternClass','CanonicalPattern','CandidateCount', ...
    'RepresentativeCandidateIndex','MinimumDegree','MedianDegree', ...
    'MaximumDegree'});
tableOut = sortrows(tableOut,'CandidateCount','descend');
end

function [candidateTable,axisTable] = localProvenanceTables(activeResults, ...
    pufTransform,eligibleIndices,firstIndex,secondIndex,patternClass, ...
    patternMultiplicity,degree,correlation,componentId,enrollmentReliability, ...
    validationReliability,worstReliability,bitAlias)
candidateIndex = eligibleIndices(:);
firstDimension = firstIndex(candidateIndex(:));
secondDimension = secondIndex(candidateIndex(:));
candidateType = repmat({'pairwise_difference'},numel(candidateIndex),1);
unary = secondDimension == 0;
candidateType(unary) = repmat({'unary_axis'},sum(unary),1);
absoluteCorrelation = abs(correlation);
absoluteCorrelation(1:size(absoluteCorrelation,1)+1:end) = 0;
maximumAbsoluteCorrelation = max(absoluteCorrelation,[],2);
canonicalMultiplicity = patternMultiplicity(patternClass);
candidateTable = table(candidateIndex,firstDimension(:), ...
    secondDimension(:),candidateType,patternClass(:), ...
    canonicalMultiplicity(:),componentId(:),degree(:), ...
    maximumAbsoluteCorrelation(:), ...
    reshape(enrollmentReliability(candidateIndex),[],1), ...
    reshape(validationReliability(candidateIndex),[],1), ...
    reshape(worstReliability(candidateIndex),[],1), ...
    reshape(bitAlias(candidateIndex),[],1), ...
    'VariableNames',{'CandidateIndex','FirstEmbeddingDimension', ...
    'SecondEmbeddingDimension','CandidateType','CanonicalPatternClass', ...
    'CanonicalPatternMultiplicity','ConflictComponent','ConflictDegree', ...
    'MaximumAbsoluteCorrelation','EnrollmentReliability', ...
    'ValidationReliability','WorstKnownConditionReliability', ...
    'EnrollmentBitAlias'});

dimensionCount = numel(pufTransform.selectedFeatures);
embeddingDimension = (1:dimensionCount)';
rawFeatureIndex = nan(dimensionCount,1);
featureName = cell(dimensionCount,1);
if isfield(pufTransform,'activeFeatures')
    activeFeatureIndices = find(pufTransform.activeFeatures);
    if numel(activeFeatureIndices) >= max(pufTransform.selectedFeatures)
        sourceIndices = activeFeatureIndices(pufTransform.selectedFeatures);
        rawFeatureIndex = sourceIndices(:);
        if numel(activeResults.featureNames) >= max(sourceIndices)
            featureName = activeResults.featureNames(sourceIndices(:));
            featureName = featureName(:);
        end
    end
end
for k = 1:dimensionCount
    if isempty(featureName{k})
        featureName{k} = sprintf('EmbeddingDimension_%d',k);
    end
end
eligibleCandidateCount = zeros(dimensionCount,1);
uniqueCanonicalPatterns = zeros(dimensionCount,1);
meanConflictDegree = zeros(dimensionCount,1);
maximumConflictDegree = zeros(dimensionCount,1);
for k = 1:dimensionCount
    member = firstDimension == k | secondDimension == k;
    eligibleCandidateCount(k) = sum(member);
    if any(member)
        uniqueCanonicalPatterns(k) = numel(unique(patternClass(member)));
        meanConflictDegree(k) = mean(degree(member));
        maximumConflictDegree(k) = max(degree(member));
    end
end
axisTable = table(embeddingDimension,rawFeatureIndex,featureName, ...
    eligibleCandidateCount,uniqueCanonicalPatterns,meanConflictDegree, ...
    maximumConflictDegree,'VariableNames',{'EmbeddingDimension', ...
    'RawFeatureIndex','FeatureName','EligibleCandidateCount', ...
    'UniqueCanonicalPatterns','MeanConflictDegree','MaximumConflictDegree'});
axisTable = sortrows(axisTable, ...
    {'EligibleCandidateCount','MeanConflictDegree'},{'descend','descend'});
end

function localSaveDiagnostic(diagnostic,cfg,options)
resultDirectory = options.resultDirectory;
if isempty(resultDirectory)
    resultDirectory = fullfile(cfg.projectRoot,'results_v32');
end
if ~exist(resultDirectory,'dir')
    mkdir(resultDirectory);
end
save(fullfile(resultDirectory,'v32_representation_diagnostic.mat'), ...
    'diagnostic','-v7.3');
writetable(diagnostic.candidates.table,fullfile(resultDirectory, ...
    'v32_eligible_candidates.csv'));
writetable(diagnostic.pattern.table,fullfile(resultDirectory, ...
    'v32_pattern_classes.csv'));
writetable(diagnostic.graph.components,fullfile(resultDirectory, ...
    'v32_conflict_components.csv'));
writetable(diagnostic.axes.table,fullfile(resultDirectory, ...
    'v32_embedding_axes.csv'));
metric = {'Cores';'EmbeddingDimensions';'AllCandidates'; ...
    'EligibleCandidates';'UnaryEligible';'PairwiseEligible'; ...
    'ExactReferencePatterns';'CanonicalPatterns';'ComplementCollapses'; ...
    'MaximumCanonicalMultiplicity';'ConflictEdges';'ConflictDensity'; ...
    'ConflictComponents';'LargestConflictComponent'; ...
    'EmbeddingEntropyEffectiveRank';'CandidateEntropyEffectiveRank'; ...
    'BinaryEntropyEffectiveRank';'EnrollmentRowsUsed'; ...
    'ValidationRowsUsed';'DevelopmentRowsUsed';'FinalRowsUsed'};
value = [diagnostic.summary.numCores; ...
    diagnostic.summary.embeddingDimensions; ...
    diagnostic.summary.numCandidates; ...
    diagnostic.summary.numEligibleCandidates; ...
    diagnostic.summary.numUnaryEligible; ...
    diagnostic.summary.numPairwiseEligible; ...
    diagnostic.summary.numExactReferencePatterns; ...
    diagnostic.summary.numCanonicalPatterns; ...
    diagnostic.summary.numComplementCollapses; ...
    diagnostic.summary.maximumCanonicalMultiplicity; ...
    diagnostic.summary.conflictEdges; ...
    diagnostic.summary.conflictDensity; ...
    diagnostic.summary.numConflictComponents; ...
    diagnostic.summary.largestConflictComponent; ...
    diagnostic.rank.embeddingCoreMedians.entropyEffective; ...
    diagnostic.rank.eligibleCandidateMedians.entropyEffective; ...
    diagnostic.rank.eligibleReferenceBits.entropyEffective; ...
    diagnostic.integrity.enrollmentRowsUsed; ...
    diagnostic.integrity.validationRowsUsed; ...
    diagnostic.integrity.developmentRowsUsed; ...
    diagnostic.integrity.finalRowsUsed];
writetable(table(metric,value),fullfile(resultDirectory, ...
    'v32_representation_summary.csv'));
end

function localPrintDiagnostic(diagnostic)
fprintf('\n--- TrafoDNA V3.2 Representation Diagnostic ---\n');
fprintf('Eligible candidates                     : %d\n', ...
    diagnostic.summary.numEligibleCandidates);
fprintf('Unary / pairwise eligible               : %d / %d\n', ...
    diagnostic.summary.numUnaryEligible, ...
    diagnostic.summary.numPairwiseEligible);
fprintf('Exact reference patterns                : %d\n', ...
    diagnostic.summary.numExactReferencePatterns);
fprintf('Canonical patterns (sign ignored)       : %d\n', ...
    diagnostic.summary.numCanonicalPatterns);
fprintf('Largest canonical pattern multiplicity  : %d\n', ...
    diagnostic.summary.maximumCanonicalMultiplicity);
fprintf('Conflict edges / density                : %d / %.4f\n', ...
    diagnostic.summary.conflictEdges, ...
    diagnostic.summary.conflictDensity);
fprintf('Conflict components / largest           : %d / %d\n', ...
    diagnostic.summary.numConflictComponents, ...
    diagnostic.summary.largestConflictComponent);
fprintf('Embedding entropy effective rank        : %.3f\n', ...
    diagnostic.rank.embeddingCoreMedians.entropyEffective);
fprintf('Candidate entropy effective rank        : %.3f\n', ...
    diagnostic.rank.eligibleCandidateMedians.entropyEffective);
fprintf('Binary entropy effective rank           : %.3f\n', ...
    diagnostic.rank.eligibleReferenceBits.entropyEffective);
fprintf('Frozen thresholds reproduced            : %s\n', ...
    localYesNo(diagnostic.integrity.thresholdsReproduced));
fprintf('Frozen eligible count reproduced        : %s\n', ...
    localYesNo(diagnostic.integrity.eligibleCountReproduced));
fprintf('Locked final rows used                   : %d\n', ...
    diagnostic.integrity.finalRowsUsed);
fprintf(['Note: This diagnostic chooses no new bits and makes no new final ' ...
    'claim. Use its structure report to preregister the V3.2 representation.\n']);
end

function text = localYesNo(value)
if value
    text = 'YES';
else
    text = 'NO';
end
end
