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
#' Passing a character vector of responses (or calling [covary_clique()])
#' declares all pairwise covariance edges among them, forming a complete
#' covariance sub-graph (clique).
#'
#' Pass declarations to [drm_sem()] / [drm_psem()] via their `covariances`
#' argument. A declared covariance edge makes [basis_set()] / [dsep()] drop the
#' `y1 _||_ y2 | predictors` independence claim, because the model has explicitly
#' allowed `y1` and `y2` to stay coupled.
#'
#' @param y1,y2 Response (node) names, as strings. If `y2` is omitted and `y1`
#'   has length \eqn{\ge 2}, [covary()] delegates to [covary_clique()] to declare
#'   all pairwise covariance edges.
#' @param level `NULL` for a residual (`rho12`) edge, or a grouping name (e.g.
#'   `"id"`, `"species"`) for a higher-level random-effect (`corpair`) edge.
#' @param structure Label for the covariance structure (informational), e.g.
#'   `"unstructured"`, `"phylo"`.
#' @return A `drm_covary` declaration object (or list of them if `y1` is a vector).
#' @seealso [covary_clique()], [covariance_cliques()], [covariances()], [drm_sem()].
#' @references
#' \insertRef{Shipley2016}{drmSEM}
#'
#' \insertRef{ShipleyDouma2021}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#' @examples
#' # A residual (rho12) covariance edge between two responses:
#' covary("activity", "boldness")
#' # A higher-level random-effect (corpair) edge sharing the `id` grouping:
#' covary("activity", "boldness", level = "id")
#' # Declare all pairwise covariance edges in a 3-response clique:
#' covary(c("activity", "boldness", "exploration"))
#' @export
covary <- function(y1, y2, level = NULL, structure = "unstructured") {
  if (missing(y2) && is.character(y1) && length(y1) >= 2L) {
    return(covary_clique(y1, level = level, structure = structure))
  }
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

#' Declare a complete covariance clique among multiple responses
#'
#' Helper that declares pairwise [covary()] edges among all pairs of the supplied
#' response names (\eqn{K \ge 2}), forming a complete covariance sub-graph (clique).
#'
#' @param responses Character vector of at least two distinct response names.
#' @param level `NULL` for residual (`rho12`) edges, or a grouping name for
#'   higher-level random-effect (`corpair`) edges.
#' @param structure Covariance structure label (default `"unstructured"`).
#' @return A list of `drm_covary` declaration objects for each pairwise combination.
#' @seealso [covary()], [covariance_cliques()], [covariances()].
#' @examples
#' covary_clique(c("activity", "boldness", "exploration"))
#' @export
covary_clique <- function(responses, level = NULL, structure = "unstructured") {
  if (
    !is.character(responses) ||
      length(responses) < 2L ||
      anyNA(responses) ||
      any(!nzchar(responses))
  ) {
    cli::cli_abort(
      "{.arg responses} must be a character vector of at least two distinct response names."
    )
  }
  if (any(duplicated(responses))) {
    cli::cli_abort("{.arg responses} must contain {.emph distinct} response names.")
  }
  pairs <- utils::combn(responses, 2L, simplify = FALSE)
  lapply(pairs, function(p) {
    covary(p[[1L]], p[[2L]], level = level, structure = structure)
  })
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

# Flatten any nested lists of drm_covary declarations.
drm_flatten_covariances <- function(covs) {
  if (is.null(covs)) {
    return(NULL)
  }
  if (inherits(covs, "drm_covary")) {
    return(list(covs))
  }
  if (!is.list(covs)) {
    return(list(covs))
  }
  res <- list()
  for (item in covs) {
    if (inherits(item, "drm_covary")) {
      res[[length(res) + 1L]] <- item
    } else if (is.list(item)) {
      flat <- drm_flatten_covariances(item)
      res <- c(res, flat)
    } else {
      res[[length(res) + 1L]] <- item
    }
  }
  res
}

# Validate covary() declarations against the SEM's node records and build the
# `$covariances` table. `covariances` may be NULL, one drm_covary, or a list of
# them. Each response must resolve to a node; the two must be distinct nodes.
drm_build_covariances <- function(covariances, records) {
  if (is.null(covariances)) {
    return(drm_empty_covariances())
  }
  covariances <- drm_flatten_covariances(covariances)
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

# Empty, typed covariance-cliques table.
drm_empty_covariance_cliques <- function() {
  out <- data.frame(
    clique_id = integer(0),
    class = character(0),
    level = character(0),
    size = integer(0),
    nodes = character(0),
    pairs_count = integer(0),
    complete = logical(0),
    stringsAsFactors = FALSE
  )
  structure(
    out,
    class = c("drm_covariance_cliques", "data.frame"),
    members = list()
  )
}

#' Detect complete covariance sub-graphs (cliques) in a covariance table
#' @keywords internal
#' @noRd
drm_find_covariance_cliques <- function(cv, min_size = 2L) {
  if (is.null(cv) || nrow(cv) == 0L) {
    return(drm_empty_covariance_cliques())
  }
  if (!is.data.frame(cv) || !all(c("y1", "y2", "class") %in% names(cv))) {
    return(drm_empty_covariance_cliques())
  }
  if (!"level" %in% names(cv)) {
    cv$level <- NA_character_
  }

  # Group by class and level
  grp_key <- paste(cv$class, ifelse(is.na(cv$level), "__residual__", cv$level), sep = "\r")
  groups <- split(cv, grp_key, drop = TRUE)

  clique_rows <- list()
  all_members <- list()
  clique_counter <- 1L

  for (grp in groups) {
    if (nrow(grp) == 0L) next
    cls <- grp$class[[1L]]
    lvl <- grp$level[[1L]]

    vertices <- sort(unique(c(grp$y1, grp$y2)))
    if (length(vertices) < min_size) next

    # Build undirected adjacency list
    adj <- stats::setNames(vector("list", length(vertices)), vertices)
    for (v in vertices) {
      adj[[v]] <- character(0)
    }
    for (i in seq_len(nrow(grp))) {
      u <- grp$y1[[i]]
      v <- grp$y2[[i]]
      if (!identical(u, v)) {
        adj[[u]] <- union(adj[[u]], v)
        adj[[v]] <- union(adj[[v]], u)
      }
    }

    # Bron-Kerbosch algorithm with pivoting
    found_cliques <- list()
    bk_pivot <- function(r, p, x) {
      if (length(p) == 0L && length(x) == 0L) {
        if (length(r) >= min_size) {
          found_cliques[[length(found_cliques) + 1L]] <<- sort(r)
        }
        return()
      }
      candidates <- c(p, x)
      pivot <- candidates[[1L]]
      max_intersect <- -1L
      for (cand in candidates) {
        deg <- length(intersect(p, adj[[cand]]))
        if (deg > max_intersect) {
          max_intersect <- deg
          pivot <- cand
        }
      }
      p_minus_adj <- setdiff(p, adj[[pivot]])
      for (node in p_minus_adj) {
        node_adj <- adj[[node]]
        bk_pivot(
          r = c(r, node),
          p = intersect(p, node_adj),
          x = intersect(x, node_adj)
        )
        p <- setdiff(p, node)
        x <- union(x, node)
      }
    }

    bk_pivot(r = character(0), p = vertices, x = character(0))

    if (length(found_cliques) > 0L) {
      # De-duplicate identical cliques
      clique_keys <- vapply(found_cliques, paste, character(1), collapse = "\r")
      uniq_idx <- which(!duplicated(clique_keys))
      found_cliques <- found_cliques[uniq_idx]

      sizes <- vapply(found_cliques, length, integer(1))
      first_nodes <- vapply(found_cliques, function(cl) cl[[1L]], character(1))
      ord <- order(-sizes, first_nodes)
      found_cliques <- found_cliques[ord]

      for (cl in found_cliques) {
        sz <- length(cl)
        pairs_cnt <- as.integer(choose(sz, 2L))
        clique_rows[[length(clique_rows) + 1L]] <- data.frame(
          clique_id = clique_counter,
          class = cls,
          level = lvl,
          size = sz,
          nodes = paste(cl, collapse = ", "),
          pairs_count = pairs_cnt,
          complete = TRUE,
          stringsAsFactors = FALSE
        )
        all_members[[length(all_members) + 1L]] <- cl
        clique_counter <- clique_counter + 1L
      }
    }
  }

  if (length(clique_rows) == 0L) {
    return(drm_empty_covariance_cliques())
  }

  out <- do.call(rbind, clique_rows)
  rownames(out) <- NULL
  structure(
    out,
    class = c("drm_covariance_cliques", "data.frame"),
    members = all_members
  )
}

#' Partition covariance sub-graphs into connected components and blocks
#' @keywords internal
#' @noRd
drm_partition_covariance_blocks <- function(cv) {
  if (is.null(cv) || nrow(cv) == 0L) {
    return(data.frame(
      block_id = integer(0),
      class = character(0),
      level = character(0),
      size = integer(0),
      nodes = character(0),
      edges_count = integer(0),
      type = character(0),
      admissible_joint_block = logical(0),
      stringsAsFactors = FALSE
    ))
  }
  if (!"level" %in% names(cv)) {
    cv$level <- NA_character_
  }

  grp_key <- paste(cv$class, ifelse(is.na(cv$level), "__residual__", cv$level), sep = "\r")
  groups <- split(cv, grp_key, drop = TRUE)
  block_rows <- list()
  block_counter <- 1L

  for (grp in groups) {
    if (nrow(grp) == 0L) next
    cls <- grp$class[[1L]]
    lvl <- grp$level[[1L]]
    vertices <- sort(unique(c(grp$y1, grp$y2)))

    # Adjacency list
    adj <- stats::setNames(vector("list", length(vertices)), vertices)
    for (v in vertices) adj[[v]] <- character(0)
    for (i in seq_len(nrow(grp))) {
      u <- grp$y1[[i]]
      v <- grp$y2[[i]]
      if (!identical(u, v)) {
        adj[[u]] <- union(adj[[u]], v)
        adj[[v]] <- union(adj[[v]], u)
      }
    }

    # BFS to find connected components
    visited <- character(0)
    for (start in vertices) {
      if (start %in% visited) next
      queue <- start
      comp <- character(0)
      while (length(queue) > 0L) {
        curr <- queue[[1L]]
        queue <- queue[-1L]
        if (curr %in% comp) next
        comp <- c(comp, curr)
        neighbors <- setdiff(adj[[curr]], comp)
        queue <- c(queue, neighbors)
      }
      visited <- union(visited, comp)
      comp <- sort(comp)
      sz <- length(comp)
      # Count declared edges within this component
      edges_in_comp <- sum(grp$y1 %in% comp & grp$y2 %in% comp)
      complete_edges <- as.integer(choose(sz, 2L))
      is_clique <- (edges_in_comp == complete_edges)
      type <- if (is_clique) "complete_clique" else "structured_network"
      admissible <- (sz == 2L && is_clique)

      block_rows[[length(block_rows) + 1L]] <- data.frame(
        block_id = block_counter,
        class = cls,
        level = lvl,
        size = sz,
        nodes = paste(comp, collapse = ", "),
        edges_count = edges_in_comp,
        type = type,
        admissible_joint_block = admissible,
        stringsAsFactors = FALSE
      )
      block_counter <- block_counter + 1L
    }
  }

  if (length(block_rows) == 0L) {
    return(data.frame(
      block_id = integer(0),
      class = character(0),
      level = character(0),
      size = integer(0),
      nodes = character(0),
      edges_count = integer(0),
      type = character(0),
      admissible_joint_block = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, block_rows)
  rownames(out) <- NULL
  out
}

# Unordered "y1\ry2" keys for all within-clique pairs across all maximal cliques.
drm_covariance_clique_pairs <- function(object) {
  cv <- object$covariances
  if (is.null(cv) || nrow(cv) == 0L) {
    return(character(0))
  }
  cliques <- drm_find_covariance_cliques(cv, min_size = 2L)
  members_list <- attr(cliques, "members")
  if (is.null(members_list) || length(members_list) == 0L) {
    return(drm_covariance_pairs(object))
  }
  pairs <- character(0)
  for (cl in members_list) {
    if (length(cl) >= 2L) {
      cb <- utils::combn(cl, 2L, simplify = FALSE)
      for (p in cb) {
        pairs <- c(pairs, paste(pmin(p[[1L]], p[[2L]]), pmax(p[[1L]], p[[2L]]), sep = "\r"))
      }
    }
  }
  unique(c(drm_covariance_pairs(object), pairs))
}

#' Covariance cliques of a distributional SEM
#'
#' Detects complete covariance sub-graphs (cliques) among declared [covary()]
#' edges in a distributional SEM, partitioned by covariance class (`"residual"` vs
#' `"higher_level"`) and grouping `level`. For \eqn{K \ge 3} responses with
#' pairwise residual covariances, cliques identify complete joint covariance
#' blocks whose within-clique independence claims are suppressed in [basis_set()].
#'
#' @param object A `drm_sem`, `drm_covariances`, or declaration object.
#' @param min_size Minimum clique size to report (default `2L`).
#' @param ... Unused.
#' @return A `drm_covariance_cliques` data frame with columns `clique_id`,
#'   `class`, `level`, `size`, `nodes`, `pairs_count`, `complete`.
#' @seealso [covary()], [covary_clique()], [covariances()], [basis_set()].
#' @examples
#' cvs <- covary_clique(c("activity", "boldness", "exploration"))
#' covariance_cliques(cvs)
#' @export
covariance_cliques <- function(object, min_size = 2L, ...) {
  UseMethod("covariance_cliques")
}

#' @rdname covariance_cliques
#' @export
covariance_cliques.drm_sem <- function(object, min_size = 2L, ...) {
  cv <- covariances(object)
  drm_find_covariance_cliques(cv, min_size = min_size)
}

#' @rdname covariance_cliques
#' @export
covariance_cliques.drm_covariances <- function(object, min_size = 2L, ...) {
  drm_find_covariance_cliques(object, min_size = min_size)
}

#' @rdname covariance_cliques
#' @export
covariance_cliques.data.frame <- function(object, min_size = 2L, ...) {
  drm_find_covariance_cliques(object, min_size = min_size)
}

#' @rdname covariance_cliques
#' @export
covariance_cliques.default <- function(object, min_size = 2L, ...) {
  if (inherits(object, "drm_covary")) {
    object <- list(object)
  }
  if (is.data.frame(object)) {
    return(drm_find_covariance_cliques(object, min_size = min_size))
  }
  if (is.list(object)) {
    flat <- drm_flatten_covariances(object)
    if (all(vapply(flat, inherits, logical(1), what = "drm_covary"))) {
      nodes <- unique(c(
        vapply(flat, function(x) x$y1, character(1)),
        vapply(flat, function(x) x$y2, character(1))
      ))
      records <- stats::setNames(
        lapply(nodes, function(nm) list(identifiers = nm)),
        nodes
      )
      cv <- drm_build_covariances(flat, records)
      return(drm_find_covariance_cliques(cv, min_size = min_size))
    }
  }
  cli::cli_abort(
    "No {.fn covariance_cliques} method for object of class {.cls {class(object)}}."
  )
}

#' @export
print.drm_covariance_cliques <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<drmSEM covariance cliques: none>")
    return(invisible(x))
  }
  k3 <- sum(x$size >= 3L)
  cli::cli_text(
    "<drmSEM covariance cliques: {nrow(x)} clique{?s} (K >= 3: {k3})>"
  )
  df <- as.data.frame(x)[,
    c("clique_id", "class", "level", "size", "nodes", "pairs_count", "complete"),
    drop = FALSE
  ]
  print.data.frame(df, row.names = FALSE)
  invisible(x)
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
#' \insertRef{ShipleyDouma2021}{drmSEM}
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
