# JSON and process helpers shared by the command-line adapters.
# Array/scalar encoding follows the original workflow R driver.
workflow_json_value <- function(value, object_field = FALSE) {
  if (is.list(value)) {
    object <- !is.null(names(value))
    result <- lapply(value, workflow_json_value, object_field = TRUE)
    if (object) names(result) <- names(value)
    return(result)
  }
  array <- !is.null(dim(value))
  if (array) {
    if (length(dim(value)) != 1L) stop("JSON job arrays must be one-dimensional")
    value <- as.vector(value)
  }
  if (is.numeric(value) && any(!is.finite(value))) stop("Non-finite R output")
  if (object_field && length(value) == 1L && !array) return(jsonlite::unbox(value))
  value
}

workflow_encode <- function(value) {
  as.character(jsonlite::toJSON(workflow_json_value(value), auto_unbox = FALSE,
                               digits = NA, null = "null", na = "null"))
}

read_json <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile("json-", tmpdir = dirname(path))
  on.exit(unlink(temporary), add = TRUE)
  writeLines(workflow_encode(value), temporary, useBytes = TRUE)
  if (!file.rename(temporary, path)) stop("Could not save ", path)
  invisible(path)
}

job_key <- function() {
  key <- Sys.getenv("JOB")
  declared <- unlist(read_json("SOURCE.json")$jobs, use.names = FALSE)
  if (length(key) != 1L || !key %in% declared) stop("JOB must name a declared job")
  key
}

require_container <- function() {
  if (!any(file.exists(c("/.dockerenv", "/run/.containerenv")))) {
    stop("Use make run to execute in the selected container")
  }
  image <- Sys.getenv("PAPER_RUNTIME_IMAGE")
  if (!grepl("^([A-Za-z0-9][A-Za-z0-9._:/-]*@)?sha256:[0-9a-f]{64}$", image)) {
    stop("PAPER_RUNTIME_IMAGE must be an immutable registry digest or local config ID")
  }
  invisible(image)
}

command_output <- function(command, args = character()) {
  output <- system2(command, vapply(args, shQuote, character(1)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(output, "status")) && attr(output, "status") != 0L) {
    stop(paste(c(paste(command, "failed"), output), collapse = "\n"))
  }
  output
}

# All declared jobs in this component use the same installed-package inventory.
runtime_info_scope <- "component_environment"

runtime_info <- function(job = NULL) {
  require_container()
  packages <- c("jsonlite", "stats")
  versions <- setNames(lapply(packages, function(package) {
    if (!requireNamespace(package, quietly = TRUE)) stop(package, " is required")
    as.character(utils::packageVersion(package))
  }), packages)
  quarto <- Sys.which("quarto")
  list(schema_version = 1L, scope = runtime_info_scope,
       r = as.character(getRversion()), r_platform = R.version$platform,
       packages = versions, quarto = if (nzchar(quarto)) {
         paste(command_output(quarto, "--version"), collapse = "\n")
       } else NULL)
}

