# Regression: drm_analytic_functional() p_gt support-limit branches used a scalar
# ifelse() on the threshold, which collapsed row-wise probabilities to one value.

test_that("p_gt returns one probability per row for every closed-form family", {
  mu <- c(0.1, 2, 6)
  sg <- c(0.4, 0.5, 0.6)
  zi <- c(0, 0.2, 0.4)
  cases <- list(
    poisson = list(list(mu = mu, zi = zi), 2),
    nbinom2 = list(list(mu = mu, sigma = sg, zi = zi), 2),
    lognormal = list(list(mu = log(mu), sigma = sg, zi = zi), 1.5),
    Gamma = list(list(mu = mu, sigma = sg, zi = zi), 1.5),
    beta = list(list(mu = c(0.2, 0.5, 0.8), sigma = sg), 0.5)
  )
  for (fam in names(cases)) {
    params <- cases[[fam]][[1]]
    thr <- cases[[fam]][[2]]
    out <- drmSEM:::drm_analytic_functional(fam, params, "p_gt", threshold = thr)
    expect_length(out, 3L)
    expect_true(all(diff(out) != 0), info = fam)
    for (i in 1:3) {
      row_i <- lapply(params, function(p) p[[i]])
      expect_equal(
        out[[i]],
        drmSEM:::drm_analytic_functional(fam, row_i, "p_gt", threshold = thr),
        info = paste(fam, i)
      )
    }
  }
})
