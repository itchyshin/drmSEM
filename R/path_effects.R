#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# OQ-5 — path-specific (per-mediator) effect attribution.
#
# Decompose the set-level indirect effect into per-mediator contributions by
# toggling which mediators are "active" in the propagation -- no new kernel, just
# different active sets fed to drm_effect_contrast(). Two model-based per-mediator
# estimands are reported because they answer different questions and only coincide
# in the additive case:
#
#   inclusion(Mj) = T({Mj}) - T(empty)   -- Mj's path with all others frozen
#   exclusion(Mj) = T(all)   - T(all \ Mj) -- Mj's marginal given all others active
#
# with T(S) the population-average response contrast when the mediators in S
# respond. We ALWAYS also report total_indirect and an explicit
# interaction_remainder = total_indirect - sum(inclusion); it is ~0 only when the
# effects are additive (parallel mediators, no downstream nonlinearity, no
# interaction) and non-zero otherwise -- never silently forced to sum. This is
# model-based attribution, NOT a claim of nonparametric path-specific
# identification (which needs the recanting-witness criterion); see
# docs/design/02-effect-calculus.md. The per-component (mu/sigma/zi) split and the
# cross-world natural variant are the OQ-5 follow-up.
# ---------------------------------------------------------------------------

# Pure kernel: per-mediator inclusion/exclusion/total/remainder contrast vectors
# for a set of mediators. Operates on engines (no drmTMB), so it is unit-tested
# directly with hand-built engines. `mediation` is "distribution" for the
# user-facing accessor and "mean" for deterministic closed-form tests.
drm_path_contrasts <- function(engines, scenarios, to, meds,
                               mediation = "distribution",
                               B = 200L, n_sim = 50L, draw = TRUE, seed = NULL) {
  contrast <- function(active, med, ns) {
    drm_effect_contrast(engines, scenarios, to, active = active,
                        mediation = med, B = B, n_sim = ns, draw = draw, seed = seed)
  }
  cde <- contrast(character(0), "mean", 1L)
  tot <- contrast(meds, mediation, n_sim)
  inclusion <- stats::setNames(
    lapply(meds, function(mj) contrast(mj, mediation, n_sim) - cde), meds
  )
  exclusion <- stats::setNames(
    lapply(meds, function(mj) tot - contrast(setdiff(meds, mj), mediation, n_sim)), meds
  )
  total_indirect <- tot - cde
  remainder <- total_indirect - Reduce(`+`, inclusion)
  list(total_indirect = total_indirect, inclusion = inclusion,
       exclusion = exclusion, remainder = remainder)
}

#' Path-specific (per-mediator) decomposition of an indirect effect
#'
#' Splits the indirect effect of `from` on `to` into a contribution for each
#' mediator, by toggling which mediators are allowed to respond. Two model-based
#' per-mediator quantities are reported:
#'
#' * **inclusion** -- the effect carried by `X -> Mj -> Y` when only `Mj`
#'   responds (all other mediators held at their observed values):
#'   `T({Mj}) - direct`.
#' * **exclusion** -- `Mj`'s marginal contribution when every *other* mediator is
#'   already active: `T(all) - T(all \ Mj)`.
#'
#' These coincide only when the mediators act additively (parallel mediators, no
#' downstream nonlinearity, no exposure-mediator or mediator-mediator
#' interaction). The output therefore **always** includes a `total_indirect` row
#' and an explicit `interaction_remainder = total_indirect - sum(inclusion)`,
#' which is ~0 in the additive case and non-zero otherwise -- the per-mediator
#' effects are never rescaled to force them to sum. This is a model-based
#' decomposition, not a claim of nonparametric path-specific identification; see
#' `docs/design/02-effect-calculus.md`.
#'
#' @inheritParams indirect_effects
#' @param through Optional subset of mediator node names to attribute over
#'   (defaults to all mediators between `from` and `to`).
#' @return A `drm_effect` data frame with columns `from`, `to`, `through`,
#'   `mediator`, `estimand` (`"inclusion"` / `"exclusion"` /
#'   `"total_indirect"` / `"interaction_remainder"`), `estimate`, `conf.low`,
#'   `conf.high`.
#' @seealso [indirect_effects()], [total_effects()].
#' @export
path_effects <- function(object, from, to, through = NULL,
                         at = NULL, B = 200L,
                         uncertainty = NULL, nsim = NULL, population = NULL,
                         level = 0.95, seed = NULL,
                         draw = NULL, n_sim = NULL, ...) {
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(uncertainty, nsim, population, draw, n_sim,
                             default_draw = TRUE, default_nsim = 50L)
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)
  all_med <- setdiff(object$endogenous, c(from, to))
  meds <- if (is.null(through)) all_med else intersect(through, all_med)
  if (length(meds) == 0L) {
    cli::cli_abort("No mediators between {.val {from}} and {.val {to}} to attribute over.")
  }

  pc <- drm_path_contrasts(engines, scen, to, meds, mediation = "distribution",
                           B = B, n_sim = ctl$n_sim, draw = ctl$draw, seed = seed)

  rows <- list(
    cbind(data.frame(mediator = NA_character_, estimand = "total_indirect",
                     stringsAsFactors = FALSE), drm_summ(pc$total_indirect, level))
  )
  for (mj in meds) {
    rows[[length(rows) + 1L]] <- cbind(
      data.frame(mediator = mj, estimand = "inclusion", stringsAsFactors = FALSE),
      drm_summ(pc$inclusion[[mj]], level)
    )
    rows[[length(rows) + 1L]] <- cbind(
      data.frame(mediator = mj, estimand = "exclusion", stringsAsFactors = FALSE),
      drm_summ(pc$exclusion[[mj]], level)
    )
  }
  rows[[length(rows) + 1L]] <- cbind(
    data.frame(mediator = NA_character_, estimand = "interaction_remainder",
               stringsAsFactors = FALSE),
    drm_summ(pc$remainder, level)
  )
  out <- cbind(
    data.frame(from = from, to = to, through = paste(meds, collapse = ", "),
               stringsAsFactors = FALSE),
    do.call(rbind, rows)
  )
  rownames(out) <- NULL
  class(out) <- c("drm_effect", "data.frame")
  out
}
