# Engine-free: pins the three-way split of assumptions inherited from the
# user-supplied DAG (issue #39). Positivity/overlap is checkable from observed
# data, so it must not be grouped with the untestable assumptions.

read_doc <- function(...) {
  p <- testthat::test_path("..", "..", ...)
  if (!file.exists(p)) {
    p <- system.file(..., package = "drmSEM")
  }
  if (!nzchar(p) || !file.exists(p)) {
    testthat::skip("source docs not available (installed package)")
  }
  readLines(p, warn = FALSE)
}

section_lines <- function(x) {
  start <- grep("^## What drmSEM assumes, and what you can check", x)
  expect_length(start, 1L)
  rest <- x[(start + 1L):length(x)]
  end <- grep("^## ", rest)
  if (length(end)) rest <- rest[seq_len(end[1L] - 1L)]
  rest
}

test_that("overview vignette states the three-way assumption split", {
  sec <- tolower(paste(section_lines(read_doc("vignettes", "drmSEM-overview.Rmd")),
                       collapse = " "))
  for (w in c("untestable", "causal sufficiency", "causal markov",
              "faithfulness", "ignorability", "positivity", "overlap",
              "checkable", "consistency", "no-interference", "definitional",
              "inherits")) {
    expect_true(grepl(w, sec, fixed = TRUE), info = w)
  }
})

test_that("positivity never shares a bullet or sentence with 'untestable'", {
  files <- list(
    read_doc("vignettes", "drmSEM-overview.Rmd"),
    read_doc("docs", "design", "02-effect-calculus.md"),
    read_doc("R", "effects.R")
  )
  for (x in files) {
    expect_gt(length(x), 0L)
    txt <- gsub("^#'\\s?", "", x)
    # paragraphs/bullets: split on blank lines and bullet starts
    blocks <- unlist(strsplit(paste(txt, collapse = "\n"), "\n\\s*\n|\n\\s*[-*] "))
    for (b in blocks) {
      sentences <- unlist(strsplit(b, "(?<=[.!?:;])\\s+", perl = TRUE))
      for (s in sentences) {
        s <- tolower(s)
        both <- grepl("positivity|overlap", s) && grepl("untestable", s)
        # allow the explicit contrast "positivity is not untestable"
        if (both) expect_match(s, "not (among the )?untestable|unlike|rather than")
      }
    }
  }
})

test_that("effects docs and design file carry the split", {
  eff <- tolower(paste(read_doc("R", "effects.R"), collapse = " "))
  expect_match(eff, "positivity")
  design <- tolower(paste(read_doc("docs", "design", "02-effect-calculus.md"),
                          collapse = " "))
  expect_match(design, "positivity")
  expect_match(design, "checkable")
})
