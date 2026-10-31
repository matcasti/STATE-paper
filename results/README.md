# results/ — outputs of the analysis

Written by `R/analysis/`, read by `R/lib/state-numbers.R` (and so by the manuscript). Do not edit by hand; regenerate with `Rscript R/run-all.R`.

| Path | Content |
|---|---|
| `exact/exact_constants.csv` | A priori tolerance δ, rate λ, barrier and critical forcing u_c. |
| `exact/exact_mfpt.csv` | Exact mean escape time and stationary variances by noise level σ. |
| `exact/mfpt_validation.csv` | Monte Carlo escape time against the exact value. |
| `exact/observability_rank.csv` | Rank of the observability matrix for the three dynamics of Proposition 1. |
| `simulation/ensemble.rds` | Representative trajectories and ensemble bands (Figure 2, graphical abstract). |
| `simulation/ensemble_metrics.csv` | Per-replicate descriptors, systems A and B. |
| `simulation/table_ensemble.csv` | Table 2. |
| `simulation/auc_main.csv` | AUC of each descriptor, with bootstrap interval. |
| `simulation/noise_sweep.csv` | Robustness to noise level (Figure 3a, b). |
| `simulation/dose_response.csv` | Response to pulse amplitude (Figure 3c, d). |
| `simulation/delta_sensitivity.csv` | Sensitivity to the tolerance δ (Figure 3e). |
| `simulation/dt_convergence.csv` | Time-step convergence of the integrator. |
| `simulation/run_settings.csv` | Replicate counts used in each analysis. |
| `sessionInfo.txt` | R version and packages of the last run. |
| `claims_check.csv` | Qualitative claims of the text and whether they hold. Regenerated at every render and not tracked. |
