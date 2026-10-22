#!/usr/bin/env Rscript
# Saved-result presentation only: no calculation adapters or fitted models.
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
source(file.path(root, "R/render.R"))
stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("knitr", quietly = TRUE))
forbidden <- function(...) stop("Presentation attempted a calculation")
calculate <- assessment <- mse_simulate <- glm <- nlminb <- forbidden
plots <- strokes <- list()
draw <- report_plot
report_plot <- function(series, field, label, points = character(), upper = NULL, reference = NULL) {
  plots[[length(plots) + 1L]] <<- list(series = series, field = field, label = label,
    points = points, upper = upper, reference = reference)
  draw(series, field, label, points, upper, reference)
}
lines <- function(x, y, ...) {
  strokes[[length(strokes) + 1L]] <<- c(list(x = x, y = y), list(...))
  graphics::lines(x, y, ...)
}
figure <- tempfile(fileext = ".pdf")
grDevices::pdf(figure, width = 8, height = 3.2)
record <- list(owner = "Fixture CPUE analyst", run_id = "Run 003", snapshot = 2003,
  title = "Fixture job title", data_source = list(provider = "Fixture provider"),
  inputs = list(upstream = list(title = "Fixture upstream job", owner = "Fixture data analyst", run_id = "Run 001")),
  source = list(repository = "https://example.test/coordinator", commit = strrep("a", 40)),
  analysis_source = list(repository = "https://example.test/component", commit = strrep("b", 40)),
  software = list(container = paste0("example.test/image@sha256:", strrep("c", 64)),
                  package_url = "https://example.test/package", packages = list(R = "fixture")))
render <- function(job, result, saved_record = record) {
  before <- serialize(list(result, saved_record), NULL)
  view <- if (job %in% c("cpue_report", "assessment_report", "mse_report")) report_full_view else report_result_view
  text <- paste(capture.output(view(job, result, saved_record)), collapse = "\n")
  stopifnot(identical(before, serialize(list(result, saved_record), NULL)),
    grepl(saved_record$run_id, text, fixed = TRUE), grepl("report-data.json", text, fixed = TRUE),
    grepl(saved_record$data_source$provider, text, fixed = TRUE),
    grepl(paste0("/commit/", saved_record$source$commit), text, fixed = TRUE),
    grepl(paste0("/commit/", saved_record$analysis_source$commit), text, fixed = TRUE),
    grepl(paste0("Image ", strrep("c", 12)), text, fixed = TRUE),
    grepl(saved_record$software$package_url, text, fixed = TRUE))
  text
}
values <- function(rows, field) vapply(rows, `[[`, numeric(1), field)
rows <- lapply(1:3, function(i) list(year = 2000L + i, index = i / 2,
  standardised_cpue = 10 + i, nominal_cpue = 20 - i, catch_t = 100 + i,
  observed_index = i / 2, fitted_index = i / 3, B_over_K = 1 - i / 10))
rows_b <- lapply(rows, function(row) {
  row$standardised_cpue <- row$standardised_cpue * 1.3
  row$nominal_cpue <- row$nominal_cpue * 0.8
  row$index <- row$index * 0.9
  row
})
analysis <- list(sets_used = 3L, sets_excluded = 1L, min_hooks = 500,
  method = "Saved fixture model", converged = TRUE, dispersion = 1.2, score_residual = 1e-10)
for (job in c("cpue_a", "cpue_b")) {
  count <- length(plots); line_count <- length(strokes)
  text <- render(job, c(list(series = rows), analysis))
  overlay <- plots[[count + 1L]]
  stopifnot(length(plots) == count + 1L, identical(overlay$label, "Fish per 1,000 hooks"),
    identical(values(overlay$series$Standardised, "cpue"), values(rows, "standardised_cpue")),
    identical(values(overlay$series$Nominal, "cpue"), values(rows, "nominal_cpue")),
    identical(strokes[[line_count + 1L]]$lty, 1), identical(strokes[[line_count + 2L]]$lty, 2),
    identical(strokes[[line_count + 1L]]$x, values(rows, "year")),
    identical(strokes[[line_count + 2L]]$y, values(rows, "nominal_cpue")))
}
series <- list("CPUE analysis A" = rows, "CPUE analysis B" = rows_b)
cpue <- list(series = series, analyses = setNames(list(analysis, analysis), names(series)))
count <- length(plots)
invisible(render("cpue_summary", cpue))
stopifnot(length(plots) == count + 1L, identical(plots[[count + 1L]]$series, series),
          identical(plots[[count + 1L]]$field, "index"))
count <- length(plots)
cpue_text <- render("cpue_report", cpue)
stopifnot(length(plots) == count + 2L,
  identical(values(plots[[count + 1L]]$series$Standardised, "cpue"), values(rows, "standardised_cpue")),
  identical(values(plots[[count + 2L]]$series$Standardised, "cpue"), values(rows_b, "standardised_cpue")),
  identical(values(plots[[count + 1L]]$series$Nominal, "cpue"), values(rows, "nominal_cpue")),
  identical(values(plots[[count + 2L]]$series$Nominal, "cpue"), values(rows_b, "nominal_cpue")),
  identical(plots[[count + 1L]]$upper, plots[[count + 2L]]$upper),
  plots[[count + 1L]]$upper >= max(values(rows_b, "standardised_cpue")),
  identical(attr(plots[[count + 1L]]$series, "panel_title"), "Analysis A"),
  identical(attr(plots[[count + 2L]]$series, "panel_title"), "Analysis B"))
relative <- lapply(rows, function(row) row[c("year", "index")])
count <- length(plots)
invisible(render("cpue_a", list(series = relative)))
stopifnot(length(plots) == count + 1L, identical(plots[[count + 1L]]$field, "index"),
          identical(plots[[count + 1L]]$series[[1]], relative),
          identical(plots[[count + 1L]]$label, "Relative CPUE"))

# Aggregation changes the displayed scale only; no row or numerical result is mutated.
observations <- lapply(1:3, function(i) list(set_id = i, year = c(2001L, 2001L, 2003L)[i],
  vessel = "V1", hooks = 1000L * i, catch_n = i))
catch_rows <- lapply(c(2001L, 2003L), function(year) list(year = year, catch_t = year * 100))
annual <- list(list(year = 2001L, observations = 2L, hooks = 3000L, catch_n = 3L, catch_t = 200100),
               list(year = 2003L, observations = 1L, hooks = 3000L, catch_n = 3L, catch_t = 200300))
count <- length(plots)
invisible(render("submission", list(sets = observations, catch = catch_rows)))
stopifnot(length(plots) == count + 2L,
          identical(values(plots[[count + 1L]]$series[[1]], "effort"), c(0.003, 0.003)),
          identical(values(plots[[count + 2L]]$series[[1]], "catch_n"), c(3, 3)))
count <- length(plots)
qc <- render("qc", list(rows = 3L, returned = list("S1"),
  checks = list(list(check = "Positive effort", result = "Pass"))))
stopifnot(length(plots) == count, grepl("Positive effort", qc, fixed = TRUE))
count <- length(plots)
invisible(render("database", list(rows = 3L, first_year = 2001L, last_year = 2003L, annual = annual)))
stopifnot(length(plots) == count + 2L,
          identical(plots[[count + 1L]]$field, "observations"),
          identical(plots[[count + 1L]]$series[[1]], annual),
          identical(plots[[count + 2L]]$field, "catch_t"),
          identical(plots[[count + 2L]]$series[[1]], annual))
count <- length(plots); line_count <- length(strokes)
invisible(render("extract", list(sets = observations, catch = catch_rows)))
stopifnot(length(plots) == count + 2L, identical(plots[[count + 2L]]$series[[1]], catch_rows),
          identical(strokes[[line_count + 2L]]$y, values(catch_rows, "catch_t") / 1000))
for (job in c("prepare_a", "prepare_b")) {
  count <- length(plots)
  text <- render(job, list(rows = rows))
  stopifnot(length(plots) == count + 2L,
            identical(plots[[count + 1L]]$series[[1]], rows),
            identical(plots[[count + 2L]]$series[[1]], rows),
            identical(plots[[count + 1L]]$field, "index"),
            identical(plots[[count + 2L]]$field, "catch_t"),
            !grepl("Review", text, fixed = TRUE))
}
bad_pairs <- rows; bad_pairs[[2]]$year <- bad_pairs[[1]]$year
stopifnot(grepl("Review", render("prepare_a", list(rows = bad_pairs)), fixed = TRUE))
fit <- list(series = rows, r = 0.2, K = 500, q = 0.01, convergence = 0,
  boundary_fit = TRUE, balance_check = "Pass", feasibility_check = "Pass", gradient_check = "Review",
  balance_residual_t = 1e-7, balance_tolerance_t = 1e-6,
  projected_gradient_logK = 0.001, gradient_tolerance = 1e-4, active_bound = "lower")
for (job in c("assessment_a1", "assessment_a2", "assessment_b1", "assessment_b2")) {
  count <- length(plots)
  text <- render(job, fit)
  stopifnot(length(plots) == count + 2L,
    identical(plots[[count + 1L]]$points, "Observed CPUE"),
    identical(values(plots[[count + 1L]]$series[["Fitted CPUE"]], "index"), values(rows, "fitted_index")),
    identical(values(plots[[count + 1L]]$series[["Observed CPUE"]], "index"), values(rows, "observed_index")),
    identical(plots[[count + 2L]]$series[[1]], rows), identical(plots[[count + 2L]]$upper, 1),
    grepl("search boundary", text, fixed = TRUE), grepl("gradient Review", text, fixed = TRUE),
    grepl(report_scalar(fit$projected_gradient_logK), text, fixed = TRUE),
    grepl(report_scalar(fit$balance_residual_t), text, fixed = TRUE))
}
assessment_result <- list(series = list(A = rows, B = rows_b),
  diagnostics = list(c(list(case = "A"), fit[setdiff(names(fit), "series")])))
stopifnot(identical(report_fit_status(list()), "Not recorded"),
          identical(report_fit_status(list(balance_check = "Pass")), "Partial record"))
for (job in c("assessment_summary", "assessment_report")) {
  count <- length(plots)
  invisible(render(job, assessment_result))
  stopifnot(length(plots) == count + 1L, identical(plots[[count + 1L]]$series, assessment_result$series))
}
assumptions <- list(years = 3L, replicates = 2L, maximum_harvest_rate = 0.2,
  maximum_catch_multiple = 2, depletion_threshold = 0.15,
  scenarios = list(list(name = "Baseline"), list(name = "Growth dip")))
models <- list(list(name = "A", first_year = 2004L, B = 200, K = 500, reference_catch_t = 100))
count <- length(plots)
invisible(render("mse_prepare", list(operating_models = models, assumptions = assumptions,
  error_streams = rep(list(list(seed = 100)), 4L))))
stopifnot(length(plots) == count)
metric <- list(trials = 4L, mean_catch_t = 101, final_B_over_K = 0.7,
  below_threshold_percent = 0, catch_change_percent = 2, shortfall_trials = 1L)
rule_names <- c("Constant catch", "Index rule", "Buffered rule")
for (i in seq_along(rule_names)) {
  job <- c("mse_constant", "mse_index", "mse_buffered")[i]
  count <- length(plots)
  text <- render(job, list(name = rule_names[i], description = "Saved rule fixture", series = rows,
    metrics = metric, assumptions = assumptions, operating_models = models))
  stopifnot(length(plots) == count + 2L,
            identical(plots[[count + 1L]]$series[[1]], rows),
            identical(plots[[count + 2L]]$series[[1]], rows),
            identical(plots[[count + 1L]]$reference, assumptions$depletion_threshold),
            identical(plots[[count + 1L]]$upper, 1),
            identical(plots[[count + 2L]]$upper, 200))
}
rules <- setNames(list(rows, rows_b, rows), rule_names)
mse <- list(series = rules, metrics = lapply(rule_names, function(name) c(list(name = name), metric)),
            assumptions = assumptions, operating_models = models)
for (job in c("mse_summary", "mse_report")) {
  count <- length(plots)
  invisible(render(job, mse))
  stopifnot(length(plots) == count + 2L, identical(plots[[count + 1L]]$field, "B_over_K"),
            identical(plots[[count + 2L]]$field, "catch_t"),
            identical(plots[[count + 1L]]$series, rules),
            identical(plots[[count + 2L]]$series, rules))
}
# Identity and execution claims come only from the supplied record.
text <- render("cpue_a", c(list(series = rows), analysis))
for (value in c(record$owner, record$title, record$inputs$upstream$title,
                record$inputs$upstream$owner, record$inputs$upstream$run_id)) {
  stopifnot(grepl(value, text, fixed = TRUE))
}
stopifnot(!grepl("Calculation finished", text, fixed = TRUE))
finished <- record; finished$execution <- list(calculation = list(exit_code = 0L))
stopifnot(grepl("Calculation finished", render("cpue_a", c(list(series = rows), analysis), finished), fixed = TRUE))
failed <- finished; failed$execution$calculation$exit_code <- 1L
stopifnot(!grepl("Calculation finished", render("cpue_a", c(list(series = rows), analysis), failed), fixed = TRUE))
legacy <- record; legacy$title <- legacy$owner <- NULL
legacy$inputs <- list(old_parent_key = list(run_id = "Run 001"))
old <- render("cpue_a", c(list(series = rows), analysis), legacy)
stopifnot(grepl("old parent key", old, fixed = TRUE), grepl("Run 001", old, fixed = TRUE),
          !grepl(record$owner, old, fixed = TRUE),
          !grepl(record$inputs$upstream$owner, old, fixed = TRUE),
          !grepl("Calculation finished", old, fixed = TRUE))
record$data_source <- list(provider = "Fixture provider", cpue_scope = "Fiji fleet; six strata",
  sources = list(list(url = "https://www.wcpfc.int/fixture")))
stopifnot(grepl(record$data_source$cpue_scope, render("cpue_a", c(list(series = rows), analysis)), fixed = TRUE),
          grepl(record$data_source$sources[[1]]$url, render("cpue_report", cpue), fixed = TRUE),
          grepl("stock-wide catches", render("assessment_report", assessment_result), fixed = TRUE))
grDevices::dev.off()
stopifnot(file.info(figure)$size > 1000)
unlink(figure)
cat("PASS: 22 saved-result views; exact saved values and plotted units; nominal/standardised styles; aligned comparison axes; numerical review flags; actual analyst/input/run identity; conditional calculation claim; unchanged fixtures.\n")
