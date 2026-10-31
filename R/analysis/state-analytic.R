# ==============================================================================
# STATE -- exact (closed-form / exact-quadrature) properties of the illustrative systems
# ==============================================================================
source("R/lib/state-lib.R"); p <- state_params(); dir.create("results/exact", recursive = TRUE, showWarnings = FALSE)
lam <- lambda_rest(p); p$delta <- delta_rule(p)

eq <- data.table(point = c("rest", "saddle", "stress"), S = c(0, p$a, p$b))
eq[, `:=`(P = -p$gamma * S, lambda_S = cubic_slope(S, p), lambda_P = -p$k_P, U = cubic_pot(S, p))]
eq[, type := fifelse(lambda_S < 0, "stable node", "saddle")]
eq[, dist_ms := sqrt(S^2 + P^2) * p$scale]
cat("== System B equilibria (dimensionless) ==\n"); print(eq[, lapply(.SD, function(x) if (is.numeric(x)) signif(x, 5) else x)])
cat(sprintf("\nRate of System A = Jacobian of B at rest: lambda = k_S*a*b = %.4f\n", lam))
cat(sprintf("Curl of B's drift  d f_P/dS - d f_S/dP = %.3f  (non-gradient)\n", -p$k_P * p$gamma))

Sg <- stationary_cov_A(p)
cat(sprintf("\nExact stationary covariance of A (sigma=%.2f): Var(S)=%.5f Var(P)=%.5f Cov=%.5f\n", p$sigma, Sg[1,1], Sg[2,2], Sg[1,2]))
cat(sprintf("A-priori tolerance rule: delta = 99.9%% quantile of stationary |A| = %.1f ms ; separatrix half-width = %.0f ms ; saddle dist = %.1f ms ; stress dist = %.1f ms\n",
            p$delta, p$a * p$scale, eq[point == "saddle", dist_ms], eq[point == "stress", dist_ms]))

dU <- cubic_pot(p$a, p) - cubic_pot(0, p)
st <- stationary_S(p, p$sigma)
mf <- rbindlist(lapply(c(0.05, 0.075, 0.10, 0.125, 0.15, 0.20, 0.25), function(sg) data.table(
  sigma = sg, barrier_over_noise = dU / (sg^2 / 2), MFPT_s = mfpt_exact(p, sg),
  stationary_Var_S_B = { s <- stationary_S(p, sg); m <- sum(s$S * s$dens) * s$h; sum((s$S - m)^2 * s$dens) * s$h },
  Var_S_A = sg^2 / (2 * lam))))
cat(sprintf("\nBarrier dU=%.5f ; stationary mass of stress basin = %.4f\n", dU, sum(st$dens[st$S > p$a]) * st$h)); print(mf[, lapply(.SD, signif, 4)])
fwrite(mf, "results/exact/exact_mfpt.csv")

uc <- critical_forcing(p)
cat(sprintf("\nCritical constant forcing u_c = %.4f ; pulse u_S = %.2f = %.1f u_c ; A needs lambda*a = %.4f = %.1f u_c to reach the saddle location\n",
            uc, p$u_S, p$u_S / uc, lam * p$a, lam * p$a / uc))
SA <- p$u_S / lam; cat(sprintf("Noise-free forced plateau of A: S=%.3f -> distance %.0f ms\n", SA, sqrt(SA^2 + (( p$u_P - p$k_P*p$gamma*SA)/p$k_P)^2) * p$scale))

obs_rank <- function(Fm, cv) qr(rbind(cv, as.numeric(cv %*% Fm)))$rank
FA <- diag(-lam, 2); FB <- jacobian_A(p); FD <- diag(c(-lam, -p$k_P))   # isotropic | coupled (B at rest) | uncoupled, distinct rates
cs <- list(c(1, 0), c(0, 1), c(1, 1), c(-1, 1))
ob <- rbindlist(lapply(cs, function(cv) data.table(c = paste0("(", paste(cv, collapse = ","), ")"),
          rank_isotropic_uncoupled = obs_rank(FA, cv), rank_uncoupled_distinct_rates = obs_rank(FD, cv), rank_coupled = obs_rank(FB, cv))))
cat("\nObservability rank (2 = full) from ONE scalar output y = c'A:\n"); print(ob); fwrite(ob, "results/exact/observability_rank.csv")
fwrite(data.table(delta_ms = p$delta, lambda = lam, barrier = dU, u_c = uc), "results/exact/exact_constants.csv")
