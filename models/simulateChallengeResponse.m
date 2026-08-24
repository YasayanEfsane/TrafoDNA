function [response,featureNames,positiveMask] = ...
    simulateChallengeResponse(core,scenario,challenge,cfg,sampleSeed)
%SIMULATECHALLENGERESPONSE Simulate one compact active Barkhausen response.
%   Persistent site thresholds provide identity; stochastic activation,
%   amplitude jitter, sensor noise, environment, and health provide variation.

validateattributes(sampleSeed,{'numeric'},{'scalar','finite'});
if ~isfield(core,'pinningSites')
    error('TrafoDNA:MissingPinningMap', ...
        'Active challenge simulation requires CREATEACTIVECORE output.');
end
previousState = rng;
cleanup = onCleanup(@() rng(previousState));
rng(mod(double(sampleSeed),2^32-1),'twister');

sites = core.pinningSites;
siteCount = numel(sites.thresholdAm);
deltaTemperature = scenario.temperatureK-293.15;
temperatureFactor = 1+sites.temperatureCoefficientPerK*deltaTemperature;
stressFactor = 1+sites.stressSensitivityPerPa*abs(scenario.stressPa);
agingFactor = 1+sites.agingSensitivity*scenario.agingLevel;
effectiveThreshold = sites.thresholdAm.*temperatureFactor.*stressFactor.*agingFactor;
effectiveThreshold = effectiveThreshold + ...
    sites.branchSign*scenario.resetOffsetAm;
effectiveThreshold = max(effectiveThreshold,1);

waveformIndex = find(strcmp(cfg.active.waveforms,challenge.waveform),1);
if isempty(waveformIndex)
    error('TrafoDNA:UnknownActiveWaveform', ...
        'Challenge waveform "%s" is not configured.',challenge.waveform);
end
switch challenge.waveform
    case 'sinusoidal'
        sweepFactor = 1.00;
    case 'triangular'
        sweepFactor = 0.88;
    case 'trapezoidal'
        sweepFactor = 1.12;
    otherwise
        error('TrafoDNA:UnknownActiveWaveform', ...
            'Unsupported active waveform "%s".',challenge.waveform);
end

fieldAmplitude = cfg.signal.baseAmplitudeAm*challenge.amplitudeScale;
rateRatio = max(challenge.amplitudeScale*challenge.frequencyScale* ...
    sweepFactor,0.05);
width = sites.activationWidthAm.*(1+0.35*scenario.agingLevel);
margin = (fieldAmplitude-effectiveThreshold)./max(width,eps) + ...
    cfg.active.activationJitter*randn(siteCount,1);
margin = min(max(margin,-40),40);
baseActivation = 1./(1+exp(-margin));
preference = sites.waveformPreference(:,waveformIndex);
activationPerCycle = 1-exp(-baseActivation.*preference.* ...
    rateRatio.^sites.rateExponent);
activationPerCycle = min(max(activationPerCycle,0),1);

occurrence = zeros(siteCount,1);
for cycle = 1:cfg.active.cyclesPerChallenge
    occurrence = occurrence+double(rand(siteCount,1)<activationPerCycle);
end
occurrence = occurrence/cfg.active.cyclesPerChallenge;

siteAmplitude = core.pulseAmplitudeV*sites.weight.*preference.* ...
    sqrt(rateRatio).*exp(cfg.active.amplitudeJitter*randn(siteCount,1));
siteAmplitude = siteAmplitude.*(1+0.18*scenario.agingLevel);
eventWeight = occurrence.*sites.weight;
weightedTotal = sum(eventWeight);
safeTotal = max(weightedTotal,eps);

noiseStd = cfg.sensor.baseNoiseStdV*scenario.noiseScale;
energy = scenario.sensorGain^2*sum(occurrence.*siteAmplitude.^2) + ...
    siteCount*noiseStd^2;
peakAmplitude = scenario.sensorGain*max(occurrence.*siteAmplitude) + ...
    2*noiseStd;
thresholdMean = sum(eventWeight.*effectiveThreshold)/safeTotal;
thresholdVariance = sum(eventWeight.*(effectiveThreshold-thresholdMean).^2)/safeTotal;
spectralCenter = sites.spectralCenterHz.* ...
    (1+0.10*scenario.agingLevel).*sqrt(challenge.frequencyScale);
spectralCentroid = sum(eventWeight.*spectralCenter)/safeTotal;
highBandFraction = sum(eventWeight(spectralCenter>=cfg.sensor.pulseCenterHz))/safeTotal;
positiveBranchFraction = sum(eventWeight(sites.branchSign>0))/safeTotal;
rateMoment = sum(eventWeight.*sites.rateExponent)/safeTotal;

fieldRatio = min(max(effectiveThreshold/max(fieldAmplitude,eps),0),1);
eventPhase = asin(fieldRatio);
negative = sites.branchSign<0;
eventPhase(negative) = pi+eventPhase(negative);
phaseVector = sum(eventWeight.*exp(1i*eventPhase))/safeTotal;

response = [mean(occurrence),weightedTotal,energy,peakAmplitude, ...
    thresholdMean,sqrt(max(thresholdVariance,0)),spectralCentroid, ...
    highBandFraction,positiveBranchFraction,rateMoment, ...
    imag(phaseVector),real(phaseVector)];
featureNames = {'ActivationFraction','WeightedEventCount','EnergyV2', ...
    'PeakAmplitudeV','ThresholdMeanAm','ThresholdStdAm', ...
    'SpectralCentroidHz','HighBandFraction','PositiveBranchFraction', ...
    'RateMoment','PhaseSin','PhaseCos'};
positiveMask = [true true true true true true true true true true false false];

positiveNoise = 1+cfg.active.featureNoiseFraction*randn(1,sum(positiveMask));
response(positiveMask) = max(response(positiveMask).*positiveNoise,eps);
response(~positiveMask) = response(~positiveMask) + ...
    0.25*cfg.active.featureNoiseFraction*randn(1,sum(~positiveMask));
response(~isfinite(response)) = 0;
clear cleanup
end
