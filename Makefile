# ==============================================================================
# STATE paper -- rebuild everything that can be rebuilt.   Run `make help`.
#
#   results/    <- R/analysis/*.R           (exact calculations, Monte Carlo, simulations)
#   figures     <- R/figures/*.R            (Figures 2 and 3, graphical abstract)
#   manuscripts <- quarto render            (journal Word + PDF, bioRxiv PDF)
#   dist/       <- upload bundles           (one folder per destination)
#
# Not rebuilt by code: Figure 1 (manuscript/figures/source/fig-main.sketch -> manuscript/figures/png/fig-main.png
# and manuscript/figures/print/Figure_1.pdf) and manuscript/Highlights.docx. They are edited by hand.
# Works with GNU Make 3.81 (the version macOS ships) and later.
# ==============================================================================

RSCRIPT ?= Rscript
QUARTO  ?= quarto

LIB      := $(wildcard R/lib/*.R)
ANALYSIS := R/analysis/state-analytic.R R/analysis/state-validate.R R/analysis/state-sim.R
FIGSCRPT := R/figures/fig-state-sim.R R/figures/fig-graphical-abstract.R
MS_FILES := manuscript/index.qmd manuscript/_quarto.yml manuscript/references.bib manuscript/templates/ref.docx manuscript/templates/typst-show.typ \
            manuscript/figures/png/fig-main.png manuscript/figures/png/fig-illustration.png manuscript/figures/png/fig-robustness.png

# stamp files record that a step ran (they live in .build/, which git ignores)
B := .build

.DEFAULT_GOAL := help
.PHONY: help all results figures check journal biorxiv submit submit-journal submit-biorxiv \
        rebuild clean distclean tools

help:  ## list the targets
	@echo "STATE paper -- targets:"
	@echo "  make all             results, figures, checks, and both manuscripts (skips steps that are up to date)"
	@echo "  make results         exact calculations and simulations         -> results/            (~2 min)"
	@echo "  make figures         Figures 2-3 and graphical abstract         -> manuscript/figures"
	@echo "  make check           consistency checks on manuscript/index.qmd"
	@echo "  make journal         journal manuscript (Word + PDF)            -> manuscript/output/journal/"
	@echo "  make biorxiv         bioRxiv variant (PDF + Word)               -> manuscript/output/biorxiv/"
	@echo "  make submit-journal  upload bundle for the journal                -> dist/journal/"
	@echo "  make submit-biorxiv  upload bundle for bioRxiv                    -> dist/biorxiv/"
	@echo "  make rebuild         run every step again (about 4 min)"
	@echo "  make clean           remove build stamps, upload bundles and the Quarto cache"
	@echo "  make distclean       also delete generated results, figures and rendered manuscripts"
	@echo "  make tools           check that R, Quarto and the R packages are installed"

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

# ---- figures -------------------------------------------------------------------------------------------
figures: $(B)/figures.stamp $(B)/abstract.stamp  ## Figures 2-3 and graphical abstract

$(B)/figures.stamp: R/figures/fig-state-sim.R $(LIB) $(B)/analytic.stamp $(B)/validate.stamp $(B)/simulation.stamp
	$(RSCRIPT) R/figures/fig-state-sim.R
	@touch $@

$(B)/abstract.stamp: R/figures/fig-graphical-abstract.R $(LIB) $(B)/simulation.stamp
	$(RSCRIPT) R/figures/fig-graphical-abstract.R
	@touch $@

# ---- checks and manuscripts ------------------------------------------------------------------------
check:  ## labels, N$ keys, hand-typed numbers, claims ledger
	$(RSCRIPT) R/check-manuscript.R

# These always render (about 30 s each) from whatever is in results/ and manuscript/figures/.
journal: $(MS_FILES)  ## journal version: Perspective abstract and introduction
	$(QUARTO) render manuscript/index.qmd
	@test -f manuscript/output/journal/index.docx && test -f manuscript/output/journal/index.pdf && echo "-> manuscript/output/journal/index.docx, index.pdf"

biorxiv: $(MS_FILES) manuscript/_quarto-biorxiv.yml  ## bioRxiv version: results-first abstract and introduction
	$(QUARTO) render manuscript/index.qmd --profile biorxiv
	@test -f manuscript/output/biorxiv/index.pdf && echo "-> manuscript/output/biorxiv/index.pdf, index.docx"

# ---- upload bundles --------------------------------------------------------------------------------
submit: submit-journal submit-biorxiv  ## both bundles

submit-journal: journal  ## dist/journal: everything the journal asks for, under upload names
	@for f in manuscript/Highlights.docx manuscript/figures/print/Figure_1.pdf manuscript/figures/print/Figure_2.pdf manuscript/figures/print/Figure_3.pdf manuscript/figures/print/Graphical_abstract.tiff; do \
	  test -f $$f || { echo "missing $$f"; exit 1; }; done
	@rm -rf dist/journal && mkdir -p dist/journal
	@cp manuscript/output/journal/index.docx dist/journal/Manuscript.docx
	@cp manuscript/Highlights.docx manuscript/figures/print/Figure_1.pdf manuscript/figures/print/Figure_2.pdf manuscript/figures/print/Figure_3.pdf \
	   manuscript/figures/print/Graphical_abstract.tiff dist/journal/
	@echo "-> dist/journal/"; ls -1 dist/journal

submit-biorxiv: biorxiv  ## dist/biorxiv: the preprint file
	@rm -rf dist/biorxiv && mkdir -p dist/biorxiv
	@cp manuscript/output/biorxiv/index.pdf dist/biorxiv/Manuscript.pdf
	@echo "-> dist/biorxiv/"; ls -1 dist/biorxiv

# ---- housekeeping ----------------------------------------------------------------------------------
rebuild:  ## forget what was built and run every step again
	rm -rf $(B) dist
	$(MAKE) all

clean:  ## build stamps, upload bundles and the Quarto cache (nothing tracked by git)
	rm -rf $(B) dist manuscript/.quarto

distclean: clean  ## also delete the generated results, figures and rendered manuscripts (`make all` brings them back)
	rm -rf manuscript/output
	rm -rf results/exact results/simulation results/sessionInfo.txt results/claims_check.csv
	rm -f manuscript/figures/png/fig-illustration.png manuscript/figures/png/fig-robustness.png
	rm -f manuscript/figures/print/Figure_2.pdf manuscript/figures/print/Figure_3.pdf manuscript/figures/print/Graphical_abstract.tiff
