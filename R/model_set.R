#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# Phase 2: phylopath-style confirmatory model comparison.
#
# A `drm_dag` is an unfitted candidate causal model: a set of node formulas.
# A `drm_model_set` is a named collection of competing `drm_dag`s. `compare()`
# fits each candidate with drm_sem(), runs the existing dsep()/fisher_c()
# machinery, and ranks the candidates by CICc by default (a
# small-sample-corrected information criterion built on Fisher's C), reporting
# deltas and weights -- mirroring phylopath's define_model_set()/phylo_path()/
# best()/average() workflow but with drmTMB families and component-labelled
# paths. A CBIC criterion is also available when the user wants a stronger
# penalty for extra paths.
#
# Construction (drm_dag/drm_model_set) and the criterion/weight arithmetic are
# pure base R and need no engine; every drmTMB-touching step lives inside
# compare()/best()/average() so the package loads without drmTMB installed.
# ---------------------------------------------------------------------------

# The response label of a captured node formula, used as the node name.
# Works on a plain formula or a drmTMB::bf()/drm_formula object (the latter
# carries the response on the mu formula's LHS). Falls back to all.vars().
drm_dag_response <- function(f) {
  # plain formula: response is the LHS
  if (inherits(f, "formula")) {
    if (length(f) < 3L) {
      cli::cli_abort(
        "Each {.fn drm_dag} formula needs a response: {.code response ~ predictors}."
      )
    }
    lhs <- f[[2L]]
    vars <- all.vars(lhs)
    if (length(vars) == 0L) {
      cli::cli_abort("Could not read a response from a {.fn drm_dag} formula.")
    }
    return(vars[[1L]])
  }
  # drmTMB::bf() / drm_formula: prefer the recorded mu response, else the
  # first entry's LHS variable.
  if (inherits(f, "drm_formula") && !is.null(f$entries)) {
    for (e in f$entries) {
      if (
        identical(as.character(e$dpar), "mu") &&
          !is.null(e$response) &&
          !is.na(e$response)
      ) {
        v <- all.vars(e$lhs)
        if (length(v)) return(v[[1L]])
      }
    }
    for (e in f$entries) {
      if (!is.null(e$lhs)) {
        v <- all.vars(e$lhs)
        if (length(v)) return(v[[1L]])
      }
    }
  }
  # last resort: deparse + all.vars on the object
  v <- all.vars(f)
  if (length(v)) {
    return(v[[1L]])
  }
  cli::cli_abort("Could not determine the response of a {.fn drm_dag} formula.")
}

#' Specify a candidate causal model (an unfitted DAG)
#'
#' `drm_dag()` captures a set of node formulas as one candidate causal model in
#' a confirmatory model set, without fitting anything. Each argument is a node:
#' a plain `response ~ predictors` formula, or a [drmTMB::bf()] /
#' [drmTMB::drm_formula()] for a distributional node (so a candidate may posit
#' arrows into `sigma`, `zi`, `hu`, ... as well as the mean). The response of
#' each formula names the node. Models are fitted later by [compare()].
#'
#' @param ... One formula per endogenous node. A bare `response ~ predictors`
#'   formula, or a [drmTMB::bf()] object for distributional parts. The node name
#'   is taken from the response.
#'
#' @return A `drm_dag` object: a list of captured node formulas.
#' @seealso [drm_model_set()], [compare()].
#' @export
#'
#' @examples
#' \dontrun{
#' # mean-only candidate
#' drm_dag(size ~ temp, fitness ~ size + temp)
#' # distributional candidate: temp also drives residual scale of size
#' drm_dag(drmTMB::bf(size ~ temp, sigma ~ temp), fitness ~ size)
#' }
drm_dag <- function(...) {
  formulas <- list(...)
  if (length(formulas) == 0L) {
    cli::cli_abort("A {.fn drm_dag} needs at least one node formula.")
  }
  ok <- vapply(
    formulas,
    function(f) inherits(f, "formula") || inherits(f, "drm_formula"),
    logical(1)
  )
  if (!all(ok)) {
    cli::cli_abort(c(
      "Every argument to {.fn drm_dag} must be a formula or a {.fn drmTMB::bf} object.",
      "x" = "Offending argument{?s}: {.val {which(!ok)}}."
    ))
  }
  responses <- vapply(formulas, drm_dag_response, character(1))
  if (anyDuplicated(responses)) {
    dup <- responses[duplicated(responses)]
    cli::cli_abort(c(
      "Each node (response) in a {.fn drm_dag} must be unique.",
      "x" = "Repeated response{?s}: {.val {unique(dup)}}."
    ))
  }
  names(formulas) <- responses
  structure(
    list(formulas = formulas, responses = responses),
    class = "drm_dag"
  )
}

#' @export
print.drm_dag <- function(x, ...) {
  cli::cli_text("<drm_dag> {length(x$formulas)} node{?s}: {.val {x$responses}}")
  for (nm in names(x$formulas)) {
    f <- x$formulas[[nm]]
    obj <- if (inherits(f, "formula")) {
      f
    } else if (!is.null(f$formula)) {
      f$formula
    } else {
      f
    }
    txt <- paste(deparse(obj), collapse = " ")
    cli::cli_text("  {.strong {nm}}: {txt}")
  }
  invisible(x)
}

#' Assemble a set of candidate causal models
#'
#' `drm_model_set()` collects named [drm_dag()] candidates into one comparison
#' set, the unit [compare()] operates on. This is drmSEM's analogue of
#' phylopath's `define_model_set()`.
#'
#' @param ... Named [drm_dag()] objects, one per candidate model.
#'
#' @return A `drm_model_set` object.
#' @seealso [drm_dag()], [compare()], [best()], [average()].
#' @export
#'
#' @examples
#' \dontrun{
#' models <- drm_model_set(
#'   direct   = drm_dag(fitness ~ temp + size),
#'   mediated = drm_dag(size ~ temp, fitness ~ size + temp)
#' )
#' models
#' }
drm_model_set <- function(...) {
  dags <- list(...)
  if (length(dags) == 0L) {
    cli::cli_abort("A {.fn drm_model_set} needs at least one {.fn drm_dag}.")
  }
  if (!all(vapply(dags, inherits, logical(1), what = "drm_dag"))) {
    cli::cli_abort(
      "Every argument to {.fn drm_model_set} must be a {.fn drm_dag}."
    )
  }
  if (is.null(names(dags)) || any(!nzchar(names(dags)))) {
    cli::cli_abort("Every candidate in a {.fn drm_model_set} must be named.")
  }
  if (anyDuplicated(names(dags))) {
    cli::cli_abort("Model names in a {.fn drm_model_set} must be unique.")
  }
  structure(list(models = dags), class = "drm_model_set")
}

#' @export
print.drm_model_set <- function(x, ...) {
  cli::cli_h1("drmSEM candidate model set")
  cli::cli_text("{length(x$models)} candidate model{?s}")
  for (nm in names(x$models)) {
    dag <- x$models[[nm]]
    cli::cli_text("{.strong {nm}}: node{?s} {.val {dag$responses}}")
  }
  cli::cli_text("Fit and rank with {.fn compare}.")
  invisible(x)
}

# Turn one captured node formula into a drm_node, applying the right family.
# `family` may be NULL (use drm_node default), a single family object shared by
# all nodes, or a named list keyed by node/response.
drm_dag_node <- function(formula, response, family) {
  fam <- NULL
  if (is.null(family)) {
    fam <- NULL
  } else if (
    is.list(family) && !is.null(names(family)) && !inherits(family, "family")
  ) {
    # a named per-node list of families
    if (response %in% names(family)) {
      fam <- family[[response]]
    } else {
      fam <- NULL
    }
  } else {
    # a single shared family object
    fam <- family
  }
  if (is.null(fam)) {
    drm_node(formula)
  } else {
    drm_node(formula, family = fam)
  }
}

# Fit one drm_dag candidate into a drm_sem, in the supplied environment so any
# structured-effect objects (e.g. a phylo `tree`) resolve like drm_sem() does.
drm_fit_dag <- function(dag, data, family, fit_env, dots) {
  nodes <- vector("list", length(dag$formulas))
  for (i in seq_along(dag$formulas)) {
    resp <- dag$responses[[i]]
    nodes[[i]] <- drm_dag_node(dag$formulas[[i]], resp, family)
  }
  names(nodes) <- dag$responses
  call_args <- c(nodes, list(data = data), dots)
  # Evaluate drm_sem() in fit_env so structured-effect markers resolve.
  do.call(drm_sem, call_args, envir = fit_env)
}

#' Fit and rank a set of candidate causal models
#'
#' `compare()` fits every candidate [drm_dag()] in a [drm_model_set()] with
#' [drm_sem()] (one node per response, using a per-node or shared `family`),
#' runs [dsep()]/[fisher_c()] on each, and ranks the candidates by an
#' information criterion built on Fisher's C. This is drmSEM's analogue of
#' phylopath's `phylo_path()`.
#'
#' The default ranking statistic is
#' \deqn{\mathrm{CICc} = C + 2k\,\frac{n}{n - k - 1},}
#' where \eqn{C} is Fisher's C statistic from the model's d-separation test,
#' \eqn{k} is the number of estimated fixed-effect coefficients across all
#' nodes (counted via [paths()]), and \eqn{n} is the number of observations.
#' \eqn{\Delta}CICc is the difference from the best (lowest-CICc) model and the
#' CICc weight is \eqn{\exp(-\tfrac12\,\Delta\mathrm{CICc})}, normalised to sum
#' to one. As \eqn{n \to \infty} the correction term tends to \eqn{2k}, so CICc
#' reduces to the usual \eqn{C + 2k}. `criterion = "CBIC"` instead ranks by
#' \eqn{\mathrm{CBIC} = C + k\log(n)}, a BIC-style penalty that is more
#' conservative about extra paths.
#'
#' @param object A `drm_model_set`.
#' @param data A data frame supplied to every node fit.
#' @param family Optional. A single `drmTMB` family applied to every node, or a
#'   named list of families keyed by node (response) name. `NULL` uses the
#'   [drm_node()] default (Gaussian) for every node.
#' @param criterion Ranking criterion. `"CICc"` keeps the phylopath-style
#'   default; `"CBIC"` uses a BIC-style penalty for stronger parsimony.
#' @param ... Further arguments passed on to each [drm_sem()] fit.
#'
#' @return A `drm_compare` object: a data frame with one row per candidate and
#'   columns `model`, `fisher_c`, `df`, `p.value`, `k`, `n`, `CICc`, `dCICc`,
#'   `wCICc`, `CBIC`, `dCBIC`, `wCBIC`, and `weight`, sorted by the selected
#'   `criterion`. `weight` is the weight for the selected criterion, so
#'   [average()] follows the same ranking rule. The fitted `drm_sem` objects and
#'   per-model d-separation tables are carried in attributes for
#'   [best()]/[average()].
#' @seealso [best()], [average()], [drm_model_set()].
#' @export
#'
#' @examples
#' \dontrun{
#' models <- drm_model_set(
#'   direct   = drm_dag(fitness ~ temp + size),
#'   mediated = drm_dag(size ~ temp, fitness ~ size + temp)
#' )
#' cmp <- compare(models, data = dat,
#'                family = list(size = stats::gaussian(),
#'                              fitness = stats::gaussian()))
#' cmp
#' best(cmp)
#' average(cmp)
#' }
compare <- function(
  object,
  data,
  family = NULL,
  criterion = c("CICc", "CBIC"),
  ...
) {
  UseMethod("compare")
}

#' @rdname compare
#' @export
compare.drm_model_set <- function(
  object,
  data,
  family = NULL,
  criterion = c("CICc", "CBIC"),
  ...
) {
  drm_require_drmTMB()
  if (missing(data)) {
    cli::cli_abort("{.arg data} is required for {.fn compare}.")
  }
  criterion <- match.arg(criterion)
  fit_env <- parent.frame()
  dots <- list(...)
  data <- as.data.frame(data)
  n <- nrow(data)

  model_names <- names(object$models)
  fits <- vector("list", length(model_names))
  dseps <- vector("list", length(model_names))
  names(fits) <- model_names
  names(dseps) <- model_names

  C <- numeric(length(model_names))
  fdf <- integer(length(model_names))
  pval <- numeric(length(model_names))
  k <- integer(length(model_names))

  for (i in seq_along(model_names)) {
    nm <- model_names[[i]]
    cli::cli_progress_step("Fitting candidate {.val {nm}}")
    sem <- drm_fit_dag(
      object$models[[i]],
      data = data,
      family = family,
      fit_env = fit_env,
      dots = dots
    )
    d <- dsep(sem)
    fc <- fisher_c(d)
    fits[[i]] <- sem
    dseps[[i]] <- d
    C[[i]] <- fc$fisher_c
    fdf[[i]] <- as.integer(fc$df)
    pval[[i]] <- fc$p.value
    # k = number of estimated fixed-effect coefficients across all nodes.
    k[[i]] <- nrow(paths(sem))
  }

  tab <- data.frame(
    model = model_names,
    fisher_c = C,
    df = fdf,
    p.value = pval,
    k = as.integer(k),
    n = rep.int(n, length(model_names)),
    stringsAsFactors = FALSE
  )
  tab <- drm_add_cicc(tab, criterion = criterion)
  attr(tab, "fits") <- fits
  attr(tab, "dsep") <- dseps
  attr(tab, "n") <- n
  attr(tab, "criterion") <- criterion
  class(tab) <- c("drm_compare", "data.frame")
  tab
}

# Pure-arithmetic core: given a data.frame carrying fisher_c (C), k and n,
# add CICc/CBIC, deltas and normalised weights, sorted ascending by the selected
# criterion.
# Factored out so the model-selection arithmetic is testable without an engine.
#
# CICc = C + 2 * k * (n / (n - k - 1)).
drm_add_cicc <- function(tab, criterion = c("CICc", "CBIC")) {
  criterion <- match.arg(criterion)
  C <- tab$fisher_c
  k <- tab$k
  n <- tab$n
  denom <- n - k - 1
  correction <- ifelse(denom > 0, n / denom, NA_real_)
  tab$CICc <- C + 2 * k * correction
  tab$CBIC <- C + k * log(n)

  cicc <- drm_delta_weights(tab$CICc)
  tab$dCICc <- cicc$delta
  tab$wCICc <- cicc$weight

  cbic <- drm_delta_weights(tab$CBIC)
  tab$dCBIC <- cbic$delta
  tab$wCBIC <- cbic$weight

  weight_col <- paste0("w", criterion)
  tab$weight <- tab[[weight_col]]
  preferred <- c(
    "model",
    "fisher_c",
    "df",
    "p.value",
    "k",
    "n",
    "CICc",
    "dCICc",
    "wCICc",
    "CBIC",
    "dCBIC",
    "wCBIC",
    "weight"
  )
  tab <- tab[,
    c(intersect(preferred, names(tab)), setdiff(names(tab), preferred)),
    drop = FALSE
  ]
  ord <- order(tab[[criterion]], na.last = TRUE)
  tab <- tab[ord, , drop = FALSE]
  attr(tab, "criterion") <- criterion
  rownames(tab) <- NULL
  tab
}

drm_delta_weights <- function(score) {
  finite <- is.finite(score)
  delta <- rep(NA_real_, length(score))
  weight <- rep(0, length(score))
  if (any(finite)) {
    delta[finite] <- score[finite] - min(score[finite])
    rel <- exp(-0.5 * delta[finite])
    total <- sum(rel)
    if (total > 0) {
      weight[finite] <- rel / total
    }
  }
  list(delta = delta, weight = weight)
}

drm_compare_criterion <- function(x) {
  criterion <- attr(x, "criterion", exact = TRUE)
  if (is.null(criterion) || !criterion %in% c("CICc", "CBIC")) {
    criterion <- "CICc"
  }
  criterion
}

#' @export
print.drm_compare <- function(x, ...) {
  cli::cli_text("<drmSEM model comparison: {nrow(x)} candidate{?s}>")
  criterion <- drm_compare_criterion(x)
  df <- as.data.frame(x)
  df$fisher_c <- round(df$fisher_c, 2)
  df$p.value <- signif(df$p.value, 3)
  df$CICc <- round(df$CICc, 2)
  df$dCICc <- round(df$dCICc, 2)
  df$wCICc <- round(df$wCICc, 3)
  df$CBIC <- round(df$CBIC, 2)
  df$dCBIC <- round(df$dCBIC, 2)
  df$wCBIC <- round(df$wCBIC, 3)
  df$weight <- round(df$weight, 3)
  print.data.frame(df, row.names = FALSE)
  top <- df$model[[which.min(x[[criterion]])]]
  cli::cli_text(
    "Best model by {criterion}: {.strong {top}}. Use {.fn best}/{.fn average}."
  )
  invisible(x)
}

# Resolve a comparison object (compute it from a model set if needed).
drm_as_compare <- function(object, ...) {
  if (inherits(object, "drm_compare")) {
    return(object)
  }
  if (inherits(object, "drm_model_set")) {
    return(compare(object, ...))
  }
  cli::cli_abort(
    "Expected a {.cls drm_compare} or {.cls drm_model_set} object."
  )
}

#' Best-supported candidate model
#'
#' `best()` returns the fitted [drm_sem] of the top-ranked candidate under the
#' criterion used by [compare()].
#'
#' @param object A `drm_compare` (from [compare()]) or a `drm_model_set`.
#' @param ... Passed to [compare()] when `object` is an unfitted model set
#'   (e.g. `data`, `family`).
#'
#' @return The fitted `drm_sem` of the top-ranked candidate.
#' @seealso [compare()], [average()].
#' @export
#'
#' @examples
#' \dontrun{
#' best(cmp)
#' }
best <- function(object, ...) {
  UseMethod("best")
}

#' @rdname best
#' @export
best.drm_model_set <- function(object, ...) {
  best(compare(object, ...))
}

#' @rdname best
#' @export
best.drm_compare <- function(object, ...) {
  fits <- attr(object, "fits")
  if (is.null(fits)) {
    cli::cli_abort("This comparison carries no fitted models.")
  }
  criterion <- drm_compare_criterion(object)
  top <- object$model[[which.min(object[[criterion]])]]
  fit <- fits[[top]]
  if (is.null(fit)) {
    cli::cli_abort("Could not recover the fitted model for {.val {top}}.")
  }
  fit
}

#' Criterion-weighted average of standardized path coefficients
#'
#' `average()` returns model-averaged standardized path coefficients across the
#' candidate set, weighting each model's [standardize()]d [paths()] by the
#' selected criterion's weight (`CICc` by default, or `CBIC` when
#' `compare(..., criterion = "CBIC")` was used). Coefficients are matched on
#' `from`, `to` and `component`, so a path present in only some candidates is
#' averaged over the weight of the models that contain it (conditional
#' averaging). This mirrors phylopath's `average()`.
#'
#' @param object A `drm_compare` (from [compare()]) or a `drm_model_set`.
#' @param method Standardization passed to [standardize()] (`"sd_x"` or
#'   `"latent"`).
#' @param ... Passed to [compare()] when `object` is an unfitted model set.
#'
#' @return A data frame of averaged standardized paths with columns `from`,
#'   `to`, `component`, `std.estimate` (weighted mean) and `weight_sum` (total
#'   weight of the models containing that path).
#' @seealso [compare()], [best()], [standardize()].
#' @export
#'
#' @examples
#' \dontrun{
#' average(cmp)
#' }
average <- function(object, ...) {
  UseMethod("average")
}

#' @rdname average
#' @export
average.drm_model_set <- function(object, ...) {
  average(compare(object, ...))
}

#' @rdname average
#' @param method Standardization passed to [standardize()].
#' @export
average.drm_compare <- function(object, method = c("sd_x", "latent"), ...) {
  method <- match.arg(method)
  fits <- attr(object, "fits")
  if (is.null(fits)) {
    cli::cli_abort("This comparison carries no fitted models.")
  }
  weights <- stats::setNames(object$weight, object$model)

  acc <- list() # key -> list(from,to,component, wsum, wxsum)
  for (nm in object$model) {
    w <- weights[[nm]]
    if (!is.finite(w) || w <= 0) {
      next
    }
    fit <- fits[[nm]]
    if (is.null(fit)) {
      next
    }
    std <- standardize(fit, method = method)
    if (nrow(std) == 0L) {
      next
    }
    for (j in seq_len(nrow(std))) {
      key <- paste(std$from[[j]], std$to[[j]], std$component[[j]], sep = "\r")
      val <- std$std.estimate[[j]]
      if (!is.finite(val)) {
        next
      }
      cur <- acc[[key]]
      if (is.null(cur)) {
        acc[[key]] <- list(
          from = std$from[[j]],
          to = std$to[[j]],
          component = std$component[[j]],
          wsum = w,
          wxsum = w * val
        )
      } else {
        cur$wsum <- cur$wsum + w
        cur$wxsum <- cur$wxsum + w * val
        acc[[key]] <- cur
      }
    }
  }

  if (length(acc) == 0L) {
    out <- data.frame(
      from = character(0),
      to = character(0),
      component = character(0),
      std.estimate = numeric(0),
      weight_sum = numeric(0),
      stringsAsFactors = FALSE
    )
    class(out) <- c("drm_average", "data.frame")
    return(out)
  }

  out <- do.call(
    rbind,
    lapply(acc, function(e) {
      data.frame(
        from = e$from,
        to = e$to,
        component = e$component,
        std.estimate = e$wxsum / e$wsum,
        weight_sum = e$wsum,
        stringsAsFactors = FALSE
      )
    })
  )
  rownames(out) <- NULL
  out <- out[order(out$to, out$component, out$from), , drop = FALSE]
  rownames(out) <- NULL
  class(out) <- c("drm_average", "data.frame")
  out
}

#' @export
print.drm_average <- function(x, ...) {
  cli::cli_text(
    "<drmSEM model-averaged standardized paths: {nrow(x)} path{?s}>"
  )
  df <- as.data.frame(x)
  df$std.estimate <- round(df$std.estimate, 4)
  df$weight_sum <- round(df$weight_sum, 3)
  print.data.frame(df, row.names = FALSE)
  invisible(x)
}
