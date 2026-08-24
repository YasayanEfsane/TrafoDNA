function result = computeEER(genuineDistances, impostorDistances)
%COMPUTEEER Compute FAR, FRR, ROC coordinates, and equal-error rate.
%   Distances at or below the threshold are accepted as genuine.

genuine = genuineDistances(isfinite(genuineDistances));
impostor = impostorDistances(isfinite(impostorDistances));
if isempty(genuine) || isempty(impostor)
    error('TrafoDNA:EmptyScores', 'Genuine and impostor score sets must be nonempty.');
end
lower = min([genuine(:); impostor(:)]);
upper = max([genuine(:); impostor(:)]);
if upper <= lower
    thresholds = lower;
else
    thresholds = linspace(lower, upper, 600)';
end

far = zeros(numel(thresholds),1);
frr = zeros(numel(thresholds),1);
for k = 1:numel(thresholds)
    far(k) = mean(impostor <= thresholds(k));
    frr(k) = mean(genuine > thresholds(k));
end
[~, index] = min(abs(far-frr));

result.thresholds = thresholds;
result.far = far;
result.frr = frr;
result.trueAcceptRate = 1-frr;
result.falseAcceptRate = far;
result.eer = 0.5*(far(index)+frr(index));
result.eerThreshold = thresholds(index);
result.eerIndex = index;
end
