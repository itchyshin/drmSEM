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
#' @references
#' \insertRef{Bollen1996}{drmSEM}
#'
#' \insertRef{ForreMooij2017}{drmSEM}
#'
#' \insertRef{Bollen1989}{drmSEM}
#' @examples
#' drm_cycle("activity", "boldness")   # a reciprocal pair activity <-> boldness
#' @export
drm_cycle <- function(...) {
  nodes <- list(...)
  ok <- vapply(
    nodes,
    function(v) {
      is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
    },
    logical(1)
  )
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
  if (
    !is.list(feedback) ||
      !all(vapply(feedback, inherits, logical(1), what = "drm_cycle"))
  ) {
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
      cli::cli_abort(
        "{.fn drm_cycle}: motif {i} resolves to fewer than two distinct nodes."
      )
    }
    rows[[i]] <- data.frame(motif = i, node = ns, stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

# Motifs (list of node-sets) from a feedback table.
drm_motifs_from_table <- function(fb) {
  if (is.null(fb) || nrow(fb) == 0L) {
    return(list())
  }
  unname(split(fb$node, fb$motif))
}

# Motifs as a list of character vectors (node sets).
drm_feedback_motifs <- function(object) {
  drm_motifs_from_table(object$feedback)
}

# All nodes participating in any declared feedback motif.
drm_feedback_nodes <- function(object) {
  fb <- object$feedback
  if (is.null(fb) || nrow(fb) == 0L) {
    return(character(0))
  }
  unique(fb$node)
}

# Unordered "a\rb" keys for every within-motif node pair, used by basis_set() to
# drop the corresponding independence claim (cf. the covariance-edge rule).
drm_feedback_pairs <- function(object) {
  motifs <- drm_feedback_motifs(object)
  keys <- character(0)
  for (ns in motifs) {
    if (length(ns) < 2L) {
      next
    }
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
#' @references
#' \insertRef{Bollen1996}{drmSEM}
#'
#' \insertRef{ForreMooij2017}{drmSEM}
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
  if (is.null(fb)) {
    fb <- drm_empty_feedback()
  }
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
    if (length(ms) < 1L) {
      next
    }
    r <- ms[[1L]]
    for (n in ms) {
      rep_of[[n]] <- r
    }
  }
  cond_nodes <- unique(unname(rep_of[nodes]))
  if (nrow(edges) == 0L) {
    cond_edges <- data.frame(
      from = character(0),
      to = character(0),
      stringsAsFactors = FALSE
    )
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
# point loop over the multi-component propagation map: each endogenous node is
# re-predicted across all modelled distributional components (mu, sigma, nu, zi, hu)
# from the current working values of its parents (including cyclic ones) until
# the active nodes' states stop changing (< tol) or `max_iter` is hit. Vectorized
# Banach contraction iteration with adaptive relaxation is applied to resolve
# oscillations. Contraction constants and spectral radius diagnostics are tracked
# and non-convergence is reported honestly (never a fabricated number).
# ---------------------------------------------------------------------------

# Extract linear direct effect matrix B for active Gaussian nodes when available.
drm_extract_B <- function(engines, active, beta_list = NULL) {
  k <- length(active)
  if (k == 0L) {
    return(list(B = matrix(0, 0, 0), spectral_radius = NA_real_, is_linear_gaussian = FALSE))
  }
  B <- matrix(0, nrow = k, ncol = k, dimnames = list(active, active))
  is_lin_gauss <- TRUE
  for (i in seq_along(active)) {
    nm_i <- active[[i]]
    eng_i <- engines[[nm_i]]
    fam <- if (is.character(eng_i$family)) eng_i$family else if (is.list(eng_i$family)) eng_i$family$family else "gaussian"
    link <- if (is.character(eng_i$links)) eng_i$links[["mu"]] %||% "identity" else if (is.list(eng_i$links)) eng_i$links$mu %||% "identity" else "identity"
    if (!fam %in% c("gaussian", "stats::gaussian", stats::gaussian()$family) || !identical(link, "identity")) {
      is_lin_gauss <- FALSE
    }
    coefs <- if (!is.null(beta_list[[nm_i]])) {
      if (is.list(beta_list[[nm_i]])) beta_list[[nm_i]][["mu"]] %||% beta_list[[nm_i]][[1L]] else beta_list[[nm_i]]
    } else {
      if (is.list(eng_i$coef)) eng_i$coef[["mu"]] %||% eng_i$coef[[1L]] else eng_i$coef
    }
    if (!is.null(coefs)) {
      for (j in seq_along(active)) {
        if (i == j) next
        nm_j <- active[[j]]
        eng_j <- engines[[nm_j]]
        ident_j <- eng_j$identifier %||% nm_j
        if (ident_j %in% names(coefs)) {
          B[i, j] <- as.numeric(coefs[[ident_j]])
        } else if (nm_j %in% names(coefs)) {
          B[i, j] <- as.numeric(coefs[[nm_j]])
        }
      }
    }
  }
  rho <- if (any(B != 0)) drm_spectral_radius(B) else NA_real_
  list(B = B, spectral_radius = rho, is_linear_gaussian = is_lin_gauss)
}

# Empirical Lipschitz contraction constant computed from iterate deltas.
drm_empirical_contraction_constant <- function(deltas) {
  if (length(deltas) < 2L) {
    return(NA_real_)
  }
  d_prev <- deltas[-length(deltas)]
  d_curr <- deltas[-1L]
  valid <- is.finite(d_prev) & is.finite(d_curr) & (d_prev > 1e-14)
  if (!any(valid)) {
    return(0)
  }
  ratios <- d_curr[valid] / d_prev[valid]
  ratios <- ratios[is.finite(ratios)]
  if (length(ratios) == 0L) {
    return(NA_real_)
  }
  tail_n <- min(length(ratios), 10L)
  tail_ratios <- utils::tail(ratios, tail_n)
  max(tail_ratios)
}

propagate_fixedpoint <- function(
  engines,
  scenario,
  active = names(engines),
  beta_list = NULL,
  max_iter = 200L,
  tol = 1e-8,
  damping = 1.0,
  adaptive_relaxation = TRUE
) {
  work <- as.data.frame(scenario)
  # Seed each active node's working column so a cyclic parent reference resolves
  # on the first pass.
  for (eng in engines) {
    if (eng$name %in% active && is.null(work[[eng$identifier]])) {
      work[[eng$identifier]] <- rep(0, nrow(work))
    }
  }

  lin_diag <- drm_extract_B(engines, active, beta_list)
  spectral_radius <- lin_diag$spectral_radius

  node_mean <- list()
  node_comps <- list()
  prev_state <- NULL
  prev_diff <- NULL
  deltas <- numeric()
  converged <- FALSE
  iters <- 0L
  alpha <- damping

  for (k in seq_len(max_iter)) {
    iters <- k
    cur_means <- list()
    cur_comps <- list()
    prev_work <- work

    # Multi-component evaluation across all engines
    for (eng in engines) {
      preds <- as.data.frame(eng$predict(work, beta = beta_list[[eng$name]]))
      fam <- eng$family %||% "gaussian"
      mod_type <- eng$model_type %||% NA_character_
      eff_fam <- drm_effective_family(fam, mod_type)
      expected <- drm_family_expected_mean(eff_fam, preds)
      cur_comps[[eng$name]] <- preds
      cur_means[[eng$name]] <- expected
    }

    # Extract state vector across all active nodes (expected means + all predicted components)
    state_pieces <- list()
    for (nm in active) {
      if (!is.null(cur_means[[nm]])) {
        state_pieces[[length(state_pieces) + 1L]] <- as.numeric(cur_means[[nm]])
      }
      if (!is.null(cur_comps[[nm]])) {
        num_cols <- vapply(cur_comps[[nm]], is.numeric, logical(1))
        if (any(num_cols)) {
          for (cn in names(cur_comps[[nm]])[num_cols]) {
            state_pieces[[length(state_pieces) + 1L]] <- as.numeric(cur_comps[[nm]][[cn]])
          }
        }
      }
    }
    cur_state <- unlist(state_pieces, use.names = FALSE)

    if (any(!is.finite(cur_state)) || any(abs(cur_state) > 1e12)) {
      converged <- FALSE
      break
    }

    if (!is.null(prev_state) && length(prev_state) == length(cur_state)) {
      diff_vec <- cur_state - prev_state
      delta_k <- max(abs(diff_vec))
      deltas <- c(deltas, delta_k)

      if (delta_k < tol) {
        converged <- TRUE
        node_mean <- cur_means
        node_comps <- cur_comps
        break
      }

      if (delta_k > 1e10 || (length(deltas) >= 15L && all(utils::tail(deltas, 5L) > 1e4))) {
        converged <- FALSE
        break
      }

      # Adaptive relaxation when oscillation is detected
      if (isTRUE(adaptive_relaxation) && !is.null(prev_diff) && length(prev_diff) == length(diff_vec)) {
        inner_prod <- sum(diff_vec * prev_diff)
        if (inner_prod < 0) {
          # Oscillation detected -> under-relax
          alpha <- max(0.05, alpha * 0.7)
        } else if (length(deltas) >= 2L && delta_k < deltas[length(deltas) - 1L] * 0.95 && alpha < 1.0) {
          # Monotonic contraction -> restore full step size
          alpha <- min(1.0, alpha * 1.05)
        }
      }
      prev_diff <- diff_vec
    }

    # Update active working variables with relaxed step
    for (eng in engines) {
      if (eng$name %in% active) {
        new_val <- cur_means[[eng$name]]
        old_val <- prev_work[[eng$identifier]]
        if (is.null(old_val)) old_val <- new_val
        work[[eng$identifier]] <- (1 - alpha) * old_val + alpha * new_val
      }
    }

    prev_state <- cur_state
    node_mean <- cur_means
    node_comps <- cur_comps
  }

  contraction_constant <- drm_empirical_contraction_constant(deltas)

  # Check stability guard
  if (!is.na(spectral_radius) && spectral_radius >= 1.0) {
    converged <- FALSE
  }
  if (!is.na(contraction_constant) && contraction_constant >= 1.0 && !converged) {
    converged <- FALSE
  }

  list(
    mean = node_mean,
    components = node_comps,
    work = work,
    converged = converged,
    iterations = iters,
    spectral_radius = spectral_radius,
    contraction_constant = contraction_constant,
    deltas = deltas
  )
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

# Equilibrium total-effect contrast of `from` on `to` for a feedback SEM. Per
# uncertainty replicate, one shared coefficient draw is propagated to the
# system's fixed point under the high and low scenarios; the contrast of the
# equilibrium mean of `to` is returned. `converged` is FALSE if ANY propagation
# (any replicate, either scenario) failed to reach a stable equilibrium -- the
# honest signal that no population-average equilibrium effect is defined (the
# feedback diverges, spectral radius >= 1). Used by total_effects() (0.5.x);
# the equilibrium is on the deterministic multi-component map, so this is target = "mean"
# and the mean/distribution decomposition through a cycle is out of scope.
drm_equilibrium_contrast <- function(
  engines,
  scenarios,
  to,
  B,
  draw,
  seed = NULL,
  max_iter = 200L,
  tol = 1e-8,
  damping = 1.0,
  adaptive_relaxation = TRUE
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  reps <- if (isTRUE(draw)) B else 1L
  vals <- numeric(reps)
  ok <- logical(reps)
  active <- names(engines)
  spectral_radii <- numeric(reps)
  contraction_constants <- numeric(reps)

  for (b in seq_len(reps)) {
    beta_list <- lapply(engines, drm_draw_beta, draw = draw)
    names(beta_list) <- names(engines)
    hi <- propagate_fixedpoint(
      engines,
      scenarios$hi,
      active = active,
      beta_list = beta_list,
      max_iter = max_iter,
      tol = tol,
      damping = damping,
      adaptive_relaxation = adaptive_relaxation
    )
    lo <- propagate_fixedpoint(
      engines,
      scenarios$lo,
      active = active,
      beta_list = beta_list,
      max_iter = max_iter,
      tol = tol,
      damping = damping,
      adaptive_relaxation = adaptive_relaxation
    )
    ok[[b]] <- isTRUE(hi$converged) && isTRUE(lo$converged)
    sr_hi <- hi$spectral_radius %||% NA_real_
    sr_lo <- lo$spectral_radius %||% NA_real_
    spectral_radii[[b]] <- if (is.finite(sr_hi) || is.finite(sr_lo)) max(sr_hi, sr_lo, na.rm = TRUE) else NA_real_

    cc_hi <- hi$contraction_constant %||% NA_real_
    cc_lo <- lo$contraction_constant %||% NA_real_
    contraction_constants[[b]] <- if (is.finite(cc_hi) || is.finite(cc_lo)) max(cc_hi, cc_lo, na.rm = TRUE) else NA_real_

    vals[[b]] <- if (ok[[b]]) {
      mean(hi$mean[[to]] - lo$mean[[to]], na.rm = TRUE)
    } else {
      NA_real_
    }
  }

  list(
    vals = vals,
    converged = all(ok),
    status = if (all(ok)) "converged" else "non_convergent",
    spectral_radius = if (any(is.finite(spectral_radii))) mean(spectral_radii, na.rm = TRUE) else NA_real_,
    contraction_constant = if (any(is.finite(contraction_constants))) mean(contraction_constants, na.rm = TRUE) else NA_real_
  )
}
