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
    lognormal = stats::rlnorm(n, meanlog = mu, sdlog = sigma),
    Gamma = stats::rgamma(n, shape = 1 / pmax(sigma^2, 1e-8),
                          rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)),
    gamma = stats::rgamma(n, shape = 1 / pmax(sigma^2, 1e-8),
                          rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)),
    poisson = stats::rpois(n, lambda = pmax(mu, 0)),
    # drmTMB's `sigma` is treated as an SD-like scale: the nbinom2 size (theta) is
    # 1/sigma^2 (so var = mu + mu^2 * sigma^2), and the beta precision is 1/sigma^2.
    # V-57..V-60 assert these moments against drmTMB::simulate().
    nbinom2 = stats::rnbinom(n, mu = pmax(mu, 0),
                             size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8)),
    truncated_nbinom2 = pmax(1, stats::rnbinom(n, mu = pmax(mu, 0),
                                               size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8))),
    beta = {
      phi <- 1 / pmax(sigma, 1e-3)^2
      stats::rbeta(n, shape1 = mu * phi, shape2 = (1 - mu) * phi)
    },
    # zero_one_beta (ordered / zero-one-inflated beta). The continuous part is
    # the same beta as `beta` above (phi = 1/sigma^2; shapes mu*phi,(1-mu)*phi).
    # The inflation part follows the standard ZOIB parameterization: `zoi` is P(observation is
    # a boundary 0/1), and `coi` is P(value == 1 | boundary). When zoi/coi are
    # not supplied (a mediator that only carries mu/sigma), this degenerates to
    # the plain beta draw. The zoi/coi-on-logit mapping is NOT yet confirmed
    # against a live drmTMB fit, so the OQ-1 test only asserts the beta-only path.
    zero_one_beta = {
      phi <- 1 / pmax(sigma, 1e-3)^2
      cont <- stats::rbeta(n, shape1 = mu * phi, shape2 = (1 - mu) * phi)
      zoi <- params$zoi
      if (!is.null(zoi) && any(zoi > 0)) {
        coi <- if (!is.null(params$coi)) params$coi else rep(0.5, n)
        is_boundary <- stats::runif(n) < zoi
        is_one <- is_boundary & (stats::runif(n) < coi)
        cont[is_boundary] <- 0
        cont[is_one] <- 1
      }
      cont
    },
    # tweedie: a compound Poisson-Gamma draw is well-defined only when the power
    # 1 < p < 2 AND the dispersion phi are known on the response scale. drmTMB
    # exposes the power, but the mapping from its SD-like `sigma` to the tweedie
    # dispersion phi is not yet confirmed against a live fit, so we cannot safely
    # parameterize the Gamma jumps. Per the "mean-fallback over a guessed
    # sampler" rule we fall through to the mean below (with drm_warn_once).
    # TODO(live-drmTMB): confirm phi <-> sigma for tweedie (compound Poisson:
    #   lambda = mu^(2-p) / (phi*(2-p)); jump ~ Gamma(shape=(2-p)/(p-1),
    #   scale=phi*(p-1)*mu^(p-1))), then enable a sampler gated on params$power
    #   (or params$nu) holding 1 < p < 2. Until then, mean fallback.
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

# Expected response value for a node's fitted family at response-scale dpars.
# Most drmTMB families expose `mu` as the response mean. lognormal is the
# important exception in current drmTMB: `mu` is meanlog and `sigma` is sdlog.
drm_family_expected_mean <- function(family, params) {
  mu <- params$mu
  sigma <- if (!is.null(params$sigma)) params$sigma else rep(0, length(mu))
  zi <- if (!is.null(params$zi)) params$zi else rep(0, length(mu))
  out <- switch(
    family,
    lognormal = exp(mu + 0.5 * sigma^2),
    mu
  )
  if (any(zi > 0)) out <- (1 - zi) * out
  out
}

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
    comps <- drm_fit_prediction_components(fit)
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
    expected <- drm_family_expected_mean(eng$family, preds)
    node_mean[[eng$name]] <- expected
    if (eng$name %in% active) {
      val <- if (identical(mediation, "distribution")) {
        drm_sample_family(eng$family, preds, n = nrow(work))
      } else {
        expected
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

# Natural (cross-world) direct/indirect effects for `to`, holding the mediators
# in `active` at their counterfactual M(x0) / M(x1) values (Pearl/Imai NDE/NIE).
# Unlike the controlled split, the mediator is set to its predicted distribution
# under each exposure level, not to its observed values. Returns one parameter
# draw as c(nde, nie, total). See docs/design/02-effect-calculus.md (OQ-8).
drm_natural_target <- function(engines, scenarios, from_col, to, active,
                               mediation = "distribution", beta_list = NULL,
                               n_sim = 1L) {
  one <- function() {
    # mediator worlds: propagate the exposure contrast through the mediators
    work0 <- drm_propagate(engines, scenarios$lo, active, mediation, beta_list)$work
    work1 <- drm_propagate(engines, scenarios$hi, active, mediation, beta_list)$work
    eng_to <- engines[[to]]
    # predict the outcome's response-scale mean with the DIRECT exposure set to
    # `from_src` while the mediators stay at their (already-fixed) world values.
    pmu <- function(work, from_src) {
      work[[from_col]] <- from_src[[from_col]]
      mean(eng_to$predict(work, beta = beta_list[[to]])$mu, na.rm = TRUE)
    }
    y00 <- pmu(work0, scenarios$lo)   # Y(x0, M(x0))
    y10 <- pmu(work0, scenarios$hi)   # Y(x1, M(x0))
    y01 <- pmu(work1, scenarios$lo)   # Y(x0, M(x1))
    y11 <- pmu(work1, scenarios$hi)   # Y(x1, M(x1))
    c(nde = y10 - y00, nie = y01 - y00, total = y11 - y00)
  }
  if (identical(mediation, "distribution") && n_sim > 1L) {
    acc <- c(nde = 0, nie = 0, total = 0)
    for (s in seq_len(n_sim)) acc <- acc + one()
    acc / n_sim
  } else {
    one()
  }
}

# Summary functional of a realized outcome vector (OQ-11): effects can be read on
# any functional of the predicted outcome distribution, not just the mean.
# `quantile` reports the `prob`-quantile (e.g. the median at prob = 0.5, or a tail
# quantile that a path into `sigma`/`nu` moves while leaving the mean unchanged).
drm_outcome_functional <- function(y, target = "mean", threshold = 0,
                                   prob = 0.5) {
  switch(
    target,
    mean = mean(y, na.rm = TRUE),
    p_gt = mean(y > threshold, na.rm = TRUE),
    p_zero = mean(y == 0, na.rm = TRUE),
    var = stats::var(y, na.rm = TRUE),
    quantile = stats::quantile(y, probs = prob, na.rm = TRUE, names = FALSE),
    mean(y, na.rm = TRUE)
  )
}

# Population functional of the outcome `to` under a scenario. For target "mean"
# this is the exact predicted mean; for distributional targets the outcome is
# simulated from its family and the functional is averaged over n_sim draws.
# `mediation` controls how the *mediators* feed downstream (their mean vs a
# realized draw); the outcome `to` is always simulated from its family so the
# functional is defined. Respecting `mediation` here (rather than forcing
# "distribution") is what keeps the mean- vs distribution-mediated split of
# indirect_effects() non-degenerate for a non-mean target.
drm_functional_target <- function(engines, scenario, to, active, mediation,
                                  beta_list, target = "mean", threshold = 0,
                                  n_sim = 1L, prob = 0.5) {
  if (identical(target, "mean")) {
    return(mean(drm_expected_target(engines, scenario, to, active, mediation,
                                    beta_list, n_sim), na.rm = TRUE))
  }
  eng_to <- engines[[to]]
  reps <- max(as.integer(n_sim), 1L)
  acc <- 0
  for (s in seq_len(reps)) {
    work <- drm_propagate(engines, scenario, active, mediation, beta_list)$work
    preds <- eng_to$predict(work, beta = beta_list[[to]])
    y <- drm_sample_family(eng_to$family, preds, n = nrow(scenario))
    acc <- acc + drm_outcome_functional(y, target, threshold, prob)
  }
  acc / reps
}

# Contrast of an outcome functional across the low/high scenarios (OQ-11).
drm_functional_contrast <- function(engines, scenarios, to, active, mediation,
                                    target, threshold, B, n_sim, draw, seed = NULL,
                                    prob = 0.5) {
  if (!is.null(seed)) set.seed(seed)
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    fhi <- drm_functional_target(engines, scenarios$hi, to, active, mediation,
                                 beta_list, target, threshold, n_sim, prob)
    flo <- drm_functional_target(engines, scenarios$lo, to, active, mediation,
                                 beta_list, target, threshold, n_sim, prob)
    vals[[b]] <- fhi - flo
  }
  vals
}
