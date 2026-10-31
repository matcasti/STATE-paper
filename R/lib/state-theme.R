# ==============================================================================
# STATE -- shared visual language for all figures (palette, theme, helpers)
#   * clean axes (left/bottom lines only), no panel boxes, no grids
#   * direct labels instead of legends, no label boxes
#   * one sans-serif family: Arial / Helvetica if installed, otherwise the closest available
# ==============================================================================
if (!require("pacman")) install.packages("pacman")
pacman::p_load(ggplot2, patchwork)

pick_font <- function(candidates = c("Arial", "Helvetica Neue", "Helvetica", "Liberation Sans", "TeX Gyre Heros", "DejaVu Sans")) {
  have <- tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character(0))
  hit <- candidates[candidates %in% have]; if (length(hit)) hit[[1]] else "sans" }
fam <- pick_font()

pal <- list(A = "#1F4E79", B = "#B03A2E",                     # systems A (monostable) and B (bistable)
            ink = "#1F2933", mute = "#5F6B7A", guide = "#A0AAB5", faint = "#DDE2E8",
            accent = "#B7791F", pulse = "#F8F2E0", basin = "#F8E5E2")
cols <- c(A = pal$A, B = pal$B)

theme_state <- function(base = 7.5) {
  theme_classic(base_size = base, base_family = fam) %+replace% theme(
    text = element_text(family = fam, colour = pal$ink),
    axis.line = element_line(linewidth = 0.3, colour = pal$ink),
    axis.ticks = element_line(linewidth = 0.3, colour = pal$ink), axis.ticks.length = unit(1.8, "pt"),
    axis.text = element_text(size = base - 0.5, colour = pal$ink),
    axis.title = element_text(size = base, colour = pal$ink, margin = margin(t = 2, r = 2)),
    axis.title.y = element_text(angle = 90, margin = margin(r = 3)),
    plot.title = element_text(face = "bold", size = base + 0.8, hjust = 0, margin = margin(b = 1)),
    plot.subtitle = element_text(size = base - 0.5, colour = pal$mute, hjust = 0, margin = margin(b = 5)),
    plot.title.position = "plot", plot.tag = element_text(face = "bold", size = base + 2.5),
    panel.grid = element_blank(), panel.background = element_blank(), plot.background = element_blank(),
    legend.position = "none", plot.margin = margin(3, 5, 2, 2))
}
# text annotation in the figure font (no box)
txt <- function(x, y, label, colour = pal$mute, hjust = 0.5, vjust = 0.5, size = 2.3, face = "plain", angle = 0, lineheight = 0.95)
  annotate("text", x = x, y = y, label = label, colour = colour, hjust = hjust, vjust = vjust, size = size, family = fam,
           fontface = face, angle = angle, lineheight = lineheight)
# save a figure as PNG (raster, embedded in the manuscript) and PDF (vector, uploaded to the journal)
save_fig <- function(plot, png, pdf, width, height, dpi = 500) {
  ggsave(png, plot, width = width, height = height, dpi = dpi, device = ragg::agg_png, bg = "white")
  ggsave(pdf, plot, width = width, height = height, device = grDevices::cairo_pdf, bg = "white") }
