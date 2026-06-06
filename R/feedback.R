#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# 0.5.0 — cyclic / feedback graphs (declaration + equilibrium propagation).
#
# drmSEM is DAG-only by default: any cycle is a hard error. This file lifts that
# restriction ONLY for an explicitly-declared feedback motif (drm_cycle()), per
# the design of record (docs/design/10-cyclic-feedback.md). Two separable
# problems; only the second is solved in the pure-R lane:
#
#   1. FITTING a feedback system consistently (simultaneity bias) needs IV/2SLS
#      or a joint likelihood -- an engine capability. drmSEM warns when a declared
#      cycle is fitted node-wise and never silently claims consistency.
#   2. EFFECT PROPAGATION has no topological order; the estimand is the system's
#      EQUILIBRIUM (fixed point). propagate_fixedpoint() iterates the mean
#      propagation map to that fixed point with a stability / max-iter guard and
#      reports non-convergence honestly (never a fabricated number).
#
# d-separation under a declared cycle: the basis set must not claim independence
# among the motif's nodes (parallel to the covariance-edge rule); full
# sigma-separation is deferred. See basis_set.drm_sem().
# ---------------------------------------------------------------------------

#' Declare a feedback (cyclic) motif
#'
#' drmSEM rejects cycles by default. `drm_cycle()` explicitly names the nodes of
#' a feedback motif — the canonical case being a reciprocal pair `y1 ⇄ y2` — so
#' that those nodes are *allowed* to form a cycle while every undeclared cycle
#' stays a hard error. Pass declarations to [drm_sem()] / [drm_psem()] via their
#' `feedback` argument.
#'
#' Declaring a motif relaxes the topological-order requirement (the motif is
#' treated as a single layer) and makes [basis_set()] drop independence claims
#' among the motif's nodes. It does **not** make node-wise fitting consistent:
#' under simultaneity, ordinary maximum likelihood per node is biased, so
#' [drm_sem()] warns when a declared cycle is fitted naively. Consistent
#' estimation (instrumental variables / a joint likelihood) is an engine
#' capability; equilibrium **effects** from supplied coefficients are computed by
#' the fixed-point propagator. See `docs/design/10-cyclic-feedback.md`.
#'
#' @param ... Two or more node names (strings) forming the feedback motif.
#' @return A `drm_cycle` declaration object.
#' @seealso [cycles()], [drm_sem()].
#' @examples
#' drm_cycle("activity", "boldness")   # a reciprocal pair activity <-> boldness
#' @export
drm_cycle <- function(...) {
  nodes <- list(...)
  ok <- vapply(nodes, function(v) {
    is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
  }, logical(1))
  if (length(nodes) == 0L || !all(ok)) {
    cli::cli_abort(c(
      "{.fn drm_cycle} takes node names as strings.",
      "i" = "e.g. {.code drm_cycle(\"y1\", \"y2\")}."
    ))
  }
  nodes <- unique(unlist(nodes))
  if (length(nodes) < 2L) {
    cli::cli_abort("A feedback motif needs at least two distinct nodes.")
  }
  out <- list(nodes = nodes)
  class(out) <- "drm_cycle"
  out
}

#' @export
print.drm_cycle <- function(x, ...) {
  cli::cli_text("<feedback motif> {paste(x$nodes, collapse = ' <-> ')}")
  invisible(x)
}

# Empty, typed feedback-motif table.
drm_empty_feedback <- function() {
  data.frame(motif = integer(0), node = character(0), stringsAsFactors = FALSE)
}

# Validate drm_cycle() declarations against the node records and build the
# `$feedback` table (long: one row per (motif, node)). `feedback` may be NULL,
# one drm_cycle, or a list of them.
drm_build_feedback <- function(feedback, records) {
  if (is.null(feedback)) {
    return(drm_empty_feedback())
  }
  if (inherits(feedback, "drm_cycle")) {
    feedback <- list(feedback)
  }
  if (!is.list(feedback) ||
      !all(vapply(feedback, inherits, logical(1), what = "drm_cycle"))) {
    cli::cli_abort(c(
      "{.arg feedback} must be {.fn drm_cycle} declaration(s).",
      "i" = "Use {.code feedback = drm_cycle(\"y1\", \"y2\")} or a list of them."
    ))
  }
  resolve <- function(tok) {
    for (nm in names(records)) {
      if (tok %in% records[[nm]]$identifiers) return(nm)
    }
    cli::cli_abort("{.fn drm_cycle}: {.val {tok}} is not a node in this SEM.")
  }
  rows <- list()
  for (i in seq_along(feedback)) {
    ns <- unique(vapply(feedback[[i]]$nodes, resolve, character(1)))
    if (length(ns) < 2L) {
      cli::cli_abort("{.fn drm_cycle}: motif {i} resolves to fewer than two distinct nodes.")
    }
    rows[[i]] <- data.frame(motif = i, node = ns, stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# Motifs (list of node-sets) from a feedback table.
drm_motifs_from_table <- function(fb) {
  if (is.null(fb) || nrow(fb) == 0L) return(list())
  unname(split(fb$node, fb$motif))
}

# Motifs as a list of character vectors (node sets).
drm_feedback_motifs <- function(object) {
  drm_motifs_from_table(object$feedback)
}

# All nodes participating in any declared feedback motif.
drm_feedback_nodes <- function(object) {
  fb <- object$feedback
  if (is.null(fb) || nrow(fb) == 0L) return(character(0))
  unique(fb$node)
}

# Unordered "a\rb" keys for every within-motif node pair, used by basis_set() to
# drop the corresponding independence claim (cf. the covariance-edge rule).
drm_feedback_pairs <- function(object) {
  motifs <- drm_feedback_motifs(object)
  keys <- character(0)
  for (ns in motifs) {
    if (length(ns) < 2L) next
    for (i in seq_len(length(ns) - 1L)) {
      for (j in seq(i + 1L, length(ns))) {
        keys <- c(keys, paste(min(ns[i], ns[j]), max(ns[i], ns[j]), sep = "\r"))
      }
    }
  }
  unique(keys)
}

#' Declared feedback motifs of a distributional SEM
#'
#' Returns the feedback (cyclic) motifs declared via [drm_cycle()] and passed to
#' [drm_sem()] / [drm_psem()] through `feedback =`. Each motif is a set of nodes
#' explicitly allowed to form a cycle; every undeclared cycle remains an error.
#'
#' @param object A `drm_sem` object.
#' @param ... Unused.
#' @return A `drm_cycles` data frame with columns `motif` and `node`.
#' @seealso [drm_cycle()].
#' @examples
#' \dontrun{
#' sem <- drm_psem(activity = a_fit, boldness = b_fit, data = dat,
#'                 feedback = drm_cycle("activity", "boldness"))
#' cycles(sem)
#' }
#' @export
cycles <- function(object, ...) {
  UseMethod("cycles")
}

#' @rdname cycles
#' @export
cycles.drm_sem <- function(object, ...) {
  fb <- object$feedback
  if (is.null(fb)) fb <- drm_empty_feedback()
  class(fb) <- c("drm_cycles", "data.frame")
  fb
}

#' @export
print.drm_cycles <- function(x, ...) {
  if (nrow(x) == 0L) {
    cli::cli_text("<drmSEM feedback motifs: none>")
    return(invisible(x))
  }
  n_motif <- length(unique(x$motif))
  cli::cli_text("<drmSEM feedback motifs: {n_motif}>")
  for (m in unique(x$motif)) {
    ns <- x$node[x$motif == m]
    cli::cli_text("  motif {m}: {paste(ns, collapse = ' <-> ')}")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# Relaxed topological sort: condense each declared motif into a super-node, sort
# the condensed graph, then expand. The SEM is acyclic-modulo-declared-feedback
# iff the condensed graph is a DAG (i.e. the only cycles are inside declared
# motifs). Motif members come out contiguous in the returned order.
# ---------------------------------------------------------------------------
drm_toposort_feedback <- function(nodes, edges, motifs) {
  nodes <- unique(as.character(nodes))
  rep_of <- stats::setNames(nodes, nodes)
  for (ms in motifs) {
    ms <- intersect(ms, nodes)
    if (length(ms) < 1L) next
    r <- ms[[1L]]
    for (n in ms) rep_of[[n]] <- r
  }
  cond_nodes <- unique(unname(rep_of[nodes]))
  if (nrow(edges) == 0L) {
    cond_edges <- data.frame(from = character(0), to = character(0),
                             stringsAsFactors = FALSE)
  } else {
    cf <- unname(rep_of[as.character(edges$from)])
    ct <- unname(rep_of[as.character(edges$to)])
    cond_edges <- data.frame(from = cf, to = ct, stringsAsFactors = FALSE)
    # collapsing a within-motif edge makes a self-loop; drop it.
    cond_edges <- cond_edges[cond_edges$from != cond_edges$to, , drop = FALSE]
  }
  topo <- drm_toposort(cond_nodes, cond_edges)
  if (!topo$acyclic) {
    return(list(order = character(0), acyclic = FALSE))
  }
  members_of <- split(nodes, unname(rep_of[nodes]))
  order <- character(0)
  for (r in topo$order) {
    order <- c(order, nodes[nodes %in% members_of[[r]]])
  }
  list(order = order, acyclic = TRUE)
}

# ---------------------------------------------------------------------------
# Equilibrium (fixed-point) propagation.
#
# Replaces drm_propagate()'s single topological sweep with an iterate-to-fixed-
# point loop over the MEAN propagation map: each endogenous node is re-predicted
# from the current working values of its parents (including the cyclic ones)
# until the active nodes' means stop changing (< tol) or `max_iter` is hit. The
# equilibrium of the means is the linear reduced form (I - B)^{-1} Gamma x in the
# identity-link Gaussian case, and its nonlinear generalization otherwise. When
# the map is not a contraction (no stable equilibrium) the result is flagged
# `converged = FALSE` -- the honest analogue of identified = FALSE elsewhere.
#
# Distributional feedback equilibria (sampling inside the loop) are deferred:
# the fixed point is defined on the deterministic mean map for 0.5.0.
# ---------------------------------------------------------------------------
propagate_fixedpoint <- function(engines, scenario, active = names(engines),
                                 beta_list = NULL, max_iter = 100L, tol = 1e-8) {
  work <- as.data.frame(scenario)
  # Seed each active node's working column so a cyclic parent reference resolves
  # on the first pass.
  for (eng in engines) {
    if (eng$name %in% active && is.null(work[[eng$identifier]])) {
      work[[eng$identifier]] <- rep(0, nrow(work))
    }
  }
  node_mean <- list()
  prev <- NULL
  converged <- FALSE
  iters <- 0L
  for (k in seq_len(max_iter)) {
    iters <- k
    node_mean <- list()
    for (eng in engines) {
      preds <- eng$predict(work, beta = beta_list[[eng$name]])
      node_mean[[eng$name]] <- preds$mu
      if (eng$name %in% active) {
        work[[eng$identifier]] <- preds$mu
      }
    }
    cur <- unlist(node_mean[active], use.names = FALSE)
    if (!is.null(prev) && length(prev) == length(cur) &&
        all(is.finite(cur)) && max(abs(cur - prev)) < tol) {
      converged <- TRUE
      break
    }
    prev <- cur
  }
  list(mean = node_mean, work = work, converged = converged, iterations = iters)
}

# Spectral radius of a direct-effect matrix B (max modulus eigenvalue). The
# equilibrium exists and is stable iff this is < 1.
drm_spectral_radius <- function(B) {
  ev <- eigen(B, only.values = TRUE)$values
  max(Mod(ev))
}

# Linear reduced-form total-effect matrix T = (I - B)^{-1} Gamma, the equilibrium
# response of the endogenous vector to the exogenous design. Carries the spectral
# radius and a `stable` flag (rho(B) < 1); T is NULL when (I - B) is singular.
drm_reduced_form <- function(B, Gamma) {
  B <- as.matrix(B)
  Gamma <- as.matrix(Gamma)
  k <- nrow(B)
  rho <- drm_spectral_radius(B)
  Tm <- tryCatch(solve(diag(k) - B) %*% Gamma, error = function(e) NULL)
  structure(Tm, spectral_radius = rho, stable = rho < 1)
}
