# STATE paper

Code, results and manuscript for *A Systems Theory of Cardiac-Autonomic Trajectories and Equilibria* (STATE): a latent stochastic dynamical-systems framework for cardiac autonomic regulation, with exact results and a simulation study. No empirical data are used.

The manuscript is written in Quarto. Every number in it is computed by the code in this repository, so the text, the tables and the figures can be regenerated and checked.

## Project layout

```
├── README.md  LICENSE  CITATION.cff  Makefile  2026-09 STATE-theory.Rproj
│
├── manuscript/    the paper: text, figures, bibliography, templates and rendered documents   (manuscript/README.md)
├── R/             all code: lib/ (shared), analysis/ (computes), figures/ (draws)            (R/README.md)
├── results/       outputs of the analysis: exact/ and simulation/                           (results/README.md)
└── dist/          upload bundles made by `make submit` (not tracked)
```

The flow is one-directional: `R/analysis/` writes `results/`; `R/figures/` and the manuscript read it; `make` renders `manuscript/` into `manuscript/output/`. Each folder has its own `README.md`.

## Requirements

- R ≥ 4.3 with `data.table`, `ggplot2`, `patchwork`, `ragg` and `knitr` (`pacman` installs them).
- [Quarto](https://quarto.org) (tested with 1.7). Typst, used for the PDF, ships with Quarto, so no LaTeX is needed.
- GNU Make (the version macOS ships is enough). Optional: the scripts also run without it.

`make tools` checks that everything is installed.

## Reproducing the results

Run everything from the repository root.

```bash
make all
```

This computes the exact results and simulations (seeds are fixed), draws the figures, checks the manuscript and renders it. Steps that are already up to date are skipped; `make rebuild` forces every step again (~4 min). `make help` lists all targets:

| To do this | Run |
|---|---|
| Exact calculations and simulations (~2 min) | `make results` |
| Figures 2 and 3 and the graphical abstract | `make figures` |
| Check the manuscript after editing it | `make check` |
| Journal-format manuscript (Word and PDF) | `make journal` |
| Preprint variant (PDF and Word) | `make biorxiv` |
| Collect the files to upload in `dist/` | `make submit` |

Without `make`: `Rscript R/run-all.R` runs the analysis, checks and figures; `quarto render manuscript/index.qmd` (add `--profile biorxiv` for the preprint variant) renders the manuscript.

Figure 1 (`manuscript/figures/source/fig-main.sketch`) and `manuscript/Highlights.docx` are edited by hand and are not rebuilt by `make`.

## How the numbers get into the text

`manuscript/index.qmd` contains no hand-typed result. Every number is read from `results/` through `R/lib/state-numbers.R`. To change one, change the analysis and re-run it; never edit the text. `make check` verifies that cross-references resolve, that every number used is defined, that no result-like number was typed by hand, and that the qualitative statements of the text still hold. See `manuscript/README.md` for details.

## License and citation

- **Code and results** (`R/`, `results/`, `Makefile`) are under the MIT license; see `LICENSE`.
- **Everything in `manuscript/`** (text, figures, highlights, bibliography, templates, rendered documents) is not covered by that license: it remains the authors' and, once the article is published, is subject to the publisher's agreement.
- To cite the repository, use `CITATION.cff`. Cite the article itself once it has a DOI.

## Scope of the example

Systems are hand-specified, time scales are illustrative, and "similar peak" holds only at the pulse amplitude used (Figure 3d).
