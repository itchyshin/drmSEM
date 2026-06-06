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
      if (length(hit)) col <- hit[[1L]] else
        cli::cli_abort("Cannot find a data column for {.val {from}}.")
    } else {
      cli::cli_abort("{.val {from}} is not a column in the model data.")
    }
  }
  x <- data[[col]]
  if (is.null(at)) {
    if (is.numeric(x)) {
      m <- mean(x, na.rm = TRUE); s <- stats::sd(x, na.rm = TRUE)
      at <- c(m - 0.5 * s, m + 0.5 * s)
    } else {
      lv <- if (is.factor(x)) levels(x) else sort(unique(x))
      if (length(lv) < 2L) cli::cli_abort("{.val {from}} has fewer than two levels.")
      at <- lv[1:2]
    }
  }
  lo <- data; hi <- data
  lo[[col]] <- if (is.factor(x)) factor(at[[1]], levels = levels(x)) else at[[1]]
  hi[[col]] <- if (is.factor(x)) factor(at[[2]], levels = levels(x)) else at[[2]]
  list(lo = lo, hi = hi, at = at, column = col)
}

# Draw-level contrast vector for a given active mediator set.
drm_effect_contrast <- function(engines, scenarios, to, active, mediation,
                                B, n_sim, draw, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    mu_hi <- drm_expected_target(engines, scenarios$hi, to, active, mediation, beta_list, n_sim)
    mu_lo <- drm_expected_target(engines, scenarios$lo, to, active, mediation, beta_list, n_sim)
    vals[[b]] <- mean(mu_hi - mu_lo, na.rm = TRUE)
  }
  vals
}

drm_summ <- function(vals, level = 0.95) {
  a <- (1 - level) / 2
  data.frame(
    estimate = mean(vals, na.rm = TRUE),
    conf.low = if (length(vals) > 1L) stats::quantile(vals, a, na.rm = TRUE, names = FALSE) else NA_real_,
    conf.high = if (length(vals) > 1L) stats::quantile(vals, 1 - a, na.rm = TRUE, names = FALSE) else NA_real_,
    stringsAsFactors = FALSE
  )
}

drm_validate_effect_args <- function(object, from, to) {
  if (!to %in% object$endogenous) {
    cli::cli_abort("{.arg to} = {.val {to}} must be an endogenous node.")
  }
  if (identical(from, to)) cli::cli_abort("{.arg from} and {.arg to} must differ.")
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
#'   or `"var"` (Var(Y)). Non-mean targets simulate the outcome from its family
#'   (OQ-11).
#' @param threshold Cutoff for `target = "p_gt"`.
#' @param at Optional length-2 contrast values for `from`.
#' @param B Number of uncertainty replicates (coefficient draws) used when
#'   `uncertainty = "parametric"`.
#' @param uncertainty How to propagate parameter uncertainty: `"parametric"`
#'   (draw coefficients from `MVN(coef, vcov)`, the default), `"none"` (MLE point
#'   estimate, no interval), or `"bootstrap"` (refit per replicate; not yet
#'   implemented, OQ-10).
#' @param nsim Inner distributional realizations per uncertainty draw (used for
#'   non-mean `target`s).
#' @param population `"conditional"` (random effects held at zero, the default)
#'   or `"marginal"` (integrate over the fitted random-effect distribution; not
#'   yet implemented, OQ-9).
#' @param level Confidence level for the Monte-Carlo interval.
#' @param seed Optional RNG seed.
#' @param draw,n_sim Deprecated aliases for `uncertainty` (`draw = TRUE`/`FALSE`
#'   maps to `"parametric"`/`"none"`) and `nsim`; supplying either emits a
#'   deprecation warning.
#' @param ... Unused.
#' @return A one-row data frame (`from`, `to`, `scale`, `target`, `estimate`,
#'   `conf.low`, `conf.high`) with a `coefficients` attribute.
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
direct_effects <- function(object, from, to, component = NULL,
                           target = c("mean", "p_gt", "p_zero", "var"),
                           threshold = 0, at = NULL, B = 200L,
                           uncertainty = NULL, nsim = NULL, population = NULL,
                           level = 0.95, seed = NULL,
                           draw = NULL, n_sim = NULL, ...) {
  target <- match.arg(target)
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(uncertainty, nsim, population, draw, n_sim,
                             default_draw = TRUE, default_nsim = 50L)
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)
  vals <- if (identical(target, "mean")) {
    drm_effect_contrast(engines, scen, to, active = character(0),
                        mediation = "mean", B = B, n_sim = 1L,
                        draw = ctl$draw, seed = seed)
  } else {
    drm_functional_contrast(engines, scen, to, active = character(0),
                            mediation = "distribution", target = target,
                            threshold = threshold, B = B, n_sim = ctl$n_sim,
                            draw = ctl$draw, seed = seed)
  }
  out <- cbind(data.frame(from = from, to = to, scale = "response",
                          target = target, stringsAsFactors = FALSE),
               drm_summ(vals, level))
  ptab <- paths(object)
  ptab <- ptab[ptab$to == to & ptab$from == from, , drop = FALSE]
  if (!is.null(component)) ptab <- ptab[ptab$component %in% component, , drop = FALSE]
  attr(out, "coefficients") <- ptab
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
#' @inheritParams direct_effects
#' @param method `"gcomp"` (mean mediation: deterministic g-computation on
#'   mediator expectations, the default) or `"simulate"` (mediators pass realized
#'   draws from their fitted families, capturing distribution-mediated paths).
#' @param target Functional of the outcome distribution to report the effect on:
#'   `"mean"` (default), `"p_gt"` (Pr(Y > `threshold`)), `"p_zero"` (Pr(Y = 0)),
#'   or `"var"` (Var(Y)). Distributional targets simulate the outcome from its
#'   family (OQ-11); see `docs/design/02-effect-calculus.md`.
#' @param threshold Cutoff for `target = "p_gt"`.
#' @param mediation Deprecated alias for `method` (`"mean"` maps to `"gcomp"`,
#'   `"distribution"` to `"simulate"`); supplying it emits a deprecation warning.
#' @return A one-row `drm_effect` data frame.
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
total_effects <- function(object, from, to, method = NULL,
                          target = c("mean", "p_gt", "p_zero", "var"),
                          threshold = 0, at = NULL, B = 200L,
                          uncertainty = NULL, nsim = NULL, population = NULL,
                          level = 0.95, seed = NULL,
                          mediation = NULL, draw = NULL, n_sim = NULL, ...) {
  target <- match.arg(target)
  mediation_resolved <- drm_resolve_mediation(method, mediation)
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(uncertainty, nsim, population, draw, n_sim,
                             default_draw = TRUE, default_nsim = 50L)
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)
  active <- setdiff(object$endogenous, c(from, to))
  vals <- if (identical(target, "mean")) {
    drm_effect_contrast(engines, scen, to, active = active,
                        mediation = mediation_resolved, B = B, n_sim = ctl$n_sim,
                        draw = ctl$draw, seed = seed)
  } else {
    drm_functional_contrast(engines, scen, to, active = active,
                            mediation = mediation_resolved, target = target,
                            threshold = threshold, B = B, n_sim = ctl$n_sim,
                            draw = ctl$draw, seed = seed)
  }
  out <- cbind(data.frame(from = from, to = to, scale = "response",
                          mediation = mediation_resolved, target = target,
                          stringsAsFactors = FALSE),
               drm_summ(vals, level))
  class(out) <- c("drm_effect", "data.frame")
  out
}

#' Indirect effect of a predictor on a node, with a distributional decomposition
#'
#' The indirect effect is the simulation-based total path effect (mediators in
#' `through` allowed to respond) minus the controlled direct effect. It is
#' decomposed into a **mean-mediated** part (mediator means propagate) and a
#' **distribution-mediated** part (the extra effect that appears when mediators
#' pass realized draws, i.e. flowing through mediator scale / zero-inflation /
#' shape).
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
#' @return A `drm_effect` data frame. For `effect = "controlled"`, rows
#'   `total_path`, `direct`, `indirect`, `mean_mediated`, `distribution_mediated`.
#'   For `effect = "natural"`, rows `total_path`, `natural_direct`,
#'   `natural_indirect`, `mediated_interaction`.
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
indirect_effects <- function(object, from, to, through = NULL,
                             effect = c("controlled", "natural"),
                             at = NULL, B = 200L,
                             uncertainty = NULL, nsim = NULL, population = NULL,
                             level = 0.95, seed = NULL,
                             draw = NULL, n_sim = NULL, ...) {
  effect <- match.arg(effect)
  drm_validate_effect_args(object, from, to)
  ctl <- drm_effect_controls(uncertainty, nsim, population, draw, n_sim,
                             default_draw = TRUE, default_nsim = 50L)
  drm_require_drmTMB()
  engines <- drm_engines_from_sem(object)
  scen <- drm_build_scenarios(object, from, at)
  all_med <- setdiff(object$endogenous, c(from, to))
  active <- if (is.null(through)) all_med else intersect(through, all_med)

  if (identical(effect, "natural")) {
    if (!is.null(seed)) set.seed(seed)
    reps <- if (isTRUE(ctl$draw)) B else 1L
    mat <- matrix(NA_real_, reps, 3L, dimnames = list(NULL, c("nde", "nie", "total")))
    for (bi in seq_len(reps)) {
      beta_list <- lapply(engines, drm_draw_beta, draw = ctl$draw)
      names(beta_list) <- names(engines)
      mat[bi, ] <- drm_natural_target(engines, scen, scen$column, to, active,
                                      "distribution", beta_list, ctl$n_sim)
    }
    rows <- rbind(
      cbind(data.frame(quantity = "total_path"), drm_summ(mat[, "total"], level)),
      cbind(data.frame(quantity = "natural_direct"), drm_summ(mat[, "nde"], level)),
      cbind(data.frame(quantity = "natural_indirect"), drm_summ(mat[, "nie"], level)),
      cbind(data.frame(quantity = "mediated_interaction"),
            drm_summ(mat[, "total"] - mat[, "nde"] - mat[, "nie"], level))
    )
    out <- cbind(
      data.frame(from = from, to = to, through = paste(active, collapse = ", "),
                 stringsAsFactors = FALSE),
      rows
    )
    rownames(out) <- NULL
    class(out) <- c("drm_effect", "data.frame")
    return(out)
  }


  cde <- drm_effect_contrast(engines, scen, to, character(0), "mean", B, 1L, ctl$draw, seed)
  tot_mean <- drm_effect_contrast(engines, scen, to, active, "mean", B, ctl$n_sim, ctl$draw, seed)
  tot_dist <- drm_effect_contrast(engines, scen, to, active, "distribution", B, ctl$n_sim, ctl$draw, seed)

  ind_mean <- tot_mean - cde
  ind_dist <- tot_dist - cde
  dist_only <- tot_dist - tot_mean

  rows <- rbind(
    cbind(data.frame(quantity = "total_path"), drm_summ(tot_dist, level)),
    cbind(data.frame(quantity = "direct"), drm_summ(cde, level)),
    cbind(data.frame(quantity = "indirect"), drm_summ(ind_dist, level)),
    cbind(data.frame(quantity = "mean_mediated"), drm_summ(ind_mean, level)),
    cbind(data.frame(quantity = "distribution_mediated"), drm_summ(dist_only, level))
  )
  out <- cbind(
    data.frame(from = from, to = to,
               through = paste(active, collapse = ", "),
               stringsAsFactors = FALSE),
    rows
  )
  rownames(out) <- NULL
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
  invisible(x)
}
