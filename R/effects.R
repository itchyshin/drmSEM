#' @keywords internal
#' @noRd
NULL

# Build paired low/high intervention scenarios over the fitted data population.
drm_build_scenarios <- function(object, from, at = NULL) {
  data <- as.data.frame(object$data)
  col <- from
  if (!col %in% names(data)) {
    if (from %in% object$endogenous) {
      ids <- object$records[[from]]$identifiers
      hit <- ids[ids %in% names(data)]
      if (length(hit)) {
        col <- hit[[1L]]
      } else {
        cli::cli_abort("Cannot find a data column for {.val {from}}.")
      }
    } else {
      cli::cli_abort("{.val {from}} is not a column in the model data.")
    }
  }
  x <- data[[col]]
  if (is.null(at)) {
    if (is.numeric(x)) {
      m <- mean(x, na.rm = TRUE)
      s <- stats::sd(x, na.rm = TRUE)
      at <- c(m - 0.5 * s, m + 0.5 * s)
    } else {
      lv <- if (is.factor(x)) levels(x) else sort(unique(x))
      if (length(lv) < 2L) {
        cli::cli_abort("{.val {from}} has fewer than two levels.")
      }
      at <- lv[1:2]
    }
  }
  lo <- data
  hi <- data
  lo[[col]] <- if (is.factor(x)) {
    factor(at[[1]], levels = levels(x))
  } else {
    at[[1]]
  }
  hi[[col]] <- if (is.factor(x)) {
    factor(at[[2]], levels = levels(x))
  } else {
    at[[2]]
  }
  list(lo = lo, hi = hi, at = at, column = col)
}

# Draw-level contrast vector for a given active mediator set.
drm_effect_contrast <- function(
  engines,
  scenarios,
  to,
  active,
  mediation,
  B,
  n_sim,
  draw,
  seed = NULL,
  population = "conditional"
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    mu_hi <- drm_expected_target(
      engines,
      scenarios$hi,
      to,
      active,
      mediation,
      beta_list,
      n_sim,
      population = population
    )
    mu_lo <- drm_expected_target(
      engines,
      scenarios$lo,
      to,
      active,
      mediation,
      beta_list,
      n_sim,
      population = population
    )
    vals[[b]] <- mean(mu_hi - mu_lo, na.rm = TRUE)
  }
  vals
}

# Paired three-leg decomposition used by indirect_effects(). Within each
# replicate, ONE coefficient draw (`beta_list`) is shared across the
# controlled-direct (cde), mean-mediated total (tot_mean), and
# distribution-mediated total (tot_dist) legs, so the differences
# `tot_mean - cde` and `tot_dist - tot_mean` are common-random-numbers (paired)
# contrasts: the reported intervals isolate the propagation mode rather than
# coefficient-draw noise. (Three separate drm_effect_contrast() calls would draw
# independent coefficients per leg -- the point estimate is unbiased either way,
# but the unpaired interval is inflated and not a valid paired contrast.) This
# mirrors the shared-draw structure already used by the natural-effect branch.
# For target = "mean" the cde/tot_mean legs are deterministic given beta, so they
# use n_sim = 1; the distribution leg consumes inner family draws (n_sim). For a
# non-mean `target` (OQ-11) every leg must simulate the outcome to estimate its
# functional, so all three legs draw n_sim inner realizations. The functional
# legs reduce to the mean legs exactly when target = "mean" (drm_functional_target
# returns the exact predicted mean there), so the mean-target results are
# unchanged.
drm_decomp_legs <- function(
  engines,
  scenarios,
  to,
  active,
  B,
  n_sim,
  draw,
  seed = NULL,
  target = "mean",
  threshold = 0,
  prob = 0.5,
  population = "conditional"
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  reps <- if (isTRUE(draw)) B else 1L
  legs <- matrix(
    NA_real_,
    reps,
    3L,
    dimnames = list(NULL, c("cde", "tot_mean", "tot_dist"))
  )
  ns_meanleg <- if (identical(target, "mean")) 1L else n_sim
  leg <- function(act, med, ns, beta_list) {
    fhi <- drm_functional_target(
      engines,
      scenarios$hi,
      to,
      act,
      med,
      beta_list,
      target,
      threshold,
      ns,
      prob,
      population = population
    )
    flo <- drm_functional_target(
      engines,
      scenarios$lo,
      to,
      act,
      med,
      beta_list,
      target,
      threshold,
      ns,
      prob,
      population = population
    )
    fhi - flo
  }
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    legs[b, "cde"] <- leg(character(0), "mean", ns_meanleg, beta_list)
    legs[b, "tot_mean"] <- leg(active, "mean", ns_meanleg, beta_list)
    legs[b, "tot_dist"] <- leg(active, "distribution", n_sim, beta_list)
  }
  legs
}

drm_summ <- function(vals, level = 0.95) {
  a <- (1 - level) / 2
  finite <- vals[is.finite(vals)]
  data.frame(
    estimate = if (length(finite)) mean(finite) else NA_real_,
    conf.low = if (length(finite) > 1L) {
      stats::quantile(finite, a, names = FALSE)
    } else {
      NA_real_
    },
    conf.high = if (length(finite) > 1L) {
      stats::quantile(finite, 1 - a, names = FALSE)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
}

drm_summ_boot <- function(orig_est, boot_vals, level = 0.95) {
  a <- (1 - level) / 2
  finite <- boot_vals[is.finite(boot_vals)]
  est <- if (!is.na(orig_est) && is.finite(orig_est)) {
    orig_est
  } else if (length(finite) > 0L) {
    mean(finite)
  } else {
    NA_real_
  }
  se <- if (length(finite) > 1L) stats::sd(finite) else NA_real_
  perc_low <- if (length(finite) > 1L) stats::quantile(finite, a, names = FALSE) else NA_real_
  perc_high <- if (length(finite) > 1L) stats::quantile(finite, 1 - a, names = FALSE) else NA_real_
  norm_low <- if (!is.na(est) && !is.na(se)) est - stats::qnorm(1 - a) * se else NA_real_
  norm_high <- if (!is.na(est) && !is.na(se)) est + stats::qnorm(1 - a) * se else NA_real_
  df <- data.frame(
    estimate = est,
    std.error = se,
    conf.low = perc_low,
    conf.high = perc_high,
    stringsAsFactors = FALSE
  )
  attr(df, "boot_se") <- se
  attr(df, "boot_ci_percentile") <- c(perc_low, perc_high)
  attr(df, "boot_ci_normal") <- c(norm_low, norm_high)
  attr(df, "boot_replicates") <- boot_vals
  attr(df, "boot_converged") <- length(finite)
  df
}

drm_value_issues <- function(values) {
  flat <- unlist(values, use.names = FALSE)
  if (!length(flat)) {
    return(data.frame(issue = character(0), n = integer(0)))
  }
  nonfinite <- sum(!is.finite(flat))
  if (!nonfinite) {
    return(data.frame(issue = character(0), n = integer(0)))
  }
  data.frame(issue = "nonfinite_effect_draws", n = nonfinite)
}

drm_finalize_effect <- function(out, engines, draw, values = list()) {
  draw_issues <- drm_effect_draw_issues(engines, draw)
  value_issues <- drm_value_issues(values)
  attr(out, "uncertainty_issues") <- draw_issues
  attr(out, "value_issues") <- value_issues
  if (nrow(draw_issues) > 0L) {
    cli::cli_warn(c(
      "Effect evidence is partial for one or more nodes.",
      "i" = "See {.code attr(x, \"uncertainty_issues\")} for the affected node/component. Non-converged fits are flagged; components with unavailable or invalid covariance use their fitted point estimate in parametric draws."
    ))
  }
  if (nrow(value_issues) > 0L) {
    cli::cli_warn(c(
      "Some effect draws were non-finite and were excluded from the summary.",
      "i" = "See {.code attr(x, \"value_issues\")} for the number of excluded draws."
    ))
  }
  out
}

drm_validate_effect_args <- function(object, from, to) {
  if (!to %in% object$endogenous) {
    cli::cli_abort("{.arg to} = {.val {to}} must be an endogenous node.")
  }
  if (identical(from, to)) {
    cli::cli_abort("{.arg from} and {.arg to} must differ.")
  }
}

# The mean/distribution *decomposition* through a declared feedback motif is not
# defined (an equilibrium has no single topological sweep to split). indirect_/
# path_effects refuse a feedback SEM and point to total_effects(), which reports
# the equilibrium total effect via the fixed-point propagator. (0.5.x.)
drm_block_feedback_decomp <- function(object, fn) {
  if (length(drm_feedback_nodes(object)) > 0L) {
    cli::cli_abort(c(
      "{.fn {fn}} is not defined for a SEM with a declared feedback motif.",
      "x" = "A mean/distribution decomposition needs a topological order, which a cycle lacks.",
      "i" = "Use {.fn total_effects} for the equilibrium total effect; see {.file docs/design/10-cyclic-feedback.md}."
    ))
  }
}


# Analytic functional contrast with a clear abort when the family/target has no
# closed form (OQ-11). Keeps the error message in one place for direct/total.
drm_analytic_or_abort <- function(
  engines,
  scen,
  to,
  active,
  mediation,
  target,
  threshold,
  prob,
  B,
  draw,
  seed
) {
  vals <- drm_functional_contrast_analytic(
    engines,
    scen,
    to,
    active,
    mediation,
    target,
    threshold,
    prob,
    B,
    draw,
    seed
  )
  if (is.null(vals)) {
    fam <- engines[[to]]$family
    cli::cli_abort(c(
      "No closed-form {.val {target}} functional for the {.val {fam}} family.",
      "i" = "Analytic functionals are offered for gaussian and poisson; use {.code functional = \"simulate\"} otherwise."
    ))
  }
  vals
}

#' Response-scale direct (controlled) effect of a predictor on a node
#'
#' The controlled direct effect holds all mediators at their observed values and
#' changes only `from`, so only the arrow(s) from `from` directly into `to`
#' operate. Reported as the population-average change in the chosen `target`
#' functional of `to` for a one-SD (numeric) or first-to-second-level (factor)
#' change in `from`. The fitted direct coefficients are attached as a
#' `coefficients` attribute.
#'
#' @param object A `drm_sem` object.
#' @param from Predictor variable or node name.
#' @param to Endogenous target node.
#' @param component Optional component filter for the attached coefficient table.
#' @param target Functional of the outcome distribution to report the effect on:
#'   `"mean"` (default), `"p_gt"` (Pr(Y > `threshold`)), `"p_zero"` (Pr(Y = 0)),
#'   `"var"` (Var(Y)), or `"quantile"` (the `prob`-quantile). Non-mean targets
#'   simulate the outcome from its family (OQ-11) — most useful when a path moves
#'   only `sigma`/`zi`/`nu`, which can shift a tail probability or quantile while
#'   leaving the mean nearly unchanged.
#' @param threshold Cutoff for `target = "p_gt"`.
#' @param prob Probability for `target = "quantile"` (default `0.5`, the median).
#' @param functional How a non-mean `target` is evaluated: `"simulate"` (default;
#'   draw the outcome from its family and summarize) or `"analytic"` (a
#'   closed-form functional of the predicted parameters — no Monte-Carlo noise).
#'   Analytic forms are offered for the gaussian and poisson families (others
#'   abort with a pointer to `"simulate"`), and require mean mediation
#'   (`method = "gcomp"`) so the outcome parameters are deterministic.
#' @param at Optional length-2 contrast values for `from`.
#' @param B Number of uncertainty replicates (coefficient draws) used when
#'   `uncertainty = "parametric"`.
#' @param uncertainty How to propagate parameter uncertainty: `"parametric"`
#'   (draw coefficients from `MVN(coef, vcov)`, the default), `"none"` (MLE point
#'   estimate, no interval), or `"bootstrap"` (cluster/case-resample and refit
#'   per replicate; reports percentile/normal intervals and bootstrap SE).
#' @param nsim Inner distributional realizations per uncertainty draw (used for
#'   non-mean `target`s).
#' @param population `"conditional"` (random effects held at zero, the default)
#'   or `"marginal"` (integrate over the fitted random-effect distribution).
#' @param level Confidence level for the Monte-Carlo interval.
#' @param seed Optional RNG seed.
#' @param draw,n_sim Deprecated aliases for `uncertainty` (`draw = TRUE`/`FALSE`
#'   maps to `"parametric"`/`"none"`) and `nsim`; supplying either emits a
#'   deprecation warning.
#' @param ... Unused.
#' @return A one-row data frame (`from`, `to`, `scale`, `target`, `estimate`,
#'   `conf.low`, `conf.high`) with a `coefficients` attribute. Effect results
#'   also carry `uncertainty_issues` and `value_issues` attributes when a fitted
#'   node cannot contribute full parametric uncertainty or when non-finite
#'   effect draws had to be excluded from the summary.
#' @references
#' \insertRef{Robins1992}{drmSEM}
#'
#' \insertRef{Pearl2001}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#'
#' \insertRef{VanderWeele2015}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' # Controlled direct effect of temp on abundance, with parametric uncertainty.
#' direct_effects(sem, from = "temp", to = "abundance",
#'                uncertainty = "parametric", nsim = 50)
#' }
#' @export
direct_effects <- function(
  object,
  from,
  to,
  component = NULL,
  target = c("mean", "p_gt", "p_zero", "var", "quantile"),
  threshold = 0,
  prob = 0.5,
  functional = c("simulate", "analytic"),
  at = NULL,
  B = 200L,
  uncertainty = NULL,
  nsim = NULL,
  population = NULL,
  level = 0.95,
  seed = NULL,
  draw = NULL,
  n_sim = NULL,
  ...
) {
  target <- match.arg(target)
  functional <- match.arg(functional)
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(
    uncertainty,
    nsim,
    population,
    draw,
    n_sim,
    default_draw = TRUE,
    default_nsim = 50L
  )
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)

  if (identical(ctl$uncertainty, "bootstrap")) {
    orig_val <- if (identical(target, "mean")) {
      drm_effect_contrast(
        engines,
        scen,
        to,
        active = character(0),
        mediation = "mean",
        B = 1L,
        n_sim = 1L,
        draw = FALSE,
        population = ctl$population
      )
    } else if (identical(functional, "analytic")) {
      drm_analytic_or_abort(
        engines,
        scen,
        to,
        active = character(0),
        mediation = "mean",
        target = target,
        threshold = threshold,
        prob = prob,
        B = 1L,
        draw = FALSE
      )
    } else {
      drm_functional_contrast(
        engines,
        scen,
        to,
        active = character(0),
        mediation = "distribution",
        target = target,
        threshold = threshold,
        B = 1L,
        n_sim = ctl$n_sim,
        draw = FALSE,
        prob = prob,
        population = ctl$population
      )
    }
    orig_est <- orig_val[[1L]]

    if (!is.null(seed)) {
      set.seed(seed)
    }
    boot_vals <- numeric(B)
    for (b in seq_len(B)) {
      boot_dat <- drm_resample_data(object)
      boot_sem <- drm_bootstrap_refit_sem(object, boot_dat)
      if (is.null(boot_sem)) {
        boot_vals[[b]] <- NA_real_
        next
      }
      b_engs <- drm_engines_from_sem(boot_sem)
      b_scen <- drm_build_scenarios(boot_sem, from, at)
      b_val <- if (identical(target, "mean")) {
        drm_effect_contrast(
          b_engs,
          b_scen,
          to,
          active = character(0),
          mediation = "mean",
          B = 1L,
          n_sim = 1L,
          draw = FALSE,
          population = ctl$population
        )
      } else if (identical(functional, "analytic")) {
        drm_analytic_or_abort(
          b_engs,
          b_scen,
          to,
          active = character(0),
          mediation = "mean",
          target = target,
          threshold = threshold,
          prob = prob,
          B = 1L,
          draw = FALSE
        )
      } else {
        drm_functional_contrast(
          b_engs,
          b_scen,
          to,
          active = character(0),
          mediation = "distribution",
          target = target,
          threshold = threshold,
          B = 1L,
          n_sim = ctl$n_sim,
          draw = FALSE,
          prob = prob,
          population = ctl$population
        )
      }
      boot_vals[[b]] <- b_val[[1L]]
    }
    summ <- drm_summ_boot(orig_est, boot_vals, level)
    out <- cbind(
      data.frame(
        from = from,
        to = to,
        scale = "response",
        target = target,
        stringsAsFactors = FALSE
      ),
      summ
    )
    ptab <- paths(object)
    ptab <- ptab[ptab$to == to & ptab$from == from, , drop = FALSE]
    if (!is.null(component)) {
      ptab <- ptab[ptab$component %in% component, , drop = FALSE]
    }
    attr(out, "coefficients") <- ptab
    attr(out, "boot_se") <- attr(summ, "boot_se")
    attr(out, "boot_ci_percentile") <- attr(summ, "boot_ci_percentile")
    attr(out, "boot_ci_normal") <- attr(summ, "boot_ci_normal")
    attr(out, "boot_replicates") <- attr(summ, "boot_replicates")
    attr(out, "boot_converged") <- attr(summ, "boot_converged")
    out <- drm_finalize_effect(out, engines, FALSE, list(boot_vals))
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }

  vals <- if (identical(target, "mean")) {
    drm_effect_contrast(
      engines,
      scen,
      to,
      active = character(0),
      mediation = "mean",
      B = B,
      n_sim = 1L,
      draw = ctl$draw,
      seed = seed,
      population = ctl$population
    )
  } else if (identical(functional, "analytic")) {
    drm_analytic_or_abort(
      engines,
      scen,
      to,
      active = character(0),
      mediation = "mean",
      target = target,
      threshold = threshold,
      prob = prob,
      B = B,
      draw = ctl$draw,
      seed = seed
    )
  } else {
    drm_functional_contrast(
      engines,
      scen,
      to,
      active = character(0),
      mediation = "distribution",
      target = target,
      threshold = threshold,
      B = B,
      n_sim = ctl$n_sim,
      draw = ctl$draw,
      seed = seed,
      prob = prob,
      population = ctl$population
    )
  }
  out <- cbind(
    data.frame(
      from = from,
      to = to,
      scale = "response",
      target = target,
      stringsAsFactors = FALSE
    ),
    drm_summ(vals, level)
  )
  ptab <- paths(object)
  ptab <- ptab[ptab$to == to & ptab$from == from, , drop = FALSE]
  if (!is.null(component)) {
    ptab <- ptab[ptab$component %in% component, , drop = FALSE]
  }
  attr(out, "coefficients") <- ptab
  out <- drm_finalize_effect(out, engines, ctl$draw, list(vals))
  class(out) <- c("drm_effect", "data.frame")
  out
}

#' Total effect of a predictor on a node by simulation
#'
#' Propagates a do()-style change in `from` through the whole DAG (all mediators
#' respond) and reports the population-average change in the chosen `target`
#' functional of `to`. With `method = "simulate"`, mediators pass realized draws
#' from their families, so effects flowing through a mediator's scale,
#' zero-inflation, or shape (distribution-mediated paths) are included; with
#' `method = "gcomp"` only the mediator means propagate.
#'
#' **Feedback SEMs.** When the model declares a feedback motif (see [drm_cycle()]),
#' the total effect is the system's **equilibrium** response, computed by
#' iterating the mean-propagation map to its fixed point rather than by a single
#' topological sweep. Only `target = "mean"` is supported (the equilibrium is on
#' the deterministic mean map), the `mediation` column reads `"equilibrium"`, and
#' if the feedback diverges (no stable equilibrium, spectral radius `>= 1`) the
#' estimate is reported as `NA` with a warning — never a fabricated number. The
#' mean/distribution decomposition through a cycle is out of scope, so
#' [indirect_effects()] / [path_effects()] refuse a feedback SEM. See
#' `docs/design/10-cyclic-feedback.md`.
#'
#' @inheritParams direct_effects
#' @param method `"gcomp"` (mean mediation: deterministic g-computation on
#'   mediator expectations, the default) or `"simulate"` (mediators pass realized
#'   draws from their fitted families, capturing distribution-mediated paths).
#' @param target Functional of the outcome distribution to report the effect on:
#'   `"mean"` (default), `"p_gt"` (Pr(Y > `threshold`)), `"p_zero"` (Pr(Y = 0)),
#'   `"var"` (Var(Y)), or `"quantile"` (the `prob`-quantile). Distributional
#'   targets simulate the outcome from its family (OQ-11); see
#'   `docs/design/02-effect-calculus.md`. For a feedback SEM only `"mean"` (the
#'   equilibrium response) is defined.
#' @param threshold Cutoff for `target = "p_gt"`.
#' @param prob Probability for `target = "quantile"` (default `0.5`, the median).
#' @param mediation Deprecated alias for `method` (`"mean"` maps to `"gcomp"`,
#'   `"distribution"` to `"simulate"`); supplying it emits a deprecation warning.
#' @return A one-row `drm_effect` data frame. See [direct_effects()] for the
#'   diagnostic attributes attached when parametric uncertainty is partial.
#' @references
#' \insertRef{Pearl2001}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#'
#' \insertRef{Imai2010}{drmSEM}
#'
#' \insertRef{VanderWeele2015}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' # Total effect of temp on abundance, mediators allowed to respond by simulation.
#' total_effects(sem, from = "temp", to = "abundance",
#'               method = "simulate", uncertainty = "parametric", nsim = 50)
#' }
#' @export
total_effects <- function(
  object,
  from,
  to,
  method = NULL,
  target = c("mean", "p_gt", "p_zero", "var", "quantile"),
  threshold = 0,
  prob = 0.5,
  functional = c("simulate", "analytic"),
  at = NULL,
  B = 200L,
  uncertainty = NULL,
  nsim = NULL,
  population = NULL,
  level = 0.95,
  seed = NULL,
  mediation = NULL,
  draw = NULL,
  n_sim = NULL,
  ...
) {
  target <- match.arg(target)
  functional <- match.arg(functional)
  mediation_resolved <- drm_resolve_mediation(method, mediation)
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(
    uncertainty,
    nsim,
    population,
    draw,
    n_sim,
    default_draw = TRUE,
    default_nsim = 50L
  )
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)

  # Feedback SEM: the total effect is the system's EQUILIBRIUM response, computed
  # by the fixed-point propagator rather than a single topological sweep (0.5.x).
  # The equilibrium is on the deterministic multi-component map, so only target = "mean" is
  # supported; non-convergence (no stable equilibrium) is reported honestly as NA.
  if (length(drm_feedback_nodes(object)) > 0L || identical(mediation_resolved, "equilibrium")) {
    if (!identical(target, "mean")) {
      cli::cli_abort(c(
        "Outcome functionals are not yet defined through a feedback motif.",
        "i" = "Only {.code target = \"mean\"} (the equilibrium mean response) is supported for a feedback SEM."
      ))
    }
    eq <- drm_equilibrium_contrast(engines, scen, to, B, ctl$draw, seed)
    summ <- if (isTRUE(eq$converged)) {
      drm_summ(eq$vals, level)
    } else {
      cli::cli_warn(c(
        "The feedback system did not reach a stable equilibrium (spectral radius >= 1 or non-contracting map).",
        "i" = "No population-average equilibrium effect is defined; reporting {.val NA}."
      ))
      data.frame(estimate = NA_real_, conf.low = NA_real_, conf.high = NA_real_)
    }
    out <- cbind(
      data.frame(
        from = from,
        to = to,
        scale = "response",
        mediation = "equilibrium",
        target = target,
        stringsAsFactors = FALSE
      ),
      summ
    )
    attr(out, "converged") <- eq$converged
    attr(out, "status") <- eq$status
    attr(out, "spectral_radius") <- eq$spectral_radius
    attr(out, "contraction_constant") <- eq$contraction_constant
    out <- drm_finalize_effect(out, engines, ctl$draw, list(eq$vals))
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }

  active <- setdiff(object$endogenous, c(from, to))
  # Analytic functionals need deterministic outcome params, i.e. mean mediation.
  if (
    identical(functional, "analytic") &&
      !identical(target, "mean") &&
      !identical(mediation_resolved, "mean")
  ) {
    cli::cli_abort(c(
      "{.code functional = \"analytic\"} requires mean mediation.",
      "i" = "Use {.code method = \"gcomp\"} with the analytic functional, or {.code functional = \"simulate\"} with {.code method = \"simulate\"}."
    ))
  }

  if (identical(ctl$uncertainty, "bootstrap")) {
    orig_val <- if (identical(target, "mean")) {
      drm_effect_contrast(
        engines,
        scen,
        to,
        active = active,
        mediation = mediation_resolved,
        B = 1L,
        n_sim = ctl$n_sim,
        draw = FALSE,
        population = ctl$population
      )
    } else if (identical(functional, "analytic")) {
      drm_analytic_or_abort(
        engines,
        scen,
        to,
        active = active,
        mediation = mediation_resolved,
        target = target,
        threshold = threshold,
        prob = prob,
        B = 1L,
        draw = FALSE
      )
    } else {
      drm_functional_contrast(
        engines,
        scen,
        to,
        active = active,
        mediation = mediation_resolved,
        target = target,
        threshold = threshold,
        B = 1L,
        n_sim = ctl$n_sim,
        draw = FALSE,
        prob = prob,
        population = ctl$population
      )
    }
    orig_est <- orig_val[[1L]]

    if (!is.null(seed)) {
      set.seed(seed)
    }
    boot_vals <- numeric(B)
    for (b in seq_len(B)) {
      boot_dat <- drm_resample_data(object)
      boot_sem <- drm_bootstrap_refit_sem(object, boot_dat)
      if (is.null(boot_sem)) {
        boot_vals[[b]] <- NA_real_
        next
      }
      b_engs <- drm_engines_from_sem(boot_sem)
      b_scen <- drm_build_scenarios(boot_sem, from, at)
      b_val <- if (identical(target, "mean")) {
        drm_effect_contrast(
          b_engs,
          b_scen,
          to,
          active = active,
          mediation = mediation_resolved,
          B = 1L,
          n_sim = ctl$n_sim,
          draw = FALSE,
          population = ctl$population
        )
      } else if (identical(functional, "analytic")) {
        drm_analytic_or_abort(
          b_engs,
          b_scen,
          to,
          active = active,
          mediation = mediation_resolved,
          target = target,
          threshold = threshold,
          prob = prob,
          B = 1L,
          draw = FALSE
        )
      } else {
        drm_functional_contrast(
          b_engs,
          b_scen,
          to,
          active = active,
          mediation = mediation_resolved,
          target = target,
          threshold = threshold,
          B = 1L,
          n_sim = ctl$n_sim,
          draw = FALSE,
          prob = prob,
          population = ctl$population
        )
      }
      boot_vals[[b]] <- b_val[[1L]]
    }
    summ <- drm_summ_boot(orig_est, boot_vals, level)
    out <- cbind(
      data.frame(
        from = from,
        to = to,
        scale = "response",
        mediation = mediation_resolved,
        target = target,
        stringsAsFactors = FALSE
      ),
      summ
    )
    attr(out, "boot_se") <- attr(summ, "boot_se")
    attr(out, "boot_ci_percentile") <- attr(summ, "boot_ci_percentile")
    attr(out, "boot_ci_normal") <- attr(summ, "boot_ci_normal")
    attr(out, "boot_replicates") <- attr(summ, "boot_replicates")
    attr(out, "boot_converged") <- attr(summ, "boot_converged")
    out <- drm_finalize_effect(out, engines, FALSE, list(boot_vals))
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }

  vals <- if (identical(target, "mean")) {
    drm_effect_contrast(
      engines,
      scen,
      to,
      active = active,
      mediation = mediation_resolved,
      B = B,
      n_sim = ctl$n_sim,
      draw = ctl$draw,
      seed = seed,
      population = ctl$population
    )
  } else if (identical(functional, "analytic")) {
    drm_analytic_or_abort(
      engines,
      scen,
      to,
      active = active,
      mediation = mediation_resolved,
      target = target,
      threshold = threshold,
      prob = prob,
      B = B,
      draw = ctl$draw,
      seed = seed
    )
  } else {
    drm_functional_contrast(
      engines,
      scen,
      to,
      active = active,
      mediation = mediation_resolved,
      target = target,
      threshold = threshold,
      B = B,
      n_sim = ctl$n_sim,
      draw = ctl$draw,
      seed = seed,
      prob = prob,
      population = ctl$population
    )
  }
  out <- cbind(
    data.frame(
      from = from,
      to = to,
      scale = "response",
      mediation = mediation_resolved,
      target = target,
      stringsAsFactors = FALSE
    ),
    drm_summ(vals, level)
  )
  out <- drm_finalize_effect(out, engines, ctl$draw, list(vals))
  class(out) <- c("drm_effect", "data.frame")
  out
}

#' @rdname total_effects
#' @export
simulate_effects <- total_effects

#' Indirect effect of a predictor on a node, with a distributional decomposition
#'
#' The indirect effect is the simulation-based total path effect (mediators in
#' `through` allowed to respond) minus the controlled direct effect. It is
#' decomposed into a **mean-mediated** part (mediator means propagate) and a
#' **distribution-mediated** part (the extra effect that appears when mediators
#' pass realized draws, i.e. flowing through mediator scale / zero-inflation /
#' shape).
#'
#' The controlled and natural direct/indirect estimands and their
#' identification under the counterfactual framework are due to Pearl (2001),
#' Robins & Greenland (1992), Imai et al. (2010), and VanderWeele (2015); the
#' four-way decomposition under exposure–mediator interaction is VanderWeele
#' (2014); the interventional estimand for multi-mediator settings is
#' Vansteelandt & Daniel (2017). The **distribution-mediated** row reported
#' here is a `drmSEM` construction: it isolates the Jensen-gap part of an
#' indirect effect that flows through a mediator's higher-moment components
#' (`sigma`, `zi`, `nu`), with no coefficient-product analogue. The
#' construction sits on top of the cited mediation framework — it does not
#' replace any of these estimands.
#'
#' @inheritParams total_effects
#' @param through Optional set of mediator node names to route through. Defaults
#'   to all mediators between `from` and `to`.
#' @param effect `"controlled"` (default) decomposes the total into a controlled
#'   direct effect (mediators at observed values) plus mean-mediated and
#'   distribution-mediated parts. `"natural"` reports the cross-world natural
#'   direct/indirect effects (Pearl/Imai), holding the mediators at their
#'   predicted `M(x0)` / `M(x1)` distributions; see
#'   `docs/design/02-effect-calculus.md`.
#' @details
#' `indirect_effects()` does not take a `method` argument: the controlled
#' decomposition is formed from *both* the mean-mediated and
#' distribution-mediated legs, and the natural decomposition always uses
#' distribution mediation, so neither has a single mean/distribution choice to
#' make. The shared `uncertainty`, `nsim`, and `population` controls apply as
#' elsewhere.
#'
#' A non-mean `target` (OQ-11) is supported for `effect = "controlled"`: every
#' leg then reports the contrast on that functional of the outcome (e.g. the
#' indirect change in `Pr(Y = 0)` or a tail quantile routed through the
#' mediators), and the mean-/distribution-mediated split still closes
#' (`indirect = mean_mediated + distribution_mediated`). `effect = "natural"`
#' supports only `target = "mean"` (the cross-world functional contrast is open,
#' OQ-8/OQ-11).
#' @return A `drm_effect` data frame. For `effect = "controlled"`, rows
#'   `total_path`, `direct`, `indirect`, `mean_mediated`, `distribution_mediated`
#'   and a `target` column naming the reported functional. For
#'   `effect = "natural"`, rows `total_path`, `natural_direct`,
#'   `natural_indirect`, `mediated_interaction`. The returned object carries
#'   `uncertainty_issues` and `value_issues` attributes when interval evidence is
#'   partial.
#' @references
#' \insertRef{Robins1992}{drmSEM}
#'
#' \insertRef{Pearl2001}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#'
#' \insertRef{Imai2010}{drmSEM}
#'
#' \insertRef{VanderWeele2014}{drmSEM}
#'
#' \insertRef{VanderWeele2015}{drmSEM}
#'
#' \insertRef{Vansteelandt2017}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' # Indirect effect of temp on abundance routed through size.
#' indirect_effects(sem, from = "temp", to = "abundance", through = "size",
#'                  uncertainty = "parametric", nsim = 50)
#' }
#' @export
indirect_effects <- function(
  object,
  from,
  to,
  through = NULL,
  effect = c("controlled", "natural"),
  target = c("mean", "p_gt", "p_zero", "var", "quantile"),
  threshold = 0,
  prob = 0.5,
  at = NULL,
  B = 200L,
  uncertainty = NULL,
  nsim = NULL,
  population = NULL,
  level = 0.95,
  seed = NULL,
  draw = NULL,
  n_sim = NULL,
  ...
) {
  effect <- match.arg(effect)
  target <- match.arg(target)
  drm_validate_effect_args(object, from, to)
  drm_block_feedback_decomp(object, "indirect_effects")
  # Natural (cross-world) effects are mean-only here: the cross-world functional
  # contrast under arbitrary links is open (OQ-8/OQ-11). Outcome functionals ride
  # the controlled decomposition.
  if (identical(effect, "natural") && !identical(target, "mean")) {
    cli::cli_abort(c(
      "Outcome functionals are only implemented for the controlled decomposition.",
      "x" = "{.code effect = \"natural\"} supports only {.code target = \"mean\"}.",
      "i" = "Use {.code effect = \"controlled\"} for a non-mean {.arg target}; cross-world functionals are open (OQ-8/OQ-11)."
    ))
  }
  ctl <- drm_effect_controls(
    uncertainty,
    nsim,
    population,
    draw,
    n_sim,
    default_draw = TRUE,
    default_nsim = 50L
  )
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)
  all_med <- setdiff(object$endogenous, c(from, to))
  active <- if (is.null(through)) all_med else intersect(through, all_med)

  if (identical(effect, "natural")) {
    if (identical(ctl$uncertainty, "bootstrap")) {
      orig_mat <- drm_natural_target(
        engines,
        scen,
        scen$column,
        to,
        active,
        "distribution",
        beta_list = NULL,
        n_sim = ctl$n_sim,
        population = ctl$population
      )
      if (!is.null(seed)) {
        set.seed(seed)
      }
      mat <- matrix(NA_real_, B, 3L, dimnames = list(NULL, c("nde", "nie", "total")))
      for (bi in seq_len(B)) {
        boot_dat <- drm_resample_data(object)
        boot_sem <- drm_bootstrap_refit_sem(object, boot_dat)
        if (is.null(boot_sem)) {
          next
        }
        b_engs <- drm_engines_from_sem(boot_sem)
        b_scen <- drm_build_scenarios(boot_sem, from, at)
        mat[bi, ] <- drm_natural_target(
          b_engs,
          b_scen,
          b_scen$column,
          to,
          active,
          "distribution",
          beta_list = NULL,
          n_sim = ctl$n_sim,
          population = ctl$population
        )
      }
      rows <- rbind(
        cbind(
          data.frame(quantity = "total_path"),
          drm_summ_boot(orig_mat[["total"]], mat[, "total"], level)
        ),
        cbind(
          data.frame(quantity = "natural_direct"),
          drm_summ_boot(orig_mat[["nde"]], mat[, "nde"], level)
        ),
        cbind(
          data.frame(quantity = "natural_indirect"),
          drm_summ_boot(orig_mat[["nie"]], mat[, "nie"], level)
        ),
        cbind(
          data.frame(quantity = "mediated_interaction"),
          drm_summ_boot(
            orig_mat[["total"]] - orig_mat[["nde"]] - orig_mat[["nie"]],
            mat[, "total"] - mat[, "nde"] - mat[, "nie"],
            level
          )
        )
      )
      out <- cbind(
        data.frame(
          from = from,
          to = to,
          through = paste(active, collapse = ", "),
          stringsAsFactors = FALSE
        ),
        rows
      )
      rownames(out) <- NULL
      out <- drm_finalize_effect(out, engines, FALSE, list(mat))
      class(out) <- c("drm_effect", "data.frame")
      return(out)
    }

    if (!is.null(seed)) {
      set.seed(seed)
    }
    reps <- if (isTRUE(ctl$draw)) B else 1L
    mat <- matrix(
      NA_real_,
      reps,
      3L,
      dimnames = list(NULL, c("nde", "nie", "total"))
    )
    for (bi in seq_len(reps)) {
      beta_list <- lapply(engines, drm_draw_beta, draw = ctl$draw)
      names(beta_list) <- names(engines)
      mat[bi, ] <- drm_natural_target(
        engines,
        scen,
        scen$column,
        to,
        active,
        "distribution",
        beta_list,
        ctl$n_sim,
        population = ctl$population
      )
    }
    rows <- rbind(
      cbind(
        data.frame(quantity = "total_path"),
        drm_summ(mat[, "total"], level)
      ),
      cbind(
        data.frame(quantity = "natural_direct"),
        drm_summ(mat[, "nde"], level)
      ),
      cbind(
        data.frame(quantity = "natural_indirect"),
        drm_summ(mat[, "nie"], level)
      ),
      cbind(
        data.frame(quantity = "mediated_interaction"),
        drm_summ(mat[, "total"] - mat[, "nde"] - mat[, "nie"], level)
      )
    )
    out <- cbind(
      data.frame(
        from = from,
        to = to,
        through = paste(active, collapse = ", "),
        stringsAsFactors = FALSE
      ),
      rows
    )
    rownames(out) <- NULL
    out <- drm_finalize_effect(out, engines, ctl$draw, list(mat))
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }

  if (identical(ctl$uncertainty, "bootstrap")) {
    orig_legs <- drm_decomp_legs(
      engines,
      scen,
      to,
      active,
      B = 1L,
      n_sim = ctl$n_sim,
      draw = FALSE,
      target = target,
      threshold = threshold,
      prob = prob,
      population = ctl$population
    )
    orig_cde <- orig_legs[1, "cde"]
    orig_tot_mean <- orig_legs[1, "tot_mean"]
    orig_tot_dist <- orig_legs[1, "tot_dist"]
    orig_ind_mean <- orig_tot_mean - orig_cde
    orig_ind_dist <- orig_tot_dist - orig_cde
    orig_dist_only <- orig_tot_dist - orig_tot_mean

    if (!is.null(seed)) {
      set.seed(seed)
    }
    boot_mat <- matrix(
      NA_real_,
      B,
      5L,
      dimnames = list(NULL, c("total_path", "direct", "indirect", "mean_mediated", "distribution_mediated"))
    )
    for (b in seq_len(B)) {
      boot_dat <- drm_resample_data(object)
      boot_sem <- drm_bootstrap_refit_sem(object, boot_dat)
      if (is.null(boot_sem)) {
        next
      }
      b_engs <- drm_engines_from_sem(boot_sem)
      b_scen <- drm_build_scenarios(boot_sem, from, at)
      b_legs <- drm_decomp_legs(
        b_engs,
        b_scen,
        to,
        active,
        B = 1L,
        n_sim = ctl$n_sim,
        draw = FALSE,
        target = target,
        threshold = threshold,
        prob = prob,
        population = ctl$population
      )
      b_cde <- b_legs[1, "cde"]
      b_tot_mean <- b_legs[1, "tot_mean"]
      b_tot_dist <- b_legs[1, "tot_dist"]
      boot_mat[b, "total_path"] <- b_tot_dist
      boot_mat[b, "direct"] <- b_cde
      boot_mat[b, "indirect"] <- b_tot_dist - b_cde
      boot_mat[b, "mean_mediated"] <- b_tot_mean - b_cde
      boot_mat[b, "distribution_mediated"] <- b_tot_dist - b_tot_mean
    }
    rows <- rbind(
      cbind(
        data.frame(quantity = "total_path"),
        drm_summ_boot(orig_tot_dist, boot_mat[, "total_path"], level)
      ),
      cbind(
        data.frame(quantity = "direct"),
        drm_summ_boot(orig_cde, boot_mat[, "direct"], level)
      ),
      cbind(
        data.frame(quantity = "indirect"),
        drm_summ_boot(orig_ind_dist, boot_mat[, "indirect"], level)
      ),
      cbind(
        data.frame(quantity = "mean_mediated"),
        drm_summ_boot(orig_ind_mean, boot_mat[, "mean_mediated"], level)
      ),
      cbind(
        data.frame(quantity = "distribution_mediated"),
        drm_summ_boot(orig_dist_only, boot_mat[, "distribution_mediated"], level)
      )
    )
    out <- cbind(
      data.frame(
        from = from,
        to = to,
        through = paste(active, collapse = ", "),
        target = target,
        stringsAsFactors = FALSE
      ),
      rows
    )
    rownames(out) <- NULL
    out <- drm_finalize_effect(out, engines, FALSE, list(boot_mat))
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }

  # Paired three-leg decomposition: a shared coefficient draw per replicate makes
  # mean_mediated and distribution_mediated valid common-random-numbers contrasts.
  # With a non-mean `target` the legs report the contrast on that functional.
  legs <- drm_decomp_legs(
    engines,
    scen,
    to,
    active,
    B,
    ctl$n_sim,
    ctl$draw,
    seed,
    target = target,
    threshold = threshold,
    prob = prob,
    population = ctl$population
  )
  cde <- legs[, "cde"]
  tot_mean <- legs[, "tot_mean"]
  tot_dist <- legs[, "tot_dist"]

  ind_mean <- tot_mean - cde
  ind_dist <- tot_dist - cde
  dist_only <- tot_dist - tot_mean

  rows <- rbind(
    cbind(data.frame(quantity = "total_path"), drm_summ(tot_dist, level)),
    cbind(data.frame(quantity = "direct"), drm_summ(cde, level)),
    cbind(data.frame(quantity = "indirect"), drm_summ(ind_dist, level)),
    cbind(data.frame(quantity = "mean_mediated"), drm_summ(ind_mean, level)),
    cbind(
      data.frame(quantity = "distribution_mediated"),
      drm_summ(dist_only, level)
    )
  )
  out <- cbind(
    data.frame(
      from = from,
      to = to,
      through = paste(active, collapse = ", "),
      target = target,
      stringsAsFactors = FALSE
    ),
    rows
  )
  rownames(out) <- NULL
  out <- drm_finalize_effect(out, engines, ctl$draw, list(legs))
  class(out) <- c("drm_effect", "data.frame")
  out
}

#' @export
print.drm_effect <- function(x, ...) {
  cli::cli_text("<drmSEM effect>")
  df <- as.data.frame(x)
  # drop the helper columns only when they carry no information: `identified`
  # (natural path_effects only) and `mediator` (set-level rows) when all-NA. Value
  # columns (conf.low/high) are kept even when NA so a missing interval is visible.
  for (col in c("identified", "mediator")) {
    if (col %in% names(df) && all(is.na(df[[col]]))) df[[col]] <- NULL
  }
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], function(v) round(v, 4))
  print.data.frame(df, row.names = FALSE)
  co <- attr(x, "coefficients")
  if (!is.null(co) && nrow(co) > 0L) {
    cli::cli_text("Direct fitted coefficients:")
    print(co)
  }
  ui <- attr(x, "uncertainty_issues", exact = TRUE)
  if (!is.null(ui) && nrow(ui) > 0L) {
    cli::cli_text("Uncertainty notes:")
    print(ui, row.names = FALSE)
  }
  vi <- attr(x, "value_issues", exact = TRUE)
  if (!is.null(vi) && nrow(vi) > 0L) {
    cli::cli_text("Effect-draw notes:")
    print(vi, row.names = FALSE)
  }
  invisible(x)
}
