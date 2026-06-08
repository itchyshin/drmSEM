# OQ-12 — the unified effect-API surface. The argument-normalization helpers are
# pure R (no drmTMB), so they are tested directly here; the end-to-end parity of
# the new surface against the deprecated aliases is checked under the drmTMB gate.

# ---- drm_effect_controls(): uncertainty / nsim / population mapping ----------

test_that("drm_effect_controls maps the unified surface onto engine knobs", {
  # defaults
  d <- drmSEM:::drm_effect_controls()
  expect_true(d$draw)
  expect_identical(d$n_sim, 50L)

  # uncertainty -> draw
  expect_false(drmSEM:::drm_effect_controls(uncertainty = "none")$draw)
  expect_true(drmSEM:::drm_effect_controls(uncertainty = "parametric")$draw)

  # nsim -> n_sim (coerced to integer)
  expect_identical(drmSEM:::drm_effect_controls(nsim = 10)$n_sim, 10L)

  # custom default_nsim is honoured when nsim is absent
  expect_identical(
    drmSEM:::drm_effect_controls(default_nsim = 1L)$n_sim, 1L
  )
})

test_that("not-yet-implemented choices abort with an OQ pointer", {
  expect_error(
    drmSEM:::drm_effect_controls(uncertainty = "bootstrap"),
    "OQ-10"
  )
  expect_error(
    drmSEM:::drm_effect_controls(population = "marginal"),
    "OQ-9"
  )
  # conditional is the supported population and must not error
  expect_silent(drmSEM:::drm_effect_controls(population = "conditional"))
})

test_that("deprecated aliases still work but warn, and the new arg wins", {
  expect_warning(
    res <- drmSEM:::drm_effect_controls(draw = FALSE),
    "deprecated"
  )
  expect_false(res$draw)

  expect_warning(
    res2 <- drmSEM:::drm_effect_controls(n_sim = 7),
    "deprecated"
  )
  expect_identical(res2$n_sim, 7L)

  # supplying both the new and deprecated form: new wins, with a warning
  expect_warning(
    res3 <- drmSEM:::drm_effect_controls(uncertainty = "none", draw = TRUE),
    "using"
  )
  expect_false(res3$draw)
})

# ---- drm_resolve_mediation(): method <-> mediation --------------------------

test_that("drm_resolve_mediation maps method and deprecates mediation", {
  expect_identical(drmSEM:::drm_resolve_mediation(), "mean")
  expect_identical(drmSEM:::drm_resolve_mediation(method = "simulate"), "distribution")
  expect_identical(drmSEM:::drm_resolve_mediation(method = "gcomp"), "mean")

  expect_warning(
    m <- drmSEM:::drm_resolve_mediation(mediation = "distribution"),
    "deprecated"
  )
  expect_identical(m, "distribution")

  # method wins over the deprecated mediation, with a warning
  expect_warning(
    m2 <- drmSEM:::drm_resolve_mediation(method = "gcomp", mediation = "distribution"),
    "using"
  )
  expect_identical(m2, "mean")

  expect_error(drmSEM:::drm_resolve_mediation(method = "nonsense"))
})

# ---- end-to-end parity of the new surface vs the deprecated aliases ---------
# These need a live drmTMB fit, so each guards itself with skip_if_not_installed.

test_that("new surface reproduces the deprecated-alias results exactly", {
  skip_if_not_installed("drmTMB")
  set.seed(11)
  n <- 600
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.5 * x, 1)
  y <- stats::rnorm(n, 0.3 * x + 0.6 * m, 1)
  dat <- data.frame(x, m, y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ x + m), family = stats::gaussian()),
    data = dat
  )

  # total_effects: method="gcomp" + uncertainty="none" == mediation="mean" + draw=FALSE
  new_tot <- total_effects(sem, "x", "y", method = "gcomp",
                           uncertainty = "none", seed = 1)
  old_tot <- suppressWarnings(
    total_effects(sem, "x", "y", mediation = "mean", draw = FALSE, seed = 1)
  )
  expect_equal(new_tot$estimate, old_tot$estimate)
  expect_identical(new_tot$mediation, "mean")

  # indirect_effects: uncertainty="none"/nsim=1 == draw=FALSE/n_sim=1
  new_ie <- indirect_effects(sem, "x", "y", uncertainty = "none", nsim = 1, seed = 2)
  old_ie <- suppressWarnings(
    indirect_effects(sem, "x", "y", draw = FALSE, n_sim = 1, seed = 2)
  )
  expect_equal(new_ie$estimate, old_ie$estimate)
})

test_that("direct_effects exposes outcome functionals (target=) like total_effects", {
  skip_if_not_installed("drmTMB")
  set.seed(13)
  n <- 500
  x <- stats::rnorm(n)
  cnt <- stats::rpois(n, lambda = exp(0.4 + 0.5 * x))
  dat <- data.frame(x, cnt)

  sem <- drm_sem(
    cnt = drm_node(drmTMB::bf(cnt ~ x), family = drmTMB::nbinom2()),
    data = dat
  )

  de <- direct_effects(sem, "x", "cnt", target = "p_zero",
                       uncertainty = "none", nsim = 50, seed = 5)
  expect_s3_class(de, "drm_effect")
  expect_identical(de$target, "p_zero")
  expect_true(is.finite(de$estimate))
})

# ---- multi-quantile curves (OQ-11): a vector `prob` ------------------------

test_that("a vector prob is validated and only direct_/total_effects accept one", {
  # No engine needed: drm_check_prob runs before drm_require_drmTMB().
  fake <- structure(list(endogenous = "y"), class = "drm_sem")
  # a vector prob is meaningless unless the target is the quantile
  expect_error(direct_effects(fake, "x", "y", target = "mean", prob = c(0.1, 0.9)),
               "only meaningful")
  expect_error(total_effects(fake, "x", "y", target = "mean", prob = c(0.1, 0.9)),
               "only meaningful")
  # out-of-range probabilities are rejected for the quantile target
  expect_error(direct_effects(fake, "x", "y", target = "quantile", prob = c(0, 0.5)),
               "between 0 and 1")
  # the decomposing entry point reports one row per quantity, so single prob only
  expect_error(
    indirect_effects(fake, "x", "y", target = "quantile", prob = c(0.25, 0.75)),
    "takes a single"
  )
})

test_that("direct_/total_effects(target='quantile') return a coherent quantile curve", {
  skip_if_not_installed("drmTMB")
  set.seed(21)
  n <- 400
  x <- stats::rnorm(n)
  y <- 0.3 + 0.5 * x + stats::rnorm(n, sd = exp(0.2 * x))   # x moves sigma too
  dat <- data.frame(x, y)
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x, sigma ~ x), family = stats::gaussian()),
    data = dat
  )

  probs <- c(0.1, 0.5, 0.9)
  curve <- direct_effects(sem, "x", "y", target = "quantile", prob = probs,
                          uncertainty = "none", nsim = 200, seed = 7)
  expect_s3_class(curve, "drm_effect")
  expect_identical(nrow(curve), 3L)
  expect_true("prob" %in% names(curve))
  expect_equal(curve$prob, probs)
  expect_true(all(curve$target == "quantile"))
  expect_true(all(is.finite(curve$estimate)))

  # a single prob keeps the historical one-row schema (no prob column)
  one <- direct_effects(sem, "x", "y", target = "quantile", prob = 0.5,
                        uncertainty = "none", nsim = 200, seed = 7)
  expect_identical(nrow(one), 1L)
  expect_false("prob" %in% names(one))
  # shared-seed coherence: the curve's median row equals the standalone median
  expect_equal(curve$estimate[curve$prob == 0.5], one$estimate, tolerance = 1e-8)

  # total_effects carries the same multi-row shape (with its mediation column)
  tcurve <- total_effects(sem, "x", "y", target = "quantile", prob = probs,
                          method = "gcomp", uncertainty = "none", nsim = 200, seed = 7)
  expect_identical(nrow(tcurve), 3L)
  expect_equal(tcurve$prob, probs)
  expect_true("mediation" %in% names(tcurve))
})

test_that("uncertainty='bootstrap' and population='marginal' abort before fitting work", {
  skip_if_not_installed("drmTMB")
  set.seed(3)
  dat <- data.frame(x = stats::rnorm(50), y = stats::rnorm(50))
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x), family = stats::gaussian()),
    data = dat
  )
  expect_error(total_effects(sem, "x", "y", uncertainty = "bootstrap"), "OQ-10")
  expect_error(direct_effects(sem, "x", "y", population = "marginal"), "OQ-9")
})
