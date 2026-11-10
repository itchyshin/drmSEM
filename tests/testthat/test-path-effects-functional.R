# Path-specific attribution on an outcome functional (target = "p_gt"): the
# analytic and simulated routes of drm_path_contrasts() / drm_component_contrasts()
# on hand-built Gaussian engines, checked against the closed form, plus the
# user-facing path_effects() wrapper on a live chain fit.
#
# DGP of the hand-built engines:  M ~ N(a x, s(x)^2),  Y | M ~ N(b M, 1), so
#   P(Y > 0 | x, mean mediation)        = pnorm(b a x)
#   P(Y > 0 | x, distribution mediation) = pnorm(b a x / sqrt(1 + b^2 s(x)^2)).

pf_a <- 0.5
pf_b <- 0.8
pf_s <- function(x) exp(-0.4 + 0.9 * x)

pf_engines <- function() {
  list(
    M = list(
      name = "M", identifier = "M", family = "gaussian",
      components = c("mu", "sigma"), coef = list(), vcov = NULL,
      predict = function(scenario, beta = NULL) {
        data.frame(mu = pf_a * scenario$x, sigma = pf_s(scenario$x))
      }
    ),
    Y = list(
      name = "Y", identifier = "Y", family = "gaussian",
      components = c("mu", "sigma"), coef = list(), vcov = NULL,
      predict = function(scenario, beta = NULL) {
        data.frame(mu = pf_b * scenario$M, sigma = rep(1, nrow(scenario)))
      }
    )
  )
}

pf_scen <- function(n = 4) {
  rows <- function(x) data.frame(x = rep(x, n), M = 0, Y = 0)
  list(lo = rows(0), hi = rows(1), column = "x")
}

test_that("analytic p_gt path contrasts under mean mediation match pnorm(b a x)", {
  truth <- stats::pnorm(pf_b * pf_a) - 0.5
  pc <- drmSEM:::drm_path_contrasts(
    pf_engines(), pf_scen(), "Y", "M", mediation = "mean", B = 1, n_sim = 1,
    draw = FALSE, target = "p_gt", threshold = 0, functional = "analytic"
  )
  # no direct x -> Y arrow, so the controlled direct effect is exactly 0 and the
  # whole indirect effect runs through M
  expect_equal(mean(pc$total_indirect), truth, tolerance = 1e-10)
  expect_equal(mean(pc$inclusion$M), truth, tolerance = 1e-10)
  expect_equal(mean(pc$exclusion$M), truth, tolerance = 1e-10)
  expect_equal(mean(pc$remainder), 0, tolerance = 1e-10)
})

test_that("simulated p_gt path contrasts agree with the analytic closed form", {
  truth <- stats::pnorm(pf_b * pf_a) - 0.5
  set.seed(10)
  pc <- drmSEM:::drm_path_contrasts(
    pf_engines(), pf_scen(4000), "Y", "M", mediation = "mean", B = 1, n_sim = 5,
    draw = FALSE, target = "p_gt", threshold = 0, functional = "simulate"
  )
  expect_lt(abs(mean(pc$inclusion$M) - truth), 0.02)
})

test_that("per-component attribution of a tail probability recovers the sigma channel", {
  s0 <- pf_s(0)
  s1 <- pf_s(1)
  p_dist <- function(x, s) stats::pnorm(pf_b * pf_a * x / sqrt(1 + pf_b^2 * s^2))
  full <- p_dist(1, s1) - p_dist(0, s0)
  mean_ch <- stats::pnorm(pf_b * pf_a) - 0.5
  # sigma channel: full distribution effect minus the one with sigma frozen at x0
  sigma_ch <- p_dist(1, s1) - p_dist(1, s0)

  set.seed(11)
  for (fn in c("analytic", "simulate")) {
    cc <- drmSEM:::drm_component_contrasts(
      pf_engines(), pf_scen(20000), "Y", "M", B = 1, n_sim = if (fn == "analytic") 1 else 3,
      draw = FALSE, target = "p_gt", threshold = 0, functional = fn
    )
    expect_lt(abs(mean(cc$inclusion) - full), 0.02)
    expect_lt(abs(mean(cc$mean) - mean_ch), 0.02)
    expect_named(cc$channels, "sigma")
    expect_lt(abs(mean(cc$channels$sigma) - sigma_ch), 0.03)
    # the channels plus the remainder close the inclusion effect exactly
    expect_equal(
      mean(cc$mean) + mean(cc$channels$sigma) + mean(cc$remainder),
      mean(cc$inclusion),
      tolerance = 1e-10,
      info = fn
    )
  }
  # sanity on the truth itself: a wider mediator pulls P(Y > 0) toward 1/2
  expect_lt(p_dist(1, s1), p_dist(1, s0))
})

test_that("a frozen engine reproduces the reference-world component and leaves others alone", {
  eng <- pf_engines()
  scen <- pf_scen(3)
  frozen <- drmSEM:::drm_freeze_engine(eng, "M", "sigma", scen$lo)
  p_hi <- frozen$M$predict(scen$hi)
  expect_equal(p_hi$sigma, rep(pf_s(0), 3)) # sigma pinned to its x0 value
  expect_equal(p_hi$mu, rep(pf_a, 3)) # mu still responds to x
  expect_identical(frozen$Y, eng$Y)
})

# ---- the user-facing wrapper ---------------------------------------------------------

test_that("path_effects rejects a model with no mediators and validates arguments", {
  skip_if_not_installed("drmTMB")
  set.seed(5)
  d <- data.frame(x = stats::rnorm(80))
  d$y <- 0.5 * d$x + stats::rnorm(80)
  sem <- drm_sem(y = drm_node(drmTMB::bf(y ~ x), family = stats::gaussian()), data = d)
  expect_error(path_effects(sem, "x", "y", uncertainty = "none"), "No mediators")
  expect_error(path_effects(sem, "x", "x", uncertainty = "none"), "endogenous")
})

chain_truth <- function(dat, at_x) {
  mean(stats::pnorm((0.3 * at_x + 0.8 * dat$m) / exp(-0.2 + 0.3 * at_x)))
}

test_that("path_effects on a tail probability: analytic closed form vs simulation on a fit", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  an <- path_effects(
    sem, "x", "y", target = "p_gt", threshold = 0, functional = "analytic",
    uncertainty = "none", seed = 1
  )
  expect_true(all(an$target == "p_gt"))
  est <- stats::setNames(an$estimate, paste(an$estimand, an$mediator))
  # the remainder is, by construction, what the per-mediator inclusion misses
  expect_equal(
    unname(est["interaction_remainder NA"]),
    unname(est["total_indirect NA"] - est["inclusion m"]),
    tolerance = 1e-8
  )
  # truth under distribution mediation: m | x, g ~ N(0.5 x + 0.4 g, 0.5^2), then
  # y | m ~ N(0.3 x + 0.8 m, exp(-0.2 + 0.3 x)^2); the direct (m held observed)
  # contrast is subtracted
  dat <- cov_chain_dgp()
  at <- mean(dat$x) + c(-0.5, 0.5) * stats::sd(dat$x)
  p_marg <- function(x) {
    mm <- 0.5 * x + 0.4 * (dat$g == "B")
    mean(stats::pnorm((0.3 * x + 0.8 * mm) / sqrt(exp(-0.2 + 0.3 * x)^2 + 0.8^2 * 0.25)))
  }
  direct <- chain_truth(dat, at[2]) - chain_truth(dat, at[1])
  truth_inc <- (p_marg(at[2]) - p_marg(at[1])) - direct
  expect_lt(abs(est[["inclusion m"]] - truth_inc), 0.07)
  expect_gt(est[["inclusion m"]], 0) # raising x raises m, which raises P(y > 0)

  comp <- path_effects(
    sem, "x", "y", by = "component", target = "p_gt", threshold = 0,
    functional = "analytic", uncertainty = "none", seed = 2
  )
  expect_setequal(
    comp$estimand,
    c("total_indirect", "mean_channel", "sigma_channel", "component_remainder")
  )
  # null control: m's sigma does not depend on x, so freezing it changes nothing
  expect_lt(abs(comp$estimate[comp$estimand == "sigma_channel"]), 0.05)

  sm <- path_effects(
    sem, "x", "y", target = "p_gt", threshold = 0, uncertainty = "none", nsim = 80, seed = 1
  )
  inc_sm <- sm$estimate[sm$estimand == "inclusion"]
  expect_lt(abs(inc_sm - est[["inclusion m"]]), 0.03)
})

test_that("path_effects natural effects carry an identification flag per mediator", {
  skip_if_not_installed("drmTMB")
  sem <- cov_chain_sem()
  nat <- path_effects(
    sem, "x", "y", effect = "natural", uncertainty = "none", nsim = 20, seed = 2
  )
  expect_identical(nat$estimand, "natural_indirect")
  expect_identical(nat$mediator, "m")
  expect_true(nat$identified) # a single mediator cannot recant
  s <- stats::sd(cov_chain_dgp()$x)
  expect_lt(abs(nat$estimate - 0.4 * s), 0.15)

  nat_q <- path_effects(
    sem, "x", "y", effect = "natural", target = "quantile", quantile_prob = 0.9,
    uncertainty = "none", nsim = 10, seed = 3
  )
  expect_identical(unique(nat_q$target), "quantile")
  expect_true(is.finite(nat_q$estimate))
  # `through` restricts the mediator set
  expect_error(
    path_effects(sem, "x", "y", through = "zzz", uncertainty = "none"),
    "No mediators"
  )
})
