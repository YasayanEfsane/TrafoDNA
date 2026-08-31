# TrafoDNA V3.2 locked-final reporting

This module converts the already observed V3.2 result into a reviewable
evidence package. It is deliberately read-only: it loads the prepared bundle,
locked final result, and final-opening marker; it does not call the simulator,
fit a model, choose a bit, or reopen the final holdout.

## Run

From the project root in MATLAB:

```matlab
addpath(genpath(pwd));
run_tests
v32FinalReport = run_v32_final_report();
```

The test suite should report 24 passed checks. The reporting command must
print that the stored final checks were reproduced and the integrity record
was verified.

## Inputs

The command requires these existing locked files:

- `results_v32_preregistered/v32_prepared_bundle.mat`
- `results_v32_preregistered/final/v32_final_result.mat`
- `results_v32_preregistered/final/V32_FINAL_OPENED.lock`

SHA-256 hashes for all three inputs are written to the evidence manifest.
The complete result-relevant protocol contract is compared with the prepared
bundle before reporting begins.

## Outputs

Outputs are written beneath `results_v32_preregistered/report/`:

- `V32_FINAL_OUTCOME.md`: repository-ready scientific outcome;
- `V32_FINAL_REPORT.html`: browser- and Word-readable report;
- `v32_final_report_summary.csv`: development/final/target comparison;
- `v32_final_scenario_metrics.csv`: identity and PUF results by scenario;
- `v32_final_per_bit_metrics.csv`: stability and balance for all selected bits;
- `v32_reference_bit_correlation.csv`: complete reference-bit correlation;
- `v32_final_integrity.csv`: partition and row-count evidence;
- `v32_evidence_manifest.csv`: input filenames, sizes, and SHA-256 hashes;
- `v32_final_report.mat`: machine-readable report structure;
- `figures/*.png`: seven 200-dpi scientific figures.

The HTML file uses relative figure paths. Keep it together with its `figures`
directory when opening it in Word or moving the report.

## Figures

1. Development versus locked-final performance.
2. Locked-final 64-core confusion matrix.
3. Locked-final verification ROC and EER operating point.
4. Intra-core and inter-core Hamming-distance distributions.
5. Identity accuracy and PUF reliability for final scenarios 215--218.
6. Final reliability of every selected projected bit.
7. Absolute enrollment-reference correlation among selected bits.

Bars use a zero baseline. Reliability plots state their frozen target. The
correlation heatmap is retained because selecting 64 bits does not imply 64
independent cryptographic bits.

## Integrity checks

For the locked default run, the reporter expects:

- 8,064 development rows;
- zero final rows generated or used during preparation;
- 2,304 final rows generated and used;
- final condition IDs 215--218;
- the stored ten final checks to reproduce exactly;
- the final PUF model to match the prepared projected-bit model.

Any mismatch stops reporting instead of silently rewriting evidence.

## Interpretation boundary

The generated report records a supported preregistered numerical result. It
does not claim physical transformer validation, independent 64-bit entropy,
or cryptographic security. The locked V3 result remains a separate 9/10
negative result; V3.2 does not retroactively change it.
