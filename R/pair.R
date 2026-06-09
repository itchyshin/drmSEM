#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# OQ-14 / 0.4 — drm_pair(): the bivariate-node *declaration* grammar.
#
# A bivariate model fits two responses jointly with a residual correlation
# `rho12` (optionally regressed on covariates) and, when the two responses share
# a grouping level, a higher-level random-effect correlation (`corpair`). The
# *joint fit* — estimating rho12 inside one drmTMB model — is the 0.4 engine
# deliverable and is NOT performed here (drmSEM never fits its own likelihoods,
# and the dev container has no engine). This file is the pure-R layer that:
#
#   1. records and validates the pair declaration (two response formulas, two
#      families, an optional `rho12 ~ x` correlation model, the shared level),
#   2. bridges it onto the shipped covariance-edge grammar (`covary()`), so the
#      pair's residual (rho12) and higher-level (corpair) arcs flow through the
#      existing d-separation / covariances() machinery unchanged,
#   3. exposes `rho12()` / `corpairs()` accessors that return the *declared*
#      structure now, with the fitted estimates explicitly left as the engine
#      read-back hook (NA until a live bivariate fit is supplied).
#
# Honest boundary (docs/design/07-bivariate-covariance-edges.md): the two
# response sub-nodes are still ordinary piecewise nodes; rho12 is *declared*, not
# jointly estimated, until the engine lane lands the joint fit. drm_pair() never
# fabricates a correlation estimate.
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
#' **This is the declaration grammar, not the fit.** drmSEM is piecewise and the
#' dev lane has no engine, so `drm_pair()` does not estimate `rho12`: it validates
#' the declaration and bridges it onto the shipped covariance-edge grammar
#' ([covary()] / [covariances()]), so the residual (`rho12`) and higher-level
#' (`corpair`) arcs are reported separately from [paths()] and respected by
#' [basis_set()] / [dsep()]. Estimating `rho12` inside one joint `drmTMB` model —
#' and reading it back through [rho12()] / [corpairs()] — is the 0.4 engine
#' deliverable (see `docs/design/07-bivariate-covariance-edges.md`). The declared
#' estimates are `NA` until a live bivariate fit is supplied; `drm_pair()` never
#' fabricates a correlation.
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
#' rho12(pair)      # declared residual edge (estimate NA -> needs a joint fit)
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
    "estimates: NA (declared; joint bivariate fit is the 0.4 engine step)"
  ))
  invisible(x)
}

#' Expand a bivariate pair onto the covariance-edge grammar
#'
#' Bridges a [drm_pair()] declaration onto the shipped pieces: two [drm_node()]
#' specifications (the marginal response sub-nodes) and the [covary()] covariance
#' edges (residual `rho12` plus any higher-level `corpair`). This is the
#' documented hook point for the 0.4 engine lane — a joint bivariate `drmTMB` fit
#' replaces the two independent node fits, while the covariance edges and
#' accessors stay the same. Building the [drm_node()] objects wraps each plain
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
# rho12() / corpairs() accessors.
#
# These return the DECLARED covariance structure with an `estimate` column that
# is NA until a live bivariate fit is read back (the engine hook). They work on a
# drm_pair (the declaration) and on a drm_sem (the declared covariance edges of a
# fitted/assembled SEM). drmSEM never re-solves; the estimate is whatever the
# fitted object exposes (currently nothing, in the pure-R lane).
# ---------------------------------------------------------------------------

# Shared note attached to the declared-only accessor output.
drm_rho12_note <- function() {
  "estimate NA: rho12/corpair are declared; a joint bivariate drmTMB fit is needed to read fitted values back (OQ-14, 0.4 engine)."
}

#' Residual response-response correlation (rho12)
#'
#' Reports the **residual** correlation edge(s) between two responses — the
#' within-observation coupling `rho12` that remains after each response's mean and
#' scale (class 2 in `docs/design/07-bivariate-covariance-edges.md`). For a
#' [drm_pair()] it is the declared edge; for a [drm_sem()] it is the declared
#' residual covariance edges of the assembled model. The `estimate` is the
#' *fitted* correlation read back from a live bivariate `drmTMB` fit — `NA` in the
#' pure-R lane, since drmSEM never re-solves and the joint fit is the 0.4 engine
#' step. Distinct from [corpairs()] (higher-level random-effect correlations) and
#' kept out of [paths()] (any `x -> rho12` directed path is reported there
#' instead).
#'
#' @param object A `drm_pair` or `drm_sem`.
#' @param ... Unused.
#' @return A `drm_rho12` data frame: `y1`, `y2`, `predictors` (of `rho12 ~ x`, or
#'   `""`), `constant`, `estimate`.
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
  out <- data.frame(
    y1 = object$responses[[1L]],
    y2 = object$responses[[2L]],
    predictors = paste(object$rho12$predictors, collapse = " + "),
    constant = object$rho12$constant,
    estimate = NA_real_,
    stringsAsFactors = FALSE
  )
  structure(out, class = c("drm_rho12", "data.frame"), note = drm_rho12_note())
}

#' @rdname rho12
#' @export
rho12.drm_sem <- function(object, ...) {
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    return(structure(
      data.frame(
        y1 = character(0),
        y2 = character(0),
        predictors = character(0),
        constant = logical(0),
        estimate = numeric(0),
        stringsAsFactors = FALSE
      ),
      class = c("drm_rho12", "data.frame"),
      note = drm_rho12_note()
    ))
  }
  res <- cv[cv$class == "residual", c("y1", "y2"), drop = FALSE]
  # Directed x -> rho12 paths, if a bivariate fit ever surfaces them, live in
  # $edges with component == "rho12"; surface their predictors per response pair.
  edges <- object$edges
  preds_for <- function(y1, y2) {
    if (is.null(edges) || nrow(edges) == 0L || is.null(edges$component)) {
      return("")
    }
    hit <- edges$component == "rho12" & edges$to %in% c(y1, y2)
    paste(unique(edges$term[hit]), collapse = " + ")
  }
  preds <- if (nrow(res) == 0L) {
    character(0)
  } else {
    vapply(
      seq_len(nrow(res)),
      function(i) preds_for(res$y1[[i]], res$y2[[i]]),
      character(1)
    )
  }
  out <- data.frame(
    y1 = res$y1,
    y2 = res$y2,
    predictors = preds,
    constant = nchar(preds) == 0L,
    estimate = NA_real_,
    stringsAsFactors = FALSE
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
#' For a [drm_pair()] these are the declared `corpair` edges (auto-detected from
#' shared grouping factors); for a [drm_sem()] they are the declared higher-level
#' covariance edges. As with [rho12()], the `estimate` is read back from a live
#' bivariate `drmTMB` fit and is `NA` in the pure-R lane. Reported separately from
#' the residual `rho12` because the two answer different biological questions
#' (between-unit average coupling vs within-observation residual coupling).
#'
#' @param object A `drm_pair` or `drm_sem`.
#' @param ... Unused.
#' @return A `drm_corpairs` data frame: `level`, `y1`, `y2`, `estimate`.
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

#' @rdname corpairs
#' @export
corpairs.drm_pair <- function(object, ...) {
  if (length(object$corpairs) == 0L) {
    out <- data.frame(
      level = character(0),
      y1 = character(0),
      y2 = character(0),
      estimate = numeric(0),
      stringsAsFactors = FALSE
    )
  } else {
    out <- do.call(
      rbind,
      lapply(object$corpairs, function(cv) {
        data.frame(
          level = cv$level,
          y1 = cv$y1,
          y2 = cv$y2,
          estimate = NA_real_,
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
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    hl <- data.frame(level = character(0), y1 = character(0), y2 = character(0))
  } else {
    hl <- cv[cv$class == "higher_level", c("level", "y1", "y2"), drop = FALSE]
  }
  out <- data.frame(
    level = hl$level,
    y1 = hl$y1,
    y2 = hl$y2,
    estimate = NA_real_,
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
