# manuscript/ — sources of the paper

Everything here is edited by people or drawn by `R/figures/`; nothing here is a finished file. `make journal` and `make biorxiv` render it (into `_build/`, a scratch folder that git ignores) and copy the finished files to `../submission/`. The first chunk of `index.qmd` makes R evaluate from the repository root, so `R/` and `results/` resolve.

```
manuscript/
├── index.qmd              the manuscript (main text, Appendix A, Appendix B)
├── _quarto.yml            authors, bibliography, Word and PDF formats
├── _quarto-biorxiv.yml    extra settings for the preprint version (--profile biorxiv)
├── references.bib         bibliography
├── Highlights.docx        five highlights for the journal (by hand)
├── Cover_letter.md        cover letter to the editor (by hand; `make journal` turns it into Word)
├── templates/             ref.docx (Word styles), typst-show.typ (PDF title block)
└── figures/
    ├── source/            fig-main.sketch: editable Figure 1 (by hand)
    ├── png/               images embedded in the text (fig-main exported from the sketch; the others drawn by R/figures/)
    └── print/             vector figures for upload: Figure_1.pdf (exported from the sketch), Figure_2.pdf, Figure_3.pdf (R/figures/)
```

When Figure 1 changes, re-export both `png/fig-main.png` and `print/Figure_1.pdf` from the sketch. The competing-interest declaration is generated in the publisher's submission system, not here.

## Two versions from one source

Text that differs is wrapped in `::: {.content-visible when-profile="biorxiv"}` (bioRxiv) or `unless-profile="biorxiv"` (journal) blocks.

| Version | Abstract and introduction |
|---|---|
| Journal (hypothesis paper) | Frames STATE as a testable hypothesis about the organization of autonomic regulation, with formal support |
| bioRxiv | Leads with the original results; states that no empirical data were used |

The project is a plain Quarto project, not `type: manuscript`: Quarto 1.7 fails to render Word output for a manuscript project that contains `content-visible` blocks.

## How the numbers get into the text

`index.qmd` contains no hand-typed result. Every number is an inline expression such as `` `r N$retB` `` (or a chunk, for Table 2), evaluated against `results/` through `R/lib/state-numbers.R`. To change a number, change the analysis and re-run `make results`; never edit the text.

- `make check` (`R/check-manuscript.R`) verifies that each `@sec-`, `@fig-`, `@tbl-`, `@eq-` reference has a label, each `N$key` exists, no result-like number was typed by hand, and the qualitative statements of the text still hold (the ledger is `claims()` in `R/lib/state-numbers.R`).
- Quarto's visual editor drops `{#tbl-…}` labels from table captions and can move equations. Edit tables in source mode; Table 2 is a chunk (`#| label: tbl-ensemble`) so that its label survives.
- A new quantity in the text needs two edits: add it to `V` and `N` in `R/lib/state-numbers.R`, and use `` `r N$key` `` in `index.qmd`.
