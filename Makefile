# ==============================================================================
# STATE paper -- rebuild everything that can be rebuilt.   Run `make help`.
#
#   results/              <- R/analysis/*.R   exact calculations, Monte Carlo, simulations
#   manuscript/figures/   <- R/figures/*.R    Figures 2 and 3 (PNG for the text, PDF for upload)
#   submission/journal/   <- make journal     everything to upload to the journal
#   submission/biorxiv/   <- make biorxiv     the preprint PDF
#
# Edited by hand, not rebuilt: Figure 1 (manuscript/figures/source/fig-main.sketch, exported to
# manuscript/figures/png/fig-main.png and manuscript/figures/print/Figure_1.pdf),
# manuscript/Highlights.docx and manuscript/Cover_letter.md.
# Quarto renders into manuscript/_build/ (scratch, not tracked); only submission/ is the output.
# Works with GNU Make 3.81 (the version macOS ships) and later.
# ==============================================================================

RSCRIPT ?= Rscript
QUARTO  ?= quarto

LIB := $(wildcard R/lib/*.R)
J   := submission/journal
P   := submission/biorxiv

# stamp files record that a step ran (they live in .build/, which git ignores)
B := .build

.DEFAULT_GOAL := help
.PHONY: help all tools results figures check journal biorxiv rebuild clean

help:  ## list the targets
	@echo "STATE paper -- targets:"
	@echo "  make all       results, figures, checks and both submissions (skips steps that are up to date)"
	@echo "  make results   exact calculations and simulations  -> results/              (~2 min)"
	@echo "  make figures   Figures 2 and 3                     -> manuscript/figures/"
	@echo "  make check     consistency checks on manuscript/index.qmd"
	@echo "  make journal   manuscript, cover letter, highlights, figures -> submission/journal/"
	@echo "  make biorxiv   preprint PDF                        -> submission/biorxiv/"
	@echo "  make rebuild   run every step again (about 4 min)"
	@echo "  make clean     remove build stamps and Quarto scratch files"
	@echo "  make tools     check that R, Quarto and the R packages are installed"

all: tools results figures check journal biorxiv  ## everything

tools:  ## R, Quarto and the R packages
	@command -v $(RSCRIPT) >/dev/null || { echo "Rscript not found (R >= 4.3 is required)"; exit 1; }
	@command -v $(QUARTO)  >/dev/null || { echo "quarto not found"; exit 1; }
	@$(RSCRIPT) -e 'miss <- setdiff(c("data.table","ggplot2","patchwork","ragg","knitr","systemfonts"), rownames(installed.packages())); if (length(miss)) { cat("Missing R packages:", miss, "\n"); quit(status = 1) }'

# ---- results ---------------------------------------------------------------------------------------
results: $(B)/analytic.stamp $(B)/validate.stamp $(B)/simulation.stamp  ## exact calculations + simulations

$(B)/analytic.stamp: R/analysis/state-analytic.R $(LIB)
	@mkdir -p $(B)
	$(RSCRIPT) R/analysis/state-analytic.R
	@touch $@

$(B)/validate.stamp: R/analysis/state-validate.R $(LIB) $(B)/analytic.stamp
	$(RSCRIPT) R/analysis/state-validate.R
	@touch $@

$(B)/simulation.stamp: R/analysis/state-sim.R $(LIB) $(B)/analytic.stamp
	$(RSCRIPT) R/analysis/state-sim.R
	@touch $@

# ---- figures ---------------------------------------------------------------------------------------
figures: $(B)/figures.stamp  ## Figures 2 and 3

$(B)/figures.stamp: R/figures/fig-state-sim.R $(LIB) $(B)/analytic.stamp $(B)/validate.stamp $(B)/simulation.stamp
	$(RSCRIPT) R/figures/fig-state-sim.R
	@touch $@

# ---- checks and submissions ------------------------------------------------------------------------
check:  ## labels, N$ keys, hand-typed numbers, claims ledger
	$(RSCRIPT) R/check-manuscript.R

# These always render (about 30 s each) from whatever is in results/ and manuscript/.
journal:  ## render the journal version and collect the upload files under their upload names
	$(QUARTO) render manuscript/index.qmd
	@rm -rf $(J) && mkdir -p $(J)
	@cp manuscript/_build/journal/index.docx $(J)/Manuscript.docx
	@cp manuscript/_build/journal/index.pdf  $(J)/Manuscript.pdf
	@$(QUARTO) pandoc manuscript/Cover_letter.md --reference-doc manuscript/templates/ref.docx -o $(J)/Cover_letter.docx
	@cp manuscript/Highlights.docx manuscript/figures/print/Figure_1.pdf manuscript/figures/print/Figure_2.pdf manuscript/figures/print/Figure_3.pdf $(J)/
	@echo "-> $(J)/"; ls -1 $(J)

biorxiv:  ## render the preprint version (results-first abstract and introduction)
	$(QUARTO) render manuscript/index.qmd --profile biorxiv --to typst
	@rm -rf $(P) && mkdir -p $(P)
	@cp manuscript/_build/biorxiv/index.pdf $(P)/Manuscript.pdf
	@echo "-> $(P)/"; ls -1 $(P)

# ---- housekeeping ----------------------------------------------------------------------------------
rebuild:  ## forget what was built and run every step again
	rm -rf $(B)
	$(MAKE) all

clean:  ## build stamps and Quarto scratch files (nothing tracked by git)
	rm -rf $(B) manuscript/_build manuscript/.quarto
