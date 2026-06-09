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
    drmSEM:::drm_effect_controls(default_nsim = 1L)$n_sim,
    1L
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
  expect_identical(
    drmSEM:::drm_resolve_mediation(method = "simulate"),
    "distribution"
  )
  expect_identical(drmSEM:::drm_resolve_mediation(method = "gcomp"), "mean")

  expect_warning(
    m <- drmSEM:::drm_resolve_mediation(mediation = "distribution"),
    "deprecated"
  )
  expect_identical(m, "distribution")

  # method wins over the deprecated mediation, with a warning
  expect_warning(
    m2 <- drmSEM:::drm_resolve_mediation(
      method = "gcomp",
      mediation = "distribution"
    ),
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
  new_tot <- total_effects(
    sem,
    "x",
    "y",
    method = "gcomp",
    uncertainty = "none",
    seed = 1
  )
  old_tot <- suppressWarnings(
    total_effects(sem, "x", "y", mediation = "mean", draw = FALSE, seed = 1)
  )
  expect_equal(new_tot$estimate, old_tot$estimate)
  expect_identical(new_tot$mediation, "mean")

  # indirect_effects: uncertainty="none"/nsim=1 == draw=FALSE/n_sim=1
  new_ie <- indirect_effects(
    sem,
    "x",
    "y",
    uncertainty = "none",
    nsim = 1,
    seed = 2
  )
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

  de <- direct_effects(
    sem,
    "x",
    "cnt",
    target = "p_zero",
    uncertainty = "none",
    nsim = 50,
    seed = 5
  )
  expect_s3_class(de, "drm_effect")
  expect_identical(de$target, "p_zero")
  expect_true(is.finite(de$estimate))
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
