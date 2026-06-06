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

  # uncertainty = "none" makes the propagation deterministic; on identity links
  # the mean-mediated effect is exactly b_xm * b_my * s.
  ie <- indirect_effects(sem, from = "x", to = "y", uncertainty = "none", nsim = 1)
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

  tot <- total_effects(sem, from = "x", to = "y", method = "gcomp", uncertainty = "none")
  ie <- indirect_effects(sem, from = "x", to = "y", uncertainty = "none", nsim = 1)
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

test_that("V-41: indirect_effects() distribution_mediated is real, closes, and is reproducible", {
  # End-to-end lock on a LIVE fit (the engine-free V-36..V-40 pin drm_decomp_legs).
  # DGP: mediator M has mean a*x and a log-sd that RISES with x (x -> sigma(M)),
  # feeding a lognormal outcome whose response mean is convex in M -- so a real
  # distribution-mediated (Jensen-gap) channel must appear.
  set.seed(21)
  n <- 4000
  x <- stats::rnorm(n)
  a <- 0.4; s0 <- -0.2; s1 <- 0.9; k <- 0.5
  m <- stats::rnorm(n, a * x, exp(s0 + s1 * x))
  y <- stats::rlnorm(n, meanlog = k * m, sdlog = 0.3)
  dat <- data.frame(x, m, y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x, sigma ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = drmTMB::lognormal()),
    data = dat
  )

  ie <- indirect_effects(sem, from = "x", to = "y",
                         uncertainty = "none", nsim = 4000, seed = 5)
  dm  <- ie$estimate[ie$quantity == "distribution_mediated"]
  mm  <- ie$estimate[ie$quantity == "mean_mediated"]
  ind <- ie$estimate[ie$quantity == "indirect"]

  expect_gt(dm, 0)                              # the distributional channel is real
  expect_equal(ind, mm + dm, tolerance = 1e-6)  # additive identity, end-to-end

  # same seed -> identical decomposition (seed plumbing on the live path)
  ie2 <- indirect_effects(sem, from = "x", to = "y",
                          uncertainty = "none", nsim = 4000, seed = 5)
  expect_equal(ie$estimate, ie2$estimate, tolerance = 1e-10)
})
