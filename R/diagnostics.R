#' @keywords internal
#' @noRd
NULL

# Families drmSEM has realized-value samplers for (distribution-mediated effects
# are fully supported only for these). Others fall back to mean propagation.
drm_supported_sampler_families <- function() {
  # zero_one_beta is listed: its continuous (beta) part is drmTMB-confirmed and it
  # degrades to a plain beta draw when zoi/coi are absent (the zoi/coi inflation
  # mapping is the only unconfirmed piece; see drm_sample_family). tweedie is
  # deliberately omitted -- it has no realized-value sampler and falls back to mean.
  c("gaussian", "student", "lognormal", "Gamma", "gamma", "poisson",
    "nbinom2", "truncated_nbinom2", "beta", "zero_one_beta")
}

#' Diagnose a fitted distributional SEM
#'
#' Reports, per node, the family, modelled components, convergence, whether a
#' fixed-effect covariance is available (needed for Wald intervals,
#' d-separation refits, and effect uncertainty), and whether a realized-value
#' sampler exists (needed for distribution-mediated effects). Also lists
#' exogenous variables and warns about anything that will silently degrade a
#' downstream computation.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame of per-node diagnostics (class `drm_diagnostics`).
#' @export
check_sem <- function(object, ...) {
  UseMethod("check_sem")
}

#' @rdname check_sem
#' @export
check_sem.drm_sem <- function(object, ...) {
  rows <- list()
  for (nm in object$order) {
    rec <- object$records[[nm]]
    conv <- drm_fit_converged(rec$fit)
    V <- drm_fit_vcov(rec$fit)
    rows[[length(rows) + 1L]] <- data.frame(
      node = nm,
      family = rec$family,
      components = paste(rec$components, collapse = ", "),
      converged = conv,
      vcov_available = !is.null(V),
      sampler = rec$family %in% drm_supported_sampler_families(),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "exogenous") <- object$exogenous
  class(out) <- c("drm_diagnostics", "data.frame")
  out
}

#' @export
print.drm_diagnostics <- function(x, ...) {
  cli::cli_h2("drmSEM diagnostics")
  print.data.frame(as.data.frame(x), row.names = FALSE)
  exo <- attr(x, "exogenous")
  if (length(exo)) cli::cli_text("Exogenous variables: {.val {exo}}")
  if (any(!x$converged %in% TRUE)) {
    cli::cli_warn("One or more nodes did not converge; effects and d-separation may be unreliable.")
  }
  if (any(!x$vcov_available)) {
    cli::cli_warn(c(
      "One or more nodes lack a fixed-effect covariance.",
      "i" = "Refit with {.code control = drmTMB::drm_control(se = TRUE)} for Wald intervals, d-separation, and effect uncertainty."
    ))
  }
  if (any(!x$sampler)) {
    cli::cli_inform(c(
      "i" = "Some node families have no realized-value sampler; their distribution-mediated effects fall back to mean propagation."
    ))
  }
  invisible(x)
}
