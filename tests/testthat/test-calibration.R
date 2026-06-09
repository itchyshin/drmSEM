# V-17: calibration of the any-component d-separation test (Fisher's C basis).
# A small Monte-Carlo study: under a correctly specified chain x -> m -> y the
# claim x _||_ y | {m} is TRUE, so its p-value should be ~Uniform (Type-I near
# the nominal 0.05); when a real x -> y edge is omitted, the claim is FALSE and
# the test should reject it (power). Modest reps keep CI fast; the fuller study
# is in the calibration vignette. Requires drmTMB; runs in CI.

skip_if_not_installed("drmTMB")

# Fit x -> m -> y and return the p-value of the x _||_ y | {m} claim.
# beta_xy = 0 is the null (no direct edge); beta_xy > 0 omits a real edge.
chain_claim_p <- function(seed, beta_xy = 0, n = 250) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.7 * x, 1)
  y <- stats::rnorm(n, beta_xy * x + 0.7 * m, 1)
  dat <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::gaussian()),
    data = dat
  )
  d <- dsep(sem)
  p <- d$p.value[d$x == "x" & d$y == "y"]
  if (length(p) == 1L) p else NA_real_
}

test_that("V-17: d-separation Type-I rate is near nominal and power is high", {
  reps <- 20

  p_null <- vapply(seq_len(reps), chain_claim_p, numeric(1), beta_xy = 0)
  type1 <- mean(p_null < 0.05, na.rm = TRUE)

  p_alt <- vapply(
    seq_len(reps),
    function(s) chain_claim_p(1000 + s, beta_xy = 0.6),
    numeric(1)
  )
  power <- mean(p_alt < 0.05, na.rm = TRUE)

  cat(sprintf(
    "\nV-17 calibration (%d reps): Type-I = %.2f (target ~0.05), power = %.2f\n",
    reps,
    type1,
    power
  ))

  # Every claim must yield a usable p-value.
  expect_true(all(is.finite(p_null)) && all(is.finite(p_alt)))
  # Null p-values roughly uniform => not badly inflated.
  expect_lt(type1, 0.25)
  # A real omitted edge is detected with high probability.
  expect_gt(power, 0.70)
})
