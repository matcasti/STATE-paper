# ==============================================================================
# STATE -- single source of truth for every number quoted in index.qmd
#
#   * Reads results/exact/*.csv and results/simulation/*.csv (written by R/analysis/state-analytic.R, state-validate.R, state-sim.R)
#     and the simulation parameters (R/lib/state-lib.R). Nothing is typed by hand.
#   * Exposes `N`   : strict list of formatted strings, used as `r N$key` in index.qmd
#                `V`   : the underlying numeric values
#                `T2`  : data.frame behind the descriptor table of the manuscript
#   * `N$unknown_key` raises an error (a mistyped key can never silently print nothing).
#   * `check_claims()` tests the qualitative statements of the text ("in all replicates",
#     "plateaus at about 90%", ...) against the data and warns when one stops being true.
# ==============================================================================
source("R/lib/state-lib.R")

.need <- c("ensemble_metrics.csv", "auc_main.csv", "exact_constants.csv", "exact_mfpt.csv", "mfpt_validation.csv",
           "noise_sweep.csv", "dose_response.csv", "delta_sensitivity.csv", "dt_convergence.csv", "run_settings.csv",
           "table_ensemble.csv")
# result files live in results/exact/ (analytic and validation) or results/simulation/
.dir <- function(f) ifelse(f %in% c("exact_constants.csv", "exact_mfpt.csv", "mfpt_validation.csv", "observability_rank.csv"), "exact", "simulation")
.res <- function(f) file.path("results", .dir(f), f)
.miss <- .need[!file.exists(.res(.need))]
if (length(.miss)) stop("Missing result files: ", paste(.miss, collapse = ", "),
                        ". Run `Rscript R/run-all.R` first (about 3 minutes; seeds are fixed, so the numbers are reproducible).", call. = FALSE)

p   <- state_params(); rd <- function(f) fread(.res(f))
ex  <- rd("exact_constants.csv"); p$delta <- ex$delta_ms
st  <- setNames(rd("run_settings.csv")$value, rd("run_settings.csv")$setting)

# ---- formatting helpers ----------------------------------------------------------------------------
fmt  <- function(x, d = 1) formatC(x, format = "f", digits = d)               # fixed decimals
sgn  <- function(x, d = 3) paste0(ifelse(x >= 0, "+", "-"), fmt(abs(x), d))    # explicit sign
dash <- "--"      # ASCII on purpose: Pandoc smart typography renders it as an en dash, independent of the OS locale
rng  <- function(lo, hi, d = 1) paste0(fmt(lo, d), dash, fmt(hi, d))
q3   <- function(x, d = 1) sprintf("%s [%s, %s]", fmt(median(x), d), fmt(quantile(x, .025), d), fmt(quantile(x, .975), d))
pw   <- function(x, d = 1) { w <- wilson(sum(x), length(x))
                             sprintf("%s [%s, %s]", fmt(100 * mean(x), d), fmt(100 * w[["lo"]], d), fmt(100 * w[["hi"]], d)) }
one  <- function(r) { stopifnot("lookup must return exactly one row" = nrow(r) == 1); r }

# ---- raw tables --------------------------------------------------------------------------------------
M  <- rd("ensemble_metrics.csv"); mA <- M[system == "A"]; mB <- M[system == "B"]
auc <- rd("auc_main.csv"); au <- function(d) one(auc[descriptor == d])
mf <- rd("exact_mfpt.csv"); mfa <- function(s) one(mf[abs(sigma - s) < 1e-9])
va <- rd("mfpt_validation.csv"); vaa <- function(s) one(va[abs(sigma - s) < 1e-9])
sw <- rd("noise_sweep.csv")[order(sigma)]
ds <- rd("dose_response.csv"); dsa <- function(s, u) one(ds[abs(sigma - s) < 1e-9 & abs(u_S - u) < 1e-9])
dl <- rd("delta_sensitivity.csv"); dla <- function(sys, d) one(dl[system == sys & abs(delta - d) < 1e-6])$no_return
cv <- rd("dt_convergence.csv")[order(-dt)]

# ---- exact quantities derived from the parameters ----------------------------------------------------
lam   <- lambda_rest(p); mu <- p$k_P; kap <- p$k_P * p$gamma
det3  <- 1 * (-1 * (lam - mu) + 1 * kap)                                    # Prop. 1 (iii), c = (-1, 1)
half  <- p$a * p$scale
d_sad <- sqrt(p$a^2 + (p$gamma * p$a)^2) * p$scale; d_str <- sqrt(p$b^2 + (p$gamma * p$b)^2) * p$scale
stat  <- stationary_S(p, p$sigma); stat_mass <- sum(stat$dens[stat$S > p$a]) * stat$h
q_del <- formals(delta_rule)$q
stopifnot("lambda in results/ disagrees with state_params()" = abs(lam - ex$lambda) < 1e-12)

# ---- selections made by the analyst (documented here, checked in the claims ledger) -------------------
sig_hi <- 0.20; sig_mid <- 0.15                                             # high-noise reference level; second escape-time check
u_plateau <- 0.12                                                           # amplitude above which the dose-response is called a plateau
u_lo <- 0.01; u_mid <- 0.04                                                 # amplitudes quoted for the regime-shift probability
u_r  <- c(0.02, 0.04, 0.08, 0.20, 0.35, p$u_S)                              # amplitudes at which the peak ratio D_max(B)/D_max(A) is quoted
d_le <- 300; d_mid <- 400; d_hi <- 450; d_lo <- 40                          # tolerances (ms) quoted in the text
s_lo <- min(sw$sigma); s_hi <- max(sw$sigma)
ratio_u <- function(u, s = p$sigma) { r <- dsa(s, u); r$Dmax_B / r$Dmax_A }
ptB <- function(u, s = p$sigma) dsa(s, u)$P_transition_B
dose_nom <- ds[abs(sigma - p$sigma) < 1e-9]; dose_hi <- ds[abs(sigma - sig_hi) < 1e-9]

V <- list(
  # design (state_params) ---------------------------------------------------------------------------------
  kS = p$k_S, a = p$a, b = p$b, kP = p$k_P, gamma = p$gamma, sigma = p$sigma, scale = p$scale, dt = p$dt, tmax = p$t_max,
  t0 = p$P_start, pulse = p$P_end - p$P_start, uS = p$u_S, uP = p$u_P, tau = p$tau, H = p$t_max - p$P_end, win_s = p$win * p$dt,
  # exact (state-analytic) ---------------------------------------------------------------------------------
  lambda = lam, kappa = kap, det3 = det3, delta = p$delta, half = half, d_sad = d_sad, d_str = d_str,
  uc = ex$u_c, var_B = mfa(p$sigma)$stationary_Var_S_B, var_A = mfa(p$sigma)$Var_S_A,
  T_nom = mfa(p$sigma)$MFPT_s, T_hi = mfa(sig_hi)$MFPT_s, bn_nom = mfa(p$sigma)$barrier_over_noise,
  bn_lo = mfa(s_hi)$barrier_over_noise, bn_hi = mfa(s_lo)$barrier_over_noise, stat_mass = stat_mass,
  # Monte Carlo check of the escape time -------------------------------------------------------------------
  mcm = vaa(sig_mid)$mc_mean_s, sem = vaa(sig_mid)$mc_se_s, exm = vaa(sig_mid)$exact_s,
  mch = vaa(sig_hi)$mc_mean_s, seh = vaa(sig_hi)$mc_se_s, exh = vaa(sig_hi)$exact_s,
  mc_dev = max(abs(va$mc_mean_s / va$exact_s - 1)) * 100, R_val = va$n_rep[1], S0_val = va$S0[1],
  # ensemble (sigma = nominal) ----------------------------------------------------------------------------
  R_main = nrow(mA), blA = median(mA$bl_sd), blB = median(mB$bl_sd), blq975A = quantile(mA$bl_sd, .975)[[1]], blq975B = quantile(mB$bl_sd, .975)[[1]],
  crossB = 100 * mean(mB$saddle_crossed_baseline), dmA = median(mA$Dmax), dmB = median(mB$Dmax),
  trA = median(mA$Trec), trA_lo = quantile(mA$Trec, .025)[[1]], trA_hi = quantile(mA$Trec, .975)[[1]],
  retA = 100 * mean(mA$returned), retB = 100 * mean(mB$returned), cens_B = 100 * mean(!mB$returned), transB = 100 * mean(mB$transitioned),
  retB_lo = 100 * wilson(sum(mB$returned), nrow(mB))[["lo"]], retB_hi = 100 * wilson(sum(mB$returned), nrow(mB))[["hi"]],
  trB_lo = 100 * wilson(sum(mB$transitioned), nrow(mB))[["lo"]], trB_hi = 100 * wilson(sum(mB$transitioned), nrow(mB))[["hi"]],
  auc_bl = au("bl_sd")$AUC, auc_bl_lo = au("bl_sd")$lo, auc_bl_hi = au("bl_sd")$hi,
  auc_dm = au("Dmax")$AUC, auc_dm_lo = au("Dmax")$lo, auc_dm_hi = au("Dmax")$hi, auc_tr = au("Trec")$AUC,
  # noise sweep ----------------------------------------------------------------------------------------------
  R_sweep = st[["R_sweep"]], s_lo = s_lo, s_hi = s_hi,
  pt_first = sw[sigma == s_lo]$P_transition_B, pt_last = sw[sigma == s_hi]$P_transition_B,
  cr_first = sw[sigma == s_lo]$saddle_crossed_baseline_B, cr_last = sw[sigma == s_hi]$saddle_crossed_baseline_B,
  aucbl_first = sw[sigma == s_lo]$AUC_baseline_SD, aucbl_last = sw[sigma == s_hi]$AUC_baseline_SD,
  auctr_min = min(sw$AUC_Trec), aucdm_lo = min(sw$AUC_Dmax), aucdm_hi = max(sw$AUC_Dmax),
  # dose-response (sigma = 0.10 unless stated) ----------------------------------------------------------------
  R_dose = st[["R_dose"]], u_plateau = u_plateau, u_lo = u_lo, u_mid = u_mid, pt_ulo = ptB(u_lo), pt_umid = ptB(u_mid),
  plateau = mean(dose_nom[u_S >= u_plateau]$P_transition_B),
  pt_hi_lo = min(dose_hi$P_transition_B), pt_hi_hi = max(dose_hi$P_transition_B),
  ptB_min = min(dose_nom$P_transition_B), ptB_max = max(dose_nom$P_transition_B), ptA_max = max(dose_nom$P_transition_A),
  u_r = u_r, r = sapply(u_r, ratio_u), r_max = max(dose_nom[, Dmax_B / Dmax_A]),
  # tolerance sensitivity ---------------------------------------------------------------------------------------
  R_delta = st[["R_delta"]], d_le = d_le, d_mid = d_mid, d_hi = d_hi, d_lo = d_lo,
  nr_le = min(dl[system == "B" & delta <= d_le]$no_return), nr_mid = dla("B", d_mid), nr_hi = max(dl[system == "B" & delta >= d_hi]$no_return),
  nrA_lo = dla("A", d_lo),
  # time-step convergence ----------------------------------------------------------------------------------------
  R_conv = st[["R_conv"]], dt0 = cv$dt[1], dt1 = cv$dt[2],
  dmax_chg = max(abs(cv$Dmax_A[2] / cv$Dmax_A[1] - 1), abs(cv$Dmax_B[2] / cv$Dmax_B[1] - 1)) * 100,
  pt_chg = abs(cv$P_transition_B[2] - cv$P_transition_B[1]),
  # time scales of the example ------------------------------------------------------------------------------------
  relax_fast = 1 / p$k_P, relax_slow = 1 / lam
)

# ---- formatted strings used in the text (`r N$key`) -----------------------------------------------------------------------
N <- list(
  kS = fmt(V$kS, 2), Ssad = fmt(V$a, 1), Sstr = fmt(V$b, 1), kP = fmt(V$kP, 2), negkP = paste0("-", fmt(V$kP, 2)), gamma = fmt(V$gamma, 2),
  sigma = fmt(V$sigma, 2), scale = fmt(V$scale, 0), dt = fmt(V$dt, 2), tmax = fmt(V$tmax, 0), t0 = fmt(V$t0, 0), pulse = fmt(V$pulse, 0),
  uS = fmt(V$uS, 2), uS1 = fmt(V$uS, 1), uP = fmt(V$uP, 2), uP_ratio = fmt(V$uP / V$uS, 1), tau = fmt(V$tau, 0), H = fmt(V$H, 0), win_s = fmt(V$win_s, 1),
  lambda = fmt(V$lambda, 3), mu = fmt(V$kP, 2), kappa = fmt(V$kappa, 2), det3 = fmt(V$det3, 3),
  Psad = fmt(-V$gamma * V$a, 1), Pstr = fmt(-V$gamma * V$b, 1),
  Ssad_ms = fmt(V$a * V$scale, 0), Psad_ms = fmt(-V$gamma * V$a * V$scale, 0), Sstr_ms = fmt(V$b * V$scale, 0), Pstr_ms = fmt(-V$gamma * V$b * V$scale, 0),
  lam_att = fmt(cubic_slope(0, p), 3), lam_sad = sgn(cubic_slope(p$a, p), 3),
  delta = fmt(V$delta, 1), q_delta = format(q_del), half = fmt(V$half, 0), d_sad = fmt(V$d_sad, 0), d_str = fmt(V$d_str, 0),
  R_main = fmt(V$R_main, 0), R_sweep = fmt(V$R_sweep, 0), R_dose = fmt(V$R_dose, 0), R_delta = fmt(V$R_delta, 0), R_conv = fmt(V$R_conv, 0), R_val = fmt(V$R_val, 0), S0_val = fmt(V$S0_val, 2),
  sig_hi = fmt(sig_hi, 2), sig_mid = fmt(sig_mid, 2), var_B = fmt(V$var_B, 3), var_A = fmt(V$var_A, 4), var_ratio = fmt(V$var_B / V$var_A, 0), T_nom = fmt(V$T_nom, 0), T_hi = fmt(V$T_hi, 1),
  uc = fmt(V$uc, 4), pulse_uc = fmt(V$uS / V$uc, 1), force_ratio = fmt(lam * p$a / V$uc, 1), stat_mass = fmt(100 * V$stat_mass, 0),
  bn_nom = fmt(V$bn_nom, 1), bn_lo = fmt(V$bn_lo, 1), bn_hi = fmt(V$bn_hi, 1),
  mcm = fmt(V$mcm, 1), sem = fmt(V$sem, 1), exm = fmt(V$exm, 1), mch = fmt(V$mch, 1), seh = fmt(V$seh, 1), exh = fmt(V$exh, 1), mc_within = fmt(ceiling(V$mc_dev), 0),
  blA = fmt(V$blA, 1), blB = fmt(V$blB, 1), blq975A = fmt(V$blq975A, 0), blq975B = fmt(V$blq975B, 0), crossB = fmt(V$crossB, 1),
  dmA = fmt(V$dmA, 0), dmB = fmt(V$dmB, 0), trA = fmt(V$trA, 1), trA_rng = rng(V$trA_lo, V$trA_hi, 1),
  retA0 = fmt(V$retA, 0), retB0 = fmt(V$retB, 0), retB = fmt(V$retB, 1), retB_ci = rng(V$retB_lo, V$retB_hi, 1), cens_B = fmt(V$cens_B, 1),
  transB0 = fmt(V$transB, 0), transB = fmt(V$transB, 1), transB_ci = rng(V$trB_lo, V$trB_hi, 1),
  auc_bl = fmt(V$auc_bl, 2), auc_bl_ci = rng(V$auc_bl_lo, V$auc_bl_hi, 2), auc_dm = fmt(V$auc_dm, 2), auc_dm_ci = rng(V$auc_dm_lo, V$auc_dm_hi, 2), auc_tr = fmt(V$auc_tr, 2),
  s_lo = fmt(V$s_lo, 2), s_hi = fmt(V$s_hi, 2), pt_first = fmt(V$pt_first, 0), pt_last = fmt(V$pt_last, 0), cr_first = fmt(V$cr_first, 0), cr_last = fmt(V$cr_last, 0),
  aucbl_first = fmt(V$aucbl_first, 2), aucbl_last = fmt(V$aucbl_last, 2), auctr_min = fmt(V$auctr_min, 2), aucdm_rng = rng(V$aucdm_lo, V$aucdm_hi, 2),
  u_plateau = fmt(V$u_plateau, 2), u_lo = fmt(V$u_lo, 2), u_mid = fmt(V$u_mid, 2), pt_ulo = fmt(V$pt_ulo, 0), pt_umid = fmt(V$pt_umid, 0), plateau = fmt(V$plateau, 0), pt_hi_rng = rng(V$pt_hi_lo, V$pt_hi_hi, 0),
  ptB_rng = rng(V$ptB_min, V$ptB_max, 0), ptA_max = fmt(V$ptA_max, 0),
  ur1 = fmt(u_r[1], 2), ur2 = fmt(u_r[2], 2), ur3 = fmt(u_r[3], 2), ur4 = fmt(u_r[4], 2), ur5 = fmt(u_r[5], 2),
  r1 = fmt(V$r[1], 2), r2 = fmt(V$r[2], 2), r3 = fmt(V$r[3], 2), r4 = fmt(V$r[4], 2), r5 = fmt(V$r[5], 2), r6 = fmt(V$r[6], 2), r_max = fmt(V$r_max, 1),
  d_le = fmt(d_le, 0), d_mid = fmt(d_mid, 0), d_hi = fmt(d_hi, 0), d_lo = fmt(d_lo, 0),
  nr_le = fmt(floor(V$nr_le), 0), nr_mid = fmt(V$nr_mid, 1), nrA_lo = fmt(V$nrA_lo, 0),
  dt0 = fmt(V$dt0, 2), dt1 = fmt(V$dt1, 3), dmax_chg = fmt(ceiling(V$dmax_chg), 0), pt_chg = fmt(V$pt_chg, 1),
  relax_rng = rng(round(V$relax_fast), round(V$relax_slow), 0)
)
class(N) <- "state_numbers"
`$.state_numbers` <- function(x, name) { v <- .subset2(x, name)
  if (is.null(v)) stop("Unknown manuscript number: N$", name, call. = FALSE); v }
`[[.state_numbers` <- function(x, i, ...) { v <- .subset2(x, i)
  if (is.null(v)) stop("Unknown manuscript number: N[[\"", i, "\"]]", call. = FALSE); v }

# ---- descriptor table (Table 2 of the manuscript) ---------------------------------------------------------------------------------------------
auc_cell <- function(d) { a <- au(d); sprintf("%s (%s)", fmt(a$AUC, 2), rng(a$lo, a$hi, 2)) }
trec_B <- paste0(fmt(median(mB$Trec), 1), if (median(mB$Trec) >= V$H) " (right-censored)" else "")
T2 <- data.frame(
  Descriptor = c(sprintf("Baseline SD of $d(A_t,\\mathcal R_{rest})$, $t<%s$ s (ms)", N$t0),
                 "Baseline windows with a smoothed excursion beyond $\\delta$ (%)",
                 "Saddle crossed during baseline (%)",
                 "Peak displacement $D_{max}$ (ms)",
                 sprintf("Sustained return $P_{return}(%s\\ \\text{s},%s\\ \\text{s})$ (%%)", N$H, N$tau),
                 sprintf("Recovery time $T_{rec}(\\delta,%s\\ \\text{s})$, median (s)", N$tau),
                 sprintf("Regime shift $P_{transition}(%s\\ \\text{s})$ (%%)", N$H)),
  `System A (monostable)` = c(q3(mA$bl_sd), pw(mA$bl_excursion), pw(mA$saddle_crossed_baseline), q3(mA$Dmax), pw(mA$returned), fmt(median(mA$Trec), 1), pw(mA$transitioned)),
  `System B (bistable)`   = c(q3(mB$bl_sd), pw(mB$bl_excursion), pw(mB$saddle_crossed_baseline), q3(mB$Dmax), pw(mB$returned), trec_B, pw(mB$transitioned)),
  `AUC, B vs A (95% CI)`  = c(auc_cell("bl_sd"), "", "", auc_cell("Dmax"), "", fmt(V$auc_tr, 2), ""),
  check.names = FALSE, stringsAsFactors = FALSE)
# the table is recomputed here from the per-replicate results; it must agree with what state-sim.R wrote
.te <- rd("table_ensemble.csv")
.chk <- c(T2[1, 2] == .te[system == "A"]$baseline_SD_ms, T2[1, 3] == .te[system == "B"]$baseline_SD_ms,
          T2[4, 2] == .te[system == "A"]$Dmax_ms, T2[4, 3] == .te[system == "B"]$Dmax_ms,
          T2[7, 3] == .te[system == "B"]$P_transition_H55_pct, T2[5, 3] == .te[system == "B"]$P_return_H55_tau5_pct)
stopifnot("Table recomputed in state-numbers.R disagrees with results/simulation/table_ensemble.csv" = all(.chk))

N$cap_ensemble <- sprintf("Descriptors in %s replicates per system ($\\sigma=%s$, $\\delta=%s$ ms, $\\tau=%s$ s, $H=%s$ s). Continuous descriptors: median [2.5th, 97.5th percentile]; percentages: proportion [95%% Wilson interval]. AUC $=\\Pr(B>A)+\\tfrac12\\Pr(\\text{tie})$; 0.5 indicates no separation.",
                          N$R_main, N$sigma, N$delta, N$tau, N$H)

# ---- claims ledger: every qualitative statement of the text that depends on the numbers --------------------------------------------------------
claims <- function() with(V, data.table(
  claim = c(
    "Sec. 5  'System A ... remained [in the tolerance region] in all replicates'", "Sec. 5  baseline variability 'comparable' (AUC between 0.5 and 0.65)",
    "Sec. 5  peak displacement 'did not discriminate' at the pulse used (AUC below 0.5)", "Sec. 5  recovery descriptors 'separated almost perfectly' (AUC >= 0.99)",
    "Sec. 5  System B 'only' returns in a minority of replicates (< 10%)", "Sec. 5  most B replicates in the stress basin (> 85%)",
    "App. B  tolerance 'inside the resting basin' (delta < half-width)", "App. A  Monte Carlo 'agreed with the exact value' (deviation <= 6%)",
    "App. A  'T(sigma)' longer than the baseline window at the nominal noise (baseline short)", "App. A  at sigma = 0.20 the baseline is NOT short relative to T",
    "App. B  P_transition 'falls' with noise toward the stationary 50% (within 5 points)", "App. B  saddle crossings in baseline rise with noise",
    "App. B  baseline AUC rises with noise", "App. B  recovery AUC at least 0.8 at every noise level",
    "App. B  dose-response 'plateaus at about 90%' (all amplitudes >= u_plateau within 5 points of the mean)", "App. B  System A 'almost never' shifts regime (<= 3%)",
    "App. B  high noise: 'irrespective of amplitude' (range <= 15 points)", "App. B  peaks 'equal only at the largest amplitude' (ratio within 5% of 1 at u = 0.5, > 1.1 at 0.04)",
    "App. B  no sustained return 'at least 80%' for every delta <= 300 ms", "App. B  'none' at delta >= 450 ms",
    "App. B  dt change 'less than 1%' in D_max and within Monte Carlo error (< 3 points) in P_transition",
    "App. B  tolerance rule inside basin yet below the stress attractor", "Disc.  'up to 2.8 times larger' at intermediate amplitudes (max ratio > 1.5)",
    "Disc.  regime shift differs 'at every amplitude tested' (B min > 0 and A max = 0)", "App. B  barrier about 2-3 noise intensities at the nominal noise"),
    ok = c(
    retA == 100, auc_bl > 0.5 & auc_bl < 0.65, auc_dm < 0.5, auc_tr >= 0.99, retB < 10, transB > 85, delta < half, mc_dev <= 6,
    T_nom > t0, T_hi < 2 * t0,
    abs(pt_last - 50) <= 5 & pt_last < pt_first, cr_last > cr_first, aucbl_last > aucbl_first, auctr_min >= 0.8,
    all(abs(dose_nom[u_S >= u_plateau]$P_transition_B - plateau) <= 5), ptA_max <= 3,
    (pt_hi_hi - pt_hi_lo) <= 15, abs(r[6] - 1) <= 0.05 & r[2] > 1.1,
    nr_le >= 80, nr_hi == 0, dmax_chg < 1 & pt_chg < 3,
    delta < d_str, r_max > 1.5, ptB_min > 0 & ptA_max == 0, bn_nom > 2 & bn_nom < 3)))
check_claims <- function(strict = identical(Sys.getenv("STATE_STRICT"), "1")) {
  cl <- claims(); fwrite(cl, "results/claims_check.csv"); bad <- cl[ok == FALSE]
  if (nrow(bad)) {
    msg <- paste0("Statements in index.qmd no longer supported by the results:\n  - ", paste(bad$claim, collapse = "\n  - "))
    cat("\n[STATE claims check] ", msg, "\n\n", file = stderr())       # stderr: knitr swallows warnings raised inside include:false chunks
    if (strict) stop(msg, call. = FALSE) else warning(msg, call. = FALSE) }  # set STATE_STRICT=1 to make the render fail
  invisible(cl) }
