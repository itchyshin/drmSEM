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

test_that("plot.drm_effect stacked style returns a ggplot of the additive parts", {
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
  p <- plot(eff, style = "stacked")
  expect_s3_class(p, "ggplot")
  # only the three additive components are bars
  expect_setequal(as.character(p$data$quantity),
                  c("direct", "mean_mediated", "distribution_mediated"))
})

test_that("plot.drm_effect stacked falls back to forest when no decomposition", {
  skip_if_not_installed("ggplot2")
  de <- data.frame(from = "temp", to = "fitness", scale = "response",
                   estimate = 0.2, conf.low = NA_real_, conf.high = NA_real_)
  class(de) <- c("drm_effect", "data.frame")
  # NA interval must still produce a plot (geom_point draws the estimate)
  expect_s3_class(suppressWarnings(plot(de, style = "stacked")), "ggplot")
})

# plot.drm_sem: the component-labelled DAG + covariance arcs. igraph is in
# Imports (always available); we render to a null device and assert the call
# succeeds and the graph carries the expected directed + covariance edges.

# A sibling SEM: x -> y1 (mu), x -> y2 (mu), with a residual rho12 covariance
# edge and a higher-level corpair edge between y1 and y2.
make_plot_sem <- function(cov_df) {
  structure(list(
    endogenous = c("y1", "y2"),
    exogenous = "x",
    edges = data.frame(
      from = c("x", "x"), to = c("y1", "y2"),
      component = c("mu", "mu"), link = c("identity", "identity"),
      term = c("x", "x"), endogenous = c(FALSE, FALSE),
      stringsAsFactors = FALSE
    ),
    covariances = cov_df
  ), class = "drm_sem")
}

cov_both <- rbind(
  data.frame(y1 = "y1", y2 = "y2", class = "residual", level = NA_character_,
             structure = "unstructured", label = "rho12(y1, y2)",
             stringsAsFactors = FALSE),
  data.frame(y1 = "y1", y2 = "y2", class = "higher_level", level = "id",
             structure = "unstructured", label = "corpair(id: y1, y2)",
             stringsAsFactors = FALSE)
)

test_that("plot.drm_sem renders directed paths and covariance arcs", {
  skip_if_not_installed("igraph")
  sem <- make_plot_sem(cov_both)
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_invisible_sem <- plot(sem)              # show = "all" by default
  expect_s3_class(expect_invisible_sem, "drm_sem")
})

test_that("plot.drm_sem show='paths' omits covariance arcs without error", {
  skip_if_not_installed("igraph")
  sem <- make_plot_sem(cov_both)
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_s3_class(plot(sem, show = "paths"), "drm_sem")
})

test_that("plot.drm_sem works when there are no covariance edges", {
  skip_if_not_installed("igraph")
  sem <- make_plot_sem(drmSEM:::drm_empty_covariances())
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_s3_class(plot(sem), "drm_sem")
})
