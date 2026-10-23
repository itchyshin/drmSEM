# Engine-free pins for the pure link / family kernels in R/simulate_effects.R.
# Every effect estimate passes through these, so a swapped link or a wrong
# variance term must fail here, not only in live drmTMB fits.
#
# Scope notes:
#   * drm_sample_family()'s hurdle semantics are a documented, unsettled gap
#     (see its roxygen and test-hurdle.R); the hurdle sampler is NOT exercised
#     here. Only the drm_effective_family() routing names are pinned.
#   * No drmTMB needed; only base R and testthat.

# Monte Carlo agreement within 5 standard errors of the sample mean.
expect_mc_mean <- function(x, target, info = NULL) {
  se <- stats::sd(x) / sqrt(length(x))
  testthat::expect_lt(abs(mean(x) - target), 5 * se, label = info)
}

test_that("drm_link_fun inverts drm_inv_link for every supported link", {
  eta <- list(
    identity = c(-3, -0.5, 0, 1.2, 4),
    log = c(-3, -0.5, 0, 1.2, 4),
    logit = c(-5, -1, 0, 0.7, 5),
    tanh = c(-2, -0.5, 0, 0.9, 2)
  )
  for (link in names(eta)) {
    expect_equal(
      drm_link_fun(link, drm_inv_link(link, eta[[link]])),
      eta[[link]],
      tolerance = 1e-8,
      info = link
    )
  }
})

test_that("forward link values are the documented functions", {
  expect_equal(drm_link_fun("log", exp(1.5)), 1.5)
  expect_equal(drm_link_fun("logit", 0.5), 0)
  expect_equal(drm_link_fun("logit", 0.8), log(0.8 / 0.2))
  expect_equal(drm_link_fun("tanh", tanh(0.3)), 0.3)
  # boundary values are clamped to finite numbers, not +/-Inf
  expect_true(is.finite(drm_link_fun("log", 0)))
  expect_true(all(is.finite(drm_link_fun("logit", c(0, 1)))))
  expect_true(all(is.finite(drm_link_fun("tanh", c(-1, 1)))))
})

test_that("an unknown link falls back to identity (current behaviour, pinned)", {
  # No error: switch() falls through to the default arm in both directions.
  expect_equal(drm_inv_link("probit", c(-1, 0, 2)), c(-1, 0, 2))
  expect_equal(drm_link_fun("probit", c(-1, 0, 2)), c(-1, 0, 2))
})

test_that("drm_marginalize_link with sigma_re = 0 (or missing) is the inverse link", {
  eta <- c(-2, -0.3, 0, 0.8, 2.5)
  for (link in c("identity", "log", "logit", "tanh")) {
    expect_equal(
      drm_marginalize_link(link, eta, 0),
      drm_inv_link(link, eta),
      info = link
    )
  }
  expect_equal(drm_marginalize_link("logit", eta, NULL), drm_inv_link("logit", eta))
  expect_equal(drm_marginalize_link("logit", eta, NA_real_), drm_inv_link("logit", eta))
})

test_that("drm_marginalize_link matches brute-force Monte Carlo for logit and log", {
  set.seed(20260101)
  n <- 2e5
  sigma_re <- 0.8
  b <- stats::rnorm(n, 0, sigma_re)
  eta <- c(-1.5, 0, 1)
  mc_logit <- vapply(eta, function(e) mean(stats::plogis(e + b)), numeric(1))
  expect_lt(max(abs(drm_marginalize_link("logit", eta, sigma_re) - mc_logit)), 5e-3)
  mc_log <- vapply(eta, function(e) mean(exp(e + b)), numeric(1))
  expect_lt(
    max(abs(drm_marginalize_link("log", eta, sigma_re) / mc_log - 1)),
    1e-2
  )
  # closed form for the log link is exp(eta + sigma_re^2 / 2) exactly
  expect_equal(
    drm_marginalize_link("log", eta, sigma_re),
    exp(eta + 0.5 * sigma_re^2)
  )
})

test_that("drm_family_expected_mean equals the closed form per family", {
  mu <- c(0.5, 2, 7.5)
  sg <- c(0.3, 0.6, 1.1)
  p <- list(mu = mu, sigma = sg)
  expect_equal(drm_family_expected_mean("gaussian", p), mu)
  expect_equal(drm_family_expected_mean("poisson", p), mu)
  expect_equal(drm_family_expected_mean("Gamma", p), mu)
  expect_equal(drm_family_expected_mean("nbinom2", p), mu)
  expect_equal(drm_family_expected_mean("lognormal", p), exp(mu + sg^2 / 2))
  # binomial: mu is a probability, the response is a count -> trials * mu
  pb <- list(mu = c(0.2, 0.5, 0.9), trials = c(10, 20, 5))
  expect_equal(drm_family_expected_mean("binomial", pb), pb$trials * pb$mu)
})

test_that("zero-inflation scales the expected mean by (1 - zi)", {
  mu <- c(1, 4, 9)
  zi <- c(0.1, 0.3, 0.5)
  expect_equal(
    drm_family_expected_mean("poisson", list(mu = mu, zi = zi)),
    mu * (1 - zi)
  )
  sg <- c(0.4, 0.5, 0.6)
  expect_equal(
    drm_family_expected_mean("lognormal", list(mu = mu, sigma = sg, zi = zi)),
    (1 - zi) * exp(mu + sg^2 / 2)
  )
  # zi = 0 changes nothing
  expect_equal(
    drm_family_expected_mean("poisson", list(mu = mu, zi = rep(0, 3))),
    mu
  )
})

test_that("drm_effective_family routes only allow-listed model_types", {
  expect_identical(
    drm_effective_family("truncated_nbinom2", "hurdle_nbinom2"),
    "hurdle_nbinom2"
  )
  expect_identical(drm_effective_family("truncated_nbinom2"), "truncated_nbinom2")
  expect_identical(
    drm_effective_family("truncated_nbinom2", "truncated_nbinom2"),
    "truncated_nbinom2"
  )
  # zi_* model_types have no sampler branch of their own: keep the family name
  expect_identical(drm_effective_family("poisson", "zi_poisson"), "poisson")
  expect_identical(drm_effective_family("gaussian", NA_character_), "gaussian")
  expect_identical(drm_model_type_samplers(), "hurdle_nbinom2")
})

test_that("drm_sample_family sample means match drm_family_expected_mean", {
  n <- 2e5
  cases <- list(
    gaussian = list(mu = rep(1.5, n), sigma = rep(0.7, n)),
    poisson = list(mu = rep(3.2, n)),
    Gamma = list(mu = rep(2.5, n), sigma = rep(0.5, n)),
    lognormal = list(mu = rep(0.4, n), sigma = rep(0.6, n)),
    nbinom2 = list(mu = rep(4, n), sigma = rep(0.5, n)),
    binomial = list(mu = rep(0.3, n), trials = rep(12, n)),
    poisson = list(mu = rep(5, n), zi = rep(0.25, n))
  )
  for (i in seq_along(cases)) {
    fam <- names(cases)[i]
    p <- cases[[i]]
    set.seed(1000 + i)
    x <- drm_sample_family(fam, p, n)
    target <- drm_family_expected_mean(fam, p)[1]
    expect_mc_mean(x, target, info = paste(fam, i))
  }
})
