#' @keywords internal
#' @noRd
NULL

# Distribution-specific theoretical error variance on the latent (link) scale,
# for the latent-variable standardization of a GLM MEAN path (Grace et al. 2018;
# piecewiseSEM's `latent.linear`). For a link g, the latent response is
# y* = eta + e with Var(e) fixed by the link's underlying threshold distribution:
# logit -> logistic (pi^2/3), probit -> standard normal (1), cloglog -> Gumbel
# (pi^2/6). identity and log return 0 here: identity has no latent inflation, and
# the log-link families' theoretical variance is mean-dependent (observation
# level), not a constant -- that term is deferred (a tracked refinement).
drm_link_latent_var <- function(link) {
  switch(link, logit = pi^2 / 3, probit = 1, cloglog = pi^2 / 6, 0)
}

# Latent-scale standardization divisor for one component's fitted linear
# predictor `eta`. For a MEAN path (`component` starts with "mu") on a
# non-identity link this is sqrt(Var(eta) + theoretical link variance); for every
# other component (and identity-link mu) it is sd(eta) = sqrt(Var(eta)), the
# per-component latent SD on that component's own link scale.
drm_latent_divisor <- function(eta, component, link) {
  ve <- stats::var(eta, na.rm = TRUE)
  lv <- if (startsWith(component, "mu")) drm_link_latent_var(link) else 0
  sqrt(ve + lv)
}

#' Standardized component-labelled path coefficients
#'
#' Rescales fitted path coefficients so they are comparable across predictors.
#' Two scalings are offered, both reported on the component's **link scale**:
#'
#' * `"sd_x"` multiplies each coefficient by the standard deviation of its
#'   predictor, giving the link-scale change in the component per one-SD change
#'   in the predictor.
#' * `"latent"` additionally divides by the standard deviation of the fitted
#'   linear predictor of that component, the latent-scale standardization used
#'   for generalized responses (after Grace & Bollen 2005).
#'
#' @section Conventions (0.2):
#' These are the finalized standardization conventions; see
#' `docs/design/08-standardization.md` for the full rationale and citations.
#'
#' * **Link scale only.** Standardized coefficients are reported on each
#'   component's link scale (the `link` column of [paths()]), where the
#'   linear-predictor algebra is valid. They are *not* back-transformed: under a
#'   nonlinear link a standardized coefficient has no constant response-scale
#'   counterpart. For response-scale, functional interpretations use the effect
#'   engine ([direct_effects()], [total_effects()]) instead.
#' * **Factor predictors use SD = 1** (no rescaling), so a factor / dummy
#'   coefficient is reported as its raw per-contrast effect (lavaan's `std.nox`
#'   convention; piecewiseSEM likewise does not SD-rescale categorical
#'   predictors). Multiplying a 0/1 dummy by its column SD would produce a
#'   data-dependent value that is not "one SD of a construct"; a Gelman (2008)
#'   2-SD rescaling of the *continuous* predictors for continuous-vs-binary
#'   comparability is planned as an opt-in (OQ-4).
#' * **Per-component `latent`.** The `latent` divisor is the SD of *that*
#'   component's own linear predictor, so a `sigma` or `zi` path is standardized
#'   on its own (log / logit) link scale — there is no marginal outcome SD for a
#'   non-`mu` component. This per-component latent standardization is drmSEM's
#'   distributional generalization of Grace & Bollen.
#'
#' @section GLM mean paths (OQ-4 `sigma_E`):
#' For a **`mu`** path on a link with a *constant* theoretical error variance, the
#' `latent` divisor is `sqrt(Var(eta) + sigma_E^2)`, adding the link's
#' distribution-specific latent-scale error variance (logit `pi^2/3`, probit `1`,
#' cloglog `pi^2/6`; after Grace et al. 2018 / piecewiseSEM's `latent.linear`).
#' This corrects the earlier mild over-standardization of GLM mean paths. The
#' **log-link** families (Poisson, negative binomial, Gamma, lognormal) carry a
#' *mean-dependent* (observation-level) latent variance rather than a constant, so
#' no `sigma_E` term is added there yet — that case is still deferred. Identity
#' links and non-`mu` components are unchanged (the divisor is `sd(eta)` on the
#' component's own link scale).
#'
#' @param object A `drm_sem` object.
#' @param method `"sd_x"` or `"latent"`.
#' @param ... Unused.
#' @return The [paths()] table with an added `std.estimate` column (link scale).
#' @references
#' \insertRef{GraceBollen2005}{drmSEM}
#'
#' \insertRef{Grace2008}{drmSEM}
#'
#' \insertRef{Grace2018}{drmSEM}
#'
#' \insertRef{Gelman2008}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' standardize(sem, method = "latent")
#' }
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
          link <- drm_nominal_link(rec$family, cc)
          lp_sd[[paste(nm, cc, sep = "::")]] <- drm_latent_divisor(
            eta,
            cc,
            link
          )
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
