# Graph-derived imputation models (S6).
#
# In x -> m -> y with m incomplete, node y needs a missing-predictor model for m.
# drmSEM already knows what that model is: it is node m's own formula and family.
# So drmSEM emits mi(m) + impute_model(m ~ x, family = <node m's family>) rather
# than asking the user to write one.
#
# Why that is worth doing: choosing the imputation model is normally the
# error-prone step, governed by folklore ("include the outcome", "include
# everything"). Here the causal graph specifies it -- the DAG gives m's parents
# directly -- and because imputer and analysis model come from ONE graph, the
# usual uncongeniality risk between a separately-specified imputer and analyst is
# structurally reduced.
#
# HONEST LIMIT, which belongs in the docs and not in a user's debugging session:
# piecewise means node y RE-ESTIMATES m's model inside its own likelihood; it
# does not share node m's estimates. Imputation uncertainty is propagated WITHIN
# each node (by drmTMB's joint Hessian) but NOT ACROSS nodes. This is a
# principled imputation, not the joint-likelihood optimum, and it must never be
# described as FIML across the SEM.
#
# drmSEM fits nothing here: it only assembles arguments that drmTMB fits inside a
# single node's likelihood, so the charter (docs/design/00-charter.md) is intact.

# Response families drmTMB accepts for a node that carries a modelled missing
# predictor. Mirrors drmTMB::drm_missing_predictor_families(); kept as a drmSEM
# constant so the gate is testable without the engine, and locked to the engine's
# own list by test-imputation.R.
drm_impute_response_families <- function() {
  c("gaussian", "poisson", "binomial", "nbinom2", "beta")
}

# Predictor-model families drmTMB can impute FROM, for a Gaussian response.
drm_impute_predictor_families <- function() {
  c(
    "gaussian", "binomial", "cumulative_logit", "categorical", "beta",
    "zero_one_beta", "beta_binomial", "poisson", "nbinom2",
    "truncated_nbinom2", "lognormal", "Gamma", "gamma", "tweedie"
  )
}

# Which columns of `data` are incomplete.
drm_incomplete_columns <- function(data) {
  data <- as.data.frame(data)
  names(data)[vapply(data, anyNA, logical(1))]
}

#' Derive one imputation model per node from the graph.
#'
#' @return A named list, one element per node needing imputation, each
#'   `list(variable, formula, family, family_name)`. Empty list when nothing
#'   needs imputing.
#' @keywords internal
#' @noRd
drm_imputation_plan <- function(specs, data) {
  incomplete <- drm_incomplete_columns(data)
  if (!length(incomplete)) {
    return(list())
  }
  records <- drm_build_spec_records(specs)
  edges <- drm_collapse_edges(drm_build_edges(records))
  plan <- list()
  for (nm in names(specs)) {
    spec <- specs[[nm]]
    parents <- drm_parents(nm, edges)
    # Only an ENDOGENOUS parent has a node model to borrow. An incomplete
    # exogenous predictor has no formula in the graph, so the graph cannot
    # specify its imputation model -- which is the whole premise here.
    endo <- intersect(parents, names(specs))
    targets <- intersect(endo, incomplete)
    if (!length(targets)) {
      next
    }
    if (length(targets) > 1L) {
      cli::cli_abort(c(
        "Node {.val {nm}} has {length(targets)} incomplete parents
         ({.val {targets}}), but the engine models one at a time.",
        "x" = "{.code drmTMB} supports exactly one {.fn mi} term per fit.",
        "i" = "Impute or complete all but one of them, or fit this node with
               {.code impute = \"none\"} and accept complete-case rows."
      ))
    }
    v <- targets[[1L]]
    drm_check_impute_legal(nm, spec, v, specs[[v]])
    plan[[nm]] <- list(
      variable = v,
      formula = drm_mu_formula(specs[[v]]),
      family = specs[[v]]$family,
      family_name = drm_family_name(drm_fit_family(specs[[v]]))
    )
  }
  plan
}

# Refuse rather than emit an illegal call. Each check mirrors a hard abort the
# engine would raise later with less context about WHY drmSEM asked for it.
drm_check_impute_legal <- function(node, spec, v, parent_spec) {
  resp_family <- drm_family_name(drm_fit_family(spec))
  pred_family <- drm_family_name(drm_fit_family(parent_spec))
  if (!resp_family %in% drm_impute_response_families()) {
    cli::cli_abort(c(
      "Cannot derive an imputation model for node {.val {node}}.",
      "x" = "Its family {.val {resp_family}} cannot carry a modelled missing
             predictor.",
      "i" = "Supported response families: {.val {drm_impute_response_families()}}."
    ))
  }
  if (!identical(resp_family, "gaussian") && !identical(pred_family, "binomial")) {
    cli::cli_abort(c(
      "Cannot derive an imputation model for node {.val {node}}.",
      "x" = "A {.val {resp_family}} response admits only a BINARY missing
             predictor, but node {.val {v}} is {.val {pred_family}}.",
      "i" = "Only a {.val gaussian} response accepts the full predictor-family
             catalogue."
    ))
  }
  if (identical(resp_family, "gaussian") &&
        !pred_family %in% drm_impute_predictor_families()) {
    cli::cli_abort(c(
      "Cannot derive an imputation model for node {.val {node}}.",
      "x" = "Node {.val {v}} has family {.val {pred_family}}, which has no
             missing-predictor route."
    ))
  }
  # mi() is only legal as a bare, additive term in the mu formula. Emitting
  # mi(log(m)) or mi() inside an interaction would abort in the engine.
  if (!drm_is_bare_additive_term(spec, v)) {
    cli::cli_abort(c(
      "Cannot derive an imputation model for node {.val {node}}.",
      "x" = "{.val {v}} is not a plain additive term in that node's location
             formula.",
      "i" = "{.fn mi} supports only a bare symbol, e.g. {.code y ~ x + {v}} --
             not a transformation or an interaction."
    ))
  }
  invisible(TRUE)
}

# The mu entry's formula, as a formula object.
drm_mu_formula <- function(spec) {
  for (e in spec$formula$entries) {
    if (identical(e$dpar, "mu")) {
      return(drm_as_formula(e$lhs, e$rhs, spec$formula$env))
    }
  }
  cli::cli_abort("Node specification has no {.val mu} formula.")
}

drm_as_formula <- function(lhs, rhs, env) {
  env <- if (is.null(env)) globalenv() else env
  eval(as.call(list(as.name("~"), lhs, rhs)), envir = env)
}

# Is `v` a top-level additive symbol on the mu right-hand side?
drm_is_bare_additive_term <- function(spec, v) {
  for (e in spec$formula$entries) {
    if (!identical(e$dpar, "mu")) {
      next
    }
    terms <- drm_additive_terms(e$rhs)
    return(any(vapply(terms, function(t) identical(t, as.name(v)), logical(1))))
  }
  FALSE
}

# Split an expression on top-level `+` only, so terms inside `:`/`*`/`log()`
# stay bundled and therefore fail the bare-symbol test above.
drm_additive_terms <- function(expr) {
  if (is.call(expr) && identical(expr[[1L]], as.name("+")) && length(expr) == 3L) {
    return(c(drm_additive_terms(expr[[2L]]), drm_additive_terms(expr[[3L]])))
  }
  list(expr)
}

# Rewrite a node's mu formula so `v` becomes mi(v), leaving other components
# untouched (mi() is only legal in the location formula).
drm_wrap_mi <- function(formula, v) {
  env <- if (is.null(formula$env)) globalenv() else formula$env
  parts <- lapply(formula$entries, function(e) {
    if (!identical(e$dpar, "mu")) {
      return(drm_as_formula(e$lhs, e$rhs, env))
    }
    sub <- stats::setNames(list(call("mi", as.name(v))), v)
    drm_as_formula(e$lhs, do.call(substitute, list(e$rhs, sub)), env)
  })
  do.call(drmTMB::bf, unname(parts))
}

#' Rewrite node specs so each incomplete endogenous parent is imputed from its
#' own node model.
#'
#' Mirrors the [drm_apply_composites()] contract: takes the thing to rewrite plus
#' the declaration, returns the rewritten thing, and is a total no-op when the
#' declaration is off.
#' @keywords internal
#' @noRd
drm_apply_imputation <- function(specs, data, impute = "none") {
  if (!identical(impute, "auto")) {
    return(specs)
  }
  drm_require_drmTMB()
  plan <- drm_imputation_plan(specs, data)
  # Leave untouched nodes ALONE. miss_control(predictor = "model") with zero
  # mi() terms is itself a hard abort in the engine, so a blanket application
  # would break every complete node.
  for (nm in names(plan)) {
    p <- plan[[nm]]
    spec <- specs[[nm]]
    spec$formula <- drm_wrap_mi(spec$formula, p$variable)
    spec$args$impute <- stats::setNames(
      list(drmTMB::impute_model(p$formula, family = p$family)),
      p$variable
    )
    spec$args$missing <- drmTMB::miss_control(predictor = "model")
    specs[[nm]] <- spec
  }
  if (length(plan)) {
    detail <- vapply(
      names(plan),
      function(nm) paste0(nm, " <- ", plan[[nm]]$variable),
      character(1)
    )
    cli::cli_inform(c(
      "i" = "Imputation models derived from the graph: {.val {detail}}.",
      "i" = "Each is the incomplete parent's own node model. Uncertainty is
             propagated within a node, not across nodes -- see
             {.code vignette(\"missing-data\")}."
    ))
  }
  specs
}

#' Imputation models drmSEM derived from the graph
#'
#' Reports the per-node imputation models [drm_sem()] built from the DAG when
#' called with `impute = "auto"`. Each row is one node whose incomplete parent
#' was imputed from that parent's own node model.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame with columns `node`, `variable`, `model` and `family`,
#'   with zero rows when no imputation was derived.
#' @seealso [drm_sem()], [check_sem()].
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   m = drm_node(drmTMB::bf(m ~ x)),
#'   y = drm_node(drmTMB::bf(y ~ m + x)),
#'   data = dat, impute = "auto"
#' )
#' imputation(sem)
#' }
#' @export
imputation <- function(object, ...) {
  UseMethod("imputation")
}

#' @rdname imputation
#' @export
imputation.drm_sem <- function(object, ...) {
  plan <- attr(object, "imputation", exact = TRUE)
  if (is.null(plan) || !length(plan)) {
    return(data.frame(
      node = character(0),
      variable = character(0),
      model = character(0),
      family = character(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    node = names(plan),
    variable = vapply(plan, function(p) p$variable, character(1)),
    model = vapply(plan, function(p) deparse1(p$formula), character(1)),
    family = vapply(plan, function(p) p$family_name, character(1)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}
