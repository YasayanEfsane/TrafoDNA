function core = createActiveCore(coreId,cfg)
%CREATEACTIVECORE Add one persistent pinning-site map to a virtual core.
%   The site map is a manufacturing-scale latent identity. It is fixed for
%   every V3 scenario, challenge, and repeated sweep of the same core.

core = createVirtualCore(coreId,cfg);
previousState = rng;
cleanup = onCleanup(@() rng(previousState));
rng(mod(cfg.rngSeed+32452843*coreId,2^32-1),'twister');

count = cfg.active.siteCount;
threshold = core.coercivityAm*exp(0.24*randn(count,1));
threshold = min(max(threshold,0.35*core.coercivityAm), ...
    1.85*core.coercivityAm);
weight = exp(core.disorderLevel*randn(count,1));
weight = weight/max(mean(weight),eps);

core.pinningSites.thresholdAm = threshold;
core.pinningSites.activationWidthAm = max(2.5, ...
    threshold.*(0.055+0.045*rand(count,1)));
core.pinningSites.weight = weight;
core.pinningSites.branchSign = 2*double(rand(count,1)>=0.5)-1;
core.pinningSites.rateExponent = 0.30+0.65*rand(count,1);
core.pinningSites.spectralCenterHz = cfg.sensor.pulseCenterHz* ...
    core.spectralShift.*exp(0.18*randn(count,1));
core.pinningSites.temperatureCoefficientPerK = ...
    core.temperatureCoefficientPerK.*(0.70+0.60*rand(count,1));
core.pinningSites.stressSensitivityPerPa = ...
    core.stressSensitivityPerPa.*(0.55+0.90*rand(count,1));
core.pinningSites.agingSensitivity = ...
    core.agingSensitivity.*(0.65+0.70*rand(count,1));
core.pinningSites.waveformPreference = min(max( ...
    1+0.12*randn(count,numel(cfg.active.waveforms)),0.65),1.35);
core.pinningSites.siteId = (1:count)';
core.pinningModel = 'persistent_threshold_map_v1';
clear cleanup
end
