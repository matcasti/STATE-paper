# ==============================================================================
# STATE -- regenerate every exact result, simulation, table and figure of the manuscript.
# Requirements: R (>= 4.3), data.table, ggplot2, patchwork, ragg (pacman installs them).
# Runtime: about 3-5 minutes on one core. Seeds are fixed inside each script.
# ==============================================================================
for (f in c("R/analysis/state-analytic.R", "R/analysis/state-validate.R", "R/analysis/state-sim.R",       # 1. exact results and simulations -> results/
            "R/check-manuscript.R",                                            # 2. labels, N$ keys, hand-typed numbers, claims ledger
            "R/figures/fig-state-sim.R", "R/figures/fig-graphical-abstract.R")) {              # 3. figures (PNG in manuscript/figures/png, vector PDF in manuscript/figures/print)
  cat("\n>>>", f, "\n"); source(f, local = new.env()) }
# 4. render the manuscript:  quarto render manuscript/index.qmd --to docx
#    (numbers are read from results/ through R/lib/state-numbers.R each time it is rendered)
