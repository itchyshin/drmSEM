# PINNED GAP: a hurdle mediator reports as fully supported and drops its zeros.
#
# This file asserts a DEFECT, on purpose. Nothing here is a capability test.
#
# The mechanism, verified against drmTMB 0.6.0:
#   * a hurdle node has `model_type = "hurdle_nbinom2"` ...
#   * ... but `family$family` is `"truncated_nbinom2"`, and drmSEM keys on the
#     family NAME (drm_family_name -> fit$family$family);
#   * `truncated_nbinom2` IS in drm_supported_sampler_families(), so check_sem()
#     reports `sampler = TRUE`;
#   * drm_sample_family() then draws a plain truncated NB2 and never consults `hu`,
#     so the hurdle zeros simply do not appear.
#
# Net effect: drmSEM tells the user this mediator is fully supported, then silently
# propagates a distribution missing its entire zero component. That is the exact
# failure class this lane exists to close — but closing it means keying on
# `model_type` rather than the family name, which changes what a mediator
# propagates. That is a SEMANTICS change, so it is GATED and deliberately not done
# here. The gap is made loud instead of left silent.
#
# V-103  `hu` is accepted and ignored (bit-identical draws)
# V-104  the family name cannot express the hurdle distinction

test_that("V-103: `hu` is ignored by the sampler -- draws are bit-identical", {
  n <- 2000L
  base <- list(mu = rep(5, n), sigma = rep(0.5, n))
  set.seed(1)
  without <- drmSEM:::drm_sample_family("truncated_nbinom2", base, n)
  set.seed(1)
  with_hu <- drmSEM:::drm_sample_family(
    "truncated_nbinom2", c(base, list(hu = rep(0.9, n))), n
  )
  # A 90% hurdle should make almost every draw zero. It changes nothing at all.
  expect_identical(without, with_hu)

  # Contrast: `zi` IS honoured, which is what makes the `hu` silence a defect
  # rather than a documented scope boundary.
  set.seed(1)
  with_zi <- drmSEM:::drm_sample_family(
    "nbinom2", c(list(mu = rep(5, n), sigma = rep(0.5, n)), list(zi = rep(0.9, n))), n
  )
  expect_gt(mean(with_zi == 0), 0.8)
})

test_that("V-104: the family name cannot express hurdle vs truncated", {
  # Both a hurdle node and a plain truncated node present the SAME family name, so
  # no name-keyed lookup can tell them apart. This is why the fix is structural.
  expect_true("truncated_nbinom2" %in% drmSEM:::drm_supported_sampler_families())

  # And the sampler claims support for it, which is how the gap stays invisible:
  # check_sem() would report sampler = TRUE for a hurdle mediator.
  n <- 50L
  drmSEM:::drm_sample_family(
    "truncated_nbinom2", list(mu = rep(4, n), sigma = rep(0.5, n)), n
  ) |>
    expect_length(n)
})

test_that("V-104b: a hurdle fit really does present as truncated_nbinom2", {
  skip_if_not_installed("drmTMB")
  set.seed(9)
  n <- 400
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
  # The engine knows it is a hurdle model ...
  expect_identical(fit$model$model_type, "hurdle_nbinom2")
  # ... but the name drmSEM reads does not, and that name is on the supported list.
  expect_identical(drmSEM:::drm_family_name(drmSEM:::drm_fit_family(fit)),
                   "truncated_nbinom2")
  expect_true(
    drmSEM:::drm_family_name(drmSEM:::drm_fit_family(fit)) %in%
      drmSEM:::drm_supported_sampler_families()
  )
  # `hu` is a modelled component of the fit, so the information IS there -- drmSEM
  # simply never routes it to the sampler.
  expect_true("hu" %in% drmSEM:::drm_fit_components(fit))
})
