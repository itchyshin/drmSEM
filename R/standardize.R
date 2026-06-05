#' @keywords internal
#' @noRd
NULL

#' Standardized component-labelled path coefficients
#'
#' Rescales fitted path coefficients so they are comparable across predictors.
#' Two scalings are offered, both reported on the component's link scale:
#'
#' * `"sd_x"` multiplies each coefficient by the standard deviation of its
#'   predictor, giving the link-scale change in the component per one-SD change
#'   in the predictor.
#' * `"latent"` additionally divides by the standard deviation of the fitted
#'   linear predictor of that component, the latent-scale standardization used
#'   for generalized responses (after Grace & Bollen).
#'
#' @param object A `drm_sem` object.
#' @param method `"sd_x"` or `"latent"`.
#' @param ... Unused.
#' @return The [paths()] table with an added `std.estimate` column.
#' @export
standardize <- function(object, method = c("sd_x", "latent"), ...) {
  UseMethod("standardize")
}

#' @rdname standardize
#' @export
standardize.drm_sem <- function(object, method = c("sd_x", "latent"), ...) {
  method <- match.arg(method)
  data <- as.data.frame(object$data)
  ptab <- paths(object)
  ptab$std.estimate <- NA_real_

  # cache linear-predictor SDs per (node, component) for the latent method
  lp_sd <- list()
  if (identical(method, "latent")) {
    for (nm in object$order) {
      rec <- object$records[[nm]]
      for (cc in rec$components) {
        X <- drm_fixed_design(rec$fit, cc, data)
        b <- drm_fit_coef(rec$fit, cc)
        if (ncol(X) && length(b)) {
          eta <- as.numeric(X %*% b[colnames(X)])
          lp_sd[[paste(nm, cc, sep = "::")]] <- stats::sd(eta, na.rm = TRUE)
        }
      }
    }
  }

  for (i in seq_len(nrow(ptab))) {
    var <- ptab$term[[i]]
    # the predictor data column behind a coefficient (factor coefs map back)
    src <- ptab$from[[i]]
    col <- if (src %in% names(data)) src else var
    sx <- if (col %in% names(data) && is.numeric(data[[col]])) {
      stats::sd(data[[col]], na.rm = TRUE)
    } else {
      1
    }
    val <- ptab$estimate[[i]] * sx
    if (identical(method, "latent")) {
      key <- paste(ptab$to[[i]], ptab$component[[i]], sep = "::")
      sy <- lp_sd[[key]]
      if (!is.null(sy) && is.finite(sy) && sy > 0) val <- val / sy
    }
    ptab$std.estimate[[i]] <- val
  }
  ptab
}
