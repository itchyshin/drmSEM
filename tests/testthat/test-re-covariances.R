# OQ-14 / Track 2 — Deep RE-Level Covariance Compatibility & Higher-Level RE Correlation
# Tests for V-151, V-152, V-153.

# Helper: simulate bivariate data with correlated random intercepts at `id` level
simulate_biv_re_data <- function(n_grp = 50, n_per = 8, rho_u = 0.60, seed = 42) {
  set.seed(seed)
  n <- n_grp * n_per
  id <- rep(paste0("ID_", seq_len(n_grp)), each = n_per)

  # Covariance matrix for random intercepts
  sd_u1 <- 1.0
  sd_u2 <- 1.2
  cov_12 <- rho_u * sd_u1 * sd_u2
  u_cov <- matrix(c(sd_u1^2, cov_12, cov_12, sd_u2^2), 2, 2)
  u <- MASS::mvrnorm(n_grp, mu = c(0, 0), Sigma = u_cov)

  idx <- as.integer(factor(id))
  u1 <- u[idx, 1]
  u2 <- u[idx, 2]

  x <- stats::rnorm(n)
  e1 <- stats::rnorm(n, sd = 0.5)
  e2 <- stats::rnorm(n, sd = 0.5)

  data.frame(
    activity = 0.5 * x + u1 + e1,
    boldness = -0.3 * x + u2 + e2,
    x = x,
    id = id,
    stringsAsFactors = FALSE
  )
}

# ---- V-151: Level-compatibility validation ------------------------------------

test_that("higher-level covariance fails validation when RE levels are mismatched (V-151)", {
  dat <- data.frame(
    y1 = rnorm(20),
    y2 = rnorm(20),
    x = rnorm(20),
    site = rep(paste0("S", 1:5), each = 4),
    species = rep(paste0("SP", 1:4), each = 5),
    stringsAsFactors = FALSE
  )

  # y1 has (1 | site), y2 has (1 | species) -> covary at level "site" must fail
  expect_error(
    drm_sem(
      y1 = drm_node(y1 ~ x + (1 | site)),
      y2 = drm_node(y2 ~ x + (1 | species)),
      covariances = covary("y1", "y2", level = "site"),
      data = dat
    ),
    "level-compatibility validation"
  )

  # Node y2 has no random effects -> covary at level "site" must fail
  expect_error(
    drm_sem(
      y1 = drm_node(y1 ~ x + (1 | site)),
      y2 = drm_node(y2 ~ x),
      covariances = covary("y1", "y2", level = "site"),
      data = dat
    ),
    "level-compatibility validation"
  )

  # Both nodes have matching (1 | site) -> validation passes
  sem_ok <- drm_sem(
    y1 = drm_node(y1 ~ x + (1 | site)),
    y2 = drm_node(y2 ~ x + (1 | site)),
    covariances = covary("y1", "y2", level = "site"),
    data = dat
  )
  expect_s3_class(sem_ok, "drm_sem")
  expect_identical(covariances(sem_ok)$level, "site")
})

# ---- V-152: Extraction of higher-level corpair estimates ---------------------

test_that("higher-level corpair estimates are extracted from fitted models with shared RE structure (V-152)", {
  skip_if_not_installed("drmTMB")

  true_rho <- 0.60
  dat <- simulate_biv_re_data(n_grp = 50, n_per = 8, rho_u = true_rho, seed = 42)

  # 1. Declarative drm_pair in drm_sem
  pair <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id))
  sem <- drm_sem(pair, data = dat)
  expect_s3_class(sem, "drm_sem")

  cp <- corpairs(sem)
  expect_s3_class(cp, "drm_corpairs")
  expect_identical(nrow(cp), 1L)
  expect_identical(cp$level, "id")
  expect_identical(sort(c(cp$y1, cp$y2)), c("activity", "boldness"))
  expect_false(is.na(cp$estimate))
  # Estimate should recover known DGP correlation
  expect_lt(abs(cp$estimate - true_rho), 0.20)

  # Check covariances table has both residual rho12 and higher-level corpair
  cv <- covariances(sem)
  expect_s3_class(cv, "drm_covariances")
  expect_identical(sort(cv$class), c("higher_level", "residual"))
  expect_identical(cv$level[cv$class == "higher_level"], "id")

  # 2. Consuming an already-fitted bivariate drmTMB model via drm_psem
  fit_biv <- drmTMB::drmTMB(
    drmTMB::bf(
      mu1 = activity ~ x + (1 | p_id | id),
      mu2 = boldness ~ x + (1 | p_id | id),
      sigma1 = ~1,
      sigma2 = ~1,
      rho12 = ~1
    ),
    family = drmTMB::biv_gaussian(),
    data = dat,
    control = drmTMB::drm_control(se = TRUE)
  )
  psem <- drm_psem(fit_biv, data = dat)
  expect_s3_class(psem, "drm_sem")

  cp_psem <- corpairs(psem)
  expect_s3_class(cp_psem, "drm_corpairs")
  expect_identical(cp_psem$level, "id")
  expect_false(is.na(cp_psem$estimate))
  expect_lt(abs(cp_psem$estimate - true_rho), 0.20)

  # 3. Piecewise univariate models with declared higher-level covariance have NA estimate
  sem_pw <- drm_sem(
    activity = drm_node(activity ~ x + (1 | id)),
    boldness = drm_node(boldness ~ x + (1 | id)),
    covariances = covary("activity", "boldness", level = "id"),
    data = dat
  )
  cp_pw <- corpairs(sem_pw)
  expect_s3_class(cp_pw, "drm_corpairs")
  expect_identical(cp_pw$level, "id")
  expect_true(is.na(cp_pw$estimate)) # piecewise cannot estimate joint RE cov without joint model
})

# ---- V-153: d-separation suppression for higher-level RE covariances ---------

test_that("d-separation suppresses independence claims for higher-level RE covariance pairs (V-153)", {
  dat <- data.frame(
    y1 = rnorm(30),
    y2 = rnorm(30),
    x = rnorm(30),
    site = rep(paste0("S", 1:6), each = 5),
    stringsAsFactors = FALSE
  )

  # Without covariance declaration: y1 and y2 are sibling non-adjacent nodes -> claim present
  sem_no_cov <- drm_sem(
    y1 = drm_node(y1 ~ x + (1 | site)),
    y2 = drm_node(y2 ~ x + (1 | site)),
    data = dat
  )
  bs_no_cov <- basis_set(sem_no_cov)
  expect_true(any(
    (bs_no_cov$x == "y1" & bs_no_cov$y == "y2") |
      (bs_no_cov$x == "y2" & bs_no_cov$y == "y1")
  ))

  # With higher-level covariance declaration at level "site": claim is suppressed
  sem_with_cov <- drm_sem(
    y1 = drm_node(y1 ~ x + (1 | site)),
    y2 = drm_node(y2 ~ x + (1 | site)),
    covariances = covary("y1", "y2", level = "site"),
    data = dat
  )
  bs_with_cov <- basis_set(sem_with_cov)
  expect_false(any(
    (bs_with_cov$x == "y1" & bs_with_cov$y == "y2") |
      (bs_with_cov$x == "y2" & bs_with_cov$y == "y1")
  ))

  # dsep() emits a warning that the graph is saturated when basis set is empty
  expect_warning(
    d <- dsep(sem_with_cov),
    "saturated|empty"
  )
  expect_s3_class(d, "drm_dsep")
})
