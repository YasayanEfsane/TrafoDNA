# V3.1 Capacity Development Audit

## Status

This is a post-V3 development protocol. The locked V3 result remains 9 of 10 gates and `NOT SUPPORTED`. Scenarios 115–118 are observed and are not treated as a new final holdout.

The V3 diagnostic found 179 candidates that passed enrollment reliability, validation reliability, worst-known-condition reliability, and population-balance screening. The frozen score-ordered greedy correlation selector retained 26 at the absolute correlation limit of 0.80. V3.1 first tests whether the six-bit deficit is caused by an avoidable ordering limitation before changing the simulator or bit representation.

## Fixed audit boundary

`analyzeV31Capacity` reconstructs candidate values, thresholds, reference bits, eligibility, and scores from the stored enrollment and validation partitions. It excludes every locked final row from selection and from the reported development metrics.

The audit keeps the V3 rules unchanged:

- enrollment reliability at least 0.90;
- validation reliability at least 0.90;
- worst-known-condition reliability at least 0.88;
- enrollment bit alias between 0.25 and 0.75;
- absolute pairwise reference-bit correlation at most 0.80;
- no fallback bits;
- target of at least 32 retained raw bits.

## Selector comparison

The audit compares four lower bounds on the admissible independent-set size:

1. the frozen V3 score-ordered greedy selector;
2. a deterministic dynamic minimum-degree selector;
3. forced-start and seeded multistart minimum-degree selectors;
4. one-for-two local improvements.

If these methods remain below 32, a bounded branch-and-bound search attempts either to find a 32-node independent set or to exhaust the graph. A time- or node-limited result is a lower bound, not proof that 32 is impossible.

## Interpretation rule

- If an admissible set of at least 32 is found, V3.1 may preregister the new selector while keeping the physical simulator and all raw-bit thresholds unchanged.
- If an exhaustive search proves a maximum below 32, V3.1 requires a new enrollment-only bit construction or challenge representation.
- If bounded search stops without reaching 32, the graph result is inconclusive; additional search or a stronger solver is required before changing the model.

Any later V3.1 hypothesis test must freeze a new random seed, new development scenarios, and a new untouched final holdout after the selector is chosen. The current audit is development evidence only and cannot support a new final claim.

## First default audit result

The default audit reproduced all 179 individually eligible candidates and the frozen 26-bit selection exactly. The deterministic degree-aware selector, forced-start and seeded multistart search, and local improvement also retained 26. The bounded branch-and-bound search completed exhaustively with a maximum independent-set size of 26, below the 32-bit target.

| Development metric | Result |
|---|---:|
| Eligible candidates before correlation | 179 |
| Frozen score-greedy bits | 26 |
| Degree-aware bits | 26 |
| Exhaustive maximum admissible bits | 26 |
| Target reached | No |
| PUF reliability | 0.9471 |
| PUF uniqueness | 0.5263 |
| Worst-development-scenario reliability | 0.9248 |
| Three-sweep PUF reliability | 0.9570 |
| Locked final rows used | 0 |

This proves that selector ordering is not the remaining bottleneck for the current graph. No algorithm can select 32 mutually admissible nodes from that fixed graph. Reaching the capacity target therefore requires a new enrollment-only representation, a better-conditioned population design, additional independent challenge contrasts, or a combination of these changes. The 0.80 correlation limit must not be relaxed merely to reverse the observed result.

## Run

With the locked V3 result structure still available:

```matlab
addpath(genpath(pwd));
run_v31_capacity
```

The runner uses `activeResults` when it is already in the workspace; otherwise it loads `results_active_v3/trafodna_active_v3_results.mat`. It does not silently rerun the full V3 simulation.

The default audit writes its MAT bundle, selected-bit table, correlation-edge table, and summary under `results_v31/`.
