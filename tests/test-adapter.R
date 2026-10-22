# Pure adapter checks: no containers, fitting or simulations.
source("R/runtime.R")
expect_error <- function(expression) {
  failed <- tryCatch({ force(expression); FALSE }, error = function(error) TRUE)
  stopifnot(failed)
}

value <- list(number = 1, singleton = list(1), empty_array = list(),
              empty_object = structure(list(), names = character()),
              dimensioned = array(1, dim = 1L))
encoded <- workflow_encode(value)
stopifnot(grepl('"empty_object":{}', encoded, fixed = TRUE),
          grepl('"empty_array":[]', encoded, fixed = TRUE),
          grepl('"singleton":[1]', encoded, fixed = TRUE))
decoded <- jsonlite::fromJSON(encoded, simplifyVector = FALSE)
stopifnot(identical(decoded$number, 1L), identical(decoded$singleton, list(1L)),
          identical(decoded$empty_array, list()), length(decoded$empty_object) == 0L,
          identical(decoded$dimensioned, list(1L)))
expect_error(workflow_encode(list(value = Inf)))
expect_error(workflow_encode(list(value = NA_real_)))

original <- read_json("runtime.json")
source_contract <- read_json("SOURCE.json")
for (dependency in source_contract$dependencies) {
  hash <- substr(command_output("sha256sum", c("--", dependency$path)), 1L, 64L)
  stopifnot(identical(hash, dependency$sha256))
}
stopifnot(identical(substr(command_output("sha256sum", c("--", source_contract$library$path)), 1L, 64L),
                    source_contract$library$sha256))
temporary <- tempfile("runtime-test-")
dir.create(temporary)
previous <- setwd(temporary)
tryCatch({
  write_json(original, "runtime.json")
  first <- source_contract$jobs[[1]]
  baseline <- resolve_runtime(first)
  # An unrelated job's image mapping cannot alter this effective descriptor.
  original$jobs[["unrelated_job"]] <- list(image = paste0("sha256:", strrep("b", 64)))
  write_json(original, "runtime.json")
  stopifnot(identical(resolve_runtime(first), baseline))
  original$jobs[[first]] <- list(image = paste0("sha256:", strrep("a", 64)))
  write_json(original, "runtime.json")
  selected <- resolve_runtime(first)
  stopifnot(identical(selected$image, paste0("sha256:", strrep("a", 64))),
            identical(selected$platform, baseline$platform),
            identical(selected$package_url, baseline$package_url))
  original$jobs[[first]] <- list(command = "unrelated entrypoint")
  write_json(original, "runtime.json")
  expect_error(resolve_runtime(first))
  invalid <- baseline
  invalid$image <- "example:latest"
  expect_error(validate_runtime(invalid))
  invalid <- baseline
  invalid$package_url <- "http://example.test"
  expect_error(validate_runtime(invalid))
}, finally = {
  setwd(previous)
  unlink(temporary, recursive = TRUE)
})
cat("Adapter JSON, runtime isolation and pinned dependency checks passed.\n")

