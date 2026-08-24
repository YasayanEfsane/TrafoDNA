function effective = applyOperatingCondition(core, condition)
%APPLYOPERATINGCONDITION Map environment and health to effective parameters.
%   EFFECTIVE = APPLYOPERATINGCONDITION(CORE, CONDITION) preserves the core's
%   latent identity while modifying physically sensitive parameters.

referenceTemperatureK = 293.15;
deltaT = condition.temperatureK - referenceTemperatureK;
stressMagnitude = abs(condition.stressPa);

temperatureFactor = 1 + core.temperatureCoefficientPerK * deltaT;
stressFactor = 1 + core.stressSensitivityPerPa * stressMagnitude;
agingFactor = 1 + core.agingSensitivity * condition.agingLevel;

effective.coercivityAm = core.coercivityAm * temperatureFactor * agingFactor + ...
    core.stressSensitivityPerPa * stressMagnitude * core.coercivityAm;
effective.pinningDensity = core.pinningDensity * stressFactor * ...
    (1 + 0.45 * condition.agingLevel);
effective.interactionCoefficient = core.interactionCoefficient * ...
    (1 + 0.12 * condition.agingLevel);
effective.disorderLevel = core.disorderLevel * ...
    (1 + 0.25 * condition.agingLevel + 0.08 * stressFactor);
effective.avalancheRateHz = core.baseAvalancheRateHz / ...
    sqrt(max(stressFactor * agingFactor, eps));
effective.domainTimeConstantS = core.domainTimeConstantS * ...
    (1 + 0.35 * condition.agingLevel);
effective.pulseAmplitudeV = core.pulseAmplitudeV * ...
    (1 + 0.18 * stressFactor + 0.22 * condition.agingLevel);
effective.sensorGain = condition.sensorGain;
effective.noiseScale = condition.noiseScale;
effective.temperatureK = condition.temperatureK;
effective.stressPa = condition.stressPa;
effective.agingLevel = condition.agingLevel;
end
