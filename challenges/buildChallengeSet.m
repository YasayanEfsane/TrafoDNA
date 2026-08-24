function challenges = buildChallengeSet(cfg)
%BUILDCHALLENGESET Build the fixed V3 active magnetic challenge matrix.
%   Challenges vary waveform, field amplitude, and frequency independently.

waveforms = cfg.active.waveforms;
amplitudes = cfg.active.amplitudeScales;
frequencies = cfg.active.frequencyScales;
count = numel(waveforms)*numel(amplitudes)*numel(frequencies);
template = struct('id',0,'waveform','','amplitudeScale',0, ...
    'frequencyScale',0,'code','');
challenges = repmat(template,count,1);

row = 0;
for waveformIndex = 1:numel(waveforms)
    for amplitudeIndex = 1:numel(amplitudes)
        for frequencyIndex = 1:numel(frequencies)
            row = row+1;
            challenges(row).id = row;
            challenges(row).waveform = waveforms{waveformIndex};
            challenges(row).amplitudeScale = amplitudes(amplitudeIndex);
            challenges(row).frequencyScale = frequencies(frequencyIndex);
            challenges(row).code = sprintf('W%d_A%d_F%d',waveformIndex, ...
                amplitudeIndex,frequencyIndex);
        end
    end
end

isReference = strcmp({challenges.waveform},cfg.active.referenceWaveform) & ...
    abs([challenges.amplitudeScale]-cfg.active.referenceAmplitudeScale) < 1e-12 & ...
    abs([challenges.frequencyScale]-cfg.active.referenceFrequencyScale) < 1e-12;
if sum(isReference) ~= 1
    error('TrafoDNA:ActiveReferenceChallenge', ...
        'The active challenge matrix must contain exactly one reference.');
end
end
