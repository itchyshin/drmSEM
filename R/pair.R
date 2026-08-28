#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# OQ-14 / 0.4 — drm_pair(): bivariate-node declaration AND joint fit.
#
# A bivariate model fits two responses jointly with a residual correlation
# `rho12` (optionally regressed on covariates) and, when the two responses share
# a grouping level, a higher-level random-effect correlation (`corpair`).
#
#   1. records and validates the pair declaration (two response formulas, two
#      families, an optional `rho12 ~ x` correlation model, the shared level),
#   2. bridges it onto the shipped covariance-edge grammar (`covary()`), so the
#      pair's residual (rho12) and higher-level (corpair) arcs flow through the
#      existing d-separation / covariances() machinery,
#   3. when consumed by drm_sem() / drm_psem(), fits ONE joint bivariate drmTMB
#      model (biv_gaussian / biv_lognormal / biv_student) and reads rho12
#      coefficients back through the extractors.R adapter.
#
# drm_pair() itself still does not fit; the declaration stays inspectable
# without an engine. Estimates stay NA until a live bivariate fit is attached.
# ---------------------------------------------------------------------------

# Response label of a (two-sided) formula: the bare symbol if the LHS is one,
# else the first variable (e.g. cbind(succ, fail) -> "succ"). Pure base R.
drm_formula_response <- function(f) {
  if (!inherits(f, "formula") || length(f) != 3L) {
    cli::cli_abort(
      "Each pair member must be a two-sided formula (e.g. {.code y ~ x})."
    )
  }
  lhs <- f[[2L]]
  if (is.symbol(lhs)) {
    return(as.character(lhs))
  }
  v <- all.vars(lhs)
  if (length(v) == 0L) {
    cli::cli_abort(
      "Could not read a response variable from {.code {deparse(f)}}."
    )
  }
  v[[1L]]
}

# Grouping factors of a formula's random-effect bar groups. Returns the variable
# name(s) on the right of each top-level `|` / `||` (the brms `|p|` correlation
# label is the middle term and is intentionally ignored). Pure base R.
drm_formula_groups <- function(f) {
  rhs <- if (length(f) == 3L) f[[3L]] else f[[2L]]
  groups <- character(0)
  collect <- function(expr) {
    if (!is.call(expr)) {
      return(invisible())
    }
    if (identical(expr[[1L]], as.name("(")) && length(expr) >= 2L) {
      inner <- expr[[2L]]
      if (
        is.call(inner) &&
          (identical(inner[[1L]], as.name("|")) ||
            identical(inner[[1L]], as.name("||")))
      ) {
        grp <- inner[[length(inner)]]
        groups <<- c(groups, all.vars(grp))
        return(invisible())
      }
    }
    for (i in seq_along(expr)[-1L]) {
      collect(expr[[i]])
    }
  }
  collect(rhs)
  unique(groups)
}

#' Declare a bivariate (joint two-response) node
#'
#' `drm_pair()` records a **bivariate node**: two responses to be fitted jointly
#' with a residual correlation `rho12` (the within-observation coupling that
#' remains after each response's mean and scale), optionally modelled as a
#' function of predictors (`rho12 ~ x`, a directed path *into* the correlation
#' component), and — when the two response formulas share a grouping level — a
#' higher-level random-effect correlation (`corpair`). It is the bivariate
#' counterpart of [drm_node()].
#'
#' **Declaration here; the joint fit happens in [drm_sem()].** `drm_pair()`
#' validates the two-response node and bridges it onto the covariance-edge
#' grammar ([covary()] / [covariances()]), so the residual (`rho12`) and
#' higher-level (`corpair`) arcs are reported separately from [paths()] and
#' respected by [basis_set()] / [dsep()]. Passing the pair to [drm_sem()] fits
#' **one** joint `drmTMB` bivariate model (`biv_gaussian()` / `biv_lognormal()` /
#' `biv_student()`) and [rho12()] / [corpairs()] then read the fitted
#' coefficients back. An unfitted declaration still reports `estimate = NA`;
#' `drm_pair()` never fabricates a correlation. See
#' `docs/design/07-bivariate-covariance-edges.md`.
#'
#' @param formula1,formula2 Two two-sided response formulas (e.g.
#'   `activity ~ x + (1 | id)` and `boldness ~ x + (1 | id)`). Random-effect bar
#'   groups shared between the two declare the higher-level `corpair` edge.
#' @param rho12 Optional one-sided formula (e.g. `~ x`) giving predictors of the
#'   residual correlation on its link (`tanh`) scale — a directed path into the
#'   `rho12` component. `NULL` (default) declares a constant residual correlation.
#' @param family,family2 `drmTMB`/`stats` families for the two responses.
#'   `family2` defaults to `family` (a homogeneous bivariate node).
#' @param level Higher-level (`corpair`) grouping. `NULL` (default) auto-detects
#'   grouping factors common to both formulas; a string forces a specific level;
#'   `NA` suppresses the `corpair` edge (residual `rho12` only).
#' @param names Optional length-2 character vector of node names, defaulting to
#'   the two response labels.
#'
#' @return A `drm_pair` declaration object.
#' @seealso [covary()], [rho12()], [corpairs()], [drm_node()],
#'   [drm_expand_pair()].
#' @references
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#'
#' \insertRef{Brooks2017}{drmSEM}
#' @examples
#' # A bivariate node: two responses sharing an `id` grouping, with the residual
#' # correlation itself modelled as a function of `x`.
#' pair <- drm_pair(
#'   activity ~ x + (1 | id),
#'   boldness ~ x + (1 | id),
#'   rho12 = ~ x
#' )
#' pair
#' rho12(pair)      # declared residual edge (estimate NA until drm_sem() fits)
#' corpairs(pair)   # declared higher-level edge at the shared `id` level
#' @export
drm_pair <- function(
  formula1,
  formula2,
  rho12 = NULL,
  family = stats::gaussian(),
  family2 = family,
  level = NULL,
  names = NULL
) {
  if (!inherits(formula1, "formula") || !inherits(formula2, "formula")) {
    cli::cli_abort("{.arg formula1} and {.arg formula2} must both be formulas.")
  }
  y1 <- drm_formula_response(formula1)
  y2 <- drm_formula_response(formula2)
  if (!is.null(names)) {
    if (
      !is.character(names) ||
        length(names) != 2L ||
        anyNA(names) ||
        !all(nzchar(names))
    ) {
      cli::cli_abort("{.arg names} must be two non-empty node names.")
    }
    y1 <- names[[1L]]
    y2 <- names[[2L]]
  }
  if (identical(y1, y2)) {
    cli::cli_abort(c(
      "A bivariate pair needs two {.emph distinct} responses; both resolve to {.val {y1}}.",
      "i" = "Pass {.arg names} to disambiguate, or use distinct response variables."
    ))
  }

  # rho12 ~ x: predictors of the residual correlation (a directed path into the
  # rho12 component). Recorded now; extracting it as a live path needs the fit.
  rho_preds <- character(0)
  if (!is.null(rho12)) {
    if (!inherits(rho12, "formula")) {
      cli::cli_abort(
        "{.arg rho12} must be a one-sided formula (e.g. {.code ~ x}) or {.code NULL}."
      )
    }
    rhs <- if (length(rho12) == 3L) rho12[[3L]] else rho12[[2L]]
    rho_preds <- drm_fixed_predictors(rhs)
  }

  # Higher-level (corpair) level: auto-detect shared grouping, or honour the
  # explicit `level` (NA suppresses).
  shared <- intersect(
    drm_formula_groups(formula1),
    drm_formula_groups(formula2)
  )
  if (is.null(level)) {
    corpair_levels <- shared
  } else if (length(level) == 1L && is.na(level)) {
    corpair_levels <- character(0)
  } else {
    if (!is.character(level) || anyNA(level) || !all(nzchar(level))) {
      cli::cli_abort(
        "{.arg level} must be {.code NULL}, {.code NA}, or grouping name(s)."
      )
    }
    missing_lv <- setdiff(level, shared)
    if (length(missing_lv) > 0L) {
      cli::cli_warn(c(
        "Declared corpair level(s) {.val {missing_lv}}: not a grouping shared by both responses.",
        "i" = "A higher-level correlation is only meaningful where both responses share the grouping (see the level-compatibility rule)."
      ))
    }
    corpair_levels <- level
  }

  residual <- covary(y1, y2)
  corpairs_decl <- lapply(corpair_levels, function(lv) {
    covary(y1, y2, level = lv)
  })

  out <- list(
    responses = c(y1, y2),
    formulas = stats::setNames(list(formula1, formula2), c(y1, y2)),
    families = stats::setNames(list(family, family2), c(y1, y2)),
    rho12 = list(
      formula = rho12,
      predictors = rho_preds,
      constant = is.null(rho12)
    ),
    residual = residual,
    corpairs = corpairs_decl,
    levels = corpair_levels
  )
  class(out) <- "drm_pair"
  out
}

#' @export
print.drm_pair <- function(x, ...) {
  cli::cli_h3(
    "<drm_pair> bivariate node {.val {x$responses[[1L]]}} & {.val {x$responses[[2L]]}}"
  )
  fam1 <- drm_family_name(x$families[[1L]])
  fam2 <- drm_family_name(x$families[[2L]])
  f1 <- paste(deparse(x$formulas[[1L]]), collapse = " ")
  f2 <- paste(deparse(x$formulas[[2L]]), collapse = " ")
  cli::cli_text("{.strong {x$responses[[1L]]}} [{fam1}]: {.code {f1}}")
  cli::cli_text("{.strong {x$responses[[2L]]}} [{fam2}]: {.code {f2}}")
  if (x$rho12$constant) {
    cli::cli_text(
      "residual correlation: rho12({x$responses[[1L]]}, {x$responses[[2L]]}) [constant]"
    )
  } else {
    cli::cli_text(
      "residual correlation: rho12 ~ {paste(x$rho12$predictors, collapse = ' + ')} [directed path into rho12]"
    )
  }
  if (length(x$levels) > 0L) {
    cli::cli_text(
      "higher-level correlation: corpair at {length(x$levels)} level{?s} ({.val {x$levels}})"
    )
  }
  cli::cli_text(cli::col_grey(
    "declaration only; pass this pair to drm_sem() for a joint bivariate fit"
  ))
  invisible(x)
}

#' Expand a bivariate pair onto the covariance-edge grammar
#'
#' Bridges a [drm_pair()] declaration onto the shipped pieces: two [drm_node()]
#' specifications (used for row-alignment and imputation bookkeeping) and the
#' [covary()] covariance edges (residual `rho12` plus any higher-level
#' `corpair`). [drm_sem()] no longer fits those two nodes independently: it
#' calls the joint bivariate engine path and stores the same `drmTMB` fit under
#' both response names. Building the [drm_node()] objects wraps each plain
#' formula with [drmTMB::bf()], so this needs `drmTMB` available; the declaration
#' itself ([drm_pair()]) and the accessors do not.
#'
#' @param pair A `drm_pair` object.
#' @return A list with `nodes` (named list of `drm_node`) and `covariances`
#'   (list of `drm_covary`).
#' @seealso [drm_pair()], [drm_sem()].
#' @examples
#' # The declaration itself needs no engine.
#' pair <- drm_pair(
#'   activity ~ x + (1 | id),
#'   boldness ~ x + (1 | id),
#'   rho12 = ~ x
#' )
#' \dontrun{
#' # Expansion builds the marginal sub-nodes with drmTMB::bf(), so it needs
#' # drmTMB available.
#' expanded <- drm_expand_pair(pair)
#' names(expanded$nodes)   # the two marginal response sub-nodes
#' expanded$covariances    # the residual rho12 (+ any corpair) edges
#' }
#' @export
drm_expand_pair <- function(pair) {
  if (!inherits(pair, "drm_pair")) {
    cli::cli_abort("{.arg pair} must be a {.fn drm_pair} object.")
  }
  nodes <- stats::setNames(
    lapply(pair$responses, function(nm) {
      drm_node(pair$formulas[[nm]], family = pair$families[[nm]])
    }),
    pair$responses
  )
  list(
    nodes = nodes,
    covariances = c(list(pair$residual), pair$corpairs)
  )
}

# ---------------------------------------------------------------------------
# Joint bivariate fit (0.4). drmSEM still never writes a likelihood: it builds
# one drmTMB::bf() with mu1/mu2/sigma1/sigma2/rho12 and delegates to drmTMB.
# ---------------------------------------------------------------------------

drm_univariate_family_stem <- function(name) {
  switch(
    name,
    biv_gaussian = "gaussian",
    biv_lognormal = "lognormal",
    biv_student = "student",
    name
  )
}

#' Map a homogeneous pair of families onto a drmTMB bivariate family.
#' @keywords internal
#' @noRd
drm_pair_joint_family <- function(pair) {
  drm_require_drmTMB()
  n1 <- drm_univariate_family_stem(drm_family_name(pair$families[[1L]]))
  n2 <- drm_univariate_family_stem(drm_family_name(pair$families[[2L]]))
  if (!identical(n1, n2)) {
    cli::cli_abort(c(
      "A joint bivariate fit needs the same family on both responses.",
      "x" = "Got {.val {n1}} and {.val {n2}}.",
      "i" = "Use two Gaussian, two lognormal, or two Student margins, or pass an already-fitted bivariate {.pkg drmTMB} model to {.fn drm_psem}."
    ))
  }
  switch(
    n1,
    gaussian = drmTMB::biv_gaussian(),
    lognormal = drmTMB::biv_lognormal(),
    student = drmTMB::biv_student(),
    cli::cli_abort(c(
      "No joint bivariate family for {.val {n1}}.",
      "i" = "{.pkg drmTMB} currently ships {.fn biv_gaussian}, {.fn biv_lognormal}, and {.fn biv_student}."
    ))
  )
}

#' Build the joint drmTMB::bf() for a drm_pair declaration.
#' @keywords internal
#' @noRd
drm_pair_formula <- function(pair) {
  drm_require_drmTMB()
  y1 <- pair$responses[[1L]]
  y2 <- pair$responses[[2L]]
  rho <- pair$rho12$formula
  if (is.null(rho)) {
    rho <- ~1
  }
  do.call(
    drmTMB::bf,
    list(
      mu1 = pair$formulas[[y1]],
      mu2 = pair$formulas[[y2]],
      sigma1 = ~1,
      sigma2 = ~1,
      rho12 = rho
    )
  )
}

#' Fit one joint bivariate drmTMB model for a drm_pair.
#' @keywords internal
#' @noRd
drm_fit_pair <- function(pair, data, name = NULL) {
  drm_require_drmTMB()
  control <- tryCatch(drmTMB::drm_control(se = TRUE), error = function(e) NULL)
  form <- drm_pair_formula(pair)
  fam <- drm_pair_joint_family(pair)
  label <- if (is.null(name)) {
    paste(pair$responses, collapse = " & ")
  } else {
    name
  }
  call_args <- c(
    list(form, family = fam, data = data),
    if (!is.null(control)) list(control = control)
  )
  tryCatch(
    do.call(drmTMB::drmTMB, call_args),
    error = function(e) {
      cli::cli_abort(c(
        "Bivariate pair {.val {label}} failed to fit.",
        "x" = conditionMessage(e)
      ))
    }
  )
}

#' Split `drm_sem(...)` args into named nodes, pairs, and covariance edges.
#' @keywords internal
#' @noRd
drm_unpack_sem_specs <- function(specs) {
  if (is.null(names(specs))) {
    names(specs) <- rep("", length(specs))
  }
  nodes <- list()
  pairs <- list()
  member_pair <- list()
  extra_cov <- list()
  for (i in seq_along(specs)) {
    spec <- specs[[i]]
    nm <- names(specs)[[i]]
    if (inherits(spec, "drm_pair")) {
      y1 <- spec$responses[[1L]]
      y2 <- spec$responses[[2L]]
      if (y1 %in% names(nodes) || y2 %in% names(nodes)) {
        cli::cli_abort(c(
          "Pair responses {.val {y1}} and {.val {y2}} collide with an existing node name.",
          "i" = "Give the pair distinct response names, or drop the duplicate {.fn drm_node}."
        ))
      }
      key <- paste(y1, y2, sep = "\r")
      pairs[[key]] <- spec
      extra_cov <- c(extra_cov, list(spec$residual), spec$corpairs)
      nodes[[y1]] <- drm_node(
        spec$formulas[[y1]],
        family = spec$families[[y1]]
      )
      nodes[[y2]] <- drm_node(
        spec$formulas[[y2]],
        family = spec$families[[y2]]
      )
      member_pair[[y1]] <- key
      member_pair[[y2]] <- key
    } else if (inherits(spec, "drm_node")) {
      if (!nzchar(nm)) {
        cli::cli_abort(c(
          "Every {.fn drm_node} passed to {.fn drm_sem} must be named.",
          "i" = "A {.fn drm_pair} may be unnamed: its responses become the node names."
        ))
      }
      if (nm %in% names(nodes)) {
        cli::cli_abort("Node name {.val {nm}} is used more than once.")
      }
      nodes[[nm]] <- spec
    } else {
      cli::cli_abort(c(
        "{.fn drm_sem} expects {.fn drm_node} or {.fn drm_pair} specifications.",
        "i" = "To assemble from already-fitted models, use {.fn drm_psem}."
      ))
    }
  }
  list(
    nodes = nodes,
    pairs = pairs,
    member_pair = member_pair,
    covariances = extra_cov
  )
}

#' Expand drm_psem() args so one bivariate fit becomes two named nodes.
#' @keywords internal
#' @noRd
drm_expand_psem_fits <- function(fits) {
  if (is.null(names(fits))) {
    names(fits) <- rep("", length(fits))
  }
  out <- list()
  for (i in seq_along(fits)) {
    fit <- fits[[i]]
    if (!is_drmTMB_fit(fit)) {
      cli::cli_abort(c(
        "{.fn drm_psem} expects fitted {.pkg drmTMB} objects.",
        "i" = "For the declarative interface that fits nodes for you, use {.fn drm_sem}."
      ))
    }
    nm <- names(fits)[[i]]
    if (drm_is_bivariate_fit(fit)) {
      ys <- drm_biv_response_names(fit)
      if (anyNA(ys) || !all(nzchar(ys))) {
        cli::cli_abort(
          "Could not read both response names from the bivariate fit."
        )
      }
      if (nzchar(nm) && nm %in% ys) {
        if (nm %in% names(out) && !identical(out[[nm]], fit)) {
          cli::cli_abort(
            "Node {.val {nm}} was supplied twice with different fits."
          )
        }
        out[[nm]] <- fit
      } else {
        for (y in ys) {
          if (y %in% names(out) && !identical(out[[y]], fit)) {
            cli::cli_abort(
              "Node {.val {y}} was supplied twice with different fits."
            )
          }
          out[[y]] <- fit
        }
      }
    } else {
      if (!nzchar(nm)) {
        cli::cli_abort("Every univariate node passed to {.fn drm_psem} must be named.")
      }
      if (nm %in% names(out)) {
        cli::cli_abort("Node name {.val {nm}} is used more than once.")
      }
      out[[nm]] <- fit
    }
  }
  out
}

#' Combine auto-detected and user covariance declarations; NULL if none.
#' @keywords internal
#' @noRd
drm_combine_covariances <- function(auto, user) {
  if (inherits(user, "drm_covary")) {
    user <- list(user)
  }
  out <- c(auto, user)
  if (!length(out)) {
    return(NULL)
  }
  out
}

#' Residual covary() edges implied by fitted bivariate nodes.
#' @keywords internal
#' @noRd
drm_bivariate_fit_covariances <- function(fits) {
  extra <- list()
  seen <- character(0)
  for (nm in names(fits)) {
    fit <- fits[[nm]]
    if (!drm_is_bivariate_fit(fit)) {
      next
    }
    ys <- drm_biv_response_names(fit)
    if (anyNA(ys) || !all(nzchar(ys))) {
      next
    }
    key <- paste(pmin(ys[[1L]], ys[[2L]]), pmax(ys[[1L]], ys[[2L]]), sep = "\r")
    if (key %in% seen) {
      next
    }
    seen <- c(seen, key)
    extra[[length(extra) + 1L]] <- covary(ys[[1L]], ys[[2L]])
  }
  extra
}

# ---------------------------------------------------------------------------
# rho12() / corpairs() accessors.
#
# Declaration objects still report estimate = NA. A drm_sem that holds a live
# bivariate drmTMB fit returns the Wald table for rho12 coefficients (link /
# tanh scale) and, for corpairs(), higher-level rows from drmTMB::corpairs().
# ---------------------------------------------------------------------------

drm_rho12_empty <- function() {
  data.frame(
    y1 = character(0),
    y2 = character(0),
    term = character(0),
    estimate = numeric(0),
    std.error = numeric(0),
    statistic = numeric(0),
    p.value = numeric(0),
    link = character(0),
    predictors = character(0),
    constant = logical(0),
    stringsAsFactors = FALSE
  )
}

drm_rho12_declared_row <- function(y1, y2, predictors, constant) {
  data.frame(
    y1 = y1,
    y2 = y2,
    term = NA_character_,
    estimate = NA_real_,
    std.error = NA_real_,
    statistic = NA_real_,
    p.value = NA_real_,
    link = "tanh",
    predictors = predictors,
    constant = constant,
    stringsAsFactors = FALSE
  )
}

drm_rho12_note <- function(fitted = FALSE) {
  if (isTRUE(fitted)) {
    "rho12 coefficients on the tanh (atanh_guarded) link; not a y1 -> y2 path."
  } else {
    "estimate NA: declaration only; fit the pair with drm_sem() or pass a bivariate drmTMB fit to drm_psem()."
  }
}

drm_unique_bivariate_fits <- function(object) {
  fits <- object$nodes
  if (is.null(fits) || !length(fits)) {
    return(list())
  }
  out <- list()
  for (nm in names(fits)) {
    fit <- fits[[nm]]
    if (!is_drmTMB_fit(fit) || !drm_is_bivariate_fit(fit)) {
      next
    }
    ys <- drm_biv_response_names(fit)
    key <- paste(ys, collapse = "\r")
    if (key %in% names(out)) {
      next
    }
    out[[key]] <- fit
  }
  out
}

#' Residual response-response correlation (rho12)
#'
#' Reports the **residual** correlation edge(s) between two responses — the
#' within-observation coupling `rho12` that remains after each response's mean and
#' scale (class 2 in `docs/design/07-bivariate-covariance-edges.md`). For an
#' unfitted [drm_pair()] it is the declared edge (`estimate` is `NA`). For a
#' [drm_sem()] that holds a joint bivariate `drmTMB` fit it is the Wald table of
#' `rho12` coefficients: intercept and any `rho12 ~ x` predictors, with standard
#' error and p-value, on the `tanh` (engine: `atanh_guarded`) link. Distinct from
#' [corpairs()] (higher-level random-effect correlations) and kept out of
#' [paths()] except for directed `x -> rho12` paths.
#'
#' @param object A `drm_pair` or `drm_sem`.
#' @param ... Unused.
#' @return A `drm_rho12` data frame: `y1`, `y2`, `term`, `estimate`,
#'   `std.error`, `statistic`, `p.value`, `link`, `predictors`, `constant`.
#' @seealso [corpairs()], [covary()], [covariances()], [drm_pair()].
#' @references
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#'
#' \insertRef{Brooks2017}{drmSEM}
#' @examples
#' rho12(drm_pair(activity ~ x, boldness ~ x, rho12 = ~ x))
#' @export
rho12 <- function(object, ...) {
  UseMethod("rho12")
}

#' @rdname rho12
#' @export
rho12.drm_pair <- function(object, ...) {
  out <- drm_rho12_declared_row(
    object$responses[[1L]],
    object$responses[[2L]],
    paste(object$rho12$predictors, collapse = " + "),
    object$rho12$constant
  )
  structure(out, class = c("drm_rho12", "data.frame"), note = drm_rho12_note())
}

#' @rdname rho12
#' @export
rho12.drm_sem <- function(object, ...) {
  biv <- drm_unique_bivariate_fits(object)
  if (length(biv)) {
    rows <- lapply(biv, function(fit) {
      ys <- drm_biv_response_names(fit)
      coefs <- drm_fit_rho12_coef(fit)
      preds <- drm_fit_component_predictors(fit, "rho12")
      if (!nrow(coefs)) {
        return(drm_rho12_declared_row(
          ys[[1L]],
          ys[[2L]],
          paste(preds, collapse = " + "),
          length(preds) == 0L
        ))
      }
      data.frame(
        y1 = ys[[1L]],
        y2 = ys[[2L]],
        term = coefs$term,
        estimate = coefs$estimate,
        std.error = coefs$std.error,
        statistic = coefs$statistic,
        p.value = coefs$p.value,
        link = "tanh",
        predictors = paste(preds, collapse = " + "),
        constant = length(preds) == 0L,
        stringsAsFactors = FALSE
      )
    })
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    return(structure(
      out,
      class = c("drm_rho12", "data.frame"),
      note = drm_rho12_note(fitted = TRUE)
    ))
  }
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    return(structure(
      drm_rho12_empty(),
      class = c("drm_rho12", "data.frame"),
      note = drm_rho12_note()
    ))
  }
  res <- cv[cv$class == "residual", c("y1", "y2"), drop = FALSE]
  edges <- object$edges
  preds_for <- function(y1, y2) {
    if (is.null(edges) || nrow(edges) == 0L || is.null(edges$component)) {
      return("")
    }
    hit <- edges$component == "rho12" & edges$to %in% c(y1, y2)
    paste(unique(edges$term[hit]), collapse = " + ")
  }
  if (nrow(res) == 0L) {
    return(structure(
      drm_rho12_empty(),
      class = c("drm_rho12", "data.frame"),
      note = drm_rho12_note()
    ))
  }
  out <- do.call(
    rbind,
    lapply(seq_len(nrow(res)), function(i) {
      pr <- preds_for(res$y1[[i]], res$y2[[i]])
      drm_rho12_declared_row(res$y1[[i]], res$y2[[i]], pr, nchar(pr) == 0L)
    })
  )
  rownames(out) <- NULL
  structure(out, class = c("drm_rho12", "data.frame"), note = drm_rho12_note())
}

#' @export
print.drm_rho12 <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<residual correlation (rho12): none>")
    return(invisible(x))
  }
  cli::cli_text("<residual correlation (rho12): {nrow(x)} edge{?s}>")
  print.data.frame(as.data.frame(x), row.names = FALSE)
  note <- attr(x, "note")
  if (!is.null(note)) {
    cli::cli_text(cli::col_grey(note))
  }
  invisible(x)
}

#' Higher-level random-effect correlations (corpairs)
#'
#' Reports the **higher-level** random-effect correlation edge(s) — the
#' between-unit coupling `u_level,y1 <-> u_level,y2` among random effects sharing a
#' grouping `level` (class 3 in `docs/design/07-bivariate-covariance-edges.md`).
#' For an unfitted [drm_pair()] these are the declared `corpair` edges. For a
#' [drm_sem()] they are read from `drmTMB::corpairs()` (non-residual rows only)
#' when a joint bivariate fit is present; otherwise the declared higher-level
#' edges are returned with `estimate = NA`. Residual `rho12` is never mixed in —
#' use [rho12()] for that.
#'
#' @param object A `drm_pair` or `drm_sem`.
#' @param ... Unused.
#' @return A `drm_corpairs` data frame: `level`, `y1`, `y2`, `estimate`,
#'   `std.error`, `p.value`.
#' @seealso [rho12()], [covary()], [covariances()], [drm_pair()].
#' @references
#' \insertRef{Bollen1989}{drmSEM}
#'
#' \insertRef{Brooks2017}{drmSEM}
#' @examples
#' corpairs(drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id)))
#' @export
corpairs <- function(object, ...) {
  UseMethod("corpairs")
}

drm_corpairs_empty <- function() {
  data.frame(
    level = character(0),
    y1 = character(0),
    y2 = character(0),
    estimate = numeric(0),
    std.error = numeric(0),
    p.value = numeric(0),
    stringsAsFactors = FALSE
  )
}

#' @rdname corpairs
#' @export
corpairs.drm_pair <- function(object, ...) {
  if (length(object$corpairs) == 0L) {
    out <- drm_corpairs_empty()
  } else {
    out <- do.call(
      rbind,
      lapply(object$corpairs, function(cv) {
        data.frame(
          level = cv$level,
          y1 = cv$y1,
          y2 = cv$y2,
          estimate = NA_real_,
          std.error = NA_real_,
          p.value = NA_real_,
          stringsAsFactors = FALSE
        )
      })
    )
  }
  rownames(out) <- NULL
  structure(
    out,
    class = c("drm_corpairs", "data.frame"),
    note = drm_rho12_note()
  )
}

#' @rdname corpairs
#' @export
corpairs.drm_sem <- function(object, ...) {
  biv <- drm_unique_bivariate_fits(object)
  rows <- list()
  for (fit in biv) {
    cp <- tryCatch(drm_fit_corpairs(fit), error = function(e) NULL)
    if (is.null(cp) || !nrow(cp)) {
      next
    }
    hl <- cp[cp$level != "residual" & cp$class != "residual", , drop = FALSE]
    if (!nrow(hl)) {
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      level = ifelse(
        is.na(hl$group) | !nzchar(hl$group),
        hl$level,
        hl$group
      ),
      y1 = hl$from_response,
      y2 = hl$to_response,
      estimate = hl$estimate,
      std.error = NA_real_,
      p.value = NA_real_,
      stringsAsFactors = FALSE
    )
  }
  if (length(rows)) {
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    return(structure(
      out,
      class = c("drm_corpairs", "data.frame"),
      note = drm_rho12_note(fitted = TRUE)
    ))
  }
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    hl <- drm_corpairs_empty()[, c("level", "y1", "y2"), drop = FALSE]
  } else {
    hl <- cv[cv$class == "higher_level", c("level", "y1", "y2"), drop = FALSE]
  }
  out <- data.frame(
    level = hl$level,
    y1 = hl$y1,
    y2 = hl$y2,
    estimate = NA_real_,
    std.error = NA_real_,
    p.value = NA_real_,
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  structure(
    out,
    class = c("drm_corpairs", "data.frame"),
    note = drm_rho12_note()
  )
}

#' @export
print.drm_corpairs <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<higher-level correlation (corpair): none>")
    return(invisible(x))
  }
  cli::cli_text("<higher-level correlation (corpair): {nrow(x)} edge{?s}>")
  print.data.frame(as.data.frame(x), row.names = FALSE)
  note <- attr(x, "note")
  if (!is.null(note)) {
    cli::cli_text(cli::col_grey(note))
  }
  invisible(x)
}
