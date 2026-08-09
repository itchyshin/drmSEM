# plot.drm_effect: the effect-decomposition forest plot. Pure ggplot2 (no engine
# required); we build a drm_effect object directly and check a ggplot is returned
# with the expected rows.

test_that("plot.drm_effect returns a ggplot of the decomposition", {
  skip_if_not_installed("ggplot2")

  eff <- data.frame(
    from = "temp",
    to = "fitness",
    quantity = c(
      "total_path",
      "direct",
      "indirect",
      "mean_mediated",
      "distribution_mediated"
    ),
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
  de <- data.frame(
    from = "temp",
    to = "fitness",
    scale = "response",
    estimate = 0.2,
    conf.low = 0.05,
    conf.high = 0.35
  )
  class(de) <- c("drm_effect", "data.frame")
  p <- plot(de)
  expect_s3_class(p, "ggplot")
})

test_that("plot.drm_effect stacked style returns a ggplot of the additive parts", {
  skip_if_not_installed("ggplot2")
  eff <- data.frame(
    from = "temp",
    to = "fitness",
    quantity = c(
      "total_path",
      "direct",
      "indirect",
      "mean_mediated",
      "distribution_mediated"
    ),
    estimate = c(0.40, 0.10, 0.30, 0.18, 0.12),
    conf.low = c(0.20, -0.02, 0.12, 0.05, 0.01),
    conf.high = c(0.60, 0.22, 0.48, 0.31, 0.23),
    stringsAsFactors = FALSE
  )
  class(eff) <- c("drm_effect", "data.frame")
  p <- plot(eff, style = "stacked")
  expect_s3_class(p, "ggplot")
  # only the three additive components are bars
  expect_setequal(
    as.character(p$data$quantity),
    c("direct", "mean_mediated", "distribution_mediated")
  )
})

test_that("plot.drm_effect stacked falls back to forest when no decomposition", {
  skip_if_not_installed("ggplot2")
  de <- data.frame(
    from = "temp",
    to = "fitness",
    scale = "response",
    estimate = 0.2,
    conf.low = NA_real_,
    conf.high = NA_real_
  )
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
  structure(
    list(
      endogenous = c("y1", "y2"),
      exogenous = "x",
      edges = data.frame(
        from = c("x", "x"),
        to = c("y1", "y2"),
        component = c("mu", "mu"),
        link = c("identity", "identity"),
        term = c("x", "x"),
        endogenous = c(FALSE, FALSE),
        stringsAsFactors = FALSE
      ),
      covariances = cov_df
    ),
    class = "drm_sem"
  )
}

cov_both <- rbind(
  data.frame(
    y1 = "y1",
    y2 = "y2",
    class = "residual",
    level = NA_character_,
    structure = "unstructured",
    label = "rho12(y1, y2)",
    stringsAsFactors = FALSE
  ),
  data.frame(
    y1 = "y1",
    y2 = "y2",
    class = "higher_level",
    level = "id",
    structure = "unstructured",
    label = "corpair(id: y1, y2)",
    stringsAsFactors = FALSE
  )
)

test_that("plot.drm_sem renders directed paths and covariance arcs", {
  skip_if_not_installed("igraph")
  sem <- make_plot_sem(cov_both)
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_invisible_sem <- plot(sem) # show = "all" by default
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

# The legend must list ONLY the components actually drawn (regression guard for
# the hero-DAG bug where it hardcoded all seven). Tested on the pure helper so it
# needs no rendering device.
test_that("drm_path_legend lists only the components present in the edges", {
  edges <- data.frame(
    from = c("temp", "temp", "habitat"),
    to = c("size", "size", "abundance"),
    component = c("mu", "sigma", "zi"),
    stringsAsFactors = FALSE
  )
  lg <- drmSEM:::drm_path_legend(edges, cov = NULL, draw_cov = FALSE)
  expect_equal(lg$lab, c("mu", "sigma", "zi")) # in fixed order
  expect_false(any(c("nu", "hu", "sd(.)", "rho12 (path)") %in% lg$lab))
  # swatches come from the style function (no drift)
  expect_equal(lg$col, c("black", "#1b9e77", "#d95f02"))
  expect_equal(lg$lty, c(1, 2, 3))
})

test_that("drm_path_legend normalises sd(group) components and a directed rho12", {
  edges <- data.frame(
    from = c("x", "g", "x"),
    to = c("y", "y", "y"),
    component = c("mu", "sd(group)", "rho12"),
    stringsAsFactors = FALSE
  )
  lg <- drmSEM:::drm_path_legend(edges, cov = NULL, draw_cov = FALSE)
  expect_equal(lg$lab, c("mu", "sd(.)", "rho12 (path)"))
})

test_that("drm_path_legend adds only the covariance classes actually present", {
  edges <- data.frame(
    from = "x",
    to = "y1",
    component = "mu",
    stringsAsFactors = FALSE
  )
  res_only <- data.frame(
    y1 = "y1",
    y2 = "y2",
    class = "residual",
    stringsAsFactors = FALSE
  )
  lg <- drmSEM:::drm_path_legend(edges, cov = res_only, draw_cov = TRUE)
  expect_true("rho12 (covary)" %in% lg$lab)
  expect_false("corpair (covary)" %in% lg$lab) # no higher-level row present
})

test_that("drm_path_legend adds a measurement row only when requested", {
  edges <- data.frame(
    from = "body",
    to = "y",
    component = "mu",
    stringsAsFactors = FALSE
  )
  expect_false(
    "loading (indicator)" %in%
      drmSEM:::drm_path_legend(edges, draw_meas = FALSE)$lab
  )
  expect_true(
    "loading (indicator)" %in%
      drmSEM:::drm_path_legend(edges, draw_meas = TRUE)$lab
  )
})

# Composite measurement edges (OQ-15): a construct's indicators point into the
# construct, drawn only under show = "all".
test_that("plot.drm_sem draws composite measurement edges", {
  skip_if_not_installed("igraph")
  sem <- structure(
    list(
      endogenous = "y",
      exogenous = "body",
      edges = data.frame(
        from = "body",
        to = "y",
        component = "mu",
        link = "identity",
        term = "body",
        endogenous = FALSE,
        stringsAsFactors = FALSE
      ),
      covariances = drmSEM:::drm_empty_covariances(),
      composites = list(list(name = "body", indicators = c("len", "mass")))
    ),
    class = "drm_sem"
  )
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_s3_class(plot(sem), "drm_sem") # draws measurement arcs
  expect_s3_class(plot(sem, show = "paths"), "drm_sem") # omits them, no error
})

# Confidence Eye contract for the forest style. The contract requires a pale
# tapered compatibility region with a darker outline and a HOLLOW estimate
# marker, and prohibits filled points and horizontal interval bars. This branch
# shipped with geom_point() + geom_pointrange() (both prohibited) until
# 2026-08-09, so these are regression guards, not decoration.

test_that("plot.drm_effect forest style meets the Confidence Eye contract", {
  skip_if_not_installed("ggplot2")

  eff <- data.frame(
    from = "temp",
    to = "fitness",
    quantity = c("total_path", "mean_mediated", "distribution_mediated"),
    estimate = c(0.40, 0.18, 0.12),
    conf.low = c(0.20, 0.05, 0.01),
    conf.high = c(0.60, 0.31, 0.23),
    stringsAsFactors = FALSE
  )
  class(eff) <- c("drm_effect", "data.frame")

  p <- plot(eff)
  geoms <- vapply(p$layers, function(l) class(l$geom)[[1L]], character(1))

  # Prohibited: a horizontal interval bar through the estimate.
  expect_false("GeomPointrange" %in% geoms)
  expect_false("GeomErrorbarh" %in% geoms)
  # Required: the tapered compatibility region.
  expect_true("GeomPolygon" %in% geoms)

  # Required: a hollow estimate marker (shape 21 is the open circle whose fill
  # is set separately; a filled point is prohibited).
  pt <- p$layers[[which(geoms == "GeomPoint")[[1L]]]]
  expect_equal(pt$aes_params$shape, 21)
  expect_equal(pt$aes_params$fill, "white")
})

test_that("drm_confidence_eyes puts the widest point on the estimate", {
  # An asymmetric interval must keep its waist on the estimate, not drift to the
  # interval's midpoint -- otherwise the lens silently misreports the estimate.
  df <- data.frame(
    estimate = 0.05,
    conf.low = 0,
    conf.high = 0.80,
    quantity = "skewed",
    .channel = "direct / total",
    .y = 1,
    stringsAsFactors = FALSE
  )
  eye <- drmSEM:::drm_confidence_eyes(df)
  widest <- eye$x[which.max(eye$y)]
  expect_equal(widest, 0.05, tolerance = 1e-6)
  # and it closes to a point at both endpoints
  expect_equal(range(eye$x), c(0, 0.80), tolerance = 1e-6)
})

test_that("drm_confidence_eyes drops rows with no usable interval", {
  df <- data.frame(
    estimate = c(0.2, 0.0, 0.3),
    conf.low = c(NA_real_, 0.0, 0.1),
    conf.high = c(NA_real_, 0.0, 0.5),
    quantity = c("missing", "degenerate", "fine"),
    .channel = "direct / total",
    .y = 1:3,
    stringsAsFactors = FALSE
  )
  eye <- drmSEM:::drm_confidence_eyes(df)
  # only the third row yields a polygon; the other two still get their marker
  # from the unconditional geom_point layer.
  expect_equal(unique(eye$.group), "fine")
})

test_that("forest eye fills stay matched to their channel outlines", {
  skip_if_not_installed("ggplot2")
  # Regression: the pale fills are derived from the outline colours with
  # paste0(), which DROPS names. An unnamed vector makes scale_fill_manual()
  # assign colours positionally in alphabetical level order, pairing the
  # mean-mediated outline with the distribution-mediated fill. The plot still
  # builds and every other assertion still passes -- only the render shows it.
  eff <- data.frame(
    from = "temp",
    to = "fitness",
    quantity = c("total_path", "mean_mediated", "distribution_mediated"),
    estimate = c(0.40, 0.18, 0.12),
    conf.low = c(0.20, 0.05, 0.01),
    conf.high = c(0.60, 0.31, 0.23),
    stringsAsFactors = FALSE
  )
  class(eff) <- c("drm_effect", "data.frame")

  p <- plot(eff)
  built <- ggplot2::ggplot_build(p)
  geoms <- vapply(p$layers, function(l) class(l$geom)[[1L]], character(1))
  poly <- built$data[[which(geoms == "GeomPolygon")[[1L]]]]
  # every polygon's fill is its own outline colour plus an alpha suffix
  expect_equal(toupper(substr(poly$fill, 1L, 7L)), toupper(poly$colour))
})
