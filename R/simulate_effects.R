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
    log = exp(pmin(eta, log(.Machine$double.xmax) - 1)),
    logit = stats::plogis(eta),
    tanh = tanh(eta),
    eta
  )
}

#' Draw realized values from a node's family given response-scale parameters
#'
#' `params` is a data frame/list with at least `mu`; optional `sigma`, `nu`,
#' `zi`, `trials`. Implemented for the common drmTMB families; unsupported
#' families fall back to the mean (with a single warning per call).
#'
#' **`hu` is NOT read.** It was listed here as accepted, but nothing in the body
#' ever consulted it -- documentation ahead of code. Removed from the list rather
#' than left as a false promise.
#'
#' The consequence is a live gap, pinned by V-103 in `test-hurdle-gap.R`. drmTMB
#' folds the hurdle into `model_type` (`hurdle_nbinom2`) while leaving
#' `family$family` as `truncated_nbinom2` -- which drmSEM keys on, and which IS in
#' `drm_supported_sampler_families()`. So a hurdle mediator reports
#' `sampler = TRUE` in `check_sem()` and is then sampled as a plain truncated
#' NB2, silently dropping its hurdle zeros. The family NAME cannot express the
#' distinction; fixing it means keying on `model_type`, which changes what a
#' mediator propagates and is therefore a semantics change, not a bug fix.
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
    Gamma = stats::rgamma(
      n,
      shape = 1 / pmax(sigma^2, 1e-8),
      rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)
    ),
    gamma = stats::rgamma(
      n,
      shape = 1 / pmax(sigma^2, 1e-8),
      rate = 1 / pmax(sigma^2, 1e-8) / pmax(mu, 1e-8)
    ),
    poisson = stats::rpois(n, lambda = pmax(mu, 0)),
    # drmTMB's `sigma` is treated as an SD-like scale: the nbinom2 size (theta) is
    # 1/sigma^2 (so var = mu + mu^2 * sigma^2), and the beta precision is 1/sigma^2.
    # V-57..V-60 assert these moments against drmTMB::simulate().
    nbinom2 = stats::rnbinom(
      n,
      mu = pmax(mu, 0),
      size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8)
    ),
    truncated_nbinom2 = pmax(
      1,
      stats::rnbinom(
        n,
        mu = pmax(mu, 0),
        size = pmax(1 / pmax(sigma, 1e-8)^2, 1e-8)
      )
    ),
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
    # tweedie: the blocker recorded here was the sigma <-> dispersion mapping.
    # It is answered by the engine itself -- simulate.drmTMB draws
    # rtweedie_compound(n, mu, phi = sigma^2, power = nu) -- so rather than
    # restate that mapping (which is how such mappings drift), call the engine's
    # own generator. If this drmTMB build does not expose it, fall through to the
    # documented mean fallback rather than guessing.
    tweedie = {
      rtw <- drm_engine_fun("rtweedie_compound")
      power <- params$nu %||% params$power
      if (is.null(rtw) || is.null(power)) {
        NULL
      } else {
        rtw(n, mu = pmax(mu, 1e-8), phi = pmax(sigma, 1e-8)^2, power = power)
      }
    },
    skew_normal = {
      rsn <- drm_engine_fun("rskew_normal_public")
      if (is.null(rsn) || is.null(params$nu)) {
        NULL
      } else {
        rsn(n, mu = mu, sigma = sigma, nu = params$nu)
      }
    },
    # binomial / beta_binomial model a PROBABILITY in mu but have COUNTS as the
    # response. Returning mu here would hand a downstream node a value on (0,1)
    # where it was fitted on counts -- off by one to two orders of magnitude. So
    # these need `trials`, and without it we must NOT draw at all.
    binomial = {
      if (is.null(params$trials)) {
        NULL
      } else {
        stats::rbinom(n, size = round(params$trials), prob = pmin(pmax(mu, 0), 1))
      }
    },
    beta_binomial = {
      shapes <- drm_engine_fun("drm_beta_shapes")
      if (is.null(params$trials) || is.null(shapes)) {
        NULL
      } else {
        native <- shapes(mu, sigma)
        p <- stats::rbeta(n, shape1 = native$shape1, shape2 = native$shape2)
        stats::rbinom(n, size = round(params$trials), prob = p)
      }
    },
    # Reached only via drm_effective_family(): a hurdle node's family NAME is
    # `truncated_nbinom2`, so without the model_type key this branch is unreachable
    # and the node is drawn as a plain truncated NB2 with its hurdle zeros missing.
    # Borrows the engine's own helpers so the parameterization cannot drift.
    hurdle_nbinom2 = {
      nb_size <- drm_engine_fun("drm_nbinom2_size")
      p0_fun <- drm_engine_fun("truncated_nbinom2_p0")
      hu <- params$hu
      if (is.null(nb_size) || is.null(p0_fun) || is.null(hu)) {
        NULL
      } else {
        size <- nb_size(sigma)
        p0 <- p0_fun(mu, sigma)
        hurdle_zero <- stats::runif(n) < hu
        u <- p0 + pmax(stats::runif(n), .Machine$double.eps) * (1 - p0)
        ifelse(hurdle_zero, 0L, stats::qnbinom(u, size = size, mu = mu))
      }
    },
    NULL
  )
  # A NULL here means either "no branch for this family" or "the branch exists
  # but its required input (trials, power, an engine helper) was unavailable".
  # Both are the same promise to the user: we did not guess.
  if (is.null(base)) {
    drm_warn_once(
      paste0("family-sampler-", family),
      cli::format_inline(
        "No realized-value sampler for family {.val {family}}; using its mean."
      )
    )
    # Deliberately raw `mu`, not drm_family_expected_mean(): that helper applies
    # the zero-inflation adjustment, which the block below applies again.
    base <- mu
  }
  # zero-inflation: with probability zi the structural zero replaces the draw
  if (any(zi > 0)) {
    is_zero <- stats::runif(n) < zi
    base[is_zero] <- 0
  }
  base
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# model_types that get their OWN sampler branch, keyed ahead of the family name.
#
# Deliberately a short allow-list rather than "always prefer model_type". Most
# model_types (zi_poisson, zi_nbinom2, ...) have no branch of their own and are
# handled correctly by the base family plus generic zi post-processing; keying on
# model_type wholesale would send those to the mean fallback -- fixing one silent
# degradation by introducing several.
drm_model_type_samplers <- function() {
  c("hurdle_nbinom2")
}

# The key drm_sample_family() should dispatch on: the model_type when it has its own
# branch, otherwise the family name.
drm_effective_family <- function(family, model_type = NA_character_) {
  if (!is.na(model_type) && model_type %in% drm_model_type_samplers()) {
    return(model_type)
  }
  family
}

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
    # Hurdle NB2: with probability hu the value is a structural zero; otherwise it is
    # a ZERO-TRUNCATED NB2, whose mean is mu/(1 - p0), not mu. Using mu here would
    # understate the conditional mean and ignore the hurdle entirely.
    hurdle_nbinom2 = {
      p0_fun <- drm_engine_fun("truncated_nbinom2_p0")
      hu <- params$hu
      if (is.null(p0_fun) || is.null(hu)) {
        mu
      } else {
        p0 <- p0_fun(mu, sigma)
        (1 - hu) * mu / pmax(1 - p0, .Machine$double.eps)
      }
    },
    # binomial / beta_binomial put a PROBABILITY in mu and COUNTS in the
    # response, so the expected response is trials * mu. Without `trials` we
    # cannot convert; returning mu would hand a downstream node a value on (0,1)
    # where it was fitted on counts. This affects mediation = "mean" too, not
    # just distributional propagation.
    binomial = ,
    beta_binomial = if (is.null(params$trials)) {
      drm_warn_once(
        paste0("family-mean-trials-", family),
        cli::format_inline(
          "No {.field trials} available for family {.val {family}}; its mean is
           reported as a probability, not a count."
        )
      )
      mu
    } else {
      params$trials * mu
    },
    mu
  )
  if (any(zi > 0)) {
    out <- (1 - zi) * out
  }
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
    # The hurdle/zi distinction lives here, not in the family name.
    model_type <- drm_fit_model_type(fit)
    comps <- drm_fit_prediction_components(fit)
    coef_list <- stats::setNames(
      lapply(comps, function(cc) drm_fit_coef(fit, cc)),
      comps
    )
    links <- stats::setNames(
      vapply(comps, function(cc) drm_nominal_link(family, cc), character(1)),
      comps
    )
    V <- drm_fit_vcov(fit)
    ident <- if (rec$response_label %in% names(object$data)) {
      rec$response_label
    } else if (length(rec$response_vars) == 1L) {
      rec$response_vars[[1L]]
    } else {
      nm
    }
    local({
      fit_l <- fit
      comps_l <- comps
      coef_l <- coef_list
      links_l <- links
      predict_fn <- function(scenario, beta = NULL) {
        out <- data.frame(.row = seq_len(nrow(scenario)))
        for (cc in comps_l) {
          X <- drm_fixed_design(fit_l, cc, scenario)
          b <- if (!is.null(beta) && !is.null(beta[[cc]])) {
            beta[[cc]]
          } else {
            coef_l[[cc]]
          }
          eta <- if (ncol(X) == 0L) {
            rep(0, nrow(scenario))
          } else {
            as.numeric(X %*% b)
          }
          out[[cc]] <- drm_inv_link(links_l[[cc]], eta)
        }
        out$.row <- NULL
        # `trials` is a model constant, not a dpar, but binomial/beta_binomial
        # samplers and means both need it to return counts rather than
        # probabilities. Carried alongside the components so the family helpers
        # see one uniform `params` object.
        tr <- drm_fit_trials(fit_l, nrow(scenario))
        if (!is.null(tr)) {
          out$trials <- tr
        }
        out
      }
      engines[[nm]] <<- list(
        name = nm,
        identifier = ident,
        family = family,
        model_type = model_type,
        components = comps_l,
        links = links_l,
        coef = coef_l,
        vcov = V,
        converged = drm_fit_converged(fit_l),
        predict = predict_fn
      )
    })
  }
  engines
}

drm_vcov_block_status <- function(V, keys) {
  if (is.null(V)) {
    return("vcov_unavailable")
  }
  rn <- rownames(V)
  cn <- colnames(V)
  if (is.null(rn) || is.null(cn) || !all(keys %in% rn) || !all(keys %in% cn)) {
    return("vcov_missing_component")
  }
  Vb <- V[keys, keys, drop = FALSE]
  if (!all(is.finite(Vb))) {
    return("vcov_nonfinite")
  }
  if (!isTRUE(all.equal(Vb, t(Vb), tolerance = 1e-8))) {
    return("vcov_not_symmetric")
  }
  ev <- tryCatch(
    eigen(Vb, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NA_real_
  )
  if (any(!is.finite(ev)) || min(ev) < -1e-8) {
    return("vcov_not_psd")
  }
  "ok"
}

drm_effect_draw_issues <- function(engines, draw = TRUE) {
  rows <- list()
  add <- function(node, component, issue) {
    rows[[length(rows) + 1L]] <<- data.frame(
      node = node,
      component = component,
      issue = issue,
      stringsAsFactors = FALSE
    )
  }
  for (eng in engines) {
    if (!isTRUE(eng$converged)) {
      add(eng$name, NA_character_, "not_converged")
    }
    if (!isTRUE(draw)) {
      next
    }
    for (cc in eng$components) {
      co <- eng$coef[[cc]]
      if (length(co) == 0L) {
        next
      }
      status <- drm_vcov_block_status(eng$vcov, paste0(cc, ":", names(co)))
      if (!identical(status, "ok")) {
        add(eng$name, cc, status)
      }
    }
  }
  if (!length(rows)) {
    return(data.frame(
      node = character(0),
      component = character(0),
      issue = character(0)
    ))
  }
  unique(do.call(rbind, rows))
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
    if (length(co) == 0L) {
      next
    }
    keys <- paste0(cc, ":", names(co))
    if (identical(drm_vcov_block_status(V, keys), "ok")) {
      Vb <- V[keys, keys, drop = FALSE]
      out[[cc]] <- stats::setNames(
        as.numeric(MASS::mvrnorm(1, mu = co, Sigma = Vb)),
        names(co)
      )
    }
  }
  out
}

# Propagate an intervention scenario through the engines (topological order).
# `active` is the set of mediator node names allowed to feed their computed
# value downstream; inactive nodes keep their scenario column values.
# Returns a list with `mean` (per-node response-scale mean vector) and `work`.
drm_propagate <- function(
  engines,
  scenario,
  active,
  mediation = "mean",
  beta_list = NULL
) {
  work <- as.data.frame(scenario)
  node_mean <- list()
  for (eng in engines) {
    preds <- eng$predict(work, beta = beta_list[[eng$name]])
    eff_family <- drm_effective_family(eng$family, eng$model_type %||% NA_character_)
    expected <- drm_family_expected_mean(eff_family, preds)
    node_mean[[eng$name]] <- expected
    if (eng$name %in% active) {
      val <- if (identical(mediation, "distribution")) {
        drm_sample_family(eff_family, preds, n = nrow(work))
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
drm_expected_target <- function(
  engines,
  scenario,
  to,
  active,
  mediation,
  beta_list,
  n_sim = 1L
) {
  if (identical(mediation, "distribution") && n_sim > 1L) {
    acc <- numeric(nrow(scenario))
    for (s in seq_len(n_sim)) {
      acc <- acc +
        drm_propagate(engines, scenario, active, mediation, beta_list)$mean[[
          to
        ]]
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
# draw as c(nde, nie, total, mediated_interaction). See docs/design/02-effect-calculus.md (OQ-8).
drm_natural_target <- function(
  engines,
  scenarios,
  from_col,
  to,
  active,
  mediation = "distribution",
  beta_list = NULL,
  n_sim = 1L,
  target = "mean",
  threshold = 0,
  prob = 0.5,
  functional = "simulate"
) {
  one <- function() {
    # mediator worlds: propagate the exposure contrast through the mediators
    work0 <- drm_propagate(
      engines,
      scenarios$lo,
      active,
      mediation,
      beta_list
    )$work
    work1 <- drm_propagate(
      engines,
      scenarios$hi,
      active,
      mediation,
      beta_list
    )$work
    eng_to <- engines[[to]]
    eff_family <- drm_effective_family(eng_to$family, eng_to$model_type %||% NA_character_)

    # predict the outcome's response-scale functional with the DIRECT exposure set to
    # `from_src` while the mediators stay at their (already-fixed) world values.
    pfn <- function(work, from_src) {
      work[[from_col]] <- from_src[[from_col]]
      if (identical(target, "mean")) {
        preds <- eng_to$predict(work, beta = beta_list[[to]])
        mean(drm_family_expected_mean(eff_family, preds), na.rm = TRUE)
      } else if (identical(functional, "analytic")) {
        preds <- eng_to$predict(work, beta = beta_list[[to]])
        fv <- drm_analytic_functional(eng_to$family, preds, target = target, threshold = threshold, prob = prob)
        if (!is.null(fv)) {
          mean(fv, na.rm = TRUE)
        } else {
          reps <- max(as.integer(n_sim), 1L)
          acc <- 0
          for (s in seq_len(reps)) {
            y <- drm_sample_family(eff_family, preds, n = nrow(work))
            acc <- acc + drm_outcome_functional(y, target, threshold, prob)
          }
          acc / reps
        }
      } else {
        reps <- max(as.integer(n_sim), 1L)
        acc <- 0
        preds <- eng_to$predict(work, beta = beta_list[[to]])
        for (s in seq_len(reps)) {
          y <- drm_sample_family(eff_family, preds, n = nrow(work))
          acc <- acc + drm_outcome_functional(y, target, threshold, prob)
        }
        acc / reps
      }
    }
    y00 <- pfn(work0, scenarios$lo) # Y(x0, M(x0))
    y10 <- pfn(work0, scenarios$hi) # Y(x1, M(x0))
    y01 <- pfn(work1, scenarios$lo) # Y(x0, M(x1))
    y11 <- pfn(work1, scenarios$hi) # Y(x1, M(x1))
    c(
      nde = y10 - y00,
      nie = y01 - y00,
      total = y11 - y00,
      mediated_interaction = y11 - y10 - y01 + y00
    )
  }
  if (identical(mediation, "distribution") && n_sim > 1L && identical(target, "mean")) {
    acc <- c(nde = 0, nie = 0, total = 0, mediated_interaction = 0)
    for (s in seq_len(n_sim)) {
      acc <- acc + one()
    }
    acc / n_sim
  } else {
    one()
  }
}

# Summary functional of a realized outcome vector (OQ-11): effects can be read on
# any functional of the predicted outcome distribution, not just the mean.
# `quantile` reports the `prob`-quantile (e.g. the median at prob = 0.5, or a tail
# quantile that a path into `sigma`/`nu` moves while leaving the mean unchanged).
drm_outcome_functional <- function(
  y,
  target = "mean",
  threshold = 0,
  prob = 0.5
) {
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
drm_functional_target <- function(
  engines,
  scenario,
  to,
  active,
  mediation,
  beta_list,
  target = "mean",
  threshold = 0,
  n_sim = 1L,
  prob = 0.5
) {
  if (identical(target, "mean")) {
    return(mean(
      drm_expected_target(
        engines,
        scenario,
        to,
        active,
        mediation,
        beta_list,
        n_sim
      ),
      na.rm = TRUE
    ))
  }
  eng_to <- engines[[to]]
  reps <- max(as.integer(n_sim), 1L)
  acc <- 0
  for (s in seq_len(reps)) {
    work <- drm_propagate(engines, scenario, active, mediation, beta_list)$work
    preds <- eng_to$predict(work, beta = beta_list[[to]])
    y <- drm_sample_family(
      drm_effective_family(eng_to$family, eng_to$model_type %||% NA_character_),
      preds, n = nrow(scenario)
    )
    acc <- acc + drm_outcome_functional(y, target, threshold, prob)
  }
  acc / reps
}

# Contrast of an outcome functional across the low/high scenarios (OQ-11).
drm_functional_contrast <- function(
  engines,
  scenarios,
  to,
  active,
  mediation,
  target,
  threshold,
  B,
  n_sim,
  draw,
  seed = NULL,
  prob = 0.5
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    fhi <- drm_functional_target(
      engines,
      scenarios$hi,
      to,
      active,
      mediation,
      beta_list,
      target,
      threshold,
      n_sim,
      prob
    )
    flo <- drm_functional_target(
      engines,
      scenarios$lo,
      to,
      active,
      mediation,
      beta_list,
      target,
      threshold,
      n_sim,
      prob
    )
    vals[[b]] <- fhi - flo
  }
  vals
}

# Closed-form (analytic) outcome functional per row, for the families where the
# functional is unambiguous given the predicted parameters -- no Monte-Carlo
# simulation, so no sampling noise (OQ-11). Returns a per-row numeric vector, or
# NULL when no closed form is offered for this (family, target).
# Supported families: gaussian, poisson, lognormal, Gamma, nbinom2, beta, student.
drm_analytic_functional <- function(
  family,
  params,
  target = "mean",
  threshold = 0,
  prob = 0.5
) {
  mu <- params$mu
  n <- length(mu)
  sigma <- if (!is.null(params$sigma)) params$sigma else rep(1, n)
  zi <- if (!is.null(params$zi)) params$zi else rep(0, n)

  if (identical(family, "gaussian")) {
    switch(
      target,
      mean = mu,
      var = sigma^2,
      p_gt = stats::pnorm(threshold, mean = mu, sd = sigma, lower.tail = FALSE),
      p_zero = rep(0, n), # continuous: Pr(Y = 0) = 0
      quantile = stats::qnorm(prob, mean = mu, sd = sigma),
      NULL
    )
  } else if (identical(family, "poisson")) {
    switch(
      target,
      mean = (1 - zi) * mu,
      var = (1 - zi) * mu + zi * (1 - zi) * mu^2,
      p_gt = ifelse(
        threshold < 0,
        1,
        (1 - zi) * stats::ppois(floor(threshold), lambda = pmax(mu, 0), lower.tail = FALSE)
      ),
      p_zero = zi + (1 - zi) * stats::dpois(0, lambda = pmax(mu, 0)),
      quantile = ifelse(
        prob <= zi,
        0,
        stats::qpois(pmax(0, (prob - zi) / pmax(1 - zi, 1e-12)), lambda = pmax(mu, 0))
      ),
      NULL
    )
  } else if (identical(family, "lognormal")) {
    # mu is meanlog, sigma is sdlog
    switch(
      target,
      mean = (1 - zi) * exp(mu + 0.5 * sigma^2),
      var = (1 - zi) * exp(2 * mu + 2 * sigma^2) - ((1 - zi) * exp(mu + 0.5 * sigma^2))^2,
      p_gt = ifelse(
        threshold <= 0,
        1 - zi,
        (1 - zi) * stats::plnorm(threshold, meanlog = mu, sdlog = pmax(sigma, 1e-8), lower.tail = FALSE)
      ),
      p_zero = zi,
      quantile = ifelse(
        prob <= zi,
        0,
        stats::qlnorm(pmax(0, (prob - zi) / pmax(1 - zi, 1e-12)), meanlog = mu, sdlog = pmax(sigma, 1e-8))
      ),
      NULL
    )
  } else if (identical(family, "Gamma") || identical(family, "gamma")) {
    # Gamma in drmTMB: shape = 1/sigma^2, rate = 1/(sigma^2 * mu)
    sig2 <- pmax(sigma^2, 1e-8)
    mu_pos <- pmax(mu, 1e-8)
    shape_val <- 1 / sig2
    rate_val <- 1 / (sig2 * mu_pos)
    switch(
      target,
      mean = (1 - zi) * mu_pos,
      var = (1 - zi) * mu_pos^2 * (sig2 + zi),
      p_gt = ifelse(
        threshold <= 0,
        1 - zi,
        (1 - zi) * stats::pgamma(threshold, shape = shape_val, rate = rate_val, lower.tail = FALSE)
      ),
      p_zero = zi,
      quantile = ifelse(
        prob <= zi,
        0,
        stats::qgamma(pmax(0, (prob - zi) / pmax(1 - zi, 1e-12)), shape = shape_val, rate = rate_val)
      ),
      NULL
    )
  } else if (identical(family, "nbinom2")) {
    # nbinom2 in drmTMB: size = 1/sigma^2
    size_val <- pmax(1 / pmax(sigma, 1e-8)^2, 1e-8)
    mu_pos <- pmax(mu, 0)
    switch(
      target,
      mean = (1 - zi) * mu_pos,
      var = (1 - zi) * (mu_pos + mu_pos^2 * (pmax(sigma, 1e-8)^2 + zi)),
      p_gt = ifelse(
        threshold < 0,
        1,
        (1 - zi) * stats::pnbinom(floor(threshold), size = size_val, mu = mu_pos, lower.tail = FALSE)
      ),
      p_zero = zi + (1 - zi) * stats::dnbinom(0, size = size_val, mu = mu_pos),
      quantile = ifelse(
        prob <= zi,
        0,
        stats::qnbinom(pmax(0, (prob - zi) / pmax(1 - zi, 1e-12)), size = size_val, mu = mu_pos)
      ),
      NULL
    )
  } else if (identical(family, "beta")) {
    # beta in drmTMB: phi = 1/sigma^2, shape1 = mu*phi, shape2 = (1-mu)*phi
    phi <- 1 / pmax(sigma, 1e-3)^2
    mu_clamped <- pmin(pmax(mu, 1e-6), 1 - 1e-6)
    sh1 <- pmax(mu_clamped * phi, 1e-6)
    sh2 <- pmax((1 - mu_clamped) * phi, 1e-6)
    switch(
      target,
      mean = mu_clamped,
      var = mu_clamped * (1 - mu_clamped) / (1 + phi),
      p_gt = ifelse(
        threshold <= 0,
        1,
        ifelse(
          threshold >= 1,
          0,
          stats::pbeta(threshold, shape1 = sh1, shape2 = sh2, lower.tail = FALSE)
        )
      ),
      p_zero = rep(0, n),
      quantile = stats::qbeta(prob, shape1 = sh1, shape2 = sh2),
      NULL
    )
  } else if (identical(family, "student")) {
    nu_val <- pmax(params$nu %||% rep(5, n), 2.1)
    sig_pos <- pmax(sigma, 1e-8)
    switch(
      target,
      mean = ifelse(nu_val > 1, mu, NA_real_),
      var = ifelse(nu_val > 2, sig_pos^2 * nu_val / (nu_val - 2), NA_real_),
      p_gt = stats::pt((threshold - mu) / sig_pos, df = nu_val, lower.tail = FALSE),
      p_zero = rep(0, n),
      quantile = mu + sig_pos * stats::qt(prob, df = nu_val),
      NULL
    )
  } else {
    NULL
  }
}

# Population analytic functional of `to` under a scenario: propagate (mediators at
# their MEAN -- analytic functionals require deterministic outcome params), read
# the outcome node's predicted params, apply the closed form, average over rows.
# Returns NULL if no closed form exists for the (family, target).
drm_functional_target_analytic <- function(
  engines,
  scenario,
  to,
  active,
  mediation,
  beta_list,
  target,
  threshold = 0,
  prob = 0.5
) {
  work <- drm_propagate(engines, scenario, active, mediation, beta_list)$work
  eng_to <- engines[[to]]
  params <- eng_to$predict(work, beta = beta_list[[to]])
  fv <- drm_analytic_functional(eng_to$family, params, target, threshold, prob)
  if (is.null(fv)) {
    return(NULL)
  }
  mean(fv, na.rm = TRUE)
}

# Analytic analogue of drm_functional_contrast: exact (noise-free) contrast of an
# outcome functional across the low/high scenarios. Requires mean mediation (the
# outcome params must be deterministic). Returns NULL when the family/target has
# no closed form, so the caller can abort or fall back.
drm_functional_contrast_analytic <- function(
  engines,
  scenarios,
  to,
  active,
  mediation,
  target,
  threshold,
  prob,
  B,
  draw,
  seed = NULL
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    fhi <- drm_functional_target_analytic(
      engines,
      scenarios$hi,
      to,
      active,
      mediation,
      beta_list,
      target,
      threshold,
      prob
    )
    flo <- drm_functional_target_analytic(
      engines,
      scenarios$lo,
      to,
      active,
      mediation,
      beta_list,
      target,
      threshold,
      prob
    )
    if (is.null(fhi) || is.null(flo)) {
      return(NULL)
    }
    vals[[b]] <- fhi - flo
  }
  vals
}
