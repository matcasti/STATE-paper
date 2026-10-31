# R/ — code

Run everything from the **project root** (paths are relative to it): `make results figures` (or `Rscript R/run-all.R`, which also runs the manuscript checks).

| Path | What it does |
|---|---|
| `run-all.R` | Runs the analysis, the manuscript checks and the figure scripts in order (~2.5 min). |
| `check-manuscript.R` | Checks `manuscript/index.qmd`: labels exist, `N$` keys exist, no hand-typed results, the qualitative claims still hold. |
| **`lib/`** | Code the other scripts load; it produces nothing by itself. |
| `lib/state-lib.R` | Model parameters, the simulation of the two systems, exact formulas and the resilience descriptors. |
| `lib/state-numbers.R` | Reads `results/` and exposes `N` (formatted strings for the text), `V` (values), `T2` (Table 2) and the claims ledger. The only source of numbers for `manuscript/index.qmd`. |
| `lib/state-theme.R` | Figure palette, theme, font choice and `save_fig()`. |
| **`analysis/`** | Scripts that compute; they write to `results/`. |
| `analysis/state-analytic.R` | Exact properties (equilibria, eigenvalues, stationary law, escape time, critical forcing, observability) → `results/exact/`. |
| `analysis/state-validate.R` | Monte Carlo check of the exact escape time → `results/exact/mfpt_validation.csv`. |
| `analysis/state-sim.R` | Main ensemble, noise sweep, dose–response, tolerance sensitivity, time-step convergence → `results/simulation/` and `results/sessionInfo.txt`. |
| **`figures/`** | Scripts that draw. |
| `figures/fig-state-sim.R` | Figure 2 and Figure 3 → PNG in `manuscript/figures/png/`, vector PDF in `manuscript/figures/print/`. |
| `figures/fig-graphical-abstract.R` | Graphical abstract → `manuscript/figures/print/Graphical_abstract.tiff`. |

Order matters: `analysis/` first, then `figures/`, because figures read `results/`. Seeds are fixed inside each script, so results are reproducible. Figure 1 is not drawn by code: it is exported by hand from `figures/source/fig-main.sketch`.
