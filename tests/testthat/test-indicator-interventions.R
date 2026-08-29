# ===========================================================================
# Indicator-Level Interventional Counterfactuals (OQ-15, V-148..V-150)
#
# Interventions on indicator variables do(x_ind = c) of composite or latent
# constructs (drm_composite(), drm_latent()) dynamically re-evaluate the construct
# score in counterfactual scenarios so the effect propagates through
# do(x_ind) -> construct -> downstream response/distributional nodes.
# ===========================================================================

# ---- V-148: Formative / composite indicator intervention --------------------

test_that("V-148: composite indicator intervention do(x1 = 2) -> construct -> y recovers analytic Delta y = w1 * beta", {
  skip_if_not_installed("drmTMB")

  set.seed(20260828)
  n <- 500L
  x1 <- rnorm(n, 0, 1)
  x2 <- rnorm(n, 0, 1)
  x3 <- rnorm(n, 0, 1)

  # Explicit known weights
  w1 <- 0.5
  w2 <- 0.3
  w3 <- 0.2
  C <- w1 * x1 + w2 * x2 + w3 * x3

  beta0 <- 1.0
  beta1 <- 1.5
  y <- beta0 + beta1 * C + rnorm(n, 0, 0.1)

  dat <- data.frame(x1 = x1, x2 = x2, x3 = x3, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ C), family = stats::gaussian()),
    data = dat,
    composites = list(
      drm_composite("C", indicators = c("x1", "x2", "x3"), weights = c(w1, w2, w3), method = "fixed", standardize = FALSE, data = dat)
    )
  )

  # Intervene on indicator x1 from 0 to 2 (Delta x1 = 2)
  # Analytic Delta C = w1 * Delta x1 = 0.5 * 2 = 1.0
  # Analytic Delta y = beta1 * Delta C = 1.5 * 1.0 = 1.5
  eff <- total_effects(sem, from = "x1", to = "y", at = c(0, 2), uncertainty = "none")

  expect_s3_class(eff, "drm_effect")
  expect_equal(eff$from, "x1")
  expect_equal(eff$to, "y")
  expect_equal(eff$estimate, 1.5, tolerance = 0.05)

  # Direct effect holding construct fixed must be 0
  dir <- direct_effects(sem, from = "x1", to = "y", at = c(0, 2), uncertainty = "none")
  expect_equal(dir$estimate, 0, tolerance = 1e-6)

  # PCA-based composite indicator intervention
  sem_pca <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ C_pca), family = stats::gaussian()),
    data = dat,
    composites = list(
      drm_composite("C_pca", indicators = c("x1", "x2", "x3"), method = "pca", standardize = FALSE, data = dat)
    )
  )

  comp_spec <- sem_pca$composites[[1L]]
  w1_pca <- comp_spec$scoring_weights[["x1"]]
  pt_pca <- paths(sem_pca)
  beta_fit <- pt_pca$estimate[pt_pca$from == "C_pca" & pt_pca$to == "y"]
  expected_delta_y <- w1_pca * beta_fit * 2

  eff_pca <- total_effects(sem_pca, from = "x1", to = "y", at = c(0, 2), uncertainty = "none")
  expect_equal(eff_pca$estimate, expected_delta_y, tolerance = 1e-5)
})

# ---- V-149: MIMIC indicator intervention with distributional child ----------

test_that("V-149: MIMIC indicator intervention propagates to downstream distributional parameter sigma", {
  skip_if_not_installed("drmTMB")

  set.seed(20260828)
  n <- 600L
  x1 <- rnorm(n, 0, 1)
  x2 <- rnorm(n, 0, 1)
  eta <- 0.8 * x1 - 0.5 * x2 + rnorm(n, 0, 0.3)

  # Reflective indicators
  y1 <- eta + rnorm(n, 0, 0.2)
  y2 <- 0.8 * eta + rnorm(n, 0, 0.2)
  y3 <- 0.6 * eta + rnorm(n, 0, 0.2)

  # Distributional child z with location and dispersion depending on eta
  mu_z <- 1.5 + 1.2 * eta
  log_sigma_z <- 0.3 + 0.5 * eta
  z <- rnorm(n, mean = mu_z, sd = exp(log_sigma_z))

  dat <- data.frame(x1 = x1, x2 = x2, y1 = y1, y2 = y2, y3 = y3, z = z)

  sem <- drm_sem(
    eta = drm_node(drmTMB::bf(eta ~ x1 + x2), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ eta, sigma ~ eta), family = stats::gaussian()),
    data = dat,
    latents = list(
      drm_latent("eta", indicators = c("y1", "y2", "y3"), type = "mimic")
    )
  )

  # 1. Total effect on mean of z from intervening on indicator y1
  eff_mean <- total_effects(sem, from = "y1", to = "z", at = c(0, 1), target = "mean", uncertainty = "none")
  expect_s3_class(eff_mean, "drm_effect")
  expect_true(eff_mean$estimate > 0)

  # 2. Total effect on var (distributional dispersion functional) from intervening on indicator y1
  eff_var <- total_effects(
    sem,
    from = "y1",
    to = "z",
    at = c(0, 1),
    target = "var",
    uncertainty = "none",
    nsim = 100L
  )
  expect_s3_class(eff_var, "drm_effect")
  expect_true(eff_var$estimate > 0)

  # 3. Direct effect on z holding eta fixed is 0
  dir <- direct_effects(sem, from = "y1", to = "z", at = c(0, 1), uncertainty = "none")
  expect_equal(dir$estimate, 0, tolerance = 1e-6)
})

# ---- V-150: Indirect effect decomposition (100% mediation through construct) -

test_that("V-150: indirect effect decomposition demonstrates 100% mediation through construct for indicator intervention", {
  skip_if_not_installed("drmTMB")

  set.seed(20260828)
  n <- 500L
  x1 <- rnorm(n, 0, 1)
  x2 <- rnorm(n, 0, 1)
  x3 <- rnorm(n, 0, 1)

  w1 <- 0.4
  w2 <- 0.6
  w3 <- 0.5
  C <- w1 * x1 + w2 * x2 + w3 * x3

  beta_c <- 2.0
  y <- 0.5 + beta_c * C + rnorm(n, 0, 0.1)

  dat <- data.frame(x1 = x1, x2 = x2, x3 = x3, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ C), family = stats::gaussian()),
    data = dat,
    composites = list(
      drm_composite("C", indicators = c("x1", "x2", "x3"), weights = c(w1, w2, w3), method = "fixed", standardize = FALSE, data = dat)
    )
  )

  # Total effect of intervening on x1
  tot <- total_effects(sem, from = "x1", to = "y", at = c(-1, 1), uncertainty = "none")
  # Delta x1 = 2 -> Delta C = 0.4 * 2 = 0.8 -> Delta y = 2.0 * 0.8 = 1.6
  expect_equal(tot$estimate, 1.6, tolerance = 0.05)

  # Direct effect holding construct fixed
  dir <- direct_effects(sem, from = "x1", to = "y", at = c(-1, 1), uncertainty = "none")
  expect_equal(dir$estimate, 0, tolerance = 1e-6)

  # Indirect effect with explicit through = "C"
  ind_exp <- indirect_effects(sem, from = "x1", to = "y", through = "C", at = c(-1, 1), uncertainty = "none")
  expect_s3_class(ind_exp, "drm_effect")

  tot_path <- ind_exp$estimate[ind_exp$quantity == "total_path"]
  direct_val <- ind_exp$estimate[ind_exp$quantity == "direct"]
  indirect_val <- ind_exp$estimate[ind_exp$quantity == "indirect"]
  mean_med <- ind_exp$estimate[ind_exp$quantity == "mean_mediated"]

  expect_equal(direct_val, 0, tolerance = 1e-6)
  expect_equal(indirect_val, tot$estimate, tolerance = 1e-5)
  expect_equal(tot_path, tot$estimate, tolerance = 1e-5)
  expect_equal(mean_med, tot$estimate, tolerance = 1e-5)

  # Indirect effect with default through = NULL (auto-detects construct)
  ind_def <- indirect_effects(sem, from = "x1", to = "y", at = c(-1, 1), uncertainty = "none")
  expect_equal(ind_def$estimate[ind_def$quantity == "indirect"], tot$estimate, tolerance = 1e-5)

  # Model with BOTH direct edge and construct path: y ~ C + x1
  # DGP: y = 0.5 + 2.0 * C + 0.7 * x1 + e
  # Total effect = 1.6 (via C) + 0.7 * 2 = 1.6 + 1.4 = 3.0
  # Direct effect = 0.7 * 2 = 1.4
  # Indirect effect = 1.6
  y_direct <- 0.5 + beta_c * C + 0.7 * x1 + rnorm(n, 0, 0.1)
  dat_dir <- data.frame(x1 = x1, x2 = x2, x3 = x3, y = y_direct)

  sem_dir <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ C + x1), family = stats::gaussian()),
    data = dat_dir,
    composites = list(
      drm_composite("C", indicators = c("x1", "x2", "x3"), weights = c(w1, w2, w3), method = "fixed", standardize = FALSE, data = dat_dir)
    )
  )

  tot_both <- total_effects(sem_dir, from = "x1", to = "y", at = c(-1, 1), uncertainty = "none")
  dir_both <- direct_effects(sem_dir, from = "x1", to = "y", at = c(-1, 1), uncertainty = "none")
  ind_both <- indirect_effects(sem_dir, from = "x1", to = "y", through = "C", at = c(-1, 1), uncertainty = "none")

  expect_equal(tot_both$estimate, 3.0, tolerance = 0.05)
  expect_equal(dir_both$estimate, 1.4, tolerance = 0.05)
  expect_equal(ind_both$estimate[ind_both$quantity == "indirect"], 1.6, tolerance = 0.05)
  expect_equal(dir_both$estimate + ind_both$estimate[ind_both$quantity == "indirect"], tot_both$estimate, tolerance = 1e-5)
})
