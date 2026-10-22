# MSE report (`mse_report`)

Render the saved management-trial comparison as a Quarto report. Trial fractions describe this conditional illustration; they are not validated risk estimates.

**Path:** Saved management comparison → describe trade-offs and limits → MSE report.

**Inputs:** `runs/mse_summary/output.json` and the report job's saved run record.

**From:** [MSE results summary (`mse_summary`)](../mse_summary/README.md).

**Settings:** No job-specific settings (`{}`).

MSE must be enabled (`"mse": true`). The declared trials use 15 years, 20 paired replicates per fitted case and growth scenario, with catches capped at 40% of current biomass.

Supply this job's saved upstream results in a context JSON, then run from the repository root:

```sh
make run JOB=mse_report CONTEXT=/absolute/context.json OUT=/absolute/result
```

[run.R](run.R) defines `calculate(context)`; the component adapter loads its local R
library and writes `response.json` with `result` and `effects`. See the
[job guide](../README.md) for context fields, runtime selection and saved-result rendering.

[Saved report](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_report/report.html) · [Run record](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_report/record.json)
