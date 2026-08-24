# TrafoDNA

**Virtual magnetic fingerprinting of transformer cores from stochastic Barkhausen noise**

TrafoDNA is a MATLAB-only numerical feasibility study for transformer-core identification, PUF-style fingerprinting, and health monitoring. It asks whether nominally identical transformer cores can retain distinguishable Barkhausen signatures under changing temperature, excitation, sensor, stress, and ageing conditions.

> **Scientific boundary:** TrafoDNA contains no physical measurements or experimental validation. Its waveforms come from an interpretable but reduced stochastic model. Numerical separation in this repository is not evidence that real transformer cores will achieve the same performance.

## Research question

> Can manufacturing-scale microstructural differences produce a repeatable virtual magnetic fingerprint, and can that identity be separated from operating-condition and health changes?

## Current status

The unchanged V1 baseline is preserved on `main`. The default-seed run reported:

| Metric | V1 result | V2.0 result | V2 engineering target |
|---|---:|---:|---:|
| Known-condition identity accuracy | 35.16% | 51.41% | at least 50% |
| Unseen-condition identity accuracy | 33.38% | 42.75% | at least 45% |
| Unseen-condition EER | 0.3542 | 0.3297 | at most 0.30 |
| PUF reliability | 0.6952 | 0.7204 | at least 0.80 |
| PUF uniqueness | 0.5263 | 0.5263 | 0.35 to 0.65 |
| Selected stable bits | 8 | 48 | at least 16 |
| Health classification accuracy | 67.43% | 77.36% | at least 65% |

V2.0 passed four of seven gates. V2.1 focuses on the remaining unseen-condition and PUF-reliability gaps. These targets remain engineering criteria, not experimental claims. The V1 label “validation EER” was misleading: the printed value was taken from the unseen-condition metrics. V2 prints validation and unseen-condition EER separately.

## What V2.1 changes

- Adds 12-bin phase-synchronous event and energy descriptors so the fixed microstructural phase pattern is not collapsed into two half-cycle values.
- Removes measurable temperature, excitation, noise, and sensor-gain effects with a ridge model fitted only on enrollment data.
- Excludes stress, ageing, health labels, and core identity from that nuisance model.
- Selects identity dimensions with a training-only Fisher score.
- Tunes feature count, covariance shrinkage, and nuisance-subspace size by leaving one complete known condition out at a time.
- Learns dominant within-core nuisance directions and projects them out without using health labels or query-time health metadata.
- Builds PUF candidates from unary identity coordinates and pairwise coordinate differences.
- Screens bits using enrollment reliability, validation reliability, worst-known-condition reliability, population balance, threshold margin, and reference correlation.
- Stops at the stable candidate count instead of always filling the response to its configured maximum.
- Applies supervised feature filtering before residual health PCA.
- Writes a benchmark CSV that compares every new run with V1 and the V2 targets.
- Adds algorithmic regression tests in addition to structural checks.

No physical simulator parameter was changed merely to inflate identification scores.

## Requirements

- MATLAB R2020b or newer is recommended.
- The default path uses base MATLAB only.
- Statistics and Machine Learning Toolbox is optional. An ECOC-SVM experiment is available but disabled by default.
- Simulink, Python, external datasets, and hardware are not required.

## Run the full experiment

Open the repository root in MATLAB:

```matlab
addpath(genpath(pwd));
results = main();
```

The default study generates 20 virtual cores, 10 operating conditions, 20 repetitions per condition, and 4,000 feature records. Raw waveforms are streamed: only a small configured subset is retained for plotting.

The summary reports actual computed values, the selected identity-model settings, and the number of V2 acceptance gates passed.

## Run a quick study

```matlab
addpath(genpath(pwd));
cfg = defaultConfig();
cfg.dataset.numCores = 5;
cfg.dataset.numConditions = 5;
cfg.dataset.repetitions = 5;
cfg.dataset.trainRepeats = 1:3;
cfg.dataset.validationRepeats = 4;
cfg.dataset.testRepeats = 5;
cfg.dataset.unseenConditionIds = 5;
cfg.dataset.conditions = cfg.dataset.conditions(1:5);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
end
results = main(cfg);
```

Quick studies validate the pipeline but are not comparable with the default V1 benchmark because their population and measurement counts differ.

## Tests

```matlab
run_tests
```

or:

```matlab
testResults = runAllTests();
```

The suite checks:

- exact seed reproducibility;
- distinct fixed parameters for different cores;
- finite signals and stable feature dimensions;
- disjoint train, validation, test, and unseen-condition partitions;
- toolbox-free identity inference and valid verification metrics;
- EER behavior on separated synthetic scores;
- valid PUF metrics and the configured minimum bit count;
- the identity-transform contract and exclusion of health variables;
- synthetic extrapolation across an unseen removable condition shift.
- leave-one-condition-out tuning and nuisance-subspace integrity.

Passing these tests establishes implementation invariants. It does not replace the full benchmark or experimental validation.

## Model pipeline

1. `defaultConfig` defines numerical, physical, split, and acceptance settings.
2. `createVirtualCore` samples a fixed latent microstructural identity.
3. `generateExcitation` generates sinusoidal, triangular, or trapezoidal `H(t)`.
4. `simulateBarkhausen` generates phase-coupled avalanche events and pickup voltage.
5. `extractFeatures` computes time, event, spectrum, phase, and Haar descriptors.
6. `splitDataset` holds out repeat groups and entire operating conditions.
7. `tuneIdentityModel` selects a condition-robust centroid model on validation data.
8. `generateBinaryFingerprint` enrolls decorrelated stable differential bits.
9. `separateIdentityAndHealth` removes core centroids and learns health coordinates.
10. Evaluation produces metrics, benchmark gates, CSV/MAT outputs, and 16 figures.

## Leakage controls

- Conditions 9 and 10 are absent from enrollment and validation.
- Repetitions 1–12 train, 13–16 validate, and 17–20 test for known conditions.
- Standardization, nuisance regression, Fisher ranking, centroids, covariance, and PUF thresholds are fitted on enrollment data only.
- Feature count, covariance regularization, nuisance-subspace size, and PUF bit stability use validation labels.
- Identity hyperparameters are scored on conditions excluded from the corresponding fold's enrollment rows.
- Test and unseen-condition labels never influence fitting or tuning.
- The identity nuisance model sees measurable operating variables only; it never sees stress, ageing, health state, or identity labels as predictors.

## Output files

`main` writes the following under `results/` when saving is enabled:

- `trafodna_results.mat`
- `trafodna_features.csv`
- `identity_accuracy_by_health.csv`
- `benchmark_comparison.csv`
- `figures/01_excitation_field.png` through `figures/16_identity_accuracy_by_health.png`

Generated data and figures are ignored by Git; `results/README.md` remains tracked.

## Repository layout

```text
TrafoDNA/
├── main.m
├── run_tests.m
├── README.md
├── MODEL.md
├── config/
├── models/
├── features/
├── dataset/
├── identity/
├── health/
├── evaluation/
├── visualization/
├── tests/
├── utils/
├── docs/
└── results/
```

## Important limitations

1. The simulator does not spatially solve domains or domain walls.
2. Lamination geometry, grain maps, flux distribution, and pickup-coil placement are not directly modeled.
3. Parameter ranges are plausible numerical assumptions, not a calibration to a particular steel grade.
4. Identity separation in synthetic data does not establish real-world separability.
5. Operating metadata used by the V2 normalizer must be measured or supplied at inference time.
6. PUF-style metrics do not constitute a cryptographic security proof.
7. The reported V1 values came from one deterministic default configuration and should not be generalized beyond it.

See [MODEL.md](MODEL.md) for equations and [docs/BASELINE_ANALYSIS.md](docs/BASELINE_ANALYSIS.md) for the V1 diagnosis and V2 rationale.

## Path to physical validation

Replace `simulateBarkhausen` with a loader that provides `signalV`, `sampleRateHz`, synchronized `H(t)`, and measurable operating metadata. A physical study should control temperature, excitation amplitude and frequency, sensor placement, clamping torque, acquisition bandwidth, and core history. It should pre-register enrollment/test splits and report confidence intervals across independently manufactured cores.
