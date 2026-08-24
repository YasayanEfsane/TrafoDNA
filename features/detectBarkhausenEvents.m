function events = detectBarkhausenEvents(signalV, sampleRateHz, cfg)
%DETECTBARKHAUSENEVENTS Detect local high-frequency Barkhausen peaks.
%   EVENTS contains selected indices, signed amplitudes, event times, and the
%   robust threshold. No Signal Processing Toolbox function is required.

x = signalV(:);
validateattributes(sampleRateHz, {'numeric'}, {'scalar','positive','finite'});

center = median(x);
robustSigma = median(abs(x - center)) / 0.6744897501960817;
if robustSigma < eps
    robustSigma = std(x);
end
threshold = cfg.features.eventThresholdSigma * max(robustSigma, eps);
absoluteSignal = abs(x - center);

if numel(x) < 3
    candidates = find(absoluteSignal >= threshold);
else
    candidates = find(absoluteSignal(2:end-1) >= absoluteSignal(1:end-2) & ...
        absoluteSignal(2:end-1) > absoluteSignal(3:end) & ...
        absoluteSignal(2:end-1) >= threshold) + 1;
end

minimumDistance = max(1, round(cfg.features.minEventDistanceS * sampleRateHz));
selected = localSuppressNearby(candidates, absoluteSignal, minimumDistance);

events.indices = selected(:);
events.amplitudesV = x(selected);
events.timesS = (selected(:) - 1) / sampleRateHz;
events.thresholdV = threshold;
events.robustSigmaV = robustSigma;
end

function selected = localSuppressNearby(candidates, magnitude, minimumDistance)
if isempty(candidates)
    selected = zeros(0, 1);
    return;
end

[~, order] = sort(magnitude(candidates), 'descend');
kept = false(numel(candidates), 1);
blocked = false(numel(candidates), 1);
for k = 1:numel(order)
    idx = order(k);
    if ~blocked(idx)
        kept(idx) = true;
        blocked = blocked | abs(candidates - candidates(idx)) < minimumDistance;
        blocked(idx) = false;
    end
end
selected = sort(candidates(kept));
end
