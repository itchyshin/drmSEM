# Terminology guard for reader-facing text.
#
# WHY THIS EXISTS (2026-08-09). Darwin's review of the README variance figure
# flagged "bet-hedging" as a mislabel: in bet-hedging theory variance is
# adaptive, while that example has a constant environment where variance is
# purely a cost, so the term predicts the opposite of what the figure shows. The
# warning was recorded in the render script's header comment -- and then the
# label was used anyway, on the live pkgdown site.
#
# The failure was not missing knowledge. The correct analysis existed, in the
# right file, before the artifact shipped. What was missing was anything that
# MEASURED the artifact against it. A written lesson is not an applied lesson;
# it only binds where something checks it. So this is a checker, not a doctrine
# note: it runs on every `devtools::test()` and in CI, and it fails loudly.
#
# TO ADD A TERM: append a row to docs/memory/FLAGGED-TERMS.tsv. That file is the
# single source of truth; this test is only the mechanism.
#
# SCOPE: reader-facing prose (README, vignettes) and the *code* lines of the
# render scripts -- comments in tools/*.R are exempt, so a script may explain
# why a term is banned without tripping its own guard.

flagged_terms_path <- function() {
  testthat::test_path("..", "..", "docs", "memory", "FLAGGED-TERMS.tsv")
}

# Comment lines in R scripts are exempt: they are where the ban is explained.
drop_r_comments <- function(lines) {
  lines[!grepl("^\\s*#", lines)]
}

test_that("no flagged term appears in reader-facing text", {
  tsv <- flagged_terms_path()
  skip_if_not(file.exists(tsv), "FLAGGED-TERMS.tsv not found")

  flagged <- utils::read.delim(tsv, stringsAsFactors = FALSE)
  skip_if(nrow(flagged) == 0L, "no terms flagged")

  root <- testthat::test_path("..", "..")
  prose <- c(
    file.path(root, "README.md"),
    list.files(file.path(root, "vignettes"), pattern = "\\.Rmd$", full.names = TRUE)
  )
  scripts <- list.files(file.path(root, "tools"), pattern = "\\.R$", full.names = TRUE)

  hits <- character(0)
  for (f in c(prose, scripts)) {
    if (!file.exists(f)) next
    lines <- readLines(f, warn = FALSE)
    if (f %in% scripts) {
      lines <- drop_r_comments(lines)
    }
    for (i in seq_len(nrow(flagged))) {
      term <- flagged$term[[i]]
      where <- grep(term, lines, ignore.case = TRUE, fixed = FALSE)
      if (length(where)) {
        hits <- c(hits, sprintf(
          "%s: '%s' on %d line(s)\n    why: %s\n    raised by %s (%s)",
          basename(f), term, length(where),
          flagged$why[[i]], flagged$raised_by[[i]], flagged$date[[i]]
        ))
      }
    }
  }

  expect_equal(
    hits, character(0),
    info = paste0(
      "A term flagged by a reviewer has reappeared in reader-facing text.\n",
      "This guard exists because exactly that happened on the live site once.\n",
      "Either remove the term, or -- if the usage is genuinely correct -- delete\n",
      "its row from docs/memory/FLAGGED-TERMS.tsv with a reason in the commit.\n\n",
      paste(hits, collapse = "\n  ")
    )
  )
})

test_that("the flagged-terms file itself stays well formed", {
  tsv <- flagged_terms_path()
  skip_if_not(file.exists(tsv), "FLAGGED-TERMS.tsv not found")
  flagged <- utils::read.delim(tsv, stringsAsFactors = FALSE)

  # A bare term with no reason is how a guard rots into folklore: the next
  # reader cannot tell whether it still applies.
  expect_true(all(c("term", "why", "raised_by", "date") %in% names(flagged)))
  expect_true(all(nzchar(flagged$term)))
  expect_true(all(nchar(flagged$why) > 20L))
  expect_true(all(nzchar(flagged$raised_by)))
})
