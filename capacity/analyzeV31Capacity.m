function audit = analyzeV31Capacity(activeResults,options)
%ANALYZEV31CAPACITY Audit the post-V3 eligible-bit correlation graph.
%   AUDIT = ANALYZEV31CAPACITY(ACTIVERESULTS) reconstructs the V3 raw-bit
%   eligibility screen from enrollment and validation rows only. It compares
%   the frozen score-ordered greedy selector with deterministic degree-aware,
%   multistart, and bounded target-search strategies without changing the
%   reliability, balance, correlation, or fallback rules.
%
%   This is a post-V3 development audit. It never uses V3 final-holdout rows
%   for candidate construction, selection, or development metrics, and it
%   cannot change the locked V3 NOT SUPPORTED decision.

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
developmentMask = logical(splits.test(:) | splits.unseen(:));
finalMask = logical(splits.finalHoldout(:));
if any(trainMask & finalMask) || any(validationMask & finalMask) || ...
        any(developmentMask & finalMask)
    error('TrafoDNA:V31PartitionLeakage', ...
        'V3.1 capacity-audit partitions overlap the locked final rows.');
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

coreMedians = zeros(numCores,numCandidates);
for k = 1:numCores
    selected = trainCoreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:V31MissingEnrollmentCore', ...
            'Every PUF core must appear in the enrollment partition.');
    end
    coreMedians(k,:) = median(trainValues(selected,:),1);
end
thresholds = median(coreMedians,1);
referenceBitsAll = coreMedians > thresholds;

enrollmentReliabilityByCore = zeros(numCores,numCandidates);
for k = 1:numCores
    sampleBits = trainValues(trainCoreIds == labels(k),:) > thresholds;
    enrollmentReliabilityByCore(k,:) = mean(sampleBits == ...
        referenceBitsAll(k,:),1);
end
meanEnrollmentReliability = mean(enrollmentReliabilityByCore,1);
[meanValidationReliability,worstConditionReliability, ...
    validationReliabilityByCore] = localValidationReliability( ...
    validationValues,validationCoreIds,validationMetadata,thresholds, ...
    labels,referenceBitsAll);

bitAlias = mean(referenceBitsAll,1);
candidateMedian = median(trainValues,1);
robustScale = median(abs(trainValues-candidateMedian),1)/0.6744897501960817;
robustScale = max(robustScale,1e-6);
normalizedMargin = mean(abs(coreMedians-thresholds)./robustScale,1);
aliasRange = cfg.puf.bitAliasRange;
balanced = bitAlias >= aliasRange(1) & bitAlias <= aliasRange(2);
eligible = meanEnrollmentReliability >= cfg.puf.minimumBitReliability & ...
    meanValidationReliability >= cfg.puf.minimumValidationReliability & ...
    worstConditionReliability >= ...
    cfg.puf.minimumWorstConditionReliability & balanced;
selectionReliability = min([meanEnrollmentReliability; ...
    meanValidationReliability;worstConditionReliability],[],1);
weights = localSelectionWeights(cfg);
selectionScore = weights.enrollmentReliability* ...
    meanEnrollmentReliability + ...
    weights.validationReliability*meanValidationReliability + ...
    weights.worstConditionReliability*worstConditionReliability - ...
    weights.aliasPenalty*abs(bitAlias-0.5) + ...
    weights.marginReward*min(normalizedMargin,4);

eligibleIndices = find(eligible);
if isempty(eligibleIndices)
    error('TrafoDNA:V31NoEligibleCandidates', ...
        'No candidates passed the frozen V3 eligibility screen.');
end
[~,rankOrder] = sort(selectionScore(eligibleIndices),'descend');
rankedEligibleIndices = eligibleIndices(rankOrder);
[~,rankedPositions] = ismember(rankedEligibleIndices,eligibleIndices);

[correlationMatrix,conflictGraph] = localCorrelationGraph( ...
    referenceBitsAll(:,eligibleIndices), ...
    cfg.puf.maximumReferenceCorrelation);
quality = localNormalize(selectionScore(eligibleIndices));
maximumBits = min([options.maximumBits,numel(eligibleIndices)]);

frozenNodes = localGreedyOrder(conflictGraph,rankedPositions,maximumBits);
degreeNodes = localDynamicGreedy(conflictGraph,quality,maximumBits,0,0,false);
degreeNodes = localOneForTwoImprove(conflictGraph,degreeNodes, ...
    quality,maximumBits);
bestNodes = localChooseBetter(frozenNodes,degreeNodes,quality);

previousRng = rng;
cleanup = onCleanup(@() rng(previousRng));
rng(options.randomSeed,'twister');
for forced = 1:numel(eligibleIndices)
    candidate = localDynamicGreedy(conflictGraph,quality,maximumBits, ...
        forced,0,false);
    bestNodes = localChooseBetter(bestNodes,candidate,quality);
end
for start = 1:options.randomStarts
    candidate = localDynamicGreedy(conflictGraph,quality,maximumBits, ...
        0,options.randomDegreeWindow,true);
    bestNodes = localChooseBetter(bestNodes,candidate,quality);
end
bestNodes = localOneForTwoImprove(conflictGraph,bestNodes, ...
    quality,maximumBits);
clear cleanup

search = localTargetSearch(conflictGraph,bestNodes,options.targetBits, ...
    maximumBits,quality,options.exactSearchSeconds, ...
    options.exactSearchNodeLimit);
bestNodes = localChooseBetter(bestNodes,search.bestNodes,quality);
selectedGlobalIndices = eligibleIndices(bestNodes);
selectedMask = false(1,numCandidates);
selectedMask(selectedGlobalIndices) = true;
localAssertIndependent(conflictGraph,bestNodes);

auditModel = frozenModel;
auditModel.selectedBits = selectedMask;
auditModel.referenceBits = referenceBitsAll(:,selectedMask);
auditModel.enrollmentReliability = ...
    enrollmentReliabilityByCore(:,selectedMask);
auditModel.validationReliability = ...
    validationReliabilityByCore(:,selectedMask);
auditModel.meanValidationReliability = ...
    meanValidationReliability(selectedMask);
auditModel.worstConditionReliability = ...
    worstConditionReliability(selectedMask);
auditModel.selectionReliability = selectionReliability(selectedMask);
auditModel.bitAliasEnrollment = bitAlias(selectedMask);
auditModel.selectionScore = selectionScore(selectedMask);
auditModel.selectionWeights = weights;
auditModel.numEligibleCandidates = sum(eligible);
auditModel.numSelectedEligibleBits = sum(selectedMask);
auditModel.numFallbackBits = 0;
auditModel.allowFallbackToMinimum = false;
auditModel.selectionMethod = 'v31_correlation_graph_audit';

developmentMetrics = evaluatePUF(auditModel,features(developmentMask,:), ...
    metadata.CoreId(developmentMask),metadata(developmentMask,:));
[worstDevelopmentReliability,developmentByCondition] = ...
    computeWorstConditionPUFReliability(auditModel, ...
    features(developmentMask,:),metadata.CoreId(developmentMask), ...
    metadata(developmentMask,:));
[developmentSessionMetrics,~] = evaluatePUFSessions(auditModel, ...
    features(developmentMask,:),metadata(developmentMask,:), ...
    cfg.session.readsPerDecision);

frozenEligibleMask = logical(frozenModel.selectedBits) & eligible;
frozenGraphMask = false(1,numCandidates);
frozenGraphMask(eligibleIndices(frozenNodes)) = true;
thresholdScale = max([1 abs(frozenModel.thresholds(:)')]);
thresholdDifference = max(abs(thresholds-frozenModel.thresholds));
thresholdsReproduced = thresholdDifference <= 1e-10*thresholdScale;
frozenSelectionMatches = isequal(frozenGraphMask,frozenEligibleMask);

selectedTable = localSelectedTable(activeResults,pufTransform, ...
    selectedGlobalIndices,firstIndex,secondIndex,selectionScore, ...
    meanEnrollmentReliability,meanValidationReliability, ...
    worstConditionReliability,bitAlias,correlationMatrix,bestNodes);
[edgeFirst,edgeSecond] = find(triu(conflictGraph,1));
firstEdgeCandidate = eligibleIndices(edgeFirst);
secondEdgeCandidate = eligibleIndices(edgeSecond);
edgeCorrelation = correlationMatrix(sub2ind(size(correlationMatrix), ...
    edgeFirst,edgeSecond));
edgeTable = table(firstEdgeCandidate(:),secondEdgeCandidate(:), ...
    edgeCorrelation(:), ...
    'VariableNames',{'FirstCandidateIndex','SecondCandidateIndex', ...
    'ReferenceCorrelation'});

audit.study = 'TrafoDNA V3.1 post-V3 capacity development audit';
audit.status = 'development_only_no_new_final_claim';
audit.options = options;
audit.eligibility.numCandidates = numCandidates;
audit.eligibility.numBalancedCandidates = sum(balanced);
audit.eligibility.numEligibleCandidates = sum(eligible);
audit.eligibility.eligibleCandidateIndices = eligibleIndices;
audit.graph.maximumAbsoluteCorrelation = ...
    cfg.puf.maximumReferenceCorrelation;
audit.graph.correlationMatrix = correlationMatrix;
audit.graph.conflictGraph = conflictGraph;
audit.graph.conflictEdges = height(edgeTable);
audit.graph.conflictDensity = 2*height(edgeTable)/ ...
    max(numel(eligibleIndices)*(numel(eligibleIndices)-1),1);
audit.graph.edgeTable = edgeTable;
audit.selection.frozenGreedyCount = numel(frozenNodes);
audit.selection.degreeAwareCount = numel(degreeNodes);
audit.selection.bestCount = numel(bestNodes);
audit.selection.targetBits = options.targetBits;
audit.selection.targetReached = numel(bestNodes) >= options.targetBits;
audit.selection.selectedCandidateIndices = selectedGlobalIndices;
audit.selection.selectedBits = selectedTable;
audit.selection.search = search;
audit.development.singleSweep = developmentMetrics;
audit.development.worstConditionReliability = ...
    worstDevelopmentReliability;
audit.development.byCondition = developmentByCondition;
audit.development.multiSweep = developmentSessionMetrics;
audit.integrity.finalRowsUsed = 0;
audit.integrity.thresholdDifference = thresholdDifference;
audit.integrity.thresholdsReproduced = thresholdsReproduced;
audit.integrity.frozenSelectionMatches = frozenSelectionMatches;
audit.integrity.lockedV3Decision = 'NOT SUPPORTED';
audit.selectedModel = auditModel;

if options.saveResults
    localSaveAudit(audit,cfg,options);
end
if options.verbose
    localPrintAudit(audit);
end
end

function localValidateResults(results)
required = {'cfg','features','featureNames','metadata','splits', ...
    'pufIdentityModel','pufModel'};
for k = 1:numel(required)
    if ~isfield(results,required{k})
        error('TrafoDNA:V31MissingResultField', ...
            'Active results are missing field "%s".',required{k});
    end
end
if ~istable(results.metadata) || ...
        height(results.metadata) ~= size(results.features,1)
    error('TrafoDNA:V31InvalidMetadata', ...
        'Active feature rows and metadata must agree.');
end
end

function options = localOptions(options,cfg)
defaults.targetBits = cfg.puf.minimumSelectedBits;
defaults.maximumBits = cfg.puf.maximumSelectedBits;
defaults.randomStarts = 512;
defaults.randomDegreeWindow = 2;
defaults.randomSeed = 20260831;
defaults.exactSearchSeconds = 20;
defaults.exactSearchNodeLimit = 2.0e6;
defaults.saveResults = true;
defaults.verbose = true;
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
validateattributes(options.targetBits,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
validateattributes(options.maximumBits,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
validateattributes(options.randomStarts,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'});
validateattributes(options.randomDegreeWindow,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'});
validateattributes(options.randomSeed,{'numeric'}, ...
    {'scalar','integer','nonnegative','finite'});
validateattributes(options.exactSearchSeconds,{'numeric'}, ...
    {'scalar','nonnegative','finite'});
validateattributes(options.exactSearchNodeLimit,{'numeric'}, ...
    {'scalar','integer','positive','finite'});
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

function [meanReliability,worstReliability,reliabilityByCore] = ...
    localValidationReliability(values,coreIds,metadata,thresholds,labels, ...
    referenceBits)
bits = values > thresholds;
agreement = false(size(bits));
reliabilityByCore = zeros(numel(labels),numel(thresholds));
for k = 1:numel(labels)
    selected = coreIds == labels(k);
    if ~any(selected)
        error('TrafoDNA:V31MissingValidationCore', ...
            'Every enrolled core must appear in PUF validation data.');
    end
    agreement(selected,:) = bits(selected,:) == referenceBits(k,:);
    reliabilityByCore(k,:) = mean(agreement(selected,:),1);
end
meanReliability = mean(agreement,1);
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

function normalized = localNormalize(values)
minimum = min(values);
span = max(values)-minimum;
if span <= eps
    normalized = ones(size(values));
else
    normalized = (values-minimum)/span;
end
normalized = normalized(:);
end

function selected = localGreedyOrder(conflict,order,limit)
selected = zeros(1,0);
blocked = false(size(conflict,1),1);
for node = order(:)'
    if ~blocked(node)
        selected(end+1) = node; %#ok<AGROW>
        blocked(node) = true;
        blocked(conflict(:,node)) = true;
        if numel(selected) >= limit
            break;
        end
    end
end
end

function selected = localDynamicGreedy(conflict,quality,limit,forced, ...
    degreeWindow,randomized)
nodeCount = size(conflict,1);
remaining = true(nodeCount,1);
degree = sum(conflict,2);
selected = zeros(1,0);
if forced > 0
    [selected,remaining,degree] = localAcceptNode(selected,remaining, ...
        degree,conflict,forced);
end
while any(remaining) && numel(selected) < limit
    candidates = find(remaining);
    candidateDegree = degree(candidates);
    minimumDegree = min(candidateDegree);
    if randomized
        pool = candidates(candidateDegree <= minimumDegree+degreeWindow);
        utility = quality(pool)-0.20*(degree(pool)-minimumDegree) + ...
            0.35*randn(numel(pool),1);
        [~,position] = max(utility);
        chosen = pool(position);
    else
        pool = candidates(candidateDegree == minimumDegree);
        [~,position] = max(quality(pool));
        chosen = pool(position);
    end
    [selected,remaining,degree] = localAcceptNode(selected,remaining, ...
        degree,conflict,chosen);
end
end

function [selected,remaining,degree] = localAcceptNode(selected,remaining, ...
    degree,conflict,node)
if ~remaining(node)
    return;
end
selected(end+1) = node;
remove = remaining & (conflict(:,node) | ...
    ((1:size(conflict,1))' == node));
removed = find(remove);
remaining(removed) = false;
degree = degree-sum(conflict(:,removed),2);
degree(~remaining) = inf;
end

function selected = localOneForTwoImprove(conflict,selected,quality,limit)
selectedMask = false(size(conflict,1),1);
selectedMask(selected) = true;
changed = true;
while changed && sum(selectedMask) < limit
    changed = false;
    current = find(selectedMask)';
    unselected = find(~selectedMask)';
    for removedNode = current
        retained = current(current ~= removedNode);
        candidates = unselected;
        if ~isempty(retained)
            candidates = candidates(~any(conflict(candidates,retained),2));
        end
        if numel(candidates) < 2
            continue;
        end
        bestPair = zeros(1,0);
        bestQuality = -inf;
        for firstPosition = 1:numel(candidates)-1
            first = candidates(firstPosition);
            seconds = candidates(firstPosition+1:end);
            seconds = seconds(~conflict(first,seconds));
            if isempty(seconds)
                continue;
            end
            [secondQuality,position] = max(quality(seconds));
            pairQuality = quality(first)+secondQuality;
            if pairQuality > bestQuality
                bestQuality = pairQuality;
                bestPair = [first seconds(position)];
            end
        end
        if ~isempty(bestPair)
            selectedMask(removedNode) = false;
            selectedMask(bestPair) = true;
            changed = true;
            break;
        end
    end
end
selected = find(selectedMask)';
end

function best = localChooseBetter(first,second,quality)
if numel(second) > numel(first)
    best = second;
elseif numel(second) < numel(first)
    best = first;
elseif sum(quality(second)) > sum(quality(first))
    best = second;
else
    best = first;
end
best = best(:)';
end

function search = localTargetSearch(conflict,initial,target,maximumBits, ...
    quality,maxSeconds,maxNodes)
bestNodes = initial(:)';
targetFound = numel(bestNodes) >= target;
limitReached = false;
nodesVisited = 0;
searchStart = tic;
compatibility = ~conflict;
compatibility(1:size(compatibility,1)+1:end) = false;

searchAttempted = ~targetFound && maxSeconds > 0;
if searchAttempted
    candidates = 1:size(conflict,1);
    expand(zeros(1,0),candidates);
end
completed = searchAttempted && ~limitReached && ~targetFound;
if targetFound
    status = 'target_reached';
elseif completed
    status = 'exhaustive_maximum_below_target';
elseif maxSeconds <= 0
    status = 'exact_search_disabled';
else
    status = 'search_limit_reached';
end
search.status = status;
search.targetFound = targetFound;
search.completedExhaustively = completed;
search.bestNodes = bestNodes;
search.bestCount = numel(bestNodes);
search.nodesVisited = nodesVisited;
search.elapsedSeconds = toc(searchStart);

    function expand(current,candidates)
        if targetFound || limitReached
            return;
        end
        nodesVisited = nodesVisited+1;
        if nodesVisited > maxNodes || toc(searchStart) > maxSeconds
            limitReached = true;
            return;
        end
        [order,colorBound] = localColorSort(compatibility,candidates,quality);
        for position = numel(order):-1:1
            if numel(current)+colorBound(position) <= numel(bestNodes)
                return;
            end
            node = order(position);
            nextCurrent = [current node]; %#ok<AGROW>
            if numel(nextCurrent) > numel(bestNodes)
                bestNodes = nextCurrent;
                if numel(bestNodes) >= target || numel(bestNodes) >= maximumBits
                    targetFound = numel(bestNodes) >= target;
                    return;
                end
            end
            nextCandidates = candidates(compatibility(node,candidates));
            if ~isempty(nextCandidates)
                expand(nextCurrent,nextCandidates);
                if targetFound || limitReached
                    return;
                end
            end
            candidates(candidates == node) = [];
        end
    end
end

function [order,colorBound] = localColorSort(compatibility,candidates,quality)
uncolored = candidates(:)';
order = zeros(1,0);
colorBound = zeros(1,0);
color = 0;
while ~isempty(uncolored)
    color = color+1;
    available = uncolored;
    while ~isempty(available)
        degree = sum(compatibility(available,uncolored),2);
        utility = degree+1e-6*quality(available);
        [~,position] = max(utility);
        node = available(position);
        order(end+1) = node; %#ok<AGROW>
        colorBound(end+1) = color; %#ok<AGROW>
        uncolored(uncolored == node) = [];
        available(available == node | compatibility(node,available)) = [];
    end
end
end

function localAssertIndependent(conflict,nodes)
if nnz(triu(conflict(nodes,nodes),1)) > 0
    error('TrafoDNA:V31InvalidIndependentSet', ...
        'The V3.1 selector returned mutually conflicting bits.');
end
end

function selectedTable = localSelectedTable(activeResults,pufTransform, ...
    selectedIndices,firstIndex,secondIndex,score,enrollmentReliability, ...
    validationReliability,worstReliability,alias,correlation,bestNodes)
featureNames = activeResults.featureNames;
activeFeatureIndices = find(pufTransform.activeFeatures);
sourceIndices = activeFeatureIndices(pufTransform.selectedFeatures);
embeddingNames = featureNames(sourceIndices);
candidateIndex = selectedIndices(:);
firstEmbeddingIndex = firstIndex(candidateIndex);
secondEmbeddingIndex = secondIndex(candidateIndex);
firstNames = embeddingNames(firstEmbeddingIndex);
firstNames = firstNames(:);
secondNames = repmat({'<unary>'},numel(candidateIndex),1);
paired = secondEmbeddingIndex > 0;
if any(paired)
    pairedNames = embeddingNames(secondEmbeddingIndex(paired));
    secondNames(paired) = pairedNames(:);
end
selectedCorrelation = abs(correlation(bestNodes,bestNodes));
selectedCorrelation(1:size(selectedCorrelation,1)+1:end) = 0;
maximumCorrelation = max(selectedCorrelation,[],2);
selectedTable = table(candidateIndex,firstEmbeddingIndex(:), ...
    secondEmbeddingIndex(:),firstNames,secondNames, ...
    reshape(score(candidateIndex),[],1), ...
    reshape(enrollmentReliability(candidateIndex),[],1), ...
    reshape(validationReliability(candidateIndex),[],1), ...
    reshape(worstReliability(candidateIndex),[],1), ...
    reshape(alias(candidateIndex),[],1), ...
    maximumCorrelation, ...
    'VariableNames',{'CandidateIndex','FirstEmbeddingIndex', ...
    'SecondEmbeddingIndex','FirstFeature','SecondFeature','SelectionScore', ...
    'EnrollmentReliability','ValidationReliability', ...
    'WorstKnownConditionReliability','EnrollmentBitAlias', ...
    'MaximumSelectedBitCorrelation'});
end

function localSaveAudit(audit,cfg,options)
resultDirectory = fullfile(cfg.projectRoot,'results_v31');
if isfield(options,'resultDirectory') && ~isempty(options.resultDirectory)
    resultDirectory = options.resultDirectory;
end
if ~exist(resultDirectory,'dir')
    mkdir(resultDirectory);
end
save(fullfile(resultDirectory,'v31_capacity_audit.mat'),'audit','-v7.3');
writetable(audit.selection.selectedBits,fullfile(resultDirectory, ...
    'v31_selected_bits.csv'));
writetable(audit.graph.edgeTable,fullfile(resultDirectory, ...
    'v31_correlation_edges.csv'));
metric = {'EligibleCandidates';'FrozenGreedyBits';'DegreeAwareBits'; ...
    'BestIndependentBits';'TargetBits';'TargetReached'; ...
    'DevelopmentReliability';'DevelopmentUniqueness'; ...
    'WorstDevelopmentReliability';'ThreeSweepReliability'; ...
    'FinalRowsUsed'};
value = [audit.eligibility.numEligibleCandidates; ...
    audit.selection.frozenGreedyCount;audit.selection.degreeAwareCount; ...
    audit.selection.bestCount;audit.selection.targetBits; ...
    double(audit.selection.targetReached); ...
    audit.development.singleSweep.reliability; ...
    audit.development.singleSweep.uniqueness; ...
    audit.development.worstConditionReliability; ...
    audit.development.multiSweep.reliability; ...
    audit.integrity.finalRowsUsed];
writetable(table(metric,value),fullfile(resultDirectory, ...
    'v31_capacity_summary.csv'));
end

function localPrintAudit(audit)
fprintf('\n--- TrafoDNA V3.1 Capacity Development Audit ---\n');
fprintf('Eligible candidates before correlation : %d\n', ...
    audit.eligibility.numEligibleCandidates);
fprintf('Frozen score-greedy retained bits       : %d\n', ...
    audit.selection.frozenGreedyCount);
fprintf('Degree-aware retained bits              : %d\n', ...
    audit.selection.degreeAwareCount);
fprintf('Best admissible set found               : %d\n', ...
    audit.selection.bestCount);
fprintf('Target                                   : %d\n', ...
    audit.selection.targetBits);
fprintf('Target reached                           : %s\n', ...
    localYesNo(audit.selection.targetReached));
fprintf('Bounded search status                    : %s\n', ...
    audit.selection.search.status);
fprintf('Development PUF reliability             : %.4f\n', ...
    audit.development.singleSweep.reliability);
fprintf('Development PUF uniqueness              : %.4f\n', ...
    audit.development.singleSweep.uniqueness);
fprintf('Worst-development-scenario reliability  : %.4f\n', ...
    audit.development.worstConditionReliability);
fprintf('Three-sweep development reliability     : %.4f\n', ...
    audit.development.multiSweep.reliability);
fprintf('Frozen thresholds reproduced            : %s\n', ...
    localYesNo(audit.integrity.thresholdsReproduced));
fprintf('Frozen selected set reproduced          : %s\n', ...
    localYesNo(audit.integrity.frozenSelectionMatches));
fprintf('Locked final rows used                   : %d\n', ...
    audit.integrity.finalRowsUsed);
fprintf(['Note: This is post-V3 development evidence. It does not alter the ' ...
    'locked V3 decision and is not a new final-holdout claim.\n']);
end

function text = localYesNo(value)
if value
    text = 'YES';
else
    text = 'NO';
end
end
