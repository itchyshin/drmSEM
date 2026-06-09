#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# OQ-12 — unified effect-API surface.
#
# drmSEM 0.1 exposed the engine-level knobs directly: `mediation`, `draw`, `B`,
# `n_sim`. They map cleanly onto a smaller, shared vocabulary that reads the same
# across direct_effects(), total_effects(), and indirect_effects():
#
#   method      total_effects only: "simulate" (mediator-distribution mediation)
#               / "gcomp" (mean / deterministic g-computation on expectations)
#   uncertainty "parametric" (MVN(coef, vcov) coefficient draws) / "none" (MLE
#               point estimate) / "bootstrap" (refit per replicate -- OQ-10, not
#               yet implemented)
#   nsim        inner distributional realizations per uncertainty draw (was n_sim)
#   population  "conditional" (random effects held at 0, the default) /
#               "marginal" (integrate g^{-1}(eta + b) over the fitted RE
#               distribution -- OQ-9, not yet implemented)
#   target      functional of the outcome distribution (mean / p_gt / p_zero / var)
#
# `B` (number of uncertainty replicates) keeps its name. The old `mediation`,
# `draw`, and `n_sim` arguments still work as deprecated aliases: when supplied
# they emit a deprecation warning and the new arguments take precedence. None of
# the simulation kernels in R/simulate_effects.R change.
# ---------------------------------------------------------------------------

# Emit a deprecation warning for a superseded effect-function argument.
drm_dep_warn <- function(old, new) {
  cli::cli_warn(c(
    "!" = "The {.arg {old}} argument of the drmSEM effect functions is deprecated.",
    "i" = "Use {.arg {new}} instead."
  ))
}

# Resolve the shared computation controls (`uncertainty`, `nsim`, `population`
# and their deprecated aliases) onto the engine knobs. Returns a list with
# `draw` (logical) and `n_sim` (integer). New arguments win over the deprecated
# aliases; not-yet-implemented choices abort with an OQ pointer.
drm_effect_controls <- function(
  uncertainty = NULL,
  nsim = NULL,
  population = NULL,
  draw = NULL,
  n_sim = NULL,
  default_draw = TRUE,
  default_nsim = 50L
) {
  # population --------------------------------------------------------------
  if (!is.null(population)) {
    population <- match.arg(population, c("conditional", "marginal"))
    if (identical(population, "marginal")) {
      cli::cli_abort(c(
        "{.code population = \"marginal\"} is not yet implemented.",
        "i" = "Effects are currently conditional on random effects held at zero (RE = 0).",
        "i" = "Marginalizing over the fitted random-effect distribution is tracked as OQ-9."
      ))
    }
  }

  # uncertainty -> draw -----------------------------------------------------
  draw_out <- default_draw
  if (!is.null(uncertainty)) {
    uncertainty <- match.arg(uncertainty, c("parametric", "none", "bootstrap"))
    if (identical(uncertainty, "bootstrap")) {
      cli::cli_abort(c(
        "{.code uncertainty = \"bootstrap\"} is not yet implemented.",
        "i" = "Use {.val parametric} (MVN(coef, vcov) draws) or {.val none} (point estimate).",
        "i" = "Refit-based bootstrap intervals are tracked as OQ-10."
      ))
    }
    if (!is.null(draw)) {
      cli::cli_warn(
        "Both {.arg uncertainty} and the deprecated {.arg draw} were supplied; using {.arg uncertainty}."
      )
    }
    draw_out <- identical(uncertainty, "parametric")
  } else if (!is.null(draw)) {
    drm_dep_warn("draw", "uncertainty")
    draw_out <- isTRUE(draw)
  }

  # nsim -> n_sim -----------------------------------------------------------
  nsim_out <- default_nsim
  if (!is.null(nsim)) {
    if (!is.null(n_sim)) {
      cli::cli_warn(
        "Both {.arg nsim} and the deprecated {.arg n_sim} were supplied; using {.arg nsim}."
      )
    }
    nsim_out <- as.integer(nsim)
  } else if (!is.null(n_sim)) {
    drm_dep_warn("n_sim", "nsim")
    nsim_out <- as.integer(n_sim)
  }

  list(draw = draw_out, n_sim = nsim_out)
}

# Resolve total_effects()'s mediation selector. `method` (new) supersedes the
# deprecated `mediation`; returns the engine value "mean" / "distribution".
drm_resolve_mediation <- function(method = NULL, mediation = NULL) {
  if (!is.null(method)) {
    method <- match.arg(method, c("simulate", "gcomp"))
    if (!is.null(mediation)) {
      cli::cli_warn(
        "Both {.arg method} and the deprecated {.arg mediation} were supplied; using {.arg method}."
      )
    }
    return(if (identical(method, "simulate")) "distribution" else "mean")
  }
  if (!is.null(mediation)) {
    drm_dep_warn("mediation", "method")
    return(match.arg(mediation, c("mean", "distribution")))
  }
  "mean"
}
