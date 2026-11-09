# Regression: natural indirect_effects() bootstrap used a 3-column matrix but
# assigns four statistics (nde, nie, total, mediated_interaction).

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

test_that("natural indirect_effects bootstrap returns four mediated quantities", {
  sem <- fix_chain_sem()
  dat <- sem$data
  s <- stats::sd(dat$x)
  nat <- indirect_effects(
    sem, "x", "y", effect = "natural", uncertainty = "bootstrap", B = 3L, seed = 6L, nsim = 20
  )
  ne <- stats::setNames(nat$estimate, nat$quantity)
  expect_setequal(
    nat$quantity,
    c("total_path", "natural_direct", "natural_indirect", "mediated_interaction")
  )
  expect_equal(
    unname(ne["mediated_interaction"]),
    unname(ne["total_path"] - ne["natural_direct"] - ne["natural_indirect"]),
    tolerance = 1e-8
  )
  expect_lt(abs(ne[["natural_direct"]] - 0.3 * s), 0.15)
  expect_lt(abs(ne[["natural_indirect"]] - 0.4 * s), 0.15)
})
