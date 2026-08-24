function core = createVirtualCore(coreId, cfg)
%CREATEVIRTUALCORE Create one repeatable virtual transformer core.
%   CORE = CREATEVIRTUALCORE(COREID, CFG) samples bounded material and
%   microstructural parameters. The parameters remain fixed for every
%   measurement of this core and therefore act as its latent identity.

validateattributes(coreId, {'numeric'}, {'scalar','integer','positive'});
previousState = rng;
cleanup = onCleanup(@() rng(previousState));
rng(mod(cfg.rngSeed + 104729 * coreId, 2^32 - 1), 'twister');

core.id = coreId;
core.coercivityAm = localBoundedNormal(62, 8, 42, 85);
core.pinningDensity = localBoundedNormal(1.00, 0.13, 0.70, 1.35);
core.interactionCoefficient = localBoundedNormal(0.34, 0.06, 0.20, 0.50);
core.disorderLevel = localBoundedNormal(0.28, 0.055, 0.15, 0.42);
core.baseAvalancheRateHz = localBoundedNormal(2700, 350, 1900, 3500);
core.domainTimeConstantS = localBoundedNormal(1.8e-4, 0.35e-4, 1.0e-4, 2.7e-4);
core.temperatureCoefficientPerK = localBoundedNormal(8.0e-4, 1.5e-4, 4e-4, 1.2e-3);
core.stressSensitivityPerPa = localBoundedNormal(5.0e-9, 0.8e-9, 3e-9, 7e-9);
core.agingSensitivity = localBoundedNormal(0.30, 0.04, 0.20, 0.40);
core.pulseAmplitudeV = localBoundedNormal(7.0e-4, 1.1e-4, 4.5e-4, 1.0e-3);
core.spectralShift = localBoundedNormal(1.0, 0.06, 0.85, 1.15);

% Fixed harmonic modulation represents repeatable microstructural bias over
% the magnetisation phase. It is not redrawn between measurements.
core.fingerprintCoefficients = 0.14 * randn(1, 8) ./ (1:8);
core.fingerprintPhases = 2 * pi * rand(1, 8);
core.materialLabel = 'virtual_GO_silicon_steel';
clear cleanup
end

function value = localBoundedNormal(mu, sigma, lowerBound, upperBound)
value = min(max(mu + sigma * randn, lowerBound), upperBound);
end
