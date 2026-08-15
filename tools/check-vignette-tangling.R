#!/usr/bin/env Rscript
# Guard: no vignette may emit engine-calling code when TANGLED.
#
# Why this exists as a script rather than an R CMD check flag.
#
# `R CMD check`'s "checking running R code from vignettes" step tangles every
# vignette and RUNS the extracted code. Six vignettes were failing it, because
# `knitr:::tangle_block` never executes chunks -- so `opts_chunk$set(eval = has_engine)`
# in a setup chunk has not run when purl decides what to emit, and any chunk whose
# OWN header lacks `eval` inherits the default TRUE and is emitted.
#
# That step is skipped whenever check re-builds the vignettes, which CI does. The
# documented lever is `_R_CHECK_VIGNETTES_SKIP_RUN_MAYBE_=false`. It was tried, it is
# demonstrably set in the CI environment, and the step STILL did not appear in the
# check output on any of the three platforms. Rather than ship a guard that cannot be
# shown to fire, the property is asserted directly here.
#
# Run: Rscript tools/check-vignette-tangling.R
# Exits 1 and names the offenders if any vignette tangles to engine-calling code.

suppressPackageStartupMessages(library(knitr))

# Calls that mean "this chunk drives the fitting engine". Deliberately a small,
# explicit list: a broad regex would catch prose and give false confidence.
ENGINE_CALLS <- c(
  "drm_sem", "drm_psem", "drm_node", "drmTMB",
  "paths", "dsep", "fisher_c", "basis_set",
  "direct_effects", "indirect_effects", "total_effects", "path_effects",
  "standardize", "compare", "best", "average", "check_sem", "symbolize"
)
pattern <- paste0("\\b(", paste(ENGINE_CALLS, collapse = "|"), ")\\s*\\(")

files <- sort(Sys.glob(file.path("vignettes", "*.Rmd")))
if (!length(files)) {
  cat("no vignettes found -- nothing to check\n")
  quit(status = 0)
}

offenders <- list()
for (f in files) {
  out <- tempfile(fileext = ".R")
  # knitr prints "object 'has_engine' not found" to stderr for every chunk it
  # correctly DROPS -- that is the mechanism working, not a problem. Left as-is;
  # the caller can redirect stderr. (An earlier attempt to muffle it with
  # capture.output swallowed purl's side effect and produced no file at all --
  # cleverness that broke the guard is worse than noise.)
  ok <- tryCatch(
    {
      knitr::purl(f, output = out, quiet = TRUE, documentation = 0)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!ok) {
    offenders[[basename(f)]] <- "purl() failed"
    next
  }
  code <- readLines(out, warn = FALSE)
  # Drop blanks and comments: purl comments out `eval = FALSE` chunks, and a
  # commented engine call is exactly what we WANT to see.
  live <- code[nzchar(trimws(code)) & !grepl("^[[:space:]]*#", code)]
  hits <- grep(pattern, live, value = TRUE)
  if (length(hits)) {
    offenders[[basename(f)]] <- hits
  }
}

if (!length(offenders)) {
  cat(sprintf("OK: all %d vignettes tangle to engine-free code\n", length(files)))
  quit(status = 0)
}

cat("FAIL: these vignettes tangle to code that calls the engine.\n")
cat("Every chunk needs an EXPLICIT `eval =` in its own header -- a setup-chunk\n")
cat("opts_chunk$set() does not apply at tangle time.\n\n")
for (nm in names(offenders)) {
  cat("  ", nm, "\n", sep = "")
  for (h in utils::head(offenders[[nm]], 3)) {
    cat("      ", trimws(h), "\n", sep = "")
  }
}
quit(status = 1)
