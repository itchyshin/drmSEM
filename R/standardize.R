#' @keywords internal
#' @noRd
NULL

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
#' @section Known limitation:
#' For non-identity-link **`mu`** paths the `latent` divisor currently uses
#' `sd(eta)` alone and omits the distribution-specific theoretical error variance
#' (e.g. `pi^2/3` for a logit link, after Grace et al. 2019 / piecewiseSEM's
#' `latent.linear`), so GLM mean paths are mildly over-standardized. Adding that
#' term is a tracked refinement (OQ-4) that needs a live-fit cross-check before it
#' is changed.
#'
#' @param object A `drm_sem` object.
#' @param method `"sd_x"` or `"latent"`.
#' @param ... Unused.
#' @return The [paths()] table with an added `std.estimate` column (link scale).
#' @references
#' Grace JB, Bollen KA (2005). Interpreting the results from multiple regression
#' and structural equation models. *Bull. Ecol. Soc. Am.* 86(4):283-295.
#'
#' Grace JB et al. (2018). Integrating the causes of biodiversity into structural
#' equation models. *Ecosphere* (latent-theoretic standardization for GLM
#' outcomes). Gelman A (2008). Scaling regression inputs by dividing by two
#' standard deviations. *Stat. Med.* 27:2865-2873.
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
