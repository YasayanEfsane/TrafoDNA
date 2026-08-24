function excitation = generateExcitation(condition, cfg)
%GENERATEEXCITATION Generate H(t) for one operating condition.
%   EXCITATION contains time, magnetic field, derivative, phase, frequency,
%   amplitude, and waveform metadata.

frequencyHz = cfg.signal.baseFrequencyHz * condition.frequencyScale;
amplitudeAm = cfg.signal.baseAmplitudeAm * condition.amplitudeScale;
durationS = cfg.signal.cycles / frequencyHz;
sampleCount = floor(durationS * cfg.signal.sampleRateHz) + 1;
t = (0:sampleCount-1)' / cfg.signal.sampleRateHz;
phase = 2 * pi * frequencyHz * t;

switch lower(cfg.signal.waveform)
    case {'sin','sine','sinusoidal'}
        unitWave = sin(phase);
        waveformName = 'sinusoidal';
    case {'triangle','triangular'}
        unitWave = (2 / pi) * asin(sin(phase));
        waveformName = 'triangular';
    case {'trapezoid','trapezoidal'}
        unitWave = min(max(1.6 * sin(phase), -1), 1);
        waveformName = 'trapezoidal';
    otherwise
        error('TrafoDNA:UnknownWaveform', ...
            'Unsupported waveform "%s".', cfg.signal.waveform);
end

H = cfg.signal.offsetAm + amplitudeAm * unitWave;
dt = 1 / cfg.signal.sampleRateHz;
dHdt = gradient(H, dt);

excitation.t = t;
excitation.H = H;
excitation.dHdt = dHdt;
excitation.phase = mod(phase, 2*pi);
excitation.frequencyHz = frequencyHz;
excitation.amplitudeAm = amplitudeAm;
excitation.waveform = waveformName;
excitation.sampleRateHz = cfg.signal.sampleRateHz;
end
