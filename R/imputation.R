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
  c("gaussian", "poisson", "binomial", "nbinom2", "beta", "gamma")
}

# Engine allow-list uses lowercase "gamma"; stats::Gamma()$family is "Gamma".
drm_impute_family_key <- function(family_name) {
  if (identical(family_name, "Gamma")) {
    return("gamma")
  }
  family_name
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

#' Derive imputation models per node from the graph.
#'
#' One record per incomplete endogenous parent. A node with two incomplete
#' Gaussian parents (Phase 1 cell) is legal. k > 2 and non-Gaussian k = 2
#' still abort — those are engine limits, not a drmSEM likelihood.
#'
#' @return A named list, one element per node needing imputation. Each
#'   element is `list(variable, formula, family, family_name)` for one
#'   parent, or the same plus `parents` (a list of those records) when
#'   k = 2. `variable` is a character vector of every imputed parent so
#'   `drm_node_rows(exclude = )` keeps those columns. Empty list when
#'   nothing needs imputing.
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
    if (length(targets) > 2L) {
      cli::cli_abort(c(
        "Node {.val {nm}} has {length(targets)} incomplete parents
         ({.val {targets}}).",
        "x" = "{.code drmTMB} does not yet implement k > 2 independent
               {.fn mi} terms.",
        "i" = "Impute or complete all but two of them, or fit this node with
               {.code impute = \"none\"} and accept complete-case rows."
      ))
    }
    if (length(targets) == 2L) {
      drm_check_two_gaussian_mi(nm, spec, targets, specs)
    }
    parent_recs <- lapply(targets, function(v) {
      drm_check_impute_legal(nm, spec, v, specs[[v]])
      list(
        variable = v,
        formula = drm_mu_formula(specs[[v]]),
        family = specs[[v]]$family,
        family_name = drm_family_name(drm_fit_family(specs[[v]]))
      )
    })
    first <- parent_recs[[1L]]
    plan[[nm]] <- list(
      # Length-1 stays a scalar so one-parent consumers (alignment, V-77)
      # keep seeing the prototype shape.
      variable = if (length(targets) == 1L) targets[[1L]] else targets,
      formula = first$formula,
      family = first$family,
      family_name = first$family_name,
      parents = if (length(targets) > 1L) parent_recs else NULL
    )
  }
  plan
}

# Parent records for a plan entry. One-parent entries have no $parents list.
drm_plan_parents <- function(p) {
  if (!is.null(p$parents)) {
    return(p$parents)
  }
  list(p[c("variable", "formula", "family", "family_name")])
}

# Phase 1 cell only: y ~ mi(m1) + mi(m2) + x with two Gaussian impute_model().
# Fail loud with the engine reason rather than emit an illegal call.
drm_check_two_gaussian_mi <- function(node, spec, targets, specs) {
  resp_family <- drm_family_name(drm_fit_family(spec))
  pred_families <- vapply(
    targets,
    function(v) drm_family_name(drm_fit_family(specs[[v]])),
    character(1)
  )
  if (!identical(resp_family, "gaussian") || !all(pred_families == "gaussian")) {
    cli::cli_abort(c(
      "Node {.val {node}} has two incomplete parents ({.val {targets}}).",
      "x" = "The engine's first k = 2 slice is two independent Gaussian
             {.fn mi} terms on a Gaussian response.",
      "x" = "This node is {.val {resp_family}}; parents are
             {.val {pred_families}}.",
      "i" = "Impute or complete one parent, or fit this node with
             {.code impute = \"none\"}."
    ))
  }
  invisible(TRUE)
}

# Refuse rather than emit an illegal call. Each check mirrors a hard abort the
# engine would raise later with less context about WHY drmSEM asked for it.
drm_check_impute_legal <- function(node, spec, v, parent_spec) {
  resp_family <- drm_impute_family_key(drm_family_name(drm_fit_family(spec)))
  pred_family <- drm_impute_family_key(drm_family_name(drm_fit_family(parent_spec)))
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
    recs <- drm_plan_parents(plan[[nm]])
    spec <- specs[[nm]]
    for (pr in recs) {
      spec$formula <- drm_wrap_mi(spec$formula, pr$variable)
    }
    spec$args$impute <- stats::setNames(
      lapply(recs, function(pr) {
        drmTMB::impute_model(pr$formula, family = pr$family)
      }),
      vapply(recs, function(pr) pr$variable, character(1))
    )
    spec$args$missing <- drmTMB::miss_control(predictor = "model")
    specs[[nm]] <- spec
  }
  if (length(plan)) {
    detail <- vapply(
      names(plan),
      function(nm) {
        vars <- vapply(
          drm_plan_parents(plan[[nm]]),
          function(pr) pr$variable,
          character(1)
        )
        paste0(nm, " <- ", paste(vars, collapse = ", "))
      },
      character(1)
    )
    cli::cli_inform(c(
      "i" = "Imputation models derived from the graph: {.val {detail}}.",
      "i" = "Each is the incomplete parent's own node model. The downstream node
             re-estimates it rather than sharing the parent's estimates, so this
             is not full-information maximum likelihood across the SEM. See
             {.file docs/design/13-missing-data.md}."
    ))
  }
  specs
}

#' Imputation models drmSEM derived from the graph
#'
#' Reports the per-node imputation models [drm_sem()] built from the DAG when
#' called with `impute = "auto"`. Each row is one `(node, parent)` pair: the
#' incomplete endogenous parent was imputed from that parent's own node model.
#' A node with two incomplete Gaussian parents yields two rows. Uncertainty
#' columns come from the engine's [imputed()] table and must be read via
#' `uncertainty_status`, never via `is.na(std_error)` — those semantics
#' differ between drmTMB 0.6.0 and 0.7.0. This is not full-information
#' maximum likelihood across the SEM.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame with columns `node`, `variable`, `model`, `family`,
#'   `n_missing`, `uncertainty_status`, and `std_error_usable`, with zero
#'   rows when no imputation was derived. `std_error_usable` is `TRUE` only
#'   when every missing row has `uncertainty_status == "ok"` and a finite
#'   standard error.
#' @seealso [drm_sem()], [imputed()], [check_sem()].
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
  empty <- data.frame(
    node = character(0),
    variable = character(0),
    model = character(0),
    family = character(0),
    n_missing = integer(0),
    uncertainty_status = character(0),
    std_error_usable = logical(0),
    stringsAsFactors = FALSE
  )
  if (is.null(plan) || !length(plan)) {
    return(empty)
  }
  rows <- lapply(names(plan), function(nm) {
    recs <- drm_plan_parents(plan[[nm]])
    fit <- object$records[[nm]]$fit
    unc <- lapply(recs, function(p) drm_imputation_uncertainty(fit, p$variable))
    data.frame(
      node = nm,
      variable = vapply(recs, function(p) p$variable, character(1)),
      model = vapply(recs, function(p) deparse1(p$formula), character(1)),
      family = vapply(recs, function(p) p$family_name, character(1)),
      n_missing = vapply(unc, function(u) u$n_missing, integer(1)),
      uncertainty_status = vapply(unc, function(u) u$uncertainty_status, character(1)),
      std_error_usable = vapply(unc, function(u) u$std_error_usable, logical(1)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# Per-(node, parent) summary of the engine imputed() table.
# Isolated so imputation() never inspects is.na(std_error) itself.
drm_imputation_uncertainty <- function(fit, variable) {
  fallback <- list(
    n_missing = NA_integer_,
    uncertainty_status = NA_character_,
    std_error_usable = NA
  )
  tbl <- tryCatch(
    drm_fit_imputed(fit, variable = variable, rows = "missing", se = TRUE),
    error = function(e) NULL
  )
  if (is.null(tbl)) {
    return(fallback)
  }
  if (!nrow(tbl)) {
    return(list(
      n_missing = 0L,
      uncertainty_status = NA_character_,
      std_error_usable = NA
    ))
  }
  statuses <- unique(as.character(tbl$uncertainty_status))
  usable <- drm_imputed_std_error_usable(
    tbl$uncertainty_status,
    tbl$std_error,
    tbl$observed
  )
  list(
    n_missing = as.integer(nrow(tbl)),
    uncertainty_status = if (length(statuses) == 1L) {
      statuses[[1L]]
    } else {
      "mixed"
    },
    std_error_usable = all(usable)
  )
}

#' Fitted missing-predictor values from a drmSEM graph
#'
#' Walks every node that [drm_sem()] derived an imputation model for and
#' returns the engine's missing-predictor table, stacked, with a `node`
#' column. Omitting `variable` stacks every imputed parent — it never
#' silently returns the first `mi()` term only. Branch on
#' `uncertainty_status`, never on `is.na(std_error)`: observed rows and
#' `se = FALSE` requests report `std_error = NA` with status `"ok"`.
#' This is not multiple imputation, not Rubin's rules, and not
#' full-information maximum likelihood across the SEM.
#'
#' @param object A `drm_sem` object.
#' @param variable Optional parent name. When omitted, every imputed
#'   parent is stacked.
#' @param node Optional endogenous node name that restricts the stack.
#' @param rows `"missing"` or `"all"`, forwarded to the engine.
#' @param se Logical; forwarded to the engine.
#' @param ... Unused.
#' @return A data frame with `node` plus the engine columns `variable`,
#'   `original_row`, `model_row`, `observed`, `estimate`, `std_error`,
#'   `source`, and `uncertainty_status`. Zero rows when nothing was
#'   imputed.
#' @seealso [imputation()], [drm_sem()].
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   m = drm_node(drmTMB::bf(m ~ x)),
#'   y = drm_node(drmTMB::bf(y ~ m + x)),
#'   data = dat, impute = "auto"
#' )
#' imputed(sem)
#' imputed(sem, variable = "m", rows = "all")
#' }
#' @export
imputed <- function(object, ...) {
  UseMethod("imputed")
}

#' @rdname imputed
#' @export
imputed.drm_sem <- function(
  object,
  variable = NULL,
  node = NULL,
  rows = c("missing", "all"),
  se = TRUE,
  ...
) {
  rows <- match.arg(rows)
  empty <- data.frame(
    node = character(0),
    variable = character(0),
    original_row = integer(0),
    model_row = integer(0),
    observed = logical(0),
    estimate = numeric(0),
    std_error = numeric(0),
    source = character(0),
    uncertainty_status = character(0),
    stringsAsFactors = FALSE
  )
  plan <- attr(object, "imputation", exact = TRUE)
  if (is.null(plan) || !length(plan)) {
    return(empty)
  }
  nms <- names(plan)
  if (!is.null(node)) {
    if (!is.character(node) || length(node) != 1L || is.na(node) || !nzchar(node)) {
      cli::cli_abort("{.arg node} must be one endogenous node name.")
    }
    if (!node %in% nms) {
      cli::cli_abort(c(
        "No graph-derived imputation for node {.val {node}}.",
        "i" = "Nodes with a derived imputer: {.val {nms}}."
      ))
    }
    nms <- node
  }
  if (!is.null(variable)) {
    if (
      !is.character(variable) ||
        length(variable) != 1L ||
        is.na(variable) ||
        !nzchar(variable)
    ) {
      cli::cli_abort("{.arg variable} must be one missing-predictor name.")
    }
  }
  chunks <- list()
  available <- character(0)
  for (nm in nms) {
    recs <- drm_plan_parents(plan[[nm]])
    vars <- vapply(recs, function(p) p$variable, character(1))
    available <- c(available, vars)
    want <- if (is.null(variable)) vars else intersect(variable, vars)
    fit <- object$records[[nm]]$fit
    for (v in want) {
      tbl <- drm_fit_imputed(fit, variable = v, rows = rows, se = se)
      tbl <- cbind(node = nm, tbl, stringsAsFactors = FALSE)
      chunks[[length(chunks) + 1L]] <- tbl
    }
  }
  if (!length(chunks)) {
    if (!is.null(variable)) {
      cli::cli_abort(c(
        "Unknown modelled missing predictor {.val {variable}}.",
        "i" = "Available modelled missing predictor{?s}: {.val {unique(available)}}."
      ))
    }
    return(empty)
  }
  out <- do.call(rbind, chunks)
  rownames(out) <- NULL
  out
}
