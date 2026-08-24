function cfg = defaultActiveConfig()
%DEFAULTACTIVECONFIG Return the preregistered V3 active-study configuration.
%   V3 is independent of the observed V2.2 final conditions. It uses a
%   persistent pinning-site model and a fixed 24-challenge response sweep.

cfg = defaultConfig();
cfg.study.name = 'TrafoDNA Active Challenge-Response V3';
cfg.study.protocolVersion = '3.0.0-preregistered';
cfg.study.status = 'preregistered_unobserved';
cfg.rngSeed = 20260825;

% Active magnetic challenge matrix: 3 waveforms x 4 amplitudes x 2 rates.
cfg.active.waveforms = {'sinusoidal','triangular','trapezoidal'};
cfg.active.amplitudeScales = [0.65 0.80 1.00 1.20];
cfg.active.frequencyScales = [0.50 1.00];
cfg.active.referenceWaveform = 'sinusoidal';
cfg.active.referenceAmplitudeScale = 1.00;
cfg.active.referenceFrequencyScale = 1.00;
cfg.active.siteCount = 256;
cfg.active.cyclesPerChallenge = 16;
cfg.active.activationJitter = 0.12;
cfg.active.amplitudeJitter = 0.06;
cfg.active.featureNoiseFraction = 0.012;
cfg.active.challenges = buildChallengeSet(cfg);
reference = strcmp({cfg.active.challenges.waveform}, ...
    cfg.active.referenceWaveform) & ...
    abs([cfg.active.challenges.amplitudeScale]- ...
    cfg.active.referenceAmplitudeScale) < 1e-12 & ...
    abs([cfg.active.challenges.frequencyScale]- ...
    cfg.active.referenceFrequencyScale) < 1e-12;
cfg.active.referenceChallengeId = cfg.active.challenges(reference).id;

% Independent V3 scenario design. IDs 101-108 are known, 109-114 are the
% development stress set, and mechanically generated IDs 115-118 are the
% locked final holdout.
cfg.dataset.conditions = localBuildActiveScenarios();
cfg.dataset.numConditions = numel(cfg.dataset.conditions);
cfg.dataset.numCores = 20;
cfg.dataset.repetitions = 9;
cfg.dataset.trainRepeats = 1:4;
cfg.dataset.validationRepeats = 5:6;
cfg.dataset.testRepeats = 7:9;
cfg.dataset.unseenConditionIds = 109:114;
cfg.dataset.finalHoldoutConditionIds = 115:118;
cfg.dataset.rawExamplesPerCore = 0;

% The active representation already removes a reference response. Only
% measurable environmental quantities enter the optional linear residualizer.
cfg.identity.method = 'mahalanobis';
cfg.identity.featureCountGrid = [48 72 96];
cfg.identity.maxFeatures = 72;
cfg.identity.covarianceRegularizationGrid = [0.10 0.25];
cfg.identity.covarianceRegularization = 0.25;
cfg.identity.nuisanceComponentGrid = [0 4];
cfg.identity.nuisanceComponents = 0;
cfg.identity.validationEERWeight = 0.25;
cfg.identity.conditionWorstCaseWeight = 0.40;
cfg.identity.nuisanceVariables = {'TemperatureK','NoiseStdV', ...
    'SensorGain','ResetOffsetAm'};
cfg.identity.nuisanceRidge = 0.10;
cfg.identity.useSVMWhenAvailable = false;

% Raw PUF-style response gates are deliberately strict. Error correction is
% not used to conceal unstable raw bits.
cfg.puf.minimumBitReliability = 0.90;
cfg.puf.minimumValidationReliability = 0.90;
cfg.puf.minimumWorstConditionReliability = 0.88;
cfg.puf.minimumSelectedBits = 32;
cfg.puf.maximumSelectedBits = 64;
cfg.puf.allowFallbackToMinimum = false;
cfg.puf.bitAliasRange = [0.25 0.75];
cfg.puf.maximumReferenceCorrelation = 0.80;
cfg.puf.transformFeatureCount = 96;
cfg.puf.transformNuisanceComponents = 20;
cfg.puf.transformCovarianceRegularization = 0.25;
cfg.puf.selectionWeights.enrollmentReliability = 0.20;
cfg.puf.selectionWeights.validationReliability = 0.30;
cfg.puf.selectionWeights.worstConditionReliability = 0.50;
cfg.puf.selectionWeights.aliasPenalty = 0.50;
cfg.puf.selectionWeights.marginReward = 0.05;
cfg.session.readsPerDecision = 3;

% Preregistered one-time final gates. These values must not be changed after
% scenarios 115-118 are first evaluated.
cfg.benchmark.activeTargets.identityAccuracy = 0.60;
cfg.benchmark.activeTargets.maximumEER = 0.20;
cfg.benchmark.activeTargets.pufReliability = 0.90;
cfg.benchmark.activeTargets.pufUniquenessRange = [0.45 0.55];
cfg.benchmark.activeTargets.minimumEligibleBits = 32;
cfg.benchmark.activeTargets.worstConditionPUFReliability = 0.85;
cfg.benchmark.activeTargets.sessionIdentityAccuracy = 0.70;
cfg.benchmark.activeTargets.maximumSessionEER = 0.15;
cfg.benchmark.activeTargets.sessionPUFReliability = 0.93;
cfg.benchmark.activeTargets.minimumGainOverPassive = 0.15;
cfg.benchmark.lockedPassiveFinalIdentityAccuracy = 0.2250;
cfg.benchmark.lockedPassiveFinalEER = 0.41066;
cfg.benchmark.lockedPassiveFinalPUFReliability = 0.69727;
cfg.benchmark.lockedPassiveFinalSessionIdentityAccuracy = 0.24583;
cfg.benchmark.lockedPassiveFinalSessionEER = 0.39638;
cfg.benchmark.lockedPassiveFinalSessionPUFReliability = 0.72031;

cfg.runtime.resultsDirectory = fullfile(cfg.projectRoot,'results_active_v3');
cfg.runtime.figureDirectory = fullfile(cfg.runtime.resultsDirectory,'figures');
end

function scenarios = localBuildActiveScenarios()
%LOCALBUILDACTIVESCENARIOS Build a space-filling, jointly varied design.

% Columns are normalized temperature, noise, gain, reset offset, stress,
% and ageing coordinates. Rows 1-8 are known. Rows 9-14 are development
% scenarios, including the four pre-freeze shadow-design rows. Rows 15-18
% are untouched final scenarios generated mechanically from Halton indices
% 23-26, rather than selected using model output.
developmentDesign = [ ...
    .0625 .4375 .8125 .3125 .1875 .5625; ...
    .5625 .9375 .3125 .8125 .6875 .0625; ...
    .3125 .1875 .5625 .0625 .9375 .8125; ...
    .8125 .6875 .0625 .5625 .4375 .3125; ...
    .1875 .0625 .9375 .1875 .5625 .4375; ...
    .6875 .5625 .4375 .6875 .0625 .9375; ...
    .4375 .3125 .6875 .4375 .3125 .1875; ...
    .9375 .8125 .1875 .9375 .8125 .6875; ...
    .1000 .7500 .2500 .3500 .8500 .5500; ...
    .9000 .2500 .7500 .6500 .1500 .4500; ...
    .0200 .9800 .9800 .9900 .0200 .9800; ...
    .9800 .0200 .0200 .0100 .9800 .0200; ...
    .1500 .8500 .9000 .9000 .8000 .2000; ...
    .8500 .1500 .1000 .1000 .2000 .8000];
haltonBases = [2 3 5 7 11 13];
finalDesign = zeros(4,numel(haltonBases));
for row = 1:size(finalDesign,1)
    for column = 1:size(finalDesign,2)
        finalDesign(row,column) = localRadicalInverse(22+row, ...
            haltonBases(column));
    end
end
unitDesign = [developmentDesign;finalDesign];

count = size(unitDesign,1);
template = struct('id',0,'temperatureK',293.15,'noiseScale',1, ...
    'sensorGain',1,'resetOffsetAm',0,'stressPa',0,'agingLevel',0, ...
    'healthState','healthy','isUnseen',false,'isFinalHoldout',false);
scenarios = repmat(template,count,1);
for k = 1:count
    scenarios(k).id = 100+k;
    scenarios(k).temperatureK = 283.15+80*unitDesign(k,1);
    scenarios(k).noiseScale = 0.75+1.75*unitDesign(k,2);
    scenarios(k).sensorGain = 0.94+0.12*unitDesign(k,3);
    scenarios(k).resetOffsetAm = -6+12*unitDesign(k,4);
    scenarios(k).stressPa = -4.5e6+9.0e6*unitDesign(k,5);
    scenarios(k).agingLevel = 0.85*unitDesign(k,6);
    scenarios(k).healthState = localHealthState( ...
        scenarios(k).stressPa,scenarios(k).agingLevel);
    scenarios(k).isUnseen = ismember(scenarios(k).id,109:114);
    scenarios(k).isFinalHoldout = ismember(scenarios(k).id,115:118);
end
end

function value = localRadicalInverse(index,base)
%LOCALRADICALINVERSE Return one deterministic Halton coordinate.

value = 0;
fraction = 1/base;
while index > 0
    digit = mod(index,base);
    value = value+digit*fraction;
    index = floor(index/base);
    fraction = fraction/base;
end
end

function state = localHealthState(stressPa,agingLevel)
hasStress = abs(stressPa) >= 1.0e6;
hasAging = agingLevel >= 0.10;
if ~hasStress && ~hasAging
    state = 'healthy';
elseif hasStress && ~hasAging
    state = 'mechanical_stress';
elseif ~hasStress && hasAging
    state = 'thermal_aging';
else
    state = 'combined';
end
end
