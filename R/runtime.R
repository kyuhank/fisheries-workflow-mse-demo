# Resolve one job's binding; unrelated entries never enter this descriptor.
source("R/adapter.R")

resolve_runtime <- function(job = job_key()) {
  manifest <- read_json("runtime.json")
  if (!identical(manifest$schema_version, 1L) && !identical(manifest$schema_version, 1)) {
    stop("Unsupported runtime schema")
  }
  selected <- manifest$default
  override <- manifest$jobs[[job]]
  if (!is.null(override)) {
    if (!is.list(override) || is.null(names(override)) ||
        any(!names(override) %in% c("image", "platform", "package_url"))) {
      stop("A runtime override may only set image, platform and package_url")
    }
    selected[names(override)] <- override
  }
  validate_runtime(selected)
}

validate_runtime <- function(selected) {
  for (field in c("image", "platform", "package_url")) {
    value <- selected[[field]]
    if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
      stop("Missing runtime ", field)
    }
  }
  if (!grepl("^([A-Za-z0-9][A-Za-z0-9._:/-]*@)?sha256:[0-9a-f]{64}$", selected$image)) {
    stop("Runtime image must use an immutable registry digest or local config ID")
  }
  if (!grepl("^[a-z0-9]+/[a-z0-9_]+(/[a-z0-9]+)?$", selected$platform)) {
    stop("Invalid runtime platform")
  }
  if (!grepl("^https://", selected$package_url)) stop("package_url must be HTTPS")
  list(schema_version = 1L, image = selected$image, platform = selected$platform,
       package_url = selected$package_url)
}

