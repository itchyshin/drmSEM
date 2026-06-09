#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# Formula / predictor parsing helpers (pure base R; no drmTMB dependency).
# These are the algorithmic heart of edge extraction and are unit-testable
# without a fitted model.
# ---------------------------------------------------------------------------

# Marker / smooth calls that are NOT simple covariate paths. They are dropped
# when collecting fixed-effect predictors. `mi(x)` is special-cased to keep `x`.
drmsem_marker_funs <- function() {
  c(
    "phylo",
    "phylo_interaction",
    "spatial",
    "animal",
    "relmat",
    "gr",
    "meta_V",
    "meta_known_V",
    "corpair",
    "s",
    "t2",
    "te",
    "ti",
    "offset",
    "poly",
    "I"
  )
}

# Recursively drop random-effect bar groups `(g | h)` and `(g || h)` from an
# expression. Returns a possibly-modified language object, or NULL if the whole
# expression collapses away.
drm_drop_bars <- function(expr) {
  if (is.call(expr) && identical(expr[[1L]], as.name("("))) {
    inner <- expr[[2L]]
    if (
      is.call(inner) &&
        (identical(inner[[1L]], as.name("|")) ||
          identical(inner[[1L]], as.name("||")))
    ) {
      return(NULL)
    }
  }
  if (is.call(expr) && identical(expr[[1L]], as.name("+"))) {
    lhs <- drm_drop_bars(expr[[2L]])
    rhs <- if (length(expr) >= 3L) drm_drop_bars(expr[[3L]]) else NULL
    if (is.null(lhs) && is.null(rhs)) {
      return(NULL)
    }
    if (is.null(lhs)) {
      return(rhs)
    }
    if (is.null(rhs)) {
      return(lhs)
    }
    return(call("+", lhs, rhs))
  }
  expr
}

# Replace `mi(x)` with `x`; drop marker calls (return NULL so the surrounding
# `+` is pruned). Applied recursively.
drm_strip_markers <- function(expr) {
  if (!is.call(expr)) {
    return(expr)
  }
  head <- expr[[1L]]
  if (is.symbol(head)) {
    fun <- as.character(head)
    if (identical(fun, "mi") && length(expr) >= 2L) {
      return(expr[[2L]])
    }
    if (fun %in% drmsem_marker_funs()) {
      return(NULL)
    }
    if (fun == "+") {
      lhs <- drm_strip_markers(expr[[2L]])
      rhs <- if (length(expr) >= 3L) drm_strip_markers(expr[[3L]]) else NULL
      if (is.null(lhs) && is.null(rhs)) {
        return(NULL)
      }
      if (is.null(lhs)) {
        return(rhs)
      }
      if (is.null(rhs)) {
        return(lhs)
      }
      return(call("+", lhs, rhs))
    }
    if (fun %in% c("*", ":", "-", "/")) {
      args <- lapply(as.list(expr)[-1L], drm_strip_markers)
      args <- args[!vapply(args, is.null, logical(1))]
      if (length(args) == 0L) {
        return(NULL)
      }
      if (length(args) == 1L) {
        return(args[[1L]])
      }
      return(as.call(c(head, args)))
    }
  }
  expr
}

#' Extract fixed-effect predictor variable names from a formula right-hand side
#'
#' Drops random-effect bar groups, structured-effect markers, smooth terms, and
#' intercept tokens, then returns the unique variable names that remain.
#'
#' @param rhs A right-hand-side language object (e.g. `entry$rhs`).
#' @return Character vector of predictor variable names (possibly empty).
#' @keywords internal
#' @noRd
drm_fixed_predictors <- function(rhs) {
  if (is.null(rhs)) {
    return(character(0))
  }
  expr <- drm_drop_bars(rhs)
  if (is.null(expr)) {
    return(character(0))
  }
  expr <- drm_strip_markers(expr)
  if (is.null(expr)) {
    return(character(0))
  }
  vars <- all.vars(expr)
  setdiff(unique(vars), c("1", "0", ".", "pi", "T", "F"))
}

# ---------------------------------------------------------------------------
# Graph primitives (pure base R). igraph is used only for plotting layout.
# ---------------------------------------------------------------------------

#' Topological sort of a directed graph by Kahn's algorithm
#'
#' @param nodes Character vector of all node names.
#' @param edges A two-column data.frame/matrix with columns `from`, `to`
#'   (only edges whose endpoints are both in `nodes` constrain the order).
#' @return A list with `order` (character, topologically sorted) and `acyclic`
#'   (logical). When a cycle exists, `order` holds the nodes that could be
#'   ordered and `acyclic` is `FALSE`.
#' @keywords internal
#' @noRd
drm_toposort <- function(nodes, edges) {
  nodes <- unique(as.character(nodes))
  from <- as.character(edges$from)
  to <- as.character(edges$to)
  keep <- from %in% nodes & to %in% nodes & from != to
  from <- from[keep]
  to <- to[keep]

  indeg <- stats::setNames(rep(0L, length(nodes)), nodes)
  for (t in to) {
    indeg[[t]] <- indeg[[t]] + 1L
  }

  ready <- nodes[indeg[nodes] == 0L]
  order <- character(0)
  # Stable: process in original node order among the ready set.
  while (length(ready) > 0L) {
    n <- ready[[1L]]
    ready <- ready[-1L]
    order <- c(order, n)
    out_to <- to[from == n]
    for (m in out_to) {
      indeg[[m]] <- indeg[[m]] - 1L
      if (indeg[[m]] == 0L) {
        # preserve original ordering when inserting
        ready <- c(ready, m)
        ready <- nodes[nodes %in% ready]
      }
    }
  }
  list(order = order, acyclic = length(order) == length(nodes))
}

#' Ancestors (transitive parents) of a node in an edge list
#' @keywords internal
#' @noRd
drm_ancestors <- function(node, edges) {
  from <- as.character(edges$from)
  to <- as.character(edges$to)
  seen <- character(0)
  frontier <- from[to == node]
  while (length(frontier) > 0L) {
    nxt <- setdiff(frontier, seen)
    seen <- union(seen, nxt)
    frontier <- from[to %in% nxt]
  }
  seen
}

#' Direct parents of a node (variable-level), across all components
#' @keywords internal
#' @noRd
drm_parents <- function(node, edges) {
  unique(as.character(edges$from[as.character(edges$to) == node]))
}

#' Enumerate all simple directed paths between two nodes (variable-level)
#'
#' Operates on the collapsed variable-level edge list. Returns a list of
#' character vectors, each a node sequence from `from` to `to`.
#' @keywords internal
#' @noRd
drm_simple_paths <- function(from, to, edges, max_len = 25L) {
  e_from <- as.character(edges$from)
  e_to <- as.character(edges$to)
  results <- list()
  walk <- function(current, visited) {
    if (identical(current, to)) {
      results[[length(results) + 1L]] <<- visited
      return(invisible())
    }
    if (length(visited) > max_len) {
      return(invisible())
    }
    nxts <- unique(e_to[e_from == current])
    for (nx in nxts) {
      if (!nx %in% visited) {
        walk(nx, c(visited, nx))
      }
    }
  }
  walk(from, from)
  results
}
