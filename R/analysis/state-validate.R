# ==============================================================================
# STATE -- Monte Carlo validation of the exact mean first-passage time (Proposition 2, iii)
# ==============================================================================
source("R/lib/state-lib.R"); p <- state_params(); set.seed(1); dir.create("results/exact", recursive = TRUE, showWarnings = FALSE)
R_val <- 3000L; S0_val <- 0.02
fp_mc <- function(R, p, sigma, S0 = 0.02, Tmax = 800, dt = 0.02) {
  S <- rep(S0, R); tau <- rep(NA_real_, R); alive <- rep(TRUE, R)
  for (i in seq_len(Tmax / dt)) {
    S[alive] <- S[alive] + cubic_drift(S[alive], p) * dt + sigma * sqrt(dt) * rnorm(sum(alive))
    hit <- alive & S > p$a; tau[hit] <- i * dt; alive[hit] <- FALSE; if (!any(alive)) break }
  tau }
out <- rbindlist(lapply(c(0.20, 0.15), function(sg) {
  tau <- fp_mc(R_val, p, sg, S0 = S0_val, Tmax = 1000)
  data.table(sigma = sg, n_rep = R_val, S0 = S0_val, exact_s = mfpt_exact(p, sg, from = S0_val), mc_mean_s = mean(tau, na.rm = TRUE),
             mc_se_s = sd(tau, na.rm = TRUE) / sqrt(sum(!is.na(tau))), censored = sum(is.na(tau)))
}))
print(out); fwrite(out, "results/exact/mfpt_validation.csv")
