#' @keywords internal
#' @noRd
NULL

# Families drmSEM has realized-value samplers for (distribution-mediated effects
# are fully supported only for these). Others fall back to mean propagation.
drm_supported_sampler_families <- function() {
  # This vector is ADVISORY -- its only consumer is check_sem()'s `sampler`
  # column. The load-bearing list is the switch() in drm_sample_family(), so
  # widening this one alone would make check_sem() LIE about a family that still
  # mean-falls-back. test-recovery-samplers.R locks the two together by asserting
  # that every family named here actually draws, and that an unnamed one warns.
  #
  # zero_one_beta is listed: its continuous (beta) part is drmTMB-confirmed and
  # it degrades to a plain beta draw when zoi/coi are absent (the zoi/coi
  # inflation mapping is the only unconfirmed piece; see drm_sample_family).
  #
  # binomial and beta_binomial are listed but are conditional: they need
  # `trials`, and without it drm_sample_family() warns and falls back rather
  # than returning a probability where a count is required.
  c(
    "gaussian",
    "student",
    "skew_normal",
    "lognormal",
    "Gamma",
    "gamma",
    "poisson",
    "nbinom2",
    "truncated_nbinom2",
    "beta",
    "zero_one_beta",
    "tweedie",
    "binomial",
    "beta_binomial"
  )
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
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' check_sem(sem)
#' }
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
      nobs = drm_fit_nobs(rec$fit),
      converged = conv,
      vcov_available = !is.null(V),
      # Report against the EFFECTIVE family: a hurdle node's family name is
      # truncated_nbinom2, but it is drawn by its own model_type branch. Keying the
      # column on the bare name would have reported TRUE for the wrong reason before
      # the hurdle branch existed, and would report it for the wrong reason still.
      sampler = drm_effective_family(rec$family, drm_fit_model_type(rec$fit)) %in%
        c(drm_supported_sampler_families(), drm_model_type_samplers()),
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
  if (length(exo)) {
    cli::cli_text("Exogenous variables: {.val {exo}}")
  }
  if (any(!x$converged %in% TRUE)) {
    cli::cli_warn(
      "One or more nodes did not converge; effects and d-separation may be unreliable."
    )
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
  if (length(unique(stats::na.omit(x$nobs))) > 1L) {
    cli::cli_warn(c(
      "Nodes were fitted on different numbers of observations.",
      "i" = "Path coefficients then come from different samples. Refit with
             {.code na_action = \"common\"} in {.fn drm_sem} to use one shared
             complete-case set."
    ))
  }
  invisible(x)
}
