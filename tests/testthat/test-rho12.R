# OQ-14 / 0.4 — joint bivariate fit. Declaration tests live in test-pair.R
# (pure-R, estimate NA). These recover a known rho12 from a live drmTMB fit.

skip_if_not_installed("drmTMB")

simulate_const_rho12 <- function(n, rho, seed) {
  set.seed(seed)
  x <- stats::rnorm(n)
  e1 <- stats::rnorm(n)
  e2 <- rho * e1 + sqrt(1 - rho^2) * stats::rnorm(n)
  data.frame(
    activity = 0.2 + 0.5 * x + e1,
    boldness = -0.1 + 0.3 * x + e2,
    x = x
  )
}

simulate_tanh_rho12 <- function(n, b0, b1, seed) {
  set.seed(seed)
  x <- stats::rnorm(n)
  eta <- b0 + b1 * x
  rho <- 0.999999 * tanh(eta)
  e1 <- stats::rnorm(n)
  e2 <- rho * e1 + sqrt(pmax(1 - rho^2, 1e-8)) * stats::rnorm(n)
  data.frame(y1 = e1, y2 = e2, x = x)
}

test_that("drm_sem fits one joint bivariate pair and recovers constant rho12 (V-128)", {
  dat <- simulate_const_rho12(n = 400, rho = 0.45, seed = 20260828)
  pair <- drm_pair(activity ~ x, boldness ~ x)
  sem <- drm_sem(pair, data = dat)
  expect_identical(sort(sem$endogenous), c("activity", "boldness"))
  expect_true(drmSEM:::drm_is_bivariate_fit(sem$nodes$activity))
  expect_identical(sem$nodes$activity, sem$nodes$boldness)

  r <- rho12(sem)
  expect_s3_class(r, "drm_rho12")
  expect_identical(nrow(r), 1L)
  expect_identical(r$term, "(Intercept)")
  expect_identical(r$link, "tanh")
  expect_false(is.na(r$estimate))
  expect_false(is.na(r$std.error))
  expect_false(is.na(r$p.value))
  # response-scale intercept vs true residual correlation
  expect_lt(abs(tanh(r$estimate) - 0.45), 0.12)

  bs <- basis_set(sem)
  expect_false(any(
    (bs$x == "activity" & bs$y == "boldness") |
      (bs$x == "boldness" & bs$y == "activity")
  ))
})

test_that("rho12 ~ x recovers the tanh-link intercept and slope (V-129)", {
  b0 <- 0.20
  b1 <- 0.50
  dat <- simulate_tanh_rho12(n = 600, b0 = b0, b1 = b1, seed = 20260828)
  pair <- drm_pair(y1 ~ 1, y2 ~ 1, rho12 = ~x)
  sem <- drm_sem(pair, data = dat)
  r <- rho12(sem)
  expect_identical(sort(r$term), c("(Intercept)", "x"))
  int <- r$estimate[r$term == "(Intercept)"]
  sl <- r$estimate[r$term == "x"]
  expect_lt(abs(int - b0), 0.15)
  expect_lt(abs(sl - b1), 0.15)
  expect_lt(r$p.value[r$term == "x"], 0.05)

  pth <- paths(sem)
  expect_true(any(pth$component == "rho12" & pth$from == "x"))
  expect_false(any(pth$component == "rho12" & pth$from %in% c("y1", "y2")))
})

test_that("drm_psem consumes a bivariate drmTMB fit as two nodes", {
  dat <- simulate_const_rho12(n = 200, rho = 0.35, seed = 7)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(
      mu1 = activity ~ x,
      mu2 = boldness ~ x,
      sigma1 = ~1,
      sigma2 = ~1,
      rho12 = ~1
    ),
    family = drmTMB::biv_gaussian(),
    data = dat,
    control = drmTMB::drm_control(se = TRUE)
  )
  sem <- drm_psem(fit, data = dat)
  expect_identical(sort(sem$endogenous), c("activity", "boldness"))
  r <- rho12(sem)
  expect_false(is.na(r$estimate[[1L]]))
  expect_lt(abs(tanh(r$estimate[[1L]]) - 0.35), 0.20)
  expect_true(any(covariances(sem)$class == "residual"))
})

test_that("mixed pair families abort before fitting", {
  expect_error(
    drmSEM:::drm_pair_joint_family(drm_pair(
      activity ~ x,
      boldness ~ x,
      family = stats::gaussian(),
      family2 = drmTMB::lognormal()
    )),
    "same family"
  )
})
