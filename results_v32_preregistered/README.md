# V3.2 preregistered outputs

`main_v32_prepare` writes the final-excluding prepared bundle and development
CSV files here. It must leave final-row counters at zero.

The `final/` directory is reserved for the explicit one-time final runner.
Do not place exploratory results in that directory and do not delete
`V32_FINAL_OPENED.lock` after a final opening.

Generated MAT, CSV, and lock files are ignored by version control.

After the locked final has been observed, run `run_v32_final_report` to create
the read-only evidence package under `report/`. The reporter hashes the three
locked inputs and reproduces the stored ten checks without generating data.
