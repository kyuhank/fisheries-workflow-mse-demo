# Apply index steps, the selected buffer and a 15% annual advice-change limit.
calculate <- function(context) {
  mse_simulate(context$parents$mse_prepare, rule = "buffered",
               buffer = min(context$settings$mse_buffer, 0.6))
}
