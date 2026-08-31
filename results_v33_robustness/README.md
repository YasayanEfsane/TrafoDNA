# V3.3 independent-population robustness outputs

`main_v33_prepare` checkpoints five independently seeded 64-core cohort models
in this directory. Preparation must preserve:

```text
finalRowsGenerated = 0
finalRowsUsed      = 0
```

The `final/` directory is reserved for the single joint final audit. Do not
delete its opening marker or checkpoint, do not remove weak cohorts, and do
not run cohort finals separately.

Generated MAT, CSV, lock, checkpoint, and cohort-output files are ignored by
version control. This README remains tracked.
