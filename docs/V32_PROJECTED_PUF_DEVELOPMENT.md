# V3.2 Stability-Weighted Projected PUF Development

## Motivation

The V3.2 representation diagnostic reconstructed 179 individually eligible V3 candidates but found only 27 exact population patterns and 26 patterns after a bit and its complement were treated as the same split. The 26 canonical patterns formed exactly 26 correlation-conflict components, and one pattern was repeated 58 times. The V3 unary/pairwise candidate family was therefore re-encoding the same core partitions rather than creating additional raw-bit capacity.

The effective-rank measurements supported the same conclusion:

| Representation | Entropy-effective rank |
|---|---:|
| PUF embedding core medians | 5.561 |
| Eligible continuous candidate medians | 3.890 |
| Eligible binary reference bits | 5.186 |

Adding more pairwise differences or changing the graph selector cannot solve this bottleneck.

## Exploratory V3.2 construction

`trainV32ProjectedPUF` uses only enrollment rows to:

1. estimate repeat variation within each core;
2. scale embedding axes by that within-core variation;
3. identify the between-core subspace with an SVD;
4. generate deterministic axis, two-axis, isotropic-random, and energy-weighted projection directions;
5. threshold every direction using the enrollment core medians.

Validation rows apply the unchanged V3 enrollment reliability, validation reliability, worst-known-condition reliability, aliasing, and absolute-correlation limits. Exact and complementary reference patterns are collapsed before selection. No fallback bits are allowed.

The default bank contains 8,553 deterministic projections when all 19 population dimensions are available: 19 axes, 342 signed two-axis combinations, and 8,192 seeded random projections.

## Development boundary

- Enrollment rows fit the PUF transform, stability scaling, projection bank, thresholds, and enrolled reference responses.
- Validation rows screen candidate stability.
- Known-test and unseen-development rows report exploratory performance.
- Locked V3 final rows are never encoded or evaluated and the report must show `Locked final rows used: 0`.
- Scenarios 115--118 remain observed and cannot serve as a V3.2 final holdout.

Even if the exploratory run reaches 32 bits, it is not a supported V3.2 hypothesis result. A later test requires a frozen projection protocol, a larger virtual-core population for more credible cross-bit correlation estimates, newly generated development scenarios, and a new untouched final holdout.

## Run

With `activeResults` still in the MATLAB workspace:

```matlab
run_v32_projected_puf_development
```

Otherwise place `trafodna_active_v3_results.mat` in `results_active_v3/` and run the same command.

## Outputs

Results are written under `results_v32_projected/`:

| File | Meaning |
|---|---|
| `v32_projected_summary.csv` | Projection counts and pooled development metrics |
| `v32_projected_selected_bits.csv` | Selected patterns, stability, margins, and correlations |
| `v32_projected_by_condition.csv` | Development reliability by scenario |
| `v32_projected_development_checks.csv` | Reference-gate comparison; not a final decision table |
| `v32_projected_puf_development.mat` | Complete exploratory study and fitted projected-bit model |
