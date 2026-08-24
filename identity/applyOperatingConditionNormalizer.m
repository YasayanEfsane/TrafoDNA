function residualized = applyOperatingConditionNormalizer(model, features, metadata)
%APPLYOPERATINGCONDITIONNORMALIZER Apply an enrollment-fitted nuisance model.

if ~model.enabled
    residualized = features;
    return;
end
if nargin < 3 || isempty(metadata) || ~istable(metadata) || ...
        height(metadata) ~= size(features,1)
    error('TrafoDNA:ConditionMetadataRequired', ...
        ['This identity model requires a condition-metadata table with one ' ...
         'row per query measurement.']);
end

raw = zeros(height(metadata), numel(model.variableNames));
available = metadata.Properties.VariableNames;
for k = 1:numel(model.variableNames)
    name = model.variableNames{k};
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

active = model.activeVariables;
z = (raw(:,active) - model.variableMean(active)) ./ model.variableStd(active);
design = [ones(size(z,1),1) z];
residualized = features - design * model.coefficients;
residualized(~isfinite(residualized)) = 0;
end
