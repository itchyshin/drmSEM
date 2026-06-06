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
  # mean-channel contribution of each mediator (mediator passes only its mean);
  # inclusion - mean_inclusion is then the distribution-mediated channel of Mj.
  mean_inclusion <- stats::setNames(
    lapply(meds, function(mj) contrast(mj, "mean", 1L) - cde), meds
  )
  total_indirect <- tot - cde
  remainder <- total_indirect - Reduce(`+`, inclusion)
  list(total_indirect = total_indirect, inclusion = inclusion,
       exclusion = exclusion, mean_inclusion = mean_inclusion,
       remainder = remainder)
}

# Return a copy of `engines` in which mediator `mediator`'s component `component`
# is FROZEN at the value it takes under `ref_scenario` (the x0 / reference world).
# Implemented by wrapping that node's predict() and splicing the frozen component
# back in before sampling -- no change to drm_propagate. Used to attribute a
# mediator's distribution-mediated effect to one component (OQ-5 per-component).
drm_freeze_engine <- function(engines, mediator, component, ref_scenario) {
  eng <- engines[[mediator]]
  ref_vals <- eng$predict(ref_scenario)[[component]]
  orig_predict <- eng$predict
  eng$predict <- function(scenario, beta = NULL) {
    p <- orig_predict(scenario, beta)
    p[[component]] <- ref_vals[seq_len(nrow(scenario))]
    p
  }
  engines[[mediator]] <- eng
  engines
}

# Per-component attribution for a single mediator `mj` (OQ-5). Splits Mj's
# indirect effect into a mean channel (Mj passes only its mean) and one channel
# per non-mean component (sigma / zi / ...), each the drop in the
# distribution-mediated effect when that component is frozen at its x0 value. A
# component_remainder carries the non-separable part (channels do not partition
# exactly under a nonlinear outcome). Pure function of engines (no drmTMB).
drm_component_contrasts <- function(engines, scenarios, to, mj,
                                    B = 200L, n_sim = 50L, draw = TRUE, seed = NULL) {
  ctr <- function(eng, med) {
    drm_effect_contrast(eng, scenarios, to, active = mj, mediation = med,
                        B = B, n_sim = if (identical(med, "mean")) 1L else n_sim,
                        draw = draw, seed = seed)
  }
  cde <- drm_effect_contrast(engines, scenarios, to, active = character(0),
                             mediation = "mean", B = B, n_sim = 1L,
                             draw = draw, seed = seed)
  full <- ctr(engines, "distribution")        # T_dist({Mj})
  mean_channel <- ctr(engines, "mean") - cde   # Mj's mean channel
  inclusion <- full - cde
  comps <- setdiff(engines[[mj]]$components, "mu")
  channels <- stats::setNames(lapply(comps, function(cc) {
    frozen <- drm_effect_contrast(drm_freeze_engine(engines, mj, cc, scenarios$lo),
                                  scenarios, to, active = mj, mediation = "distribution",
                                  B = B, n_sim = n_sim, draw = draw, seed = seed)
    full - frozen
  }), comps)
  channel_sum <- if (length(channels)) Reduce(`+`, channels) else 0
  remainder <- inclusion - mean_channel - channel_sum
  list(inclusion = inclusion, mean = mean_channel,
       channels = channels, remainder = remainder)
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
#' @param by `"mediator"` (default) reports the per-mediator `inclusion` /
#'   `exclusion` split with an `interaction_remainder`. `"component"` instead
#'   splits each mediator's indirect effect into a `mean_channel` (the mediator
#'   passes only its mean) and one channel per non-mean component
#'   (`sigma_channel`, `zi_channel`, ... -- the drop when that component is frozen
#'   at its reference value), plus a `component_remainder` for the part that does
#'   not separate cleanly (the channels are not an exact partition under a
#'   nonlinear outcome).
#' @return A `drm_effect` data frame with columns `from`, `to`, `through`,
#'   `mediator`, `estimand`, `estimate`, `conf.low`, `conf.high`. For
#'   `by = "mediator"` the `estimand` values are `total_indirect`, `inclusion`,
#'   `exclusion`, `interaction_remainder`; for `by = "component"` they are
#'   `total_indirect`, `mean_channel`, `<component>_channel` (one per non-mean
#'   component), and `component_remainder`.
#' @seealso [indirect_effects()], [total_effects()].
#' @examples
#' \dontrun{
#' # per-mediator attribution of temp's indirect effect on survival
#' path_effects(sem, from = "temp", to = "survival")
#' # split each mediator's effect into mean vs distributional channels
#' path_effects(sem, from = "temp", to = "survival", by = "component")
#' }
#' @export
path_effects <- function(object, from, to, through = NULL,
                         by = c("mediator", "component"),
                         at = NULL, B = 200L,
                         uncertainty = NULL, nsim = NULL, population = NULL,
                         level = 0.95, seed = NULL,
                         draw = NULL, n_sim = NULL, ...) {
  by <- match.arg(by)
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

  add_row <- function(rows, med, estimand, v) {
    rows[[length(rows) + 1L]] <- cbind(
      data.frame(mediator = med, estimand = estimand, stringsAsFactors = FALSE),
      drm_summ(v, level)
    )
    rows
  }
  rows <- add_row(list(), NA_character_, "total_indirect", pc$total_indirect)
  if (identical(by, "mediator")) {
    for (mj in meds) {
      rows <- add_row(rows, mj, "inclusion", pc$inclusion[[mj]])
      rows <- add_row(rows, mj, "exclusion", pc$exclusion[[mj]])
    }
    rows <- add_row(rows, NA_character_, "interaction_remainder", pc$remainder)
  } else {
    for (mj in meds) {
      cc <- drm_component_contrasts(engines, scen, to, mj, B = B,
                                    n_sim = ctl$n_sim, draw = ctl$draw, seed = seed)
      rows <- add_row(rows, mj, "mean_channel", cc$mean)
      for (comp in names(cc$channels)) {
        rows <- add_row(rows, mj, paste0(comp, "_channel"), cc$channels[[comp]])
      }
      rows <- add_row(rows, mj, "component_remainder", cc$remainder)
    }
  }
  out <- cbind(
    data.frame(from = from, to = to, through = paste(meds, collapse = ", "),
               stringsAsFactors = FALSE),
    do.call(rbind, rows)
  )
  rownames(out) <- NULL
  class(out) <- c("drm_effect", "data.frame")
  out
}
