#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# drmTMB adapter.
#
# EVERY assumption about the internal shape of a fitted `drmTMB` object lives
# here. No other file in drmSEM should reach into a drmTMB object directly.
# This keeps drmSEM robust to drmTMB internal changes: if drmTMB shifts, only
# this file needs updating.
#
# Verified against drmTMB 0.1.3.9000 (github itchyshin/drmTMB):
#   * `bf()`/`drm_formula()` returns an object with `$calls`, `$names`,
#     `$entries` (each entry has `$dpar`, `$response`, `$lhs`, `$rhs`).
#   * A fitted object carries `$formula` (the bf object), `$family`, `$data`,
#     `$coefficients` (named list keyed by dpar -> named numeric vector).
#   * `coef(obj, dpar)`, `fixef(obj, dpar)`, `vcov(obj)` (dimnames "dpar:term",
#     needs control = drm_control(se = TRUE)), `logLik()`, `is_converged()`,
#     `predict_parameters(obj, newdata, dpar, type = c("response","link"))`.
# ---------------------------------------------------------------------------

#' Is this object a fitted drmTMB model?
#' @keywords internal
#' @noRd
is_drmTMB_fit <- function(x) {
  inherits(x, "drmTMB")
}

drm_require_drmTMB <- function() {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    cli::cli_abort(c(
      "The {.pkg drmTMB} package is required for this operation.",
      "i" = "Install it with {.code remotes::install_github(\"itchyshin/drmTMB\")}."
    ))
  }
}

#' The `bf`/`drm_formula` object for a fitted node
#' @keywords internal
#' @noRd
drm_fit_formula <- function(fit) {
  fit$formula
}

#' Formula entries (one per distributional-parameter formula)
#' @keywords internal
#' @noRd
drm_fit_entries <- function(fit) {
  ff <- drm_fit_formula(fit)
  entries <- ff$entries
  if (is.null(entries)) {
    cli::cli_abort("Could not read formula entries from the fitted node.")
  }
  entries
}

#' Family object / name of a fitted node
#' @keywords internal
#' @noRd
drm_fit_family <- function(fit) {
  fit$family
}

drm_family_name <- function(family) {
  if (is.character(family)) {
    return(family[[1L]])
  }
  if (is.list(family) && !is.null(family$family)) {
    return(family$family)
  }
  if (inherits(family, "family") && !is.null(family$family)) {
    return(family$family)
  }
  "unknown"
}

#' Model data frame used to fit a node
#' @keywords internal
#' @noRd
drm_fit_data <- function(fit) {
  fit$data
}

#' The response label (deparsed mu LHS) and bare response variables of a node
#' @keywords internal
#' @noRd
drm_fit_response <- function(fit) {
  entries <- drm_fit_entries(fit)
  for (e in entries) {
    if (identical(e$dpar, "mu") && !is.na(e$response)) {
      return(list(label = e$response, vars = all.vars(e$lhs)))
    }
  }
  # bivariate or unusual: fall back to the first entry with a response
  for (e in entries) {
    if (!is.null(e$response) && !is.na(e$response)) {
      return(list(label = e$response, vars = all.vars(e$lhs)))
    }
  }
  list(label = NA_character_, vars = character(0))
}

#' Modelled distributional components (dpars) of a node, in formula order
#' @keywords internal
#' @noRd
drm_fit_components <- function(fit) {
  entries <- drm_fit_entries(fit)
  comps <- vapply(entries, function(e) as.character(e$dpar), character(1))
  unique(comps)
}

#' Fixed-effect predictors targeting one component of a node
#'
#' @return Character vector of predictor variable names for the formula whose
#'   `dpar` equals `component` (empty if intercept-only or absent).
#' @keywords internal
#' @noRd
drm_fit_component_predictors <- function(fit, component) {
  entries <- drm_fit_entries(fit)
  preds <- character(0)
  for (e in entries) {
    if (identical(as.character(e$dpar), component)) {
      preds <- c(preds, drm_fixed_predictors(e$rhs))
    }
  }
  unique(preds)
}

#' Coefficients for one component (named numeric vector)
#' @keywords internal
#' @noRd
drm_fit_coef <- function(fit, component) {
  co <- fit$coefficients
  if (is.null(co) || is.null(co[[component]])) {
    return(stats::setNames(numeric(0), character(0)))
  }
  co[[component]]
}

#' Full fixed-effect coefficient vector with "dpar:term" names
#' @keywords internal
#' @noRd
drm_fit_coef_vector <- function(fit) {
  co <- fit$coefficients
  out <- numeric(0)
  for (dpar in names(co)) {
    v <- co[[dpar]]
    if (length(v)) {
      names(v) <- paste0(dpar, ":", names(v))
      out <- c(out, v)
    }
  }
  out
}

#' Fixed-effect covariance matrix (dimnames "dpar:term")
#'
#' Returns `NULL` when standard errors are unavailable (model fitted without
#' `drm_control(se = TRUE)` or a non-positive-definite Hessian).
#' @keywords internal
#' @noRd
drm_fit_vcov <- function(fit) {
  out <- tryCatch(stats::vcov(fit), error = function(e) NULL)
  if (is.null(out) || any(is.na(out))) {
    return(out)
  }
  out
}

#' Log-likelihood and degrees of freedom of a node
#' @keywords internal
#' @noRd
drm_fit_logLik <- function(fit) {
  ll <- tryCatch(stats::logLik(fit), error = function(e) NULL)
  if (is.null(ll)) {
    return(list(logLik = NA_real_, df = NA_integer_))
  }
  list(logLik = as.numeric(ll), df = attr(ll, "df"))
}

#' Convergence flag for a node
#' @keywords internal
#' @noRd
drm_fit_converged <- function(fit) {
  if (requireNamespace("drmTMB", quietly = TRUE) &&
      exists("is_converged", envir = asNamespace("drmTMB"))) {
    conv <- tryCatch(drmTMB::is_converged(fit), error = function(e) NA)
    if (length(conv) == 1L && !is.na(conv)) {
      return(isTRUE(conv))
    }
  }
  conv <- fit$opt$convergence
  if (is.null(conv)) NA else identical(as.integer(conv), 0L)
}

#' Predict distributional parameters on a new data grid
#'
#' Thin wrapper over `drmTMB::predict_parameters()`. Returns a data.frame with
#' one column per requested distributional parameter (and, by default, the
#' newdata columns).
#' @keywords internal
#' @noRd
drm_predict_parameters <- function(fit, newdata, dpar = NULL,
                                    type = c("response", "link"),
                                    include_newdata = FALSE) {
  drm_require_drmTMB()
  type <- match.arg(type)
  drmTMB::predict_parameters(
    fit,
    newdata = newdata,
    dpar = dpar,
    type = type,
    include_newdata = include_newdata
  )
}

#' Refit a node, adding `add_var` as a fixed-effect predictor to every modelled
#' component. Used by the d-separation engine.
#'
#' @return A fitted `drmTMB` object, or `NULL` if the refit fails.
#' @keywords internal
#' @noRd
drm_refit_augmented <- function(fit, add_var, components = NULL,
                                se = TRUE, env = parent.frame()) {
  drm_require_drmTMB()
  ff <- drm_fit_formula(fit)
  calls <- ff$calls
  nms <- ff$names
  if (is.null(nms)) nms <- rep("", length(calls))
  entries <- drm_fit_entries(fit)
  if (is.null(components)) {
    components <- drm_fit_components(fit)
  }

  add_sym <- as.name(add_var)
  new_calls <- vector("list", length(calls))
  for (i in seq_along(calls)) {
    e <- entries[[i]]
    if (as.character(e$dpar) %in% components) {
      cl <- calls[[i]]
      # append `+ add_var` to the RHS (last element of the `~` call)
      rhs <- cl[[length(cl)]]
      cl[[length(cl)]] <- call("+", rhs, add_sym)
      new_calls[[i]] <- cl
    } else {
      new_calls[[i]] <- calls[[i]]
    }
  }
  names(new_calls) <- nms

  # Evaluate the rebuilt formula AND the refit in `env` -- the environment where
  # the SEM was specified -- so structured-effect objects referenced by name
  # (e.g. the `tree` in phylo(1 | species, tree = tree)) resolve on refit. Without
  # this, re-fitting a phylo/animal/spatial node fails ("refit_failed"); see OQ-13.
  new_formula <- tryCatch(
    do.call(drmTMB::drm_formula, new_calls, envir = env),
    error = function(e) NULL
  )
  if (is.null(new_formula)) {
    return(NULL)
  }

  control <- if (isTRUE(se)) {
    tryCatch(drmTMB::drm_control(se = TRUE), error = function(e) list())
  } else {
    list()
  }

  tryCatch(
    do.call(
      drmTMB::drmTMB,
      list(
        new_formula,
        family = drm_fit_family(fit),
        data = drm_fit_data(fit),
        control = control
      ),
      envir = env
    ),
    error = function(e) NULL
  )
}

#' Fixed-effect design matrix for one component, aligned to the fitted
#' coefficient names.
#'
#' Reconstructs the fixed-effect formula for `component` (bars and structured
#' markers dropped), builds `model.matrix()` on `newdata`, and aligns/zero-fills
#' columns to match the fitted coefficient names. Random effects are treated as
#' zero (population-level / typical-group prediction), which is the convention
#' drmSEM uses for marginal effect propagation.
#'
#' This assumes drmTMB codes fixed effects with standard `model.matrix()`
#' contrasts; it is isolated here so that assumption lives in one place.
#'
#' @return A numeric matrix with `nrow(newdata)` rows and columns named exactly
#'   like `names(drm_fit_coef(fit, component))`.
#' @keywords internal
#' @noRd
drm_fixed_design <- function(fit, component, newdata) {
  coefs <- drm_fit_coef(fit, component)
  coef_names <- names(coefs)
  if (length(coef_names) == 0L) {
    return(matrix(numeric(0), nrow = nrow(newdata), ncol = 0L))
  }
  entries <- drm_fit_entries(fit)
  fixed_rhs <- NULL
  for (e in entries) {
    if (identical(as.character(e$dpar), component)) {
      rhs <- drm_drop_bars(e$rhs)
      rhs <- if (is.null(rhs)) NULL else drm_strip_markers(rhs)
      fixed_rhs <- rhs
      break
    }
  }
  has_intercept <- "(Intercept)" %in% coef_names
  rhs_text <- if (is.null(fixed_rhs)) "1" else deparse1(fixed_rhs)
  form <- stats::as.formula(
    paste0("~ ", rhs_text, if (has_intercept) "" else " - 1")
  )
  mm <- tryCatch(
    stats::model.matrix(form, data = as.data.frame(newdata)),
    error = function(e) NULL
  )
  out <- matrix(0, nrow = nrow(newdata), ncol = length(coef_names),
                dimnames = list(NULL, coef_names))
  if (!is.null(mm)) {
    shared <- intersect(colnames(mm), coef_names)
    out[, shared] <- mm[, shared, drop = FALSE]
  }
  out
}
