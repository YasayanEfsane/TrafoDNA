function [featureVector, featureNames, diagnostics] = extractFeatures(signalV, excitation, cfg)
%EXTRACTFEATURES Extract time, event, spectral, phase, and Haar features.
%   [VECTOR, NAMES, DIAGNOSTICS] = EXTRACTFEATURES(SIGNAL, EXCITATION, CFG)
%   returns one finite row vector and event/envelope diagnostics.

x = signalV(:);
H = excitation.H(:);
fs = excitation.sampleRateHz;
if numel(x) ~= numel(H)
    error('TrafoDNA:DimensionMismatch', ...
        'Signal and excitation must have equal sample counts.');
end
if any(~isfinite(x))
    error('TrafoDNA:NonFiniteSignal', 'Signal contains NaN or Inf.');
end

signalRms = sqrt(mean(x.^2));
peakValue = max(abs(x));
crestFactor = peakValue / max(signalRms, eps);
centered = x - mean(x);
standardDeviation = sqrt(mean(centered.^2));
skewnessValue = mean(centered.^3) / max(standardDeviation^3, eps);
kurtosisValue = mean(centered.^4) / max(standardDeviation^4, eps);
zeroCrossingRate = sum(x(1:end-1) .* x(2:end) < 0) / max(numel(x)-1, 1);

events = detectBarkhausenEvents(x, fs, cfg);
eventCount = numel(events.indices);
if eventCount > 0
    meanEventAmplitude = mean(abs(events.amplitudesV));
    maxEventAmplitude = max(abs(events.amplitudesV));
else
    meanEventAmplitude = 0;
    maxEventAmplitude = 0;
end
if eventCount > 1
    eventIntervals = diff(events.timesS);
    meanEventInterval = mean(eventIntervals);
    stdEventInterval = std(eventIntervals);
else
    meanEventInterval = 0;
    stdEventInterval = 0;
end

[frequencyHz, powerSpectrum] = localOneSidedPower(x, fs);
totalSpectralPower = sum(powerSpectrum);
spectralCentroid = sum(frequencyHz .* powerSpectrum) / max(totalSpectralPower, eps);
spectralBandwidth = sqrt(sum(((frequencyHz-spectralCentroid).^2) .* powerSpectrum) / ...
    max(totalSpectralPower, eps));
probabilitySpectrum = powerSpectrum / max(totalSpectralPower, eps);
nonzeroProbability = probabilitySpectrum(probabilitySpectrum > 0);
spectralEntropy = -sum(nonzeroProbability .* log2(nonzeroProbability)) / ...
    max(log2(numel(probabilitySpectrum)), 1);

edges = cfg.features.bandEdgesFractionNyquist(:)' * (fs/2);
bandEnergy = zeros(1, numel(edges)-1);
for band = 1:numel(bandEnergy)
    if band == numel(bandEnergy)
        selected = frequencyHz >= edges(band) & frequencyHz <= edges(band+1);
    else
        selected = frequencyHz >= edges(band) & frequencyHz < edges(band+1);
    end
    bandEnergy(band) = sum(powerSpectrum(selected)) / max(totalSpectralPower, eps);
end

totalTimeEnergy = sum(x.^2);
positiveEnergyRatio = sum(x(H >= 0).^2) / max(totalTimeEnergy, eps);
negativeEnergyRatio = sum(x(H < 0).^2) / max(totalTimeEnergy, eps);

% Phase-synchronous descriptors preserve the repeatable microstructural
% modulation that is otherwise lost in whole-waveform summary statistics.
numPhaseBins = max(4, round(cfg.features.phaseBins));
phase = mod(excitation.phase(:), 2*pi);
phaseBin = min(floor(phase * numPhaseBins / (2*pi)) + 1, numPhaseBins);
phaseEnergyRatio = zeros(1, numPhaseBins);
phaseEventRatio = zeros(1, numPhaseBins);
for bin = 1:numPhaseBins
    phaseEnergyRatio(bin) = sum(x(phaseBin == bin).^2) / max(totalTimeEnergy, eps);
end
if eventCount > 0
    eventBins = phaseBin(events.indices);
    for bin = 1:numPhaseBins
        phaseEventRatio(bin) = sum(eventBins == bin) / eventCount;
    end
end

windowLength = max(3, round(cfg.features.envelopeWindowS * fs));
envelope = conv(abs(x), ones(windowLength,1)/windowLength, 'same');
activeEnvelope = find(envelope >= 0.5 * max(envelope));
if isempty(activeEnvelope)
    envelopeWidthS = 0;
else
    envelopeWidthS = (activeEnvelope(end)-activeEnvelope(1)) / fs;
end

eventCountPerCycle = eventCount / max(cfg.signal.cycles, eps);
eventAmplitudeRmsRatio = meanEventAmplitude / max(signalRms, eps);
eventPeakToMeanRatio = maxEventAmplitude / max(meanEventAmplitude, eps);
spectralCentroidNormalized = spectralCentroid / max(fs/2, eps);
spectralBandwidthNormalized = spectralBandwidth / max(fs/2, eps);
envelopeWidthCycles = envelopeWidthS * excitation.frequencyHz;

[haarEnergy, haarNames] = customHaarFeatures(x, cfg.features.haarLevels);
bandNames = arrayfun(@(k) sprintf('bandEnergyRatio%d', k), ...
    1:numel(bandEnergy), 'UniformOutput', false);
phaseEventNames = arrayfun(@(k) sprintf('phaseEventRatio%02d', k), ...
    1:numPhaseBins, 'UniformOutput', false);
phaseEnergyNames = arrayfun(@(k) sprintf('phaseEnergyRatio%02d', k), ...
    1:numPhaseBins, 'UniformOutput', false);

featureVector = [signalRms peakValue crestFactor skewnessValue kurtosisValue ...
    zeroCrossingRate eventCount meanEventAmplitude maxEventAmplitude ...
    meanEventInterval stdEventInterval eventCountPerCycle eventAmplitudeRmsRatio ...
    eventPeakToMeanRatio spectralCentroid spectralBandwidth ...
    spectralCentroidNormalized spectralBandwidthNormalized spectralEntropy ...
    bandEnergy positiveEnergyRatio negativeEnergyRatio phaseEventRatio ...
    phaseEnergyRatio envelopeWidthS envelopeWidthCycles haarEnergy];

featureNames = [{'signalRmsV','peakAbsoluteV','crestFactor','skewness','kurtosis', ...
    'zeroCrossingRate','eventCount','meanEventAmplitudeV','maxEventAmplitudeV', ...
    'meanEventIntervalS','stdEventIntervalS','eventCountPerCycle', ...
    'eventAmplitudeRmsRatio','eventPeakToMeanRatio','spectralCentroidHz', ...
    'spectralBandwidthHz','spectralCentroidNormalized', ...
    'spectralBandwidthNormalized','spectralEntropy'}, bandNames, ...
    {'positiveHalfEnergyRatio','negativeHalfEnergyRatio'}, phaseEventNames, ...
    phaseEnergyNames, {'envelopeWidthS','envelopeWidthCycles'}, haarNames];

featureVector(~isfinite(featureVector)) = 0;
diagnostics.events = events;
diagnostics.envelope = envelope;
diagnostics.frequencyHz = frequencyHz;
diagnostics.powerSpectrum = powerSpectrum;
end

function [frequencyHz, powerSpectrum] = localOneSidedPower(x, fs)
n = numel(x);
X = fft(x - mean(x));
oneSidedLength = floor(n/2) + 1;
X = X(1:oneSidedLength);
powerSpectrum = abs(X).^2 / max(n, 1);
frequencyHz = (0:oneSidedLength-1)' * (fs/n);
end
