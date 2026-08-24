function cfg = defaultConfig()
%DEFAULTCONFIG Return the complete configuration for the TrafoDNA project.
%   CFG = DEFAULTCONFIG() creates a scalar structure containing simulation,
%   dataset, feature, identity, PUF, health, plotting, and runtime settings.
%   All physical quantities use SI units unless explicitly stated.

cfg.projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.rngSeed = 20260824;

% Excitation and sampling.
cfg.signal.sampleRateHz = 5.0e4;
cfg.signal.cycles = 2;
cfg.signal.waveform = 'sinusoidal'; % sinusoidal | triangular | trapezoidal
cfg.signal.baseFrequencyHz = 50;
cfg.signal.baseAmplitudeAm = 120;   % magnetic field strength, A/m
cfg.signal.offsetAm = 0;

% Sensor model. The band is deliberately above the 50 Hz excitation.
cfg.sensor.lowCutHz = 1.5e3;
cfg.sensor.highCutHz = 2.0e4;
cfg.sensor.nominalGain = 1;
cfg.sensor.baseNoiseStdV = 2.0e-5;
cfg.sensor.pulseCenterHz = 8.0e3;
cfg.sensor.pulseDecayS = 1.2e-4;

% Virtual population and memory-aware dataset generation.
cfg.dataset.numCores = 20;
cfg.dataset.numConditions = 10;
cfg.dataset.repetitions = 20;
cfg.dataset.trainRepeats = 1:12;
cfg.dataset.validationRepeats = 13:16;
cfg.dataset.testRepeats = 17:20;
cfg.dataset.unseenConditionIds = [9 10];
cfg.dataset.rawExamplesPerCore = 2;
cfg.dataset.conditions = localBuildConditions(cfg);

% Event detection and feature extraction.
cfg.features.eventThresholdSigma = 3.5;
cfg.features.minEventDistanceS = 5.0e-5;
cfg.features.envelopeWindowS = 3.0e-4;
cfg.features.bandEdgesFractionNyquist = [0 0.15 0.35 0.65 1.0];
cfg.features.haarLevels = 4;

% Identity model.
cfg.identity.method = 'mahalanobis'; % mahalanobis | euclidean
cfg.identity.covarianceRegularization = 5.0e-2;
cfg.identity.useSVMWhenAvailable = false;

% Binary magnetic fingerprint (PUF-style) settings.
cfg.puf.minimumBitReliability = 0.75;
cfg.puf.minimumSelectedBits = 8;

% Identity/health separation.
cfg.health.varianceToKeep = 0.95;
cfg.health.maxComponents = 8;

% Output behavior.
cfg.runtime.createFigures = true;
cfg.runtime.saveMatFile = true;
cfg.runtime.saveCsvFile = true;
cfg.runtime.verbose = true;
cfg.runtime.figureVisible = 'off';
cfg.runtime.resultsDirectory = fullfile(cfg.projectRoot, 'results');
cfg.runtime.figureDirectory = fullfile(cfg.runtime.resultsDirectory, 'figures');
end

function conditions = localBuildConditions(cfg)
%LOCALBUILDCONDITIONS Create known and deliberately unseen operating states.

n = cfg.dataset.numConditions;
template = struct('id', 0, 'temperatureK', 293.15, ...
    'amplitudeScale', 1, 'frequencyScale', 1, 'noiseScale', 1, ...
    'sensorGain', 1, 'stressPa', 0, 'agingLevel', 0, ...
    'healthState', 'healthy', 'isUnseen', false);
conditions = repmat(template, n, 1);

% Rows: temperature [K], amplitude scale, frequency scale, noise scale,
% gain, stress [Pa], ageing [0,1]. Conditions 9-10 are held out entirely.
design = [ ...
    293.15  1.00  1.00  1.0  1.00   0.0e6  0.00; ...
    303.15  0.95  1.04  1.2  0.98   0.0e6  0.02; ...
    298.15  1.05  0.96  1.0  1.02   1.5e6  0.04; ...
    318.15  1.00  1.08  1.4  1.01  -2.0e6  0.05; ...
    323.15  0.92  0.92  1.5  0.99   0.3e6  0.35; ...
    333.15  1.08  1.02  1.7  1.03   0.5e6  0.55; ...
    328.15  0.97  1.10  1.8  0.97   2.5e6  0.35; ...
    343.15  1.03  0.90  2.0  1.04  -3.0e6  0.60; ...
    353.15  0.88  1.15  2.2  0.95   3.5e6  0.70; ...
    363.15  1.12  0.85  2.5  1.06  -4.0e6  0.85];

for k = 1:n
    conditions(k).id = k;
    conditions(k).temperatureK = design(k, 1);
    conditions(k).amplitudeScale = design(k, 2);
    conditions(k).frequencyScale = design(k, 3);
    conditions(k).noiseScale = design(k, 4);
    conditions(k).sensorGain = design(k, 5);
    conditions(k).stressPa = design(k, 6);
    conditions(k).agingLevel = design(k, 7);
    if abs(design(k, 6)) < 1.0e6 && design(k, 7) < 0.10
        conditions(k).healthState = 'healthy';
    elseif abs(design(k, 6)) >= 1.0e6 && design(k, 7) < 0.10
        conditions(k).healthState = 'mechanical_stress';
    elseif abs(design(k, 6)) < 1.0e6 && design(k, 7) >= 0.10
        conditions(k).healthState = 'thermal_aging';
    else
        conditions(k).healthState = 'combined';
    end
    conditions(k).isUnseen = any(k == cfg.dataset.unseenConditionIds);
end
end
