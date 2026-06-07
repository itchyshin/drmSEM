#' @keywords internal
#' @noRd
NULL

# ---------------------------------------------------------------------------
# Graph-interchange (interop) layer.
#
# Pure-R graph interchange between a drmSEM component-labelled graph and the
# neighbouring ecosystems' text formats. This is NOT a fitting bridge: drmSEM
# never fits its own likelihoods, and lavaan/brms FITTING interop stays out of
# the 0.x scope (docs/design/05-roadmap.md, "Interop and distribution"). The
# functions here translate the *structure* only.
#
# CRITICAL honesty rule (AGENTS.md, Core Scope): lavaan model syntax has no way
# to express a distributional-component path (an arrow into sigma / zi / nu / hu
# / sd(group) / rho12). Such a path is therefore NEVER silently emitted as a
# lavaan mean (`~`) regression. as_lavaan() collapses to the mean structure and
# reports every dropped non-mu path, both as a `dropped` attribute and as a
# one-time cli message, so the loss is explicit rather than misrepresented.
# ---------------------------------------------------------------------------

# Directed mean-structure edges (component == "mu*") collapsed to a per-`to`
# list of source variables, preserving first-seen order and dropping duplicates.
# Returns a named list keyed by endogenous node (the regression LHS).
drm_mean_edges_by_to <- function(edges) {
  if (is.null(edges) || nrow(edges) == 0L) {
    return(list())
  }
  is_mu <- startsWith(edges$component, "mu")
  me <- edges[is_mu, , drop = FALSE]
  out <- list()
  for (i in seq_len(nrow(me))) {
    to <- me$to[[i]]
    from <- me$from[[i]]
    cur <- out[[to]]
    if (is.null(cur)) cur <- character(0)
    if (!from %in% cur) {
      out[[to]] <- c(cur, from)
    }
  }
  out
}

# The non-mu component paths, as a small character vector of "from -> component
# of to" strings, for the dropped attribute and the honesty message.
drm_nonmu_dropped <- function(edges) {
  if (is.null(edges) || nrow(edges) == 0L) {
    return(character(0))
  }
  is_mu <- startsWith(edges$component, "mu")
  ne <- edges[!is_mu, , drop = FALSE]
  if (nrow(ne) == 0L) {
    return(character(0))
  }
  unique(sprintf("%s -> %s of %s", ne$from, ne$component, ne$to))
}

# Build the lavaan-syntax string from a per-`to` mean-edge list, a covariance
# data frame, and the topological node order (so lines emit in a stable order).
drm_lavaan_syntax <- function(mean_by_to, covariances, order = NULL) {
  lines <- character(0)
  tos <- names(mean_by_to)
  if (!is.null(order)) {
    tos <- c(intersect(order, tos), setdiff(tos, order))
  }
  for (to in tos) {
    rhs <- mean_by_to[[to]]
    if (length(rhs) == 0L) next
    lines <- c(lines, sprintf("%s ~ %s", to, paste(rhs, collapse = " + ")))
  }
  if (!is.null(covariances) && nrow(covariances) > 0L) {
    for (i in seq_len(nrow(covariances))) {
      lines <- c(lines, sprintf("%s ~~ %s", covariances$y1[[i]], covariances$y2[[i]]))
    }
  }
  paste(lines, collapse = "\n")
}

#' Export a distributional SEM as lavaan model syntax
#'
#' `as_lavaan()` renders the **mean structure** of a drmSEM graph as a
#' lavaan-style model-syntax string: one `y ~ x1 + x2` regression line per
#' endogenous node (from the variable-level directed edges) and one `y1 ~~ y2`
#' line per declared covariance edge ([covariances()]).
#'
#' This is *graph interchange*, not a fitting bridge — drmSEM never fits its own
#' likelihoods and does not call lavaan. **Honesty:** lavaan model syntax cannot
#' express a distributional-component path (an arrow into `sigma`, `zi`, `nu`,
#' `hu`, `sd(group)`, or `rho12`). Such paths are therefore **collapsed away**,
#' never silently emitted as a mean (`~`) regression. Every dropped non-`mu` path
#' is attached as a `dropped` attribute and reported once via a `cli` message, so
#' the loss is explicit.
#'
#' @param object A `drm_sem` (from [drm_sem()] / [drm_psem()]) or a `drm_dag`
#'   (from [drm_dag()]).
#' @param ... Unused.
#'
#' @return A length-1 character string of class `drm_lavaan` (its print method
#'   `cat()`s the syntax). The `dropped` attribute lists any non-`mu` component
#'   paths that lavaan syntax could not represent.
#' @seealso [from_lavaan()], [as_dot()], [covariances()].
#' @examples
#' # From an unfitted candidate DAG (no engine needed):
#' dag <- drm_dag(size ~ temp, abundance ~ size + temp)
#' as_lavaan(dag)
#' @export
as_lavaan <- function(object, ...) {
  UseMethod("as_lavaan")
}

# Construct the classed string + emit the one-time honesty message.
drm_new_lavaan <- function(syntax, dropped) {
  if (length(dropped) > 0L) {
    cli::cli_inform(c(
      "!" = "{length(dropped)} non-{.field mu} component path{?s} cannot be expressed in lavaan syntax and {?was/were} dropped.",
      "i" = "Dropped: {.val {dropped}}.",
      "i" = "lavaan models the mean structure only; the distributional-component paths live in the drmSEM graph (see {.fn paths})."
    ))
  }
  structure(syntax, dropped = dropped, class = "drm_lavaan")
}

#' @rdname as_lavaan
#' @export
as_lavaan.drm_sem <- function(object, ...) {
  mean_by_to <- drm_mean_edges_by_to(object$edges)
  dropped <- drm_nonmu_dropped(object$edges)
  cv <- object$covariances
  syntax <- drm_lavaan_syntax(mean_by_to, cv, order = object$order)
  drm_new_lavaan(syntax, dropped)
}

#' @rdname as_lavaan
#' @export
as_lavaan.drm_dag <- function(object, ...) {
  ext <- drm_dag_edges(object)
  mean_by_to <- drm_mean_edges_by_to(ext$edges)
  dropped <- drm_nonmu_dropped(ext$edges)
  syntax <- drm_lavaan_syntax(mean_by_to, NULL, order = object$responses)
  drm_new_lavaan(syntax, dropped)
}

#' @export
print.drm_lavaan <- function(x, ...) {
  cat(unclass(x), "\n", sep = "")
  invisible(x)
}

# Extract a component-labelled edge table from an (unfitted) drm_dag, working
# from the captured node formulas alone (pure base R; no fitted model). For a
# plain formula every predictor is a `mu` path; for a drmTMB::bf()/drm_formula
# each entry's `dpar` names the component.
drm_dag_edges <- function(dag) {
  nodes <- dag$responses
  rows <- list()
  for (nm in names(dag$formulas)) {
    f <- dag$formulas[[nm]]
    comp_rhs <- drm_dag_component_rhs(f)
    for (cmp in names(comp_rhs)) {
      preds <- drm_fixed_predictors(comp_rhs[[cmp]])
      for (p in preds) {
        if (identical(p, nm)) next
        endo <- p %in% nodes
        rows[[length(rows) + 1L]] <- data.frame(
          from = p, to = nm, component = cmp, term = p,
          endogenous = endo, stringsAsFactors = FALSE
        )
      }
    }
  }
  edges <- if (length(rows) == 0L) {
    data.frame(from = character(0), to = character(0), component = character(0),
               term = character(0), endogenous = logical(0),
               stringsAsFactors = FALSE)
  } else {
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
  }
  list(nodes = nodes, edges = edges)
}

# Map a captured node formula to a named list `component -> rhs language object`.
# A plain formula is a single `mu` component. A drm_formula (drmTMB::bf) carries
# one entry per distributional parameter; `dpar` names the component.
drm_dag_component_rhs <- function(f) {
  if (inherits(f, "formula")) {
    return(list(mu = if (length(f) >= 3L) f[[3L]] else f[[2L]]))
  }
  if (inherits(f, "drm_formula") && !is.null(f$entries)) {
    out <- list()
    for (e in f$entries) {
      cmp <- if (!is.null(e$dpar)) as.character(e$dpar) else "mu"
      rhs <- e$rhs
      if (is.null(rhs) && !is.null(e$formula) && length(e$formula) >= 3L) {
        rhs <- e$formula[[3L]]
      }
      if (!is.null(rhs)) out[[cmp]] <- rhs
    }
    if (length(out) > 0L) return(out)
  }
  # Fallback: treat the whole object as a mean formula RHS.
  if (length(f) >= 3L) list(mu = f[[3L]]) else list()
}

# ---------------------------------------------------------------------------
# from_lavaan(): pure string parsing of lavaan model syntax into a drmSEM
# graph skeleton. We split on operators, never evaluate, and never fit.
# ---------------------------------------------------------------------------

# Split lavaan syntax into non-empty, comment-stripped logical lines. lavaan
# allows `#` and `!` comments and `;`/newline line separators.
drm_lavaan_lines <- function(syntax) {
  if (!is.character(syntax) || length(syntax) != 1L || is.na(syntax)) {
    cli::cli_abort("{.arg syntax} must be a single lavaan model-syntax string.")
  }
  raw <- unlist(strsplit(syntax, "[\n;]", perl = TRUE))
  # strip trailing comments (# or !) and surrounding whitespace
  raw <- sub("[#!].*$", "", raw)
  raw <- trimws(raw)
  raw[nzchar(raw)]
}

# Split a RHS predictor string like " a + 0.5*b + c " into bare variable tokens,
# dropping lavaan numeric prefixes / fixed loadings (`0.5*b` -> `b`) and the
# intercept/labels.
drm_lavaan_rhs_tokens <- function(rhs) {
  parts <- trimws(unlist(strsplit(rhs, "\\+")))
  parts <- parts[nzchar(parts)]
  toks <- vapply(parts, function(p) {
    # a `label*var` or `coef*var` prefix: keep the part after the last `*`
    if (grepl("\\*", p)) {
      p <- trimws(sub("^.*\\*", "", p))
    }
    p
  }, character(1), USE.NAMES = FALSE)
  toks <- toks[nzchar(toks)]
  setdiff(unique(toks), c("1", "0"))
}

#' Parse lavaan model syntax into a drmSEM graph skeleton
#'
#' `from_lavaan()` reads a lavaan-style model-syntax string and returns a drmSEM
#' graph skeleton: the `~` regression lines become per-response node formulas
#' (assembled into a [drm_dag()]), and the `~~` covariance lines become
#' [covary()] declarations. This is pure string parsing — nothing is evaluated
#' or fitted.
#'
#' Reflective latent measurement (`=~`) lines are **ignored with a warning**:
#' reflective measurement models need a joint likelihood and are out of the 0.x
#' scope (`docs/design/09-latent-variables.md`). Variance / intercept-only lines
#' (`x ~~ x`, `x ~ 1`) are skipped.
#'
#' @param syntax A single lavaan model-syntax string.
#'
#' @return A list of class `drm_skeleton` with elements `dag` (a [drm_dag()] of
#'   the regression structure, or `NULL` if there were no `~` lines) and
#'   `covary` (a list of [covary()] declarations from the `~~` lines, possibly
#'   empty).
#' @seealso [as_lavaan()], [drm_dag()], [covary()].
#' @examples
#' skel <- from_lavaan("abundance ~ size + temp\nsize ~ temp\nsize ~~ abundance")
#' skel$dag
#' skel$covary
#' @export
from_lavaan <- function(syntax) {
  lines <- drm_lavaan_lines(syntax)
  if (any(grepl("=~", lines, fixed = TRUE))) {
    n_meas <- sum(grepl("=~", lines, fixed = TRUE))
    cli::cli_warn(c(
      "Ignoring {n_meas} reflective measurement (`=~`) line{?s}.",
      "i" = "Reflective latent measurement needs a joint likelihood and is out of the drmSEM 0.x scope (see {.file docs/design/09-latent-variables.md})."
    ))
    lines <- lines[!grepl("=~", lines, fixed = TRUE)]
  }

  reg_rhs <- list()   # response -> character() of predictors (first-seen order)
  covs <- list()
  for (ln in lines) {
    if (grepl("~~", ln, fixed = TRUE)) {
      sides <- strsplit(ln, "~~", fixed = TRUE)[[1L]]
      y1 <- trimws(sides[[1L]])
      y2 <- if (length(sides) >= 2L) trimws(sides[[2L]]) else ""
      if (!nzchar(y1) || !nzchar(y2) || identical(y1, y2)) next  # skip variances
      covs[[length(covs) + 1L]] <- covary(y1, y2)
    } else if (grepl("~", ln, fixed = TRUE)) {
      sides <- strsplit(ln, "~", fixed = TRUE)[[1L]]
      resp <- trimws(sides[[1L]])
      rhs <- if (length(sides) >= 2L) sides[[2L]] else ""
      toks <- drm_lavaan_rhs_tokens(rhs)
      if (!nzchar(resp) || length(toks) == 0L) next  # skip intercept-only
      cur <- reg_rhs[[resp]]
      if (is.null(cur)) cur <- character(0)
      reg_rhs[[resp]] <- unique(c(cur, toks))
    }
    # other operators (e.g. `:=`, `==`) are not graph structure: ignore.
  }

  dag <- NULL
  if (length(reg_rhs) > 0L) {
    formulas <- lapply(names(reg_rhs), function(resp) {
      stats::as.formula(
        paste(resp, "~", paste(reg_rhs[[resp]], collapse = " + ")),
        env = baseenv()
      )
    })
    dag <- do.call(drm_dag, formulas)
  }

  structure(list(dag = dag, covary = covs), class = "drm_skeleton")
}

#' @export
print.drm_skeleton <- function(x, ...) {
  cli::cli_text("<drmSEM graph skeleton (from lavaan syntax)>")
  if (is.null(x$dag)) {
    cli::cli_text("  no regression (`~`) structure")
  } else {
    cli::cli_text("  {length(x$dag$formulas)} node{?s}: {.val {x$dag$responses}}")
  }
  nc <- length(x$covary)
  cli::cli_text("  {nc} covariance edge{?s} (`~~`)")
  invisible(x)
}

# ---------------------------------------------------------------------------
# as_dot(): Graphviz DOT export of the component-labelled DAG.
# ---------------------------------------------------------------------------

# Style hint per component: mean paths solid; distributional-component paths get
# a dashed/coloured edge so the label is reinforced visually. Best-effort only.
drm_dot_edge_attr <- function(component) {
  base <- sprintf('label="%s"', component)
  if (startsWith(component, "mu")) {
    return(base)
  }
  # non-mean component: dashed, to mirror the "this is not a mean path" framing
  sprintf('%s, style=dashed, color="#777777", fontcolor="#777777"', base)
}

# Quote a node id for DOT (always quote: drmSEM node names may contain dots etc.)
drm_dot_id <- function(x) sprintf('"%s"', x)

# Build the DOT string from a typed edge table (columns from, to, component)
# and the full node set.
drm_dot_syntax <- function(edges, nodes) {
  lines <- c("digraph drmSEM {", "  rankdir=LR;",
             "  node [shape=box, style=rounded];")
  for (n in nodes) {
    lines <- c(lines, sprintf("  %s;", drm_dot_id(n)))
  }
  if (!is.null(edges) && nrow(edges) > 0L) {
    for (i in seq_len(nrow(edges))) {
      lines <- c(lines, sprintf(
        "  %s -> %s [%s];",
        drm_dot_id(edges$from[[i]]), drm_dot_id(edges$to[[i]]),
        drm_dot_edge_attr(edges$component[[i]])
      ))
    }
  }
  lines <- c(lines, "}")
  paste(lines, collapse = "\n")
}

#' Export a distributional SEM as Graphviz DOT
#'
#' `as_dot()` renders the **component-labelled** structural graph as a Graphviz
#' DOT string: one edge per typed edge (`from -> to`), with the distributional
#' component (`mu`, `sigma`, `zi`, ...) as the edge label. Non-mean paths are
#' dashed and greyed so a `sigma` / `zi` arrow reads differently from a mean
#' arrow. Unlike [as_lavaan()], DOT keeps **every** component path — nothing is
#' dropped.
#'
#' @param object A `drm_sem` or a `drm_dag`.
#' @param ... Unused.
#'
#' @return A length-1 character string of class `drm_dot` (its print method
#'   `cat()`s the DOT source). Pipe it to Graphviz (`dot -Tpng`) or
#'   `DiagrammeR::grViz()` to render.
#' @seealso [as_lavaan()], [plot.drm_sem()].
#' @examples
#' dag <- drm_dag(size ~ temp, abundance ~ size + temp)
#' as_dot(dag)
#' @export
as_dot <- function(object, ...) {
  UseMethod("as_dot")
}

#' @rdname as_dot
#' @export
as_dot.drm_sem <- function(object, ...) {
  nodes <- unique(c(object$order, object$endogenous, object$exogenous,
                    object$edges$from, object$edges$to))
  structure(drm_dot_syntax(object$edges, nodes), class = "drm_dot")
}

#' @rdname as_dot
#' @export
as_dot.drm_dag <- function(object, ...) {
  ext <- drm_dag_edges(object)
  nodes <- unique(c(ext$nodes, ext$edges$from, ext$edges$to))
  structure(drm_dot_syntax(ext$edges, nodes), class = "drm_dot")
}

#' @export
print.drm_dot <- function(x, ...) {
  cat(unclass(x), "\n", sep = "")
  invisible(x)
}
