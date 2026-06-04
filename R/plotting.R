#' @keywords internal
#' @noRd
NULL

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
