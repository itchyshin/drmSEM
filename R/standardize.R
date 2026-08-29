#' @keywords internal
#' @noRd
NULL

# Distribution-specific theoretical error variance on the latent (link) scale,
# for the latent-variable standardization of a GLM MEAN path (Grace et al. 2018;
# Nakagawa & Schielzeth 2010; piecewiseSEM's `latent.linear`). For a link g, the
# latent response is y* = eta + e with Var(e) fixed by the link's underlying
# threshold distribution: logit -> logistic (pi^2/3), probit -> standard normal
# (1), cloglog -> Gumbel (pi^2/6).
#
# For the log link (Poisson, negative binomial, Gamma, lognormal), the
# observation-level variance on the latent scale is mean-dependent:
# Var(e) ~ log(1 + 1 / mu_bar) by the delta method (Nakagawa & Schielzeth 2010;
# Grace et al. 2018), where mu_bar = mean(exp(eta)).
#
# Identity link has no latent inflation (Var(e) = 0).
drm_link_latent_var <- function(link, eta = NULL, family = NULL) {
  switch(
    link,
    logit = pi^2 / 3,
    probit = 1,
    cloglog = pi^2 / 6,
    log = {
      if (!is.null(eta)) {
        mu_bar <- mean(exp(eta), na.rm = TRUE)
        if (is.finite(mu_bar) && mu_bar > 0) {
          log(1 + 1 / mu_bar)
        } else {
          0
        }
      } else {
        0
      }
    },
    0
  )
}

# Latent-scale standardization divisor for one component's fitted linear
# predictor `eta`. For a MEAN path (`component` starts with "mu") on a
# non-identity link this is sqrt(Var(eta) + theoretical link variance); for every
# other component (and identity-link mu) it is sd(eta) = sqrt(Var(eta)), the
# per-component latent SD on that component's own link scale.
drm_latent_divisor <- function(eta, component, link, family = NULL) {
  ve <- stats::var(eta, na.rm = TRUE)
  lv <- if (startsWith(component, "mu")) {
    drm_link_latent_var(link, eta = eta, family = family)
  } else {
    0
  }
  sqrt(ve + lv)
}

# Identify whether a named data column represents a continuous numeric predictor
# vs a factor, character, logical, or 0/1 binary indicator.
drm_is_continuous_predictor <- function(col, data) {
  if (!(col %in% names(data))) {
    return(FALSE)
  }
  val_col <- data[[col]]
  if (!is.numeric(val_col) || is.factor(val_col) || is.character(val_col) || is.logical(val_col)) {
    return(FALSE)
  }
  clean_val <- stats::na.omit(val_col)
  if (length(unique(clean_val)) <= 2L && all(clean_val %in% c(0, 1))) {
    return(FALSE)
  }
  TRUE
}

#' Standardized component-labelled path coefficients
#'
#' Rescales fitted path coefficients so they are comparable across predictors.
#' Two scalings and two standardization bases are offered, reported on each
#' component's **link scale**:
#'
#' * `"sd_x"` multiplies each coefficient by the standard deviation of its
#'   predictor (or twice the SD under `scale = "2sd"`), giving the link-scale
#'   change in the component per one-SD (or 2-SD) change in the predictor.
#' * `"latent"` additionally divides by the standard deviation of the fitted
#'   linear predictor of that component (incorporating distribution-specific
#'   latent error variance for GLM mean paths), the latent-scale standardization
#'   used for generalized responses (after Grace & Bollen 2005; Grace et al. 2018).
#'
#' @section Conventions & Gelman 2-SD Scaling:
#' See `docs/design/08-standardization.md` for the full rationale and citations.
#'
#' * **Link scale only.** Standardized coefficients are reported on each
#'   component's link scale (the `link` column of [paths()]), where the
#'   linear-predictor algebra is valid. They are *not* back-transformed: under a
#'   nonlinear link a standardized coefficient has no constant response-scale
#'   counterpart. For response-scale, functional interpretations use the effect
#'   engine ([direct_effects()], [total_effects()]) instead.
#' * **Factor and binary predictors (SD = 1).** Categorical factor dummies and
#'   binary 0/1 indicators use a scale multiplier of 1, so their standardized
#'   coefficient reflects the raw per-contrast effect (lavaan's `std.nox`
#'   convention; piecewiseSEM likewise does not SD-rescale categorical
#'   predictors).
#' * **Gelman (2008) 2-SD scaling (`scale = "2sd"`).** Under `scale = "2sd"`,
#'   continuous numeric predictors are scaled by \eqn{2 \times \text{SD}(X)}
#'   while binary and factor predictors retain a scale multiplier of 1. This
#'   places continuous and binary predictors on a directly comparable footing,
#'   as a 2-SD shift in a symmetric continuous variable spans the middle
#'   50--80% of its distribution, corresponding to a 0-to-1 transition.
#' * **Per-component `latent`.** The `latent` divisor is the SD of *that*
#'   component's own linear predictor, so a `sigma` or `zi` path is standardized
#'   on its own (log / logit) link scale — there is no marginal outcome SD for a
#'   non-`mu` component. This per-component latent standardization is drmSEM's
#'   distributional generalization of Grace & Bollen.
#'
#' @section GLM mean paths (Theoretical Link Variance):
#' For a **`mu`** path on a generalized link, the `latent` divisor is
#' \eqn{\sqrt{\text{Var}(\eta) + \sigma_E^2}}, adding the link's
#' distribution-specific latent-scale error variance \eqn{\sigma_E^2}:
#' * Logit: \eqn{\pi^2 / 3 \approx 3.290} (logistic threshold distribution)
#' * Probit: \eqn{1} (standard normal threshold distribution)
#' * Cloglog: \eqn{\pi^2 / 6 \approx 1.645} (Gumbel threshold distribution)
#' * Log: \eqn{\log(1 + 1 / \bar{\mu})} observation-level delta-method variance
#'   where \eqn{\bar{\mu} = \text{mean}(\exp(\eta))} (Nakagawa & Schielzeth 2010;
#'   Grace et al. 2018).
#'
#' Identity links and non-`mu` components are unchanged (the divisor is
#' `sd(eta)` on the component's own link scale).
#'
#' @param object A `drm_sem` or `drm_psem` object.
#' @param method `"sd_x"` or `"latent"`.
#' @param scale `"1sd"` (default 1-SD scaling) or `"2sd"` (Gelman 2008 2-SD scaling).
#' @param ... Unused.
#' @return An object of class `c("drm_standardized_paths", "drm_paths", "data.frame")`
#'   containing the [paths()] table with an added `std.estimate` column (link scale).
#' @references
#' \insertRef{GraceBollen2005}{drmSEM}
#'
#' \insertRef{Grace2008}{drmSEM}
#'
#' \insertRef{Grace2018}{drmSEM}
#'
#' \insertRef{Gelman2008}{drmSEM}
#'
#' \insertRef{Nakagawa2010}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' standardize(sem, method = "latent", scale = "2sd")
#' }
#' @export
standardize <- function(object, method = c("sd_x", "latent"), scale = c("1sd", "2sd"), ...) {
  UseMethod("standardize")
}

#' @rdname standardize
#' @export
standardize.drm_sem <- function(
  object,
  method = c("sd_x", "latent"),
  scale = c("1sd", "2sd"),
  ...
) {
  method <- match.arg(method)
  scale <- match.arg(scale)
  data <- as.data.frame(object$data)
  ptab <- paths(object)
  ptab$std.estimate <- NA_real_

  # Cache linear-predictor SDs per (node, component) for the latent method
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
            link,
            family = rec$family
          )
        }
      }
    }
  }

  for (i in seq_len(nrow(ptab))) {
    var <- ptab$term[[i]]
    # The predictor data column behind a coefficient (factor coefs map back)
    src <- ptab$from[[i]]
    col <- if (src %in% names(data)) src else var

    is_continuous <- drm_is_continuous_predictor(col, data)
    sx <- if (is_continuous) {
      sd_val <- stats::sd(data[[col]], na.rm = TRUE)
      if (identical(scale, "2sd")) 2 * sd_val else sd_val
    } else {
      1
    }

    val <- ptab$estimate[[i]] * sx
    if (identical(method, "latent")) {
      key <- paste(ptab$to[[i]], ptab$component[[i]], sep = "::")
      sy <- lp_sd[[key]]
      if (!is.null(sy) && is.finite(sy) && sy > 0) {
        val <- val / sy
      }
    }
    ptab$std.estimate[[i]] <- val
  }

  attr(ptab, "method") <- method
  attr(ptab, "scale") <- scale
  class(ptab) <- c("drm_standardized_paths", "drm_paths", "data.frame")
  ptab
}

#' @rdname standardize
#' @export
standardize.drm_psem <- function(
  object,
  method = c("sd_x", "latent"),
  scale = c("1sd", "2sd"),
  ...
) {
  standardize.drm_sem(object, method = method, scale = scale, ...)
}

#' @export
print.drm_standardized_paths <- function(x, ...) {
  method <- attr(x, "method")
  scale <- attr(x, "scale")
  header <- if (!is.null(method) && !is.null(scale)) {
    cli::format_inline("<drmSEM standardized paths ({method}, {scale}): {nrow(x)} component-labelled coefficient{?s}>")
  } else {
    cli::format_inline("<drmSEM standardized paths: {nrow(x)} component-labelled coefficient{?s}>")
  }
  cat(header, "\n", sep = "")
  print.data.frame(
    within(as.data.frame(x), {
      estimate <- round(estimate, 4)
      std.error <- round(std.error, 4)
      if ("std.estimate" %in% names(x)) {
        std.estimate <- round(std.estimate, 4)
      }
      statistic <- round(statistic, 3)
      p.value <- signif(p.value, 3)
    }),
    row.names = FALSE,
    right = TRUE,
    digits = 4,
    ...
  )
  invisible(x)
}
