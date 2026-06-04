#' @keywords internal
#' @noRd
NULL

# Bare column names used inside ggplot2::aes() in plot.drm_effect(); declared so
# R CMD check does not flag them as undefined globals.
utils::globalVariables(c("estimate", "quantity", "conf.low", "conf.high", ".channel"))

# Colour and line style per distributional component, so the plot reads as a
# distributional SEM rather than a plain DAG.
drm_component_style <- function(component) {
  if (startsWith(component, "sd")) return(list(col = "grey50", lty = 3))
  switch(
    component,
    mu = list(col = "black", lty = 1),
    sigma = list(col = "#1b9e77", lty = 2),
    nu = list(col = "#7570b3", lty = 4),
    zi = list(col = "#d95f02", lty = 3),
    hu = list(col = "#e7298a", lty = 3),
    rho12 = list(col = "#666666", lty = 5),
    list(col = "black", lty = 1)
  )
}

#' Plot the distributional SEM as a component-labelled DAG
#'
#' Nodes are variables; arrows are coloured and styled by the distributional
#' component they target (mu solid black, sigma dashed green, zi dotted orange,
#' random-effect scale grey dotted, rho12 long-dash). Uses `igraph` for layout.
#'
#' @param x A `drm_sem` object.
#' @param ... Passed to the underlying plot.
#' @return `x`, invisibly.
#' @export
plot.drm_sem <- function(x, ...) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    cli::cli_abort("Plotting requires the {.pkg igraph} package.")
  }
  edges <- x$edges
  verts <- unique(c(x$endogenous, x$exogenous, edges$from, edges$to))
  g <- igraph::graph_from_data_frame(
    d = edges[, c("from", "to")], vertices = data.frame(name = verts),
    directed = TRUE
  )
  styles <- lapply(edges$component, drm_component_style)
  igraph::E(g)$color <- vapply(styles, function(s) s$col, character(1))
  igraph::E(g)$lty <- vapply(styles, function(s) s$lty, numeric(1))
  vcol <- ifelse(verts %in% x$endogenous, "#cde", "#eee")
  lay <- igraph::layout_with_sugiyama(g)$layout
  graphics::plot(
    g, layout = lay,
    vertex.color = vcol, vertex.frame.color = "grey40",
    vertex.label.color = "black", vertex.size = 34,
    edge.arrow.size = 0.5, edge.curved = 0.12, ...
  )
  graphics::legend(
    "bottomleft", bty = "n", cex = 0.8,
    legend = c("mu", "sigma", "nu", "zi", "hu", "sd(.)", "rho12"),
    col = c("black", "#1b9e77", "#7570b3", "#d95f02", "#e7298a", "grey50", "#666666"),
    lty = c(1, 2, 4, 3, 3, 3, 5)
  )
  invisible(x)
}

#' Plot an effect decomposition as a forest plot
#'
#' Visualizes the output of [indirect_effects()] (or [direct_effects()] /
#' [total_effects()]) as a horizontal point-and-interval (forest) plot, with a
#' reference line at zero. This is the picture the rest of the SEM ecosystem does
#' not draw: `piecewiseSEM`, `dsem`, and `lavaan` plot the path diagram but leave
#' the direct / indirect / total *decomposition* as a table. drmSEM separates the
#' **distribution-mediated** contribution (the effect flowing through a mediator's
#' scale, zero-inflation, or shape) from the **mean-mediated** part, so a path that
#' acts on dispersion rather than the mean is visible.
#'
#' Requires `ggplot2` (Suggests); returns a `ggplot` object you can restyle.
#'
#' @param x A `drm_effect` data frame from [indirect_effects()],
#'   [direct_effects()], or [total_effects()].
#' @param ... Unused.
#' @return A `ggplot` object (invisibly printed by default).
#' @export
plot.drm_effect <- function(x, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Plotting an effect decomposition requires the {.pkg ggplot2} package.")
  }
  df <- as.data.frame(x)
  if (!"quantity" %in% names(df)) {
    df$quantity <- "effect"
  }
  if (!all(c("conf.low", "conf.high") %in% names(df))) {
    df$conf.low <- NA_real_
    df$conf.high <- NA_real_
  }
  # canonical top-to-bottom order; map each row to a decomposition class
  ord <- c("total_path", "total", "direct", "indirect",
           "mean_mediated", "distribution_mediated", "effect")
  present <- intersect(ord, unique(df$quantity))
  present <- c(present, setdiff(unique(df$quantity), present))
  df$quantity <- factor(df$quantity, levels = rev(present))
  df$.channel <- ifelse(
    df$quantity == "distribution_mediated", "distribution-mediated",
    ifelse(df$quantity %in% c("indirect", "mean_mediated"), "mean-mediated",
           "direct / total")
  )
  from <- if ("from" %in% names(df)) df$from[[1L]] else "x"
  to <- if ("to" %in% names(df)) df$to[[1L]] else "y"
  ggplot2::ggplot(df, ggplot2::aes(x = estimate, y = quantity)) +
    ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = "grey55") +
    ggplot2::geom_pointrange(
      ggplot2::aes(xmin = conf.low, xmax = conf.high, colour = .channel),
      na.rm = TRUE
    ) +
    ggplot2::scale_colour_manual(
      values = c("direct / total" = "black", "mean-mediated" = "#1f78b4",
                 "distribution-mediated" = "#d95f02"),
      name = NULL
    ) +
    ggplot2::labs(
      x = sprintf("Effect of %s on %s (response scale)", from, to),
      y = NULL
    ) +
    ggplot2::theme_minimal()
}
