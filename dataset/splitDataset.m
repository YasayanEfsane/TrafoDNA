function splits = splitDataset(metadata, cfg)
%SPLITDATASET Create disjoint known, development, and final partitions.
%   Development and final holdout conditions never enter enrollment,
%   validation, or the ordinary known-condition test set.

if any(strcmp(metadata.Properties.VariableNames,'IsFinalHoldoutCondition'))
    finalHoldoutCondition = metadata.IsFinalHoldoutCondition;
else
    finalHoldoutCondition = false(height(metadata),1);
end
developmentHoldoutCondition = metadata.IsUnseenCondition;
if any(finalHoldoutCondition & developmentHoldoutCondition)
    error('TrafoDNA:HoldoutOverlap', ...
        'Development and final holdout conditions must be disjoint.');
end
knownCondition = ~(developmentHoldoutCondition | finalHoldoutCondition);
splits.train = knownCondition & ismember(metadata.RepeatId, cfg.dataset.trainRepeats);
splits.validation = knownCondition & ismember(metadata.RepeatId, cfg.dataset.validationRepeats);
splits.test = knownCondition & ismember(metadata.RepeatId, cfg.dataset.testRepeats);
splits.unseen = developmentHoldoutCondition;
splits.finalHoldout = finalHoldoutCondition;

combined = double(splits.train) + double(splits.validation) + ...
    double(splits.test) + double(splits.unseen) + double(splits.finalHoldout);
if any(combined > 1)
    error('TrafoDNA:DataLeakage', 'Dataset partitions overlap.');
end
if ~any(splits.train) || ~any(splits.validation) || ~any(splits.test) || ~any(splits.unseen)
    error('TrafoDNA:EmptyPartition', ...
        'Train, validation, test, and unseen partitions must be nonempty.');
end
if isfield(cfg.dataset,'finalHoldoutConditionIds') && ...
        any(ismember(cfg.dataset.finalHoldoutConditionIds,metadata.ConditionId)) && ...
        ~any(splits.finalHoldout)
    error('TrafoDNA:EmptyFinalHoldout', ...
        'Configured final-holdout conditions produced no samples.');
end
end
