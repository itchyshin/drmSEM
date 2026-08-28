# 0.3 — Latent & MIMIC Measurement Blocks.
#
# V-130  Grammar & specification of drm_latent() and drm_indicator()
# V-131  Cronbach's alpha and Raykov's rho composite reliability calculation
# V-132  2-cause, 3-indicator MIMIC model parameter recovery
# V-133  Interventions & distributional effect propagation through latent nodes to downstream sigma targets
# V-134  MAG m-separation projection with marginalized latents

test_data_latent <- function(n = 600, seed = 20260828) {
  set.seed(seed)
  x1 <- rnorm(n)
  x2 <- rnorm(n)
  # Latent construct: eta = 0.80*x1 - 0.50*x2 + zeta
  zeta <- rnorm(n, 0, 0.35)
  eta <- 0.80 * x1 - 0.50 * x2 + zeta

  # Indicators with marker y1 (lambda1 = 1.0)
  e1 <- rnorm(n, 0, 0.30)
  e2 <- rnorm(n, 0, 0.30)
  e3 <- rnorm(n, 0, 0.30)
  y1 <- 1.00 * eta + e1
  y2 <- 0.75 * eta + e2
  y3 <- 0.50 * eta + e3

  # Downstream response z with location-scale dependency on eta
  mu_z <- 1.5 + 1.2 * eta
  sigma_z <- exp(0.2 + 0.5 * eta)
  z <- rnorm(n, mean = mu_z, sd = sigma_z)

  data.frame(x1 = x1, x2 = x2, y1 = y1, y2 = y2, y3 = y3, z = z)
}

# ===========================================================================
# V-130: Grammar & Specification
# ===========================================================================

test_that("V-130: drm_indicator() creates and validates indicator declarations", {
  ind1 <- drm_indicator("y1", marker = TRUE)
  expect_s3_class(ind1, "drm_indicator")
  expect_identical(ind1$name, "y1")
  expect_true(ind1$marker)
  expect_null(ind1$loading)

  ind2 <- drm_indicator("y2", loading = 0.8)
  expect_false(ind2$marker)
  expect_equal(ind2$loading, 0.8)

  expect_error(drm_indicator(123), "single non-empty")
  expect_error(drm_indicator("y", loading = "bad"), "single numeric")
  expect_error(drm_indicator("y", marker = "bad"), "single logical")
})

test_that("V-130: drm_latent() supports mimic, reflective, and formative constructs", {
  dat <- test_data_latent(n = 50)

  # MIMIC construct with marker identification
  mimic_spec <- drm_latent(
    "eta",
    indicators = c("y1", "y2", "y3"),
    causes = c("x1", "x2"),
    type = "mimic",
    identification = "marker",
    marker = "y1",
    data = dat
  )
  expect_s3_class(mimic_spec, "drm_latent")
  expect_s3_class(mimic_spec, "drm_composite")
  expect_identical(mimic_spec$type, "mimic")
  expect_identical(mimic_spec$identification, "marker")
  expect_identical(mimic_spec$marker, "y1")
  expect_equal(unname(mimic_spec$loadings["y1"]), 1.0)
  expect_true(is.numeric(mimic_spec$composite_reliability))
  expect_true(is.numeric(mimic_spec$reliability))

  # Reflective construct with unit_variance identification
  refl_spec <- drm_latent(
    "eta",
    indicators = list(drm_indicator("y1"), drm_indicator("y2"), drm_indicator("y3")),
    type = "reflective",
    identification = "unit_variance",
    data = dat
  )
  expect_identical(refl_spec$type, "reflective")
  expect_identical(refl_spec$identification, "unit_variance")
  expect_equal(names(refl_spec$loadings), c("y1", "y2", "y3"))

  # Formative construct
  form_spec <- drm_latent(
    "comp",
    indicators = c("y1", "y2"),
    type = "formative",
    method = "fixed",
    weights = c(0.4, 0.6),
    data = dat
  )
  expect_identical(form_spec$type, "formative")
  expect_equal(unname(form_spec$loadings), c(0.4, 0.6))
})

test_that("V-130: drm_latent() rejects malformed declarations", {
  dat <- test_data_latent(n = 50)
  expect_error(drm_latent("eta", "y1", data = dat), "at least two")
  expect_error(drm_latent("eta", c("y1", "ghost"), data = dat), "not found")
  expect_error(drm_latent("eta", c("y1", "y2"), marker = "ghost", data = dat), "not among")
  expect_error(drm_latent(c("e1", "e2"), c("y1", "y2")), "single non-empty")
})

# ===========================================================================
# V-131: Reliability Calculation (Cronbach's alpha & Raykov's rho)
# ===========================================================================

test_that("V-131: tau-equivalent indicators yield alpha == rho", {
  # In a tau-equivalent model (equal loadings), Raykov's rho equals Cronbach's alpha
  set.seed(42)
  n <- 500
  eta <- rnorm(n)
  # All loadings = 1.0, error variance = 0.5^2
  y1 <- eta + rnorm(n, 0, 0.5)
  y2 <- eta + rnorm(n, 0, 0.5)
  y3 <- eta + rnorm(n, 0, 0.5)
  M <- cbind(y1, y2, y3)

  alpha_val <- drm_cronbach_alpha(M)
  rho_val <- drm_raykov_rho(M)

  expect_true(is.finite(alpha_val))
  expect_true(is.finite(rho_val))
  # With equal true loadings, rho and alpha agree closely
  expect_equal(alpha_val, rho_val, tolerance = 0.05)
})

test_that("V-131: congeneric indicators satisfy Raykov rho >= Cronbach alpha", {
  set.seed(42)
  n <- 1000
  eta <- rnorm(n)
  # Strongly unequal loadings (congeneric model)
  y1 <- 1.5 * eta + rnorm(n, 0, 0.3)
  y2 <- 0.8 * eta + rnorm(n, 0, 0.4)
  y3 <- 0.3 * eta + rnorm(n, 0, 0.6)
  M <- cbind(y1, y2, y3)

  alpha_val <- drm_cronbach_alpha(M)
  rho_val <- drm_raykov_rho(M)

  # Alpha is a lower bound to composite reliability for congeneric measures
  expect_gte(rho_val + 1e-4, alpha_val)
})

test_that("V-131: closed-form reliability recovery on known covariance matrix", {
  # Known parameters: factor var = 1.0, loadings = c(1.0, 0.8, 0.6), error var = c(0.25, 0.25, 0.25)
  lam <- c(y1 = 1.0, y2 = 0.8, y3 = 0.6)
  theta <- c(y1 = 0.25, y2 = 0.25, y3 = 0.25)
  # True composite reliability: (1.0 + 0.8 + 0.6)^2 / ((2.4)^2 + 0.75) = 5.76 / (5.76 + 0.75) = 5.76 / 6.51 = 0.8847926
  true_rho <- (sum(lam)^2) / (sum(lam)^2 + sum(theta))

  # Theoretical covariance matrix
  S <- outer(lam, lam) + diag(theta)
  # Generate large sample from N(0, S)
  set.seed(123)
  M <- MASS::mvrnorm(5000, mu = rep(0, 3), Sigma = S)

  recovered_rho <- drm_raykov_rho(M, loadings = lam, error_variances = theta, factor_var = 1.0)
  expect_equal(recovered_rho, true_rho, tolerance = 1e-4)

  # Also test edge case: single indicator returns NA
  expect_true(is.na(drm_raykov_rho(matrix(1:10, ncol = 1))))
  expect_true(is.na(drm_cronbach_alpha(matrix(1:10, ncol = 1))))
})

# ===========================================================================
# V-132: 2-Cause, 3-Indicator MIMIC Model Parameter Recovery
# ===========================================================================

test_that("V-132: 2-cause, 3-indicator MIMIC model parameter recovery", {
  skip_if_not_installed("drmTMB")

  dat <- test_data_latent(n = 800, seed = 20260828)

  # Fit piecewise SEM with MIMIC latent construct
  sem <- drm_sem(
    eta = drm_node(drmTMB::bf(eta ~ x1 + x2), family = stats::gaussian()),
    data = dat,
    latents = list(
      drm_latent(
        "eta",
        indicators = c("y1", "y2", "y3"),
        causes = c("x1", "x2"),
        type = "mimic",
        identification = "marker",
        marker = "y1"
      )
    )
  )

  expect_s3_class(sem, "drm_sem")

  # 1. Check structural paths: gamma1 = 0.80, gamma2 = -0.50
  pt <- paths(sem)
  expect_s3_class(pt, "drm_paths")

  b_x1 <- pt$estimate[pt$from == "x1" & pt$to == "eta"]
  b_x2 <- pt$estimate[pt$from == "x2" & pt$to == "eta"]

  expect_length(b_x1, 1L)
  expect_length(b_x2, 1L)
  expect_equal(b_x1, 0.80, tolerance = 0.15)
  expect_equal(b_x2, -0.50, tolerance = 0.15)

  # 2. Check measurement loadings: lambda1 = 1.00 (marker), lambda2 ~ 0.75, lambda3 ~ 0.50
  ld <- loadings(sem)
  expect_s3_class(ld, "drm_loadings")
  expect_true(all(c("composite", "indicator", "loading", "type", "identification") %in% names(ld)))

  l1 <- ld$loading[ld$composite == "eta" & ld$indicator == "y1"]
  l2 <- ld$loading[ld$composite == "eta" & ld$indicator == "y2"]
  l3 <- ld$loading[ld$composite == "eta" & ld$indicator == "y3"]

  expect_equal(l1, 1.00, tolerance = 1e-6)
  expect_equal(l2, 0.75, tolerance = 0.15)
  expect_equal(l3, 0.50, tolerance = 0.15)

  # 3. Structural paths and measurement loadings are strictly separated
  expect_false(any(pt$from %in% c("y1", "y2", "y3")))
  expect_false(any(pt$to %in% c("y1", "y2", "y3")))
  expect_false(any(ld$indicator %in% c("x1", "x2")))

  # 4. Reliability summary accessor
  rel <- reliability(sem)
  expect_s3_class(rel, "drm_reliability")
  expect_identical(rel$composite, "eta")
  expect_identical(rel$type, "mimic")
  expect_true(rel$rho > 0.70)
})

# ===========================================================================
# V-133: Interventions & Distributional Effect Propagation
# ===========================================================================

test_that("V-133: interventions on latent constructs and propagation to downstream sigma", {
  skip_if_not_installed("drmTMB")

  dat <- test_data_latent(n = 800, seed = 20260828)

  sem <- drm_sem(
    eta = drm_node(drmTMB::bf(eta ~ x1 + x2), family = stats::gaussian()),
    z = drm_node(drmTMB::bf(z ~ eta, sigma ~ eta), family = stats::gaussian()),
    data = dat,
    latents = list(
      drm_latent("eta", indicators = c("y1", "y2", "y3"), type = "mimic")
    )
  )

  # 1. Simulate intervention directly on the latent construct: do(eta) -> z
  eff_eta <- simulate_effects(sem, from = "eta", to = "z", uncertainty = "none")
  expect_s3_class(eff_eta, "drm_effect")
  expect_true(eff_eta$estimate > 0)

  # 2. Simulate intervention on cause x1 through latent eta to z: do(x1) -> eta -> z
  eff_x1 <- simulate_effects(sem, from = "x1", to = "z", uncertainty = "none")
  expect_s3_class(eff_x1, "drm_effect")
  expect_true(eff_x1$estimate > 0)

  # 3. Direct / indirect effect decomposition
  dir_eff <- direct_effects(sem, from = "x1", to = "z", uncertainty = "none")
  indir_eff <- indirect_effects(sem, from = "x1", to = "z", uncertainty = "none")

  expect_s3_class(dir_eff, "drm_effect")
  expect_s3_class(indir_eff, "drm_effect")
  # x1 has no direct edge to z, so direct effect is 0 and total is mediated via eta
  expect_equal(dir_eff$estimate, 0, tolerance = 0.05)
  indir_row <- indir_eff$estimate[indir_eff$quantity == "indirect"]
  expect_equal(indir_row, eff_x1$estimate, tolerance = 1e-2)

  # 4. Distributional channel: eta targets both mu and sigma of z
  pt <- paths(sem)
  expect_true(any(pt$from == "eta" & pt$to == "z" & pt$component == "mu"))
  expect_true(any(pt$from == "eta" & pt$to == "z" & pt$component == "sigma"))
})

# ===========================================================================
# V-134: MAG Projection with Marginalized Latents
# ===========================================================================

test_that("V-134: MAG m-separation projection with marginalized latents without spurious cycles", {
  # Test DAG with causes X -> L, indicators L -> Y1, L -> Y2, and downstream L -> Z
  # with L declared as marginalized latent:
  # In the MAG over {X, Y1, Y2, Z}:
  # - Inducing path Y1 <- L -> Y2 gives bidirected Y1 <-> Y2
  # - Inducing path Y1 <- L -> Z gives bidirected Y1 <-> Z
  # - Inducing path Y2 <- L -> Z gives bidirected Y2 <-> Z
  # - Inducing path X -> L -> Y1 gives directed X -> Y1
  # - Inducing path X -> L -> Y2 gives directed X -> Y2
  # - Inducing path X -> L -> Z gives directed X -> Z

  edges <- data.frame(
    from = c("X", "L", "L", "L"),
    to = c("L", "Y1", "Y2", "Z"),
    stringsAsFactors = FALSE
  )
  mag <- drmSEM:::drm_dag_to_mag(edges, latent = "L")

  # 1. Adjacency checks in the MAG
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "X", "Y1"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "X", "Y2"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "X", "Z"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "Y1", "Y2"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "Y1", "Z"))
  expect_true(drmSEM:::drm_mag_is_adjacent(mag, "Y2", "Z"))

  # 2. Check MAG edge types
  y1_y2_edge <- mag[mag$from %in% c("Y1", "Y2") & mag$to %in% c("Y1", "Y2"), ]
  expect_identical(y1_y2_edge$type, "<->")

  x_y1_edge <- mag[mag$from == "X" & mag$to == "Y1", ]
  expect_identical(x_y1_edge$type, "-->")

  # 3. Create a mock drm_sem with marginalized latent "L"
  mock_sem <- structure(
    list(
      order = c("Y1", "Y2", "Z"),
      endogenous = c("Y1", "Y2", "Z"),
      exogenous = "X",
      latents = "L",
      mag = mag,
      covariances = NULL,
      records = list(
        Y1 = list(family = "gaussian", components = "mu"),
        Y2 = list(family = "gaussian", components = "mu"),
        Z = list(family = "gaussian", components = "mu")
      )
    ),
    class = "drm_sem"
  )

  # 4. Basis set on the implied MAG: all observed pairs are adjacent, so 0 missing edges
  bs <- basis_set(mock_sem)
  expect_identical(nrow(bs), 0L)
})
