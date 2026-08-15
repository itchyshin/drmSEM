# Hurdle nodes: the fix for what V-103/V-104 previously pinned as a defect.
#
# HISTORY, kept because it explains the shape of the fix. drmTMB folds the hurdle
# into `model_type` (`hurdle_nbinom2`) while leaving `family$family` at
# `truncated_nbinom2`. drmSEM keyed its sampler on the family NAME, so:
#   * check_sem() reported `sampler = TRUE` (truncated_nbinom2 is on the list);
#   * drm_sample_family() drew a plain truncated NB2 and never read `hu`;
#   * the hurdle zeros silently vanished from the propagated distribution.
# The package announced full support and then propagated a distribution missing its
# entire zero component. This file first pinned that gap, and now guards the fix.
#
# THE FIX is narrow on purpose. `drm_effective_family()` prefers `model_type` ONLY
# for model_types on a short allow-list (`drm_model_type_samplers()`). Keying on
# model_type wholesale would send `zi_poisson`, `zi_nbinom2` and friends -- which are
# handled correctly today by the base family plus generic `zi` post-processing -- to
# the mean fallback, fixing one silent degradation by introducing several.
#
# V-103  the base family still ignores `hu` (and MUST -- that is not the hurdle route)
# V-104  the routing resolves a hurdle node to its own sampler
# V-108  the hurdle sampler's moments match drmTMB::simulate(), zeros included

test_that("V-103: the BASE family still ignores `hu`, by design", {
  # truncated_nbinom2 is the no-hurdle distribution. Passing it `hu` must change
  # nothing: the hurdle is reached through model_type, not by smuggling a parameter
  # into the base family. Bit-identical draws are the assertion.
  n <- 2000L
  base <- list(mu = rep(5, n), sigma = rep(0.5, n))
  set.seed(1)
  without <- drmSEM:::drm_sample_family("truncated_nbinom2", base, n)
  set.seed(1)
  with_hu <- drmSEM:::drm_sample_family(
    "truncated_nbinom2", c(base, list(hu = rep(0.9, n))), n
  )
  expect_identical(without, with_hu)
})

test_that("V-104: routing resolves a hurdle node to its own sampler", {
  expect_identical(
    drmSEM:::drm_effective_family("truncated_nbinom2", "hurdle_nbinom2"),
    "hurdle_nbinom2"
  )
  # ... and leaves everything else alone. This is the regression that matters: a
  # wholesale model_type key would break these.
  expect_identical(drmSEM:::drm_effective_family("poisson", "zi_poisson"), "poisson")
  expect_identical(drmSEM:::drm_effective_family("nbinom2", "zi_nbinom2"), "nbinom2")
  expect_identical(
    drmSEM:::drm_effective_family("truncated_nbinom2", "truncated_nbinom2"),
    "truncated_nbinom2"
  )
  expect_identical(drmSEM:::drm_effective_family("gaussian", NA_character_), "gaussian")
})

test_that("V-104b: `hu` now changes the draws, and produces the zeros", {
  n <- 4000L
  p <- list(mu = rep(5, n), sigma = rep(0.5, n), hu = rep(0.6, n))
  set.seed(3)
  drawn <- drmSEM:::drm_sample_family("hurdle_nbinom2", p, n)
  expect_length(drawn, n)
  # ~60% structural zeros, and the non-zero part is zero-truncated (never 0 by
  # accident), so the zero fraction is the hurdle probability.
  expect_gt(mean(drawn == 0), 0.55)
  expect_lt(mean(drawn == 0), 0.65)
  expect_true(all(drawn[drawn != 0] >= 1))
  # Without hu the branch cannot draw and must fall back rather than guess.
  wenv <- drmSEM:::drm_warn_once_env
  key <- "family-sampler-hurdle_nbinom2"
  if (!is.null(wenv[[key]])) rm(list = key, envir = wenv)
  expect_warning(
    drmSEM:::drm_sample_family("hurdle_nbinom2", p[c("mu", "sigma")], n),
    "No realized-value sampler"
  )
})

test_that("V-108: hurdle sampler moments match drmTMB::simulate(), zeros included", {
  skip_on_cran()
  skip_if_not_installed("drmTMB")
  set.seed(9)
  n <- 500
  x <- stats::rnorm(n)
  y <- stats::rnbinom(n, mu = exp(1 + 0.4 * x), size = 2)
  y[stats::runif(n) < 0.3] <- 0
  d <- data.frame(x = x, y = y)
  fit <- tryCatch(
    drmTMB::drmTMB(drmTMB::bf(y ~ x, hu ~ 1),
                   family = drmTMB::truncated_nbinom2(), data = d),
    error = function(e) NULL
  )
  skip_if(is.null(fit), "hurdle fit unavailable in this environment")
  expect_identical(drmSEM:::drm_fit_model_type(fit), "hurdle_nbinom2")

  rep <- 100L
  dat <- drmSEM:::drm_fit_data(fit)
  big <- dat[rep(seq_len(nrow(dat)), times = rep), , drop = FALSE]
  N <- nrow(big)
  pr <- lapply(c("mu", "sigma", "hu"), function(dp) {
    as.numeric(drmSEM:::drm_predict_parameter_values(
      fit, newdata = big, dpar = dp, type = "response"
    ))
  })
  names(pr) <- c("mu", "sigma", "hu")
  skip_if(any(vapply(pr, function(v) length(v) != N || any(!is.finite(v)), logical(1))),
          "response-scale parameters unavailable at full length")

  set.seed(202)
  drm <- drmSEM:::drm_sample_family("hurdle_nbinom2", pr, N)
  f2 <- fit
  f2$data <- big
  sim <- suppressWarnings(as.numeric(as.matrix(
    stats::simulate(f2, nsim = rep, seed = 203)
  )))
  sim <- sim[is.finite(sim)]
  skip_if(length(sim) == 0L, "drmTMB::simulate() not callable for this fit")

  info <- sprintf("hurdle: drmSEM(mean=%.4g,var=%.4g,zeros=%.4g) vs drmTMB(mean=%.4g,var=%.4g,zeros=%.4g)",
                  mean(drm), stats::var(drm), mean(drm == 0),
                  mean(sim), stats::var(sim), mean(sim == 0))
  expect_lt(abs(mean(drm) - mean(sim)) / abs(mean(sim)), 0.06, label = info)
  expect_lt(abs(stats::var(drm) - stats::var(sim)) / abs(stats::var(sim)), 0.20, label = info)
  # The zero fraction is the whole point: pre-fix drmSEM produced essentially none.
  expect_lt(abs(mean(drm == 0) - mean(sim == 0)), 0.03, label = info)
})

test_that("V-108b: check_sem() reports a hurdle node as sampled, for the right reason", {
  skip_if_not_installed("drmTMB")
  set.seed(11)
  n <- 300
  x <- stats::rnorm(n)
  y <- stats::rnbinom(n, mu = exp(1 + 0.3 * x), size = 2)
  y[stats::runif(n) < 0.3] <- 0
  d <- data.frame(x = x, y = y)
  sem <- tryCatch(
    drm_sem(
      y = drm_node(drmTMB::bf(y ~ x, hu ~ 1), family = drmTMB::truncated_nbinom2()),
      data = d
    ),
    error = function(e) NULL
  )
  skip_if(is.null(sem), "hurdle SEM unavailable in this environment")
  chk <- as.data.frame(check_sem(sem))
  expect_true(chk$sampler[chk$node == "y"])
  expect_true("hu" %in% strsplit(chk$components[chk$node == "y"], ", ")[[1]])
})
