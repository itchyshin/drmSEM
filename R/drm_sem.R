#' @keywords internal
#' @noRd
NULL

# Internal constructor shared by drm_sem() and drm_psem(). `fit_env` is the
# environment where the SEM was specified; d-separation refits are evaluated
# there so structured-effect objects (e.g. a phylo `tree`) resolve (OQ-13).
# `covariances` holds covary() declarations (residual rho12 / higher-level
# corpair edges), stored separately from the directed `$edges` (OQ-14).
new_drm_sem <- function(fits, data, call, fit_env = parent.frame(),
                        covariances = NULL, composites = NULL) {
  if (length(fits) == 0L) {
    cli::cli_abort("A drmSEM model needs at least one endogenous node.")
  }
  if (is.null(names(fits)) || any(!nzchar(names(fits)))) {
    cli::cli_abort("All nodes must be named.")
  }
  if (anyDuplicated(names(fits))) {
    cli::cli_abort("Node names must be unique.")
  }

  records <- drm_build_node_records(fits)
  edges <- drm_build_edges(records)
  vedges <- drm_collapse_edges(edges)
  covs <- drm_build_covariances(covariances, records)
  comps <- drm_build_composites(composites)
  clash <- intersect(vapply(comps, function(c) c$name, character(1)), names(fits))
  if (length(clash)) {
    cli::cli_abort("Composite name{?s} {.val {clash}} collide{?s/} with a node name.")
  }

  node_names <- names(fits)
  exo <- setdiff(unique(edges$from[!edges$endogenous]), node_names)

  topo <- drm_toposort(node_names, vedges)
  if (!topo$acyclic) {
    cyc <- setdiff(node_names, topo$order)
    cli::cli_abort(c(
      "The structural graph contains a cycle; drmSEM requires a DAG.",
      "x" = "Nodes involved in or downstream of the cycle: {.val {cyc}}.",
      "i" = "Remove feedback arrows or split the offending node."
    ))
  }

  structure(
    list(
      nodes = fits,
      records = records,
      data = data,
      edges = edges,
      var_edges = vedges,
      covariances = covs,
      composites = comps,
      endogenous = node_names,
      exogenous = exo,
      order = topo$order,
      call = call,
      fit_env = fit_env
    ),
    class = "drm_sem"
  )
}

#' Assemble a distributional piecewise SEM from fitted drmTMB models
#'
#' `drm_psem()` is the piecewiseSEM-style core: you fit each endogenous node
#' yourself with [drmTMB::drmTMB()] and pass the fitted models. drmSEM extracts
#' the component-labelled graph, validates it as a DAG, and provides path
#' tables, d-separation tests, and simulation-based effects on top.
#'
#' Fit nodes with `control = drmTMB::drm_control(se = TRUE)` so that [vcov()],
#' Wald intervals, and d-separation refits are available.
#'
#' @param ... Named fitted `drmTMB` objects, one per endogenous node. The name
#'   is the node identifier used in path queries; predictors are matched to a
#'   node by its name or its response variable.
#' @param data The data frame all nodes were fitted to. Defaults to the data of
#'   the first node.
#' @param covariances Optional [covary()] declaration(s) (one object or a list)
#'   recording residual (`rho12`) or higher-level (`corpair`) covariance edges
#'   between responses. These are reported by [covariances()] and respected by
#'   [basis_set()] / [dsep()], but never enter [paths()] or the effect
#'   decomposition.
#' @param composites Optional [drm_composite()] declaration(s). For `drm_psem()`
#'   the construct column(s) must already be present in the data the nodes were
#'   fitted on; the declarations are recorded so [loadings()] can report them.
#'
#' @return A `drm_sem` object.
#' @seealso [drm_sem()] for the declarative interface that fits nodes for you.
#' @examples
#' \dontrun{
#' ctrl <- drmTMB::drm_control(se = TRUE)
#' size_fit <- drmTMB::drmTMB(
#'   drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'   family = stats::gaussian(), data = dat, control = ctrl)
#' abundance_fit <- drmTMB::drmTMB(
#'   drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'   family = drmTMB::nbinom2(), data = dat, control = ctrl)
#' sem <- drm_psem(size = size_fit, abundance = abundance_fit, data = dat)
#' paths(sem)
#' }
#' @export
drm_psem <- function(..., data = NULL, covariances = NULL, composites = NULL) {
  fits <- list(...)
  if (!all(vapply(fits, is_drmTMB_fit, logical(1)))) {
    cli::cli_abort(c(
      "{.fn drm_psem} expects fitted {.pkg drmTMB} objects.",
      "i" = "For the declarative interface that fits nodes for you, use {.fn drm_sem}."
    ))
  }
  if (is.null(data)) {
    data <- drm_fit_data(fits[[1L]])
  }
  new_drm_sem(fits, data, match.call(), fit_env = parent.frame(),
              covariances = covariances, composites = composites)
}

#' Fit and assemble a distributional piecewise SEM
#'
#' `drm_sem()` is the declarative interface. You describe each endogenous node
#' with [drm_node()]; `drm_sem()` fits each node with [drmTMB::drmTMB()] and then
#' builds the same object [drm_psem()] returns. Causal paths are
#' component-labelled: a predictor may target `mu`, `sigma`, `nu`, `zi`, `hu`,
#' `sd(group)`, or `rho12` of a node.
#'
#' @param ... Named [drm_node()] specifications, one per endogenous node.
#' @param data A data frame supplied to every node fit.
#' @param covariances Optional [covary()] declaration(s) (one object or a list)
#'   recording residual (`rho12`) or higher-level (`corpair`) covariance edges
#'   between responses; see [covariances()].
#' @param composites Optional [drm_composite()] declaration(s). Each construct
#'   column is materialized from its indicators *before* fitting, so node
#'   formulas can reference it as an ordinary observed column; the loadings are
#'   reported by [loadings()].
#'
#' @return A `drm_sem` object.
#' @seealso [drm_psem()], [paths()], [dsep()], [indirect_effects()].
#' @export
#'
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(
#'     drmTMB::bf(size ~ temp + habitat + (1 | species), sigma ~ temp),
#'     family = stats::gaussian()
#'   ),
#'   abundance = drm_node(
#'     drmTMB::bf(abundance ~ size + temp + (1 | site), sigma ~ temp, zi ~ habitat),
#'     family = drmTMB::nbinom2()
#'   ),
#'   data = dat
#' )
#' paths(sem)
#' dsep(sem)
#' indirect_effects(sem, from = "temp", to = "abundance")
#' }
drm_sem <- function(..., data, covariances = NULL, composites = NULL) {
  specs <- list(...)
  if (missing(data)) {
    cli::cli_abort("{.arg data} is required for {.fn drm_sem}.")
  }
  if (length(specs) == 0L) {
    cli::cli_abort("Supply at least one named {.fn drm_node}.")
  }
  if (!all(vapply(specs, inherits, logical(1), what = "drm_node"))) {
    cli::cli_abort(c(
      "{.fn drm_sem} expects {.fn drm_node} specifications.",
      "i" = "To assemble from already-fitted models, use {.fn drm_psem}."
    ))
  }
  if (is.null(names(specs)) || any(!nzchar(names(specs)))) {
    cli::cli_abort("Every node passed to {.fn drm_sem} must be named.")
  }
  # Materialize composite-construct columns BEFORE fitting, so node formulas can
  # reference them as ordinary observed columns (drm_apply_composites is a no-op
  # when composites is NULL).
  data <- drm_apply_composites(data, composites)
  nms <- names(specs)
  fits <- vector("list", length(specs))
  for (i in seq_along(specs)) {
    cli::cli_progress_step("Fitting node {.val {nms[[i]]}}")
    fits[[i]] <- drm_fit_node(specs[[i]], data = data, name = nms[[i]])
  }
  names(fits) <- nms
  new_drm_sem(fits, data, match.call(), fit_env = parent.frame(),
              covariances = covariances, composites = composites)
}

#' @export
print.drm_sem <- function(x, ...) {
  cli::cli_h1("drmSEM distributional piecewise SEM")
  cli::cli_text(
    "{length(x$endogenous)} endogenous node{?s}, {length(x$exogenous)} exogenous variable{?s}"
  )
  cli::cli_text("Topological order: {.val {x$order}}")
  for (nm in x$order) {
    rec <- x$records[[nm]]
    conv <- drm_fit_converged(rec$fit)
    flag <- if (isTRUE(conv)) "" else if (is.na(conv)) " (convergence unknown)" else " (NOT converged)"
    cli::cli_text(
      "{.strong {nm}} [{rec$family}] -> components {.val {rec$components}}{flag}"
    )
  }
  ne <- nrow(x$edges)
  cli::cli_text("{ne} component-labelled edge{?s}. Use {.fn paths} to list them.")
  nc <- if (is.null(x$covariances)) 0L else nrow(x$covariances)
  if (nc > 0L) {
    cli::cli_text("{nc} covariance edge{?s} (rho12/corpair). Use {.fn covariances} to list them.")
  }
  np <- if (is.null(x$composites)) 0L else length(x$composites)
  if (np > 0L) {
    cli::cli_text("{np} composite construct{?s}. Use {.fn loadings} to list the indicators.")
  }
  invisible(x)
}

#' @rdname drm_psem
#' @param object A `drm_sem` object.
#' @export
summary.drm_sem <- function(object, ...) {
  comp_counts <- table(object$edges$component)
  out <- list(
    n_nodes = length(object$endogenous),
    n_exogenous = length(object$exogenous),
    order = object$order,
    families = vapply(object$records[object$order], function(r) r$family, character(1)),
    components = lapply(object$records[object$order], function(r) r$components),
    converged = vapply(object$order, function(nm) drm_fit_converged(object$records[[nm]]$fit), logical(1)),
    edges_by_component = comp_counts,
    paths = paths(object)
  )
  class(out) <- "summary.drm_sem"
  out
}

#' @export
print.summary.drm_sem <- function(x, ...) {
  cli::cli_h1("drmSEM summary")
  cli::cli_text("{x$n_nodes} endogenous node{?s}; order {.val {x$order}}")
  cli::cli_h2("Edges by component")
  for (cmp in names(x$edges_by_component)) {
    cli::cli_text("{.strong {cmp}}: {x$edges_by_component[[cmp]]}")
  }
  cli::cli_h2("Paths")
  print(x$paths)
  invisible(x)
}
