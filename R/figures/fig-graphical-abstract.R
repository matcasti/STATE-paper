# ==============================================================================
# STATE -- graphical abstract (Elsevier: TIFF/PDF/PNG, at least 531 x 1328 px) -> manuscript/figures/print/Graphical_abstract.tiff
# All numbers come from results/ via R/lib/state-numbers.R
# ==============================================================================
source("R/lib/state-numbers.R"); source("R/lib/state-theme.R")
bands <- readRDS("results/simulation/ensemble.rds")$bands
end_y <- function(s) bands[system == s][which.max(t)]$q50
t_pulse <- c(p$P_start, p$P_end); y_br <- 1015
bracket <- function(x0, x1, y = y_br, tick = 18) list(
  annotate("segment", x = x0, xend = x1, y = y, yend = y, colour = pal$ink, linewidth = 0.4),
  annotate("segment", x = x0, xend = x0, y = y, yend = y - tick, colour = pal$ink, linewidth = 0.4),
  annotate("segment", x = x1, xend = x1, y = y, yend = y - tick, colour = pal$ink, linewidth = 0.4))
stage <- function(x0, x1, head, detail) list(bracket(x0 + 0.6, x1 - 0.6),
  txt((x0 + x1) / 2, y_br + 24, head, colour = pal$ink, face = "bold", size = 3.0, vjust = 0),
  txt((x0 + x1) / 2, y_br + 112, detail, colour = pal$mute, size = 2.5, vjust = 0, lineheight = 1))

g <- ggplot() +
  annotate("rect", xmin = t_pulse[1], xmax = t_pulse[2], ymin = 0, ymax = y_br - 40, fill = pal$pulse) +
  geom_ribbon(data = bands, aes(t, ymin = q05, ymax = q95, fill = system), alpha = 0.17) +
  geom_line(data = bands, aes(t, q50, colour = system), linewidth = 1.0, lineend = "round") +
  geom_hline(yintercept = p$delta, linetype = "22", colour = pal$accent, linewidth = 0.35) +
  scale_colour_manual(values = cols) + scale_fill_manual(values = cols) +
  stage(0, p$P_start, "1  Similar baseline", sprintf("AUC %s", N$auc_bl)) +
  stage(t_pulse[1], t_pulse[2], "2  Similar peak", sprintf("AUC %s\n(at this amplitude)", N$auc_dm)) +
  stage(t_pulse[2], p$t_max, "3  Different fate", sprintf("sustained return: A %s%%, B %s%%\nregime shift in B: %s%%", N$retA0, N$retB0, N$transB0)) +
  txt(p$t_max + 1.5, end_y("B"), "B  bistable", colour = pal$B, hjust = 0, face = "bold", size = 2.9) +
  txt(p$t_max + 1.5, end_y("A"), "A  monostable", colour = pal$A, hjust = 0, face = "bold", size = 2.9) +
  txt(mean(t_pulse), 40, "pulse", colour = pal$accent, size = 2.4) +
  coord_cartesian(xlim = c(0, p$t_max), ylim = c(0, 1010), clip = "off", expand = FALSE) +
  scale_x_continuous(breaks = seq(0, 100, 25)) + scale_y_continuous(breaks = seq(0, 800, 400)) +
  labs(x = "Time (s)", y = "Distance from rest (ms)") +
  theme_state(8) + theme(plot.margin = margin(40, 64, 4, 4))

# title and one-line subtitle live in the margin above the strip
g <- g + plot_annotation(
  title = "Similar baseline. Similar peak. Different fate.",
  subtitle = sprintf("Monostable vs bistable autonomic landscape under one identical pulse (median and 90%% band; n = %s per system)", N$R_main),
  theme = theme(plot.title = element_text(face = "bold", size = 12, family = fam, colour = pal$ink, margin = margin(b = 1)),
                plot.subtitle = element_text(size = 7.5, family = fam, colour = pal$mute, margin = margin(b = 2)), plot.margin = margin(6, 6, 2, 6)))
ggsave("manuscript/figures/print/Graphical_abstract.tiff", g, width = 7.2, height = 2.9, dpi = 500, device = ragg::agg_tiff, compression = "lzw", bg = "white")
cat("graphical abstract saved\n")
