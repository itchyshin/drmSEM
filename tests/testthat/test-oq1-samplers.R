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

test_that("OQ-1: zero_one_beta continuous (beta) parameterization matches drmTMB", {
  set.seed(3)
  n <- 1500

  # No boundary 0/1 observations: a zero_one_beta fit's continuous part is the
  # same beta(mu*phi, (1-mu)*phi), phi = 1/sigma^2, as the confirmed `beta`
  # sampler. With zoi/coi absent, drm_sample_family("zero_one_beta", ...)
  # degenerates to that beta draw, so the data moments must be recovered.
  yzob <- stats::rbeta(n, shape1 = 0.4 * 8, shape2 = 0.6 * 8)
  fzob <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::zero_one_beta(),
                         data = data.frame(y = yzob))
  expect_sampler_recovers("zero_one_beta", fzob, yzob)

  # TODO(live-drmTMB): once the zoi/coi-on-logit parameterization of a
  # zero_one_beta mediator is confirmed against a live fit, add a boundary-
  # inflated DGP here and assert recovery of P(0), P(1), and the conditional
  # beta moments. Not asserted yet (would fail CI if the mapping is wrong).
})

test_that("OQ-1: student sampler recovers the mean under drmTMB parameterization", {
  set.seed(4)
  n <- 3000

  # mu uses the identity link (high confidence), so mean recovery is asserted.
  # The Student variance is sigma^2 * nu/(nu-2) and is extremely sensitive to nu
  # near its lower bound; the response-scale nu (degrees of freedom) mapping is
  # not confirmed against a live fit here, so the variance is NOT asserted.
  # TODO(live-drmTMB): confirm drmTMB's response-scale `nu` for student, then
  # add a variance assertion (drm_sample_family uses mu + sigma*rt(df = nu)).
  ys <- 3 + 2 * stats::rt(n, df = 10)
  fs <- drmTMB::drmTMB(drmTMB::bf(y ~ 1), family = drmTMB::student(),
                       data = data.frame(y = ys))
  pr <- node_params(fs, "student")
  nu_b <- drm_fit_coef(fs, "nu")
  nu <- if (length(nu_b) && "(Intercept)" %in% names(nu_b)) {
    drm_inv_link("log", unname(nu_b[["(Intercept)"]]))
  } else {
    5
  }
  set.seed(99)
  draws <- drm_sample_family(
    "student",
    list(mu = rep(pr$mu, n * 100L), sigma = rep(pr$sigma, n * 100L),
         nu = rep(nu, n * 100L)),
    n * 100L
  )
  expect_lt(abs(mean(draws) - mean(ys)) / (abs(mean(ys)) + 1e-6), 0.06)
})
