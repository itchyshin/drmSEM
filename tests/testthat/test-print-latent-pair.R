# Engine-free coverage of the print/summary methods for latent constructs,
# indicators, bivariate pairs and higher-level correlation tables, plus the
# internal rho12 declaration helpers in R/pair.R. Objects are built without a
# fitted drmTMB model.

# Capture cli output (message stream) and any stdout from a print method.
capture_print <- function(expr) {
  expr <- substitute(expr)
  env <- parent.frame()
  res <- NULL
  out <- utils::capture.output(
    msg <- cli::cli_fmt(res <- withVisible(eval(expr, env)))
  )
  list(text = paste(c(msg, out), collapse = "\n"), res = res)
}

lat_data <- function(n = 80) {
  set.seed(11)
  eta <- rnorm(n)
  data.frame(
    y1 = eta + rnorm(n, 0, 0.3),
    y2 = 0.8 * eta + rnorm(n, 0, 0.3),
    y3 = 0.6 * eta + rnorm(n, 0, 0.3)
  )
}

# ---- print.drm_indicator ------------------------------------------------------

test_that("print.drm_indicator shows marker and loading tags only when set", {
  p_plain <- capture_print(print(drm_indicator("y1")))
  expect_match(p_plain$text, "<indicator> y1", fixed = TRUE)
  expect_no_match(p_plain$text, "marker")
  expect_no_match(p_plain$text, "loading")

  p_marker <- capture_print(print(drm_indicator("y1", marker = TRUE)))
  expect_match(p_marker$text, "[marker, lambda = 1]", fixed = TRUE)
  expect_no_match(p_marker$text, "loading")

  p_load <- capture_print(print(drm_indicator("y2", loading = 0.81234)))
  expect_match(p_load$text, "(loading = 0.8123)", fixed = TRUE)
  expect_no_match(p_load$text, "marker")

  ind <- drm_indicator("y1", marker = TRUE)
  p <- capture_print(print(ind))
  expect_false(p$res$visible)
  expect_identical(p$res$value, ind)
})

# ---- print.drm_latent / summary.drm_latent -----------------------------------

test_that("print.drm_latent omits optional lines on a bare declaration", {
  lat <- drm_latent("eta", indicators = c("y1", "y2", "y3"), type = "mimic")
  p <- capture_print(print(lat))
  expect_match(p$text, "<latent construct: mimic> eta", fixed = TRUE)
  expect_match(p$text, "(identification: marker)", fixed = TRUE)
  expect_match(p$text, "y1, y2, y3", fixed = TRUE)
  expect_no_match(p$text, "structural causes")
  expect_no_match(p$text, "composite reliability")
  expect_no_match(p$text, "Cronbach")
  expect_no_match(p$text, "score standardized")
  expect_false(p$res$visible)
  expect_identical(p$res$value, lat)
})

test_that("print.drm_latent shows causes, reliabilities and standardization when present", {
  lat <- drm_latent(
    "eta",
    indicators = c("y1", "y2", "y3"),
    causes = c("x1", "x2"),
    type = "mimic",
    data = lat_data(),
    standardize = TRUE
  )
  p <- capture_print(print(lat))
  expect_match(p$text, "structural causes: x1, x2", fixed = TRUE)
  expect_match(p$text, "composite reliability (Raykov's rho):", fixed = TRUE)
  expect_match(p$text, "Cronbach's alpha:", fixed = TRUE)
  expect_match(p$text, "score standardized (mean 0, sd 1)", fixed = TRUE)
  expect_identical(p$res$value, lat)
})

test_that("summary.drm_latent prints the loadings table only when loadings exist", {
  bare <- drm_latent("eta", indicators = c("y1", "y2", "y3"), causes = "x1")
  s0 <- capture_print(summary(bare))
  expect_match(s0$text, "Structural causes: x1", fixed = TRUE)
  expect_no_match(s0$text, "loading")
  expect_no_match(s0$text, "Composite reliability")
  expect_no_match(s0$text, "Reliability (Cronbach", fixed = TRUE)
  expect_false(s0$res$visible)
  expect_identical(s0$res$value, bare)

  fit <- drm_latent("eta", indicators = c("y1", "y2", "y3"), data = lat_data())
  s1 <- capture_print(summary(fit))
  expect_no_match(s1$text, "Structural causes")
  expect_match(s1$text, "indicator", fixed = TRUE)
  expect_match(s1$text, "std_loading", fixed = TRUE)
  expect_match(s1$text, "Composite reliability (Raykov's rho):", fixed = TRUE)
  expect_match(s1$text, "Reliability (Cronbach's alpha):", fixed = TRUE)

  # std_loading column is dropped when std_loadings is absent
  fit$std_loadings <- NULL
  s2 <- capture_print(summary(fit))
  expect_match(s2$text, "loading", fixed = TRUE)
  expect_no_match(s2$text, "std_loading")
})

# ---- print.drm_pair -----------------------------------------------------------

test_that("print.drm_pair distinguishes constant rho12 from a directed path", {
  pair_const <- drm_pair(activity ~ x, boldness ~ x)
  pc <- capture_print(print(pair_const))
  expect_match(pc$text, "bivariate node", fixed = TRUE)
  expect_match(pc$text, "rho12(activity, boldness) [constant]", fixed = TRUE)
  expect_no_match(pc$text, "directed path into rho12")
  expect_no_match(pc$text, "higher-level correlation")
  expect_match(pc$text, "declaration only", fixed = TRUE)
  # print.drm_pair ends on invisible(x), so the pair is returned invisibly
  expect_false(pc$res$visible)
  expect_identical(pc$res$value, pair_const)

  pair_dir <- drm_pair(activity ~ x, boldness ~ x, rho12 = ~x)
  pd <- capture_print(print(pair_dir))
  expect_match(pd$text, "rho12 ~ x [directed path into rho12]", fixed = TRUE)
  expect_no_match(pd$text, "[constant]", fixed = TRUE)
})

test_that("print.drm_pair reports the higher-level correlation line only with levels", {
  pair <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id))
  p <- capture_print(print(pair))
  expect_match(p$text, "higher-level correlation: corpair at 1 level", fixed = TRUE)
  expect_match(p$text, "id", fixed = TRUE)

  none <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id), level = NA)
  pn <- capture_print(print(none))
  expect_no_match(pn$text, "higher-level correlation")
})

# ---- print.drm_corpairs -------------------------------------------------------

test_that("print.drm_corpairs handles the zero-row and n-edge branches", {
  empty <- structure(
    data.frame(level = character(0), estimate = numeric(0)),
    class = c("drm_corpairs", "data.frame")
  )
  pe <- capture_print(print(empty))
  expect_match(pe$text, "<higher-level correlation (corpair): none>", fixed = TRUE)
  expect_false(pe$res$visible)
  expect_identical(pe$res$value, empty)

  one <- structure(
    data.frame(level = "id", estimate = 0.42, stringsAsFactors = FALSE),
    class = c("drm_corpairs", "data.frame")
  )
  p1 <- capture_print(print(one))
  expect_match(p1$text, "1 edge>", fixed = TRUE)
  expect_match(p1$text, "0.42", fixed = TRUE)
  expect_no_match(p1$text, "NOTE-MARKER")

  two <- structure(
    data.frame(level = c("id", "site"), estimate = c(0.1, 0.2), stringsAsFactors = FALSE),
    class = c("drm_corpairs", "data.frame"),
    note = "NOTE-MARKER grey note"
  )
  p2 <- capture_print(print(two))
  expect_match(p2$text, "2 edges>", fixed = TRUE)
  expect_match(p2$text, "NOTE-MARKER grey note", fixed = TRUE)
  expect_false(p2$res$visible)
  expect_identical(p2$res$value, two)
})

# ---- rho12 declaration helpers ------------------------------------------------

test_that("drm_rho12_empty returns a zero-row table with the rho12 columns", {
  e <- drmSEM:::drm_rho12_empty()
  expect_s3_class(e, "data.frame")
  expect_identical(nrow(e), 0L)
  expect_identical(
    names(e),
    c(
      "y1", "y2", "term", "estimate", "std.error", "statistic", "p.value",
      "link", "predictors", "constant"
    )
  )
  expect_type(e$estimate, "double")
  expect_type(e$constant, "logical")
})

test_that("drm_rho12_declared_row builds one NA-estimate tanh-link row", {
  r <- drmSEM:::drm_rho12_declared_row("a", "b", predictors = "x + z", constant = FALSE)
  expect_identical(nrow(r), 1L)
  expect_identical(r$y1, "a")
  expect_identical(r$y2, "b")
  expect_identical(r$link, "tanh")
  expect_identical(r$predictors, "x + z")
  expect_false(r$constant)
  expect_true(all(is.na(r[c("term", "estimate", "std.error", "statistic", "p.value")])))
  expect_identical(names(r), names(drmSEM:::drm_rho12_empty()))

  rc <- drmSEM:::drm_rho12_declared_row("a", "b", predictors = "", constant = TRUE)
  expect_true(rc$constant)
})

test_that("drm_rho12_note distinguishes declaration-only from fitted tables", {
  decl <- drmSEM:::drm_rho12_note()
  expect_identical(decl, drmSEM:::drm_rho12_note(fitted = FALSE))
  expect_match(decl, "estimate NA: declaration only", fixed = TRUE)

  fit <- drmSEM:::drm_rho12_note(fitted = TRUE)
  expect_match(fit, "tanh (atanh_guarded) link", fixed = TRUE)
  expect_match(fit, "not a y1 -> y2 path", fixed = TRUE)
  expect_false(identical(decl, fit))
  # only a literal TRUE selects the fitted note
  expect_identical(drmSEM:::drm_rho12_note(fitted = NA), decl)
})
