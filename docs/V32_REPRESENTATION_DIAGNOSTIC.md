# V3.2 Representation Diagnostic

## Purpose

The locked V3 run passed 9 of 10 gates but retained only 26 of the required 32 strict raw bits. The exhaustive V3.1 audit proved that 26 is the maximum independent-set size for the fixed 179-candidate graph at the unchanged absolute-correlation limit of 0.80. Selector-only optimization is therefore closed for that representation.

V3.2 begins with a diagnostic rather than another selector. `analyzeV32Representation` reconstructs the frozen enrollment and validation candidate population and measures where representation capacity is being lost:

- exact binary response-pattern duplication;
- duplication after treating a bit and its complement as one pattern class;
- conflict-graph density and connected-component sizes;
- numerical, entropy-effective, and participation-ratio rank;
- reuse of the same transformed embedding axes across eligible candidates;
- unary-axis versus pairwise-difference candidate counts.

The diagnostic selects no new bits and changes no thresholds.

## Integrity boundary

Only the frozen enrollment and validation rows are transformed. Known-condition test rows, unseen-development rows, and locked final rows are excluded from every diagnostic calculation. The report records all excluded-partition usage explicitly and must show:

```text
Locked final rows used : 0
Frozen thresholds reproduced : YES
Frozen eligible count reproduced : YES
```

Scenarios 115--118 are already observed. They cannot become a new final holdout. Any later V3.2 hypothesis test requires newly generated development scenarios, a new random seed, a newly locked final holdout, and a frozen representation before that holdout is evaluated.

## Run

Place the original locked result at:

```text
results_active_v3/trafodna_active_v3_results.mat
```

Then run:

```matlab
clear
clc
cd C:\Users\yusuf\OneDrive\Masaüstü\TrafoDNA
addpath(genpath(pwd))
run_v32_representation_diagnostic
```

If `activeResults` is already loaded, the runner uses it directly.

## Outputs

The default run writes these development-only artifacts under `results_v32/`:

| File | Meaning |
|---|---|
| `v32_representation_summary.csv` | Compact counts, graph density, effective ranks, and row-use audit |
| `v32_eligible_candidates.csv` | Candidate provenance, reliability, pattern class, component, and degree |
| `v32_pattern_classes.csv` | Canonical response patterns and their multiplicities |
| `v32_conflict_components.csv` | Correlation-conflict component sizes and degree ranges |
| `v32_embedding_axes.csv` | Embedding-axis reuse and correlation burden |
| `v32_representation_diagnostic.mat` | Complete MATLAB diagnostic structure |

## Interpretation before implementation

1. If the canonical-pattern count is small and multiplicities are high, unary axes and pairwise differences are repeatedly encoding the same core partition. V3.2 should replace the candidate family, not the selector.
2. If the candidate or binary effective rank is low, the PUF transform is concentrating identity information into too few population directions. V3.2 should test enrollment-only whitening or diversity-constrained projection learning.
3. If conflict density is concentrated in a few embedding axes, V3.2 should limit axis reuse or construct challenge-local contrasts before global projection.
4. If the graph is structurally diverse but stability filters remove most alternative patterns, V3.2 should improve challenge repeatability or the physical response representation rather than weaken reliability gates.

No threshold may be relaxed merely because this diagnostic exposes a bottleneck. Error correction may be studied later for reconstruction, but it cannot be counted as additional strict raw-bit capacity.
