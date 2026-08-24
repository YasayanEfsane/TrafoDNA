# Locked V3 Active Final Result

## Integrity record

The active protocol was frozen in commit `a0506152845b6fc22af1785b22e5a68b90e7462f` before the first MATLAB evaluation of scenarios 115–118. The first result below is retained without changing the challenge matrix, simulator noise, feature representation, PUF filters, target values, or decision rule.

Scenarios 115–118 are now observed. They cannot be used for fitting, threshold selection, challenge selection, feature engineering, or future claims of untouched evidence.

## First default-seed result

| Development metric | Result |
|---|---:|
| Known-scenario identity accuracy | 100.00% |
| Development identity accuracy | 100.00% |
| Development identity EER | 0.0110 |
| Pooled raw PUF reliability | 0.9471 |
| Pooled PUF uniqueness | 0.5263 |
| Three-sweep development identity accuracy | 100.00% |
| Three-sweep development identity EER | 0.0028 |
| Three-sweep development PUF reliability | 0.9525 |
| Selected active identity features | 72 |
| Selected raw fingerprint bits | 26 |
| Eligible candidates before correlation pruning | 179 |
| Strictly eligible raw fingerprint bits | 26 |
| Fallback fingerprint bits | 0 |

### Preregistered final gates

| Metric | Result | Target | Passed |
|---|---:|---:|:---:|
| Single-sweep identity accuracy | 100.00% | at least 60% | Yes |
| Single-sweep identity EER | 0.0038743 | at most 0.20 | Yes |
| Raw PUF reliability | 0.93953 | at least 0.90 | Yes |
| PUF uniqueness | 0.52632 | 0.45 to 0.55 | Yes |
| Strictly eligible raw fingerprint bits | 26 | at least 32 | **No** |
| Worst-final-scenario PUF reliability | 0.91987 | at least 0.85 | Yes |
| Three-sweep identity accuracy | 100.00% | at least 70% | Yes |
| Three-sweep identity EER | 0.0004386 | at most 0.15 | Yes |
| Three-sweep PUF reliability | 0.95048 | at least 0.93 | Yes |
| Gain over locked passive identity accuracy | 77.50 percentage points | at least 15 points | Yes |

The first final run passed **9 of 10** gates. Under the preregistered all-gates decision rule, the result is:

> **NOT SUPPORTED**

## Passive V2.2 comparison

| Metric | Passive V2.2 | Active V3 | Change |
|---|---:|---:|---:|
| Single-sweep identity accuracy | 0.22500 | 1.00000 | +0.77500 |
| Single-sweep identity EER | 0.41066 | 0.0038743 | -0.40679 |
| Raw PUF reliability | 0.69727 | 0.93953 | +0.24226 |
| Three-sweep identity accuracy | 0.24583 | 1.00000 | +0.75417 |
| Three-sweep identity EER | 0.39638 | 0.0004386 | -0.39594 |
| Three-sweep PUF reliability | 0.72031 | 0.95048 | +0.23017 |

These comparisons are engineering contrasts between two numerical protocols, not a controlled physical experiment.

## Interpretation

Within this reduced virtual model, active differential challenge responses solved the identity-separation and verification problem decisively. The final identity accuracy and EER substantially exceeded their preregistered targets, and PUF reliability, uniqueness, worst-scenario reliability, and three-sweep reliability also passed.

The remaining failure is response capacity under the strict raw-bit definition. The post-run capacity diagnostic shows that 179 candidates passed the enrollment, validation, worst-condition, and population-balance eligibility screen. The fixed score-ordered greedy selector retained only 26 after applying the absolute cross-bit-correlation limit of 0.80; the protocol required 32. The bottleneck is therefore correlation pruning under the current selection rule, not a shortage of stable and balanced candidates. However, the count of 179 does not prove that a mutually admissible 32-bit subset exists because the greedy result can depend on ordering and the maximum independent-set size has not been established.

The six-bit deficit must not be hidden by relaxing the target, increasing the allowed correlation, or enabling fallback after observing the result.

The result therefore supports the narrower numerical claim that active challenge responses are far more separable and stable than the passive V2.2 representation. It does not support the complete preregistered V3 hypothesis, a 32-bit raw response claim, physical-core performance, or cryptographic security.

## Locked next-step boundary

Future V3.1 development may inspect the V3 models and scenarios 109–118, but it must introduce new development and final scenarios before making another unbiased claim. The first development task is to measure the correlation graph of the 179 eligible candidates and compare the frozen score-ordered greedy result with deterministic degree-aware and multistart independent-set heuristics. Any new selector, bit construction, challenge design, population size, or decorrelation method must be selected without evaluating the next final holdout.
