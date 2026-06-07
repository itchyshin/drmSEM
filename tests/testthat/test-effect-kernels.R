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

# Natural (cross-world) direct/indirect effects: on an identity-link chain
# x -> m -> y with a direct x -> y edge, NDE = c, NIE = a*b, total = c + a*b.
test_that("natural NDE/NIE recover the cross-world decomposition", {
  a <- 0.5; b <- 0.6; cc <- 0.3
  engines <- list(
    M = list(name = "M", identifier = "M", family = "gaussian", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL) data.frame(mu = a * scenario$x)),
    Y = list(name = "Y", identifier = "Y", family = "gaussian", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = cc * scenario$x + b * scenario$M))
  )
  n <- 50
  lo <- data.frame(x = 0, M = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, M = 0, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  ne <- drm_natural_target(engines, scen, "x", "Y", active = "M",
                           mediation = "mean", beta_list = NULL)
  expect_equal(unname(ne["nde"]), cc, tolerance = 1e-8)
  expect_equal(unname(ne["nie"]), a * b, tolerance = 1e-8)
  expect_equal(unname(ne["total"]), cc + a * b, tolerance = 1e-8)
  # no exposure-mediator interaction here, so total = nde + nie
  expect_equal(unname(ne["total"]), unname(ne["nde"] + ne["nie"]), tolerance = 1e-8)
})

test_that("natural indirect is zero when there is no x -> m path", {
  engines <- list(
    M = list(name = "M", identifier = "M", family = "gaussian", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL) data.frame(mu = 0 * scenario$x)),
    Y = list(name = "Y", identifier = "Y", family = "gaussian", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = 0.4 * scenario$x + 0.6 * scenario$M))
  )
  n <- 30
  lo <- data.frame(x = 0, M = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, M = 0, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  ne <- drm_natural_target(engines, scen, "x", "Y", active = "M",
                           mediation = "mean", beta_list = NULL)
  expect_equal(unname(ne["nie"]), 0, tolerance = 1e-8)
  expect_equal(unname(ne["nde"]), 0.4, tolerance = 1e-8)
})

# Outcome functionals (OQ-11): the effect on Pr(Y = 0) for a Poisson outcome
# whose mean drops from 2 to 0.5 is exp(-0.5) - exp(-2).
test_that("outcome functional p_zero recovers the Poisson zero-probability effect", {
  mu_lo <- 2; mu_hi <- 0.5
  engines <- list(
    Y = list(name = "Y", identifier = "Y", family = "poisson", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = mu_lo + (mu_hi - mu_lo) * scenario$x))
  )
  set.seed(1); n <- 4000
  lo <- data.frame(x = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  v <- drm_functional_contrast(engines, scen, "Y", active = character(0),
                               mediation = "distribution", target = "p_zero",
                               threshold = 0, B = 1, n_sim = 20, draw = FALSE)
  expect_equal(unname(v), exp(-mu_hi) - exp(-mu_lo), tolerance = 0.03)
})

# Outcome functionals (OQ-11): the quantile target. For a gaussian Y with
# mu = 10 + 2x and sigma = 1 + 3x the p-quantile is mu + qnorm(p) * sigma, so the
# x-contrast of the p-quantile is 2 + qnorm(p) * 3: the median (p = 0.5) moves by
# the mean slope only, while the upper tail (p = 0.9) also picks up the sigma
# slope -- exactly the case where reporting a quantile beats reporting the mean.
test_that("outcome functional quantile recovers a sigma-path tail effect", {
  engines <- list(
    Y = list(name = "Y", identifier = "Y", family = "gaussian",
             components = c("mu", "sigma"), coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = 10 + 2 * scenario$x, sigma = 1 + 3 * scenario$x))
  )
  set.seed(1); n <- 4000
  lo <- data.frame(x = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  med <- drm_functional_contrast(engines, scen, "Y", active = character(0),
                                 mediation = "distribution", target = "quantile",
                                 threshold = 0, B = 1, n_sim = 10, draw = FALSE,
                                 prob = 0.5)
  up <- drm_functional_contrast(engines, scen, "Y", active = character(0),
                                mediation = "distribution", target = "quantile",
                                threshold = 0, B = 1, n_sim = 10, draw = FALSE,
                                prob = 0.9)
  expect_equal(unname(med), 2, tolerance = 0.15)
  expect_equal(unname(up), 2 + stats::qnorm(0.9) * 3, tolerance = 0.3)
})

# Outcome functionals through a mediator (OQ-11): the controlled decomposition
# must stay NON-DEGENERATE for a non-mean target. X -> M -> Y with no direct
# X -> Y; M is a gaussian mediator, Y is Poisson with mu = exp(M). For p_zero the
# mean-mediated leg (M passes its mean) and the distribution-mediated leg (M
# passes draws) differ by a Jensen gap -- which only holds because the legs now
# honour their mediation mode instead of always simulating the mediator.
test_that("functional decomposition legs are non-degenerate for a non-mean target", {
  engines <- list(
    M = list(name = "M", identifier = "M", family = "gaussian",
             components = c("mu", "sigma"), coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = scenario$x, sigma = 1)),
    Y = list(name = "Y", identifier = "Y", family = "poisson",
             components = "mu", coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = exp(scenario$M)))
  )
  set.seed(42); n <- 3000
  lo <- data.frame(x = 0, M = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, M = 0, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  legs <- drm_decomp_legs(engines, scen, "Y", active = "M", B = 1, n_sim = 30,
                          draw = FALSE, target = "p_zero")
  cde <- legs[, "cde"]; tot_mean <- legs[, "tot_mean"]; tot_dist <- legs[, "tot_dist"]
  # No direct path: the controlled direct effect on Pr(Y = 0) is ~0.
  expect_equal(unname(cde), 0, tolerance = 0.02)
  # The distribution-mediated part is non-degenerate (the legs genuinely differ).
  expect_gt(abs(tot_dist - tot_mean), 0.02)
  # The decomposition closes exactly: indirect = mean_mediated + distribution.
  expect_equal(unname(tot_dist - cde),
               unname((tot_mean - cde) + (tot_dist - tot_mean)),
               tolerance = 1e-10)
})

# Analytic (non-simulated) outcome functionals (OQ-11): closed forms per row.
test_that("V-76: analytic outcome functionals match closed forms", {
  g <- data.frame(mu = c(1, 4), sigma = c(2, 3))
  expect_equal(drmSEM:::drm_analytic_functional("gaussian", g, "mean"), c(1, 4))
  expect_equal(drmSEM:::drm_analytic_functional("gaussian", g, "var"), c(4, 9))
  expect_equal(drmSEM:::drm_analytic_functional("gaussian", g, "quantile", prob = 0.975),
               stats::qnorm(0.975, c(1, 4), c(2, 3)))
  expect_equal(drmSEM:::drm_analytic_functional("gaussian", g, "p_gt", threshold = 0),
               stats::pnorm(0, c(1, 4), c(2, 3), lower.tail = FALSE))
  expect_equal(drmSEM:::drm_analytic_functional("gaussian", g, "p_zero"), c(0, 0))

  p <- data.frame(mu = c(0.5, 2))
  expect_equal(drmSEM:::drm_analytic_functional("poisson", p, "p_zero"), exp(-c(0.5, 2)))
  expect_equal(drmSEM:::drm_analytic_functional("poisson", p, "var"), c(0.5, 2))
  expect_equal(drmSEM:::drm_analytic_functional("poisson", p, "quantile", prob = 0.9),
               stats::qpois(0.9, c(0.5, 2)))
  # families with the unconfirmed sigma<->dispersion scale return NULL (fall back)
  expect_null(drmSEM:::drm_analytic_functional("nbinom2", g, "p_zero"))
  expect_null(drmSEM:::drm_analytic_functional("gaussian", g, "nonsense"))
})

# The analytic contrast is EXACT (no Monte-Carlo noise): the same Poisson p_zero
# effect that the simulated kernel recovers only to ~0.03 is hit to machine
# precision here.
test_that("V-76: analytic functional contrast is exact (no MC noise)", {
  mu_lo <- 2; mu_hi <- 0.5
  engines <- list(
    Y = list(name = "Y", identifier = "Y", family = "poisson", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = mu_lo + (mu_hi - mu_lo) * scenario$x))
  )
  n <- 8
  lo <- data.frame(x = 0, Y = 0)[rep(1, n), ]
  hi <- data.frame(x = 1, Y = 0)[rep(1, n), ]
  scen <- list(lo = lo, hi = hi, column = "x")
  v <- drmSEM:::drm_functional_contrast_analytic(
    engines, scen, "Y", active = character(0), mediation = "mean",
    target = "p_zero", threshold = 0, prob = 0.5, B = 1, draw = FALSE
  )
  expect_equal(unname(v), exp(-mu_hi) - exp(-mu_lo))   # exact
  # unsupported family returns NULL so the caller can abort/fall back
  engines$Y$family <- "beta"
  expect_null(drmSEM:::drm_functional_contrast_analytic(
    engines, scen, "Y", active = character(0), mediation = "mean",
    target = "p_zero", threshold = 0, prob = 0.5, B = 1, draw = FALSE
  ))
})
