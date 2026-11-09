# Closed-form outcome functionals (drm_analytic_functional) and the realized-value
# / expected-mean helpers in R/simulate_effects.R. Each family/target is checked
# against an independent truth: a hand-derived moment, the family's own
# CDF/quantile functions, or a large seeded Monte-Carlo draw. No drmTMB fit.

af <- function(family, target, threshold = 0, prob = 0.5, ...) {
  drmSEM:::drm_analytic_functional(
    family, list(...), target = target, threshold = threshold, prob = prob
  )
}

# ---- zero-inflated Poisson -----------------------------------------------------

test_that("Poisson with zi reproduces the zero-inflated-Poisson moments and tail", {
  mu <- c(0.8, 2.5)
  zi <- c(0.1, 0.3)
  expect_equal(af("poisson", "mean", mu = mu, zi = zi), (1 - zi) * mu)
  # ZIP variance: (1 - pi) mu (1 + pi mu)
  expect_equal(af("poisson", "var", mu = mu, zi = zi), (1 - zi) * mu * (1 + zi * mu))
  # P(Y = 0) = pi + (1 - pi) exp(-mu)
  expect_equal(af("poisson", "p_zero", mu = mu, zi = zi), zi + (1 - zi) * exp(-mu))
  # P(Y > 2) summed explicitly from the Poisson pmf (single-row parameters: the
  # threshold branches of p_gt return one value, see the PR note on p_gt)
  tail2 <- 1 - exp(-mu[2]) * (1 + mu[2] + mu[2]^2 / 2)
  expect_equal(af("poisson", "p_gt", threshold = 2, mu = mu[2], zi = zi[2]), (1 - zi[2]) * tail2)
  # a negative threshold is exceeded with certainty
  expect_equal(af("poisson", "p_gt", threshold = -1, mu = mu[2], zi = zi[2]), 1)
})

test_that("Poisson quantile is the smallest q whose zero-inflated CDF reaches prob", {
  mu <- 2.5
  zi <- 0.3
  zip_cdf <- function(q) zi + (1 - zi) * stats::ppois(q, mu)
  for (p in c(0.5, 0.8, 0.95)) {
    q <- af("poisson", "quantile", prob = p, mu = mu, zi = zi)
    expect_gte(zip_cdf(q), p)
    expect_lt(zip_cdf(q - 1), p)
  }
  # probabilities at or below the structural-zero mass sit at 0
  expect_equal(af("poisson", "quantile", prob = 0.2, mu = mu, zi = zi), 0)
})

# ---- lognormal / Gamma / nbinom2 with zero inflation --------------------------------

test_that("lognormal functionals match closed forms and a Monte-Carlo draw", {
  mu <- 0.5
  sg <- 0.4
  zi <- 0.2
  expect_equal(af("lognormal", "mean", mu = mu, sigma = sg, zi = zi), 0.8 * exp(mu + sg^2 / 2))
  set.seed(1)
  n <- 4e5
  y <- stats::rlnorm(n, mu, sg) * (stats::runif(n) >= zi)
  expect_equal(af("lognormal", "var", mu = mu, sigma = sg, zi = zi), stats::var(y), tolerance = 0.03)
  expect_equal(af("lognormal", "p_zero", mu = mu, sigma = sg, zi = zi), zi)
  expect_equal(
    af("lognormal", "p_gt", threshold = 2, mu = mu, sigma = sg, zi = zi),
    mean(y > 2),
    tolerance = 0.01
  )
  # a non-positive threshold is exceeded by every non-zero draw
  expect_equal(af("lognormal", "p_gt", threshold = 0, mu = mu, sigma = sg, zi = zi), 1 - zi)
  expect_equal(af("lognormal", "quantile", prob = 0.1, mu = mu, sigma = sg, zi = zi), 0)
  q <- af("lognormal", "quantile", prob = 0.6, mu = mu, sigma = sg, zi = zi)
  expect_equal(zi + (1 - zi) * stats::plnorm(q, mu, sg), 0.6, tolerance = 1e-10)
  expect_null(af("lognormal", "bogus", mu = mu, sigma = sg))
})

test_that("Gamma functionals match closed forms (mean, variance, zero mass, tail, quantile)", {
  mu <- 3
  sg <- 0.5
  zi <- 0.25
  expect_equal(af("Gamma", "mean", mu = mu, sigma = sg, zi = zi), 0.75 * mu)
  # E[Y^2] = (1 - pi) mu^2 (1 + sigma^2) for a Gamma with CV sigma
  ey2 <- 0.75 * mu^2 * (1 + sg^2)
  expect_equal(af("Gamma", "var", mu = mu, sigma = sg, zi = zi), ey2 - (0.75 * mu)^2)
  expect_equal(af("gamma", "var", mu = mu, sigma = sg, zi = zi), ey2 - (0.75 * mu)^2)
  expect_equal(af("Gamma", "p_zero", mu = mu, sigma = sg, zi = zi), zi)
  expect_equal(af("Gamma", "p_gt", threshold = 0, mu = mu, sigma = sg, zi = zi), 0.75)
  shape <- 1 / sg^2
  expect_equal(
    af("Gamma", "p_gt", threshold = 4, mu = mu, sigma = sg, zi = zi),
    0.75 * stats::pgamma(4, shape = shape, scale = mu / shape, lower.tail = FALSE)
  )
  expect_equal(af("Gamma", "quantile", prob = 0.2, mu = mu, sigma = sg, zi = zi), 0)
  q <- af("Gamma", "quantile", prob = 0.7, mu = mu, sigma = sg, zi = zi)
  expect_equal(zi + 0.75 * stats::pgamma(q, shape = shape, scale = mu / shape), 0.7, tolerance = 1e-10)
  expect_null(af("Gamma", "bogus", mu = mu, sigma = sg))
})

test_that("nbinom2 functionals match closed forms (size = 1 / sigma^2)", {
  mu <- 4
  sg <- 0.6
  zi <- 0.2
  size <- 1 / sg^2
  expect_equal(af("nbinom2", "mean", mu = mu, sigma = sg, zi = zi), 0.8 * mu)
  # Var(NB2) = mu + sigma^2 mu^2;  E[Y^2] = (1 - pi)(Var + mu^2)
  ey2 <- 0.8 * (mu + sg^2 * mu^2 + mu^2)
  expect_equal(af("nbinom2", "var", mu = mu, sigma = sg, zi = zi), ey2 - (0.8 * mu)^2)
  expect_equal(
    af("nbinom2", "p_zero", mu = mu, sigma = sg, zi = zi),
    zi + 0.8 * (size / (size + mu))^size
  )
  expect_equal(
    af("nbinom2", "p_gt", threshold = 3, mu = mu, sigma = sg, zi = zi),
    0.8 * stats::pnbinom(3, size = size, mu = mu, lower.tail = FALSE)
  )
  expect_equal(af("nbinom2", "p_gt", threshold = -2, mu = mu, sigma = sg, zi = zi), 1)
  cdf <- function(q) zi + 0.8 * stats::pnbinom(q, size = size, mu = mu)
  q <- af("nbinom2", "quantile", prob = 0.9, mu = mu, sigma = sg, zi = zi)
  expect_gte(cdf(q), 0.9)
  expect_lt(cdf(q - 1), 0.9)
  expect_equal(af("nbinom2", "quantile", prob = 0.1, mu = mu, sigma = sg, zi = zi), 0)
})

# ---- beta / student ----------------------------------------------------------------

test_that("beta functionals follow phi = 1 / sigma^2 and clamp the boundary", {
  mu <- c(0.3, 0.6)
  sg <- c(0.5, 0.5)
  phi <- 1 / sg^2
  expect_equal(af("beta", "mean", mu = mu, sigma = sg), mu)
  expect_equal(af("beta", "var", mu = mu, sigma = sg), mu * (1 - mu) / (1 + phi))
  expect_equal(af("beta", "p_zero", mu = mu, sigma = sg), c(0, 0))
  expect_equal(
    af("beta", "p_gt", threshold = 0.5, mu = mu[1], sigma = sg[1]),
    stats::pbeta(0.5, mu[1] * phi[1], (1 - mu[1]) * phi[1], lower.tail = FALSE)
  )
  # support limits
  expect_equal(af("beta", "p_gt", threshold = 0, mu = mu[1], sigma = sg[1]), 1)
  expect_equal(af("beta", "p_gt", threshold = 1, mu = mu[1], sigma = sg[1]), 0)
  expect_equal(
    af("beta", "quantile", prob = 0.75, mu = mu, sigma = sg),
    stats::qbeta(0.75, mu * phi, (1 - mu) * phi)
  )
  # a mean outside (0, 1) is clamped into the open interval, not propagated
  expect_lt(af("beta", "mean", mu = 1.2, sigma = 0.5), 1)
  expect_gt(af("beta", "mean", mu = -0.2, sigma = 0.5), 0)
  expect_null(af("beta", "bogus", mu = 0.5, sigma = 0.5))
})

test_that("student functionals use the scale-location t with nu floored at 2.1", {
  mu <- 1
  sg <- 2
  nu <- 5
  expect_equal(af("student", "mean", mu = mu, sigma = sg, nu = nu), mu)
  expect_equal(af("student", "var", mu = mu, sigma = sg, nu = nu), sg^2 * nu / (nu - 2))
  expect_equal(af("student", "p_gt", threshold = mu, mu = mu, sigma = sg, nu = nu), 0.5)
  expect_equal(
    af("student", "p_gt", threshold = 3, mu = mu, sigma = sg, nu = nu),
    stats::pt((3 - mu) / sg, df = nu, lower.tail = FALSE)
  )
  expect_equal(af("student", "p_zero", mu = mu, sigma = sg, nu = nu), 0)
  expect_equal(af("student", "quantile", prob = 0.5, mu = mu, sigma = sg, nu = nu), mu)
  expect_equal(
    af("student", "quantile", prob = 0.975, mu = mu, sigma = sg, nu = nu),
    mu + sg * stats::qt(0.975, df = nu)
  )
  # default nu is 5 when none is supplied
  expect_equal(
    af("student", "var", mu = mu, sigma = sg),
    af("student", "var", mu = mu, sigma = sg, nu = 5)
  )
  # nu below the floor is raised to 2.1 so the variance stays finite
  expect_equal(af("student", "var", mu = mu, sigma = sg, nu = 1.2), sg^2 * 2.1 / 0.1)
  expect_null(af("student", "bogus", mu = mu, sigma = sg, nu = nu))
})

test_that("families without a closed form return NULL", {
  expect_null(af("binomial", "mean", mu = 0.5))
  expect_null(af("gaussian", "bogus", mu = 0))
  expect_null(af("poisson", "bogus", mu = 1))
  expect_null(af("nbinom2", "bogus", mu = 1))
})

# ---- realized-value sampler edge branches ---------------------------------------------

test_that("zero_one_beta draws boundary values with probability zoi, split by coi", {
  set.seed(2)
  n <- 20000
  p <- list(mu = rep(0.5, n), sigma = rep(0.5, n), zoi = rep(0.4, n), coi = rep(0.75, n))
  y <- drmSEM:::drm_sample_family("zero_one_beta", p, n)
  expect_equal(mean(y == 0) + mean(y == 1), 0.4, tolerance = 0.02)
  expect_equal(mean(y == 1) / (mean(y == 0) + mean(y == 1)), 0.75, tolerance = 0.03)
  # the continuous part stays strictly inside (0, 1)
  expect_true(all(y[y > 0 & y < 1] > 0 & y[y > 0 & y < 1] < 1))
  # with no coi supplied, boundaries split evenly
  p$coi <- NULL
  y2 <- drmSEM:::drm_sample_family("zero_one_beta", p, n)
  expect_equal(mean(y2 == 1) / (mean(y2 == 0) + mean(y2 == 1)), 0.5, tolerance = 0.03)
})

test_that("an unsupported family falls back to its mean with a single warning", {
  wenv <- drmSEM:::drm_warn_once_env
  key <- "family-sampler-notafamily"
  if (!is.null(wenv[[key]])) rm(list = key, envir = wenv)
  p <- list(mu = c(1, 2, 3))
  expect_warning(
    y <- drmSEM:::drm_sample_family("notafamily", p, 3),
    "No realized-value sampler"
  )
  expect_equal(y, c(1, 2, 3))
  # already warned once this session: silent the second time
  expect_no_warning(drmSEM:::drm_sample_family("notafamily", p, 3))
})

test_that("a sampler that needs trials but has none falls back to the mean, not a probability draw", {
  wenv <- drmSEM:::drm_warn_once_env
  key <- "family-sampler-binomial"
  if (!is.null(wenv[[key]])) rm(list = key, envir = wenv)
  expect_warning(
    y <- drmSEM:::drm_sample_family("binomial", list(mu = c(0.2, 0.9)), 2),
    "binomial"
  )
  expect_equal(y, c(0.2, 0.9))
  # with trials supplied the draw is a count
  set.seed(3)
  yc <- drmSEM:::drm_sample_family("binomial", list(mu = rep(0.3, 5000), trials = rep(10, 5000)), 5000)
  expect_true(all(yc == round(yc)))
  expect_equal(mean(yc), 3, tolerance = 0.05)
})

test_that("zero-inflation zeroes a share zi of the draws of any base family", {
  set.seed(4)
  n <- 20000
  y <- drmSEM:::drm_sample_family(
    "poisson", list(mu = rep(5, n), zi = rep(0.3, n)), n
  )
  expect_equal(mean(y == 0), 0.3 + 0.7 * exp(-5), tolerance = 0.05)
})

# ---- expected mean per family ---------------------------------------------------------

test_that("drm_family_expected_mean applies the family-specific conversions", {
  m <- drmSEM:::drm_family_expected_mean
  # lognormal: mu is meanlog and sigma is sdlog
  expect_equal(m("lognormal", list(mu = 1, sigma = 0.5)), exp(1 + 0.125))
  # zero inflation scales any family's mean by (1 - zi)
  expect_equal(m("poisson", list(mu = 4, zi = 0.25)), 3)
  expect_equal(m("gaussian", list(mu = 2)), 2)
  # binomial: trials * p when trials exist
  expect_equal(m("binomial", list(mu = 0.3, trials = 10)), 3)
  expect_equal(m("beta_binomial", list(mu = 0.3, trials = 20)), 6)
  # without trials the probability is returned with a once-per-session warning
  wenv <- drmSEM:::drm_warn_once_env
  key <- "family-mean-trials-binomial"
  if (!is.null(wenv[[key]])) rm(list = key, envir = wenv)
  expect_warning(out <- m("binomial", list(mu = 0.3)), "trials")
  expect_equal(out, 0.3)
  expect_no_warning(m("binomial", list(mu = 0.3)))
})

test_that("hurdle_nbinom2 mean uses the zero-truncated NB2 mean mu / (1 - p0)", {
  skip_if_not_installed("drmTMB")
  p0_fun <- drmSEM:::drm_engine_fun("truncated_nbinom2_p0")
  skip_if(is.null(p0_fun), "this drmTMB build does not expose truncated_nbinom2_p0")
  mu <- 3
  sg <- 0.5
  hu <- 0.2
  p0 <- (1 / (1 + sg^2 * mu))^(1 / sg^2) # NB2 P(Y = 0) with size = 1 / sigma^2
  expect_equal(
    drmSEM:::drm_family_expected_mean("hurdle_nbinom2", list(mu = mu, sigma = sg, hu = hu)),
    (1 - hu) * mu / (1 - p0),
    tolerance = 1e-8
  )
  # without hu there is nothing to hurdle: the mean falls back to mu
  expect_equal(
    drmSEM:::drm_family_expected_mean("hurdle_nbinom2", list(mu = mu, sigma = sg)),
    mu
  )
})

test_that("drm_effective_family keys on model_type only for allow-listed samplers", {
  eff <- drmSEM:::drm_effective_family
  expect_identical(eff("truncated_nbinom2", "hurdle_nbinom2"), "hurdle_nbinom2")
  expect_identical(eff("poisson", "zi_poisson"), "poisson")
  expect_identical(eff("poisson"), "poisson")
})

# ---- outcome functionals of a realized vector -------------------------------------------

test_that("drm_outcome_functional summarises a realized outcome vector", {
  f <- drmSEM:::drm_outcome_functional
  y <- c(0, 0, 1, 2, 5, NA)
  expect_equal(f(y, "mean"), 1.6)
  expect_equal(f(y, "p_gt", threshold = 1), 0.4)
  expect_equal(f(y, "p_zero"), 0.4)
  expect_equal(f(y, "var"), stats::var(y, na.rm = TRUE))
  expect_equal(f(y, "quantile", prob = 0.5), 1)
  # an unrecognised target falls back to the mean
  expect_equal(f(y, "unknown"), 1.6)
})
