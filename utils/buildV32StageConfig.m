function stageCfg = buildV32StageConfig(cfg,stage)
%BUILDV32STAGECONFIG Restrict generation to one sealed V3.2 stage.
%   Development excludes all final conditions. Final contains only the
%   preregistered final IDs and is intended solely for MAIN_V32_FINAL.

if ~(ischar(stage) || (isstring(stage) && isscalar(stage)))
    error('TrafoDNA:InvalidV32Stage','V3.2 stage must be text.');
end
stage = lower(char(stage));
conditions = cfg.dataset.conditions;
conditionIds = [conditions.id];
finalIds = cfg.dataset.finalHoldoutConditionIds;
if numel(unique(conditionIds)) ~= numel(conditionIds) || ...
        ~all(ismember(finalIds,conditionIds))
    error('TrafoDNA:InvalidV32ConditionContract', ...
        'V3.2 condition IDs are duplicated or final IDs are missing.');
end

switch stage
    case 'development'
        keep = ~ismember(conditionIds,finalIds);
        if any([conditions(keep).isFinalHoldout])
            error('TrafoDNA:V32FinalFlagLeakage', ...
                'A development condition is marked as final.');
        end
    case 'final'
        keep = ismember(conditionIds,finalIds);
        if ~all([conditions(keep).isFinalHoldout]) || ...
                any([conditions(keep).isUnseen])
            error('TrafoDNA:InvalidV32FinalFlags', ...
                'Final conditions must be final-only and not development.');
        end
    otherwise
        error('TrafoDNA:InvalidV32Stage', ...
            'V3.2 stage must be "development" or "final".');
end

stageCfg = cfg;
stageCfg.dataset.conditions = conditions(keep);
stageCfg.dataset.numConditions = nnz(keep);
if isempty(stageCfg.dataset.conditions)
    error('TrafoDNA:EmptyV32Stage','The requested V3.2 stage is empty.');
end
end
