#!/usr/bin/env Rscript
# Saved-result presentation only: no calculation adapters or fitted models.
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- dirname(dirname(normalizePath(script, mustWork = TRUE)))
source(file.path(root, "R/render.R"))
stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("knitr", quietly = TRUE))
forbidden <- function(...) stop("Presentation attempted a calculation")
calculate <- assessment <- mse_simulate <- glm <- nlminb <- forbidden
plots <- list()
draw <- report_plot
report_plot <- function(series, field, label, points = character(), upper = NULL) {
  plots[[length(plots) + 1L]] <<- list(series = series, field = field, label = label, points = points, upper = upper)
  draw(series, field, label, points, upper)
}
figure <- tempfile(fileext = ".pdf")
grDevices::pdf(figure, width = 8, height = 3.2)
record <- list(run_id = "fixture-saved-run", data_source = list(provider = "Fixture provider"),
  source = list(repository = "https://example.test/coordinator", commit = strrep("a", 40)),
  analysis_source = list(repository = "https://example.test/component", commit = strrep("b", 40)),
  software = list(container = paste0("example.test/image@sha256:", strrep("c", 64)),
                  package_url = "https://example.test/package", packages = list(R = "fixture")))
render <- function(job, result) {
  before <- serialize(list(result, record), NULL)
  view <- if (job %in% c("cpue_report", "assessment_report", "mse_report")) report_full_view else report_result_view
  text <- paste(capture.output(view(job, result, record)), collapse = "\n")
  stopifnot(identical(before, serialize(list(result, record), NULL)),
    grepl(record$run_id, text, fixed = TRUE), grepl("report-data.json", text, fixed = TRUE),
    grepl(record$data_source$provider, text, fixed = TRUE),
    grepl(paste0("/commit/", record$source$commit), text, fixed = TRUE),
    grepl(paste0("/commit/", record$analysis_source$commit), text, fixed = TRUE),
    grepl(paste0("Image ", strrep("c", 12)), text, fixed = TRUE),
    grepl(record$software$package_url, text, fixed = TRUE))
  text
}
rows <- lapply(1:3, function(i) list(year = 2000L + i, index = i / 2,
  standardised_cpue = 10 + i, nominal_cpue = 20 - i, catch_t = 100 + i,
  observed_index = i / 2, fitted_index = i / 3, B_over_K = 1 - i / 10))
analysis <- list(sets_used = 3L, sets_excluded = 1L, min_hooks = 500,
                 method = "Saved fixture model", converged = TRUE)
for (job in c("cpue_a", "cpue_b")) {
  count <- length(plots)
  text <- render(job, c(list(series = rows), analysis))
  overlay <- plots[[count + 1L]]
  stopifnot(length(plots) == count + 1L, identical(overlay$label, "Fish per 1,000 hooks"),
    identical(vapply(overlay$series$Standardised, `[[`, numeric(1), "cpue"),
              vapply(rows, `[[`, numeric(1), "standardised_cpue")),
    identical(vapply(overlay$series[["Nominal: same records"]], `[[`, numeric(1), "cpue"),
              vapply(rows, `[[`, numeric(1), "nominal_cpue")),
    grepl("same selected records", text, fixed = TRUE), grepl("500", text, fixed = TRUE))
}
series <- list("CPUE analysis A" = rows, "CPUE analysis B" = rows)
cpue <- list(series = series, analyses = setNames(list(analysis, analysis), names(series)))
count <- length(plots)
invisible(render("cpue_summary", cpue))
stopifnot(length(plots) == count + 1L)
count <- length(plots)
cpue_text <- render("cpue_report", cpue)
stopifnot(length(plots) == count + 3L,
  identical(plots[[count + 1L]]$series[[1]], plots[[count + 2L]]$series[[1]]),
  identical(plots[[count + 1L]]$series[[2]], plots[[count + 2L]]$series[[2]]),
  identical(names(plots[[count + 1L]]$series), c("Standardised", "Nominal")),
  identical(names(plots[[count + 2L]]$series), c("Standardised", "Nominal")),
  identical(attr(plots[[count + 1L]]$series, "panel_title"), "Analysis A"),
  identical(attr(plots[[count + 2L]]$series, "panel_title"), "Analysis B"),
  !grepl("Score error", cpue_text, fixed = TRUE), !grepl("score error", cpue_text, fixed = TRUE),
  grepl("Yes", cpue_text, fixed = TRUE))
relative <- lapply(rows, function(row) row[c("year", "index")])
stopifnot(grepl("relative indices only", render("cpue_a", list(series = relative)), fixed = TRUE))

observations <- lapply(1:3, function(i) list(set_id = i, year = 2000L + i, vessel = "V1", hooks = 1000L, catch_n = i))
count <- length(plots)
invisible(render("submission", list(sets = observations)))
stopifnot(grepl("returned and replaced", render("qc", list(returned = list("S1"),
  checks = list(list(check = "Positive effort", result = "Pass")))), fixed = TRUE))
invisible(render("database", list(rows = 3L, first_year = 2001, last_year = 2003, annual = rows)))
stopifnot(grepl("# Extracted data", render("extract", list(sets = observations, catch = rows)), fixed = TRUE))
for (job in c("prepare_a", "prepare_b")) invisible(render(job, list(rows = rows)))
stopifnot(length(plots) == count)
fit <- list(series = rows, r = 0.2, K = 500, q = 0.01, convergence = 0,
            boundary_fit = TRUE, balance_check = "Pass", feasibility_check = "Pass", gradient_check = "Review")
for (job in c("assessment_a1", "assessment_a2", "assessment_b1", "assessment_b2")) {
  count <- length(plots)
  text <- render(job, fit)
  stopifnot(length(plots) == count + 2L,
    identical(plots[[count + 1L]]$points, "Observed CPUE"),
    identical(vapply(plots[[count + 1L]]$series[["Fitted CPUE"]], `[[`, numeric(1), "index"),
              vapply(rows, `[[`, numeric(1), "fitted_index")),
    grepl("search boundary", text, fixed = TRUE), grepl("gradient Review", text, fixed = TRUE))
}
assessment_result <- list(series = list(A = rows, B = rows),
  diagnostics = list(c(list(case = "A"), fit[setdiff(names(fit), "series")])))
stopifnot(identical(report_fit_status(list()), "Not recorded"),
          identical(report_fit_status(list(balance_check = "Pass")), "Partial record"))
invisible(render("assessment_summary", assessment_result))
invisible(render("assessment_report", assessment_result))
assumptions <- list(years = 3L, replicates = 2L, maximum_harvest_rate = 0.2, depletion_threshold = 0.15)
count <- length(plots)
invisible(render("mse_prepare", list(operating_models = list(list(name = "A", first_year = 2004,
  B = 200, K = 500, reference_catch_t = 100)), assumptions = assumptions)))
stopifnot(length(plots) == count)
metric <- list(mean_catch_t = 101, final_B_over_K = 0.7, below_threshold_percent = 0,
                catch_change_percent = 2, shortfall_trials = 1L)
scenarios <- list(list(name = "Baseline", series = rows), list(name = "Growth dip", series = rows))
for (job in c("mse_constant", "mse_index", "mse_buffered")) {
  count <- length(plots)
  text <- render(job, list(name = "Constant catch", description = "Saved rule fixture", series = rows,
       metrics = metric, scenarios = scenarios, assumptions = assumptions))
  stopifnot(length(plots) == count + 2L, grepl("Below 0.15 (%)", text, fixed = TRUE),
            grepl("20%", text, fixed = TRUE), grepl("guardrail", text, fixed = TRUE))
}
rules <- list("Constant catch" = rows, "Index rule" = rows, "Buffered rule" = rows)
mse <- list(series = rules, metrics = lapply(names(rules), function(name) c(list(name = name), metric)),
  scenarios = lapply(scenarios, function(scenario) list(name = scenario$name, series = rules)), assumptions = assumptions)
for (job in c("mse_summary", "mse_report")) {
  count <- length(plots)
  invisible(render(job, mse))
  stopifnot(length(plots) == count + 2L, identical(plots[[count + 1L]]$field, "B_over_K"),
            identical(plots[[count + 2L]]$field, "catch_t"))
}
# Public source scope and attribution remain visible in compact reports.
record$data_source <- list(provider = "Fixture provider", cpue_scope = "Fiji fleet; six strata",
  sources = list(list(url = "https://www.wcpfc.int/fixture")))
stopifnot(grepl("absent/suppressed", render("cpue_a", c(list(series = rows), analysis)), fixed = TRUE),
          grepl("stock-wide catches", render("assessment_report", assessment_result), fixed = TRUE))
footer_record <- record
footer_record$run_id <- "Run 002"
footer <- paste(capture.output(report_record(footer_record)), collapse = "\n")
stopifnot(grepl("Run `002`", footer, fixed = TRUE), !grepl("Run `Run ", footer, fixed = TRUE))
grDevices::dev.off()
stopifnot(file.info(figure)$size > 1000)
unlink(figure)
cat("PASS: 22 saved-result views; CPUE same-record rates; assessment diagnostics; compact plot counts; guardrail/threshold labels; source links; unchanged fixtures.\n")
