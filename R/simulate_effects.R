#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# Simulation kernels for effect propagation.
#
# The engine propagates a do()-style intervention through the DAG in
# topological order. Each node turns its predictors into response-scale
# distributional parameters (own linear predictor + inverse link, random
# effects held at zero), then either passes its expected mean downstream
# (mean-mediated) or a realized draw from its family (distribution-mediated).
# The numeric kernels below are pure and unit-tested without drmTMB; the
# drmTMB-specific glue is `drm_engines_from_sem()` via the adapter.
# ---------------------------------------------------------------------------

#' Inverse link
#' @keywords internal
#' @noRd
drm_inv_link <- function(link, eta) {
  switch(
    link,
    identity = eta,
    log = exp(eta),
    logit = stats::plogis(eta),
    tanh = tanh(eta),
    eta
  )
}

#' Draw realized values from a node's family given response-scale parameters
#'
#' `params` is a data frame/list with at least `mu`; optional `sigma`, `nu`,
#' `zi`, `hu`, `trials`. Implemented for the common drmTMB families; unsupported
#' families fall back to the mean (with a single warning per call).
#' @keywords internal
#' @noRd
drm_sample_family <- function(family, params, n) {
  mu <- params$mu
  sigma <- if (!is.null(params$sigma)) params$sigma else rep(1, n)
  zi <- if (!is.null(params$zi)) params$zi else rep(0, n)
  base <- switch(
    family,
    gaussian = stats::rnorm(n, mean = mu, sd = sigma),
    student = mu + sigma * stats::rt(n, df = pmax(params$nu %||% 5, 2.1)),
    lognormal = stats::rlnorm(n, meanlog = log(pmax(mu, 1e-8)), sdlog = sigma),
    Gamma = stats::rgamma(n, shape = 1 / pmax(sigma^2, 1e-8),
                          rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)),
    gamma = stats::rgamma(n, shape = 1 / pmax(sigma^2, 1e-8),
                          rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)),
    poisson = stats::rpois(n, lambda = pmax(mu, 0)),
    # drmTMB's `sigma` is an SD-like scale: the nbinom2 size (theta) is 1/sigma^2
    # (so var = mu + mu^2 * sigma^2), and the beta precision is 1/sigma^2.
    # Confirmed against drmTMB fits in test-oq1-samplers.R (OQ-1).
    nbinom2 = stats::rnbinom(n, mu = pmax(mu, 0),
                             size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8)),
    truncated_nbinom2 = pmax(1, stats::rnbinom(n, mu = pmax(mu, 0),
                                               size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8))),
    beta = {
      phi <- 1 / pmax(sigma, 1e-3)^2
      stats::rbeta(n, shape1 = mu * phi, shape2 = (1 - mu) * phi)
    },
    {
      drm_warn_once(paste0("family-sampler-", family),
        cli::format_inline("No realized-value sampler for family {.val {family}}; using its mean."))
      mu
    }
  )
  # zero-inflation: with probability zi the structural zero replaces the draw
  if (any(zi > 0)) {
    is_zero <- stats::runif(n) < zi
    base[is_zero] <- 0
  }
  base
}

`%||%` <- function(a, b) if (is.null(a)) b else a

drm_warn_once_env <- new.env(parent = emptyenv())
drm_warn_once <- function(key, msg) {
  if (is.null(drm_warn_once_env[[key]])) {
    drm_warn_once_env[[key]] <- TRUE
    cli::cli_warn(msg)
  }
  invisible(NULL)
}

# Build a per-node prediction engine list for an object. Each engine exposes a
# predict() that returns a data frame of response-scale components.
drm_engines_from_sem <- function(object) {
  engines <- vector("list", length(object$order))
  names(engines) <- object$order
  for (nm in object$order) {
    rec <- object$records[[nm]]
    fit <- rec$fit
    family <- rec$family
    comps <- rec$components
    coef_list <- stats::setNames(lapply(comps, function(cc) drm_fit_coef(fit, cc)), comps)
    links <- stats::setNames(vapply(comps, function(cc) drm_nominal_link(family, cc), character(1)), comps)
    V <- drm_fit_vcov(fit)
    ident <- if (rec$response_label %in% names(object$data)) {
      rec$response_label
    } else if (length(rec$response_vars) == 1L) {
      rec$response_vars[[1L]]
    } else {
      nm
    }
    local({
      fit_l <- fit; comps_l <- comps; coef_l <- coef_list; links_l <- links
      predict_fn <- function(scenario, beta = NULL) {
        out <- data.frame(.row = seq_len(nrow(scenario)))
        for (cc in comps_l) {
          X <- drm_fixed_design(fit_l, cc, scenario)
          b <- if (!is.null(beta) && !is.null(beta[[cc]])) beta[[cc]] else coef_l[[cc]]
          eta <- if (ncol(X) == 0L) rep(0, nrow(scenario)) else as.numeric(X %*% b)
          out[[cc]] <- drm_inv_link(links_l[[cc]], eta)
        }
        out$.row <- NULL
        out
      }
      engines[[nm]] <<- list(
        name = nm, identifier = ident, family = family, components = comps_l,
        links = links_l, coef = coef_l, vcov = V, predict = predict_fn
      )
    })
  }
  engines
}

# Draw a coefficient set per component from MVN(coef, vcov); MLE if draw=FALSE
# or covariance unavailable.
drm_draw_beta <- function(engine, draw = TRUE) {
  if (!isTRUE(draw) || is.null(engine$vcov)) {
    return(engine$coef)
  }
  V <- engine$vcov
  out <- engine$coef
  for (cc in engine$components) {
    co <- engine$coef[[cc]]
    if (length(co) == 0L) next
    keys <- paste0(cc, ":", names(co))
    if (all(keys %in% rownames(V))) {
      Vb <- V[keys, keys, drop = FALSE]
      # A node whose Hessian was not positive-definite yields NaN/Inf standard
      # errors (drmTMB warns "NaNs produced" from TMB::sdreport). Drawing from
      # such a covariance would poison the effect with NaNs, so for that
      # component fall back to the point estimate (already in `out[[cc]]`).
      if (all(is.finite(Vb))) {
        out[[cc]] <- stats::setNames(
          as.numeric(MASS::mvrnorm(1, mu = co, Sigma = Vb)), names(co)
        )
      }
    }
  }
  out
}

# Propagate an intervention scenario through the engines (topological order).
# `active` is the set of mediator node names allowed to feed their computed
# value downstream; inactive nodes keep their scenario column values.
# Returns a list with `mean` (per-node response-scale mean vector) and `work`.
drm_propagate <- function(engines, scenario, active, mediation = "mean",
                          beta_list = NULL) {
  work <- as.data.frame(scenario)
  node_mean <- list()
  for (eng in engines) {
    preds <- eng$predict(work, beta = beta_list[[eng$name]])
    node_mean[[eng$name]] <- preds$mu
    if (eng$name %in% active) {
      val <- if (identical(mediation, "distribution")) {
        drm_sample_family(eng$family, preds, n = nrow(work))
      } else {
        preds$mu
      }
      work[[eng$identifier]] <- val
    }
  }
  list(mean = node_mean, work = work)
}

# Expected response-scale mean of `to` under a scenario, averaging over inner
# realizations when mediation == "distribution".
drm_expected_target <- function(engines, scenario, to, active, mediation,
                                 beta_list, n_sim = 1L) {
  if (identical(mediation, "distribution") && n_sim > 1L) {
    acc <- numeric(nrow(scenario))
    for (s in seq_len(n_sim)) {
      acc <- acc + drm_propagate(engines, scenario, active, mediation, beta_list)$mean[[to]]
    }
    acc / n_sim
  } else {
    drm_propagate(engines, scenario, active, mediation, beta_list)$mean[[to]]
  }
}
