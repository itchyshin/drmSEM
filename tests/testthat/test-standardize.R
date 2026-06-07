# Pure-logic tests for the SCALING MATH of standardize().
#
# Motivation: standardize() is otherwise exercised only indirectly (via
# average() in test-model-set.R), which checks that the std.estimate column
# EXISTS but never checks its VALUES. A sign error or a wrong divisor in the
# `latent` branch would pass the suite. These tests pin the exact arithmetic.
#
# No drmTMB / no engine. The public entry point standardize.drm_sem() reads only
# a handful of list elements off the object and off each fitted node:
#
#   object$data                      -> the model data.frame (predictor SDs)
#   object$order                     -> node names (character)
#   object$records[[nm]]$fit         -> fitted node (a fake here)
#   object$records[[nm]]$family      -> family name (for the link label)
#   object$records[[nm]]$components  -> modelled dpars
#   object$records[[nm]]$identifiers -> node identifier tokens (endogeneity)
#
# and off each fitted node, via the extractors in R/extractors.R:
#
#   fit$coefficients         -> named list keyed by dpar -> named numeric vector
#   fit$formula$entries      -> list of entries with $dpar, $response, $lhs, $rhs
#   fit$family, fit$data
#
# A `fakefit` carrying exactly those fields is faithful: standardize() and the
# extractors it calls (drm_fit_coef, drm_fixed_design, drm_fit_component_predictors)
# touch nothing else. vcov() has no fakefit method, so drm_fit_vcov() catches the
# error and returns NULL -> std.error = NA, which is irrelevant to the scaling
# math under test. The design matrix is built with base model.matrix(), so the
# fake reproduces the real linear-predictor construction exactly.
#
# Derived scaling conventions (read off R/standardize.R, not assumed):
#   sd_x   : std.estimate = estimate * sd(predictor_column)
#            factor / non-numeric predictor -> sd = 1 (estimate unchanged)
#   latent : additionally divide by the SD of the TARGET component's fitted
#            linear predictor eta = X %*% b (NOT the outcome's marginal SD),
#            after Grace & Bollen. Always reported on the component link scale.

# ---- fake-object builders ---------------------------------------------------

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

# A two-node Gaussian-mean chain  x -> M -> Y  with a factor predictor grp on Y.
#   M: mu = 0.1 + b_xm * x
#   Y: mu = -0.2 + b_my * m + b_grpB * grpB
# Coefficients are hand-picked so every standardized value is known in closed
# form. b_my is NEGATIVE to pin sign preservation.
build_chain_sem <- function() {
  set.seed(1)
  n <- 200
  dat <- data.frame(
    x   = rnorm(n, 0, 1),
    m   = rnorm(n, 0, 1),
    grp = factor(rep(c("A", "B"), length.out = n))
  )

  fit_M <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = 0.1, x = 2.0)),
    entries   = list(fml_entry("mu", "m", quote(m), quote(x))),
    family    = "gaussian", data = dat
  )
  fit_Y <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = -0.2, m = -3.0, grpB = 0.7)),
    entries   = list(fml_entry("mu", "y", quote(y), quote(m + grp))),
    family    = "gaussian", data = dat
  )

  structure(
    list(
      data  = dat,
      order = c("M", "Y"),
      records = list(
        M = list(fit = fit_M, family = "gaussian",
                 components = "mu", identifiers = "m"),
        Y = list(fit = fit_Y, family = "gaussian",
                 components = "mu", identifiers = "y")
      )
    ),
    class = "drm_sem"
  )
}

pick <- function(tab, term) {
  tab$std.estimate[match(term, tab$term)]
}

# ---- sd_x scaling -----------------------------------------------------------

test_that("sd_x multiplies each coefficient by its predictor SD", {
  obj <- build_chain_sem()
  dat <- obj$data
  s <- standardize(obj, "sd_x")

  b_xm <- 2.0
  b_my <- -3.0

  # numeric predictor: std.estimate = estimate * sd(column)
  expect_equal(pick(s, "x"), b_xm * stats::sd(dat$x))
  expect_equal(pick(s, "m"), b_my * stats::sd(dat$m))
})

test_that("sd_x leaves a factor coefficient unchanged (SD = 1 convention)", {
  obj <- build_chain_sem()
  s <- standardize(obj, "sd_x")
  # grpB maps back to a non-numeric column -> sd = 1 -> estimate unchanged
  expect_equal(pick(s, "grpB"), 0.7)
})

test_that("sd_x preserves the sign of a negative coefficient", {
  obj <- build_chain_sem()
  s <- standardize(obj, "sd_x")
  expect_lt(pick(s, "m"), 0)        # b_my < 0
  expect_equal(sign(pick(s, "m")), -1)
})

# ---- latent scaling ---------------------------------------------------------

test_that("latent divides sd_x by the target component's linear-predictor SD", {
  obj <- build_chain_sem()
  dat <- obj$data
  s <- standardize(obj, "latent")

  b_xm <- 2.0
  b_my <- -3.0
  b_grpB <- 0.7

  # Reconstruct each target component's fitted linear predictor SD exactly as
  # standardize() does: eta = X %*% b over the model data.
  Xm <- stats::model.matrix(~ x, data = dat)
  bm <- c("(Intercept)" = 0.1, x = b_xm)[colnames(Xm)]
  sclp_M <- stats::sd(as.numeric(Xm %*% bm))

  Xy <- stats::model.matrix(~ m + grp, data = dat)
  by <- c("(Intercept)" = -0.2, m = b_my, grpB = b_grpB)[colnames(Xy)]
  sclp_Y <- stats::sd(as.numeric(Xy %*% by))

  expect_equal(pick(s, "x"), b_xm * stats::sd(dat$x) / sclp_M)
  expect_equal(pick(s, "m"), b_my * stats::sd(dat$m) / sclp_Y)
  expect_equal(pick(s, "grpB"), b_grpB * 1 / sclp_Y)
})

test_that("latent preserves the sign of a negative coefficient", {
  obj <- build_chain_sem()
  s <- standardize(obj, "latent")
  expect_lt(pick(s, "m"), 0)
})

test_that("latent self-consistency: a single-predictor mean path standardizes to 1", {
  # For M: mu = intercept + b_xm * x, the only predictor is x, so the linear
  # predictor is eta = b_xm * x and sd(eta) = |b_xm| * sd(x). Hence
  # latent = b_xm * sd(x) / (|b_xm| * sd(x)) = sign(b_xm) = +1 here. This is an
  # engine-free sanity check that the divisor is the linear-predictor SD and not
  # some other scale.
  obj <- build_chain_sem()
  s <- standardize(obj, "latent")
  expect_equal(pick(s, "x"), 1.0)
})

# ---- link-scale labelling ---------------------------------------------------

test_that("standardized table reports component link scale (log for sigma)", {
  # A node with mu ~ m AND sigma ~ x. The sigma path must carry the log link
  # (link scale), and a single-predictor sigma path also standardizes to 1.
  set.seed(1)
  n <- 200
  dat <- data.frame(x = rnorm(n), m = rnorm(n))

  fit_Y <- make_fakefit(
    coef_list = list(
      mu    = c("(Intercept)" = 0, m = -3.0),
      sigma = c("(Intercept)" = 0, x = 1.5)
    ),
    entries = list(
      fml_entry("mu", "y", quote(y), quote(m)),
      fml_entry("sigma", NA, NA, quote(x))
    ),
    family = "gaussian", data = dat
  )
  obj <- structure(
    list(
      data = dat, order = "Y",
      records = list(Y = list(fit = fit_Y, family = "gaussian",
                              components = c("mu", "sigma"),
                              identifiers = "y"))
    ),
    class = "drm_sem"
  )

  s <- standardize(obj, "latent")
  s <- as.data.frame(s)

  expect_equal(s$link[s$component == "mu"], "identity")
  expect_equal(s$link[s$component == "sigma"], "log")

  # single-predictor sigma path -> latent standardizes to +1 (sign of 1.5)
  expect_equal(s$std.estimate[s$component == "sigma"], 1.0)
})

# ---- OQ-4 sigma_E: theoretical link variance in the latent divisor ----------

test_that("drm_link_latent_var returns the link's theoretical error variance", {
  expect_equal(drmSEM:::drm_link_latent_var("logit"), pi^2 / 3)
  expect_equal(drmSEM:::drm_link_latent_var("probit"), 1)
  expect_equal(drmSEM:::drm_link_latent_var("cloglog"), pi^2 / 6)
  # identity and log carry no constant latent-error term here
  expect_equal(drmSEM:::drm_link_latent_var("identity"), 0)
  expect_equal(drmSEM:::drm_link_latent_var("log"), 0)
})

test_that("drm_latent_divisor adds sigma_E only for a non-identity-link mean path", {
  set.seed(2)
  eta <- stats::rnorm(500, 0, 1.3)
  V <- stats::var(eta)
  # mean path on logit -> sqrt(Var(eta) + pi^2/3)
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "logit"),
               sqrt(V + pi^2 / 3))
  # mean path on identity -> sd(eta) (no inflation)
  expect_equal(drmSEM:::drm_latent_divisor(eta, "mu", "identity"), sqrt(V))
  # a non-mean component (sigma) never gets the term, whatever the link label
  expect_equal(drmSEM:::drm_latent_divisor(eta, "sigma", "log"), sqrt(V))
})

test_that("V-44: a logit-link mean path standardizes by sqrt(Var(eta) + pi^2/3)", {
  set.seed(1)
  n <- 300
  dat <- data.frame(x = stats::rnorm(n))
  b_x <- 1.3
  fit_Y <- make_fakefit(
    coef_list = list(mu = c("(Intercept)" = 0.2, x = b_x)),
    entries   = list(fml_entry("mu", "y", quote(y), quote(x))),
    family    = "binomial", data = dat   # logit-link mu
  )
  obj <- structure(
    list(data = dat, order = "Y",
         records = list(Y = list(fit = fit_Y, family = "binomial",
                                 components = "mu", identifiers = "y"))),
    class = "drm_sem"
  )
  s <- standardize(obj, "latent")

  Xy <- stats::model.matrix(~ x, data = dat)
  by <- c("(Intercept)" = 0.2, x = b_x)[colnames(Xy)]
  eta <- as.numeric(Xy %*% by)
  divisor <- sqrt(stats::var(eta) + pi^2 / 3)        # the OQ-4 sigma_E divisor

  expect_equal(pick(s, "x"), b_x * stats::sd(dat$x) / divisor)
  # the sigma_E term shrinks the standardized coefficient vs the old sd(eta)-only
  # divisor, so a single-predictor logit mean path is now strictly below 1.
  expect_lt(pick(s, "x"), 1)
})
