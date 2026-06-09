#' @keywords internal
#' @noRd
NULL

# Bare column names used inside ggplot2::aes() in plot.drm_effect(); declared so
# R CMD check does not flag them as undefined globals.
utils::globalVariables(c(
  "estimate",
  "quantity",
  "conf.low",
  "conf.high",
  ".channel"
))

# Colour and line style per distributional component, so the plot reads as a
# distributional SEM rather than a plain DAG.
drm_component_style <- function(component) {
  if (startsWith(component, "sd")) {
    return(list(col = "grey50", lty = 3))
  }
  switch(
    component,
    mu = list(col = "black", lty = 1),
    sigma = list(col = "#1b9e77", lty = 2),
    nu = list(col = "#7570b3", lty = 4),
    zi = list(col = "#d95f02", lty = 3),
    hu = list(col = "#e7298a", lty = 6),
    rho12 = list(col = "#666666", lty = 5),
    list(col = "black", lty = 1)
  )
}

# Build the legend from the components ACTUALLY drawn (and the covariance classes
# actually present), sourcing swatches from drm_component_style() so the legend
# can never drift from the edges. Returns parallel lab/col/lty vectors: the
# path-target rows first (in a fixed component order), then any covariance rows.
drm_path_legend <- function(
  edges,
  cov = NULL,
  draw_cov = FALSE,
  draw_meas = FALSE
) {
  comp_lab <- c(
    mu = "mu",
    sigma = "sigma",
    nu = "nu",
    zi = "zi",
    hu = "hu",
    rho12 = "rho12 (path)"
  )
  drawn <- ifelse(startsWith(edges$component, "sd"), "sd", edges$component)
  present <- intersect(
    c("mu", "sigma", "nu", "zi", "hu", "sd", "rho12"),
    unique(drawn)
  )
  lab <- vapply(
    present,
    function(k) {
      if (identical(k, "sd")) "sd(.)" else unname(comp_lab[[k]])
    },
    character(1)
  )
  stys <- lapply(present, function(k) {
    drm_component_style(if (identical(k, "sd")) "sd(.)" else k)
  })
  col <- vapply(stys, `[[`, character(1), "col")
  lty <- vapply(stys, `[[`, numeric(1), "lty")
  if (isTRUE(draw_cov) && !is.null(cov) && nrow(cov) > 0L) {
    if (any(cov$class == "residual")) {
      lab <- c(lab, "rho12 (covary)")
      col <- c(col, "#666666")
      lty <- c(lty, 1)
    }
    if (any(cov$class != "residual")) {
      lab <- c(lab, "corpair (covary)")
      col <- c(col, "#666666")
      lty <- c(lty, 2)
    }
  }
  if (isTRUE(draw_meas)) {
    lab <- c(lab, "loading (indicator)")
    col <- c(col, "#3182bd")
    lty <- c(lty, 1)
  }
  list(lab = unname(lab), col = unname(col), lty = unname(lty))
}

#' Plot the distributional SEM as a component-labelled DAG
#'
#' Nodes are variables; **directed** arrows are coloured and styled by the
#' distributional component they target (mu solid black, sigma dashed green, zi
#' dotted orange, random-effect scale grey dotted, a directed `x -> rho12` path
#' long-dash). **Covariance edges** declared with [covary()] / [drm_pair()] are
#' drawn as **double-headed arcs** — solid grey for a residual correlation
#' (`rho12`), dashed grey for a higher-level random-effect correlation
#' (`corpair`) — so the three edge classes (directed path, residual covariance,
#' higher-level covariance) are visually distinct
#' (`docs/design/07-bivariate-covariance-edges.md`). **Composite measurement
#' edges** — each [drm_composite()] construct's indicators pointing into the
#' construct — are drawn as steel-blue arrows, with the indicators shown as
#' distinctly-filled nodes, so a formative measurement model reads apart from the
#' structural paths. Uses `igraph` for layout.
#'
#' The legend lists **only the components, covariance classes, and measurement
#' edges actually present in the plotted graph** (its swatches come from the same
#' style function as the edges, so they cannot drift from what is drawn). Node
#' fills distinguish endogenous responses, exogenous predictors, and composite
#' indicators. Parallel paths between one pair (for example a `mu` and a `sigma`
#' arrow) are fanned onto separate arcs.
#'
#' @param x A `drm_sem` object.
#' @param show `"all"` (default) draws directed paths **and** covariance arcs
#'   **and** composite measurement edges; `"paths"` draws the directed structural
#'   edges only.
#' @param ... Passed to the underlying `igraph` plot. A `layout =` matrix is
#'   honoured (if it carries rownames it is reordered to the internal vertex
#'   order), so a fixed, crossing-free layout can be supplied.
#' @return `x`, invisibly.
#' @references
#' \insertRef{Wright1934}{drmSEM}
#'
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' plot(sem)              # directed paths + any covariance arcs
#' plot(sem, show = "paths")
#' }
#' @export
plot.drm_sem <- function(x, show = c("all", "paths"), ...) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    cli::cli_abort("Plotting requires the {.pkg igraph} package.")
  }
  show <- match.arg(show)
  edges <- x$edges
  cov <- x$covariances
  comps <- x$composites
  draw_cov <- identical(show, "all") && !is.null(cov) && nrow(cov) > 0L
  draw_meas <- identical(show, "all") && length(comps) > 0L

  # Directed structural edges, styled by the component they target.
  styles <- lapply(edges$component, drm_component_style)
  e_df <- edges[, c("from", "to"), drop = FALSE]
  ecol <- vapply(styles, function(s) s$col, character(1))
  elty <- vapply(styles, function(s) s$lty, numeric(1))
  earrow <- rep(2, nrow(e_df)) # forward arrowhead (directed path)
  ecurv <- rep(0.12, nrow(e_df))

  # Covariance edges: double-headed arcs, NOT directed paths. Residual (rho12)
  # solid grey; higher-level (corpair) dashed grey. arrow.mode = 3 = both ends.
  if (draw_cov) {
    e_df <- rbind(
      e_df,
      data.frame(from = cov$y1, to = cov$y2, stringsAsFactors = FALSE)
    )
    is_res <- cov$class == "residual"
    ecol <- c(ecol, rep("#666666", nrow(cov)))
    elty <- c(elty, ifelse(is_res, 1, 2))
    earrow <- c(earrow, rep(3, nrow(cov)))
    ecurv <- c(ecurv, ifelse(is_res, 0.35, 0.45))
  }

  # Measurement edges: each composite construct's indicators point INTO the
  # construct (formative loadings), drawn as steel-blue arrows so they read as a
  # measurement model, distinct from structural paths and covariance arcs.
  ind_names <- character(0)
  if (draw_meas) {
    meas <- do.call(
      rbind,
      lapply(comps, function(cp) {
        data.frame(from = cp$indicators, to = cp$name, stringsAsFactors = FALSE)
      })
    )
    ind_names <- unique(meas$from)
    e_df <- rbind(e_df, meas)
    ecol <- c(ecol, rep("#3182bd", nrow(meas)))
    elty <- c(elty, rep(1, nrow(meas)))
    earrow <- c(earrow, rep(2, nrow(meas))) # indicator -> construct
    ecurv <- c(ecurv, rep(0, nrow(meas)))
  }

  verts <- unique(c(x$endogenous, x$exogenous, e_df$from, e_df$to))
  g <- igraph::graph_from_data_frame(
    d = e_df,
    vertices = data.frame(name = verts),
    directed = TRUE
  )
  igraph::E(g)$color <- ecol
  igraph::E(g)$lty <- elty
  igraph::E(g)$arrow.mode <- earrow
  vcol <- ifelse(
    verts %in% x$endogenous,
    "#cde",
    ifelse(verts %in% ind_names, "#fff7bc", "#eee")
  )

  # Layout: honour a caller-supplied `layout=` (a matrix; if it carries rownames
  # it is reordered to the internal vertex order, so the caller need not know it),
  # else fall back to Sugiyama.
  dots <- list(...)
  lay <- if (!is.null(dots$layout)) {
    L <- as.matrix(dots$layout)
    if (!is.null(rownames(L))) {
      L <- L[verts, , drop = FALSE]
    }
    L
  } else {
    igraph::layout_with_sugiyama(g)$layout
  }
  dots$layout <- NULL

  # Curvature: fan parallel directed edges (same from->to but a different target
  # component -- e.g. a mu and a sigma path between one pair) onto opposite arcs so
  # they never collapse into one line, and give a lone edge a direction-signed bow
  # so long diagonals separate. Covariance arcs keep their wider preset curvature.
  n_dir <- nrow(edges)
  if (n_dir > 0L) {
    fx <- lay[match(e_df$from[seq_len(n_dir)], verts), 1L]
    tx <- lay[match(e_df$to[seq_len(n_dir)], verts), 1L]
    key <- paste(e_df$from[seq_len(n_dir)], e_df$to[seq_len(n_dir)], sep = "\r")
    for (k in unique(key)) {
      idx <- which(key == k)
      ecurv[idx] <- if (length(idx) == 1L) {
        if (isTRUE(tx[idx] >= fx[idx])) 0.15 else -0.15
      } else {
        0.3 * seq(-1, 1, length.out = length(idx))
      }
    }
  }

  base <- list(
    g,
    layout = lay,
    vertex.color = vcol,
    vertex.frame.color = "grey40",
    vertex.label.color = "black",
    vertex.size = 34,
    edge.arrow.mode = earrow,
    edge.curved = ecurv
  )
  if (is.null(dots$edge.arrow.size)) {
    base$edge.arrow.size <- 0.5
  }
  do.call(graphics::plot, c(base, dots))

  # Edge legend: lists ONLY the components/covariance classes/measurement edges
  # actually drawn (previously hardcoded all seven components).
  lg <- drm_path_legend(edges, cov, draw_cov, draw_meas)
  if (length(lg$lab) > 0L) {
    graphics::legend(
      "bottomleft",
      bty = "n",
      cex = 0.8,
      title = "path target",
      legend = lg$lab,
      col = lg$col,
      lty = lg$lty
    )
  }
  # Node legend: modelled response vs exogenous predictor vs (if drawn) composite
  # indicator -- the node fill colours, previously unexplained on the figure.
  node_lab <- c("endogenous (response)", "exogenous (predictor)")
  node_bg <- c("#cde", "#eee")
  if (draw_meas) {
    node_lab <- c(node_lab, "indicator")
    node_bg <- c(node_bg, "#fff7bc")
  }
  graphics::legend(
    "topleft",
    bty = "n",
    cex = 0.8,
    legend = node_lab,
    pt.bg = node_bg,
    pch = 21,
    col = "grey40"
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
#' @param style `"forest"` (default; one point-and-interval row per quantity) or
#'   `"stacked"` (a single bar stacking `direct` + `mean_mediated` +
#'   `distribution_mediated`, which sum to the total effect). `"stacked"` needs
#'   the decomposition rows from [indirect_effects()] and falls back to
#'   `"forest"` if they are absent.
#' @param ... Unused.
#' @return A `ggplot` object (invisibly printed by default).
#' @references
#' \insertRef{Pearl2001}{drmSEM}
#'
#' \insertRef{Imai2010}{drmSEM}
#'
#' \insertRef{VanderWeele2015}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' eff <- indirect_effects(sem, from = "temp", to = "abundance", through = "size")
#' plot(eff, style = "forest")
#' }
#' @export
plot.drm_effect <- function(x, style = c("forest", "stacked"), ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort(
      "Plotting an effect decomposition requires the {.pkg ggplot2} package."
    )
  }
  style <- match.arg(style)
  df <- as.data.frame(x)
  if (!"quantity" %in% names(df)) {
    df$quantity <- "effect"
  }
  if (!all(c("conf.low", "conf.high") %in% names(df))) {
    df$conf.low <- NA_real_
    df$conf.high <- NA_real_
  }
  from <- if ("from" %in% names(df)) df$from[[1L]] else "x"
  to <- if ("to" %in% names(df)) df$to[[1L]] else "y"
  xlab <- sprintf("Effect of %s on %s (response scale)", from, to)
  part_cols <- c("direct", "mean_mediated", "distribution_mediated")
  fills <- c(
    direct = "black",
    mean_mediated = "#1f78b4",
    distribution_mediated = "#d95f02"
  )

  if (identical(style, "stacked")) {
    parts <- df[df$quantity %in% part_cols, , drop = FALSE]
    if (nrow(parts) == 0L) {
      cli::cli_warn(
        "No decomposition components present; using {.val forest} style."
      )
    } else {
      parts$quantity <- factor(as.character(parts$quantity), levels = part_cols)
      return(
        ggplot2::ggplot(
          parts,
          ggplot2::aes(x = estimate, y = "effect", fill = quantity)
        ) +
          ggplot2::geom_col(width = 0.6) +
          ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = "grey55") +
          ggplot2::scale_fill_manual(values = fills, name = NULL) +
          ggplot2::labs(x = xlab, y = NULL) +
          ggplot2::theme_minimal()
      )
    }
  }

  # forest (default): one point-and-interval row per quantity
  ord <- c(
    "total_path",
    "total",
    "direct",
    "indirect",
    "mean_mediated",
    "distribution_mediated",
    "effect"
  )
  present <- intersect(ord, unique(df$quantity))
  present <- c(present, setdiff(unique(df$quantity), present))
  df$quantity <- factor(df$quantity, levels = rev(present))
  df$.channel <- ifelse(
    df$quantity == "distribution_mediated",
    "distribution-mediated",
    ifelse(
      df$quantity %in% c("indirect", "mean_mediated"),
      "mean-mediated",
      "direct / total"
    )
  )
  ggplot2::ggplot(df, ggplot2::aes(x = estimate, y = quantity)) +
    ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = "grey55") +
    # geom_point always draws the estimate, so a row with no MC interval
    # (e.g. a draw = FALSE direct effect) still shows.
    ggplot2::geom_point(ggplot2::aes(colour = .channel)) +
    ggplot2::geom_pointrange(
      ggplot2::aes(xmin = conf.low, xmax = conf.high, colour = .channel),
      na.rm = TRUE
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "direct / total" = "black",
        "mean-mediated" = "#1f78b4",
        "distribution-mediated" = "#d95f02"
      ),
      name = NULL
    ) +
    ggplot2::labs(x = xlab, y = NULL) +
    ggplot2::theme_minimal()
}
