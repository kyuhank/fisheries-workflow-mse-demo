# Host launcher: resolve one immutable image and run the component's own target.
source("R/runtime.R")
  main <- function() {
  key <- job_key()
  context <- Sys.getenv("CONTEXT")
  output <- Sys.getenv("OUT")
  if (!startsWith(context, "/") || !file.exists(context)) stop("CONTEXT must be an absolute JSON path")
  if (!startsWith(output, "/")) stop("OUT must be an absolute directory path")
  root <- normalizePath(".", mustWork = TRUE)
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output, mustWork = TRUE)
  context <- normalizePath(context, mustWork = TRUE)
  if (output == "/" || output == root || startsWith(output, paste0(root, "/")) ||
      startsWith(root, paste0(output, "/"))) stop("OUT and the source tree must not overlap")
  if (any(grepl("[,\n]", c(root, context, output)))) stop("Mount paths may not contain commas or newlines")
  if (file.exists(file.path(output, "response.json"))) stop("OUT already contains a response; choose a new directory")
  existing <- list.files(output, all.files = TRUE, no.. = TRUE)
  if (length(setdiff(existing, if (identical(context, file.path(output, "context.json"))) "context.json" else character()))) {
    stop("OUT must be a new result directory")
  }
  request <- read_json(context)
  if (!identical(request$key, key)) stop("CONTEXT key differs from JOB")
  runtime_file <- Sys.getenv("RUNTIME")
  preserved <- if (nzchar(runtime_file)) read_json(runtime_file) else NULL
  selected <- if (is.null(preserved)) resolve_runtime(key) else validate_runtime(preserved)
  pull <- Sys.getenv("PULL", "missing")
  network <- Sys.getenv("NETWORK", "none")
  timeout <- suppressWarnings(as.integer(Sys.getenv("TIMEOUT", "300")))
  if (!pull %in% c("missing", "never")) stop("PULL must be missing or never")
  if (!network %in% c("none", "bridge")) stop("NETWORK must be none or bridge")
  if (is.na(timeout) || timeout < 1L) stop("TIMEOUT must be a positive number of seconds")
  if (!nzchar(Sys.which("docker"))) stop("Docker is required")

  docker <- function(args, logfile = NULL, allow_failure = FALSE) {
    stdout <- if (is.null(logfile)) tempfile("docker-out-") else logfile
    stderr <- if (is.null(logfile)) tempfile("docker-error-") else paste0(logfile, ".stderr")
    if (is.null(logfile)) on.exit(unlink(c(stdout, stderr)), add = TRUE)
    status <- suppressWarnings(system2("docker", vapply(args, shQuote, character(1)),
                                      stdout = stdout, stderr = stderr, timeout = timeout))
    result <- if (file.exists(stdout)) readLines(stdout, warn = FALSE) else character()
    errors <- if (file.exists(stderr)) readLines(stderr, warn = FALSE) else character()
    if (status != 0L && !allow_failure) {
      stop(paste(c(paste("Docker exited with status", status), errors, result), collapse = "\n"))
    }
    list(status = status, output = result)
  }

  inspection <- docker(c("image", "inspect", selected$image), allow_failure = TRUE)
  if (inspection$status != 0L && !is.null(preserved$image_id)) {
    inspection <- docker(c("image", "inspect", preserved$image_id), allow_failure = TRUE)
  }
  if (inspection$status != 0L) {
    if (startsWith(selected$image, "sha256:")) stop("Selected local config ID is unavailable; it cannot be pulled")
    if (pull == "never") stop("Selected image is unavailable locally; PULL=never prohibits retrieval")
    docker(c("pull", "--platform", selected$platform, selected$image),
           file.path(output, "image-pull.log"))
    inspection <- docker(c("image", "inspect", selected$image))
  }
  native <- jsonlite::fromJSON(paste(inspection$output, collapse = "\n"), simplifyVector = FALSE)[[1]]
  actual_platform <- paste(native$Os, native$Architecture, sep = "/")
  if (!is.null(native$Variant) && nzchar(native$Variant)) actual_platform <- paste(actual_platform, native$Variant, sep = "/")
  if (!identical(actual_platform, selected$platform)) stop("Selected image platform differs from inspected platform")
  if (!grepl("^sha256:[0-9a-f]{64}$", native$Id)) stop("Docker returned an invalid image config ID")
  local_config <- startsWith(selected$image, "sha256:")
  if (local_config && !identical(selected$image, native$Id)) stop("Local image config ID differs from the inspected image")
  if (!local_config && !selected$image %in% unlist(native$RepoDigests, use.names = FALSE)) {
    # Restored offline archives may have no RepoDigest. Require a preserved identity.
    expected <- preserved
    if (is.null(expected$image_id) || !identical(expected$image_id, native$Id) ||
        !identical(unlist(expected$layers, use.names = FALSE), unlist(native$RootFS$Layers, use.names = FALSE))) {
      stop("Image digest is absent locally; RUNTIME must supply matching preserved image_id and ordered layers")
    }
  }
  input <- file.path(output, "context.json")
  if (!identical(context, input) && !file.copy(context, input, overwrite = TRUE)) stop("Could not stage CONTEXT")
  write_json(selected, file.path(output, "runtime-selected.json"))
  identity <- c(selected, list(image_kind = if (local_config) "local_config" else "registry_manifest",
                              image_id = native$Id, os = native$Os,
                              architecture = native$Architecture, layers = native$RootFS$Layers,
                              repo_digests = native$RepoDigests))
  write_json(identity, file.path(output, "runtime-identity.json"))
  source_identity <- if (file.exists(".git") && nzchar(Sys.which("git"))) {
    list(repository = paste(command_output("git", c("remote", "get-url", "origin")), collapse = "\n"),
         commit = paste(command_output("git", c("rev-parse", "HEAD")), collapse = "\n"),
         dirty = length(command_output("git", c("status", "--porcelain"))) > 0L)
  } else list(repository = NULL, commit = NULL, dirty = NULL)

  container <- paste0("fisheries-", key, "-", Sys.getpid(), "-", sample.int(1e8, 1))
  on.exit(docker(c("rm", "--force", container), allow_failure = TRUE), add = TRUE)
  uid <- command_output("id", "-u")
  gid <- command_output("id", "-g")
  arguments <- c("run", "--rm", "--pull=never", "--name", container,
                 "--platform", selected$platform, "--network", network,
                 "--cap-drop=ALL", "--security-opt=no-new-privileges",
                 "--read-only", "--cpus", Sys.getenv("PAPER_JOB_CPUS", "1"),
                 "--memory", Sys.getenv("PAPER_JOB_MEMORY", "2g"),
                 "--tmpfs", "/tmp:rw,nosuid,nodev,size=1g,mode=1777",
                 "--user", paste(uid, gid, sep = ":"), "--workdir", "/work",
                 "--mount", paste0("type=bind,src=", root, ",dst=/work,readonly"),
                 "--mount", paste0("type=bind,src=", output, ",dst=/io"),
                 "--env", paste0("JOB=", key),
                 "--env", paste0("PAPER_RUNTIME_IMAGE=", selected$image),
                 "--env", paste0("PAPER_RUNTIME_IMAGE_URL=", selected$package_url),
                 "--env", "CONTEXT=/io/context.json", "--env", "OUT=/io",
                 "--env", "XDG_CACHE_HOME=/tmp/cache",
                 "--env", "XDG_DATA_HOME=/tmp/data", "--env", "XDG_CONFIG_HOME=/tmp/config",
                 "--entrypoint", "make", native$Id)
  docker(c(arguments, "--no-print-directory", "--silent", "info"),
         file.path(output, "runtime-info.json"))
  docker(c(arguments, "--no-print-directory", "--silent", "inside-job"),
         file.path(output, "calculation.log"))
  response <- read_json(file.path(output, "response.json"))
  if (!identical(sort(names(response)), c("effects", "result"))) stop("Invalid response envelope")
  write_json(c(identity, list(software = read_json(file.path(output, "runtime-info.json")),
                             job = key, entrypoint = "make inside-job",
                             source = source_identity,
                             network = network, completed = TRUE)),
             file.path(output, "execution.json"))
}
main()

