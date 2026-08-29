# Tests for Gelman 2-SD Standardization & GLM Latent Divisors (OQ-4, V-154..V-156)

make_fakefit <- function(coef_list, entries, family, data) {
  structure(
    list(
      coefficients = coef_list,
      formula = list(entries = entries, calls = NULL, names = NULL),
      family = family,
      data = data
    ),
    class = "fakefit"
  )
}

fml_entry <- function(dpar, response, lhs, rhs) {
  list(dpar = dpar, response = response, lhs = lhs, rhs = rhs)
}

build_complex_sem <- function() {
  set.seed(42)
  n <- 300
  dat <- data.frame(
    x = stats::rnorm(n, 0, 1.5),
    z = stats::rnorm(n, 2, 0.8),
    grp = factor(sample(c("Control", "Treated"), n, replace = TRUE)),
    binary_num = sample(c(0, 1), n, replace = TRUE),
    m = stats::rnorm(n, 0, 1.2),
    y = stats::rnorm(n, 0, 2.0)
  )

  # Node M: mu = 0.5 + 1.8 * x + (-0.9) * z + 0.6 * grpTreated
  fit_M <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = 0.5, x = 1.8, z = -0.9, grpTreated = 0.6)),
    entries = list(fml_entry("mu", "m", quote(m), quote(x + z + grp))),
    family = "gaussian",
    data = dat
  )

  # Node Y: mu = -1.0 + 2.5 * m + 1.2 * binary_num, sigma = 0.2 + 0.7 * x
  fit_Y <- make_fakefit(
    coef_list = list(
      mu = c("(Intercept)" = -1.0, m = 2.5, binary_num = 1.2),
      sigma = c("(Intercept)" = 0.2, x = 0.7)
    ),
    entries = list(
      fml_entry("mu", "y", quote(y), quote(m + binary_num)),
      fml_entry("sigma", NA, NA, quote(x))
    ),
    family = "gaussian",
    data = dat
  )

  structure(
    list(
      data = dat,
      order = c("M", "Y"),
      records = list(
        M = list(
          fit = fit_M,
          family = "gaussian",
          components = "mu",
          identifiers = "m"
        ),
        Y = list(
          fit = fit_Y,
          family = "gaussian",
          components = c("mu", "sigma"),
          identifiers = "y"
        )
      )
    ),
    class = "drm_sem"
  )
}

pick_val <- function(tab, term, component = "mu") {
  idx <- which(tab$term == term & tab$component == component)
  if (length(idx) == 0L) return(NA_real_)
  tab$std.estimate[idx[1L]]
}

# -----------------------------------------------------------------------------
# V-154: Gelman 2-SD standardization recovery
# -----------------------------------------------------------------------------

test_that("V-154: Gelman 2-SD standardization doubles continuous predictors while binary/factor remain invariant (sd_x)", {
  sem <- build_complex_sem()
  dat <- sem$data

  s_1sd <- standardize(sem, method = "sd_x", scale = "1sd")
  s_2sd <- standardize(sem, method = "sd_x", scale = "2sd")

  # Continuous predictors: x, z, m
  expect_equal(pick_val(s_1sd, "x", "mu"), 1.8 * stats::sd(dat$x))
  expect_equal(pick_val(s_2sd, "x", "mu"), 1.8 * 2 * stats::sd(dat$x))
  expect_equal(pick_val(s_2sd, "x", "mu"), 2 * pick_val(s_1sd, "x", "mu"))

  expect_equal(pick_val(s_1sd, "z", "mu"), -0.9 * stats::sd(dat$z))
  expect_equal(pick_val(s_2sd, "z", "mu"), -0.9 * 2 * stats::sd(dat$z))
  expect_equal(pick_val(s_2sd, "z", "mu"), 2 * pick_val(s_1sd, "z", "mu"))

  expect_equal(pick_val(s_1sd, "m", "mu"), 2.5 * stats::sd(dat$m))
  expect_equal(pick_val(s_2sd, "m", "mu"), 2.5 * 2 * stats::sd(dat$m))
  expect_equal(pick_val(s_2sd, "m", "mu"), 2 * pick_val(s_1sd, "m", "mu"))

  # Non-mean component continuous predictor (x on sigma)
  expect_equal(pick_val(s_1sd, "x", "sigma"), 0.7 * stats::sd(dat$x))
  expect_equal(pick_val(s_2sd, "x", "sigma"), 0.7 * 2 * stats::sd(dat$x))
  expect_equal(pick_val(s_2sd, "x", "sigma"), 2 * pick_val(s_1sd, "x", "sigma"))

  # Factor predictor: grpTreated -> invariant
  expect_equal(pick_val(s_1sd, "grpTreated", "mu"), 0.6)
  expect_equal(pick_val(s_2sd, "grpTreated", "mu"), 0.6)
  expect_equal(pick_val(s_2sd, "grpTreated", "mu"), pick_val(s_1sd, "grpTreated", "mu"))

  # Binary numeric indicator {0, 1}: binary_num -> invariant
  expect_equal(pick_val(s_1sd, "binary_num", "mu"), 1.2)
  expect_equal(pick_val(s_2sd, "binary_num", "mu"), 1.2)
  expect_equal(pick_val(s_2sd, "binary_num", "mu"), pick_val(s_1sd, "binary_num", "mu"))
})

test_that("V-154: Gelman 2-SD standardization doubles continuous predictors while binary/factor remain invariant (latent)", {
  sem <- build_complex_sem()

  s_lat_1sd <- standardize(sem, method = "latent", scale = "1sd")
  s_lat_2sd <- standardize(sem, method = "latent", scale = "2sd")

  # Continuous predictors are exactly doubled
  expect_equal(pick_val(s_lat_2sd, "x", "mu"), 2 * pick_val(s_lat_1sd, "x", "mu"))
  expect_equal(pick_val(s_lat_2sd, "z", "mu"), 2 * pick_val(s_lat_1sd, "z", "mu"))
  expect_equal(pick_val(s_lat_2sd, "m", "mu"), 2 * pick_val(s_lat_1sd, "m", "mu"))
  expect_equal(pick_val(s_lat_2sd, "x", "sigma"), 2 * pick_val(s_lat_1sd, "x", "sigma"))

  # Factor and binary numeric predictors remain invariant
  expect_equal(pick_val(s_lat_2sd, "grpTreated", "mu"), pick_val(s_lat_1sd, "grpTreated", "mu"))
  expect_equal(pick_val(s_lat_2sd, "binary_num", "mu"), pick_val(s_lat_1sd, "binary_num", "mu"))
})

# -----------------------------------------------------------------------------
# V-155: Latent-scale standardization across GLM links (logit, probit, cloglog, log)
# -----------------------------------------------------------------------------

test_that("V-155: Theoretical link error variances match Grace et al. (2018) & Nakagawa & Schielzeth (2010)", {
  expect_equal(drmSEM:::drm_link_latent_var("logit"), pi^2 / 3)
  expect_equal(drmSEM:::drm_link_latent_var("probit"), 1.0)
  expect_equal(drmSEM:::drm_link_latent_var("cloglog"), pi^2 / 6)
  expect_equal(drmSEM:::drm_link_latent_var("identity"), 0.0)
  expect_equal(drmSEM:::drm_link_latent_var("unknown_link"), 0.0)

  # Log link: mean-dependent variance log(1 + 1/mu_bar)
  eta_test <- c(0, 1, 2)
  mu_bar <- mean(exp(eta_test))
  expect_equal(drmSEM:::drm_link_latent_var("log", eta = eta_test), log(1 + 1 / mu_bar))
  expect_equal(drmSEM:::drm_link_latent_var("log", eta = NULL), 0.0)
})

test_that("V-155: Latent divisor correctly incorporates logit, probit, cloglog, and log theoretical variances", {
  set.seed(123)
  eta <- stats::rnorm(200, mean = 0.5, sd = 1.1)
  V <- stats::var(eta)

  # Logit
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "logit"), sqrt(V + pi^2 / 3))

  # Probit
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "probit"), sqrt(V + 1.0))

  # Cloglog
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "cloglog"), sqrt(V + pi^2 / 6))

  # Log
  mu_bar <- mean(exp(eta))
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "log"), sqrt(V + log(1 + 1 / mu_bar)))

  # Identity
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "identity"), sqrt(V))

  # Non-mu component (e.g. sigma, zi) never gets theoretical error variance
  expect_equal(drmSEM:::drm_latent_divisor(eta, "sigma", "log"), sqrt(V))
  expect_equal(drmSEM:::drm_latent_divisor(eta, "zi", "logit"), sqrt(V))
})

test_that("V-155: Latent standardization across log-link and binary links in a full SEM", {
  set.seed(99)
  n <- 250
  dat <- data.frame(
    x = stats::rnorm(n, 0, 1),
    m = stats::rpois(n, lambda = 3),
    y = stats::rbinom(n, size = 1, prob = 0.4)
  )

  # Node M: log-link Poisson count node: mu = 0.8 + 0.4 * x
  fit_M <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = 0.8, x = 0.4)),
    entries = list(fml_entry("mu", "m", quote(m), quote(x))),
    family = "poisson",
    data = dat
  )

  # Node Y: probit-link binary node: mu = -0.2 + 0.5 * m
  fit_Y <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = -0.2, m = 0.5)),
    entries = list(fml_entry("mu", "y", quote(y), quote(m))),
    family = "binomial", # we will set nominal link to probit
    data = dat
  )

  sem <- structure(
    list(
      data = dat,
      order = c("M", "Y"),
      records = list(
        M = list(
          fit = fit_M,
          family = "poisson", # nominal link: log
          components = "mu",
          identifiers = "m"
        ),
        Y = list(
          fit = fit_Y,
          family = "binomial", # nominal link: logit
          components = "mu",
          identifiers = "y"
        )
      )
    ),
    class = "drm_sem"
  )

  s_lat <- standardize(sem, method = "latent", scale = "1sd")

  # Closed-form calculation for M (Poisson, log link):
  Xm <- stats::model.matrix(~x, data = dat)
  bm <- c("(Intercept)" = 0.8, x = 0.4)[colnames(Xm)]
  eta_m <- as.numeric(Xm %*% bm)
  var_eta_m <- stats::var(eta_m)
  mu_bar_m <- mean(exp(eta_m))
  div_m <- sqrt(var_eta_m + log(1 + 1 / mu_bar_m))
  expected_x_std <- 0.4 * stats::sd(dat$x) / div_m

  expect_equal(pick_val(s_lat, "x", "mu"), expected_x_std)

  # Closed-form calculation for Y (Binomial, logit link):
  Xy <- stats::model.matrix(~m, data = dat)
  by <- c("(Intercept)" = -0.2, m = 0.5)[colnames(Xy)]
  eta_y <- as.numeric(Xy %*% by)
  var_eta_y <- stats::var(eta_y)
  div_y <- sqrt(var_eta_y + pi^2 / 3)
  expected_m_std <- 0.5 * stats::sd(dat$m) / div_y

  expect_equal(pick_val(s_lat, "m", "mu"), expected_m_std)
})

# -----------------------------------------------------------------------------
# V-156: Standardized table column integrity, print formatting, and component reporting
# -----------------------------------------------------------------------------

test_that("V-156: Return object has correct class, attributes, and column structure", {
  sem <- build_complex_sem()
  s <- standardize(sem, method = "latent", scale = "2sd")

  expect_s3_class(s, "drm_standardized_paths")
  expect_s3_class(s, "drm_paths")
  expect_s3_class(s, "data.frame")

  expect_equal(attr(s, "method"), "latent")
  expect_equal(attr(s, "scale"), "2sd")

  expected_cols <- c(
    "from", "to", "component", "link", "term",
    "estimate", "std.error", "statistic", "p.value",
    "endogenous", "std.estimate"
  )
  expect_true(all(expected_cols %in% names(s)))
})

test_that("V-156: Print method formats header and standardized values cleanly", {
  sem <- build_complex_sem()
  s <- standardize(sem, method = "latent", scale = "2sd")

  out <- utils::capture.output(print(s))
  full_out <- paste(out, collapse = " ")
  expect_true(grepl("<drmSEM standardized paths \\(latent, 2sd\\):", full_out))
  expect_true(grepl("std\\.estimate", full_out))
})

test_that("V-156: standardize.drm_psem matches standardize.drm_sem identically", {
  sem <- build_complex_sem()
  class(sem) <- c("drm_psem", "drm_sem")

  s_psem <- standardize(sem, method = "latent", scale = "2sd")
  s_sem <- standardize.drm_sem(sem, method = "latent", scale = "2sd")

  expect_equal(as.data.frame(s_psem), as.data.frame(s_sem))
})
