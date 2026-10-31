# ==============================================================================
# STATE -- consistency checks for manuscript/index.qmd (run after every editing session)
#   1. every @sec-/@fig-/@tbl-/@eq- reference has a label
#      (Quarto's visual editor can drop `{#tbl-...}` labels from table captions)
#   2. every `r N$key` used in the text exists in R/lib/state-numbers.R
#   3. no result-like number is typed by hand in the abstract, the illustration or the Discussion
#   4. the qualitative claims of the text still hold (claims ledger)
# Usage: Rscript R/check-manuscript.R      (exit status 1 if 1 or 2 fail)
# ==============================================================================
qmd <- paste(readLines("manuscript/index.qmd", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
hits <- function(pat, x = qmd) { m <- gregexpr(pat, x, perl = TRUE)[[1]]; if (m[1] == -1) character(0) else regmatches(x, list(m))[[1]] }
fail <- 0L; ok <- function(msg) cat("  ok     ", msg, "\n"); bad <- function(msg) { cat("  FAIL   ", msg, "\n"); fail <<- fail + 1L }

cat("1. cross-references\n")
refs   <- unique(sub("^@", "", hits("@(?:sec|fig|tbl|eq)-[A-Za-z0-9-]+")))
labels <- unique(c(sub("^\\{#", "", hits("\\{#(?:sec|fig|tbl|eq)-[A-Za-z0-9-]+")), sub("^#\\| label: ", "", hits("#\\| label: (?:fig|tbl)-[A-Za-z0-9-]+"))))
miss <- setdiff(refs, labels)
if (length(miss)) bad(paste("referenced but not labelled:", paste(miss, collapse = ", "))) else ok(sprintf("%d references, all labelled", length(refs)))

cat("2. manuscript numbers (N$key)\n")
suppressMessages(source("R/lib/state-numbers.R"))
keys <- unique(sub("^N\\$", "", hits("N\\$[A-Za-z0-9_]+"))); unknown <- setdiff(keys, names(unclass(N)))
if (length(unknown)) bad(paste("unknown keys:", paste(unknown, collapse = ", "))) else ok(sprintf("%d keys used, all defined (%d available)", length(keys), length(unclass(N))))

cat("3. numbers typed by hand in result-bearing text (review list)\n")
section <- function(from, to) { i <- regexpr(from, qmd, fixed = TRUE); j <- regexpr(to, qmd, fixed = TRUE); substr(qmd, i, j - 1) }
body <- paste(section("**Abstract**", "**Keywords:**"), section("# Introduction", "# CRediT"), sep = "\n")      # abstract + whole article
clean <- gsub("(?s)```\\{r\\}.*?```", " ", body, perl = TRUE)         # chunks
clean <- gsub("`r [^`]*`", " ", clean, perl = TRUE)                   # inline R code
clean <- gsub("(?s)\\$\\$.*?\\$\\$", " ", clean, perl = TRUE); clean <- gsub("(?s)\\$[^$]*\\$", " ", clean, perl = TRUE)   # math
clean <- gsub("\\[@[^]]*\\]|@[A-Za-z0-9-]+|\\{#[^}]*\\}|^#.*$", " ", clean, perl = TRUE)
# phrases whose numbers are conventions or labels, not results (whitelisted as phrases, never as bare digits)
allowed_phrases <- c("2\\.5th", "97\\.5th", "90%", "95%", "0\\.5 for no separation", "0\\.5 indicates no separation", "5-minute recording",
                     "Postulates? [0-9](?:, [0-9], and [0-9])?", "Propositions? [0-9]", "Section [0-9]+", "N-of-1", "0\\.5 = none")
for (ph in allowed_phrases) clean <- gsub(ph, " ", clean, perl = TRUE)
left <- unique(hits("(?<![A-Za-z_.])[0-9]+(?:\\.[0-9]+)?(?:%|st|nd|rd|th)?", clean))
if (length(left)) cat("  review ", paste(left, collapse = "  "), "\n         (typed by hand: replace with `r N$...` if it comes from a result)\n") else ok("none")

cat("4. qualitative claims\n"); cl <- check_claims(); nb <- sum(!cl$ok)
if (nb) cat("  review ", nb, "claim(s) no longer supported -- see warning above\n") else ok(sprintf("%d claims hold", nrow(cl)))
if (fail) quit(status = 1)
