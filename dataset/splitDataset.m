function splits = splitDataset(metadata, cfg)
%SPLITDATASET Create disjoint repeat-group and unseen-condition partitions.
%   Conditions listed in CFG.DATASET.UNSEENCONDITIONIDS never enter training,
%   validation, or the ordinary test set.

knownCondition = ~metadata.IsUnseenCondition;
splits.train = knownCondition & ismember(metadata.RepeatId, cfg.dataset.trainRepeats);
splits.validation = knownCondition & ismember(metadata.RepeatId, cfg.dataset.validationRepeats);
splits.test = knownCondition & ismember(metadata.RepeatId, cfg.dataset.testRepeats);
splits.unseen = metadata.IsUnseenCondition;

combined = double(splits.train) + double(splits.validation) + ...
    double(splits.test) + double(splits.unseen);
if any(combined > 1)
    error('TrafoDNA:DataLeakage', 'Dataset partitions overlap.');
end
if ~any(splits.train) || ~any(splits.validation) || ~any(splits.test) || ~any(splits.unseen)
    error('TrafoDNA:EmptyPartition', ...
        'Train, validation, test, and unseen partitions must be nonempty.');
end
end
