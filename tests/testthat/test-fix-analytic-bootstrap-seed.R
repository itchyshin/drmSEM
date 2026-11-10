# Regression: drm_analytic_or_abort() required `seed` even when the caller
# omits it, so bootstrap paths that use analytic functionals crashed.

fix_chain_sem <- local({
  cache <- NULL
  function() {
    skip_if_not_installed("drmTMB")
    if (is.null(cache)) {
      set.seed(20260901)
      n <- 300
      x <- stats::rnorm(n)
      g <- factor(sample(c("A", "B"), n, replace = TRUE))
      m <- 0.5 * x + 0.4 * (g == "B") + stats::rnorm(n, 0, 0.5)
      y <- 0.3 * x + 0.8 * m + stats::rnorm(n, 0, exp(-0.2 + 0.3 * x))
      dat <- data.frame(x, g, m, y)
      cache <<- drm_sem(
        m = drm_node(drmTMB::bf(m ~ x + g), family = stats::gaussian()),
        y = drm_node(drmTMB::bf(y ~ x + m, sigma ~ x), family = stats::gaussian()),
        data = dat
      )
    }
    cache
  }
})

test_that("direct_effects bootstrap reproduces the point estimate and reports resampling uncertainty", {
  sem <- fix_chain_sem()
  point <- direct_effects(sem, "x", "y", uncertainty = "none")$estimate
  for (args in list(
    list(),
    list(target = "p_gt", functional = "analytic"),
    list(target = "var", functional = "simulate", nsim = 5)
  )) {
    bt <- do.call(
      direct_effects,
      c(list(sem, "x", "y", uncertainty = "bootstrap", B = 3L, seed = 1L), args)
    )
    expect_s3_class(bt, "drm_effect")
    expect_length(attr(bt, "boot_replicates"), 3L)
    expect_lte(attr(bt, "boot_converged"), 3L)
    expect_length(attr(bt, "boot_ci_normal"), 2L)
    expect_true(is.finite(bt$estimate))
    if (length(args) == 0L) {
      expect_equal(bt$estimate, point, tolerance = 1e-8)
    }
  }
  sig <- direct_effects(
    sem, "x", "y", component = "sigma", uncertainty = "bootstrap", B = 2L, seed = 2L
  )
  expect_identical(unique(attr(sig, "coefficients")$component), "sigma")
})

test_that("total_effects bootstrap covers analytic, simulated, and mean functionals", {
  sem <- fix_chain_sem()
  for (args in list(
    list(method = "gcomp"),
    list(method = "gcomp", target = "p_gt", functional = "analytic"),
    list(method = "simulate", target = "quantile", prob = 0.9, nsim = 5)
  )) {
    bt <- do.call(
      total_effects,
      c(list(sem, "x", "y", uncertainty = "bootstrap", B = 3L, seed = 4L), args)
    )
    expect_s3_class(bt, "drm_effect")
    expect_length(attr(bt, "boot_replicates"), 3L)
    expect_true(is.finite(bt$estimate))
  }
})
