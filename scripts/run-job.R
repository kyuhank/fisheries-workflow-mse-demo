source("R/adapter.R")
require_container()
key <- job_key()
context_path <- Sys.getenv("CONTEXT")
output <- Sys.getenv("OUT")
if (!nzchar(context_path) || !file.exists(context_path)) stop("CONTEXT must be an existing JSON file")
if (!nzchar(output)) stop("OUT is required")
context <- read_json(context_path)
if (!identical(context$key, key)) stop("CONTEXT key differs from JOB")
# Source only the component's declared closure, never caller-supplied host paths.
environment <- new.env(parent = globalenv())
source("R/common.R", local = environment)
component <- read_json("SOURCE.json")$library$path
if (file.exists("R/assessment-recurrence.R")) source("R/assessment-recurrence.R", local = environment)
source(component, local = environment)
source(file.path("jobs", key, "run.R"), local = environment)
if (!is.function(environment$calculate)) stop("Job must define calculate(context)")
result <- environment$calculate(context)
effects <- attr(result, "workflow_effects", exact = TRUE)
attr(result, "workflow_effects") <- NULL
if (is.null(effects)) effects <- structure(list(), names = character())
if (!is.list(result) || is.null(names(result)) || !is.list(effects) || is.null(names(effects))) {
  stop("Result and effects must be JSON objects")
}
write_json(list(result = result, effects = effects), file.path(output, "response.json"))

