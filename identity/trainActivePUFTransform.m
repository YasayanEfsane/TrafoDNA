function model = trainActivePUFTransform(features,coreIds,metadata,cfg)
%TRAINACTIVEPUFTRANSFORM Fit the fixed V3 PUF-stability representation.
%   This transform is separate from the identity classifier because raw-bit
%   stability and multiclass accuracy have different objectives. All
%   coefficients, nuisance directions, and feature rankings use enrollment
%   rows only; validation rows are reserved for later bit screening.

required = {'transformFeatureCount','transformNuisanceComponents', ...
    'transformCovarianceRegularization'};
for k = 1:numel(required)
    if ~isfield(cfg.puf,required{k})
        error('TrafoDNA:MissingActivePUFSetting', ...
            'Active PUF configuration is missing "%s".',required{k});
    end
end

pufCfg = cfg;
pufCfg.identity.maxFeatures = cfg.puf.transformFeatureCount;
pufCfg.identity.nuisanceComponents = cfg.puf.transformNuisanceComponents;
pufCfg.identity.covarianceRegularization = ...
    cfg.puf.transformCovarianceRegularization;
pufCfg.identity.useSVMWhenAvailable = false;
model = trainIdentityModel(features,coreIds,metadata,pufCfg);
model.role = 'active_puf_stability_transform';
model.preregisteredFeatureCount = cfg.puf.transformFeatureCount;
model.preregisteredNuisanceComponents = ...
    cfg.puf.transformNuisanceComponents;
end
