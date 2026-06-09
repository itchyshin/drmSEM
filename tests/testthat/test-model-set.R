# Phase 2: phylopath-style confirmatory model comparison.
#
# The pure-logic tests exercise the CICc / CBIC / weight arithmetic and the
# drm_dag()/drm_model_set() constructors + print methods WITHOUT the drmTMB
# engine (loading drmSEM needs no engine). The end-to-end test that actually
# fits candidates is gated on drmTMB and mirrors test-integration.R.

# ---------------------------------------------------------------------------
# Pure-logic: CICc / CBIC / weight arithmetic (no engine required)
# ---------------------------------------------------------------------------

test_that("drm_add_cicc computes CICc = C + 2k * n/(n-k-1)", {
  tab <- data.frame(
    model = c("a", "b", "c"),
    fisher_c = c(2, 4, 10),
    k = c(3L, 4L, 2L),
    n = c(100L, 100L, 100L),
    stringsAsFactors = FALSE
  )
  out <- drm_add_cicc(tab)

  # CICc and CBIC match the formulas row by row.
  expected_cicc <- tab$fisher_c + 2 * tab$k * (tab$n / (tab$n - tab$k - 1))
  names(expected_cicc) <- tab$model
  expect_equal(out$CICc, unname(expected_cicc[out$model]))

  expected_cbic <- tab$fisher_c + tab$k * log(tab$n)
  names(expected_cbic) <- tab$model
  expect_equal(out$CBIC, unname(expected_cbic[out$model]))

  # The default table is sorted ascending by CBIC; deltas are from each
  # criterion's minimum.
  expect_false(is.unsorted(out$CBIC))
  expect_equal(attr(out, "criterion"), "CBIC")
  expect_equal(min(out$dCICc), 0)
  expect_equal(out$dCICc, out$CICc - min(out$CICc))
  expect_equal(min(out$dCBIC), 0)
  expect_equal(out$dCBIC, out$CBIC - min(out$CBIC))
})

test_that("criterion weights sum to 1 and the best model carries the most weight", {
  tab <- data.frame(
    model = c("a", "b", "c"),
    fisher_c = c(2, 4, 10),
    k = c(3L, 4L, 2L),
    n = c(100L, 100L, 100L),
    stringsAsFactors = FALSE
  )
  out <- drm_add_cicc(tab)

  expect_equal(sum(out$weight), 1)
  expect_equal(out$weight, out$wCBIC)
  # lowest CBIC <=> highest weight
  expect_equal(out$model[which.min(out$CBIC)], out$model[which.max(out$weight)])
  # weights are monotone-decreasing along the (CBIC-sorted) table
  expect_false(is.unsorted(rev(out$weight)))
  expect_equal(out$weight, exp(-0.5 * out$dCBIC) / sum(exp(-0.5 * out$dCBIC)))
})

test_that("CBIC is the default and CICc remains available when requested", {
  tab <- data.frame(
    model = c("truth", "overfit"),
    fisher_c = c(4, 0),
    k = c(2L, 3L),
    n = c(1000L, 1000L),
    stringsAsFactors = FALSE
  )

  cicc <- drm_add_cicc(tab, criterion = "CICc")
  cbic <- drm_add_cicc(tab)

  expect_equal(cicc$model[[which.min(cicc$CICc)]], "overfit")
  expect_equal(cicc$weight, cicc$wCICc)

  expect_equal(cbic$model[[which.min(cbic$CBIC)]], "truth")
  expect_equal(cbic$weight, cbic$wCBIC)
  expect_equal(attr(cbic, "criterion"), "CBIC")
})

test_that("CICc reduces to C + 2k as n grows large", {
  small <- data.frame(
    model = "m",
    fisher_c = 5,
    k = 4L,
    n = 30L,
    stringsAsFactors = FALSE
  )
  large <- data.frame(
    model = "m",
    fisher_c = 5,
    k = 4L,
    n = 1e7,
    stringsAsFactors = FALSE
  )
  cicc_small <- drm_add_cicc(small)$CICc
  cicc_large <- drm_add_cicc(large)$CICc

  c_plus_2k <- 5 + 2 * 4
  # the finite-sample correction inflates CICc for small n ...
  expect_gt(cicc_small, c_plus_2k)
  # ... and vanishes as n -> Inf, leaving C + 2k.
  expect_equal(cicc_large, c_plus_2k, tolerance = 1e-3)
})

test_that("drm_add_cicc handles a non-estimable correction (n - k - 1 <= 0)", {
  tab <- data.frame(
    model = c("ok", "saturated"),
    fisher_c = c(3, 1),
    k = c(2L, 10L),
    n = c(10L, 10L),
    stringsAsFactors = FALSE
  )
  out <- drm_add_cicc(tab, criterion = "CICc")
  # CICc undefined where denom <= 0; weight degrades to 0, not NaN-propagated.
  expect_true(is.na(out$CICc[out$model == "saturated"]))
  expect_equal(out$weight[out$model == "saturated"], 0)
  expect_true(is.finite(out$CBIC[out$model == "saturated"]))
  # the estimable model still gets all the (finite) weight.
  expect_equal(out$weight[out$model == "ok"], 1)

  cbic <- drm_add_cicc(tab)
  expect_equal(cbic$weight, cbic$wCBIC)
  expect_true(all(is.finite(cbic$weight)))
})

# ---------------------------------------------------------------------------
# Pure-logic: constructors + print methods (no engine required)
# ---------------------------------------------------------------------------

test_that("drm_dag() captures node formulas keyed by response", {
  dag <- drm_dag(size ~ temp, fitness ~ size + temp)
  expect_s3_class(dag, "drm_dag")
  expect_equal(dag$responses, c("size", "fitness"))
  expect_equal(names(dag$formulas), c("size", "fitness"))
  expect_no_error(print(dag))
})

test_that("drm_dag() rejects empty input, non-formulas, and duplicate responses", {
  expect_error(drm_dag(), "at least one")
  expect_error(drm_dag(1), "formula")
  expect_error(drm_dag(y ~ x, y ~ z), "unique")
  expect_error(drm_dag(~x), "response")
})

test_that("drm_model_set() collects named drm_dags and prints", {
  models <- drm_model_set(
    direct = drm_dag(fitness ~ temp + size),
    mediated = drm_dag(size ~ temp, fitness ~ size + temp)
  )
  expect_s3_class(models, "drm_model_set")
  expect_equal(names(models$models), c("direct", "mediated"))
  expect_no_error(print(models))
})

test_that("drm_model_set() requires named, unique drm_dag arguments", {
  expect_error(drm_model_set(), "at least one")
  expect_error(drm_model_set(drm_dag(y ~ x)), "named")
  expect_error(drm_model_set(a = 1), "drm_dag")
  expect_error(
    drm_model_set(a = drm_dag(y ~ x), a = drm_dag(z ~ x)),
    "unique"
  )
})

# ---------------------------------------------------------------------------
# Engine-gated end-to-end: fit, compare, best (mirrors test-integration.R)
# ---------------------------------------------------------------------------

# Candidate-model factories. Defined BEFORE the test that uses them: testthat
# evaluates each test_that() block as the file is sourced, so a helper defined
# at the bottom would not yet exist when the test runs.
drm_model_set_dag_mediated <- function() {
  drm_dag(size ~ temp, abundance ~ size + temp)
}
drm_model_set_dag_direct <- function() {
  drm_dag(size ~ temp, abundance ~ temp)
}
drm_model_set_dag_full <- function() {
  drm_dag(size ~ temp, abundance ~ size + temp + alive)
}

skip_if_not_installed("drmTMB")

test_that("compare() fits a model set and ranks candidates by CBIC", {
  dat <- simulate_drmsem_dgp(n = 300, seed = 11)

  models <- drm_model_set(
    # true generating structure: temp -> size -> abundance, temp -> abundance
    mediated = drm_model_set_dag_mediated(),
    # omits the size -> abundance arrow (should fit worse)
    direct = drm_model_set_dag_direct(),
    # adds a spurious arrow but is otherwise saturated for these three nodes
    full = drm_model_set_dag_full()
  )

  cmp <- compare(
    models,
    data = dat,
    family = list(
      size = stats::gaussian(),
      abundance = drmTMB::nbinom2()
    )
  )

  expect_s3_class(cmp, "drm_compare")
  # one row per candidate model
  expect_equal(nrow(cmp), length(models$models))
  expect_setequal(cmp$model, names(models$models))
  # the required comparison columns are present
  expect_true(all(
    c(
      "model",
      "fisher_c",
      "df",
      "p.value",
      "k",
      "n",
      "CICc",
      "dCICc",
      "wCICc",
      "CBIC",
      "dCBIC",
      "wCBIC",
      "weight"
    ) %in%
      names(cmp)
  ))
  # weights sum to ~1 and the table is sorted ascending by CBIC by default
  expect_equal(sum(cmp$weight, na.rm = TRUE), 1, tolerance = 1e-8)
  expect_equal(cmp$weight, cmp$wCBIC)
  expect_false(is.unsorted(cmp$CBIC, na.rm = TRUE))
  expect_equal(attr(cmp, "criterion"), "CBIC")
  expect_true(all(cmp$n == nrow(dat)))
  expect_no_error(print(cmp))

  # best() returns the fitted drm_sem of the lowest-CBIC candidate.
  top <- best(cmp)
  expect_s3_class(top, "drm_sem")

  # average() returns CBIC-weighted standardized paths.
  avg <- average(cmp)
  expect_s3_class(avg, "drm_average")
  expect_true(all(
    c("from", "to", "component", "std.estimate", "weight_sum") %in% names(avg)
  ))
})
