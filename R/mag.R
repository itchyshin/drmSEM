# DAG -> MAG conversion, marginalised latents only.
#
# SOURCE. Richardson, T. & Spirtes, P. (2002), "Ancestral graph Markov models",
# Ann. Statist. 30(4) 962-1030. Every rule below is taken from that paper (read via
# UW Dept. of Statistics Technical Report 375, the tech-report version; the Project
# Euclid PDF is paywalled, so section/theorem numbers are cited rather than pages).
# Extracted and cross-verified by three independent readings plus adversarial review
# before implementation -- deliberately NOT written from memory, because a subtly
# wrong orientation rule yields independence claims that are plausible and wrong,
# which no downstream test would catch.
#
# SCOPE: marginalised latents only (R&S's L; their selection set S is empty).
# There is no selection argument, so a conditioned latent is structurally
# unrepresentable here rather than merely discouraged. This is not caution: Shipley & Douma
# (2021)'s published orientation rules drop R&S's `∪ S` and are demonstrably wrong
# when S is non-empty, coinciding with R&S §4.2.1 only in the S = ∅ case.
#
# NOT IMPLEMENTED HERE, on purpose:
#   * the basis set over a MAG. R&S Corollary 5.3 proves each pairwise claim
#     (conditioning on ANTERIORS in the MAG, not parents), but pairwise => global
#     was not established, and a basis set needs the global property. Shipley &
#     Douma's parent-based set is unproven on a MAG. So this file converts graphs
#     and stops; nothing here is wired into basis_set() or dsep().
#   * anything involving selection/conditioned latents.

#' Ancestors of `v` in a directed edge table, reflexively.
#'
#' R&S §2.4: `α` is an ancestor of `β` if there is a directed path `α → ... → β`
#' **or `α = β`**. The reflexivity is load-bearing -- the orientation rule reads
#' "α not anterior to β", and a non-reflexive `an` mis-orients every edge whose
#' endpoints coincide with the conditioning target.
#'
#' In a DAG (no undirected edges) anterior and ancestor coincide (R&S Cor. 3.3 +
#' Lemma 3.8(iii)), so one function serves for both.
#' @keywords internal
#' @noRd
drm_ancestors_of <- function(v, edges) {
  seen <- v
  repeat {
    add <- unique(edges$from[edges$to %in% seen])
    new <- setdiff(add, seen)
    if (!length(new)) {
      break
    }
    seen <- c(seen, new)
  }
  seen
}

# All simple UNDIRECTED paths between a and b, as vertex sequences.
#
# Named distinctly from drm_simple_paths() in R/utils.R, which is DIRECTED and is
# used by path_effects(). An earlier draft of this file reused that name; R redefines
# silently, collation order decided which survived, and this function simply did not
# exist as written. The Shipley & Douma acceptance example is what caught it.
#
# SEM graphs are small (a handful of nodes), so enumerating paths and applying
# R&S Theorem 4.2(ii) verbatim is preferable to the equivalent single m-separation
# test of Thm 4.2(iv): it is the definition, not a derived shortcut, and it is far
# easier to check against the paper.
drm_undirected_paths <- function(a, b, edges) {
  nbr <- function(v) unique(c(edges$to[edges$from == v], edges$from[edges$to == v]))
  out <- list()
  walk <- function(path) {
    cur <- path[[length(path)]]
    if (identical(cur, b)) {
      out[[length(out) + 1L]] <<- path
      return(invisible(NULL))
    }
    for (n in setdiff(nbr(cur), path)) {
      walk(c(path, n))
    }
    invisible(NULL)
  }
  walk(a)
  out
}

# Is `z` a collider on this path? R&S §3.4: the edges preceding and succeeding z
# both have an arrowhead at z. In a DAG the only arrowhead is the head of a
# directed edge, so this is prev -> z <- nxt.
drm_is_collider_on <- function(prev, z, nxt, edges) {
  into <- function(u, w) any(edges$from == u & edges$to == w)
  into(prev, z) && into(nxt, z)
}

#' Convert a DAG to a maximal ancestral graph over the observed variables.
#'
#' Marginalising over `latent`; no selection variables (see file header).
#'
#' **Adjacency** (R&S §4.2.3, Theorem 4.2(ii)): `α` and `β` are adjacent in the MAG
#' iff there is an *inducing path* between them -- a path on which every collider is
#' an ancestor of `{α, β}` and every non-collider is in `latent`.
#'
#' **Orientation** (R&S §4.2.1): there is an arrowhead at `α` iff `α` is **not** an
#' ancestor of `β`, and a tail otherwise. With `S = ∅` and a DAG input only `→`,
#' `←` and `↔` can result (R&S Prop. 4.13) -- `—` requires mutual ancestry, which
#' acyclicity forbids.
#'
#' **Ancestors are computed in the ORIGINAL DAG, latents still present.** This is
#' the single easiest thing to get wrong: for `α → u → β` with `u` latent, the
#' inducing path gives adjacency and `α ∈ an(β)` gives `α → β`. Drop the latents
#' first and `α ↔ β` comes out instead -- still a valid MAG, but the wrong one, and
#' every independence claim downstream inherits the error silently.
#'
#' @param edges A data frame of directed edges with `from` and `to`.
#' @param latent Character vector of vertices to marginalise over.
#' @return A data frame `from`, `to`, `type` where `type` is `"-->"` or `"<->"`.
#'   `"-->"` rows are oriented `from -> to`; `"<->"` rows are unordered.
#' @keywords internal
#' @noRd
drm_dag_to_mag <- function(edges, latent = character(0)) {
  edges <- as.data.frame(edges)[, c("from", "to"), drop = FALSE]
  edges$from <- as.character(edges$from)
  edges$to <- as.character(edges$to)
  verts <- unique(c(edges$from, edges$to))
  latent <- intersect(as.character(latent), verts)
  obs <- setdiff(verts, latent)

  anc <- stats::setNames(lapply(verts, drm_ancestors_of, edges = edges), verts)

  rows <- list()
  if (length(obs) >= 2L) {
    pairs <- utils::combn(sort(obs), 2L, simplify = FALSE)
    for (p in pairs) {
      a <- p[[1L]]
      b <- p[[2L]]
      an_ab <- unique(c(anc[[a]], anc[[b]]))
      adjacent <- FALSE
      for (path in drm_undirected_paths(a, b, edges)) {
        if (length(path) < 2L) {
          next
        }
        ok <- TRUE
        # Endpoints are never colliders or non-colliders (R&S §3.4): only
        # non-endpoint vertices are classified. Treating an endpoint as a
        # non-collider would demand it be latent and collapse the graph to empty.
        if (length(path) > 2L) {
          for (k in seq(2L, length(path) - 1L)) {
            z <- path[[k]]
            if (drm_is_collider_on(path[[k - 1L]], z, path[[k + 1L]], edges)) {
              if (!z %in% an_ab) {
                ok <- FALSE
                break
              }
            } else if (!z %in% latent) {
              ok <- FALSE
              break
            }
          }
        }
        if (ok) {
          adjacent <- TRUE
          break
        }
      }
      if (!adjacent) {
        next
      }
      head_at_a <- !a %in% anc[[b]]
      head_at_b <- !b %in% anc[[a]]
      if (head_at_a && head_at_b) {
        rows[[length(rows) + 1L]] <- data.frame(
          from = a, to = b, type = "<->", stringsAsFactors = FALSE
        )
      } else if (head_at_b) {
        rows[[length(rows) + 1L]] <- data.frame(
          from = a, to = b, type = "-->", stringsAsFactors = FALSE
        )
      } else if (head_at_a) {
        rows[[length(rows) + 1L]] <- data.frame(
          from = b, to = a, type = "-->", stringsAsFactors = FALSE
        )
      } else {
        # Tails at both ends means mutual ancestry, impossible in a DAG.
        cli::cli_abort(
          "Undirected edge between {.val {a}} and {.val {b}}: the input is not acyclic."
        )
      }
    }
  }
  if (!length(rows)) {
    return(data.frame(
      from = character(0), to = character(0), type = character(0),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Is `a` adjacent to `b` in a MAG edge table?
#' @keywords internal
#' @noRd
drm_mag_is_adjacent <- function(mag, a, b) {
  if (!nrow(mag)) {
    return(FALSE)
  }
  a <- as.character(a)
  b <- as.character(b)
  any(
    (mag$from == a & mag$to == b) | (mag$from == b & mag$to == a),
    na.rm = TRUE
  )
}

#' Anterior set of `v` in a MAG (reflexive).
#'
#' Follows directed tails into `v` and spouses across bidirected edges, then
#' closes transitively. Matches R&S anterior on ancestral graphs for MAGs built
#' with `S = \emptyset`.
#' @keywords internal
#' @noRd
drm_mag_anterior_of <- function(v, mag) {
  # R&S anterior: reflexive closure along --> and undirected --- only.
  # Bidirected spouses (<->) are NOT anteriors (arrowheads at both ends).
  # Walking <-> here would emit the false claim A _||_ Y | {X} on A-->X<->Y.
  v <- as.character(v)
  seen <- v
  if (!nrow(mag)) {
    return(seen)
  }
  repeat {
    add <- character(0)
    idx <- mag$type == "-->" & mag$to %in% seen
    if (any(idx)) {
      add <- c(add, mag$from[idx])
    }
    # Undirected edges (---) do not arise from DAG+S=emptyset marginalisation,
    # but honour them if present so anterior matches R&S on general AGs.
    idx <- mag$type %in% c("---", "--") & (mag$from %in% seen | mag$to %in% seen)
    if (any(idx)) {
      add <- c(add, mag$from[idx], mag$to[idx])
    }
    new <- setdiff(unique(add), seen)
    if (!length(new)) {
      break
    }
    seen <- c(seen, new)
  }
  seen
}

#' Conditioning set for a Cor. 5.3 pairwise claim: ant({alpha, beta}) \\ {alpha, beta}.
#' @keywords internal
#' @noRd
drm_mag_anteriors <- function(mag, alpha, beta) {
  alpha <- as.character(alpha)
  beta <- as.character(beta)
  ant <- unique(c(
    drm_mag_anterior_of(alpha, mag),
    drm_mag_anterior_of(beta, mag)
  ))
  setdiff(ant, c(alpha, beta))
}

#' Build a MAG from collapsed DAG edges and marginalised latent names.
#' @keywords internal
#' @noRd
drm_build_mag <- function(dag_edges, latents) {
  latents <- as.character(latents)
  if (!length(latents)) {
    return(NULL)
  }
  edges <- as.data.frame(dag_edges)[, c("from", "to"), drop = FALSE]
  drm_dag_to_mag(edges, latent = latents)
}
