# V1 Baseline Analysis and V2 Remediation

## Observed V1 result

The deterministic default configuration produced:

| Metric | Value |
|---|---:|
| Known-condition identity accuracy | 35.16% |
| Unseen-condition identity accuracy | 33.38% |
| Printed EER | 0.3542 |
| PUF reliability | 0.6952 |
| PUF uniqueness | 0.5263 |
| Selected stable bits | 8 |
| Health classification accuracy | 67.43% |

All seven V1 implementation tests passed.

## Interpretation

With 20 enrolled cores, random identification accuracy is 5%. Both identity results therefore contain information, but they are not strong enough for a credible authentication claim. The 1.78 percentage-point gap between known and unseen conditions is small; the main issue is weak per-sample separation rather than a dramatic unseen-condition collapse.

An EER of 0.3542 means the genuine and impostor distance distributions overlap heavily. PUF uniqueness of 0.5263 is close to the ideal population mean of 0.5, but reliability of 0.6952 is too low for a stable response. Eight selected bits provide little capacity and make every flipped bit disproportionately important. Health accuracy is above a four-class chance level of 25%, but remains a feasibility result.

The V1 console labeled the EER as validation EER while passing `unseenMetrics.eer` to the printer. V2 corrects the label and reports both values.

## Root causes

1. **Identity information was compressed away.** The simulator contains an eight-harmonic, core-specific phase modulation, but V1 retained only positive and negative half-cycle energy ratios.
2. **Operating effects dominated shared features.** Temperature, excitation, noise, and gain affected the same amplitude, count, and spectrum dimensions used for identity.
3. **Every active feature entered the distance model.** No training-only ranking removed dimensions with high within-core variance and low between-core value.
4. **Covariance shrinkage was fixed.** One regularization value was used without validation evidence.
5. **PUF capacity was limited to unary features.** The 26 V1 features produced only eight selected bits after fallback.
6. **Structural tests had no algorithmic regression case.** Bounded FAR/FRR and finite metrics do not establish useful accuracy or robustness.
7. **Health PCA was variance-driven.** Unsupervised residual variance could prioritize noise over health separation.

## V2 remediation map

| Deficiency | Change | Leakage control |
|---|---|---|
| Lost phase signature | 12-bin event and energy ratios | Signal-derived only |
| Measurable nuisance variation | Enrollment-fitted ridge residualizer | Training rows only; no health variables |
| No feature selection | Fisher-ranked identity dimensions | Training labels only |
| Fixed covariance shrinkage | Validation grid search | No test or unseen data |
| Few unstable bits | Unary and differential PUF candidates | Enrollment repeats only |
| Redundant PUF bits | Reference-correlation filter | Enrollment references only |
| Weak test semantics | Transform-contract and synthetic unseen-shift tests | Deterministic synthetic fixture |
| No health feature filter | Residual health Fisher ranking before PCA | Training health labels only |

## Acceptance criteria

V2 encodes explicit engineering gates in `defaultConfig` and writes them to `results/benchmark_comparison.csv`. They are deliberately modest first milestones: at least 50% known-condition identity accuracy, at least 45% unseen-condition accuracy, unseen EER at most 0.30, PUF reliability at least 0.80, uniqueness between 0.35 and 0.65, at least 16 stable bits, and health accuracy of at least 65%.

Failure of a gate is an actionable result, not a reason to hide or overwrite the metric. Because no MATLAB-compatible runtime is bundled with the development environment, the branch must be executed in MATLAB before any performance improvement is claimed.

## Next evidence step

Run the unchanged default seed on the V2 branch, archive `benchmark_comparison.csv`, and inspect per-condition and per-health plots. If gates fail, adjust only training/validation choices or revise the measurement protocol transparently. Do not tune simulator identity strength against test or unseen-condition results.

## First V2.0 run

The first MATLAB run produced 51.41% known-condition accuracy, 42.75% unseen-condition accuracy, 0.2762 validation EER, 0.3297 unseen-condition EER, 0.7204 PUF reliability, 0.5263 uniqueness, 48 selected bits, and 77.36% health accuracy. Four of seven gates passed.

Relative to V1, known-condition accuracy improved by 16.25 percentage points, unseen-condition accuracy by 9.37 points, PUF reliability by 0.0252, and health accuracy by 9.93 points. Unseen EER fell by 0.0245. The larger 8.66-point known/unseen accuracy gap and the 0.0535 validation/unseen EER gap expose remaining domain shift.

The response also reached the exact 48-bit maximum. Code review showed that V2.0 ranked eligible bits first but continued filling from all balanced candidates until the maximum was reached. V2.1 stops after the eligible set and uses validation-screened backups only when required to reach 16 bits.

V2.1 therefore adds leave-one-condition-out hyperparameter tuning, a training-only within-core nuisance projection, and PUF screening by validation and worst-known-condition reliability. These changes are responses to the V2.0 evidence; the V2.0 test and unseen-condition values are not used as fitting data.
