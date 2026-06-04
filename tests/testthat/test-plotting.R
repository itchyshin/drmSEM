# plot.drm_effect: the effect-decomposition forest plot. Pure ggplot2 (no engine
# required); we build a drm_effect object directly and check a ggplot is returned
# with the expected rows.

test_that("plot.drm_effect returns a ggplot of the decomposition", {
  skip_if_not_installed("ggplot2")

  eff <- data.frame(
    from = "temp", to = "fitness",
    quantity = c("total_path", "direct", "indirect",
                 "mean_mediated", "distribution_mediated"),
    estimate = c(0.40, 0.10, 0.30, 0.18, 0.12),
    conf.low = c(0.20, -0.02, 0.12, 0.05, 0.01),
    conf.high = c(0.60, 0.22, 0.48, 0.31, 0.23),
    stringsAsFactors = FALSE
  )
  class(eff) <- c("drm_effect", "data.frame")

  p <- plot(eff)
  expect_s3_class(p, "ggplot")
  # the distribution-mediated channel is one of the colour groups
  expect_true("distribution-mediated" %in% p$data$.channel)
  # one row per decomposition quantity
  expect_equal(nrow(p$data), 5L)
})

test_that("plot.drm_effect handles a single-row effect (no quantity column)", {
  skip_if_not_installed("ggplot2")
  de <- data.frame(from = "temp", to = "fitness", scale = "response",
                   estimate = 0.2, conf.low = 0.05, conf.high = 0.35)
  class(de) <- c("drm_effect", "data.frame")
  p <- plot(de)
  expect_s3_class(p, "ggplot")
})
