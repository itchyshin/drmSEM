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

#' Grouping columns within which `var` takes a single value.
#'
#' A d-separation claim is tested on the flattened data frame, one row per
#' observation. When the claim's variable actually varies at a COARSER scale --
#' a species-level trait repeated down to individuals, say -- the likelihood
#' ratio sees one row per individual while the variable carries only as much
#' information as there are groups. The test then rejects a TRUE independence,
#' because a chance group-level correlation is credited with n = rows of evidence.
#'
#' This finds the candidate groupings: factor/character columns of `data`, with
#' fewer levels than rows, within which `var` is constant.
#' @return A data frame of `group` and `n_groups`, zero rows when the variable
#'   varies within every candidate grouping (i.e. it is at row scale).
#' @keywords internal
#' @noRd
drm_coarser_scales <- function(var, data) {
  empty <- data.frame(
    group = character(0), n_groups = integer(0), stringsAsFactors = FALSE
  )
  data <- as.data.frame(data)
  if (!var %in% names(data)) {
    return(empty)
  }
  v <- data[[var]]
  rows <- list()
  for (nm in setdiff(names(data), var)) {
    g <- data[[nm]]
    if (!is.factor(g) && !is.character(g)) {
      next
    }
    lv <- length(unique(g))
    if (lv <= 1L || lv >= nrow(data)) {
      next
    }
    # constant within every level => the variable lives at this coarser scale
    per <- tapply(v, g, function(x) length(unique(x[!is.na(x)])))
    if (all(per <= 1L, na.rm = TRUE)) {
      rows[[length(rows) + 1L]] <- data.frame(
        group = nm, n_groups = as.integer(lv), stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    return(empty)
  }
  do.call(rbind, rows)
}

#' Grouping factors a fitted node already accounts for, as bare names.
#' @keywords internal
#' @noRd
drm_fit_grouping_vars <- function(fit) {
  entries <- tryCatch(drm_fit_entries(fit), error = function(e) NULL)
  if (is.null(entries)) {
    return(character(0))
  }
  out <- character(0)
  for (e in entries) {
    rhs <- e$rhs
    if (is.null(rhs)) {
      next
    }
    txt <- paste(deparse(rhs), collapse = " ")
    # bar terms: (1 | g), (x | g), relmat(1 | g, ...), phylo(1 | g, ...)
    m <- gregexpr("\\|[[:space:]]*([A-Za-z._][A-Za-z0-9._]*)", txt)
    hits <- regmatches(txt, m)[[1]]
    if (length(hits)) {
      out <- c(out, sub("^\\|[[:space:]]*", "", hits))
    }
  }
  unique(out)
}

#' The engine's `model_type` for a fitted node.
#'
#' drmTMB folds zero-inflation and the hurdle into `model_type` while leaving
#' `family$family` at the base family: a hurdle node is `model_type =
#' "hurdle_nbinom2"` but `family$family = "truncated_nbinom2"`. drmSEM keys on the
#' family NAME almost everywhere, which is correct for labelling — but a sampler
#' that needs to know about the hurdle cannot get it from the name.
#' @return A single string, or `NA_character_` when the engine does not say.
#' @keywords internal
#' @noRd
drm_fit_model_type <- function(fit) {
  mt <- tryCatch(fit$model$model_type, error = function(e) NULL)
  if (is.null(mt) || length(mt) != 1L || !is.character(mt)) {
    return(NA_character_)
  }
  mt
}

#' Borrow an internal drmTMB draw helper by name.
#'
#' Realized-value samplers must match `drmTMB::simulate()` exactly, and the
#' surest way to match a parameterization is to call the engine's own function
#' rather than restate it. Restating is how `sigma`-to-dispersion mappings drift.
#' Isolated here because reaching into drmTMB's namespace is precisely the kind
#' of assumption this file exists to contain.
#' @return The function, or `NULL` if this drmTMB build does not export it.
#' @keywords internal
#' @noRd
drm_engine_fun <- function(name) {
  if (!requireNamespace("drmTMB", quietly = TRUE)) {
    return(NULL)
  }
  ns <- asNamespace("drmTMB")
  if (!exists(name, envir = ns, inherits = FALSE)) {
    return(NULL)
  }
  f <- get(name, envir = ns)
  if (is.function(f)) f else NULL
}

#' Binomial denominator of a fitted node, aligned to `n` rows.
#'
#' `binomial` and `beta_binomial` model a PROBABILITY in `mu` but have COUNTS as
#' the response, so both the realized-value sampler and the expected mean need
#' the number of trials. drmTMB stores it on the fitted model.
#' @return A numeric vector of length `n`, or `NULL` when unavailable or of a
#'   length that cannot be aligned (in which case callers must not guess).
#' @keywords internal
#' @noRd
drm_fit_trials <- function(fit, n) {
  trials <- tryCatch(fit$model$trials, error = function(e) NULL)
  if (is.null(trials) || !length(trials) || !is.numeric(trials)) {
    return(NULL)
  }
  if (length(trials) == 1L) {
    return(rep(as.numeric(trials), n))
  }
  if (length(trials) == n) {
    return(as.numeric(trials))
  }
  NULL
}

#' Number of observations a fitted node actually used.
#' @return A single integer, or `NA_integer_` if the engine will not say.
#' @keywords internal
#' @noRd
drm_fit_nobs <- function(fit) {
  n <- tryCatch(stats::nobs(fit), error = function(e) NA_integer_)
  if (length(n) != 1L || !is.finite(n)) {
    return(NA_integer_)
  }
  as.integer(n)
}

#' Every data column a node reads: response variables plus fixed predictors of
#' every modelled component.
#'
#' Duck-typed on `$formula`/`$family`, so this works on an unfitted `drm_node`
#' spec as well as on a fitted drmTMB object.
#' @keywords internal
#' @noRd
drm_node_vars <- function(fit) {
  resp <- drm_fit_response(fit)
  vars <- resp$vars
  for (cc in drm_fit_components(fit)) {
    vars <- c(vars, drm_fit_component_predictors(fit, cc))
  }
  unique(stats::na.omit(vars))
}

#' Rows of `data` a node will actually be fitted on.
#'
#' drmTMB drops rows with a missing value in any model variable, so a node's
#' realized sample is the complete-case set over `drm_node_vars()`. This is the
#' one place that assumption lives. Columns the node names but `data` does not
#' carry are ignored here -- fitting reports that far better than we can.
#'
#' `exclude` names variables that are imputed rather than dropped: an `mi()`
#' predictor keeps its rows, so counting its NAs would understate the node's
#' realized sample.
#' @return A logical vector of length `nrow(data)`.
#' @keywords internal
#' @noRd
drm_node_rows <- function(fit, data, exclude = character(0)) {
  data <- as.data.frame(data)
  vars <- setdiff(intersect(drm_node_vars(fit), names(data)), exclude)
  if (!length(vars)) {
    return(rep(TRUE, nrow(data)))
  }
  stats::complete.cases(data[, vars, drop = FALSE])
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

#' Distributional components needed for prediction/effect propagation
#'
#' Formula entries record user-modelled components for graph semantics. drmTMB
#' still fits default intercept components such as `sigma`, and samplers need
#' those fitted values even when no `sigma ~ ...` formula was declared.
#' @keywords internal
#' @noRd
drm_fit_prediction_components <- function(fit) {
  unique(c(drm_fit_components(fit), names(fit$coefficients)))
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

#' Bivariate drmTMB family names (joint two-response residual correlation).
#' @keywords internal
#' @noRd
drm_biv_family_names <- function() {
  c("biv_gaussian", "biv_lognormal", "biv_student")
}

#' Is this a joint bivariate drmTMB fit (mu1/mu2/rho12)?
#' @keywords internal
#' @noRd
drm_is_bivariate_fit <- function(fit) {
  fam <- drm_family_name(drm_fit_family(fit))
  if (fam %in% drm_biv_family_names()) {
    return(TRUE)
  }
  comps <- tryCatch(drm_fit_components(fit), error = function(e) character(0))
  any(comps %in% c("mu1", "mu2", "rho12"))
}

#' Response labels of a bivariate fit: c(y1, y2) from the mu1/mu2 entries.
#' @keywords internal
#' @noRd
drm_biv_response_names <- function(fit) {
  entries <- tryCatch(drm_fit_entries(fit), error = function(e) list())
  y1 <- NA_character_
  y2 <- NA_character_
  for (e in entries) {
    if (identical(as.character(e$dpar), "mu1") && !is.null(e$response) &&
      !is.na(e$response)) {
      y1 <- e$response
    }
    if (identical(as.character(e$dpar), "mu2") && !is.null(e$response) &&
      !is.na(e$response)) {
      y2 <- e$response
    }
  }
  c(y1, y2)
}

#' Which margin of a bivariate fit `name` is (1 = mu1, 2 = mu2, NA = neither).
#' @keywords internal
#' @noRd
drm_biv_role <- function(fit, name) {
  ys <- drm_biv_response_names(fit)
  if (!is.na(ys[[1L]]) && identical(name, ys[[1L]])) {
    return(1L)
  }
  if (!is.na(ys[[2L]]) && identical(name, ys[[2L]])) {
    return(2L)
  }
  NA_integer_
}

#' Engine dpars that belong to one margin of a bivariate fit.
#'
#' `rho12` is a pair-level component. Attach it to margin 1 for path extraction
#' so `x -> rho12` appears once; d-separation strips it before the LRT so a
#' claim about y1 does not also test the correlation.
#' @keywords internal
#' @noRd
drm_biv_components_for_role <- function(role, include_rho12 = FALSE) {
  if (identical(role, 1L)) {
    c("mu1", "sigma1", if (isTRUE(include_rho12)) "rho12")
  } else if (identical(role, 2L)) {
    c("mu2", "sigma2")
  } else {
    character(0)
  }
}

#' Wald table for one component: term, estimate, SE, z, p.
#' Isolated here so rho12()/paths() share the dpar:term vcov convention.
#' @keywords internal
#' @noRd
drm_wald_rows <- function(fit, component) {
  empty <- data.frame(
    term = character(0),
    estimate = numeric(0),
    std.error = numeric(0),
    statistic = numeric(0),
    p.value = numeric(0),
    stringsAsFactors = FALSE
  )
  coefs <- drm_fit_coef(fit, component)
  if (!length(coefs)) {
    return(empty)
  }
  V <- drm_fit_vcov(fit)
  rows <- lapply(names(coefs), function(cn) {
    est <- unname(coefs[[cn]])
    key <- paste0(component, ":", cn)
    se <- if (!is.null(V) && key %in% rownames(V)) {
      sqrt(V[key, key])
    } else {
      NA_real_
    }
    z <- est / se
    data.frame(
      term = cn,
      estimate = est,
      std.error = se,
      statistic = z,
      p.value = 2 * stats::pnorm(-abs(z)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' Fitted rho12 coefficients (link / atanh scale) from a bivariate drmTMB fit.
#' @keywords internal
#' @noRd
drm_fit_rho12_coef <- function(fit) {
  drm_wald_rows(fit, "rho12")
}

#' Response- or link-scale residual correlation curve from drmTMB::rho12().
#' @keywords internal
#' @noRd
drm_fit_rho12 <- function(fit, newdata = NULL, type = c("response", "link")) {
  drm_require_drmTMB()
  type <- match.arg(type)
  drmTMB::rho12(fit, newdata = newdata, type = type)
}

#' Fitted correlation-pair table from drmTMB::corpairs().
#' @keywords internal
#' @noRd
drm_fit_corpairs <- function(fit, ...) {
  drm_require_drmTMB()
  ns <- asNamespace("drmTMB")
  if (!exists("corpairs", envir = ns, inherits = FALSE)) {
    return(NULL)
  }
  drmTMB::corpairs(fit, ...)
}

#' Convergence flag for a node
#' @keywords internal
#' @noRd
drm_fit_converged <- function(fit) {
  if (
    requireNamespace("drmTMB", quietly = TRUE) &&
      exists("is_converged", envir = asNamespace("drmTMB"))
  ) {
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
drm_predict_parameters <- function(
  fit,
  newdata,
  dpar = NULL,
  type = c("response", "link"),
  include_newdata = FALSE
) {
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

#' Extract one predicted distributional parameter as a numeric vector
#'
#' `drmTMB::predict_parameters()` has changed shape across versions. In current
#' builds the parameter value lives in an `estimate` column and the original
#' numeric predictors can appear after it. Prefer named/estimate columns and
#' avoid treating numeric `newdata` columns as predictions.
#' @keywords internal
#' @noRd
drm_predict_parameter_values <- function(
  fit,
  newdata,
  dpar,
  type = c("response", "link")
) {
  type <- match.arg(type)
  pp <- as.data.frame(drm_predict_parameters(
    fit,
    newdata = newdata,
    dpar = dpar,
    type = type,
    include_newdata = FALSE
  ))
  drm_prediction_estimate_column(pp, dpar, nrow(newdata), names(newdata))
}

drm_prediction_estimate_column <- function(
  pp,
  dpar,
  n,
  newdata_names = character(0)
) {
  if (
    dpar %in% names(pp) && is.numeric(pp[[dpar]]) && length(pp[[dpar]]) == n
  ) {
    return(as.numeric(pp[[dpar]]))
  }
  if (
    "estimate" %in%
      names(pp) &&
      is.numeric(pp$estimate) &&
      length(pp$estimate) == n
  ) {
    return(as.numeric(pp$estimate))
  }
  numeric_cols <- names(pp)[vapply(pp, is.numeric, logical(1))]
  metadata_cols <- c(
    "row",
    "conf.low",
    "conf.high",
    "std.error",
    "statistic",
    "p.value",
    newdata_names
  )
  candidates <- setdiff(numeric_cols, metadata_cols)
  if (length(candidates)) {
    col <- pp[[candidates[[length(candidates)]]]]
    if (length(col) == n) {
      return(as.numeric(col))
    }
  }
  rep(NA_real_, n)
}

#' Refit a node, adding `add_var` as a fixed-effect predictor to every modelled
#' component. Used by the d-separation engine.
#'
#' @return A fitted `drmTMB` object, or `NULL` if the refit fails.
#' @keywords internal
#' @noRd
drm_refit_augmented <- function(
  fit,
  add_var,
  components = NULL,
  se = TRUE,
  env = parent.frame()
) {
  drm_require_drmTMB()
  ff <- drm_fit_formula(fit)
  calls <- ff$calls
  nms <- ff$names
  if (is.null(nms)) {
    nms <- rep("", length(calls))
  }
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
  # na.action = na.pass is load-bearing, not defensive. model.matrix() otherwise
  # honours getOption("na.action") (na.omit), so a single NA in any predictor
  # returns FEWER rows than newdata. The assignment below then either errors
  # ("number of items to replace is not a multiple of replacement length") or --
  # when the counts happen to divide evenly -- RECYCLES SILENTLY and returns a
  # scrambled design matrix. Passing NAs through keeps the row contract this
  # function documents, and lets incomplete rows surface as NA predictions
  # instead of wrong numbers.
  mm <- tryCatch(
    {
      mf <- stats::model.frame(
        form,
        data = as.data.frame(newdata),
        na.action = stats::na.pass
      )
      stats::model.matrix(form, data = mf)
    },
    error = function(e) NULL
  )
  out <- matrix(
    0,
    nrow = nrow(newdata),
    ncol = length(coef_names),
    dimnames = list(NULL, coef_names)
  )
  if (!is.null(mm)) {
    if (nrow(mm) != nrow(newdata)) {
      cli::cli_abort(c(
        "Design matrix for component {.val {component}} has {nrow(mm)} row{?s} but
         {nrow(newdata)} row{?s} were supplied.",
        "i" = "This should be unreachable now that the model frame passes {.code NA}s
               through; it means a term dropped rows by another route."
      ))
    }
    shared <- intersect(colnames(mm), coef_names)
    out[, shared] <- mm[, shared, drop = FALSE]
  }
  out
}

# ---------------------------------------------------------------------------
# Missing-predictor summaries (A1 / A9).
#
# drmTMB::imputed() return shape lives here. Consumers must branch on
# uncertainty_status, never on is.na(std_error): observed rows and se = FALSE
# requests report NA standard errors with status "ok".
# ---------------------------------------------------------------------------

#' Engine `uncertainty_status` levels (drmTMB 0.7.0).
#' @keywords internal
#' @noRd
drm_imputed_status_levels <- function() {
  c(
    "ok",
    "sdreport_skipped",
    "sdreport_failed",
    "sdreport_non_pd_hessian",
    "sdreport_unavailable",
    "route_conditional_se_unavailable"
  )
}

#' Whether a row's `std_error` is usable.
#'
#' Inspect `uncertainty_status` first. A missing `std_error` with status
#' `"ok"` is an observed row or an `se = FALSE` request, not a failure.
#' @keywords internal
#' @noRd
drm_imputed_std_error_usable <- function(
  uncertainty_status,
  std_error,
  observed
) {
  (uncertainty_status == "ok") & !observed & is.finite(std_error)
}

#' Fitted missing-predictor table from one drmTMB node.
#' @keywords internal
#' @noRd
drm_fit_imputed <- function(fit, variable = NULL, rows = "missing", se = TRUE) {
  drm_require_drmTMB()
  ns <- asNamespace("drmTMB")
  if (!exists("imputed", envir = ns, inherits = FALSE)) {
    cli::cli_abort(c(
      "{.pkg drmTMB} does not export {.fn imputed}.",
      "i" = "Install drmTMB >= 0.6.0."
    ))
  }
  drmTMB::imputed(fit, variable = variable, rows = rows, se = se)
}
