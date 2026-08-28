# ---------------------------------------------------------------------------
# Track 2: Full Bootstrap & Marginal Population Integration Engine (OQ-9 / OQ-10)
# Validation tests V-142 .. V-144
# ---------------------------------------------------------------------------

test_that("V-142: Bootstrap confidence interval coverage calibration", {
  skip_if_not_installed("drmTMB")
  set.seed(42)

  # DGP: simple mediation chain with known parameters
  # x -> m (beta = 0.5), m -> y (beta = 0.8), direct x -> y = 0
  n <- 120
  x <- stats::rnorm(n, mean = 2, sd = 1)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.4)
  y <- 0.8 * m + stats::rnorm(n, sd = 0.4)
  dat <- data.frame(x = x, m = m, y = y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = dat
  )

  # True direct effect of x on m: 0.5 * sd(x) ~ 0.5 * 1.0 = 0.5
  true_effect_xm <- 0.5 * stats::sd(x)

  de <- direct_effects(
    sem,
    from = "x",
    to = "m",
    uncertainty = "bootstrap",
    B = 40L,
    seed = 123L
  )

  expect_s3_class(de, "drm_effect")
  expect_true(is.finite(de$estimate))
  expect_true(is.finite(de$std.error))
  expect_gt(de$std.error, 0)
  expect_true(is.finite(de$conf.low))
  expect_true(is.finite(de$conf.high))
  expect_lt(de$conf.low, de$conf.high)

  # Point estimate and bootstrap interval bracket the true DGP effect
  expect_lte(de$conf.low, true_effect_xm)
  expect_gte(de$conf.high, true_effect_xm)

  # Check normal approximation interval attribute
  norm_ci <- attr(de, "boot_ci_normal")
  expect_length(norm_ci, 2L)
  expect_lte(norm_ci[[1L]], true_effect_xm)
  expect_gte(norm_ci[[2L]], true_effect_xm)

  # Indirect effect bootstrap decomposition
  ie <- indirect_effects(
    sem,
    from = "x",
    to = "y",
    uncertainty = "bootstrap",
    B = 30L,
    seed = 456L
  )
  expect_s3_class(ie, "drm_effect")
  expect_true(all(is.finite(ie$estimate)))
  expect_true(all(is.finite(ie$std.error)))
  expect_true(all(ie$conf.low <= ie$conf.high))
})

test_that("V-143: Cluster bootstrap maintaining valid uncertainty under clustered data", {
  skip_if_not_installed("drmTMB")
  set.seed(101)

  # DGP: 15 clusters of size 10
  n_clust <- 15
  n_per <- 10
  n <- n_clust * n_per
  g <- factor(rep(seq_len(n_clust), each = n_per))
  u_g <- stats::rnorm(n_clust, sd = 0.8)
  names(u_g) <- levels(g)

  x <- stats::rnorm(n) + u_g[g] * 0.5
  y <- 0.6 * x + u_g[g] + stats::rnorm(n, sd = 0.5)
  dat <- data.frame(x = x, y = y, g = g)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x + (1 | g)), family = stats::gaussian()),
    data = dat
  )

  # Ensure cluster grouping variable was extracted
  g_vars <- drmSEM:::drm_sem_grouping_vars(sem)
  expect_true("g" %in% g_vars)

  # Cluster bootstrap
  eff <- total_effects(
    sem,
    from = "x",
    to = "y",
    uncertainty = "bootstrap",
    B = 30L,
    seed = 789L
  )

  expect_s3_class(eff, "drm_effect")
  expect_true(is.finite(eff$estimate))
  expect_true(is.finite(eff$std.error))
  expect_gt(eff$std.error, 0)
  expect_true(is.finite(eff$conf.low))
  expect_true(is.finite(eff$conf.high))

  # True DGP slope is 0.6; effect is 0.6 * sd(x)
  true_tot <- 0.6 * stats::sd(x)
  expect_lte(eff$conf.low, true_tot)
  expect_gte(eff$conf.high, true_tot)
})

test_that("V-144: Marginal population effect matching analytical population average for nonlinear link", {
  skip_if_not_installed("drmTMB")
  set.seed(202)

  # 1. Log link: E_b[exp(eta + b)] = exp(eta + 0.5 * sigma_re^2)
  # Theoretical ratio marginal / conditional = exp(0.5 * sigma_re^2)
  sigma_re <- 0.6
  n_clust <- 20
  n_per <- 15
  n <- n_clust * n_per
  g <- factor(rep(seq_len(n_clust), each = n_per))
  u_g <- stats::rnorm(n_clust, sd = sigma_re)
  names(u_g) <- levels(g)

  x <- stats::rnorm(n, mean = 0, sd = 1)
  eta <- 0.5 + 0.4 * x + u_g[g]
  y_pois <- stats::rpois(n, lambda = exp(eta))
  dat <- data.frame(x = x, y = y_pois, g = g)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x + (1 | g)), family = stats::poisson()),
    data = dat
  )

  eff_cond <- direct_effects(
    sem,
    from = "x",
    to = "y",
    population = "conditional",
    uncertainty = "none"
  )
  eff_marg <- direct_effects(
    sem,
    from = "x",
    to = "y",
    population = "marginal",
    uncertainty = "none"
  )

  expect_true(is.finite(eff_cond$estimate))
  expect_true(is.finite(eff_marg$estimate))

  # Extract estimated random effect SD from fitted model
  fit_sd <- drmSEM:::drm_fit_component_sdpar(sem$nodes$y, "mu")
  expect_gt(fit_sd, 0)

  # Analytical multiplier: exp(0.5 * fit_sd^2)
  analytical_ratio <- exp(0.5 * fit_sd^2)
  empirical_ratio <- eff_marg$estimate / eff_cond$estimate

  expect_equal(empirical_ratio, analytical_ratio, tolerance = 1e-3)

  # 2. Logit link: Gauss-Hermite integration matches sample-integrated quadrature
  eta_test <- seq(-2, 2, length.out = 5)
  gh_marg <- drmSEM:::drm_marginalize_link("logit", eta_test, sigma_re = 0.5)

  # Compare with fine Monte-Carlo integration
  b_large <- stats::rnorm(100000, mean = 0, sd = 0.5)
  mc_marg <- vapply(eta_test, function(et) mean(stats::plogis(et + b_large)), numeric(1))

  expect_equal(gh_marg, mc_marg, tolerance = 0.01)
})
