function [residualized, model] = fitOperatingConditionNormalizer(features, metadata, cfg)
%FITOPERATINGCONDITIONNORMALIZER Learn removable measurement-condition effects.
%   The linear ridge model is fitted only on enrollment data. It uses
%   measurable operating variables and deliberately excludes stress, ageing,
%   health labels, and core identity.

model.enabled = false;
model.variableNames = {};
model.variableMean = [];
model.variableStd = [];
model.activeVariables = [];
model.coefficients = [];
model.ridge = 0;
residualized = features;

if ~isfield(cfg.identity, 'removeOperatingConditionEffects') || ...
        ~cfg.identity.removeOperatingConditionEffects || isempty(metadata)
    return;
end
if ~istable(metadata) || height(metadata) ~= size(features,1)
    error('TrafoDNA:InvalidConditionMetadata', ...
        'Condition metadata must be a table with one row per feature row.');
end

variableNames = cfg.identity.nuisanceVariables;
raw = localReadVariables(metadata, variableNames);
variableMean = mean(raw, 1);
variableStd = std(raw, 0, 1);
active = variableStd > 1e-12 & all(isfinite(raw), 1);
if ~any(active)
    return;
end

z = (raw(:,active) - variableMean(active)) ./ variableStd(active);
design = [ones(size(z,1),1) z];
ridge = max(cfg.identity.nuisanceRidge, 0);
penalty = eye(size(design,2));
penalty(1,1) = 0;
scaledPenalty = ridge * size(design,1) * penalty;
coefficients = (design' * design + scaledPenalty) \ (design' * features);
residualized = features - design * coefficients;
residualized(~isfinite(residualized)) = 0;

model.enabled = true;
model.variableNames = variableNames;
model.variableMean = variableMean;
model.variableStd = variableStd;
model.activeVariables = active;
model.coefficients = coefficients;
model.ridge = ridge;
end

function raw = localReadVariables(metadata, variableNames)
raw = zeros(height(metadata), numel(variableNames));
available = metadata.Properties.VariableNames;
for k = 1:numel(variableNames)
    name = variableNames{k};
    if ~any(strcmp(available, name))
        error('TrafoDNA:MissingConditionVariable', ...
            'Condition metadata is missing variable "%s".', name);
    end
    values = metadata.(name);
    if ~isnumeric(values) || size(values,2) ~= 1
        error('TrafoDNA:InvalidConditionVariable', ...
            'Condition variable "%s" must be a numeric column.', name);
    end
    raw(:,k) = double(values);
end
end
