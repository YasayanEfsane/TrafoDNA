# Locked V2.2 Final-Holdout Result

## Status

This document records the first evaluation of preregistered conditions 11–12. The conditions and seven targets were committed before their outputs were inspected. This result must be retained regardless of future development.

Conditions 11–12 are now observed. They are permanently frozen and must never again be described as untouched final-holdout evidence.

## Configuration

- Random seed: `20260824`
- Enrolled cores: 20
- Known conditions: 1–8
- Observed development holdout: 9–10
- Preregistered final holdout: 11–12
- Repetitions per condition: 20
- Multi-read protocol: median of 3 consecutive independent reads
- Identity tuning: leave one known condition out
- Selected identity features: 32
- Removed nuisance components: 0
- Covariance regularization: 0.05
- Selected PUF bits: 16

## Development-holdout result

| Metric | Single read | Three reads | Change |
|---|---:|---:|---:|
| Identity accuracy | 42.88% | 50.42% | +7.54 percentage points |
| Identity EER | 0.3332 | 0.2795 | -0.0537 |
| PUF reliability | 0.7598 | 0.8059 | +0.0461 |

The three-read protocol materially reduced stochastic error on the already observed development conditions.

## First final-holdout result

| Metric | Single read | Three reads | Preregistered target | Passed |
|---|---:|---:|---:|:---:|
| Identity accuracy | 22.50% | — | at least 45% | No |
| Identity EER | 0.4107 | — | at most 0.30 | No |
| PUF reliability | 0.6973 | — | at least 0.80 | No |
| Health classification accuracy | 90.38% | — | at least 65% | Yes |
| Identity accuracy | — | 24.58% | at least 55% | No |
| Identity EER | — | 0.3964 | at most 0.25 | No |
| PUF reliability | — | 0.7203 | at least 0.85 | No |

Final-holdout checks passed: **1/7**.

## Interpretation

Three-read aggregation improved final identity accuracy by only 2.08 percentage points, EER by 0.0143, and PUF reliability by 0.0230. This is much smaller than the development-holdout improvement. The dominant final error is therefore systematic domain shift, not independent read noise. More voting or repeated reads cannot be expected to solve it by themselves.

The identity representation and PUF response do not generalize to the jointly shifted temperature, excitation, sensor, stress, and ageing combinations in conditions 11–12. Leave-one-known-condition-out validation was not representative of this more severe shift. The selection of zero nuisance components is consistent with the training conditions failing to expose a transferable nuisance direction.

Health accuracy of 90.38% is the only passed final gate. This indicates that the residual health representation generalized substantially better than the core-identity representation. It does not validate the identity or PUF hypotheses.

## Scientific conclusion

Under the present simulator, features, population, and arbitrary operating-condition protocol:

- the passive single-read transformer-core identity hypothesis is not supported on the final holdout;
- three-read aggregation does not restore final-holdout identity separation;
- the PUF-style response is not sufficiently reliable on the final holdout;
- health-state classification remains numerically feasible.

These are simulation findings, not physical transformer conclusions.

## Integrity rule for future work

No subsequent threshold, feature, condition normalizer, simulator parameter, or read-count choice may be tuned on conditions 11–12 and then reported against those same conditions as unbiased evidence.

A clean next study requires a new preregistered evaluation set. The recommended research direction is an **active magnetic challenge-response protocol** with controlled excitation challenges and a broader factorial or space-filling operating-condition design. That study must define its challenge set, training domains, new final conditions, metrics, and targets before the new final outputs are inspected.
