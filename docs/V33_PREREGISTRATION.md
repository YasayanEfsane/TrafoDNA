# TrafoDNA V3.3 independent-population robustness protocol

**Protocol version:** `3.3.0-preregistered`
**Freeze date:** 31 August 2026
**Status:** five-cohort preparation permitted; every final remains sealed.

## Question

The locked V3.2 run passed all ten preregistered gates on one new 64-core
virtual population. V3.3 asks whether that result is robust to independently
seeded virtual populations and completely new operating-condition blocks:

> Does the unchanged V3.2 method pass all ten frozen gates in at least four
> of five independently generated 64-core cohorts?

V3.3 tests numerical robustness inside the same simulator. It is not an
independent physical replication and does not convert simulated evidence into
cryptographic validation.

## Frozen cohort design

Each cohort contains 64 new virtual cores, 18 condition rows, nine repeated
sweeps, 24 challenges per sweep, 16 cycles per challenge, and 256 persistent
pinning sites per core.

| Cohort | Population seed | Halton indices | Scenario IDs | Known | Development | Locked final |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 20260901 | 59–76 | 301–318 | 301–308 | 309–314 | 315–318 |
| 2 | 20260902 | 77–94 | 401–418 | 401–408 | 409–414 | 415–418 |
| 3 | 20260903 | 95–112 | 501–518 | 501–508 | 509–514 | 515–518 |
| 4 | 20260904 | 113–130 | 601–618 | 601–608 | 609–614 | 615–618 |
| 5 | 20260905 | 131–148 | 701–718 | 701–708 | 709–714 | 715–718 |

The six-dimensional Halton coordinates map to the frozen V3.2 temperature,
noise, sensor-gain, reset, stress, and ageing ranges. None of the 90 scenario
IDs or Halton rows reuses an observed V3 or V3.2 final.

Per cohort, preparation generates 8,064 rows:

```text
64 cores × 14 non-final conditions × 9 repetitions = 8,064
```

The complete preparation therefore generates 40,320 non-final rows and must
report zero final rows generated and zero final rows used. A final opening
would later generate 2,304 rows per cohort and 11,520 rows in total.

## Frozen method and ten cohort gates

V3.3 retains the V3.2 challenge set, simulator, identity transform, projected
candidate construction, thresholds, and selection rule. In particular:

- 8,192 deterministic random projections;
- 19 stable-subspace dimensions;
- projection seed 20260831;
- at least 32 and at most 64 selected projected bits;
- no fallback bits;
- maximum absolute reference correlation 0.80.

Each cohort is independently fitted using only that cohort's known training
and validation rows. Development readiness is reported but cannot be used to
select or discard cohorts. Before any final row is generated, all five cohort
populations and models must be prepared and frozen.

| Cohort final criterion | Requirement |
|---|---:|
| Single-sweep identity accuracy | ≥ 0.60 |
| Single-sweep identity EER | ≤ 0.20 |
| Raw projected-PUF reliability | ≥ 0.90 |
| Projected-PUF uniqueness | 0.45–0.55 |
| Strictly eligible projected bits | ≥ 32 |
| Worst-final-scenario PUF reliability | ≥ 0.85 |
| Three-sweep identity accuracy | ≥ 0.70 |
| Three-sweep identity EER | ≤ 0.15 |
| Three-sweep PUF reliability | ≥ 0.93 |
| Maximum selected-bit reference correlation | ≤ 0.80 |

A cohort passes only if all ten gates pass. The V3.3 hypothesis is
**SUPPORTED** only when at least four of five cohorts pass. Three or fewer
passing cohorts produce **NOT SUPPORTED**. Every cohort final is evaluated;
there is no early stopping after four successes or two failures.

## Sealing, checkpointing, and interruption rule

`main_v33_prepare` contains no final-generation path and checkpoints after
each prepared cohort. Re-running it resumes from the first unfinished cohort.
It never overwrites a completed cohort and refuses to run after the final
audit has opened.

The final audit requires a complete five-cohort prepared bundle, creates an
opening marker and a checkpoint before evaluation, and checkpoints after each
cohort. An interrupted current cohort may be deterministically reconstructed
from its frozen seed; already checkpointed final cohorts are not regenerated.
No metric may change the loop order or stop evaluation early.

The public source contains no final-opening value. A locally authorised final
must obtain its workflow token from `TRAFODNA_V33_FINAL_TOKEN`. This value is
not a scientific parameter and is omitted from the frozen protocol contract.

## Preparation command and stopping rule

From the project root:

```matlab
addpath(genpath(pwd));
run_tests
preparedV33 = main_v33_prepare();
```

The tests should report 27 passes. Preparation can take substantially longer
than V3.2 because it fits five independent populations. When it finishes,
archive `results_v33_robustness/v33_prepared_bundle.mat` and review the
five-row development summary. Do not open the final audit during the same
review cycle.

Development failure does not authorise threshold changes, seed replacement,
cohort removal, or final-row inspection. Any revised algorithm is a new
version and requires new ungenerated final conditions.

## Interpretation boundary

This protocol measures sensitivity to virtual-population and acquisition
seeds under one numerical model. A supported outcome strengthens the claim of
simulator-level robustness, but does not establish physical repeatability,
manufacturing uniqueness, independent 64-bit entropy, resistance to attack,
or deployable cryptographic security.
