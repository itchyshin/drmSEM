#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# OQ-14 — covariance edges (rho12 / corpair).
#
# drmSEM separates three edge classes (docs/design/07-bivariate-covariance-edges.md):
#   1. directed causal/distributional paths (incl. x -> rho12) -- live in $edges,
#      reported by paths(), and enter d-separation + effects as usual;
#   2. residual covariance edges (rho12): eps_y1 <-> eps_y2, within-observation;
#   3. higher-level random-effect covariance edges (corpair): u_*,y1 <-> u_*,y2.
#
# Classes (2) and (3) are *covariance allowances*: double-headed arcs that carry
# no direction and no mediated effect, but DO constrain d-separation (a declared
# covariance edge between y1 and y2 removes the `y1 _||_ y2` independence claim).
# They are stored in a dedicated `$covariances` slot, never in `$edges`, so that
# paths() stays directed-only. This file is the pure-R grammar/accessor layer;
# reading a residual/RE correlation back from a live bivariate drmTMB fit
# (`rho12()` / `corpairs()`) is the engine-dependent remainder of OQ-14.
# ---------------------------------------------------------------------------

#' Declare a covariance edge between two responses
#'
#' A covariance edge is a double-headed arc, **not** a directed path: it states
#' that two responses are *allowed to remain associated* after their modelled
#' predictors, without asserting a direction or a mediated effect. With `level =
#' NULL` it is a **residual** correlation (`rho12`, within-observation,
#' `eps_y1 <-> eps_y2`); with a grouping `level` it is a **higher-level**
#' random-effect correlation (`corpair`, between-unit, `u_level,y1 <-> u_level,y2`).
#' These are biologically distinct and are reported separately by
#' [covariances()]; neither enters [paths()] or the effect decomposition.
#'
#' Pass declarations to [drm_sem()] / [drm_psem()] via their `covariances`
#' argument. A declared covariance edge makes [basis_set()] / [dsep()] drop the
#' `y1 _||_ y2 | predictors` independence claim, because the model has explicitly
#' allowed `y1` and `y2` to stay coupled.
#'
#' @param y1,y2 Response (node) names, as strings. Matched to nodes by name or
#'   response variable, exactly like a predictor token.
#' @param level `NULL` for a residual (`rho12`) edge, or a grouping name (e.g.
#'   `"id"`, `"species"`) for a higher-level random-effect (`corpair`) edge.
#' @param structure Label for the covariance structure (informational), e.g.
#'   `"unstructured"`, `"phylo"`.
#' @return A `drm_covary` declaration object.
#' @seealso [covariances()], [drm_sem()].
#' @references
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#' @examples
#' # A residual (rho12) covariance edge between two responses:
#' covary("activity", "boldness")
#' # A higher-level random-effect (corpair) edge sharing the `id` grouping:
#' covary("activity", "boldness", level = "id")
#' @export
covary <- function(y1, y2, level = NULL, structure = "unstructured") {
  chk_name <- function(v, arg) {
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(v)) {
      cli::cli_abort(
        "{.arg {arg}} must be a single non-empty response name (string)."
      )
    }
  }
  chk_name(y1, "y1")
  chk_name(y2, "y2")
  if (identical(y1, y2)) {
    cli::cli_abort("A covariance edge needs two {.emph distinct} responses.")
  }
  if (
    !is.null(level) &&
      (!is.character(level) ||
        length(level) != 1L ||
        is.na(level) ||
        !nzchar(level))
  ) {
    cli::cli_abort(c(
      "{.arg level} must be {.code NULL} or a single grouping name.",
      "i" = "{.code NULL} declares a residual (rho12) edge; a name declares a higher-level (corpair) edge."
    ))
  }
  if (!is.character(structure) || length(structure) != 1L || is.na(structure)) {
    cli::cli_abort("{.arg structure} must be a single string.")
  }
  # NB: the `structure` argument shadows base::structure(), so build the object
  # with an explicit class<- rather than a structure() call.
  out <- list(
    y1 = y1,
    y2 = y2,
    class = if (is.null(level)) "residual" else "higher_level",
    level = if (is.null(level)) NA_character_ else level,
    structure = structure
  )
  class(out) <- "drm_covary"
  out
}

#' @export
print.drm_covary <- function(x, ...) {
  if (identical(x$class, "residual")) {
    cli::cli_text("<covariance edge> rho12({x$y1}, {x$y2}) [residual]")
  } else {
    cli::cli_text(
      "<covariance edge> corpair({x$level}: {x$y1}, {x$y2}) [higher-level]"
    )
  }
  invisible(x)
}

# Empty, typed covariance-edge table.
drm_empty_covariances <- function() {
  data.frame(
    y1 = character(0),
    y2 = character(0),
    class = character(0),
    level = character(0),
    structure = character(0),
    label = character(0),
    stringsAsFactors = FALSE
  )
}

# Validate covary() declarations against the SEM's node records and build the
# `$covariances` table. `covariances` may be NULL, one drm_covary, or a list of
# them. Each response must resolve to a node; the two must be distinct nodes.
drm_build_covariances <- function(covariances, records) {
  if (is.null(covariances)) {
    return(drm_empty_covariances())
  }
  if (inherits(covariances, "drm_covary")) {
    covariances <- list(covariances)
  }
  if (
    !is.list(covariances) ||
      !all(vapply(covariances, inherits, logical(1), what = "drm_covary"))
  ) {
    cli::cli_abort(c(
      "{.arg covariances} must be {.fn covary} declaration(s).",
      "i" = "Use {.code covariances = covary(\"y1\", \"y2\")} or a list of them."
    ))
  }
  resolve <- function(tok) {
    for (nm in names(records)) {
      if (tok %in% records[[nm]]$identifiers) return(nm)
    }
    cli::cli_abort(
      "{.fn covary}: {.val {tok}} is not a response node in this SEM."
    )
  }
  rows <- lapply(covariances, function(cv) {
    n1 <- resolve(cv$y1)
    n2 <- resolve(cv$y2)
    if (identical(n1, n2)) {
      cli::cli_abort(
        "{.fn covary}: {.val {cv$y1}} and {.val {cv$y2}} resolve to the same node {.val {n1}}."
      )
    }
    label <- if (identical(cv$class, "residual")) {
      sprintf("rho12(%s, %s)", n1, n2)
    } else {
      sprintf("corpair(%s: %s, %s)", cv$level, n1, n2)
    }
    data.frame(
      y1 = n1,
      y2 = n2,
      class = cv$class,
      level = cv$level,
      structure = cv$structure,
      label = label,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  # Collapse duplicate declarations of the same unordered pair + class + level.
  key <- paste(
    pmin(out$y1, out$y2),
    pmax(out$y1, out$y2),
    out$class,
    out$level,
    sep = "\r"
  )
  out <- out[!duplicated(key), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Unordered "y1\ry2" keys for every covariance edge, used by basis_set() to drop
# the corresponding independence claim. Returns character(0) when there are none
# (incl. objects built before this slot existed, where $covariances is NULL).
drm_covariance_pairs <- function(object) {
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    return(character(0))
  }
  unique(paste(pmin(cv$y1, cv$y2), pmax(cv$y1, cv$y2), sep = "\r"))
}

#' Covariance edges of a distributional SEM (residual rho12 and higher-level corpair)
#'
#' Returns the **covariance allowances** declared via [covary()] — double-headed
#' arcs that are deliberately kept *separate* from [paths()] (which stays
#' directed-only, including any `x -> rho12` directed path into the correlation
#' component). Residual (`rho12`, within-observation) and higher-level (`corpair`,
#' between-unit random-effect) edges are reported together with a `class` column
#' that distinguishes them; they answer different biological questions and are
#' never collapsed. A declared edge also makes [basis_set()] / [dsep()] drop the
#' `y1 _||_ y2` independence claim.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A `drm_covariances` data frame with columns `y1`, `y2`, `class`
#'   (`"residual"` / `"higher_level"`), `level`, `structure`, `label`.
#' @seealso [covary()], [paths()], [basis_set()].
#' @references
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#' @examples
#' \dontrun{
#' sem <- drm_sem(
#'   activity = drm_node(drmTMB::bf(activity ~ x), family = stats::gaussian()),
#'   boldness = drm_node(drmTMB::bf(boldness ~ x), family = stats::gaussian()),
#'   data = dat,
#'   covariances = covary("activity", "boldness"))
#' covariances(sem)   # the residual rho12 edge, reported separately from paths()
#' }
#' @export
covariances <- function(object, ...) {
  UseMethod("covariances")
}

#' @rdname covariances
#' @export
covariances.drm_sem <- function(object, ...) {
  cv <- object$covariances
  if (is.null(cv)) {
    cv <- drm_empty_covariances()
  }
  class(cv) <- c("drm_covariances", "data.frame")
  cv
}

#' @export
print.drm_covariances <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<drmSEM covariance edges: none>")
    return(invisible(x))
  }
  cli::cli_text("<drmSEM covariance edges: {nrow(x)}>")
  df <- as.data.frame(x)[,
    c("class", "level", "y1", "y2", "label"),
    drop = FALSE
  ]
  print.data.frame(df, row.names = FALSE)
  invisible(x)
}
