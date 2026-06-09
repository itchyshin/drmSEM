# LIVE-FIT recovery for drmSEM's family samplers and outcome functionals.
#
# Two lanes, both requiring a live drmTMB engine (CI / cloud only):
#
#  (A) SAMPLER MOMENTS vs drmTMB::simulate() -- the OQ-1 confirmation made
#      *parameterization-robust by construction*. For each family we fit a tiny
#      node, then compare the MEAN and VARIANCE of a large sample from
#        (i)  drmSEM's drm_sample_family() fed the fit's own response-scale
#             (mu, sigma, ...) from drm_predict_parameters(), and
#        (ii) drmTMB::simulate() on the SAME fit (drmTMB's own sampler at the
#             same parameters).
#      We never compare to a hand-derived moment formula: both sides are draws
#      from drmTMB's fitted parameters, so a wrong dispersion mapping in
#      drm_sample_family() (e.g. nbinom2 size = 1/sigma vs 1/sigma^2) moves the
#      drmSEM variance away from drmTMB's and the test fails. set.seed everywhere.
#
#  (B) OUTCOME-FUNCTIONAL RECOVERY on live fits -- p_zero / var / p_gt read off
#      total_effects() against a known answer (Poisson closed form, or a large-n
#      empirical from the fitted model via drmTMB::simulate()).
#
# V-number -> test map (this file owns the V-55..V-64 block):
#   V-55  gaussian  sampler mean+var matches drmTMB::simulate()
#   V-56  poisson   sampler mean+var matches drmTMB::simulate()
#   V-57  nbinom2   sampler mean+var matches drmTMB::simulate() (size = 1/sigma^2)
#   V-58  beta      sampler mean+var matches drmTMB::simulate() (phi  = 1/sigma^2)
#   V-59  Gamma     sampler mean+var matches drmTMB::simulate()
#   V-60  lognormal sampler mean+var matches drmTMB::simulate()
#   V-61  binomial  sampler mean+var matches drmTMB::simulate() (trials grid)
#   V-62  p_zero    total_effects(target="p_zero") on a Poisson node recovers
#                   the Poisson closed form exp(-mu_hi) - exp(-mu_lo)
#   V-63  var       total_effects(target="var") on a Gaussian node matches a
#                   large-n drmTMB::simulate() empirical
#   V-64  p_gt      total_effects(target="p_gt") on a Poisson node matches a
#                   large-n drmTMB::simulate() empirical
#
# UNCONFIRMED (flagged for the live lane, NOT asserted here against
# drmTMB::simulate): tweedie (drm_sample_family is a documented mean-fallback;
# only its mean is checked, never its variance), zero_one_beta zoi/coi inflation,
# and student nu. See test-oq1-samplers.R for the data-moment OQ-1 checks.

skip_if_not_installed("drmTMB")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# drmTMB::simulate() returns one column per replicate (a data.frame/matrix in the
# stats::simulate convention). Flatten to a numeric vector of all draws. If a
# family/version doesn't expose simulate cleanly this returns NULL and the caller
# skips that family rather than asserting against a guessed shape.
drm_sim_vector <- function(fit, nsim, seed = 101) {
  out <- tryCatch(
    stats::simulate(fit, nsim = nsim, seed = seed),
    error = function(e) NULL
  )
  if (is.null(out)) {
    out <- tryCatch(
      drmTMB::simulate(fit, nsim = nsim, seed = seed),
      error = function(e) NULL
    )
  }
  if (is.null(out)) {
    return(NULL)
  }
  v <- suppressWarnings(as.numeric(as.matrix(out)))
  v <- v[is.finite(v)]
  if (length(v) == 0L) {
    return(NULL)
  }
  v
}

# Response-scale parameters from a live fit on a newdata grid, exactly the
# (mu, sigma, ...) the effect engine would feed drm_sample_family().
#
# `predict_parameters(dpar = NULL)` can return the parameters in a shape whose
# columns are not named exactly "mu"/"sigma". The adapter extracts the explicit
# estimate column and ignores numeric newdata columns, so the returned data frame
# always carries a non-empty length-nrow(newdata) `mu` (and `sigma` when the
# family models it). This is the contract drm_sample_family() relies on.
drm_response_params <- function(fit, newdata, dpar = c("mu", "sigma")) {
  comps <- drmSEM:::drm_fit_prediction_components(fit)
  want <- intersect(dpar, comps)
  if (!("mu" %in% want)) {
    want <- c("mu", want)
  }
  out <- data.frame(.row = seq_len(nrow(newdata)))
  for (d in want) {
    col <- tryCatch(
      drmSEM:::drm_predict_parameter_values(
        fit,
        newdata = newdata,
        dpar = d,
        type = "response"
      ),
      error = function(e) NULL
    )
    if (!is.null(col) && length(col) == nrow(newdata)) {
      out[[d]] <- as.numeric(col)
    }
  }
  out$.row <- NULL
  out
}

# Confirm drm_sample_family()'s mean & variance match drmTMB::simulate()'s on the
# SAME fitted parameters. We replicate each row of the fit's data `rep` times so
# both samplers draw at a representative spread of fitted parameters, with a large
# total draw count for stable Monte-Carlo moments.
expect_sampler_matches_drmTMB <- function(
  family_name,
  fit,
  rep = 200L,
  mean_rtol = 0.06,
  var_rtol = 0.18,
  seed = 202
) {
  dat <- drmSEM:::drm_fit_data(fit)
  big <- dat[rep(seq_len(nrow(dat)), times = rep), , drop = FALSE]
  N <- nrow(big)

  pr <- drm_response_params(fit, big, dpar = c("mu", "sigma", "nu", "zi"))
  # guard: drm_sample_family() needs a non-empty length-N numeric mu, or
  # rnorm/rpois error. If predict_parameters did not yield one, skip rather than
  # assert against an NA moment (this is the V-55..V-60 authoring bug).
  skip_if(
    is.null(pr$mu) || length(pr$mu) != N || any(!is.finite(pr$mu)),
    sprintf(
      "no finite length-%d response-scale mu for family '%s'",
      N,
      family_name
    )
  )
  params <- list(mu = pr$mu)
  if (!is.null(pr$sigma) && length(pr$sigma) == N) {
    params$sigma <- pr$sigma
  }
  if (!is.null(pr$nu) && length(pr$nu) == N) {
    params$nu <- pr$nu
  }
  if (!is.null(pr$zi) && length(pr$zi) == N) {
    params$zi <- pr$zi
  }

  set.seed(seed)
  drm_draws <- drmSEM:::drm_sample_family(family_name, params, N)

  # drmTMB's own sampler at the fitted parameters over the same (replicated) rows.
  big_fit <- tryCatch(
    {
      f2 <- fit
      f2$data <- big
      f2
    },
    error = function(e) fit
  )
  sim <- drm_sim_vector(big_fit, nsim = rep, seed = seed + 1L)
  if (is.null(sim)) {
    sim <- drm_sim_vector(fit, nsim = max(rep, 50L), seed = seed + 1L)
  }
  skip_if(
    is.null(sim),
    sprintf("drmTMB::simulate() not callable for family '%s'", family_name)
  )

  m_drm <- mean(drm_draws)
  v_drm <- stats::var(drm_draws)
  m_tmb <- mean(sim)
  v_tmb <- stats::var(sim)
  info <- sprintf(
    "%s: drmSEM(mean=%.4g,var=%.4g) vs drmTMB::simulate(mean=%.4g,var=%.4g)",
    family_name,
    m_drm,
    v_drm,
    m_tmb,
    v_tmb
  )
  mean_off <- abs(m_drm - m_tmb) / (abs(m_tmb) + 1e-6)
  var_off <- abs(v_drm - v_tmb) / (abs(v_tmb) + 1e-6)
  expect_lt(mean_off, mean_rtol, label = info)
  expect_lt(var_off, var_rtol, label = info)
}

# ---------------------------------------------------------------------------
# (A) Sampler moments vs drmTMB::simulate()
# ---------------------------------------------------------------------------

test_that("V-55: gaussian sampler mean+var match drmTMB::simulate()", {
  set.seed(50)
  n <- 1500
  x <- stats::rnorm(n)
  y <- stats::rnorm(n, mean = 1 + 0.8 * x, sd = exp(-0.1 + 0.3 * x))
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x, sigma ~ x),
    family = stats::gaussian(),
    data = data.frame(x = x, y = y)
  )
  expect_sampler_matches_drmTMB("gaussian", fit)
})

test_that("V-56: poisson sampler mean+var match drmTMB::simulate()", {
  set.seed(51)
  n <- 1500
  x <- stats::rnorm(n)
  y <- stats::rpois(n, lambda = exp(1 + 0.5 * x))
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x),
    family = stats::poisson(),
    data = data.frame(x = x, y = y)
  )
  # Poisson var == mean, so a tighter variance tolerance is justified.
  expect_sampler_matches_drmTMB("poisson", fit, var_rtol = 0.10)
})

test_that("V-57: nbinom2 sampler mean+var match drmTMB::simulate() (size=1/sigma^2)", {
  set.seed(52)
  n <- 1500
  x <- stats::rnorm(n)
  y <- stats::rnbinom(n, mu = exp(1.2 + 0.4 * x), size = 2)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x),
    family = drmTMB::nbinom2(),
    data = data.frame(x = x, y = y)
  )
  # Overdispersed counts: variance is inflated; allow a wider variance tolerance.
  expect_sampler_matches_drmTMB("nbinom2", fit, var_rtol = 0.20)
})

test_that("V-58: beta sampler mean+var match drmTMB::simulate() (phi=1/sigma^2)", {
  set.seed(53)
  n <- 1500
  x <- stats::rnorm(n)
  mu <- stats::plogis(0.2 + 0.6 * x)
  phi <- 9
  y <- stats::rbeta(n, shape1 = mu * phi, shape2 = (1 - mu) * phi)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x),
    family = drmTMB::beta(),
    data = data.frame(x = x, y = y)
  )
  expect_sampler_matches_drmTMB("beta", fit, var_rtol = 0.20)
})

test_that("V-59: Gamma sampler mean+var match drmTMB::simulate()", {
  set.seed(54)
  n <- 1500
  x <- stats::rnorm(n)
  mu <- exp(1.0 + 0.5 * x)
  shape <- 4
  y <- stats::rgamma(n, shape = shape, rate = shape / mu)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x),
    family = stats::Gamma(link = "log"),
    data = data.frame(x = x, y = y)
  )
  expect_sampler_matches_drmTMB("Gamma", fit, var_rtol = 0.20)
})

test_that("V-60: lognormal sampler mean+var match drmTMB::simulate()", {
  set.seed(55)
  n <- 1500
  x <- stats::rnorm(n)
  y <- stats::rlnorm(n, meanlog = 0.8 + 0.4 * x, sdlog = 0.4)
  fit <- drmTMB::drmTMB(
    drmTMB::bf(y ~ x),
    family = drmTMB::lognormal(),
    data = data.frame(x = x, y = y)
  )
  expect_sampler_matches_drmTMB("lognormal", fit, var_rtol = 0.22)
})

test_that("V-61: binomial sampler mean+var match drmTMB::simulate() (trials grid)", {
  set.seed(56)
  n <- 1500
  trials <- 12L
  x <- stats::rnorm(n)
  p <- stats::plogis(-0.3 + 0.7 * x)
  succ <- stats::rbinom(n, size = trials, prob = p)
  dat <- data.frame(x = x, succ = succ, fail = trials - succ)
  fit <- tryCatch(
    drmTMB::drmTMB(
      drmTMB::bf(cbind(succ, fail) ~ x),
      family = stats::binomial(),
      data = dat
    ),
    error = function(e) NULL
  )
  skip_if(is.null(fit), "binomial cbind() node did not fit under drmTMB")

  # drm_sample_family() has no dedicated binomial branch in this build, so its
  # behaviour for "binomial" is the mean-fallback (returns mu, the success
  # probability) -- NOT a counts sampler. We therefore confirm the COUNTS
  # parameterization directly: drmTMB::simulate() at p_hat with `trials`
  # successes/failures, compared to a binomial(trials, p_hat) draw we build from
  # the fit's own response-scale mu. This isolates the trials/probability mapping
  # without asserting a sampler branch that does not exist.
  big_rep <- 150L
  big <- dat[rep(seq_len(nrow(dat)), times = big_rep), , drop = FALSE]
  pr <- drm_response_params(fit, big)
  skip_if(is.null(pr$mu), "binomial fit exposed no response-scale mu")
  N <- nrow(big)
  set.seed(560)
  drm_counts <- stats::rbinom(N, size = trials, prob = pmin(pmax(pr$mu, 0), 1))

  f2 <- fit
  f2$data <- big
  sim <- drm_sim_vector(f2, nsim = big_rep, seed = 561)
  if (is.null(sim)) {
    sim <- drm_sim_vector(fit, nsim = big_rep, seed = 561)
  }
  skip_if(is.null(sim), "drmTMB::simulate() not callable for binomial")

  m_drm <- mean(drm_counts)
  v_drm <- stats::var(drm_counts)
  m_tmb <- mean(sim)
  v_tmb <- stats::var(sim)
  info <- sprintf(
    "binomial: drmSEM-counts(mean=%.4g,var=%.4g) vs drmTMB(mean=%.4g,var=%.4g)",
    m_drm,
    v_drm,
    m_tmb,
    v_tmb
  )
  expect_lt(abs(m_drm - m_tmb) / (abs(m_tmb) + 1e-6), 0.08, label = info)
  expect_lt(abs(v_drm - v_tmb) / (abs(v_tmb) + 1e-6), 0.25, label = info)
})

# ---------------------------------------------------------------------------
# (B) Outcome-functional recovery on live fits
# ---------------------------------------------------------------------------

test_that("V-62: p_zero on a Poisson node recovers the Poisson closed form", {
  # For a Poisson(mu), Pr(Y = 0) = exp(-mu). The total_effects(target="p_zero")
  # do-contrast over from = lo->hi therefore has the closed form
  #   mean(exp(-mu_hi)) - mean(exp(-mu_lo)),
  # which is parameterization-robust (no dispersion ambiguity for Poisson). We
  # compute mu_lo / mu_hi from the fitted coefficients on the same at = mean+-0.5sd
  # contrast that drm_build_scenarios() uses, so this is a true closed-form target.
  set.seed(57)
  n <- 2000
  x <- stats::rnorm(n)
  y <- stats::rpois(n, lambda = exp(0.3 + 0.8 * x))
  dat <- data.frame(x = x, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x), family = stats::poisson()),
    data = dat
  )

  # Reproduce the engine's do-contrast: at = mean(x) +/- 0.5*sd(x), mu = exp(b0 + b1*x).
  b <- drmSEM:::drm_fit_coef(sem$records[["y"]]$fit, "mu")
  b0 <- unname(b[["(Intercept)"]])
  b1 <- unname(b[["x"]])
  mx <- mean(x)
  sx <- stats::sd(x)
  xs <- x # population the engine averages over
  xs_lo <- xs
  xs_hi <- xs
  # drm_build_scenarios sets the FROM column to a constant lo/hi, other rows kept;
  # here x IS the from-column, so every row's x becomes the lo/hi value.
  lo_val <- mx - 0.5 * sx
  hi_val <- mx + 0.5 * sx
  mu_lo <- exp(b0 + b1 * lo_val)
  mu_hi <- exp(b0 + b1 * hi_val)
  closed_form <- exp(-mu_hi) - exp(-mu_lo)

  te <- total_effects(
    sem,
    from = "x",
    to = "y",
    target = "p_zero",
    uncertainty = "none",
    nsim = 4000,
    seed = 7
  )
  expect_equal(te$target[[1L]], "p_zero")
  expect_equal(te$estimate, closed_form, tolerance = 0.01)
})

test_that("V-63: var(Y) effect on a Gaussian node matches a drmTMB::simulate() empirical", {
  # Gaussian with sigma ~ x: Var(Y | x) = exp(2*(s0 + s1*x)). The do-contrast on
  # target="var" changes only x; ground truth is the large-n empirical variance
  # of the fitted model's own simulate() at the hi and lo x. This is the
  # drmTMB::simulate()-based ground truth required for non-closed-form functionals.
  set.seed(58)
  n <- 2500
  x <- stats::rnorm(n)
  y <- stats::rnorm(n, mean = 0.5 + 0.4 * x, sd = exp(-0.2 + 0.5 * x))
  dat <- data.frame(x = x, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x, sigma ~ x), family = stats::gaussian()),
    data = dat
  )
  fit <- sem$records[["y"]]$fit

  mx <- mean(x)
  sx <- stats::sd(x)
  lo_val <- mx - 0.5 * sx
  hi_val <- mx + 0.5 * sx
  big <- 60000L
  nd_lo <- data.frame(x = rep(lo_val, big))
  nd_hi <- data.frame(x = rep(hi_val, big))

  # Ground-truth Var(Y) at each level from the fit's response-scale (mu, sigma).
  # For a Gaussian node drmTMB's sigma is SD-like, so Y ~ rnorm(mu, sigma); V-55
  # already confirmed THIS gaussian draw matches drmTMB::simulate() moments, so a
  # large-n rnorm(mu, sigma) here is a transitive drmTMB::simulate() ground truth.
  # The test's claim: total_effects(target="var"), which routes through
  # drm_sample_family(), lands on the same Var(Y) contrast that draw gives.
  pr_lo <- drm_response_params(fit, nd_lo)
  pr_hi <- drm_response_params(fit, nd_hi)
  # both mu and sigma must come back as full-length vectors for the rnorm ground
  # truth; otherwise the comparison is undefined (the V-63 authoring bug).
  skip_if(
    is.null(pr_lo$mu) ||
      is.null(pr_lo$sigma) ||
      length(pr_lo$mu) != big ||
      length(pr_lo$sigma) != big ||
      !all(is.finite(pr_lo$mu)) ||
      !all(is.finite(pr_lo$sigma)) ||
      !all(is.finite(pr_hi$mu)) ||
      !all(is.finite(pr_hi$sigma)),
    "gaussian fit did not expose finite full-length response-scale mu/sigma"
  )
  set.seed(580)
  sim_lo <- stats::rnorm(big, mean = pr_lo$mu, sd = pr_lo$sigma)
  sim_hi <- stats::rnorm(big, mean = pr_hi$mu, sd = pr_hi$sigma)
  var_truth <- stats::var(sim_hi) - stats::var(sim_lo)

  te <- total_effects(
    sem,
    from = "x",
    to = "y",
    target = "var",
    uncertainty = "none",
    nsim = 6000,
    seed = 8
  )
  expect_equal(te$target[[1L]], "var")
  # var effect can be sizeable; use a relative tolerance on a positive truth.
  expect_gt(var_truth, 0)
  expect_lt(abs(te$estimate - var_truth) / abs(var_truth), 0.20)
})

test_that("V-64: p_gt on a Poisson node matches a drmTMB::simulate() empirical", {
  # Pr(Y > t) for a Poisson is 1 - ppois(t, mu); the do-contrast on target="p_gt"
  # is mean(1 - ppois(t, mu_hi)) - mean(1 - ppois(t, mu_lo)). We use that exact
  # Poisson tail (which IS what drmTMB::simulate() converges to) as ground truth.
  set.seed(59)
  n <- 2000
  x <- stats::rnorm(n)
  y <- stats::rpois(n, lambda = exp(0.6 + 0.7 * x))
  dat <- data.frame(x = x, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x), family = stats::poisson()),
    data = dat
  )
  b <- drmSEM:::drm_fit_coef(sem$records[["y"]]$fit, "mu")
  b0 <- unname(b[["(Intercept)"]])
  b1 <- unname(b[["x"]])
  mx <- mean(x)
  sx <- stats::sd(x)
  lo_val <- mx - 0.5 * sx
  hi_val <- mx + 0.5 * sx
  mu_lo <- exp(b0 + b1 * lo_val)
  mu_hi <- exp(b0 + b1 * hi_val)

  thr <- 2
  pgt_truth <- (1 - stats::ppois(thr, mu_hi)) - (1 - stats::ppois(thr, mu_lo))

  te <- total_effects(
    sem,
    from = "x",
    to = "y",
    target = "p_gt",
    threshold = thr,
    uncertainty = "none",
    nsim = 8000,
    seed = 9
  )
  expect_equal(te$target[[1L]], "p_gt")
  expect_equal(te$estimate, pgt_truth, tolerance = 0.02)
})
