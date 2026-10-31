# ==============================================================================
# STATE -- Figure 2 (illustration) and Figure 3 (robustness)
# Data and every printed number come from results/ via R/lib/state-numbers.R
# Output: manuscript/figures/png/fig-illustration.png, fig-robustness.png and vector PDFs manuscript/figures/print/Figure_2.pdf, Figure_3.pdf
# ==============================================================================
source("R/lib/state-numbers.R"); source("R/lib/state-theme.R")
E <- readRDS("results/simulation/ensemble.rds"); paths <- E$paths; bands <- E$bands
half_w <- V$half; u_c <- V$uc
sys_lab <- c(A = "A  monostable", B = "B  bistable")

# =============================== Figure 2 ==========================================================
# ---- (a, b) state space -----------------------------------------------------------------------------
grid <- CJ(S = seq(-60, 680, length.out = 13), P = seq(-430, 110, length.out = 9))
vector_field <- function(sys) {
  Sr <- grid$S / p$scale; Pr <- grid$P / p$scale
  u <- (if (sys == "A") -lam * Sr else cubic_drift(Sr, p)) * p$scale; v <- -p$k_P * (Pr + p$gamma * Sr) * p$scale
  len <- sqrt(u^2 + v^2) + 1e-9; cbind(grid, xe = grid$S + 30 * u / len, ye = grid$P + 30 * v / len) }
circle <- data.table(S = p$delta * cos(seq(0, 2 * pi, length.out = 240)), P = p$delta * sin(seq(0, 2 * pi, length.out = 240)))

ss_panel <- function(sys, ttl, sub, show_y = TRUE) {
  g <- ggplot() +
    (if (sys == "B") list(annotate("rect", xmin = half_w, xmax = Inf, ymin = -Inf, ymax = Inf, fill = pal$basin),
                          geom_vline(xintercept = half_w, linetype = "22", colour = pal$guide, linewidth = 0.35))) +
    geom_segment(data = vector_field(sys), aes(S, P, xend = xe, yend = ye), colour = "#C3CAD2", linewidth = 0.22,
                 arrow = arrow(length = unit(1.5, "pt"), type = "closed")) +
    geom_path(data = circle, aes(S, P), colour = pal$guide, linetype = "22", linewidth = 0.35) +
    geom_path(data = paths[system == sys], aes(S, P), colour = cols[[sys]], linewidth = 0.4, lineend = "round", linejoin = "round") +
    annotate("point", x = 0, y = 0, size = 1.5, colour = pal$ink) +
    coord_fixed(xlim = c(-170, 720), ylim = c(-470, 190), expand = FALSE) +
    scale_x_continuous(breaks = seq(0, 600, 200)) + scale_y_continuous(breaks = seq(-400, 0, 200)) +
    labs(title = ttl, subtitle = sub, x = "Sympathetic coordinate S (ms)", y = if (show_y) "Parasympathetic coordinate P (ms)" else NULL) +
    theme_state()
  if (sys == "B") g <- g +
    annotate("point", x = half_w, y = -p$gamma * half_w, shape = 4, size = 1.9, stroke = 0.5, colour = pal$mute) +
    annotate("point", x = p$b * p$scale, y = -p$gamma * p$b * p$scale, shape = 17, size = 1.9, colour = pal$B) +
    txt(half_w + 10, 135, "separatrix", hjust = 0) + txt(p$b * p$scale + 70, -p$gamma * p$b * p$scale + 78, "stress attractor", colour = pal$B, hjust = 0) +
    txt(half_w + 17, -p$gamma * half_w + 4, "saddle", hjust = 0) + txt(660, 135, "stress basin", colour = pal$B, hjust = 1)
  g }
pa <- ss_panel("A", "Monostable control (A)", "Linear drift, same Jacobian as B at rest")
pb <- ss_panel("B", "Bistable landscape (B)", "Cubic drift: rest, saddle, stress attractor", show_y = FALSE)

# ---- (c) time course ------------------------------------------------------------------------------------------
end_y <- function(s) bands[system == s][which.max(t)]$q50
pc <- ggplot() +
  annotate("rect", xmin = p$P_start, xmax = p$P_end, ymin = -Inf, ymax = Inf, fill = pal$pulse) +
  geom_hline(yintercept = p$delta, linetype = "22", colour = pal$accent, linewidth = 0.35) +
  geom_ribbon(data = bands, aes(t, ymin = q05, ymax = q95, fill = system), alpha = 0.16) +
  geom_line(data = paths, aes(t, d, colour = system), linewidth = 0.28, alpha = 0.75, lineend = "round") +
  geom_line(data = bands, aes(t, q50, colour = system), linewidth = 0.85, lineend = "round") +
  scale_colour_manual(values = cols) + scale_fill_manual(values = cols) +
  txt(0.8, p$delta + 42, sprintf("\u03b4 = %s ms", fmt(p$delta, 0)), colour = pal$accent, hjust = 0) +
  txt(mean(c(p$P_start, p$P_end)), 905, "pulse", colour = pal$accent) +
  txt(101.5, end_y("B"), sys_lab[["B"]], colour = pal$B, hjust = 0, face = "bold") + txt(101.5, end_y("A"), sys_lab[["A"]], colour = pal$A, hjust = 0, face = "bold") +
  txt(98, 560, sprintf("%s%% in stress basin at t = %s s;  %s%% sustained return", N$transB0, N$tmax, N$retB0), colour = pal$B, hjust = 1) +
  txt(98, 110, sprintf("%s%% sustained return;  median T_rec = %s s", N$retA0, N$trA), colour = pal$A, hjust = 1) +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 950), clip = "off", expand = FALSE) +
  scale_x_continuous(breaks = seq(0, 100, 25)) + scale_y_continuous(breaks = seq(0, 800, 200)) +
  labs(title = "Same pulse, similar peak, different fate",
       subtitle = sprintf("Distance from rest: median, 90%% band (n = %s per system) and the replicate closest to the medians", N$R_main),
       x = "Time (s)", y = "Distance from rest (ms)") +
  theme_state() + theme(plot.margin = margin(3, 62, 2, 2))

# ---- (d-g) ensemble descriptors ---------------------------------------------------------------------------------
iv_q <- function(x) data.table(y = median(x), lo = quantile(x, .025)[[1]], hi = quantile(x, .975)[[1]])
iv_p <- function(x) { w <- wilson(sum(x), length(x)); data.table(y = 100 * mean(x), lo = 100 * w[["lo"]], hi = 100 * w[["hi"]]) }
mk <- function(f, var) rbindlist(list(cbind(sys = "A", f(mA[[var]])), cbind(sys = "B", f(mB[[var]]))))
dot_panel <- function(d, ttl, sub, ylab, breaks, ylim, labels = FALSE) {
  g <- ggplot(d, aes(sys, y, colour = sys)) + geom_linerange(aes(ymin = lo, ymax = hi), linewidth = 0.55, lineend = "round") +
    geom_point(size = 2, stroke = 0) + scale_colour_manual(values = cols) +
    scale_y_continuous(breaks = breaks, limits = ylim, expand = expansion(mult = c(0, 0))) + scale_x_discrete(expand = expansion(add = 0.6)) +
    labs(title = ttl, subtitle = sub, x = NULL, y = ylab) + theme_state()
  if (labels) g <- g + geom_text(aes(label = sprintf("%.0f%%", y)), vjust = -1.1, size = 2.3, family = fam, colour = pal$ink)
  g }
pd <- dot_panel(mk(iv_q, "bl_sd"), "Baseline SD", "similar medians", "SD of distance (ms)", seq(0, 80, 20), c(0, 92))
pe <- dot_panel(mk(iv_q, "Dmax"), "Peak displacement", "similar medians", "D_max (ms)", seq(0, 800, 200), c(0, 850))
pf <- dot_panel(mk(iv_p, "returned"), "Sustained return", "divergent", "P_return (%)", seq(0, 100, 25), c(0, 112), labels = TRUE)
pg <- dot_panel(mk(iv_p, "transitioned"), "Regime shift", "divergent", "P_transition (%)", seq(0, 100, 25), c(0, 112), labels = TRUE)

fig2 <- (pa | pb) / pc / (pd | pe | pf | pg) + plot_layout(heights = c(1.02, 0.85, 0.75)) +
  plot_annotation(tag_levels = "a") & theme(plot.tag = element_text(face = "bold", size = 10, family = fam))
save_fig(fig2, "manuscript/figures/png/fig-illustration.png", "manuscript/figures/print/Figure_2.pdf", 7.5, 8.0)

# =============================== Figure 3 ==========================================================
lab_end <- function(x, y, label, colour, ...) txt(x, y, label, colour = colour, hjust = 0, ...)
right <- function(m = 46) theme(plot.margin = margin(3, m, 2, 2))
xs <- expansion(mult = c(0.03, 0.03))

# (a) AUC vs noise ------------------------------------------------------------------------------------------------
al <- melt(sw, id.vars = "sigma", measure.vars = c("AUC_Trec", "AUC_baseline_SD", "AUC_baseline_AC1", "AUC_Dmax"), variable.name = "d", value.name = "AUC")
last <- sw[sigma == s_hi]
f1 <- ggplot(al, aes(sigma, AUC, colour = d, linetype = d)) + geom_hline(yintercept = 0.5, colour = pal$guide, linewidth = 0.3, linetype = "22") +
  geom_line(linewidth = 0.65, lineend = "round") + geom_point(size = 1.1, stroke = 0) +
  scale_colour_manual(values = c(AUC_Trec = pal$B, AUC_baseline_SD = pal$mute, AUC_baseline_AC1 = pal$mute, AUC_Dmax = pal$accent)) +
  scale_linetype_manual(values = c(AUC_Trec = "solid", AUC_baseline_SD = "solid", AUC_baseline_AC1 = "42", AUC_Dmax = "solid")) +
  lab_end(s_hi + 0.008, last$AUC_Trec, "T_rec", pal$B) + lab_end(s_hi + 0.008, last$AUC_baseline_SD, "baseline SD\n(and lag-1 AC)", pal$mute) +
  lab_end(s_hi + 0.008, last$AUC_Dmax, "D_max", pal$accent) + txt(s_hi, 0.515, "no separation", hjust = 1, vjust = 0, colour = pal$guide) +
  coord_cartesian(ylim = c(0, 1), clip = "off") + scale_x_continuous(breaks = seq(0.05, 0.25, 0.05), expand = xs) + scale_y_continuous(breaks = seq(0, 1, 0.25)) +
  labs(title = "Which descriptors separate B from A?", subtitle = "AUC = P(B > A)", x = "Process noise \u03c3", y = "AUC") + theme_state() + right(62)

# (b) noise sets the regime ---------------------------------------------------------------------------------------------
f2 <- ggplot(sw, aes(sigma)) +
  geom_ribbon(aes(ymin = ptrans_lo, ymax = ptrans_hi), fill = pal$B, alpha = 0.14) + geom_line(aes(y = P_transition_B), colour = pal$B, linewidth = 0.65, lineend = "round") +
  geom_ribbon(aes(ymin = cross_lo, ymax = cross_hi), fill = pal$B, alpha = 0.14) + geom_line(aes(y = saddle_crossed_baseline_B), colour = pal$B, linewidth = 0.65, linetype = "42", lineend = "round") +
  geom_point(aes(y = P_transition_B), colour = pal$B, size = 1.1, stroke = 0) + geom_point(aes(y = saddle_crossed_baseline_B), colour = pal$B, size = 1.1, stroke = 0) +
  lab_end(s_hi + 0.008, last$P_transition_B, "in stress basin\nat t = 100 s", pal$B) + lab_end(s_hi + 0.008, last$saddle_crossed_baseline_B, "saddle crossed\nin baseline", pal$B) +
  coord_cartesian(ylim = c(0, 100), clip = "off") + scale_x_continuous(breaks = seq(0.05, 0.25, 0.05), expand = xs) + scale_y_continuous(breaks = seq(0, 100, 25)) +
  labs(title = "Noise sets the regime (B)", subtitle = sprintf("%% of replicates, 95%% intervals; barrier/noise %s to %s", N$bn_hi, N$bn_lo), x = "Process noise \u03c3", y = "% of replicates") + theme_state() + right(62)

# (c) dose-response -----------------------------------------------------------------------------------------------------------
dl_ <- melt(ds, id.vars = c("sigma", "u_S"), measure.vars = c("P_transition_B", "P_transition_A"), variable.name = "sys", value.name = "v")
dl_[, `:=`(sys = sub("P_transition_", "", sys))][, g := paste(sys, sigma)]
u_max <- max(ds$u_S)
f3 <- ggplot(dl_, aes(u_S, v, colour = sys, linetype = factor(sigma), group = g)) +
  geom_vline(xintercept = u_c, linetype = "22", colour = pal$guide, linewidth = 0.3) + geom_vline(xintercept = p$u_S, linetype = "22", colour = pal$accent, linewidth = 0.3) +
  geom_line(linewidth = 0.65, lineend = "round") + geom_point(size = 1, stroke = 0) +
  scale_colour_manual(values = cols) + scale_linetype_manual(values = c("solid", "42")) +
  txt(u_max * 1.12, ptB(p$u_S), sprintf("B, \u03c3 = %s", N$sigma), colour = pal$B, hjust = 0) + txt(u_max * 1.12, ptB(p$u_S, sig_hi), sprintf("B, \u03c3 = %s", N$sig_hi), colour = pal$B, hjust = 0) +
  txt(u_max * 1.12, 3, "A", colour = pal$A, hjust = 0) +
  txt(u_c * 1.08, 97, sprintf("u_c = %s", fmt(u_c, 3)), hjust = 0, vjust = 1) + txt(p$u_S * 0.9, 12, "pulse\nused", colour = pal$accent, hjust = 1) +
  coord_cartesian(ylim = c(0, 100), clip = "off") + scale_x_log10(breaks = c(0.01, 0.03, 0.1, 0.5)) + scale_y_continuous(breaks = seq(0, 100, 25)) +
  labs(title = "Dose\u2013response", subtitle = "% in stress basin at t = 100 s", x = "Pulse amplitude u_S", y = "P_transition (%)") + theme_state() + right(42)

# (d) peak ratio ----------------------------------------------------------------------------------------------------------------------
dr <- ds[, .(sigma, u_S, ratio = Dmax_B / Dmax_A)]
pk <- function(s) dr[sigma == s][which.max(ratio)]
f5 <- ggplot(dr, aes(u_S, ratio, linetype = factor(sigma), group = sigma)) + geom_hline(yintercept = 1, colour = pal$guide, linewidth = 0.3, linetype = "22") +
  geom_vline(xintercept = p$u_S, linetype = "22", colour = pal$accent, linewidth = 0.3) +
  geom_line(colour = pal$accent, linewidth = 0.65, lineend = "round") + geom_point(colour = pal$accent, size = 1, stroke = 0) +
  scale_linetype_manual(values = c("solid", "42")) +
  txt(pk(p$sigma)$u_S * 1.1, pk(p$sigma)$ratio + 0.12, sprintf("\u03c3 = %s", N$sigma), colour = pal$accent, hjust = 0) +
  txt(pk(sig_hi)$u_S * 0.9, pk(sig_hi)$ratio + 0.12, sprintf("\u03c3 = %s", N$sig_hi), colour = pal$accent, hjust = 1) +
  txt(p$u_S * 0.9, 3.1, "pulse used", colour = pal$accent, hjust = 1) +
  coord_cartesian(ylim = c(0.8, 3.2), clip = "off") + scale_x_log10(breaks = c(0.01, 0.03, 0.1, 0.5)) + scale_y_continuous(breaks = seq(1, 3, 0.5)) +
  labs(title = "Peak depends on amplitude", subtitle = "median D_max(B) / D_max(A)", x = "Pulse amplitude u_S", y = "D_max ratio B / A") + theme_state() + right(6)

# (e) tolerance --------------------------------------------------------------------------------------------------------------------------
f4 <- ggplot(dl, aes(delta, no_return, colour = system)) +
  geom_vline(xintercept = c(half_w, V$d_str), linetype = "22", colour = pal$guide, linewidth = 0.3) + geom_vline(xintercept = p$delta, linetype = "22", colour = pal$accent, linewidth = 0.35) +
  geom_line(linewidth = 0.65, lineend = "round") + geom_point(size = 1, stroke = 0) + scale_colour_manual(values = cols) +
  txt(half_w + 9, 8, "separatrix", angle = 90, hjust = 0) + txt(V$d_str + 9, 8, "stress attractor", angle = 90, hjust = 0) +
  txt(300, 92, "B", colour = pal$B, face = "bold", size = 2.8) + txt(560, 6, "A", colour = pal$A, face = "bold", size = 2.8) +
  coord_cartesian(ylim = c(0, 100), clip = "off") + scale_x_continuous(breaks = seq(0, 600, 200)) + scale_y_continuous(breaks = seq(0, 100, 25)) +
  labs(title = "Sensitivity to \u03b4", subtitle = "% without sustained return", x = "Tolerance \u03b4 (ms)", y = "% without sustained return") + theme_state() + right(6)

fig3 <- (f1 | f2) / (f3 | f5 | f4) + plot_annotation(tag_levels = "a") & theme(plot.tag = element_text(face = "bold", size = 10, family = fam))
save_fig(fig3, "manuscript/figures/png/fig-robustness.png", "manuscript/figures/print/Figure_3.pdf", 7.5, 6.9)
cat("figures saved\n")
