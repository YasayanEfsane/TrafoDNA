function model = tuneIdentityModel(trainFeatures, trainIds, trainMetadata, ...
    validationFeatures, validationIds, validationMetadata, cfg)
%TUNEIDENTITYMODEL Select identity settings with condition-holdout validation.
%   When ConditionId is available, each known condition is excluded from a
%   candidate model and evaluated using validation repetitions of that held-
%   out condition. The final model is then refitted on all enrollment rows.

featureGrid = unique(cfg.identity.featureCountGrid(:)');
regularizationGrid = unique(cfg.identity.covarianceRegularizationGrid(:)');
if isfield(cfg.identity,'nuisanceComponentGrid')
    nuisanceGrid = unique(cfg.identity.nuisanceComponentGrid(:)');
else
    nuisanceGrid = 0;
end

useConditionHoldout = isfield(cfg.identity,'useConditionHoldoutTuning') && ...
    cfg.identity.useConditionHoldoutTuning && istable(trainMetadata) && ...
    istable(validationMetadata) && ...
    any(strcmp(trainMetadata.Properties.VariableNames,'ConditionId')) && ...
    any(strcmp(validationMetadata.Properties.VariableNames,'ConditionId'));
if useConditionHoldout
    conditions = intersect(unique(trainMetadata.ConditionId), ...
        unique(validationMetadata.ConditionId));
    useConditionHoldout = numel(conditions) > 1;
else
    conditions = [];
end

if useConditionHoldout
    tuningStrategy = 'leave_one_condition_out';
else
    tuningStrategy = 'repeat_group_validation';
    conditions = NaN;
end

numCandidates = numel(featureGrid)*numel(regularizationGrid)*numel(nuisanceGrid);
candidateFeatureCount = zeros(numCandidates,1);
candidateRegularization = zeros(numCandidates,1);
candidateNuisanceComponents = zeros(numCandidates,1);
candidateMeanAccuracy = zeros(numCandidates,1);
candidateWorstAccuracy = zeros(numCandidates,1);
candidateMeanEER = zeros(numCandidates,1);
candidateObjective = zeros(numCandidates,1);

worstCaseWeight = min(max(cfg.identity.conditionWorstCaseWeight,0),1);
bestObjective = -Inf;
bestWorstAccuracy = -Inf;
bestEER = Inf;
bestFeatureCount = featureGrid(1);
bestRegularization = regularizationGrid(1);
bestNuisanceComponents = nuisanceGrid(1);
row = 0;

for featureCount = featureGrid
    for regularization = regularizationGrid
        for nuisanceComponents = nuisanceGrid
            row = row+1;
            foldAccuracy = zeros(numel(conditions),1);
            foldEER = zeros(numel(conditions),1);
            for fold = 1:numel(conditions)
                if useConditionHoldout
                    fitMask = trainMetadata.ConditionId ~= conditions(fold);
                    evaluationMask = validationMetadata.ConditionId == conditions(fold);
                else
                    fitMask = true(size(trainIds));
                    evaluationMask = true(size(validationIds));
                end

                trialCfg = cfg;
                trialCfg.identity.maxFeatures = featureCount;
                trialCfg.identity.covarianceRegularization = regularization;
                trialCfg.identity.nuisanceComponents = nuisanceComponents;
                trialModel = trainIdentityModel(trainFeatures(fitMask,:), ...
                    trainIds(fitMask),trainMetadata(fitMask,:),trialCfg);
                [prediction,confidence,distances] = predictIdentity(trialModel, ...
                    validationFeatures(evaluationMask,:), ...
                    validationMetadata(evaluationMask,:));
                metrics = computeVerificationMetrics(prediction, ...
                    validationIds(evaluationMask),confidence,distances, ...
                    trialModel.coreIds);
                foldAccuracy(fold) = metrics.accuracy;
                foldEER(fold) = metrics.eer;
            end

            meanAccuracy = mean(foldAccuracy);
            worstAccuracy = min(foldAccuracy);
            meanEER = mean(foldEER);
            robustAccuracy = (1-worstCaseWeight)*meanAccuracy + ...
                worstCaseWeight*worstAccuracy;
            objective = robustAccuracy-cfg.identity.validationEERWeight*meanEER;

            candidateFeatureCount(row) = featureCount;
            candidateRegularization(row) = regularization;
            candidateNuisanceComponents(row) = nuisanceComponents;
            candidateMeanAccuracy(row) = meanAccuracy;
            candidateWorstAccuracy(row) = worstAccuracy;
            candidateMeanEER(row) = meanEER;
            candidateObjective(row) = objective;

            isBetter = objective > bestObjective+1e-12 || ...
                (abs(objective-bestObjective) <= 1e-12 && ...
                worstAccuracy > bestWorstAccuracy+1e-12) || ...
                (abs(objective-bestObjective) <= 1e-12 && ...
                abs(worstAccuracy-bestWorstAccuracy) <= 1e-12 && meanEER < bestEER);
            if isBetter
                bestObjective = objective;
                bestWorstAccuracy = worstAccuracy;
                bestEER = meanEER;
                bestFeatureCount = featureCount;
                bestRegularization = regularization;
                bestNuisanceComponents = nuisanceComponents;
            end
        end
    end
end

finalCfg = cfg;
finalCfg.identity.maxFeatures = bestFeatureCount;
finalCfg.identity.covarianceRegularization = bestRegularization;
finalCfg.identity.nuisanceComponents = bestNuisanceComponents;
model = trainIdentityModel(trainFeatures,trainIds,trainMetadata,finalCfg);
model.tuningResults = table(candidateFeatureCount,candidateRegularization, ...
    candidateNuisanceComponents,candidateMeanAccuracy,candidateWorstAccuracy, ...
    candidateMeanEER,candidateObjective, ...
    'VariableNames',{'FeatureCount','CovarianceRegularization', ...
    'NuisanceComponents','MeanValidationAccuracy','WorstConditionAccuracy', ...
    'MeanValidationEER','Objective'});
model.tuningObjective = bestObjective;
model.tuningStrategy = tuningStrategy;
end
