# Recovery: a latent common cause makes DAG d-separation wrong, MAG m-separation right.
#
# DGP: unmodelled L -> x and L -> y (Gaussian). The piecewise fits omit L from the
# likelihood (x ~ 1, y ~ 1). For MAG basis_set(), structural edges L -> x and L -> y
# must appear on the DAG before marginalisation — so the MAG object declares those
# edges via formulas while the same misspecified intercept-only likelihood is the
# comparison target for dsep() on the DAG side.
#
# V-118  DAG basis_set asserts a false x _||_ y independence; MAG drops it
# V-119  live dsep(): DAG rejects the false claim; MAG omits it from Fisher's C

skip_if_not_installed("drmTMB")

simulate_latent_common_cause_dgp <- function(n = 600L, seed = 42L) {
  set.seed(seed)
  L <- stats::rnorm(n)
  x <- stats::rnorm(n, mean = 0.85 * L, sd = 0.5)
  y <- stats::rnorm(n, mean = 0.85 * L, sd = 0.5)
  data.frame(L, x, y)
}

has_xy_independence_claim <- function(bs, x_nm = "x", y_nm = "y") {
  any(
    (bs$x == x_nm & bs$y == y_nm) | (bs$x == y_nm & bs$y == x_nm)
  )
}

test_that("V-118: DAG basis_set claims x _||_ y when a latent common cause is omitted", {
  dat <- simulate_latent_common_cause_dgp()

  sem_dag <- drm_sem(
    x = drm_node(drmTMB::bf(x ~ 1), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ 1), family = stats::gaussian()),
    data = dat
  )

  bs <- basis_set(sem_dag)
  expect_true(has_xy_independence_claim(bs))
  xy <- bs[(bs$x == "x" & bs$y == "y") | (bs$x == "y" & bs$y == "x"), , drop = FALSE]
  expect_equal(nrow(xy), 1L)
  expect_match(xy$claim[[1L]], " _\\|\\|_ ")
})

test_that("V-118: MAG basis_set drops the false x-y claim when latent = L is declared", {
  dat <- simulate_latent_common_cause_dgp()

  sem_mag <- drm_sem(
    x = drm_node(drmTMB::bf(x ~ L), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ L), family = stats::gaussian()),
    data = dat,
    latent = "L"
  )

  # Same structural edges, MAG stripped: DAG d-separation claims x _||_ y | {L}.
  sem_dag <- sem_mag
  sem_dag$latents <- character(0)
  sem_dag$mag <- NULL

  bs_dag <- basis_set(sem_dag)
  bs_mag <- basis_set(sem_mag)

  expect_true(has_xy_independence_claim(bs_dag))
  expect_false(has_xy_independence_claim(bs_mag))
  expect_false(any(bs_mag$x == "L" | bs_mag$y == "L"))
  expect_lt(nrow(bs_mag), nrow(bs_dag))
})

test_that("V-119: live dsep() rejects the DAG false claim; MAG omits it from Fisher's C", {
  dat <- simulate_latent_common_cause_dgp()

  sem_dag <- drm_sem(
    x = drm_node(drmTMB::bf(x ~ 1), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ 1), family = stats::gaussian()),
    data = dat
  )

  sem_mag <- drm_sem(
    x = drm_node(drmTMB::bf(x ~ L), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ L), family = stats::gaussian()),
    data = dat,
    latent = "L"
  )

  d_dag <- dsep(sem_dag)
  xy <- d_dag[(d_dag$x == "x" & d_dag$y == "y") | (d_dag$x == "y" & d_dag$y == "x"), , drop = FALSE]
  expect_equal(nrow(xy), 1L)
  expect_equal(xy$status[[1L]], "ok")
  expect_lt(xy$p.value[[1L]], 0.05)

  fc_dag <- fisher_c(d_dag)
  expect_lt(fc_dag$p.value, 0.05)

  d_mag <- suppressWarnings(dsep(sem_mag))
  expect_false(has_xy_independence_claim(d_mag))
  fc_mag <- fisher_c(d_mag)
  if (fc_mag$n_claims > 0L) {
    expect_gt(fc_mag$p.value, 0.05)
  }
})
