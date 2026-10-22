# Fisheries workflow MSE example

These six jobs prepare common future trials, test constant catch, an index rule
and a buffered rule, then compare their catch, biomass and catch stability.
The [coordinator](https://github.com/kyuhank/fisheries-workflow-demo) loads an exact
source revision and preserves each producing record.

The fitted Schaefer cases are teaching inputs. In the public-data example they
inherit an unvalidated link between the selected Fiji fleet CPUE and stock-wide
abundance. The same saved growth and observation errors are used for all rules.

Realised catch is capped at 40% of true starting biomass, a simulator guardrail
shared by every rule. Low-biomass statistics are conditional on that safeguard;
they do not show that a rule would be safe without it. Cases and scenarios have
equal comparison weight, rather than estimated probabilities. The example
provides no calibrated risk estimates or real-fishery advice.

Run a supplied context with host R (jsonlite), Make and Docker:

```sh
make runtime JOB=mse_prepare
make run JOB=mse_prepare CONTEXT="$PWD/examples/context.json" OUT=/absolute/new-result
```

The repository's Makefile launches the job in its selected image. Numerical code is
in [R/mse.R](R/mse.R) and [jobs/](jobs/README.md). `response.json` contains the
result and declared workflow effects; runtime and execution JSON files identify
the image and software actually used. See the [job guide](jobs/README.md) for
input fields and rendering saved results. The small synthetic example illustrates
the adapter interface; use recorded upstream outputs for an actual workflow.

[SOURCE.json](SOURCE.json) records the calculation library's baseline origin and
SHA-256. The R library and calculation entry points retain those source bytes;
the report and reader guides have been revised for the public-data example.
