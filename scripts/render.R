#!/usr/bin/env Rscript
# Make render supplies JOB and REPORT_DIR; positional arguments are also accepted.
arguments <- commandArgs(trailingOnly = TRUE)
job <- if (length(arguments) >= 1L) arguments[[1]] else Sys.getenv("JOB")
folder <- if (length(arguments) >= 2L) arguments[[2]] else Sys.getenv("REPORT_DIR")
if (length(arguments) > 2L || !nzchar(job) || !nzchar(folder)) {
  stop("Usage: Rscript scripts/render.R JOB REPORT_DIR (or set JOB and REPORT_DIR)")
}
script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_argument) != 1L) stop("Cannot locate render.R")
root <- dirname(dirname(normalizePath(sub("^--file=", "", script_argument), mustWork = TRUE)))
source(file.path(root, "R/adapter.R"))
source(file.path(root, "R/render.R"))
render_saved_report(root, job, folder)
cat(file.path(normalizePath(folder), "rendering.json"), "\n", sep = "")
