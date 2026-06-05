# Recovery checks: validate the effect engine against closed-form results on
# identity-link Gaussian DAGs (where the Gaussian sampler is exact), and the
# specificity of d-separation. Requires the drmTMB engine; run in CI / cloud.

skip_if_not_installed("drmTMB")

# Contrast width used by drm_build_scenarios(): at = mean +/- 0.5*sd, so the
# low->high change in `from` equals sd(from).
contrast_width <- function(x) stats::sd(x)

test_that("V-15: Gaussian mean-mediated effect equals the product of fitted path coefficients", {
  set.seed(7)
  n <- 1000
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.4 * x, 1)
  y <- stats::rnorm(n, 0.6 * m, 1)
  dat <- data.frame(x, m, y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = dat
  )

  p <- paths(sem)
  b_xm <- p$estimate[p$from == "x" & p$to == "m" & p$component == "mu"]
  b_my <- p$estimate[p$from == "m" & p$to == "y" & p$component == "mu"]
  s <- contrast_width(dat$x)

  # draw = FALSE makes the propagation deterministic; on identity links the
  # mean-mediated effect is exactly b_xm * b_my * s.
  ie <- indirect_effects(sem, from = "x", to = "y", draw = FALSE, n_sim = 1)
  mm <- ie$estimate[ie$quantity == "mean_mediated"]

  expect_equal(mm, b_xm * b_my * s, tolerance = 0.02)
  # No direct x -> y edge, so the controlled direct effect is ~0.
  expect_equal(ie$estimate[ie$quantity == "direct"], 0, tolerance = 0.02)
})

test_that("V-14: total = direct + indirect on an identity-link DAG with a direct edge", {
  set.seed(9)
  n <- 1000
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.5 * x, 1)
  y <- stats::rnorm(n, 0.3 * x + 0.6 * m, 1)
  dat <- data.frame(x, m, y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ x + m), family = stats::gaussian()),
    data = dat
  )

  p <- paths(sem)
  b_xy <- p$estimate[p$from == "x" & p$to == "y" & p$component == "mu"]
  b_xm <- p$estimate[p$from == "x" & p$to == "m" & p$component == "mu"]
  b_my <- p$estimate[p$from == "m" & p$to == "y" & p$component == "mu"]
  s <- contrast_width(dat$x)

  tot <- total_effects(sem, from = "x", to = "y", mediation = "mean", draw = FALSE)
  ie <- indirect_effects(sem, from = "x", to = "y", draw = FALSE, n_sim = 1)
  direct <- ie$estimate[ie$quantity == "direct"]
  indirect <- ie$estimate[ie$quantity == "mean_mediated"]

  expect_equal(direct, b_xy * s, tolerance = 0.02)
  expect_equal(indirect, b_xm * b_my * s, tolerance = 0.02)
  expect_equal(tot$estimate, (b_xy + b_xm * b_my) * s, tolerance = 0.02)
  # decomposition closes: total = direct + indirect
  expect_equal(tot$estimate, direct + indirect, tolerance = 0.02)
})

test_that("V-16: d-separation does NOT over-reject a true non-edge (specificity)", {
  # Correct chain x -> m -> y. The claim x _||_ y | {m} is TRUE, so its p-value
  # is ~Uniform(0,1) under the null. A single seed is therefore fragile; instead
  # check the rejection RATE over several seeds stays near the nominal 0.05.
  reject <- 0L
  seeds <- 1:8
  for (sd_i in seeds) {
    set.seed(sd_i)
    n <- 300
    x <- stats::rnorm(n)
    m <- stats::rnorm(n, 0.7 * x, 1)
    y <- stats::rnorm(n, 0.7 * m, 1)
    dat <- data.frame(x, m, y)
    sem <- drm_sem(
      m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
      y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
      data = dat
    )
    d <- dsep(sem)
    claim <- d[d$x == "x" & d$y == "y", ]
    expect_equal(nrow(claim), 1L)
    expect_true(is.finite(claim$p.value) && claim$p.value >= 0 && claim$p.value <= 1)
    if (isTRUE(claim$p.value < 0.05)) reject <- reject + 1L
  }
  # Expected rejections under the null ~ 0.4 / 8; P(>= 3) is negligible.
  expect_lte(reject, 3L)
})
