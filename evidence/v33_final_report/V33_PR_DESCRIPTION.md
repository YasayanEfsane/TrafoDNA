# Add preregistered V3.3 independent-population robustness audit

## Summary

This change adds the preregistered V3.3 robustness stage and its read-only locked-final evidence. V3.3 keeps the V3.2 method and ten thresholds frozen, then evaluates five independently seeded 64-core virtual populations on five disjoint Halton condition blocks.

## Frozen decision rule

- Every cohort is evaluated; no early stopping.
- A cohort passes only when all 10 V3.2 gates pass.
- V3.3 is supported only when at least 4 of 5 cohorts pass.
- All five models are frozen before any final row is generated.

## Locked result

- Passing cohorts: **5/5**
- Cohort checks: **50/50**
- Final rows generated and used: **11,520 / 11,520**
- Mean identity accuracy: **99.90%**
- Maximum identity EER: **0.0261**
- Mean raw PUF reliability: **0.9648**
- Minimum worst-scenario reliability: **0.9527**
- Decision: **SUPPORTED**

## Validation

- The final audit lock records `OPENED` and `COMPLETED`.
- The final MAT recomputes to `9b3ff468dccbd9ca0654582f3d3f52f6f88413cf599dc46d30282e5e0aa7effb`.
- The final cohort CSV independently reproduces the 5/5 decision.
- The preparation archive hash matches the preregistered freeze record.
- Reporting uses frozen evidence only and performs no refitting or final generation.

## Interpretation

The result supports numerical robustness to virtual-population and acquisition seeds inside the same simulator. It does not establish physical repeatability, independent 64-bit entropy, attack resistance, or deployable cryptographic security.
