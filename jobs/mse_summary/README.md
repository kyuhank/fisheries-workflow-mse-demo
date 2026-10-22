# MSE results summary (`mse_summary`)

Compare the three rules only when fitted stocks, scenarios and the actual saved error vectors match. Summarise catches, biomass and catch stability.

**Path:** Three rule outputs → compare trial metrics → management comparison.

**Inputs:** Completed constant, index and buffered rule outputs, including their actual common error vectors.

**From:** [Constant catch (`mse_constant`)](../mse_constant/README.md), [Index rule (`mse_index`)](../mse_index/README.md), [Buffered rule (`mse_buffered`)](../mse_buffered/README.md).

**Settings:** No job-specific settings (`{}`).

MSE must be enabled (`"mse": true`). The declared trials use 15 years, 20 paired replicates per fitted case and growth scenario, with catches capped at 40% of current biomass.

Supply this job's saved upstream results in a context JSON, then run from the repository root:

```sh
make run JOB=mse_summary CONTEXT=/absolute/context.json OUT=/absolute/result
```

[run.R](run.R) defines `calculate(context)`; the component adapter loads its local R
library and writes `response.json` with `result` and `effects`. See the
[job guide](../README.md) for context fields, runtime selection and saved-result rendering.

[Saved report](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_summary/report.html) · [Run record](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_summary/record.json)
