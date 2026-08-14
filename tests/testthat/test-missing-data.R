# Row alignment across nodes (S5).
#
# drmSEM had no missing-data policy at all: drm_sem() handed one frame to every
# node and each drmTMB fit then dropped incomplete rows by its own rules, so a
# piecewise SEM could be fitted on several different samples without any warning.
# Two defects, both covered here:
#
#   1. silent divergence  -- nodes on different row sets, nothing said;
#   2. undiagnosed crash  -- drm_fixed_design() built its design matrix with
#      model.matrix(), which honours na.action = na.omit. With NAs present it
#      returned FEWER rows than newdata, so the assignment either errored with
#      "number of items to replace is not a multiple of replacement length" or,
#      when the counts divided evenly, RECYCLED SILENTLY into a scrambled matrix.
#
# The recycling case is the important one: it produced a wrong number with no
# error at all, so a test that only checks "does not error" would have passed
# against the bug.

skip_if_not_installed("drmTMB")

# x -> m -> y, with missingness injected into named columns.
mdat <- function(n = 200, na_m = integer(0), na_y = integer(0), seed = 11) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.6 * m + stats::rnorm(n)
  d <- data.frame(x = x, m = m, y = y)
  d$m[na_m] <- NA
  d$y[na_y] <- NA
  d
}

chain <- function(d, ...) {
  drm_sem(
    m = drm_node(drmTMB::bf(m ~ x)),
    y = drm_node(drmTMB::bf(y ~ m + x)),
    data = d,
    ...
  )
}

test_that("complete data reports no alignment issues and does not warn", {
  sem <- expect_no_warning(chain(mdat()))
  aln <- attr(sem, "alignment_issues", exact = TRUE)
  expect_s3_class(aln, "data.frame")
  expect_identical(nrow(aln), 0L)
  expect_named(aln, c("node", "n", "issue"))
})

test_that("divergent row sets warn and are reported per node", {
  d <- mdat(na_m = 1:20, na_y = 21:60)
  expect_warning(sem <- chain(d), "different row sets")
  aln <- attr(sem, "alignment_issues", exact = TRUE)
  expect_identical(nrow(aln), 2L)
  expect_setequal(aln$issue, "row_set_mismatch")
  # node m loses only its own NAs; node y loses both columns' NAs.
  expect_identical(aln$n[aln$node == "m"], 180L)
  expect_identical(aln$n[aln$node == "y"], 140L)
})

test_that("na_action = 'fail' aborts and names the counts", {
  d <- mdat(na_m = 1:20, na_y = 21:60)
  expect_error(chain(d, na_action = "fail"), "different row sets")
  expect_error(chain(d, na_action = "fail"), "180")
})

test_that("na_action = 'common' fits every node on one shared sample", {
  d <- mdat(na_m = 1:20, na_y = 21:60)
  sem <- chain(d, na_action = "common")
  expect_identical(nrow(attr(sem, "alignment_issues", exact = TRUE)), 0L)
  n_m <- drmSEM:::drm_fit_nobs(sem$nodes$m)
  n_y <- drmSEM:::drm_fit_nobs(sem$nodes$y)
  expect_identical(n_m, n_y)
  expect_identical(n_m, 140L)
})

test_that("na_action = 'common' keeps rows that only unmodelled columns lack", {
  # `junk` is in the frame but in no node formula, so its NAs must not cost rows.
  d <- mdat()
  d$junk <- NA_real_
  sem <- chain(d, na_action = "common")
  expect_identical(drmSEM:::drm_fit_nobs(sem$nodes$y), 200L)
})

test_that("check_sem() reports per-node nobs", {
  d <- mdat(na_m = 1:20, na_y = 21:60)
  suppressWarnings(sem <- chain(d))
  chk <- check_sem(sem)
  expect_true("nobs" %in% names(chk))
  expect_identical(chk$nobs[chk$node == "y"], 140L)
})

test_that("drm_fixed_design keeps every newdata row when predictors have NAs", {
  # THE RECYCLING CASE. 300 newdata rows with exactly 150 complete means
  # 300 = 2 * 150, so the old code recycled without raising any condition.
  sem <- chain(mdat())
  nd <- mdat(n = 300, seed = 4)
  nd$x[1:150] <- NA
  X <- drmSEM:::drm_fixed_design(sem$nodes$y, "mu", nd)
  expect_identical(nrow(X), 300L)
  expect_identical(sum(!stats::complete.cases(X)), 150L)
})

test_that("effect engine diagnoses rather than raising a raw subscript error", {
  d <- mdat(na_m = 1:20, na_y = 21:60)
  suppressWarnings(sem <- chain(d))
  # Pre-fix this raised "number of items to replace is not a multiple of
  # replacement length" from drm_fixed_design(). Completing at all is the claim.
  eff <- suppressWarnings(indirect_effects(sem, from = "x", to = "y"))
  expect_s3_class(eff, "drm_effect")
  expect_true(nrow(eff) > 0L)
})

test_that("d-separation refuses a claim whose refit changed the sample size", {
  # `w` is a candidate d-sep variable with NAs, so augmenting node y with it
  # drops rows and the LR would otherwise compare two different samples.
  # `w` must be IN the graph for the basis set to contain a claim about it, so
  # it enters as an exogenous predictor of m only. The claim `w _||_ y` then
  # augments node y with w -- and w's NAs shrink that refit's sample.
  d <- mdat()
  set.seed(5)
  d$w <- stats::rnorm(nrow(d))
  d$w[1:40] <- NA
  sem <- suppressWarnings(drm_sem(
    m = drm_node(drmTMB::bf(m ~ x + w)),
    y = drm_node(drmTMB::bf(y ~ m)),
    data = d
  ))
  ds <- dsep(sem)
  involved <- ds[ds$x == "w" | ds$y == "w", , drop = FALSE]
  expect_true(nrow(involved) > 0L)
  expect_true(all(involved$status == "n_mismatch"))
  expect_true(all(is.na(involved$p.value)))
  # An untested claim must not silently enter Fisher's C.
  expect_false(any(involved$status == "ok"))
})
