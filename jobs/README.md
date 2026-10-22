# Run and inspect a job

Each `jobs/<job>/run.R` defines `calculate(context)`. The shared calculation library
lives in `R/`; the R adapter supplies the local helper closure. Job READMEs describe
the scientific inputs and settings.

```sh
make runtime JOB=mse_prepare
make run JOB=mse_prepare CONTEXT="$PWD/examples/context.json" OUT=/absolute/new-result
```

The host requires R with jsonlite, Make and Docker. The image supplies R packages
and Quarto. A context contains `key` (equal to JOB), `settings`, `job_settings`,
`run_id` and `parents`: a named object mapping upstream job keys to their
saved numerical results. Submission/QC also receive `source`; extraction receives
`extracted` with the saved SQL and selected rows. The coordinator owns the SQLite
snapshot and queries. The adapter reads only this repository's declared R sources.

`runtime.json` sets an immutable default image, platform and package page.
A named `jobs` entry can override those fields for one job, for example:

```json
{"jobs": {"mse_prepare": {"image": "registry.example/project@sha256:<64 hex digits>"}}}
```

Use a real published digest and compatible platform; this fragment illustrates
the mapping shape. An explicit local image config ID (`sha256:<64 hex digits>`)
is also accepted; it is recorded as a local config, never a published manifest.
`make runtime` emits only the selected effective binding.
`make run` inspects the actual image and calls `make inside-job` with read-only source
and one writable I/O directory. By default it retrieves a missing image and
disables job networking. `PULL=never` prohibits retrieval; `TIMEOUT=300` bounds each
Docker command. For restored offline images without a RepoDigest, supply
`RUNTIME=/absolute/runtime-identity.json` with the preserved image ID and ordered layers.

The result directory contains `response.json = {result,effects}`,
`context.json`, `runtime-selected.json`, `runtime-identity.json`,
`runtime-info.json`, `execution.json` and command logs. Choose a new result
directory for each invocation. The workflow coordinator separately records input
lineage and producing run IDs.

To render, place `report-data.json = {result,record}` in a writable report directory,
then invoke the following inside the selected image with this repository as the
working directory:

```sh
make render JOB=mse_prepare REPORT_DIR=/io
```

This reads saved values and never calls the calculation entry point. It preserves
`report.html`, a genuine Quarto/Typst `report.pdf`, QMD, JSON, Typst, plot assets and
`rendering.json` with observed rendering software and artifact checksums. The three
formal reports retain their component-owned `jobs/*_report/report.qmd` sources.
`make info JOB=<job>` inside the image emits actual R/package/Quarto versions.

