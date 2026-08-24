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
cfg.features.phaseBins = 12;

% Identity model.
cfg.identity.method = 'mahalanobis'; % mahalanobis | euclidean
cfg.identity.covarianceRegularization = 0.25;
cfg.identity.covarianceRegularizationGrid = [0.05 0.10 0.25 0.50];
cfg.identity.maxFeatures = 24;
cfg.identity.featureCountGrid = [18 24 32];
cfg.identity.validationEERWeight = 0.20;
cfg.identity.conditionWorstCaseWeight = 0.30;
cfg.identity.useConditionHoldoutTuning = true;
cfg.identity.removeOperatingConditionEffects = true;
cfg.identity.nuisanceVariables = {'TemperatureK','ExcitationAmplitudeAm', ...
    'ExcitationFrequencyHz','NoiseStdV','SensorGain'};
cfg.identity.nuisanceRidge = 0.05;
cfg.identity.nuisanceComponents = 0;
cfg.identity.nuisanceComponentGrid = [0 2 4];
cfg.identity.useSVMWhenAvailable = false;

% Binary magnetic fingerprint (PUF-style) settings.
cfg.puf.minimumBitReliability = 0.82;
cfg.puf.minimumValidationReliability = 0.80;
cfg.puf.minimumWorstConditionReliability = 0.72;
cfg.puf.minimumSelectedBits = 16;
cfg.puf.maximumSelectedBits = 32;
cfg.puf.bitAliasRange = [0.15 0.85];
cfg.puf.maximumReferenceCorrelation = 0.85;

% Identity/health separation.
cfg.health.varianceToKeep = 0.95;
cfg.health.maxComponents = 8;
cfg.health.maxFeatures = 20;

% Reproducible V1 benchmark and V2 engineering targets. Targets are
% acceptance criteria, not hard-coded or claimed results.
cfg.benchmark.baseline.knownIdentityAccuracy = 0.3516;
cfg.benchmark.baseline.unseenIdentityAccuracy = 0.3338;
cfg.benchmark.baseline.unseenEER = 0.3542;
cfg.benchmark.baseline.pufReliability = 0.6952;
cfg.benchmark.baseline.pufUniqueness = 0.5263;
cfg.benchmark.baseline.selectedBits = 8;
cfg.benchmark.baseline.healthAccuracy = 0.6743;
cfg.benchmark.targets.knownIdentityAccuracy = 0.50;
cfg.benchmark.targets.unseenIdentityAccuracy = 0.45;
cfg.benchmark.targets.maximumUnseenEER = 0.30;
cfg.benchmark.targets.pufReliability = 0.80;
cfg.benchmark.targets.pufUniquenessRange = [0.35 0.65];
cfg.benchmark.targets.minimumSelectedBits = 16;
cfg.benchmark.targets.healthAccuracy = 0.65;

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
