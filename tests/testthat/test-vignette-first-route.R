# First-route reader check for vignettes/drmSEM.Rmd (TRANSFERS X-002).
#
# drmTMB is on CRAN, so the vignette that a new user reads first should run its
# fitting chunks whenever the engine is installed, not hard-code them off.

vignette_path <- function() {
  testthat::test_path("..", "..", "vignettes", "drmSEM.Rmd")
}

test_that("drmSEM.Rmd gates its fitting chunks on drmTMB being installed", {
  path <- vignette_path()
  skip_if_not(file.exists(path), "vignette source not available")
  lines <- readLines(path, warn = FALSE)

  expect_false(any(grepl("^has_engine <- FALSE\\s*$", lines)))
  expect_true(any(grepl(
    "^has_engine <- requireNamespace\\(\"drmTMB\", quietly = TRUE\\)\\s*$",
    lines
  )))
})

test_that("drmSEM.Rmd simulate + build chunks run on the first route", {
  skip_on_cran()
  skip_if_not_installed("drmTMB")
  path <- vignette_path()
  skip_if_not(file.exists(path), "vignette source not available")

  lines <- readLines(path, warn = FALSE)
  opens <- grep("^```\\{r ", lines)
  closes <- grep("^```\\s*$", lines)
  labels <- sub("^```\\{r ([^,}]+).*$", "\\1", lines[opens])
  chunk <- function(label) {
    i <- match(label, labels)
    stopifnot(!is.na(i))
    end <- closes[closes > opens[i]][1]
    lines[(opens[i] + 1L):(end - 1L)]
  }

  env <- new.env(parent = globalenv())
  env$has_engine <- TRUE
  eval(parse(text = chunk("simulate")), envir = env)
  eval(parse(text = chunk("build")), envir = env)
  expect_s3_class(env$sem, "drm_sem")
})
