.DEFAULT_GOAL := help
JOB ?=
CONTEXT ?=
OUT ?=
REPORT_DIR ?=
RUNTIME ?=
PULL ?= missing
NETWORK ?= none
TIMEOUT ?= 300
export JOB CONTEXT OUT REPORT_DIR RUNTIME PULL NETWORK TIMEOUT

.PHONY: help runtime run inside-job render info
help:
	@printf '%s\n' 'make runtime JOB=<job>' 'make run JOB=<job> CONTEXT=/absolute/context.json OUT=/absolute/result' 'make render JOB=<job> REPORT_DIR=/io'

runtime:
	@Rscript --vanilla scripts/runtime.R

run:
	@Rscript --vanilla scripts/launch.R

inside-job:
	@Rscript --vanilla scripts/run-job.R

render:
	@Rscript --vanilla scripts/render.R

info:
	@Rscript --vanilla scripts/info.R

