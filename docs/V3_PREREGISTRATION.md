# V3 Active Challenge-Response Preregistration

## Status and integrity boundary

> **Post-run status:** The first scenarios 115–118 evaluation passed 9 of 10 gates and returned `NOT SUPPORTED`. These scenarios are now observed. The original protocol below remains unchanged; see [V3_FINAL_RESULTS.md](V3_FINAL_RESULTS.md) for the locked result.

This document defines TrafoDNA V3 before the outputs of active final scenarios 115–118 are inspected. The V2.2 final conditions 11–12 remain an observed historical audit set and are not reused by V3.

During pre-commit design work, a MATLAB-independent shadow implementation evaluated candidate scenarios 111–114 while comparing PUF averaging and nuisance-removal choices. Those scenarios are therefore observed development evidence, not final evidence. They were permanently moved into the development stress set before this preregistration. The replacement final scenarios 115–118 are generated mechanically as Halton points 23–26 in bases 2, 3, 5, 7, 11, and 13; their model outputs have not been evaluated.

The V3 final targets, scenario definitions, challenge matrix, random seed, feature construction, and evaluation protocol must be committed before the first default V3 run. After that run, scenarios 115–118 become observed and cannot be reused as unbiased evidence.

## Revised hypothesis

> A calibrated vector of differential Barkhausen responses to controlled magnetic challenges is more stable within a transformer core than between nominally identical cores across preregistered environmental and health shifts.

V3 does not assume that one passive waveform is a reliable identifier. It tests the interaction between a persistent virtual pinning map and a fixed challenge set.

## Fixed study design

- Random seed: `20260825`
- Virtual cores: 20
- Scenarios: 18 independent V3 scenarios
- Known scenarios: 101–108
- Development holdout: 109–114
- Final holdout: 115–118
- Sweeps per core and scenario: 9
- Enrollment sweeps: 1–4
- Validation sweeps: 5–6
- Known-condition test sweeps: 7–9
- Multi-sweep decision: median of 3 complete challenge sweeps
- Pinning sites per core: 256
- Measured cycles per challenge: 16

At a 50 Hz base frequency, the fixed 0.50/1.00 frequency matrix implies an idealized 11.52 seconds of excitation per complete sweep and 34.56 seconds for a three-sweep decision. Switching, reset, settling, and transfer time are excluded from that lower bound.

## Fixed challenge matrix

The 24 challenges are the Cartesian product of:

- waveform: sinusoidal, triangular, trapezoidal;
- field-amplitude scale: 0.65, 0.80, 1.00, 1.20;
- frequency scale: 0.50, 1.00.

The reference challenge is sinusoidal with unit amplitude and unit frequency scale. Every active sample contains the complete challenge matrix. Cost-reduced subsets may be studied later, but they cannot replace the preregistered full-sweep result.

## Representation

Each core has one fixed pinning-site map containing site thresholds, weights, rate sensitivities, spectral tendencies, branch signs, and challenge preferences. These quantities are never redrawn between measurements. Challenge activation and measurement noise remain stochastic.

Positive response quantities are log transformed. For challenge `c` and the reference challenge `r`, V3 uses

```text
delta(c) = log(response(c) + epsilon) - log(response(r) + epsilon)
```

Signed circular quantities use ordinary differences. The absolute reference response is retained. This construction reduces common sensor-gain effects while retaining the core-by-challenge response surface.

Only measurable temperature, noise level, sensor gain, and reset-field offset may enter the identity nuisance model. Stress, ageing, health state, and core labels are forbidden nuisance predictors.

The multiclass identity model and the PUF-style response use separate enrollment-only transforms. The PUF transform is fixed at 96 Fisher-ranked coordinates, covariance regularization 0.25, and 20 removed within-core nuisance components. Raw-bit candidate gates are 0.90 enrollment reliability, 0.90 validation reliability, and 0.88 worst-known-condition reliability. Candidate ranking weights those three quantities by 0.20, 0.30, and 0.50 respectively; no final row participates in the transform or bit selection. V3 disables minimum-length fallback: a bit that fails the strict gates cannot be used to satisfy the 32-bit requirement.

## Preregistered final gates

| Metric | Target |
|---|---:|
| Single-sweep identity accuracy | at least 60% |
| Single-sweep identity EER | at most 0.20 |
| Raw PUF reliability | at least 0.90 |
| PUF uniqueness | 0.45 to 0.55 |
| Strictly eligible raw fingerprint bits | at least 32 |
| Worst-final-scenario PUF reliability | at least 0.85 |
| Three-sweep identity accuracy | at least 70% |
| Three-sweep identity EER | at most 0.15 |
| Three-sweep PUF reliability | at least 0.93 |
| Gain over locked V2.2 passive final identity accuracy | at least 15 percentage points |

All ten checks must be printed and retained. The locked passive comparison value is 22.50%.

The preregistered V3 hypothesis is marked `SUPPORTED` only if all ten gates pass on the first untouched 115–118 evaluation. Any smaller count is `NOT SUPPORTED`, although individual subsystem results remain reportable.

## Prohibited shortcuts

- Do not enlarge core-to-core variation after seeing final results.
- Do not reduce sensor or activation noise after seeing final results.
- Do not select challenges, features, thresholds, or response bits on final scenarios.
- Do not use error correction to replace raw PUF reliability reporting.
- Do not describe a numerical result as physical or cryptographic validation.
- Do not reuse V2.2 conditions 11–12, V3 development scenarios 109–114, or final scenarios 115–118 as untouched evidence after inspection.

## Decision rule

The development holdout is a go/no-go diagnostic, not a final claim. The first default V3 final result is reported regardless of outcome. If active development evidence does not improve materially over the passive baseline, future challenge-selection work must use a new development design and must not consume the V3 final holdout.
