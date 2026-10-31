# manuscript/ — text, figures and rendered documents

Quarto project. Render it from the repository root with `make journal` / `make biorxiv` (or `quarto render manuscript/index.qmd [--profile biorxiv]`). The first chunk of `index.qmd` makes R evaluate from the repository root, so `R/` and `results/` resolve.

```
manuscript/
├── index.qmd              the manuscript (main text, Appendix A, Appendix B)
├── _quarto.yml            authors, bibliography, formats; journal output goes to output/journal/
├── _quarto-biorxiv.yml    extra settings for --profile biorxiv; output goes to output/biorxiv/
├── references.bib         bibliography
├── Highlights.docx        five highlights for the journal (by hand)
├── templates/             ref.docx (Word styles), typst-show.typ (PDF title block)
├── figures/
│   ├── source/            fig-main.sketch: editable Figure 1 (by hand)
│   ├── png/               images embedded in the text (fig-main from the sketch; fig-illustration, fig-robustness from R/figures/)
│   └── print/             files uploaded to the journal: Figure_1.pdf (by hand), Figure_2.pdf, Figure_3.pdf, Graphical_abstract.tiff (from R/figures/)
└── output/                rendered documents (only those listed below are tracked)
    ├── journal/           index.docx (upload to the journal), index.pdf (PDF version)
    └── biorxiv/           index.pdf (bioRxiv)
```

Edited by hand, not rebuilt by `make`: Figure 1 (re-export `png/fig-main.png` and `print/Figure_1.pdf` from the sketch) and `Highlights.docx`. The cover letter and the competing-interest form are prepared outside this repository.

## Two versions from one source

Text that differs is wrapped in `::: {.content-visible when-profile="biorxiv"}` (bioRxiv) or `unless-profile="biorxiv"` (journal) blocks.

| Version | Abstract and introduction |
|---|---|
| Journal (Perspective) | Frames the work as a viewpoint with formal support |
| bioRxiv | Leads with the original results; states that no empirical data were used |

The project is a plain Quarto project, not `type: manuscript`: Quarto 1.7 fails to render Word output for a manuscript project that contains `content-visible` blocks.

## How the numbers get into the text

`index.qmd` contains no hand-typed result. Every number is an inline expression such as `` `r N$retB` `` (or a chunk, for Table 2), evaluated against `results/` through `R/lib/state-numbers.R`. To change a number, change the analysis and re-run `make results`; never edit the text.

- `make check` (`R/check-manuscript.R`) verifies that each `@sec-`, `@fig-`, `@tbl-`, `@eq-` reference has a label, each `N$key` exists, no result-like number was typed by hand, and the qualitative statements of the text still hold (the ledger is `claims()` in `R/lib/state-numbers.R`).
- Quarto's visual editor drops `{#tbl-…}` labels from table captions and can move equations. Edit tables in source mode; Table 2 is a chunk (`#| label: tbl-ensemble`) so that its label survives.
- A new quantity in the text needs two edits: add it to `V` and `N` in `R/lib/state-numbers.R`, and use `` `r N$key` `` in `index.qmd`.
