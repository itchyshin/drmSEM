# Helpers and error paths in R/model_set.R that test-model-set.R does not cover:
# drm_delta_weights(), drm_compare_criterion(), drm_as_compare(), best(),
# average() and compare() argument checks, and the print methods.
#
# drm_compare objects are built by hand (no 'fits' attribute) so these tests
# need no drmTMB engine, except the compare() data check which is gated.

make_cmp <- function(
  fisher_c = c(10, 12, 30),
  k = c(2L, 3L, 4L),
  n = 100L,
  criterion = "CBIC",
  fits = NULL
) {
  m <- length(fisher_c)
  tab <- data.frame(
    model = paste0("m", seq_len(m)),
    fisher_c = fisher_c,
    df = rep(4L, m),
    p.value = rep(0.5, m),
    k = k,
    n = rep(n, m),
    stringsAsFactors = FALSE
  )
  tab <- drmSEM:::drm_add_cicc(tab, criterion = criterion)
  if (!is.null(fits)) {
    attr(tab, "fits") <- fits
  }
  class(tab) <- c("drm_compare", "data.frame")
  tab
}

# ---------------------------------------------------------------------------
# drm_delta_weights()
# ---------------------------------------------------------------------------

test_that("drm_delta_weights gives deltas from the minimum and normalised weights", {
  out <- drmSEM:::drm_delta_weights(c(10, 12, 20))
  expect_equal(out$delta, c(0, 2, 10))
  rel <- exp(-0.5 * c(0, 2, 10))
  expect_equal(out$weight, rel / sum(rel))
  expect_equal(sum(out$weight), 1)
  expect_true(all(diff(out$weight) < 0))
})

test_that("drm_delta_weights gives tied scores equal weight", {
  out <- drmSEM:::drm_delta_weights(c(5, 5, 9))
  expect_equal(out$delta[1:2], c(0, 0))
  expect_equal(out$weight[[1]], out$weight[[2]])
  expect_equal(sum(out$weight), 1)

  all_tied <- drmSEM:::drm_delta_weights(c(7, 7, 7, 7))
  expect_equal(all_tied$weight, rep(0.25, 4))
})

test_that("drm_delta_weights gives a single model delta 0 and weight 1", {
  out <- drmSEM:::drm_delta_weights(42)
  expect_equal(out$delta, 0)
  expect_equal(out$weight, 1)
})

test_that("drm_delta_weights gives +Inf and NA scores NA delta and zero weight", {
  out <- drmSEM:::drm_delta_weights(c(10, Inf, NA, 14))
  expect_equal(out$delta, c(0, NA, NA, 4))
  expect_equal(out$weight[c(2, 3)], c(0, 0))
  expect_equal(sum(out$weight), 1)
  rel <- exp(-0.5 * c(0, 4))
  expect_equal(out$weight[c(1, 4)], rel / sum(rel))

  none <- drmSEM:::drm_delta_weights(c(Inf, NA))
  expect_true(all(is.na(none$delta)))
  expect_equal(none$weight, c(0, 0))
})

# ---------------------------------------------------------------------------
# drm_compare_criterion()
# ---------------------------------------------------------------------------

test_that("drm_compare_criterion reads the criterion attribute", {
  expect_identical(drmSEM:::drm_compare_criterion(make_cmp()), "CBIC")
  expect_identical(
    drmSEM:::drm_compare_criterion(make_cmp(criterion = "CICc")),
    "CICc"
  )
})

test_that("drm_compare_criterion falls back to CBIC then CICc", {
  cmp <- make_cmp(criterion = "CICc")
  attr(cmp, "criterion") <- NULL
  expect_identical(drmSEM:::drm_compare_criterion(cmp), "CBIC")

  attr(cmp, "criterion") <- "nonsense"
  expect_identical(drmSEM:::drm_compare_criterion(cmp), "CBIC")

  no_cbic <- as.data.frame(cmp)
  no_cbic$CBIC <- NULL
  attr(no_cbic, "criterion") <- "CBIC"
  expect_identical(drmSEM:::drm_compare_criterion(no_cbic), "CICc")
})

# ---------------------------------------------------------------------------
# drm_as_compare()
# ---------------------------------------------------------------------------

test_that("drm_as_compare passes a drm_compare through unchanged", {
  cmp <- make_cmp()
  expect_identical(drmSEM:::drm_as_compare(cmp), cmp)
})

test_that("drm_as_compare rejects other objects", {
  expect_error(
    drmSEM:::drm_as_compare(data.frame(a = 1)),
    "Expected a .*drm_compare.* or .*drm_model_set"
  )
  expect_error(drmSEM:::drm_as_compare(NULL), "Expected a")
})

# ---------------------------------------------------------------------------
# best() / average() abort paths
# ---------------------------------------------------------------------------

test_that("best.drm_compare aborts when the comparison carries no fits", {
  expect_error(best(make_cmp()), "This comparison carries no fitted models.")
})

test_that("best.drm_compare aborts when the top model's fit is missing", {
  # top model by CBIC is m1; the fits list only holds m2
  cmp <- make_cmp(fits = list(m2 = "fit2"))
  expect_error(best(cmp), "Could not recover the fitted model for .*m1")
})

test_that("best.drm_compare returns the fit of the top-ranked model", {
  cmp <- make_cmp(fits = list(m1 = "fit1", m2 = "fit2", m3 = "fit3"))
  expect_identical(best(cmp), "fit1")
})

test_that("best.drm_model_set delegates to compare() and surfaces its errors", {
  skip_if_not_installed("drmTMB")
  ms <- drm_model_set(a = drm_dag(y ~ x))
  expect_error(best(ms), "data. is required")
})

test_that("average.drm_compare aborts when the comparison carries no fits", {
  expect_error(
    average(make_cmp()),
    "This comparison carries no fitted models."
  )
})

# ---------------------------------------------------------------------------
# compare() argument checks
# ---------------------------------------------------------------------------

test_that("compare.drm_model_set aborts when data is missing", {
  skip_if_not_installed("drmTMB")
  ms <- drm_model_set(a = drm_dag(y ~ x))
  expect_error(compare(ms), "data. is required for .*compare")
})

test_that("compare rejects an unknown criterion in match.arg", {
  skip_if_not_installed("drmTMB")
  ms <- drm_model_set(a = drm_dag(y ~ x))
  expect_error(
    compare(ms, data = data.frame(x = 1:3, y = 1:3), criterion = "nonsense"),
    "should be one of"
  )
})

test_that("drm_add_cicc rejects an unknown criterion in match.arg", {
  tab <- data.frame(
    model = "a",
    fisher_c = 1,
    df = 2L,
    p.value = 0.5,
    k = 1L,
    n = 50L
  )
  expect_error(drmSEM:::drm_add_cicc(tab, criterion = "nonsense"), "should be one of")
})

# ---------------------------------------------------------------------------
# print methods
# ---------------------------------------------------------------------------

capture_print <- function(x) {
  msgs <- character()
  out <- withCallingHandlers(
    utils::capture.output(print(x)),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  list(out = out, msgs = paste(msgs, collapse = "\n"))
}

test_that("print.drm_compare shows candidates, delta/weight columns and the best model", {
  cmp <- make_cmp()
  res <- capture_print(cmp)
  expect_match(res$msgs, "model comparison: 3 candidates")
  header <- res$out[[1]]
  for (col in c("CICc", "dCICc", "wCICc", "CBIC", "dCBIC", "wCBIC", "weight")) {
    expect_match(header, col, fixed = TRUE)
  }
  expect_match(res$msgs, "Best model by CBIC")
  expect_match(res$msgs, "m1")
  invisible_out <- withVisible(utils::capture.output(r <- print(cmp)))
  expect_identical(r, cmp)
})

test_that("print.drm_compare names CICc when that criterion was used", {
  cmp <- make_cmp(criterion = "CICc")
  res <- capture_print(cmp)
  expect_match(res$msgs, "Best model by CICc")
})

test_that("print.drm_compare pluralises a single candidate", {
  res <- capture_print(make_cmp(fisher_c = 5, k = 2L))
  expect_match(res$msgs, "1 candidate>")
  expect_no_match(res$msgs, "candidates")
})

test_that("print.drm_average shows the path columns and rounded values", {
  avg <- data.frame(
    from = c("x", "z"),
    to = c("y", "y"),
    component = c("mu", "sigma"),
    std.estimate = c(0.123456, -0.5),
    weight_sum = c(0.98765, 0.4),
    stringsAsFactors = FALSE
  )
  class(avg) <- c("drm_average", "data.frame")
  res <- capture_print(avg)
  expect_match(res$msgs, "model-averaged standardized paths: 2 paths")
  for (col in c("from", "to", "component", "std.estimate", "weight_sum")) {
    expect_match(res$out[[1]], col, fixed = TRUE)
  }
  expect_true(any(grepl("0.1235", res$out, fixed = TRUE)))
  expect_true(any(grepl("0.988", res$out, fixed = TRUE)))
  expect_true(any(grepl("sigma", res$out, fixed = TRUE)))
})
