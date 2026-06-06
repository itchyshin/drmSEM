#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# 0.3 — composite latent constructs.
#
# A composite construct is a deterministic function of observed indicator
# columns, computed BEFORE any fit (a weighted sum or a principal-component
# index). Once materialized it is an ordinary observed column: a node formula
# can use it as a predictor or response, and paths()/dsep()/effects treat it
# like any other variable. drmSEM records the construct's loadings so they can be
# reported by loadings(), kept separate from the structural paths() exactly as
# covariance edges are.
#
# This is the FORMATIVE / composite case (indicators -> construct), which is
# pure-R: no joint likelihood, no engine change. REFLECTIVE latent constructs (a
# latent common cause with a measurement model) need a joint measurement
# likelihood drmTMB does not provide piecewise, and are deferred to 0.4 / lavaan
# interop. See docs/design/09-latent-variables.md.
# ---------------------------------------------------------------------------

#' Declare a composite construct from observed indicators
#'
#' A composite construct is a deterministic index built from two or more observed
#' indicator columns and materialized as a single column *before* fitting, so it
#' can be used as an ordinary predictor or response in a node formula. With
#' `method = "fixed"` the construct is a weighted sum of the (raw) indicators;
#' with `method = "pca"` it is the first principal-component score of the scaled
#' indicators. The indicator loadings are recorded and reported by [loadings()].
#'
#' This is the *formative / composite* construct (indicators define the
#' construct), which stays fully within drmSEM's piecewise, likelihood-based core.
#' *Reflective* latent variables (a latent common cause estimated through a
#' measurement model) require a joint likelihood drmTMB does not fit piecewise and
#' are out of scope here; see `docs/design/09-latent-variables.md`.
#'
#' @param name Name of the construct column to create. Must not collide with an
#'   existing data column or node name.
#' @param indicators Character vector (length >= 2) of numeric indicator columns
#'   present in `data`.
#' @param weights Optional numeric weights for `method = "fixed"` (defaults to
#'   equal weights `1/k`). Ignored for `method = "pca"`.
#' @param method `"fixed"` (weighted sum of raw indicators) or `"pca"` (first
#'   principal-component score of the scaled indicators).
#' @param data A data frame containing the `indicators` (used to validate them
#'   and, for `"pca"`, to derive the loadings).
#' @return A `drm_composite` declaration object.
#' @seealso [loadings()], [drm_sem()].
#' @examples
#' dat <- data.frame(len = rnorm(50), mass = rnorm(50), wing = rnorm(50))
#' # equal-weighted index of three indicators:
#' drm_composite("body_size", c("len", "mass", "wing"), data = dat)
#' # first principal-component index instead:
#' drm_composite("body_size", c("len", "mass", "wing"), method = "pca", data = dat)
#' @export
drm_composite <- function(name, indicators, weights = NULL,
                          method = c("fixed", "pca"), data) {
  method <- match.arg(method)
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }
  if (!is.character(indicators) || length(indicators) < 2L) {
    cli::cli_abort("{.arg indicators} must name at least two indicator columns.")
  }
  if (missing(data) || !is.data.frame(data)) {
    cli::cli_abort("{.arg data} (a data frame holding the indicators) is required.")
  }
  miss <- setdiff(indicators, names(data))
  if (length(miss)) {
    cli::cli_abort("Indicator column{?s} not found in {.arg data}: {.val {miss}}.")
  }
  num <- vapply(indicators, function(v) is.numeric(data[[v]]), logical(1))
  if (!all(num)) {
    cli::cli_abort("All indicators must be numeric; not: {.val {indicators[!num]}}.")
  }
  M <- as.matrix(data[, indicators, drop = FALSE])

  if (identical(method, "fixed")) {
    w <- if (is.null(weights)) rep(1 / length(indicators), length(indicators)) else weights
    if (length(w) != length(indicators)) {
      cli::cli_abort("{.arg weights} must have one value per indicator ({length(indicators)}).")
    }
    loadings <- stats::setNames(as.numeric(w), indicators)
    scale_indicators <- FALSE
    prop_var <- NA_real_
  } else {
    pc <- stats::prcomp(M, center = TRUE, scale. = TRUE)
    load1 <- pc$rotation[, 1L]
    # sign convention: the largest-magnitude loading is positive, so the score
    # points the intuitive way and is reproducible.
    if (load1[which.max(abs(load1))] < 0) load1 <- -load1
    loadings <- stats::setNames(as.numeric(load1), indicators)
    scale_indicators <- TRUE
    prop_var <- (pc$sdev^2 / sum(pc$sdev^2))[1L]
  }

  out <- list(
    name = name, indicators = indicators, method = method,
    loadings = loadings, scale = scale_indicators, prop_var = prop_var
  )
  class(out) <- "drm_composite"
  out
}

#' @export
print.drm_composite <- function(x, ...) {
  cli::cli_text("<composite construct> {x$name} = {x$method}({paste(x$indicators, collapse = ', ')})")
  if (!is.na(x$prop_var)) {
    cli::cli_text("  first-PC proportion of variance: {round(x$prop_var, 3)}")
  }
  invisible(x)
}

# Score a composite spec on a (possibly new) data frame. Recomputing from the
# fitting data via the stored loadings guarantees the materialized column and the
# reported loadings are consistent.
drm_score_composite <- function(spec, data) {
  miss <- setdiff(spec$indicators, names(data))
  if (length(miss)) {
    cli::cli_abort("Composite {.val {spec$name}}: indicator{?s} {.val {miss}} missing from data.")
  }
  M <- as.matrix(data[, spec$indicators, drop = FALSE])
  if (isTRUE(spec$scale)) M <- scale(M)
  as.numeric(M %*% spec$loadings[spec$indicators])
}

# Normalize a composites argument (NULL / one drm_composite / list) to a list,
# validating that names are distinct and do not collide with each other.
drm_build_composites <- function(composites) {
  if (is.null(composites)) {
    return(list())
  }
  if (inherits(composites, "drm_composite")) {
    composites <- list(composites)
  }
  if (!is.list(composites) ||
      !all(vapply(composites, inherits, logical(1), what = "drm_composite"))) {
    cli::cli_abort(c(
      "{.arg composites} must be {.fn drm_composite} declaration(s).",
      "i" = "Use {.code composites = drm_composite(...)} or a list of them."
    ))
  }
  nms <- vapply(composites, function(c) c$name, character(1))
  if (anyDuplicated(nms)) {
    cli::cli_abort("Composite names must be unique; duplicated: {.val {nms[duplicated(nms)]}}.")
  }
  composites
}

# Materialize composite columns into `data` (used by drm_sem before fitting).
drm_apply_composites <- function(data, composites) {
  comps <- drm_build_composites(composites)
  for (spec in comps) {
    if (spec$name %in% names(data)) {
      cli::cli_abort("Composite {.val {spec$name}} collides with an existing data column.")
    }
    data[[spec$name]] <- drm_score_composite(spec, data)
  }
  data
}

#' Indicator loadings of a SEM's composite constructs
#'
#' Returns the indicator-to-construct loadings for every composite declared with
#' [drm_composite()], reported separately from the structural [paths()] (a
#' composite's measurement structure is not a causal path). Empty if the SEM has
#' no composites.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A `drm_loadings` data frame with columns `composite`, `indicator`,
#'   `loading`, `method`.
#' @seealso [drm_composite()], [paths()].
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   fitness = drm_node(drmTMB::bf(fitness ~ body_size), family = stats::gaussian()),
#'   data = dat,
#'   composites = drm_composite("body_size", c("len", "mass"), data = dat))
#' loadings(sem)
#' }
#' @export
loadings <- function(object, ...) {
  UseMethod("loadings")
}

#' @rdname loadings
#' @export
loadings.drm_sem <- function(object, ...) {
  comps <- object$composites
  empty <- data.frame(composite = character(0), indicator = character(0),
                      loading = numeric(0), method = character(0),
                      stringsAsFactors = FALSE)
  if (is.null(comps) || length(comps) == 0L) {
    out <- empty
  } else {
    rows <- lapply(comps, function(spec) {
      data.frame(composite = spec$name, indicator = spec$indicators,
                 loading = as.numeric(spec$loadings[spec$indicators]),
                 method = spec$method, stringsAsFactors = FALSE)
    })
    out <- do.call(rbind, rows)
  }
  rownames(out) <- NULL
  class(out) <- c("drm_loadings", "data.frame")
  out
}

#' @export
print.drm_loadings <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<drmSEM composite loadings: none>")
    return(invisible(x))
  }
  cli::cli_text("<drmSEM composite loadings: {length(unique(x$composite))} construct{?s}>")
  df <- as.data.frame(x)
  df$loading <- round(df$loading, 4)
  print.data.frame(df, row.names = FALSE)
  invisible(x)
}
