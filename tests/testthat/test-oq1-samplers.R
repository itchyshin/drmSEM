# OQ-1: confirm drmSEM's family samplers (drm_sample_family) match drmTMB's
# parameterization. For an intercept-only fit, drmSEM's effect engine produces a
# constant response-scale (mu, sigma) via inverse links; we feed those to
# drm_sample_family() and check the sampled mean/variance reproduce the data
# moments. A wrong dispersion parameterization (e.g. nbinom2 size = 1/sigma vs
# 1/sigma^2) shifts the variance well outside tolerance. Requires drmTMB; CI.

skip_if_not_installed("drmTMB")

# Constant response-scale parameters of an intercept-only node, exactly as the
# effect engine builds them: mu via the family link, sigma always via log.
node_params <- function(fit, family_name) {
  mu_b <- drm_fit_coef(fit, "mu")
  mu <- drm_inv_link(drm_nominal_link(family_name, "mu"), unname(mu_b[["(Intercept)"]]))
  sig_b <- drm_fit_coef(fit, "sigma")
  sigma <- if (length(sig_b) && "(Intercept)" %in% names(sig_b)) {
    drm_inv_link("log", unname(sig_b[["(Intercept)"]]))
  } else {
    1
  }
  list(mu = mu, sigma = sigma)
}

# Sample N draws at the fitted constant params and compare to the data moments.
expect_sampler_recovers <- function(family_name, fit, y, N = 2e5,
                                     mean_rtol = 0.06, var_rtol = 0.15, seed = 99) {
  pr <- node_params(fit, family_name)
  set.seed(seed)
  draws <- drm_sample_family(
    family_name, list(mu = rep(pr$mu, N), sigma = rep(pr$sigma, N)), N
  )
  dm <- mean(y); dv <- stats::var(y)
  rm <- mean(draws); rv <- stats::var(draws)
  info <- sprintf("%s: sampler(mean=%.4g,var=%.4g) vs data(mean=%.4g,var=%.4g) [mu=%.4g,sigma=%.4g]",
                  family_name, rm, rv, dm, dv, pr$mu, pr$sigma)
  expect_lt(abs(rm - dm) / (abs(dm) + 1e-6), mean_rtol, label = info)
  expect_lt(abs(rv - dv) / (abs(dv) + 1e-6), var_rtol, label = info)
}

test_that("OQ-1: count and continuous samplers match drmTMB parameterization", {
  set.seed(1)
  n <- 1500

  yg <- stats::rnorm(n, mean = 3, sd = 2)
  fg <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = stats::gaussian(),
                       data = data.frame(y = yg))
  expect_sampler_recovers("gaussian", fg, yg)

  yp <- stats::rpois(n, lambda = 4)
  fp <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = stats::poisson(),
                       data = data.frame(y = yp))
  expect_sampler_recovers("poisson", fp, yp)

  ynb <- stats::rnbinom(n, mu = 6, size = 2)            # var = 6 + 36/2 = 24
  fnb <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::nbinom2(),
                        data = data.frame(y = ynb))
  expect_sampler_recovers("nbinom2", fnb, ynb)
})

test_that("OQ-1: beta, lognormal, and Gamma samplers match drmTMB parameterization", {
  set.seed(2)
  n <- 1500

  yb <- stats::rbeta(n, shape1 = 0.4 * 8, shape2 = 0.6 * 8)
  fb <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::beta(),
                       data = data.frame(y = yb))
  expect_sampler_recovers("beta", fb, yb)

  yl <- stats::rlnorm(n, meanlog = 1.0, sdlog = 0.5)
  fl <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::lognormal(),
                       data = data.frame(y = yl))
  expect_sampler_recovers("lognormal", fl, yl)

  yga <- stats::rgamma(n, shape = 4, scale = 1.5)        # mean 6, var 9, CV = 0.5
  fga <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = stats::Gamma(link = "log"),
                        data = data.frame(y = yga))
  expect_sampler_recovers("Gamma", fga, yga)
})
