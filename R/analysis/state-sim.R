# ==============================================================================
# STATE -- ensemble simulations: main ensemble, noise sweep, dose-response, delta sensitivity
# Outputs: results/simulation/*.csv, results/simulation/ensemble.rds, results/sessionInfo.txt
# ==============================================================================
source("R/lib/state-lib.R"); p <- state_params(); dir.create("results/simulation", recursive = TRUE, showWarnings = FALSE)
p$delta <- delta_rule(p); cat(sprintf("delta (a-priori rule) = %.1f ms\n", p$delta))
R_main <- 2000L; R_sweep <- 2000L; R_dose <- 600L; R_delta <- 1000L; R_conv <- 600L
# every count quoted in the manuscript is read back from this file (see R/lib/state-numbers.R)
fwrite(data.table(setting = c("R_main", "R_sweep", "R_dose", "R_delta", "R_conv"), value = c(R_main, R_sweep, R_dose, R_delta, R_conv)), "results/simulation/run_settings.csv")

# ---- 0. check the delta rule against simulation of the stationary A -------------------
set.seed(1); R0 <- 20000L; Sg <- stationary_cov_A(p); Z <- matrix(rnorm(2 * R0), R0) %*% chol(Sg)
cat(sprintf("check: P(|A| > delta) under exact stationary law, MC = %.4f (target 0.001)\n", mean(sqrt(rowSums(Z^2)) * p$scale > p$delta)))

# ---- 1. main ensemble (sigma = 0.10) -------------------------------------------------------
set.seed(20261027)
sim <- simulate_state(R_main, p, keep_P = c("A", "B"))
mA <- state_metrics(sim$dist$A, sim$t, p, sim$S$A); mB <- state_metrics(sim$dist$B, sim$t, p, sim$S$B)
all_m <- rbind(cbind(system = "A", mA), cbind(system = "B", mB)); fwrite(all_m, "results/simulation/ensemble_metrics.csv")

q <- function(x) sprintf("%.1f [%.1f, %.1f]", median(x), quantile(x, .025), quantile(x, .975))
pc <- function(x) { w <- wilson(sum(x), length(x)); sprintf("%.1f [%.1f, %.1f]", 100 * mean(x), 100 * w["lo"], 100 * w["hi"]) }
tab <- rbindlist(lapply(c("A", "B"), function(s) { m <- if (s == "A") mA else mB; data.table(
  system = s, baseline_SD_ms = q(m$bl_sd), baseline_excursion_pct = pc(m$bl_excursion),
  saddle_crossed_baseline_pct = pc(m$saddle_crossed_baseline), Dmax_ms = q(m$Dmax),
  P_return_H55_tau5_pct = pc(m$returned), Trec_median_s = median(m$Trec), P_transition_H55_pct = pc(m$transitioned)) }))
fwrite(tab, "results/simulation/table_ensemble.csv"); print(t(tab))
set.seed(7)
aucs <- rbindlist(lapply(c("bl_sd", "bl_ac1", "Dmax", "Trec"), function(f) { ci <- auc_ci(mA[[f]], mB[[f]])
  data.table(descriptor = f, AUC = auc_rank(mA[[f]], mB[[f]]), lo = ci[1], hi = ci[2]) }))
fwrite(aucs, "results/simulation/auc_main.csv"); print(aucs)
cat(sprintf("Median ratios B/A: baseline SD %.3f ; Dmax %.3f\n", median(mB$bl_sd) / median(mA$bl_sd), median(mB$Dmax) / median(mA$Dmax)))

# representative realization: replicate closest to the ensemble medians (pre-specified rule)
rep_idx <- function(m) { z <- sapply(c("bl_sd", "Dmax", "Trec"), function(f) { x <- m[[f]]; sc <- max(mad(x), 0.05 * abs(median(x)), 1e-6); (x - median(x)) / sc })
  which.min(rowSums(z^2)) }
iA <- rep_idx(mA); iB <- rep_idx(mB); keep <- seq(1, length(sim$t), by = 2L)
paths <- rbindlist(list(
  data.table(system = "A", t = sim$t[keep], S = sim$S$A[keep, iA] * p$scale, P = sim$P$A[keep, iA] * p$scale, d = sim$dist$A[keep, iA]),
  data.table(system = "B", t = sim$t[keep], S = sim$S$B[keep, iB] * p$scale, P = sim$P$B[keep, iB] * p$scale, d = sim$dist$B[keep, iB])))
kk <- seq(1, length(sim$t), by = 5L)
bands <- rbindlist(lapply(c("A", "B"), function(s) { M <- sim$dist[[s]][kk, ]
  data.table(system = s, t = sim$t[kk], q05 = apply(M, 1, quantile, .05), q50 = apply(M, 1, median), q95 = apply(M, 1, quantile, .95)) }))
saveRDS(list(paths = paths, bands = bands, rep = c(A = iA, B = iB)), "results/simulation/ensemble.rds")
cat(sprintf("representative replicates: A=%d B=%d\n", iA, iB))

# delta sensitivity (main ensemble, first R_delta replicates)
dgrid <- c(40, 60, 80, 105, 130, p$delta, 180, 210, 250, 300, 400, 450, 600)
dl <- rbindlist(lapply(c("A", "B"), function(s) return_by_delta(sim$dist[[s]][, seq_len(R_delta)], sim$t, p, dgrid)[, system := s]))
fwrite(dl, "results/simulation/delta_sensitivity.csv")

# ---- 2. noise sweep ----------------------------------------------------------------------------
set.seed(20261028)
sweep <- rbindlist(lapply(c(0.05, 0.075, 0.10, 0.125, 0.15, 0.20, 0.25), function(sg) {
  cat(sprintf("sweep sigma=%.3f\n", sg)); s <- simulate_state(R_sweep, p, sigma = sg)
  a <- state_metrics(s$dist$A, s$t, p, s$S$A); b <- state_metrics(s$dist$B, s$t, p, s$S$B)
  wc <- wilson(sum(b$saddle_crossed_baseline), R_sweep); wt <- wilson(sum(b$transitioned), R_sweep)
  data.table(sigma = sg, saddle_crossed_baseline_B = 100 * mean(b$saddle_crossed_baseline), cross_lo = 100 * wc["lo"], cross_hi = 100 * wc["hi"],
             P_transition_B = 100 * mean(b$transitioned), ptrans_lo = 100 * wt["lo"], ptrans_hi = 100 * wt["hi"],
             P_transition_A = 100 * mean(a$transitioned), no_return_B = 100 * mean(!b$returned), no_return_A = 100 * mean(!a$returned),
             AUC_baseline_SD = auc_rank(a$bl_sd, b$bl_sd), AUC_baseline_AC1 = auc_rank(a$bl_ac1, b$bl_ac1),
             AUC_Dmax = auc_rank(a$Dmax, b$Dmax), AUC_Trec = auc_rank(a$Trec, b$Trec))
}))
fwrite(sweep, "results/simulation/noise_sweep.csv"); print(round(sweep, 3))

# ---- 3. dose-response --------------------------------------------------------------------------------
set.seed(20261029)
u_grid <- c(0.01, 0.02, 0.03, 0.04, 0.06, 0.08, 0.12, 0.20, 0.35, 0.50)
dose <- rbindlist(lapply(c(0.10, 0.20), function(sg) rbindlist(lapply(u_grid, function(u) {
  s <- simulate_state(R_dose, p, sigma = sg, u_scale = u / p$u_S)
  a <- state_metrics(s$dist$A, s$t, p, s$S$A); b <- state_metrics(s$dist$B, s$t, p, s$S$B)
  data.table(sigma = sg, u_S = u, P_transition_A = 100 * mean(a$transitioned), P_transition_B = 100 * mean(b$transitioned),
             Dmax_A = median(a$Dmax), Dmax_B = median(b$Dmax)) }))))
fwrite(dose, "results/simulation/dose_response.csv")

# ---- 4. dt convergence ---------------------------------------------------------------------------------
set.seed(20261030)
conv <- rbindlist(lapply(c(0.02, 0.005), function(dt) { q2 <- p; q2$dt <- dt; q2$win <- round(0.5 / dt)
  s <- simulate_state(R_conv, q2); a <- state_metrics(s$dist$A, s$t, q2, s$S$A); b <- state_metrics(s$dist$B, s$t, q2, s$S$B)
  data.table(dt = dt, Dmax_A = median(a$Dmax), Dmax_B = median(b$Dmax), P_transition_B = 100 * mean(b$transitioned), no_return_B = 100 * mean(!b$returned)) }))
fwrite(conv, "results/simulation/dt_convergence.csv"); print(conv)
writeLines(capture.output(sessionInfo()), "results/sessionInfo.txt"); cat("done\n")
