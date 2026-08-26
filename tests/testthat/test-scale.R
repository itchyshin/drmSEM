# Scale-aware d-separation: detecting a claim tested at the wrong scale.
#
# THE DEFECT, demonstrated before it was addressed. A d-separation claim is tested
# on the flattened data frame, one row per observation. When the claim's variable
# actually varies at a COARSER scale -- a species-level trait repeated down to
# individuals -- the likelihood ratio sees one row per individual while the variable
# carries only as much information as there are groups. A chance group-level
# correlation is then credited with n = rows of evidence.
#
# Measured on the fixture below (12 species x 40 individuals, `trait` species-level,
# `z` species-structured but INDEPENDENT of trait):
#     flattened      : p = 0.004   <- REJECTS a TRUE independence
#     with (1 | sp)  : p >> 0.05   <- correct
# Fisher's C inherits the false rejection, so the whole model is condemned.
#
# WHY THIS EXCLUDES FROM C RATHER THAN AUTO-REFITTING. The remedy is to give
# BOTH the base and the augmented fit the grouping term. Adding it only to the
# augmented fit would compare two different random-effect structures, which is
# not a valid likelihood-ratio test. Auto-adding it to the stored node would
# test a different SEM than paths(). D-21 therefore marks the claim
# `wrong_scale` and drops its p-value from Fisher's C. The user adds `(1 | g)`
# to test at the right scale (V-110).
#
# V-109   a claim whose variable lives at a coarser scale is detected and reported
# V-109c  Fisher's C excludes that p-value; the true independence is not condemned
# V-110   a correctly-specified model is NOT flagged (no false alarms)
# V-111   the underlying detector is exact about what counts as a coarser scale

skip_if_not_installed("drmTMB")

scale_dat <- function(n_sp = 12, n_per = 40, seed = 42) {
  set.seed(seed)
  n <- n_sp * n_per
  sp <- factor(rep(seq_len(n_sp), each = n_per))
  trait <- stats::rnorm(n_sp)[as.integer(sp)]        # ONE value per species
  y <- 0.6 * trait + stats::rnorm(n)
  # z is species-structured but has NO dependence on trait: the claim
  # `trait _||_ z | {y}` is TRUE in this DGP.
  z <- stats::rnorm(n_sp, sd = 1)[as.integer(sp)] + stats::rnorm(n, sd = 0.5)
  data.frame(sp = sp, trait = trait, y = y, z = z)
}

test_that("V-109: a claim tested at the wrong scale is detected and reported", {
  d <- scale_dat()
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ trait), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ y), family = stats::gaussian()),
    data = d
  )
  expect_warning(ds <- dsep(sem), "wrong scale")
  ds <- as.data.frame(ds)
  row <- ds[ds$x == "trait" & ds$y == "z", , drop = FALSE]
  expect_identical(nrow(row), 1L)
  # The report must name the grouping and the honest sample size, because "this
  # p-value is untrustworthy" is not actionable without them.
  expect_identical(row$scale_group, "sp")
  expect_identical(row$n_effective, 12L)
  expect_lt(row$n_effective, nrow(d))
})

test_that("V-109b: the warning names the remedy, not just the problem", {
  d <- scale_dat()
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ trait), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ y), family = stats::gaussian()),
    data = d
  )
  msg <- tryCatch(dsep(sem), warning = function(w) conditionMessage(w))
  expect_match(msg, "sp", fixed = TRUE)
  expect_match(msg, "(1 | group)", fixed = TRUE)
  # And it must say which DIRECTION the error goes -- rejecting true independences,
  # not missing false ones. A reader who assumes the opposite will misread the table.
  expect_match(msg, "REJECTS TRUE", fixed = TRUE)
})

test_that("V-109c: Fisher's C excludes the mis-scaled claim", {
  d <- scale_dat()
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ trait), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ y), family = stats::gaussian()),
    data = d
  )
  expect_warning(ds <- dsep(sem), "wrong scale")
  row <- as.data.frame(ds)[ds$x == "trait" & ds$y == "z", , drop = FALSE]
  expect_identical(nrow(row), 1L)
  expect_identical(row$status, "wrong_scale")
  fc <- fisher_c(ds)
  expect_equal(
    fc$n_claims,
    sum(ds$status == "ok" & !is.na(ds$p.value))
  )
  expect_false(any(ds$status[ds$status == "ok"] == "wrong_scale"))
  # The V-109 fixture used to condemn the whole model (C p = 0.004) on a
  # TRUE independence. Excluding the invalid LR must not reject.
  expect_false(isTRUE(fc$p.value < 0.05))
})

test_that("V-110: a correctly-specified model is not flagged", {
  d <- scale_dat()
  # Node z now models the species grouping, so the claim is tested at its own scale.
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ trait), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ y + (1 | sp)), family = stats::gaussian()),
    data = d
  )
  ds <- expect_no_warning(dsep(sem))
  ds <- as.data.frame(ds)
  expect_true(all(is.na(ds$n_effective)))
  expect_true(all(is.na(ds$scale_group)))
  # And the true independence is no longer rejected -- the point of the whole thing.
  row <- ds[ds$x == "trait" & ds$y == "z", , drop = FALSE]
  expect_gt(row$p.value, 0.05)
})

test_that("V-110b: plain row-scale data is never flagged", {
  set.seed(7)
  n <- 300
  d <- data.frame(x = stats::rnorm(n), m = stats::rnorm(n))
  d$y <- 0.5 * d$m + stats::rnorm(n)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = d
  )
  ds <- as.data.frame(expect_no_warning(dsep(sem)))
  expect_true(all(is.na(ds$n_effective)))
})

test_that("V-111: the detector is exact about what counts as a coarser scale", {
  d <- scale_dat(n_sp = 6, n_per = 10)
  # `trait` is constant within `sp` -> sp is a coarser scale for it.
  hit <- drmSEM:::drm_coarser_scales("trait", d)
  expect_identical(nrow(hit), 1L)
  expect_identical(hit$group, "sp")
  expect_identical(hit$n_groups, 6L)

  # `y` varies within species -> no coarser scale, so nothing to report.
  expect_identical(nrow(drmSEM:::drm_coarser_scales("y", d)), 0L)

  # A grouping with one level per row carries no pooling and must not count --
  # otherwise a row id would be reported as a "scale" for every variable.
  d$rowid <- factor(seq_len(nrow(d)))
  expect_false("rowid" %in% drmSEM:::drm_coarser_scales("trait", d)$group)

  # A variable that is not a column at all is not an error, just no finding.
  expect_identical(nrow(drmSEM:::drm_coarser_scales("not_a_column", d)), 0L)
})

test_that("V-111b: groupings the node already models are not re-reported", {
  skip_if_not_installed("drmTMB")
  set.seed(3)
  n <- 120
  g <- factor(rep(seq_len(6), each = 20))
  d <- data.frame(g = g, a = stats::rnorm(6)[as.integer(g)], b = stats::rnorm(n))
  fit <- drmTMB::drmTMB(drmTMB::bf(b ~ 1 + (1 | g)), family = stats::gaussian(), data = d)
  # The bar term must be found, so a node that already pools by `g` is not told to
  # add `(1 | g)` it already has.
  expect_true("g" %in% drmSEM:::drm_fit_grouping_vars(fit))
})
