#' Symbolize a distributional piecewise SEM
#'
#' Builds a `symbolized_drm_sem` from a fitted [drm_sem()] / [drm_psem()] object
#' by walking the topological-order node list and calling [symbolizer::symbolize()]
#' on each node's underlying `drmTMB` fit. The result is a list of per-node
#' `symbolized_model`s plus the SEM's graph metadata (edges, topological order,
#' modelled distributional components per node), so the rendering generics
#' ([symbolizer::as_latex()], [symbolizer::equations()],
#' [symbolizer::assumption_table()]) can collate the SEM's equations as one
#' document.
#'
#' This is the **model-specification** layer: per-node distributional equations
#' (location, scale, shape, zero-inflation, hurdle, residual correlation),
#' families, links, and assumptions. The **SEM layer** — DAG plotting,
#' d-separation, Fisher's C, the simulation-based effect calculus — stays
#' with the existing `drmSEM` machinery; symbolizer does not attempt to render
#' the (simulation-based) distribution-mediated effect.
#'
#' Requires the [`symbolizer`](https://itchyshin.github.io/symbolizer/) package
#' (a `Suggests`).
#'
#' @param fit A `drm_sem` object.
#' @param symbols,units,context Passed through to each per-node
#'   [symbolizer::symbolize()] call. See `?symbolizer::symbolize` for the
#'   shape (named character vectors keyed by variable name).
#' @param ... Passed through to each per-node [symbolizer::symbolize()] call
#'   (for example, `ci_method = "profile"` for `drmTMB` nodes).
#' @return A `symbolized_drm_sem` object (a list with elements `parts`,
#'   `edges`, `order`, `dpars`, `metadata`).
#' @seealso [symbolizer::symbolize()], [symbolizer::as_latex()],
#'   [symbolizer::equations()], [symbolizer::assumption_table()].
#' @references
#' \insertRef{Shipley2009}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#'
#' \insertRef{Brooks2017}{drmSEM}
#'
#' \insertRef{Rigby2005}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size      = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                        family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat
#' )
#' sym <- symbolizer::symbolize(sem)
#' symbolizer::as_latex(sym)         # publication-ready equations
#' symbolizer::equations(sym)        # raw equation table
#' symbolizer::assumption_table(sym) # families, links, deferred components
#' }
#' @exportS3Method symbolizer::symbolize
symbolize.drm_sem <- function(
  fit,
  symbols = NULL,
  units = NULL,
  context = NULL,
  ...
) {
  drm_require_symbolizer()
  records <- fit$records
  if (is.null(records) || length(records) == 0L) {
    cli::cli_abort("This {.cls drm_sem} has no node records to symbolize.")
  }
  order <- fit$order %||% names(records)
  parts <- stats::setNames(
    lapply(order, function(nm) {
      node_fit <- records[[nm]]$fit
      if (is.null(node_fit)) {
        cli::cli_abort(
          "Node {.val {nm}} has no fitted model; refit the SEM before symbolizing."
        )
      }
      symbolizer::symbolize(
        node_fit,
        symbols = symbols,
        units = units,
        context = context,
        ...
      )
    }),
    order
  )
  out <- list(
    parts = parts,
    edges = fit$edges,
    order = order,
    dpars = fit$dpars,
    metadata = list(
      n_nodes = length(parts),
      n_edges = if (is.null(fit$edges)) 0L else nrow(fit$edges),
      generator = "drmSEM::symbolize.drm_sem"
    )
  )
  class(out) <- c("symbolized_drm_sem", "symbolized_model_set")
  out
}

#' Render the symbolized SEM as LaTeX, equations, or an assumption table
#'
#' These are `drm_sem`-aware methods for `symbolizer`'s
#' [symbolizer::as_latex()], [symbolizer::equations()], and
#' [symbolizer::assumption_table()] generics. Each method walks the per-node
#' `symbolized_model`s in topological order, prefixes each block with a
#' `## Node: <name>` header, and concatenates the result.
#'
#' @param x A `symbolized_drm_sem` from [symbolizer::symbolize()] dispatched on
#'   a `drm_sem`.
#' @param notation,... Passed through to the underlying per-node generic.
#' @return The collated rendering (a character string for
#'   [symbolizer::as_latex()] / [symbolizer::equations()]; a tibble for
#'   [symbolizer::assumption_table()]).
#' @seealso [symbolizer::symbolize()].
#' @name symbolized_drm_sem
NULL

#' @rdname symbolized_drm_sem
#' @exportS3Method symbolizer::as_latex
as_latex.symbolized_drm_sem <- function(
  x,
  notation = c("index", "matrix", "both"),
  ...
) {
  drm_require_symbolizer()
  notation <- match.arg(notation)
  blocks <- vapply(
    names(x$parts),
    function(nm) {
      tex <- symbolizer::as_latex(x$parts[[nm]], notation = notation, ...)
      paste0("%% Node: ", nm, "\n", tex)
    },
    character(1L)
  )
  paste(blocks, collapse = "\n\n")
}

#' @rdname symbolized_drm_sem
#' @exportS3Method symbolizer::equations
equations.symbolized_drm_sem <- function(
  x,
  notation = c("index", "matrix", "both"),
  ...
) {
  drm_require_symbolizer()
  notation <- match.arg(notation)
  rows <- lapply(names(x$parts), function(nm) {
    tab <- symbolizer::equations(x$parts[[nm]], notation = notation, ...)
    if (is.data.frame(tab) && nrow(tab) > 0L) {
      tab[["node"]] <- nm
      ord <- c("node", setdiff(names(tab), "node"))
      tab <- tab[, ord, drop = FALSE]
    }
    tab
  })
  out <- do.call(rbind, rows)
  attr(out, "notation") <- notation
  out
}

#' @rdname symbolized_drm_sem
#' @exportS3Method symbolizer::assumption_table
assumption_table.symbolized_drm_sem <- function(x, ...) {
  drm_require_symbolizer()
  rows <- lapply(names(x$parts), function(nm) {
    tab <- symbolizer::assumption_table(x$parts[[nm]], ...)
    if (is.data.frame(tab) && nrow(tab) > 0L) {
      tab[["node"]] <- nm
      # Move node to the leading column for readability.
      ord <- c("node", setdiff(names(tab), "node"))
      tab <- tab[, ord, drop = FALSE]
    }
    tab
  })
  do.call(rbind, rows)
}

#' @export
print.symbolized_drm_sem <- function(x, ...) {
  cli::cli_text(
    "<symbolized_drm_sem: {x$metadata$n_nodes} node{?s}, {x$metadata$n_edges} edge{?s}>"
  )
  cli::cli_text("Nodes (topological order): {.val {x$order}}")
  cli::cli_text(
    paste(
      "Use {.fn symbolizer::as_latex} / {.fn symbolizer::equations} /",
      "{.fn symbolizer::assumption_table} to render."
    )
  )
  invisible(x)
}

# Internal: a guard so every entry point gives the same actionable message
# when symbolizer is not installed.
drm_require_symbolizer <- function() {
  if (!requireNamespace("symbolizer", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg symbolizer} package is required for {.fn symbolize.drm_sem} and its renderers.",
      "i" = "Install it with {.code remotes::install_github(\"itchyshin/symbolizer\")}."
    ))
  }
  invisible(TRUE)
}
