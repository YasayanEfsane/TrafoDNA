function simulation = simulateBarkhausen(core, condition, excitation, cfg, sampleSeed)
%SIMULATEBARKHAUSEN Generate an ABBM-inspired stochastic voltage waveform.
%   SIMULATION = SIMULATEBARKHAUSEN(CORE, CONDITION, EXCITATION, CFG, SEED)
%   produces phase-coupled avalanche impulses, applies a pickup-coil/sensor
%   response, and adds reproducible measurement noise.

validateattributes(sampleSeed, {'numeric'}, {'scalar','finite'});
previousState = rng;
cleanup = onCleanup(@() rng(previousState));
rng(mod(double(sampleSeed), 2^32 - 1), 'twister');

effective = applyOperatingCondition(core, condition);
t = excitation.t;
H = excitation.H;
dHdt = excitation.dHdt;
phase = excitation.phase;
dt = 1 / excitation.sampleRateHz;
n = numel(t);

speedScale = max(abs(dHdt));
speedNormalized = abs(dHdt) / max(speedScale, eps);
coerciveWidth = max(0.18 * effective.coercivityAm + ...
    10 * effective.disorderLevel, 4);

% Domain-wall activity peaks near +/- coercivity and increases with field
% sweep rate. The fixed harmonic term makes each core repeatably distinctive.
coerciveWindow = exp(-0.5 * ((abs(H) - effective.coercivityAm) ./ coerciveWidth).^2);
phaseFingerprint = ones(n, 1);
for harmonic = 1:numel(core.fingerprintCoefficients)
    phaseFingerprint = phaseFingerprint + core.fingerprintCoefficients(harmonic) * ...
        cos(harmonic * phase + core.fingerprintPhases(harmonic));
end
phaseFingerprint = max(phaseFingerprint, 0.15);

rateHz = effective.avalancheRateHz .* (0.05 + speedNormalized.^0.72) .* ...
    (0.10 + coerciveWindow) .* phaseFingerprint;
eventProbability = min(rateHz * dt, 0.30);
primaryEvents = rand(n, 1) < eventProbability;

% A decaying activity state approximates avalanche branching: a large event
% temporarily raises the probability of nearby secondary events.
activity = zeros(n, 1);
eventMask = false(n, 1);
eventAmplitude = zeros(n, 1);
decay = exp(-dt / max(effective.domainTimeConstantS, dt));
for k = 2:n
    activity(k) = decay * activity(k-1);
    secondaryProbability = min(0.06 * effective.interactionCoefficient * activity(k), 0.12);
    isEvent = primaryEvents(k) || (rand < secondaryProbability);
    if isEvent
        localDrive = 0.25 + 0.75 * speedNormalized(k);
        logAmplitude = log(max(effective.pulseAmplitudeV, eps)) + ...
            effective.disorderLevel * randn;
        amplitude = exp(logAmplitude) * localDrive * ...
            (1 + 0.30 * activity(k));
        eventMask(k) = true;
        eventAmplitude(k) = sign(dHdt(k) + eps) * amplitude;
        activity(k) = activity(k) + min(amplitude / ...
            max(effective.pulseAmplitudeV, eps), 5);
    end
end

% Pickup-coil impulse response: damped oscillation followed by an idealized
% FFT-domain band-pass. This uses base MATLAB only.
pulseDuration = min(8 * cfg.sensor.pulseDecayS, t(end));
tp = (0:floor(pulseDuration * excitation.sampleRateHz))' / excitation.sampleRateHz;
pulseFrequency = cfg.sensor.pulseCenterHz * core.spectralShift * ...
    (1 + 0.08 * condition.agingLevel);
impulseResponse = exp(-tp / cfg.sensor.pulseDecayS) .* sin(2*pi*pulseFrequency*tp);
impulseResponse = impulseResponse / max(sqrt(sum(impulseResponse.^2)), eps);
cleanSignal = conv(eventAmplitude, impulseResponse, 'same');
cleanSignal = localBandpassFFT(cleanSignal, excitation.sampleRateHz, ...
    cfg.sensor.lowCutHz, cfg.sensor.highCutHz);

noiseStd = cfg.sensor.baseNoiseStdV * effective.noiseScale;
whiteNoise = randn(n, 1);
coloredNoise = filter(1, [1 -0.82], whiteNoise);
coloredNoise = coloredNoise / max(std(coloredNoise), eps);
measuredSignal = effective.sensorGain * cleanSignal + noiseStd * coloredNoise;
measuredSignal = measuredSignal - mean(measuredSignal);

simulation.signalV = measuredSignal;
simulation.cleanSignalV = cleanSignal;
simulation.eventMask = eventMask;
simulation.eventAmplitudeV = eventAmplitude;
simulation.eventPhaseRad = phase(eventMask);
simulation.activity = activity;
simulation.effective = effective;
simulation.sampleSeed = sampleSeed;
clear cleanup
end

function y = localBandpassFFT(x, fs, lowCut, highCut)
n = numel(x);
X = fft(x);
frequency = (0:n-1)' * (fs / n);
absoluteFrequency = min(frequency, fs - frequency);
mask = absoluteFrequency >= lowCut & absoluteFrequency <= min(highCut, fs/2);
% A short cosine transition reduces ringing without requiring a toolbox.
transition = max(0.12 * lowCut, fs / n);
lowerRamp = absoluteFrequency >= max(lowCut-transition, 0) & absoluteFrequency < lowCut;
upperRamp = absoluteFrequency > min(highCut, fs/2) & ...
    absoluteFrequency <= min(highCut+transition, fs/2);
weight = double(mask);
if any(lowerRamp)
    z = (absoluteFrequency(lowerRamp) - (lowCut-transition)) / transition;
    weight(lowerRamp) = 0.5 - 0.5*cos(pi*z);
end
if any(upperRamp)
    z = (absoluteFrequency(upperRamp) - highCut) / transition;
    weight(upperRamp) = 0.5 + 0.5*cos(pi*z);
end
y = real(ifft(X .* weight));
end
