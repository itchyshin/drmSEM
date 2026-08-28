#' @keywords internal
#' @noRd
NULL

# A variable is "adjacent" to node Y if it is a direct parent of Y on any
# component (the any-component adjacency rule).
drm_is_parent <- function(x, y, edges) {
  any(as.character(edges$from) == x & as.character(edges$to) == y)
}

# Order index of a variable: endogenous nodes use their topological position;
# exogenous variables sort before all nodes (index 0).
drm_order_index <- function(object) {
  idx <- stats::setNames(seq_along(object$order), object$order)
  function(v) {
    if (v %in% names(idx)) idx[[v]] else 0L
  }
}

#' Basis set of independence claims for a distributional SEM
#'
#' The basis set is the collection of non-adjacent variable pairs (X, Y) where Y
#' is endogenous and X is causally no later than Y. Each claim asserts that X has
#' **no effect on any modelled distributional component of Y**, conditional on
#' Y's existing parents. This any-component reading is drmSEM's definition of a
#' missing arrow (see `docs/design/03-dsep.md`).
#'
#' A covariance edge declared with [covary()] (a residual `rho12` or higher-level
#' `corpair` arc) is an allowance that the two responses stay associated, so the
#' `y1 _||_ y2` claim is dropped from the basis set (Shipley's bidirected-edge
#' rule; OQ-14). A declared feedback motif ([drm_cycle()], 0.5) likewise drops
#' independence claims among its nodes — DAG d-separation does not hold across a
#' cycle, and the goodness-of-fit test is scoped to the acyclic part until
#' sigma-separation lands.
#'
#' When `latent =` names **marginalised** latents (`L_M`), claims are generated
#' on the implied MAG by Richardson & Spirtes (2002) Corollary 5.3: each
#' non-adjacent observed pair is conditioned on the **anteriors** of the pair
#' (not on Shipley & Douma's observed parents). Bidirected spouses are not
#' anteriors. Pairwise ⇒ global is licensed when the independence model is a
#' compositional graphoid (Sadeghi & Lauritzen 2014 Thm 3; Lauritzen & Sadeghi
#' 2018 Thm 4) — automatic for homoscedastic all-Gaussian nodes, otherwise
#' assumed via faithfulness (a `cli_inform()` fires for non-Gaussian or
#' `sigma ~` nodes). Selection / conditioned latents are not supported.
#'
#' The any-component reading of an independence claim is a `drmSEM` choice on top
#' of the local-likelihood d-separation framework of Shipley; the d-separation
#' graphical criterion itself is due to Pearl, and the bidirected-edge handling
#' of declared residual correlations follows Shipley's path-analysis treatment.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame with columns `claim`, `x`, `y`, `given` (comma-separated
#'   conditioning set). On a DAG, `given` is Y's parents. On a MAG (`latent =`
#'   supplied), it is `ant({X, Y}) \\ {X, Y}`.
#' @references
#' \insertRef{Shipley2000}{drmSEM}
#'
#' \insertRef{Shipley2009}{drmSEM}
#'
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#'
#' \insertRef{RichardsonSpirtes2002}{drmSEM}
#'
#' \insertRef{SadeghiLauritzen2014}{drmSEM}
#'
#' \insertRef{LauritzenSadeghi2018}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' basis_set(sem)
#' }
#' @export
basis_set <- function(object, ...) {
  UseMethod("basis_set")
}

#' @rdname basis_set
#' @export
basis_set.drm_sem <- function(object, ...) {
  if (length(object$latents)) {
    drm_mag_compositionality_inform(object)
    return(basis_set_mag(object))
  }
  edges <- object$edges
  ord <- drm_order_index(object)
  all_vars <- unique(c(object$endogenous, object$exogenous))
  # A declared covariance edge (residual rho12 / higher-level corpair) is an
  # allowance that y1 and y2 stay associated, so the basis set must NOT claim
  # y1 _||_ y2 (OQ-14; Shipley's bidirected-edge rule).
  #
  # The justification is Shipley & Douma (2021, doi:10.1080/10705511.2020.1871355):
  # a correlated error between two variables is EQUIVALENT to a latent common
  # cause of both (Pearl 2009, thm 5.2.3), so dropping the independence claim is
  # what marginalising over that latent implies. That paper notes piecewiseSEM
  # already did this "even though no theoretical justification for this was
  # provided" -- drmSEM inherits the justification, so it cites the source.
  #
  # The two-variable special case of the MAG layer: a declared covariance is
  # equivalent to a latent common cause (Pearl 2009 thm 5.2.3). When `latent =`
  # is supplied, basis_set_mag() generalises this to the full implied MAG.
  # A declared feedback
  # motif (drm_cycle(), 0.5) likewise drops independence claims among its nodes:
  # DAG d-separation does not apply across the cycle (sigma-separation is
  # deferred; docs/design/10-cyclic-feedback.md). Keyed unordered.
  cov_pairs <- unique(c(
    drm_covariance_pairs(object),
    drm_feedback_pairs(object)
  ))
  rows <- list()
  for (y in object$order) {
    yi <- ord(y)
    parents_y <- drm_parents(y, edges)
    for (x in all_vars) {
      if (identical(x, y)) {
        next
      }
      if (ord(x) > yi) {
        next
      } # X must be causally no later than Y
      if (x %in% parents_y) {
        next
      } # adjacent -> not a missing arrow
      if (drm_is_parent(y, x, edges)) {
        next
      }
      if (paste(pmin(x, y), pmax(x, y), sep = "\r") %in% cov_pairs) {
        next
      }
      rows[[length(rows) + 1L]] <- data.frame(
        x = x,
        y = y,
        given = paste(parents_y, collapse = ", "),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    out <- data.frame(
      claim = character(0),
      x = character(0),
      y = character(0),
      given = character(0),
      stringsAsFactors = FALSE
    )
    return(out)
  }
  out <- do.call(rbind, rows)
  out <- cbind(
    claim = paste0(out$x, " _||_ ", out$y, " | {", out$given, "}"),
    out
  )
  rownames(out) <- NULL
  out
}

#' MAG basis set: Cor. 5.3 pairwise claims with anterior conditioning sets.
#' @keywords internal
#' @noRd
basis_set_mag <- function(object) {
  mag <- object$mag
  if (is.null(mag) || !nrow(mag)) {
    out <- data.frame(
      claim = character(0),
      x = character(0),
      y = character(0),
      given = character(0),
      stringsAsFactors = FALSE
    )
    return(out)
  }
  ord <- drm_order_index(object)
  # MAG is over observed vertices. Emitting claims that name a marginalised
  # latent would test a vertex that is no longer in the graph.
  all_vars <- setdiff(
    unique(c(object$endogenous, object$exogenous)),
    object$latents
  )
  cov_pairs <- unique(c(
    drm_covariance_pairs(object),
    drm_feedback_pairs(object)
  ))
  rows <- list()
  for (y in object$order) {
    yi <- ord(y)
    for (x in all_vars) {
      if (identical(x, y)) {
        next
      }
      if (ord(x) > yi) {
        next
      }
      if (drm_mag_is_adjacent(mag, x, y)) {
        next
      }
      if (paste(pmin(x, y), pmax(x, y), sep = "\r") %in% cov_pairs) {
        next
      }
      given <- drm_mag_anteriors(mag, x, y)
      rows[[length(rows) + 1L]] <- data.frame(
        x = x,
        y = y,
        given = paste(sort(given), collapse = ", "),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(
      claim = character(0),
      x = character(0),
      y = character(0),
      given = character(0),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  out <- cbind(
    claim = paste0(out$x, " _||_ ", out$y, " | {", out$given, "}"),
    out
  )
  rownames(out) <- NULL
  out
}

# Choose the data column to add for variable `v` (node identifier or exogenous).
drm_add_column <- function(v, object) {
  data <- object$data
  if (v %in% names(data)) {
    return(v)
  }
  if (v %in% object$endogenous) {
    ids <- object$records[[v]]$identifiers
    hit <- ids[ids %in% names(data)]
    if (length(hit)) return(hit[[1L]])
  }
  NA_character_
}

#' Test directed-separation claims by likelihood-ratio refits
#'
#' For each claim X _||_ Y in [basis_set()], `dsep()` refits node Y with X added
#' as a fixed-effect predictor to **every modelled distributional component**,
#' and compares it to the base node fit by a likelihood-ratio test. A small
#' p-value means X carries information about some component of Y beyond Y's
#' parents, i.e. a missing arrow.
#'
#' This is the local-likelihood d-separation test of Shipley (2000, 2009),
#' extended in `drmSEM` from a mean-only test to an **any-component** test (the
#' claim that X is irrelevant to *every* modelled distributional parameter of
#' Y). This any-component extension is a `drmSEM` construction; it has been
#' calibrated against the family-grid data-generating processes in
#' `inst/calibration/`.
#'
#' When the SEM declares `latent =` marginalised names, the claims come from the
#' MAG branch of [basis_set()]; the LRT itself is unchanged (any-component).
#'
#' Requires nodes fitted so that refits converge (the declarative [drm_sem()]
#' requests standard errors automatically).
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A data frame of claims with `df`, `LR`, and `p.value`, carrying a
#'   `fisher_c` attribute (see [fisher_c()]). A `status` column records why a
#'   claim was not tested: `"no_data_column"` (the claim's variable is not a
#'   column), `"refit_failed"`, `"n_mismatch"` (the augmented refit used a
#'   different number of observations than the base fit, usually because the
#'   added variable has missing values, so the likelihood ratio would compare two
#'   different samples), `"degenerate"` (non-nested or non-finite), or
#'   `"wrong_scale"` (the added variable is constant within a grouping the node
#'   does not already model, so the LRT would credit one row per observation
#'   while the variable carries only as many independent pieces of information
#'   as there are groups). Only `"ok"` claims enter Fisher's C.
#'
#'   Two further columns report the claim's **scale**. `n_effective` and
#'   `scale_group` are `NA` when the claim's variable varies row by row. When it is
#'   constant within a grouping the node does not already model -- a species-level
#'   trait repeated down to individuals, say -- they name that grouping and its
#'   number of levels, `status` is `"wrong_scale"`, and `dsep()` warns.
#'
#'   That situation matters because the likelihood ratio treats every row as
#'   independent evidence: a chance group-level association is credited with far
#'   more support than it has, so the test **rejects TRUE independences** rather
#'   than missing false ones. Fisher's C therefore excludes these p-values
#'   rather than inheriting the false rejection (D-21). The flattened p-value
#'   stays in the table so the mismatch is inspectable. The remedy is to add the
#'   grouping term to that node so the base and augmented fits share it, then
#'   re-run. drmSEM does not auto-add `(1 | group)`: that would test a different
#'   SEM than the one in [paths()]. Adding the term to only the augmented fit
#'   would compare two different random-effect structures, which is not a valid
#'   likelihood-ratio test.
#' @references
#' \insertRef{Shipley2000}{drmSEM}
#'
#' \insertRef{Shipley2009}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#'
#' \insertRef{Pearl2009}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' dsep(sem)
#' }
#' @export
dsep <- function(object, ...) {
  UseMethod("dsep")
}

#' @rdname dsep
#' @export
dsep.drm_sem <- function(object, ...) {
  drm_require_drmTMB()
  bs <- basis_set(object)
  if (nrow(bs) == 0L) {
    # Saturated DAG: no independence claims to test. Return an empty, typed
    # result (assigning a scalar column to a 0-row data.frame would error).
    cli::cli_warn(
      "Basis set is empty: the graph is fully saturated, no claims to test."
    )
    bs$df <- integer(0)
    bs$LR <- numeric(0)
    bs$p.value <- numeric(0)
    bs$status <- character(0)
    attr(bs, "fisher_c") <- drm_fisher_c_from_p(numeric(0))
    class(bs) <- c("drm_dsep", "data.frame")
    return(bs)
  }
  bs$df <- NA_integer_
  bs$LR <- NA_real_
  bs$p.value <- NA_real_
  bs$status <- "ok"
  # Effective sample size for the claim's added variable. NA means row scale.
  bs$n_effective <- NA_integer_
  bs$scale_group <- NA_character_
  scale_notes <- list()
  # Evaluate augmented refits where the SEM was specified, so a node's
  # structured-effect objects (e.g. a phylo `tree`) resolve (OQ-13).
  refit_env <- if (is.null(object$fit_env)) globalenv() else object$fit_env
  for (i in seq_len(nrow(bs))) {
    y <- bs$y[[i]]
    rec <- object$records[[y]]
    fit <- rec$fit
    add_var <- drm_add_column(bs$x[[i]], object)
    if (is.na(add_var)) {
      bs$status[[i]] <- "no_data_column"
      next
    }
    base <- drm_fit_logLik(fit)
    # A shared bivariate fit models both margins. The any-component claim is
    # about Y only, so augment this margin's dpars and never rho12 (pair-level).
    comps <- rec$components
    if (isTRUE(drm_is_bivariate_fit(fit))) {
      comps <- setdiff(comps, "rho12")
    }
    aug_fit <- drm_refit_augmented(
      fit,
      add_var,
      components = comps,
      env = refit_env
    )
    if (is.null(aug_fit)) {
      bs$status[[i]] <- "refit_failed"
      next
    }
    # A likelihood-ratio test is only meaningful when both fits saw the same
    # observations. If `add_var` carries NAs the augmented refit silently drops
    # those rows, and 2*(aug - base) then compares two different samples --
    # producing a WRONG number rather than an error, which the df_diff guard
    # below cannot catch because the df are still nested.
    # Scale check BEFORE the test: if the added variable is constant within a
    # grouping the node does not already model, the LRT sees one row per
    # observation while the variable carries only n_groups' worth of information,
    # and a chance group-level correlation is credited with far more evidence
    # than it has. That rejects TRUE independences.
    coarse <- drm_coarser_scales(add_var, object$data)
    if (nrow(coarse)) {
      already <- drm_fit_grouping_vars(fit)
      coarse <- coarse[!coarse$group %in% already, , drop = FALSE]
    }
    if (nrow(coarse)) {
      k <- which.min(coarse$n_groups)
      bs$n_effective[[i]] <- coarse$n_groups[[k]]
      bs$scale_group[[i]] <- coarse$group[[k]]
      bs$status[[i]] <- "wrong_scale"
      scale_notes[[length(scale_notes) + 1L]] <- sprintf(
        "%s (varies at the scale of %s: %d groups, not %d rows)",
        add_var, coarse$group[[k]], coarse$n_groups[[k]], nrow(as.data.frame(object$data))
      )
    }
    n_base <- drm_fit_nobs(fit)
    n_aug <- drm_fit_nobs(aug_fit)
    if (!is.na(n_base) && !is.na(n_aug) && n_base != n_aug) {
      bs$status[[i]] <- "n_mismatch"
      next
    }
    aug <- drm_fit_logLik(aug_fit)
    df_diff <- aug$df - base$df
    lr <- 2 * (aug$logLik - base$logLik)
    if (is.na(df_diff) || df_diff <= 0 || is.na(lr)) {
      bs$status[[i]] <- "degenerate"
      next
    }
    bs$df[[i]] <- as.integer(df_diff)
    bs$LR[[i]] <- lr
    bs$p.value[[i]] <- stats::pchisq(lr, df = df_diff, lower.tail = FALSE)
  }
  if (length(scale_notes)) {
    cli::cli_warn(c(
      "{length(scale_notes)} d-separation claim{?s} {?is/are} tested at the wrong scale.",
      "!" = "{.val {unlist(scale_notes)}}",
      "i" = "The likelihood ratio treats every row as independent evidence, so a
             chance group-level association is credited with far more support than it
             has -- this REJECTS TRUE independences rather than missing false ones.",
      "i" = "These claims are excluded from Fisher's C (status {.val wrong_scale}).
             Add the grouping term to that node (e.g. {.code (1 | group)}) so both
             the base and augmented fits share it, then re-run. See the
             {.code n_effective} / {.code scale_group} columns."
    ))
  }
  fc <- drm_fisher_c_from_p(bs$p.value[bs$status == "ok" & !is.na(bs$p.value)])
  attr(bs, "fisher_c") <- fc
  class(bs) <- c("drm_dsep", "data.frame")
  bs
}

drm_fisher_c_from_p <- function(p) {
  # Drop only un-tested claims (NA). A claim with p == 0 (a decisively rejected
  # independence -- the strongest possible evidence of a missing arrow) must NOT
  # be dropped: doing so removes log(0) = -Inf from C and shrinks df, biasing
  # Fisher's C toward non-rejection exactly when the DAG is most wrong. Floor p
  # at the smallest positive double so such a claim inflates C instead.
  p <- p[!is.na(p)]
  p <- pmax(p, .Machine$double.xmin)
  k <- length(p)
  C <- -2 * sum(log(p))
  df <- 2L * k
  list(
    C = C,
    df = df,
    k = k,
    p.value = if (k > 0) {
      stats::pchisq(C, df = df, lower.tail = FALSE)
    } else {
      NA_real_
    }
  )
}

#' Fisher's C statistic for a fitted distributional SEM
#'
#' Combines the independence-claim p-values from [dsep()] into Fisher's C,
#' `C = -2 * sum(log(p))`, which is chi-squared with `2k` degrees of freedom
#' under the hypothesis that all missing arrows are absent. A small p-value
#' indicates the DAG omits a needed path.
#'
#' This is the Fisher-combined goodness-of-fit test introduced by Shipley (2000)
#' for path models on directed acyclic graphs and extended to generalized
#' multilevel models by Shipley (2009); `piecewiseSEM` (Lefcheck 2016) is the
#' established R implementation. The construction itself is unchanged here; what
#' differs is that the p-values being combined are the any-component
#' likelihood-ratio claims of [dsep()] rather than mean-only claims. Only
#' `"ok"` claims enter C; `"wrong_scale"` and other non-`"ok"` statuses are
#' excluded (D-21).
#'
#' @param object A `drm_sem` object or the result of [dsep()].
#' @param ... Unused.
#' @return A one-row data frame with `fisher_c`, `df`, `n_claims`, `p.value`.
#' @references
#' \insertRef{Shipley2000}{drmSEM}
#'
#' \insertRef{Shipley2009}{drmSEM}
#'
#' \insertRef{Lefcheck2016}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   size = drm_node(drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
#'                   family = stats::gaussian()),
#'   abundance = drm_node(drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
#'                        family = drmTMB::nbinom2()),
#'   data = dat)
#' fisher_c(sem)
#' }
#' @export
fisher_c <- function(object, ...) {
  UseMethod("fisher_c")
}

#' @rdname fisher_c
#' @export
fisher_c.drm_sem <- function(object, ...) {
  fisher_c(dsep(object))
}

#' @rdname fisher_c
#' @export
fisher_c.drm_dsep <- function(object, ...) {
  fc <- attr(object, "fisher_c")
  data.frame(
    fisher_c = fc$C,
    df = fc$df,
    n_claims = fc$k,
    p.value = fc$p.value,
    stringsAsFactors = FALSE
  )
}

#' @export
print.drm_dsep <- function(x, ...) {
  fc <- attr(x, "fisher_c")
  cli::cli_text("<drmSEM d-separation: {nrow(x)} claim{?s}>")
  print.data.frame(
    transform(
      as.data.frame(x),
      p.value = signif(p.value, 3),
      LR = round(LR, 3)
    ),
    row.names = FALSE
  )
  if (!is.null(fc) && fc$k > 0) {
    cli::cli_text(
      "Fisher's C = {round(fc$C, 2)} on {fc$df} df, p = {signif(fc$p.value, 3)}"
    )
  }
  invisible(x)
}
