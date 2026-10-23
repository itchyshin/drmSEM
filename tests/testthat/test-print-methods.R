# Engine-free tests for S3 print/summary methods: each returns its argument
# invisibly, shows its key tokens, and survives empty / edge inputs. The cli
# text goes to the message stream and print.data.frame() to stdout, so both are
# captured together.

show <- function(expr) {
  expr <- substitute(expr)
  env <- parent.frame()
  msgs <- character()
  out <- utils::capture.output(
    msgs <- testthat::capture_messages(eval(expr, env))
  )
  paste(c(msgs, out), collapse = "\n")
}

dat_pm <- data.frame(
  i1 = c(1, 2, 3, 4, 5, 6),
  i2 = c(2, 1, 4, 3, 6, 5),
  i3 = c(0, 1, 0, 1, 0, 1)
)

# ---- feedback motifs ---------------------------------------------------------

test_that("print.drm_cycle shows the motif and returns invisibly", {
  local_reproducible_output()
  cy <- drm_cycle("activity", "boldness")
  expect_invisible(print(cy))
  expect_identical(suppressMessages(print(cy)), cy)
  expect_match(show(print(cy)), "feedback motif.*activity <-> boldness")
  expect_match(show(print(drm_cycle("a", "b", "c"))), "a <-> b <-> c")
})

test_that("print.drm_cycles handles the empty and populated tables", {
  local_reproducible_output()
  empty <- structure(
    data.frame(motif = integer(0), node = character(0)),
    class = c("drm_cycles", "data.frame")
  )
  expect_invisible(print(empty))
  expect_match(show(print(empty)), "feedback motifs: none")

  tab <- structure(
    data.frame(motif = c(1L, 1L, 2L, 2L), node = c("a", "b", "c", "d")),
    class = c("drm_cycles", "data.frame")
  )
  expect_invisible(print(tab))
  res <- show(print(tab))
  expect_match(res, "feedback motifs: 2")
  expect_match(res, "motif 1: a <-> b")
  expect_match(res, "motif 2: c <-> d")
})

# ---- covariance edges --------------------------------------------------------

test_that("print.drm_covary labels residual and higher-level edges", {
  local_reproducible_output()
  res <- covary("y1", "y2")
  expect_invisible(print(res))
  expect_match(show(print(res)), "rho12\\(y1, y2\\).*\\[residual\\]")

  hi <- covary("y1", "y2", level = "site")
  expect_invisible(print(hi))
  expect_match(
    show(print(hi)),
    "corpair\\(site: y1, y2\\).*\\[higher-level\\]"
  )
})

# ---- composite constructs ----------------------------------------------------

test_that("print/summary.drm_composite show construct, loadings, reliability", {
  local_reproducible_output()
  cp <- drm_composite("C", c("i1", "i2", "i3"), method = "pca",
                      data = dat_pm, standardize = TRUE)
  expect_invisible(print(cp))
  res <- show(print(cp))
  expect_match(res, "composite construct.*C = pca\\(i1, i2, i3\\)")
  expect_match(res, "first-PC proportion of variance")
  expect_match(res, "Cronbach's alpha")
  expect_match(res, "standardized")

  expect_invisible(summary(cp))
  sm <- show(summary(cp))
  expect_match(sm, "composite construct.*C.*pca")
  expect_match(sm, "indicator\\s+loading")
  expect_match(sm, "i1")
  expect_match(sm, "Reliability \\(Cronbach's alpha\\)")
})

test_that("print.drm_composite omits absent diagnostics", {
  local_reproducible_output()
  cp <- drm_composite("C", c("i1", "i2"), method = "fixed", data = dat_pm)
  cp$prop_var <- NA_real_
  cp$reliability <- NA_real_
  res <- show(print(cp))
  expect_match(res, "C = fixed\\(i1, i2\\)")
  expect_no_match(res, "proportion of variance")
  expect_no_match(res, "Cronbach")
  expect_no_match(res, "standardized")
  expect_no_error(show(summary(cp)))
})

test_that("print.drm_loadings handles empty and populated tables", {
  local_reproducible_output()
  empty <- structure(
    data.frame(composite = character(0), indicator = character(0),
               loading = numeric(0), std_loading = numeric(0)),
    class = c("drm_loadings", "data.frame")
  )
  expect_invisible(print(empty))
  expect_match(show(print(empty)), "<drmSEM composite/latent loadings: none>",
               fixed = TRUE)

  tab <- structure(
    data.frame(composite = c("C", "C", "D", "D"),
               indicator = c("i1", "i2", "i3", "i4"),
               loading = c(0.123456, 0.5, 0.7, 0.2),
               std_loading = c(0.9, 0.8, 0.7, 0.6)),
    class = c("drm_loadings", "data.frame")
  )
  expect_invisible(print(tab))
  res <- show(print(tab))
  expect_match(res, "loadings: 2 constructs")
  expect_match(res, "0.1235")
  expect_match(res, "std_loading")

  one <- tab[tab$composite == "C", ]
  class(one) <- c("drm_loadings", "data.frame")
  expect_match(show(print(one)), "loadings: 1 construct>")

  no_std <- tab[, c("composite", "indicator", "loading")]
  class(no_std) <- c("drm_loadings", "data.frame")
  expect_no_error(show(print(no_std)))
})

test_that("print.drm_reliability handles empty and populated tables", {
  local_reproducible_output()
  empty <- structure(
    data.frame(composite = character(0), type = character(0),
               method = character(0), n_indicators = integer(0),
               alpha = numeric(0), rho = numeric(0), ave = numeric(0),
               prop_var = numeric(0)),
    class = c("drm_reliability", "data.frame")
  )
  expect_invisible(print(empty))
  expect_match(show(print(empty)), "construct reliability: none")

  tab <- structure(
    data.frame(composite = c("C", "D"), type = "formative", method = "pca",
               n_indicators = c(3L, 2L), alpha = c(0.81234, NA),
               rho = c(0.7, 0.6), ave = c(0.55555, NA),
               prop_var = c(0.62, 0.7)),
    class = c("drm_reliability", "data.frame")
  )
  expect_invisible(print(tab))
  res <- show(print(tab))
  expect_match(res, "construct reliability: 2 constructs")
  expect_match(res, "0.8123")
  expect_match(res, "0.5556")
  expect_match(res, "NA")
})

# ---- model sets, comparison, averaging --------------------------------------

test_that("print.drm_model_set lists candidates", {
  local_reproducible_output()
  ms <- drm_model_set(
    direct = drm_dag(fitness ~ temp + size),
    mediated = drm_dag(size ~ temp, fitness ~ size + temp)
  )
  expect_invisible(print(ms))
  res <- show(print(ms))
  expect_match(res, "candidate model set")
  expect_match(res, "2 candidate models")
  expect_match(res, "direct")
  expect_match(res, "mediated")
  expect_match(res, "compare")

  one <- drm_model_set(only = drm_dag(y ~ x))
  expect_match(show(print(one)), "1 candidate model\\b")
})

make_compare <- function(criterion = "CBIC", n_models = 2L) {
  tab <- data.frame(
    model = c("m1", "m2")[seq_len(n_models)],
    fisher_c = c(4.2, 9.7)[seq_len(n_models)],
    df = c(4L, 6L)[seq_len(n_models)],
    p.value = c(0.38, 0.14)[seq_len(n_models)],
    k = c(2L, 3L)[seq_len(n_models)],
    n = 100L,
    stringsAsFactors = FALSE
  )
  tab <- drmSEM:::drm_add_cicc(tab, criterion = criterion)
  attr(tab, "criterion") <- criterion
  class(tab) <- c("drm_compare", "data.frame")
  tab
}

test_that("print.drm_compare shows the table and the best model", {
  local_reproducible_output()
  cmp <- make_compare("CBIC")
  expect_invisible(print(cmp))
  res <- show(print(cmp))
  expect_match(res, "model comparison: 2 candidates")
  expect_match(res, "wCBIC")
  expect_match(res, "Best model by CBIC: m1")

  expect_match(show(print(make_compare("CICc"))), "Best model by CICc: m1")
  expect_match(show(print(make_compare("CBIC", 1L))), "1 candidate>")
})

test_that("print.drm_average handles empty and populated tables", {
  local_reproducible_output()
  empty <- structure(
    data.frame(from = character(0), to = character(0),
               component = character(0), std.estimate = numeric(0),
               weight_sum = numeric(0)),
    class = c("drm_average", "data.frame")
  )
  expect_invisible(print(empty))
  expect_match(show(print(empty)), "model-averaged standardized paths: 0 paths")

  tab <- structure(
    data.frame(from = c("temp", "size"), to = c("size", "fitness"),
               component = c("mu", "sigma"),
               std.estimate = c(0.123456, -0.5),
               weight_sum = c(0.98765, 1)),
    class = c("drm_average", "data.frame")
  )
  expect_invisible(print(tab))
  res <- show(print(tab))
  expect_match(res, "standardized paths: 2 paths")
  expect_match(res, "0.1235")
  expect_match(res, "0.988")
  expect_match(res, "sigma")
})

# ---- d-separation ------------------------------------------------------------

make_dsep <- function(p) {
  tab <- data.frame(
    claim = rep_len("c", length(p)),
    p.value = p,
    LR = rep(1.23456, length(p)),
    stringsAsFactors = FALSE
  )
  attr(tab, "fisher_c") <- drmSEM:::drm_fisher_c_from_p(p)
  class(tab) <- c("drm_dsep", "data.frame")
  tab
}

test_that("print.drm_dsep reports Fisher's C on its df", {
  local_reproducible_output()
  ds <- make_dsep(c(0.5, 0.2))
  expect_invisible(print(ds))
  res <- show(print(ds))
  expect_match(res, "d-separation: 2 claims")
  expect_match(res, "1.235")
  C <- -2 * (log(0.5) + log(0.2))
  expect_match(res, sprintf("Fisher's C = %s on 4 df", round(C, 2)),
               fixed = TRUE)
})

test_that("print.drm_dsep tolerates zero claims and a missing C", {
  local_reproducible_output()
  none <- make_dsep(numeric(0))
  expect_invisible(print(none))
  res <- show(print(none))
  expect_match(res, "d-separation: 0 claims")
  expect_no_match(res, "Fisher's C")

  nofc <- make_dsep(0.3)
  attr(nofc, "fisher_c") <- NULL
  expect_no_error(show(print(nofc)))
  expect_no_match(show(print(nofc)), "Fisher's C")
})
