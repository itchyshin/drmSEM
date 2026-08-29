#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# 0.3 — Latent & MIMIC measurement blocks.
#
# Supports MIMIC (Multiple Indicators, Multiple Causes), reflective (latent factor
# with multiple indicators), and formative (composite) constructs within the
# piecewise SEM paradigm.
#
# Piecewise estimation:
# Measurement structure is estimated from observed indicators (PCA or 1-factor
# analysis with sign alignment and marker/unit-variance identification). Latent
# scores are materialized into the data frame before node fitting, allowing
# structural nodes to use the latent construct as an ordinary predictor or
# response (e.g. eta ~ x1 + x2, y ~ eta, sigma ~ eta). Indicator loadings are
# reported separately by loadings() and never mixed into structural paths().
#
# References:
# Joreskog & Goldberger (1975), Bollen (1989), Raykov (1997), Grace & Bollen (2008).
# ---------------------------------------------------------------------------

#' Declare an observed indicator for a latent construct
#'
#' Specifies an observed indicator variable for a latent construct declared with
#' [drm_latent()].
#'
#' @param name Character string naming an indicator column in the data.
#' @param loading Optional fixed loading value (numeric). If `NULL` (default),
#'   the loading is estimated from data.
#' @param marker Logical. If `TRUE`, this indicator serves as the marker
#'   variable for identification (unit loading constraint: \eqn{\lambda = 1}).
#' @return A `drm_indicator` object.
#' @seealso [drm_latent()], [loadings()].
#' @examples
#' drm_indicator("y1", marker = TRUE)
#' drm_indicator("y2")
#' @export
drm_indicator <- function(name, loading = NULL, marker = FALSE) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }
  if (!is.null(loading) && (!is.numeric(loading) || length(loading) != 1L)) {
    cli::cli_abort("{.arg loading} must be a single numeric value or NULL.")
  }
  if (!is.logical(marker) || length(marker) != 1L) {
    cli::cli_abort("{.arg marker} must be a single logical value.")
  }
  structure(
    list(
      name = name,
      loading = if (!is.null(loading)) as.numeric(loading) else NULL,
      marker = isTRUE(marker)
    ),
    class = "drm_indicator"
  )
}

#' @export
print.drm_indicator <- function(x, ...) {
  mk <- if (isTRUE(x$marker)) " [marker, lambda = 1]" else ""
  ld <- if (!is.null(x$loading)) paste0(" (loading = ", round(x$loading, 4), ")") else ""
  cli::cli_text("<indicator> {x$name}{mk}{ld}")
  invisible(x)
}

#' Cronbach's alpha internal-consistency reliability
#'
#' Computes Cronbach's alpha for a matrix or data frame of observed indicators:
#' \deqn{\alpha = \frac{k}{k - 1} \left(1 - \frac{\sum \sigma_i^2}{\sum \sum \sigma_{ij}}\right)}
#'
#' @param M A numeric matrix or data frame of indicator columns.
#' @return Numeric alpha scalar, or `NA_real_` if \eqn{k < 2} or variance is non-positive.
#' @references
#' \insertRef{Cronbach1951}{drmSEM}
#' @export
drm_cronbach_alpha <- function(M) {
  if (is.data.frame(M)) {
    M <- as.matrix(M)
  }
  k <- ncol(M)
  if (is.null(k) || k < 2L) {
    return(NA_real_)
  }
  cv <- stats::cov(M, use = "pairwise.complete.obs")
  total_var <- sum(cv)
  if (!is.finite(total_var) || total_var <= 0) {
    return(NA_real_)
  }
  (k / (k - 1)) * (1 - sum(diag(cv)) / total_var)
}

#' Composite reliability (Raykov's rho / McDonald's omega)
#'
#' Computes composite reliability (Raykov's rho / McDonald's omega) for a set
#' of congeneric reflective indicators:
#' \deqn{\rho = \frac{(\sum \lambda_i)^2 \text{Var}(\eta)}{(\sum \lambda_i)^2 \text{Var}(\eta) + \sum \theta_i}}
#' where \eqn{\lambda_i} are the unstandardized factor loadings and \eqn{\theta_i}
#' are the indicator error (unique) variances.
#'
#' @param M A numeric matrix or data frame of indicators (rows = observations,
#'   cols = indicators).
#' @param loadings Optional named numeric vector of indicator loadings.
#' @param error_variances Optional named numeric vector of unique error variances.
#' @param factor_var Variance of the latent construct (default 1.0).
#' @return Numeric composite reliability scalar in \[0, 1\] (or `NA_real_` if not
#'   computable).
#' @references
#' \insertRef{Raykov1997}{drmSEM}
#'
#' \insertRef{McDonald1999}{drmSEM}
#' @export
drm_raykov_rho <- function(M, loadings = NULL, error_variances = NULL, factor_var = 1.0) {
  if (is.data.frame(M)) {
    M <- as.matrix(M)
  }
  k <- ncol(M)
  if (is.null(k) || k < 2L) {
    return(NA_real_)
  }
  S <- stats::cov(M, use = "pairwise.complete.obs")
  if (!all(is.finite(S))) {
    return(NA_real_)
  }
  if (is.null(loadings) || is.null(error_variances)) {
    ev <- eigen(S, symmetric = TRUE)
    if (ev$values[1L] <= 0) {
      return(NA_real_)
    }
    loadings <- ev$vectors[, 1L] * sqrt(ev$values[1L])
    if (loadings[which.max(abs(loadings))] < 0) {
      loadings <- -loadings
    }
    error_variances <- pmax(diag(S) - loadings^2, 1e-6)
    factor_var <- 1.0
  }
  sum_lam <- sum(loadings)
  sum_theta <- sum(error_variances)
  num <- (sum_lam^2) * factor_var
  denom <- num + sum_theta
  if (!is.finite(denom) || denom <= 0) {
    return(NA_real_)
  }
  rho <- num / denom
  pmin(pmax(rho, 0), 1)
}

#' Declare a latent construct (MIMIC, reflective, or formative)
#'
#' Declares a latent construct within the piecewise SEM framework.
#' Supports MIMIC (Multiple Indicators, Multiple Causes), reflective (latent factor
#' with multiple indicators), and formative (composite) constructs.
#'
#' In piecewise SEM, measurement equations and structural causes are estimated
#' piece-by-piece with sign-alignment and marker/unit-variance identification.
#' Latent scores are materialized into `data` before fitting, allowing structural
#' nodes to use the latent construct as an ordinary predictor or response in any
#' [drm_node()] formula. Indicator loadings are reported by [loadings()] and kept
#' strictly separate from structural [paths()].
#'
#' @param name Name of the latent construct column to create.
#' @param indicators Character vector of indicator column names (length >= 2), or a
#'   list of [drm_indicator()] declarations.
#' @param causes Optional character vector of structural cause variables for
#'   MIMIC constructs.
#' @param type Type of construct: `"mimic"` (default; causes -> latent -> indicators),
#'   `"reflective"` (latent -> indicators), or `"formative"` (indicators -> construct).
#' @param identification Identification constraint: `"marker"` (unit loading on
#'   marker indicator, \eqn{\lambda_{\text{marker}} = 1}) or `"unit_variance"`
#'   (\eqn{\text{Var}(\eta) = 1}). Defaults to `"marker"`.
#' @param marker Optional name of the marker indicator for `"marker"` identification
#'   (defaults to the indicator with `marker = TRUE` or the first indicator).
#' @param method Measurement estimation method: `"pca"` (first principal component /
#'   factor score), `"fa"` (1-factor analysis), or `"fixed"` (user weights).
#' @param weights Optional numeric weights for `method = "fixed"`.
#' @param data Optional data frame containing indicator and cause columns. If provided,
#'   measurement structure and loadings are estimated immediately.
#' @param standardize Logical. If `TRUE`, materialized latent score is standardized
#'   (mean 0, sd 1). Default `FALSE`.
#' @return A `drm_latent` declaration object (inheriting from `drm_composite`).
#' @seealso [drm_indicator()], [drm_composite()], [loadings()], [drm_sem()].
#' @references
#' \insertRef{JoreskogGoldberger1975}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#'
#' \insertRef{Raykov1997}{drmSEM}
#'
#' \insertRef{Grace2008}{drmSEM}
#' @examples
#' dat <- data.frame(
#'   x1 = rnorm(50), x2 = rnorm(50),
#'   y1 = rnorm(50), y2 = rnorm(50), y3 = rnorm(50)
#' )
#' # MIMIC construct with marker identification:
#' lat <- drm_latent("size", indicators = c("y1", "y2", "y3"), causes = c("x1", "x2"), data = dat)
#' print(lat)
#' @export
drm_latent <- function(
  name,
  indicators,
  causes = NULL,
  type = c("mimic", "reflective", "formative"),
  identification = c("marker", "unit_variance"),
  marker = NULL,
  method = c("pca", "fa", "fixed"),
  weights = NULL,
  data = NULL,
  standardize = FALSE
) {
  type <- match.arg(type)
  identification <- match.arg(identification)
  method <- match.arg(method)

  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    cli::cli_abort("{.arg name} must be a single non-empty string.")
  }

  # Parse indicators argument (character vector or list of drm_indicator objects)
  ind_names <- character(0)
  ind_specs <- list()
  marker_from_spec <- NULL

  if (is.character(indicators)) {
    ind_names <- indicators
    ind_specs <- lapply(indicators, function(ind) drm_indicator(ind))
    names(ind_specs) <- ind_names
  } else if (is.list(indicators)) {
    for (item in indicators) {
      if (inherits(item, "drm_indicator")) {
        ind_names <- c(ind_names, item$name)
        ind_specs[[item$name]] <- item
        if (isTRUE(item$marker)) {
          marker_from_spec <- item$name
        }
      } else if (is.character(item) && length(item) == 1L) {
        ind_names <- c(ind_names, item)
        ind_specs[[item]] <- drm_indicator(item)
      } else {
        cli::cli_abort("{.arg indicators} must be a character vector or list of {.fn drm_indicator} objects.")
      }
    }
  } else {
    cli::cli_abort("{.arg indicators} must be a character vector or list of {.fn drm_indicator} objects.")
  }

  if (length(ind_names) < 2L) {
    cli::cli_abort("{.arg indicators} must name at least two indicator columns.")
  }
  if (anyDuplicated(ind_names)) {
    cli::cli_abort("Indicator names must be unique; duplicated: {.val {ind_names[duplicated(ind_names)]}}.")
  }

  # Identification marker setup
  marker_name <- if (!is.null(marker)) {
    if (!marker %in% ind_names) {
      cli::cli_abort("Marker indicator {.val {marker}} is not among declared indicators {.val {ind_names}}.")
    }
    marker
  } else if (!is.null(marker_from_spec)) {
    marker_from_spec
  } else {
    ind_names[[1L]]
  }

  # Causes setup
  cause_names <- if (!is.null(causes)) as.character(causes) else character(0)

  spec <- list(
    name = name,
    indicators = ind_names,
    indicator_specs = ind_specs,
    causes = cause_names,
    type = type,
    identification = identification,
    marker = marker_name,
    method = method,
    weights = weights,
    loadings = NULL,
    std_loadings = NULL,
    error_variances = NULL,
    scale = (method %in% c("pca", "fa")),
    prop_var = NA_real_,
    standardize = isTRUE(standardize),
    reliability = NA_real_,
    composite_reliability = NA_real_
  )
  class(spec) <- c("drm_latent", "drm_composite")

  if (!is.null(data)) {
    spec <- drm_resolve_latent(spec, data)
  }

  spec
}

#' Resolve and compute latent loadings and reliabilities from data
#' @keywords internal
#' @noRd
drm_resolve_latent <- function(spec, data) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  miss <- setdiff(spec$indicators, names(data))
  if (length(miss)) {
    cli::cli_abort("Indicator column{?s} not found in {.arg data}: {.val {miss}}.")
  }
  num <- vapply(spec$indicators, function(v) is.numeric(data[[v]]), logical(1))
  if (!all(num)) {
    cli::cli_abort("All indicators must be numeric; not: {.val {spec$indicators[!num]}}.")
  }

  M <- as.matrix(data[, spec$indicators, drop = FALSE])
  k <- ncol(M)

  if (identical(spec$method, "fixed")) {
    w <- if (is.null(spec$weights)) {
      rep(1 / k, k)
    } else {
      spec$weights
    }
    if (length(w) != k) {
      cli::cli_abort("{.arg weights} must have one value per indicator ({k}).")
    }
    loadings <- stats::setNames(as.numeric(w), spec$indicators)
    std_loadings <- loadings
    err_var <- stats::setNames(rep(0, k), spec$indicators)
    prop_var <- NA_real_
    rel <- drm_cronbach_alpha(M)
    comp_rel <- rel
    pc_center <- NULL
    pc_scale <- NULL
    raw_score <- as.numeric(M %*% loadings[spec$indicators])
    if (isTRUE(spec$standardize)) {
      mu_s <- mean(raw_score, na.rm = TRUE)
      sd_s <- stats::sd(raw_score, na.rm = TRUE)
      scoring_weights <- loadings / sd_s
      scoring_intercept <- -mu_s / sd_s
    } else {
      scoring_weights <- loadings
      scoring_intercept <- 0
    }
  } else {
    # PCA / FA extraction
    pc <- stats::prcomp(M, center = TRUE, scale. = TRUE)
    score_raw <- pc$x[, 1L]
    load_rot <- pc$rotation[, 1L]

    # Sign alignment: positive orientation with marker indicator
    marker_col <- M[, spec$marker]
    if (stats::cor(score_raw, marker_col, use = "pairwise.complete.obs") < 0) {
      score_raw <- -score_raw
      load_rot <- -load_rot
    }
    pc_center <- pc$center
    pc_scale <- pc$scale
    w_raw <- load_rot / pc_scale
    c_raw <- -sum(load_rot * pc_center / pc_scale)

    if (identical(spec$identification, "marker")) {
      # Unit loading on marker indicator: slope of ym on score_raw = 1
      cov_m <- stats::cov(marker_col, score_raw, use = "pairwise.complete.obs")
      var_s <- stats::var(score_raw, na.rm = TRUE)
      slope <- cov_m / var_s
      score_identified <- score_raw * slope
      var_eta <- stats::var(score_identified, na.rm = TRUE)

      loadings_vec <- vapply(spec$indicators, function(ind) {
        stats::cov(M[, ind], score_identified, use = "pairwise.complete.obs") / var_eta
      }, numeric(1))
      names(loadings_vec) <- spec$indicators

      std_loadings_vec <- vapply(spec$indicators, function(ind) {
        stats::cor(M[, ind], score_identified, use = "pairwise.complete.obs")
      }, numeric(1))
      names(std_loadings_vec) <- spec$indicators

      err_var <- vapply(spec$indicators, function(ind) {
        pmax(stats::var(M[, ind], na.rm = TRUE) - (loadings_vec[[ind]]^2) * var_eta, 1e-6)
      }, numeric(1))
      names(err_var) <- spec$indicators

      prop_var <- (pc$sdev^2 / sum(pc$sdev^2))[1L]
      rel <- drm_cronbach_alpha(M)
      comp_rel <- drm_raykov_rho(M, loadings = loadings_vec, error_variances = err_var, factor_var = var_eta)
      w_id <- w_raw * slope
      c_id <- c_raw * slope

    } else {
      # Unit variance identification: Var(eta) = 1
      score_identified <- as.numeric(scale(score_raw))
      loadings_vec <- vapply(spec$indicators, function(ind) {
        stats::cov(M[, ind], score_identified, use = "pairwise.complete.obs")
      }, numeric(1))
      names(loadings_vec) <- spec$indicators

      std_loadings_vec <- vapply(spec$indicators, function(ind) {
        stats::cor(M[, ind], score_identified, use = "pairwise.complete.obs")
      }, numeric(1))
      names(std_loadings_vec) <- spec$indicators

      err_var <- vapply(spec$indicators, function(ind) {
        pmax(stats::var(M[, ind], na.rm = TRUE) - loadings_vec[[ind]]^2, 1e-6)
      }, numeric(1))
      names(err_var) <- spec$indicators

      prop_var <- (pc$sdev^2 / sum(pc$sdev^2))[1L]
      rel <- drm_cronbach_alpha(M)
      comp_rel <- drm_raykov_rho(M, loadings = loadings_vec, error_variances = err_var, factor_var = 1.0)
      mu_s <- mean(score_raw, na.rm = TRUE)
      sd_s <- stats::sd(score_raw, na.rm = TRUE)
      w_id <- w_raw / sd_s
      c_id <- (c_raw - mu_s) / sd_s
    }

    if (isTRUE(spec$standardize)) {
      score_id_vec <- as.numeric(M %*% w_id + c_id)
      mu_id <- mean(score_id_vec, na.rm = TRUE)
      sd_id <- stats::sd(score_id_vec, na.rm = TRUE)
      scoring_weights <- w_id / sd_id
      scoring_intercept <- (c_id - mu_id) / sd_id
    } else {
      scoring_weights <- w_id
      scoring_intercept <- c_id
    }

    loadings <- loadings_vec
    std_loadings <- std_loadings_vec
  }

  spec$loadings <- loadings
  spec$std_loadings <- std_loadings
  spec$error_variances <- err_var
  spec$prop_var <- prop_var
  spec$reliability <- rel
  spec$composite_reliability <- comp_rel
  spec$center <- pc_center
  spec$scale_sd <- pc_scale
  spec$scoring_weights <- scoring_weights
  spec$scoring_intercept <- scoring_intercept
  spec
}

#' Score a latent construct on a dataset
#' @keywords internal
#' @noRd
drm_score_latent <- function(spec, data) {
  if (is.null(spec$loadings)) {
    spec <- drm_resolve_latent(spec, data)
  }
  miss <- setdiff(spec$indicators, names(data))
  if (length(miss)) {
    cli::cli_abort("Latent construct {.val {spec$name}}: indicator{?s} {.val {miss}} missing from data.")
  }
  M <- as.matrix(data[, spec$indicators, drop = FALSE])

  if (!is.null(spec$scoring_weights) && !is.null(spec$scoring_intercept)) {
    as.numeric(M %*% spec$scoring_weights[spec$indicators] + spec$scoring_intercept)
  } else {
    if (identical(spec$method, "fixed")) {
      score <- as.numeric(M %*% spec$loadings[spec$indicators])
    } else {
      pc <- stats::prcomp(M, center = TRUE, scale. = TRUE)
      score_raw <- pc$x[, 1L]
      marker_col <- M[, spec$marker]
      if (stats::cor(score_raw, marker_col, use = "pairwise.complete.obs") < 0) {
        score_raw <- -score_raw
      }
      if (identical(spec$identification, "marker")) {
        cov_m <- stats::cov(marker_col, score_raw, use = "pairwise.complete.obs")
        var_s <- stats::var(score_raw, na.rm = TRUE)
        slope <- cov_m / var_s
        score <- score_raw * slope
      } else {
        score <- as.numeric(scale(score_raw))
      }
    }

    if (isTRUE(spec$standardize)) {
      score <- as.numeric(scale(score))
    }
    score
  }
}

#' Normalize and resolve a list of latent constructs
#' @keywords internal
#' @noRd
drm_build_latent_constructs <- function(latents, data = NULL) {
  if (is.null(latents)) {
    return(list())
  }
  if (inherits(latents, "drm_latent") || inherits(latents, "drm_composite")) {
    latents <- list(latents)
  }
  if (!is.list(latents)) {
    cli::cli_abort("{.arg latents} must be a {.fn drm_latent} declaration or list of them.")
  }
  # Filter to latent/composite objects
  lat_objs <- list()
  for (item in latents) {
    if (inherits(item, "drm_latent") || inherits(item, "drm_composite")) {
      if (!is.null(data) && inherits(item, "drm_latent") && is.null(item$loadings)) {
        item <- drm_resolve_latent(item, data)
      }
      lat_objs[[length(lat_objs) + 1L]] <- item
    }
  }
  nms <- vapply(lat_objs, function(c) c$name, character(1))
  if (anyDuplicated(nms)) {
    cli::cli_abort(
      "Latent construct names must be unique; duplicated: {.val {nms[duplicated(nms)]}}."
    )
  }
  lat_objs
}

#' Materialize latent construct scores into data frame
#' @keywords internal
#' @noRd
drm_apply_latents <- function(data, latents) {
  specs <- drm_build_latent_constructs(latents, data = data)
  for (spec in specs) {
    if (!spec$name %in% names(data)) {
      data[[spec$name]] <- drm_score_latent(spec, data)
    }
  }
  data
}

#' @export
print.drm_latent <- function(x, ...) {
  cli::cli_text(
    "<latent construct: {x$type}> {x$name} (identification: {x$identification}) = {paste(x$indicators, collapse = ', ')}"
  )
  if (length(x$causes)) {
    cli::cli_text("  structural causes: {paste(x$causes, collapse = ', ')}")
  }
  if (!is.na(x$composite_reliability)) {
    cli::cli_text("  composite reliability (Raykov's rho): {round(x$composite_reliability, 3)}")
  }
  if (!is.na(x$reliability)) {
    cli::cli_text("  Cronbach's alpha: {round(x$reliability, 3)}")
  }
  if (isTRUE(x$standardize)) {
    cli::cli_text("  score standardized (mean 0, sd 1)")
  }
  invisible(x)
}

#' @export
summary.drm_latent <- function(object, ...) {
  cli::cli_text(
    "<latent construct: {object$type}> {.strong {object$name}} (identification: {object$identification})"
  )
  if (length(object$causes)) {
    cli::cli_text("Structural causes: {paste(object$causes, collapse = ', ')}")
  }
  if (!is.null(object$loadings)) {
    ld <- data.frame(
      indicator = object$indicators,
      loading = round(as.numeric(object$loadings[object$indicators]), 4),
      stringsAsFactors = FALSE
    )
    if (!is.null(object$std_loadings)) {
      ld$std_loading <- round(as.numeric(object$std_loadings[object$indicators]), 4)
    }
    print(ld, row.names = FALSE)
  }
  if (!is.na(object$composite_reliability)) {
    cli::cli_text(
      "Composite reliability (Raykov's rho): {round(object$composite_reliability, 3)}"
    )
  }
  if (!is.na(object$reliability)) {
    cli::cli_text(
      "Reliability (Cronbach's alpha): {round(object$reliability, 3)}"
    )
  }
  invisible(object)
}

# ---------------------------------------------------------------------------
# Marginalised latent declarations (`latent =`) for MAG m-separation.
# ---------------------------------------------------------------------------

#' Normalize a `latent =` argument to a character vector of graph vertex names.
#'
#' @param latent `NULL`, a character vector, or a single name.
#' @param dag_vertices All vertex names present on the structural DAG.
#' @return Character vector (possibly empty).
#' @keywords internal
#' @noRd
drm_build_latents <- function(latent, dag_vertices) {
  if (is.null(latent)) {
    return(character(0))
  }
  latent <- as.character(latent)
  if (length(latent) == 1L && !nzchar(latent[[1L]])) {
    return(character(0))
  }
  if (anyDuplicated(latent)) {
    cli::cli_abort(
      "Marginalised latent names must be unique; duplicated: {.val {latent[duplicated(latent)]}}."
    )
  }
  miss <- setdiff(latent, dag_vertices)
  if (length(miss)) {
    cli::cli_abort(c(
      "Marginalised latent{?s} not found in the structural graph: {.val {miss}}.",
      "i" = "Latent names must appear on at least one directed edge in the DAG
             (as an exogenous vertex) before marginalisation."
    ))
  }
  latent
}

#' Inform once that MAG m-separation assumes a compositional graphoid when families
#' or sigma paths break homoscedastic Gaussianity (guardrail 3).
#' @keywords internal
#' @noRd
drm_mag_compositionality_inform <- function(object) {
  if (!length(object$latents)) {
    return(invisible(NULL))
  }
  flagged <- FALSE
  for (nm in object$endogenous) {
    rec <- object$records[[nm]]
    if (!identical(rec$family, "gaussian")) {
      flagged <- TRUE
      break
    }
    if ("sigma" %in% rec$components) {
      flagged <- TRUE
      break
    }
  }
  if (!flagged) {
    return(invisible(NULL))
  }
  cli::cli_inform(c(
    "i" = "MAG m-separation claims are licensed under a compositional graphoid
           (Sadeghi & Lauritzen 2014 Thm 3; Lauritzen & Sadeghi 2018 Thm 4).",
    "i" = "That holds automatically for homoscedastic all-Gaussian models and under
           faithfulness otherwise; it is not guaranteed for non-Gaussian nodes or
           location-scale ({.code sigma ~}) paths. See {.file docs/design/14-m-separation.md}."
  ))
  invisible(NULL)
}
