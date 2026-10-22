# B[t] is biomass before that year's catch; the final element is next year's state.
surplus_path <- function(K, r, catches) {
  B <- rep(K, length(catches) + 1L)
  for (t in seq_along(catches)) {
    B[t + 1L] <- B[t] + r * B[t] * (1 - B[t] / K) - catches[t]
  }
  B
}

