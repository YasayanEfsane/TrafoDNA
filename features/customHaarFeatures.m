function [energies, names] = customHaarFeatures(signalV, levels)
%CUSTOMHAARFEATURES Compute normalized Haar detail/approximation energies.
%   [ENERGIES, NAMES] = CUSTOMHAARFEATURES(X, LEVELS) provides a toolbox-free
%   multiresolution description. X is cropped to a multiple of 2^LEVELS.

x = signalV(:)';
validateattributes(levels, {'numeric'}, {'scalar','integer','positive'});
blockLength = 2^levels;
usableLength = floor(numel(x) / blockLength) * blockLength;
if usableLength < blockLength
    x = [x zeros(1, blockLength-numel(x))];
else
    x = x(1:usableLength);
end

approximation = x;
detailEnergy = zeros(1, levels);
for level = 1:levels
    odd = approximation(1:2:end);
    even = approximation(2:2:end);
    detail = (odd - even) / sqrt(2);
    approximation = (odd + even) / sqrt(2);
    detailEnergy(level) = sum(detail.^2);
end
approximationEnergy = sum(approximation.^2);
energies = [detailEnergy approximationEnergy];
energies = energies / max(sum(energies), eps);

names = cell(1, levels + 1);
for level = 1:levels
    names{level} = sprintf('haarDetailEnergyL%d', level);
end
names{end} = sprintf('haarApproxEnergyL%d', levels);
end
