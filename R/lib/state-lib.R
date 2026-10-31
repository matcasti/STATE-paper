# ==============================================================================
# STATE -- shared library (simulation, exact results, descriptors)
# Units: dimensionless latent coordinates, converted to ms by `scale`.
# Vectorised over replicates; loops run over time only.
# ==============================================================================
if (!require("pacman")) install.packages("pacman")
pacman::p_load(data.table)

state_params <- function() list(
  scale = 300,                              # ms per dimensionless unit
  dt = 0.02, t_max = 100,                   # Euler-Maruyama step and horizon (s)
  P_start = 25, P_end = 45,                 # perturbation window (s)
  u_S = 0.50, u_P = -0.20,                  # pulse (dimensionless): u_P = -0.4 u_S
  k_S = 0.38, a = 0.6, b = 1.2,             # System B: cubic drift with roots 0, a (saddle), b (stress)
  k_P = 0.48, gamma = 0.50,                 # P relaxes to -gamma*S (both systems)
  sigma = 0.10,                             # nominal process noise
  tau = 5,                                  # dwell time for 'sustained' return (s)
  win = 25,                                 # 0.5-s moving average (samples)
  delta = NA_real_                          # tolerance (ms); set by delta_rule()
)
lambda_rest <- function(p) p$k_S * p$a * p$b   # rate of System A = Jacobian of B at rest (S direction)

# ---- exact objects of the S-subsystem of B  (autonomous gradient diffusion) ------
cubic_drift <- function(S, p) -p$k_S * S * (S - p$a) * (S - p$b)
cubic_slope <- function(S, p) -p$k_S * (3 * S^2 - 2 * (p$a + p$b) * S + p$a * p$b)
cubic_pot   <- function(S, p) p$k_S * (S^4 / 4 - (p$a + p$b) * S^3 / 3 + p$a * p$b * S^2 / 2)
mfpt_exact <- function(p, sigma, from = 0, to = p$a, lo = -1, n = 400001L) {
  S <- seq(lo, to, length.out = n); h <- S[2] - S[1]; U <- cubic_pot(S, p); c2 <- 2 / sigma^2
  inner <- cumsum(exp(-c2 * U)) * h; i0 <- which.min(abs(S - from))
  c2 * sum((exp(c2 * U) * inner)[i0:n]) * h
}
stationary_S <- function(p, sigma, n = 200001L, lim = c(-1.5, 3)) {
  S <- seq(lim[1], lim[2], length.out = n); h <- S[2] - S[1]
  w <- exp(-2 * cubic_pot(S, p) / sigma^2); list(S = S, dens = w / (sum(w) * h), h = h)
}
critical_forcing <- function(p) {
  Sx <- ((p$a + p$b) - sqrt(p$a^2 - p$a * p$b + p$b^2)) / 3
  -cubic_drift(Sx, p)
}

# ---- exact stationary law of System A and the a-priori tolerance rule -------------
jacobian_A <- function(p) matrix(c(-lambda_rest(p), 0, -p$k_P * p$gamma, -p$k_P), 2, byrow = TRUE)
stationary_cov_A <- function(p, sigma = p$sigma) {       # Lyapunov equation F S + S F' + sigma^2 I = 0
  Fm <- jacobian_A(p); M <- kronecker(diag(2), Fm) + kronecker(Fm, diag(2))
  matrix(solve(M, -as.vector(sigma^2 * diag(2))), 2, 2)
}
# delta = q-quantile of the stationary distance |A| of the monostable System A (exact 1-D quadrature
# of the Gaussian tail in polar form). Calibrated from the resting regime only, i.e. independent of outcome.
delta_rule <- function(p, sigma = p$sigma, q = 0.999) {
  Sg <- stationary_cov_A(p, sigma); Si <- solve(Sg)
  th <- seq(0, 2 * pi, length.out = 4001)[-4001]
  g <- Si[1, 1] * cos(th)^2 + 2 * Si[1, 2] * cos(th) * sin(th) + Si[2, 2] * sin(th)^2
  tail_p <- function(r) mean(exp(-r^2 * g / 2) / g) / sqrt(det(Sg))
  uniroot(function(r) tail_p(r) - (1 - q), c(1e-6, 10), tol = 1e-12)$root * p$scale
}

# ---- Euler-Maruyama integrator: System A (linear control) and System B (bistable) --
simulate_state <- function(R, p, sigma = p$sigma, u_scale = 1, systems = c("A", "B"),
                           keep_S = systems, keep_P = character(0)) {
  t <- seq(0, p$t_max, by = p$dt); N <- length(t); sq <- sqrt(p$dt)
  on <- t >= p$P_start & t <= p$P_end; uS <- u_scale * p$u_S * on; uP <- u_scale * p$u_P * on
  lam <- lambda_rest(p)
  dS <- list(A = function(S) -lam * S, B = function(S) cubic_drift(S, p))
  dP <- function(P, S) -p$k_P * (P + p$gamma * S)
  st   <- setNames(lapply(systems, function(s) list(S = rep(0.02, R), P = rep(-0.02, R))), systems)
  dist <- setNames(lapply(systems, function(s) { m <- matrix(0, N, R); m[1, ] <- sqrt(2) * 0.02 * p$scale; m }), systems)
  mk <- function(keep, init) setNames(lapply(intersect(keep, systems), function(s) { m <- matrix(0, N, R); m[1, ] <- init; m }), intersect(keep, systems))
  Sm <- mk(keep_S, 0.02); Pm <- mk(keep_P, -0.02)
  for (i in seq_len(N - 1L)) for (s in systems) {
    S <- st[[s]]$S; P <- st[[s]]$P
    Sn <- S + (dS[[s]](S) + uS[i]) * p$dt + sigma * sq * rnorm(R)
    Pn <- P + (dP(P, S)   + uP[i]) * p$dt + sigma * sq * rnorm(R)
    st[[s]]$S <- Sn; st[[s]]$P <- Pn; dist[[s]][i + 1L, ] <- sqrt(Sn^2 + Pn^2) * p$scale
    if (!is.null(Sm[[s]])) Sm[[s]][i + 1L, ] <- Sn
    if (!is.null(Pm[[s]])) Pm[[s]][i + 1L, ] <- Pn
  }
  list(t = t, dist = dist, S = Sm, P = Pm, sigma = sigma)
}

# ---- descriptors (manuscript definitions) ------------------------------------------
smooth_cols <- function(M, win) {
  sm <- matrix(as.numeric(stats::filter(M, rep(1 / win, win), sides = 2)), nrow(M), ncol(M))
  i <- is.na(sm); sm[i] <- M[i]; sm
}
state_metrics <- function(dist, t, p, S_mat = NULL, delta = p$delta, tau = p$tau) {
  base <- t < p$P_start; pert <- t >= p$P_start & t <= p$P_end; post <- t > p$P_end; tp <- t[post]
  Db <- dist[base, , drop = FALSE]; n <- nrow(Db); H <- p$t_max - p$P_end
  sm <- smooth_cols(dist, p$win); inside <- sm[post, , drop = FALSE] <= delta; n_tau <- round(tau / p$dt)
  trec <- apply(inside, 2, function(v) {          # T_rec(delta, tau): earliest t with dwell tau inside R_rest^delta
    r <- rle(v); e <- cumsum(r$lengths); ok <- which(r$values & r$lengths >= n_tau)
    if (length(ok)) tp[e[ok[1]] - r$lengths[ok[1]] + 1L] - p$P_end else NA_real_ })
  res <- data.table(
    bl_sd = sqrt((colSums(Db^2) - n * colMeans(Db)^2) / (n - 1)),
    bl_ac1 = vapply(seq_len(ncol(Db)), function(j) cor(Db[-1, j], Db[-n, j]), 0),
    bl_excursion = apply(sm[base, , drop = FALSE] > delta, 2, any),
    Dmax = apply(dist[pert, , drop = FALSE], 2, max),
    returned = !is.na(trec),                       # P_return(H, tau)
    Trec = ifelse(is.na(trec), H, trec))           # right-censored at the horizon H
  if (!is.null(S_mat)) {
    res[, saddle_crossed_baseline := apply(S_mat[base, , drop = FALSE] > p$a, 2, any)]
    res[, transitioned := S_mat[nrow(S_mat), ] > p$a]   # P_transition(H): in the stress basin at t_end + H
  }
  res
}
return_by_delta <- function(dist, t, p, deltas) rbindlist(lapply(deltas, function(d) {
  m <- state_metrics(dist, t, p, delta = d); data.table(delta = d, no_return = 100 * mean(!m$returned)) }))
auc_rank <- function(x_ref, x_B) {                 # P(X_B > X_ref) + 0.5 P(tie)
  r <- rank(c(x_ref, x_B)); n1 <- length(x_ref); n2 <- length(x_B)
  (sum(r[n1 + seq_len(n2)]) - n2 * (n2 + 1) / 2) / (n1 * n2)
}
auc_ci <- function(x_ref, x_B, B = 400L) {         # percentile bootstrap
  bs <- replicate(B, auc_rank(sample(x_ref, replace = TRUE), sample(x_B, replace = TRUE)))
  quantile(bs, c(.025, .975))
}
wilson <- function(k, n, z = 1.96) { ph <- k / n; d <- 1 + z^2 / n
  c(lo = (ph + z^2 / (2 * n) - z * sqrt(ph * (1 - ph) / n + z^2 / (4 * n^2))) / d,
    hi = (ph + z^2 / (2 * n) + z * sqrt(ph * (1 - ph) / n + z^2 / (4 * n^2))) / d) }
