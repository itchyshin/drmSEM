# Effect-propagation kernels and the distribution-mediated mechanism
# (no drmTMB required: engines are constructed directly).

test_that("inverse links are correct", {
  expect_equal(drm_inv_link("identity", 2), 2)
  expect_equal(drm_inv_link("log", 0), 1)
  expect_equal(drm_inv_link("logit", 0), 0.5)
  expect_equal(drm_inv_link("tanh", 0), 0)
})

test_that("family samplers recover their target moments", {
  set.seed(2)
  g <- drm_sample_family("gaussian", list(mu = rep(3, 1e4), sigma = rep(2, 1e4)), 1e4)
  expect_equal(mean(g), 3, tolerance = 0.1)
  expect_equal(sd(g), 2, tolerance = 0.1)
  p <- drm_sample_family("poisson", list(mu = rep(5, 1e4)), 1e4)
  expect_equal(mean(p), 5, tolerance = 0.2)
  zi <- drm_sample_family("poisson", list(mu = rep(5, 1e4), zi = rep(0.5, 1e4)), 1e4)
  expect_lt(mean(zi), mean(p))
})

# Chain x -> M (gaussian: mu and sigma depend on x) -> Y (mu = exp(0.5 M)).
make_engines <- function(s_coef) {
  list(
    M = list(name = "M", identifier = "M", family = "gaussian",
             components = c("mu", "sigma"), coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = 1.0 * scenario$x,
                          sigma = exp(-0.2 + s_coef * scenario$x))),
    Y = list(name = "Y", identifier = "Y", family = "gaussian",
             components = "mu", coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = exp(0.5 * scenario$M)))
  )
}

test_that("a mediator's scale propagates only under distribution mediation", {
  set.seed(1)
  n <- 400
  lo <- data.frame(x = 0, M = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, M = 0, Y = 0)[rep(1, n), ]
  contrast <- function(eng, mediation, n_sim) {
    mean(drm_expected_target(eng, hi, "Y", "M", mediation, NULL, n_sim) -
         drm_expected_target(eng, lo, "Y", "M", mediation, NULL, n_sim))
  }
  # constant scale: distribution-mediated effect is negligible
  eng0 <- make_engines(0)
  expect_equal(contrast(eng0, "distribution", 400), contrast(eng0, "mean", 1),
               tolerance = 0.2)
  # scale increases with x: distribution mediation adds a positive effect
  eng1 <- make_engines(0.9)
  expect_gt(contrast(eng1, "distribution", 800) - contrast(eng1, "mean", 1), 0.1)
})
