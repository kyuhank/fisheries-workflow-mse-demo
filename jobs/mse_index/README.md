# Index rule (`mse_index`)

Test advice proportional to the three-year mean observed abundance index in the common seeded Schaefer management trials.

**Path:** Shared trials → index-based catch → catch and biomass outcomes.

**Inputs:** Stocks, scenarios and saved `error_streams` in `runs/mse_prepare/output.json`.

**From:** [Prepare MSE (`mse_prepare`)](https://github.com/kyuhank/fisheries-workflow-mse-demo/tree/main/jobs/mse_prepare).

**Settings:** No job-specific settings (`{}`).

MSE must be enabled (`"mse": true`). The declared trials use 15 years, 20 paired replicates per fitted case and growth scenario, with catches capped at 40% of current biomass.

Supply this job's saved upstream results in a context JSON, then run from the repository root:

```sh
make run JOB=mse_index CONTEXT=/absolute/context.json OUT=/absolute/result
```

[run.R](run.R) defines `calculate(context)`; the component adapter loads its local R
library and writes `response.json` with `result` and `effects`. See the
[job guide](../README.md) for context fields, runtime selection and saved-result rendering.

[Saved report](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_index/report.html) · [Run record](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_index/record.json)
