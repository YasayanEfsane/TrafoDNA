# TrafoDNA

**Virtual magnetic fingerprinting of transformer cores from stochastic Barkhausen noise**

TrafoDNA is a MATLAB-only numerical feasibility study for transformer-core identification, PUF-style fingerprinting, and health monitoring. It asks whether nominally identical transformer cores can retain distinguishable Barkhausen signatures under changing temperature, excitation, sensor, stress, and ageing conditions.

> **Scientific boundary:** TrafoDNA contains no physical measurements or experimental validation. Its waveforms come from an interpretable but reduced stochastic model. Numerical separation in this repository is not evidence that real transformer cores will achieve the same performance.

## Research question

> Can manufacturing-scale microstructural differences produce a repeatable virtual magnetic fingerprint, and can that identity be separated from operating-condition and health changes?

## Current status

The V1 benchmark is preserved as a documented reference. The merged `main` branch contains the locked V2.2 result, and the default-seed runs reported:

| Metric | V1 | V2.0 | V2.1 | Engineering target |
|---|---:|---:|---:|---:|
| Known-condition identity accuracy | 35.16% | 51.41% | 51.41% | at least 50% |
| Development-holdout identity accuracy | 33.38% | 42.75% | 42.88% | at least 45% |
| Development-holdout EER | 0.3542 | 0.3297 | 0.3332 | at most 0.30 |
| PUF reliability | 0.6952 | 0.7204 | 0.7598 | at least 0.80 |
| PUF uniqueness | 0.5263 | 0.5263 | 0.5263 | 0.35 to 0.65 |
| Selected stable bits | 8 | 48 | 16 | at least 16 |
| Health classification accuracy | 67.43% | 77.36% | 77.36% | at least 65% |

V2.1 still passed four of seven single-read gates. It improved PUF reliability and corrected the forced 48-bit response, while identity generalization remained effectively unchanged. Conditions 9–10 have now been observed repeatedly and are frozen as a development holdout. V2.2 preregistered conditions 11–12 and seven final gates before the first inspection; that first evaluation is now locked below. These targets remain engineering criteria, not experimental claims.

### First V2.2 final-holdout result

The first preregistered run passed **1 of 7** final-holdout gates. Single-read identity accuracy was 22.50%, EER was 0.4107, PUF reliability was 0.6973, and health accuracy was 90.38%. Three-read identity accuracy was 24.58%, EER was 0.3964, and PUF reliability was 0.7203.

Conditions 11–12 are now observed and permanently frozen. They must not be described as untouched in any later experiment. The result does not support robust passive identity or PUF operation under the current arbitrary-condition protocol; it does support the health-classification feasibility result. See [docs/FINAL_HOLDOUT_RESULTS.md](docs/FINAL_HOLDOUT_RESULTS.md) for the locked record and interpretation.

### Locked V3 active result

V3 preserves the complete passive result and adds a separate active magnetic challenge-response experiment. Each virtual core receives one persistent 256-site pinning map and is queried with a fixed matrix of 24 waveform, amplitude, and frequency challenges, averaged over 16 excitation cycles per challenge. Positive response quantities are expressed as log ratios to a reference challenge; signed phase quantities use differences. Identity classification and PUF-style enrollment use separately fitted, enrollment-only transforms because multiclass accuracy and raw-bit stability are distinct objectives.

The V3 random seed, 18 independent scenarios, final scenarios 115–118, representation, and ten final gates were frozen in [docs/V3_PREREGISTRATION.md](docs/V3_PREREGISTRATION.md) and commit `a0506152845b6fc22af1785b22e5a68b90e7462f` before the first final run.

That first run passed **9 of 10** gates. Final identity accuracy was 100.00%, identity EER was 0.0038743, raw PUF reliability was 0.93953, uniqueness was 0.52632, worst-scenario reliability was 0.91987, and three-sweep PUF reliability was 0.95048. The only failed gate was response length: 179 candidates passed the stability-and-balance eligibility screen, but the fixed greedy correlation pruning retained only 26 mutually admissible raw bits against a target of 32. The preregistered all-gates decision is therefore **NOT SUPPORTED**. Scenarios 115–118 are now observed and frozen. See [docs/V3_FINAL_RESULTS.md](docs/V3_FINAL_RESULTS.md) for the complete locked record.

## What V2.2 adds

- Adds 12-bin phase-synchronous event and energy descriptors so the fixed microstructural phase pattern is not collapsed into two half-cycle values.
- Removes measurable temperature, excitation, noise, and sensor-gain effects with a ridge model fitted only on enrollment data.
- Excludes stress, ageing, health labels, and core identity from that nuisance model.
- Selects identity dimensions with a training-only Fisher score.
- Tunes feature count, covariance shrinkage, and nuisance-subspace size by leaving one complete known condition out at a time.
- Learns dominant within-core nuisance directions and projects them out without using health labels or query-time health metadata.
- Builds PUF candidates from unary identity coordinates and pairwise coordinate differences.
- Screens bits using enrollment reliability, validation reliability, worst-known-condition reliability, population balance, threshold margin, and reference correlation.
- Stops at the stable candidate count instead of always filling the response to its configured maximum.
- Preserves every single-read result and adds a separate three-read session decision based on median features or median continuous PUF responses.
- Freezes conditions 9–10 as development evidence and adds conditions 11–12 as a preregistered final-holdout partition.
- Applies seven preregistered final-holdout checks without using those observations for fitting or tuning.
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

The default study generates 20 virtual cores, 12 operating conditions, 20 repetitions per condition, and 4,800 feature records. Conditions 1–8 are known, 9–10 are the frozen development holdout, and 11–12 are the preregistered final holdout. Raw waveforms are streamed: only a small configured subset is retained for plotting.

The summary reports actual computed values, the selected identity-model settings, and the number of V2 acceptance gates passed.

## Reproduce the locked V3 active study

The preregistration commit is preserved. Future executions reproduce an observed result; they do not create a new untouched final evaluation:

```matlab
addpath(genpath(pwd));
activeResults = main_active();
```

The default active study uses 20 cores, 18 independent V3 scenarios, 9 complete sweeps per core/scenario, 24 challenges per sweep, and 16 excitation cycles per challenge. It produces 3,240 differential response records from 77,760 compact challenge simulations. Scenarios 101–108 are known, 109–114 are development-only, and 115–118 are the locked V3 final holdout.

`main_active` does not overwrite the passive `main` results. Active outputs are written under `results_active_v3/`.

## Run the V3.1 capacity development audit

The locked V3 diagnostic found 179 individually eligible raw-bit candidates but retained only 26 after the fixed score-ordered correlation pruning. V3.1 first measures that correlation graph and tests stronger selection strategies without relaxing the 0.80 absolute-correlation limit, changing reliability thresholds, enabling fallback, or using final rows:

```matlab
addpath(genpath(pwd));
run_v31_capacity
```

The audit compares the frozen greedy result with degree-aware, forced-start, seeded multistart, local-improvement, and bounded target-search methods. It reports a development-only lower bound unless the search completes exhaustively. See [docs/V31_CAPACITY_AUDIT.md](docs/V31_CAPACITY_AUDIT.md) for the integrity boundary and interpretation rules.

The first default audit completed exhaustively. All selector variants retained 26 bits, and the bounded exact search proved that the current 179-candidate correlation graph has no admissible 32-bit subset at the unchanged 0.80 limit. Development reliability remained 0.9471, uniqueness 0.5263, worst-scenario reliability 0.9248, and three-sweep reliability 0.9570. This closes selector-only optimization for the V3 representation; a later V3.1 study must construct a new enrollment-only bit representation and use a new final holdout.

## Run the V3.2 representation diagnostic

The next development step diagnoses why the 179 stable candidates collapse to a 26-node admissible set before a new bit construction is chosen. It uses enrollment and validation rows only and reports exact/complement pattern duplication, conflict components, effective rank, and embedding-axis reuse:

```matlab
addpath(genpath(pwd));
run_v32_representation_diagnostic
```

The diagnostic does not tune a threshold, select replacement bits, or consume any final-holdout row. See [docs/V32_REPRESENTATION_DIAGNOSTIC.md](docs/V32_REPRESENTATION_DIAGNOSTIC.md) for outputs and interpretation rules.

The first diagnostic run found 27 exact reference patterns and 26 canonical patterns after complement symmetry was removed. Those 26 patterns formed exactly 26 conflict components; one pattern was repeated 58 times. Entropy-effective rank was 5.561 for the PUF embedding medians, 3.890 for eligible continuous candidates, and 5.186 after binarization. This confirms that the unary/pairwise V3 candidate family repeatedly encoded the same population partitions.

## Run the exploratory V3.2 projected-PUF study

The next module replaces unary/pairwise candidate reuse with enrollment-only, within-core-variance-weighted projection directions. Validation applies the unchanged V3 stability, aliasing, and correlation gates, while known-test and unseen-development rows provide exploratory reporting:

```matlab
addpath(genpath(pwd));
run_v32_projected_puf_development
```

Locked V3 final rows are excluded from every calculation. Reaching 32 bits in this study would justify preregistering a new protocol with a larger core population and a new final holdout; it would not itself be a new supported result. See [docs/V32_PROJECTED_PUF_DEVELOPMENT.md](docs/V32_PROJECTED_PUF_DEVELOPMENT.md).

The exploratory run generated 8,553 deterministic projections, found 2,630
eligible projected candidates and 407 unique canonical patterns, and retained
64 mutually admissible bits. It passed all seven development checks without
using locked final rows. This is the motivation for the new protocol below;
it is not itself a final result.

## Prepare the preregistered V3.2 study

V3.2 freezes the projected representation and moves to a new seed, a new
64-core virtual population, and mechanically generated scenarios 201–218.
Preparation generates only known scenarios 201–208 and unseen-development
scenarios 209–214. Final scenarios 215–218 remain ungenerated.

```matlab
addpath(genpath(pwd));
run_tests
preparedV32 = main_v32_prepare();
```

Stop after preparation and archive the output. Do not call `main_v32_final`
until the preparation record has been reviewed. The final runner verifies the
frozen protocol and model, requires an explicit token, and writes a one-time
opening marker before it generates any final row. See
[docs/V32_PREREGISTRATION.md](docs/V32_PREREGISTRATION.md) for the complete
population, projection, partition, gate, and interpretation contract.

### Build the locked V3.2 evidence report

After the one-time final has been observed, create the read-only report and
scientific figure package without reopening the simulator:

```matlab
addpath(genpath(pwd));
run_tests
v32FinalReport = run_v32_final_report();
```

The reporter verifies the prepared/final contract, reproduces all ten stored
checks, validates the 2,304 final rows and scenarios 215–218, hashes the locked
inputs, and writes Markdown, Word-readable HTML, CSV evidence tables, and seven
PNG figures. See [docs/V32_FINAL_REPORTING.md](docs/V32_FINAL_REPORTING.md).

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
cfg.dataset.finalHoldoutConditionIds = [];
cfg.session.readsPerDecision = 1;
cfg.dataset.conditions = cfg.dataset.conditions(1:5);
for k = 1:numel(cfg.dataset.conditions)
    cfg.dataset.conditions(k).isUnseen = (k == 5);
    cfg.dataset.conditions(k).isFinalHoldout = false;
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
- exact three-read session formation and final-holdout execution paths.
- the exact 24-challenge V3 contract and unique reference challenge;
- persistent pinning-map reproducibility and cross-core differences;
- finite, seed-reproducible compact active responses;
- common-gain cancellation in differential challenge coordinates;
- active partition integrity and complete V3 identity/PUF/final-gate paths.
- V3.1 capacity reconstruction, final-row exclusion, and independent-set validity.
- V3.2 pattern/rank diagnostic reconstruction and excluded-row audit.
- V3.2 projected-bit determinism, encoder compatibility, and final-row exclusion.

Passing these tests establishes implementation invariants. It does not replace the full benchmark or experimental validation.

## Model pipeline

1. `defaultConfig` defines numerical, physical, split, and acceptance settings.
2. `createVirtualCore` samples a fixed latent microstructural identity.
3. `generateExcitation` generates sinusoidal, triangular, or trapezoidal `H(t)`.
4. `simulateBarkhausen` generates phase-coupled avalanche events and pickup voltage.
5. `extractFeatures` computes time, event, spectrum, phase, and Haar descriptors.
6. `splitDataset` separates repeat groups, the development holdout, and the preregistered final-holdout partition.
7. `tuneIdentityModel` selects a condition-robust centroid model on validation data.
8. `generateBinaryFingerprint` enrolls decorrelated stable differential bits.
9. `separateIdentityAndHealth` removes core centroids and learns health coordinates.
10. Evaluation preserves single-read metrics, adds three-read session metrics, and produces benchmark/final-holdout gates, CSV/MAT outputs, and 16 figures.

The separate V3 pipeline uses `createActiveCore`, `simulateChallengeResponse`, `generateActiveDataset`, and `buildDifferentialChallengeFeatures`. It then reuses the same training-only identity, verification, PUF, session, and leakage-control infrastructure before applying ten V3-specific final gates. `trainActivePUFTransform` fixes a separate 96-feature, 20-nuisance-component representation for raw-bit stability; validation rows screen bits but do not fit that transform. V3 disables fallback filling, so only candidates that pass every strict stability gate count toward the 32-bit requirement.

## Leakage controls

- Conditions 9 and 10 are absent from enrollment and validation and are now treated as observed development evidence.
- Conditions 11 and 12 were defined before their first run and are excluded from every fit, tuning decision, and PUF selection step.
- Repetitions 1–12 train, 13–16 validate, and 17–20 test for known conditions.
- Standardization, nuisance regression, Fisher ranking, centroids, covariance, and PUF thresholds are fitted on enrollment data only.
- Feature count, covariance regularization, nuisance-subspace size, and PUF bit stability use validation labels.
- Identity hyperparameters are scored on conditions excluded from the corresponding fold's enrollment rows.
- Test and unseen-condition labels never influence fitting or tuning.
- The identity nuisance model sees measurable operating variables only; it never sees stress, ageing, health state, or identity labels as predictors.
- V3 scenarios 115–118 were absent from every fit, hyperparameter choice, threshold, and bit-selection step in the locked first run. They are now observed and cannot be reused as fresh evidence.
- Candidate final scenarios 111–114 were used only during the pre-commit shadow design audit and are therefore permanently classified as development evidence.
- V3 uses a new random seed and independent scenario design; the observed V2.2 final conditions are not reused.
- V3 nuisance regression may use measured temperature, noise, sensor gain, and reset offset, but never stress, ageing, health state, or identity labels.

## Output files

`main` writes the following under `results/` when saving is enabled:

- `trafodna_results.mat`
- `trafodna_features.csv`
- `identity_accuracy_by_health.csv`
- `benchmark_comparison.csv`
- `final_holdout_checks.csv`
- `figures/01_excitation_field.png` through `figures/16_identity_accuracy_by_health.png`

Generated data and figures are ignored by Git; `results/README.md` remains tracked.

`main_active` writes under `results_active_v3/`:

- `trafodna_active_v3_results.mat`
- `active_response_features.csv`
- `active_final_checks.csv`
- `active_final_puf_by_scenario.csv`
- `active_passive_comparison.csv`
- `active_challenge_set.csv`
- `active_scenario_set.csv`
- `figures/01_active_challenge_matrix.png` through `08_active_final_accuracy_by_scenario.png`

## Repository layout

```text
TrafoDNA/
├── main.m
├── main_active.m
├── run_v31_capacity.m
├── run_v32_representation_diagnostic.m
├── run_v32_projected_puf_development.m
├── run_tests.m
├── README.md
├── MODEL.md
├── config/
├── challenges/
├── capacity/
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
├── results/
├── results_active_v3/
└── results_v31/
```

## Important limitations

1. The simulator does not spatially solve domains or domain walls.
2. Lamination geometry, grain maps, flux distribution, and pickup-coil placement are not directly modeled.
3. Parameter ranges are plausible numerical assumptions, not a calibration to a particular steel grade.
4. Identity separation in synthetic data does not establish real-world separability.
5. Operating metadata used by the V2 normalizer must be measured or supplied at inference time.
6. PUF-style metrics do not constitute a cryptographic security proof.
7. The reported V1 values came from one deterministic default configuration and should not be generalized beyond it.
8. A three-read decision requires three independent acquisitions and must always be reported separately from single-read performance.
9. Figures 11–13 are grouped-condition diagnostics. Temperature, noise, ageing, and other condition variables vary jointly, so these plots are not controlled one-factor causal sweeps.
10. The V3 persistent pinning-site map is a physics-inspired latent model, not a calibrated metallurgical reconstruction.
11. The idealized V3 excitation time is 11.52 seconds per 24-challenge sweep and 34.56 seconds per three-sweep decision; reset, switching, settling, and data-transfer overhead remain unmodeled.

See [MODEL.md](MODEL.md) for equations, [docs/BASELINE_ANALYSIS.md](docs/BASELINE_ANALYSIS.md) for the V1/V2 rationale, [docs/FINAL_HOLDOUT_RESULTS.md](docs/FINAL_HOLDOUT_RESULTS.md) for the locked V2.2 result, [docs/V3_DESIGN_AUDIT.md](docs/V3_DESIGN_AUDIT.md) for the transparent pre-freeze shadow audit, [docs/V3_PREREGISTRATION.md](docs/V3_PREREGISTRATION.md) for the active protocol, and [docs/V3_FINAL_RESULTS.md](docs/V3_FINAL_RESULTS.md) for its locked outcome.

## Path to physical validation

Replace `simulateBarkhausen` with a loader that provides `signalV`, `sampleRateHz`, synchronized `H(t)`, and measurable operating metadata. A physical study should control temperature, excitation amplitude and frequency, sensor placement, clamping torque, acquisition bandwidth, and core history. It should pre-register enrollment/test splits and report confidence intervals across independently manufactured cores.
