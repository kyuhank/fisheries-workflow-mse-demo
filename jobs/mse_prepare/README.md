# Prepare MSE (`mse_prepare`)

Reconstruct next-year Schaefer stocks after the terminal assessment catch, then prepare common seeded growth and observation errors once for all three management rules.

**Path:** Four fitted cases → define future trials → shared simulation inputs.

**Inputs:** All four assessment outputs: r, K, q, annual catches, observed indices and the declared next-year biomass.

**From:** [Assessment A1 (`assessment_a1`)](https://github.com/kyuhank/fisheries-workflow-assessment-demo/tree/main/jobs/assessment_a1), [Assessment A2 (`assessment_a2`)](https://github.com/kyuhank/fisheries-workflow-assessment-demo/tree/main/jobs/assessment_a2), [Assessment B1 (`assessment_b1`)](https://github.com/kyuhank/fisheries-workflow-assessment-demo/tree/main/jobs/assessment_b1), [Assessment B2 (`assessment_b2`)](https://github.com/kyuhank/fisheries-workflow-assessment-demo/tree/main/jobs/assessment_b2).

**Settings:** No job-specific settings (`{}`).

MSE must be enabled (`"mse": true`). The declared trials use 15 years, 20 paired replicates per fitted case and growth scenario, with catches capped at 40% of current biomass.

Supply this job's saved upstream results in a context JSON, then run from the repository root:

```sh
make run JOB=mse_prepare CONTEXT=/absolute/context.json OUT=/absolute/result
```

[run.R](run.R) defines `calculate(context)`; the component adapter loads its local R
library and writes `response.json` with `result` and `effects`. See the
[job guide](../README.md) for context fields, runtime selection and saved-result rendering.

[Saved report](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_prepare/report.html) · [Run record](https://kyuhank.github.io/fisheries-workflow-demo/example/mse_prepare/record.json)
