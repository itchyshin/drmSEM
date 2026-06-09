#' Build an evolutionary phylogenetic covariance / relatedness matrix
#'
#' `drm_phylo_cov()` turns a phylogenetic tree plus an evolutionary model into
#' the precomputed relationship matrix that a drmTMB node consumes through the
#' structured-effect marker `relmat(1 | species, K = <matrix>)`. drmSEM already
#' recognises `relmat()` as a marker (it is stripped from the causal edge set),
#' so the returned matrix enters each node's
#' likelihood as a phylogenetic random effect while `paths()`, `dsep()`,
#' `fisher_c()`, and the effect calculus continue to operate on the
#' fixed-effect DAG.
#'
#' This is Phase 3 of the phylogenetic roadmap (see
#' `vignette` material / `docs/design/06-phylogenetic-sem.md`): construct or
#' transform the phylogenetic covariance under a fixed evolutionary model
#' (Brownian motion or one of Pagel's lambda / kappa or an Ornstein-Uhlenbeck
#' decay) *before* it reaches the structured-effect layer. Joint estimation of
#' the evolutionary parameter is a larger engine problem that belongs upstream
#' in drmTMB.
#'
#' @section Evolutionary models:
#' All four models start from the Brownian-motion covariance `C = ape::vcv(tree)`
#' (square, symmetric, with tip labels as dimnames). For an ultrametric tree
#' `diag(C)` is the constant root-to-tip height `T` and the off-diagonals are the
#' shared (ancestral) path lengths.
#'
#' * **BM** -- Brownian motion. `C` is returned unchanged (the trait variance
#'   accumulates linearly with time; covariance is shared ancestry).
#' * **lambda** -- Pagel's lambda multiplies the off-diagonal covariances by
#'   `lambda` while preserving the diagonal: `lambda = 1` recovers BM and
#'   `lambda = 0` collapses to a star phylogeny (diagonal matrix, no shared
#'   signal). Requires `0 <= lambda <= 1`.
#' * **OU** -- an Ornstein-Uhlenbeck process under the Martins & Hansen (1997)
#'   exponential-decay correlation. Phylogenetic *correlation* between two tips
#'   decays with their patristic distance `d` as `exp(-alpha * d)`. This always
#'   returns a correlation matrix (unit diagonal) regardless of `standardize`.
#'   `alpha -> 0` is the strong-inertia singular limit (an all-ones matrix);
#'   large `alpha` approaches the identity (independence). Requires `alpha >= 0`.
#' * **kappa** -- Pagel's kappa raises each branch length to the power `kappa`
#'   before computing the covariance, so it genuinely needs the tree's branch
#'   lengths (it is not a pure transform of `C`). `kappa = 1` recovers BM.
#'   Requires `kappa >= 0`.
#'
#' @section Standardisation:
#' With `standardize = TRUE` (the default) the final covariance is converted to
#' a correlation matrix via `D^{-1/2} C D^{-1/2}` (unit diagonal). A
#' correlation-style relatedness matrix is the natural input to `relmat()`,
#' which expects a relationship rather than a raw covariance. For the OU model
#' the result is already a correlation matrix, so `standardize` is a no-op there.
#'
#' @param tree An `ape` "phylo" object. For drmTMB phylo modelling this should
#'   be **ultrametric** (rescale a raw `ape::rtree()` with
#'   `ape::compute.brlen(tree, "Grafen")`), and every `species` factor level fed
#'   to `relmat()` must be a tip label.
#' @param model Evolutionary model: one of `"BM"`, `"lambda"`, `"OU"`,
#'   `"kappa"`.
#' @param lambda Pagel's lambda in `[0, 1]` (used when `model = "lambda"`).
#' @param alpha OU decay rate, `>= 0` (used when `model = "OU"`).
#' @param kappa Pagel's kappa, `>= 0` (used when `model = "kappa"`).
#' @param standardize Logical; convert the result to a correlation matrix
#'   (unit diagonal). Defaults to `TRUE`.
#'
#' @return A square, symmetric matrix with the tree's tip labels as dimnames,
#'   suitable as the `K =` argument of `relmat()`.
#'
#' @references
#' \insertRef{Felsenstein1985}{drmSEM}
#'
#' \insertRef{MartinsHansen1997}{drmSEM}
#'
#' \insertRef{Pagel1999}{drmSEM}
#'
#' \insertRef{vanderBijl2018}{drmSEM}
#'
#' @export
#'
#' @examples
#' if (requireNamespace("ape", quietly = TRUE)) {
#'   # an ultrametric tree on 8 tips
#'   tree <- ape::compute.brlen(ape::rtree(8), "Grafen")
#'
#'   # Pagel's lambda relatedness matrix (off-diagonals shrunk toward a star)
#'   K <- drm_phylo_cov(tree, "lambda", lambda = 0.6)
#'
#'   # an OU correlation matrix
#'   K_ou <- drm_phylo_cov(tree, "OU", alpha = 2)
#'
#'   # feed K to a drmTMB node via the relmat() marker (species == tip labels):
#'   \dontrun{
#'   if (requireNamespace("drmTMB", quietly = TRUE)) {
#'     drmTMB::bf(y ~ x + relmat(1 | species, K = K))
#'   }
#'   }
#' }
drm_phylo_cov <- function(
  tree,
  model = c("BM", "lambda", "OU", "kappa"),
  lambda = 1,
  alpha = 1,
  kappa = 1,
  standardize = TRUE
) {
  model <- match.arg(model)

  # `tree` must be a genuine ape phylo object. Validate the class first so a
  # plainly wrong input fails with a clear message (this check does not need
  # ape itself -- `inherits()` only reads the class attribute).
  if (!inherits(tree, "phylo")) {
    cli::cli_abort(c(
      "{.arg tree} must be an {.pkg ape} {.cls phylo} object.",
      "x" = "You supplied an object of class {.cls {class(tree)}}.",
      "i" = "Build one with {.fn ape::rtree} and rescale to ultrametric via {.fn ape::compute.brlen}."
    ))
  }

  # ape supplies the base BM covariance (and, for kappa, the branch-length
  # transform). It is a Suggests dependency, so guard it explicitly.
  if (!requireNamespace("ape", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.fn drm_phylo_cov} needs the {.pkg ape} package to read the tree.",
      "i" = "Install it with {.code install.packages(\"ape\")}."
    ))
  }

  if (identical(model, "kappa")) {
    # Pagel's kappa stretches/compresses individual branches, so it must act on
    # the branch lengths BEFORE the covariance is formed -- it cannot be a pure
    # transform of C. kappa = 1 leaves the tree (hence BM) unchanged.
    if (
      !is.numeric(kappa) || length(kappa) != 1L || is.na(kappa) || kappa < 0
    ) {
      cli::cli_abort("{.arg kappa} must be a single number {.code >= 0}.")
    }
    tree2 <- tree
    tree2$edge.length <- tree2$edge.length^kappa
    C <- ape::vcv(tree2)
  } else {
    # BM / lambda / OU all start from the plain BM covariance; the lambda and OU
    # transforms below are pure matrix algebra (see the internal helpers), which
    # keeps their maths unit-testable without ape.
    C <- ape::vcv(tree)
    C <- switch(
      model,
      BM = C,
      lambda = phylo_transform_lambda(C, lambda),
      OU = phylo_transform_ou(C, alpha)
    )
  }

  # OU already returns a correlation matrix (unit diagonal); standardising it is
  # a near-identity no-op. For BM / lambda / kappa, convert the covariance to a
  # relatedness-style correlation matrix when requested -- the natural input to
  # relmat().
  if (standardize) {
    C <- phylo_to_corr(C)
  }

  C
}

# ---------------------------------------------------------------------------
# Internal evolutionary-covariance transforms (pure base R; no ape dependency).
# Each takes a base covariance matrix `C` so the matrix algebra can be unit
# tested with a hand-built covariance, independent of any tree object.
# ---------------------------------------------------------------------------

# Pagel's lambda on the COVARIANCE scale: scale the off-diagonal (shared
# ancestry) by lambda while leaving the diagonal (tip variances) untouched.
#   lambda = 1 -> C unchanged (BM)
#   lambda = 0 -> diagonal matrix (star phylogeny: no phylogenetic signal)
phylo_transform_lambda <- function(C, lambda) {
  if (
    !is.numeric(lambda) ||
      length(lambda) != 1L ||
      is.na(lambda) ||
      lambda < 0 ||
      lambda > 1
  ) {
    cli::cli_abort("{.arg lambda} must be a single number in {.code [0, 1]}.")
  }
  C_l <- lambda * C
  diag(C_l) <- diag(C)
  dimnames(C_l) <- dimnames(C)
  C_l
}

# Ornstein-Uhlenbeck (Martins & Hansen 1997) exponential-decay CORRELATION.
# The phylogenetic correlation between tips i and j decays with their patristic
# distance D[i, j] = C[i, i] + C[j, j] - 2 * C[i, j] as exp(-alpha * D).
#   alpha -> 0    -> all-ones matrix (the strong-inertia singular limit)
#   alpha large   -> identity (independence; off-diagonals vanish)
# The diagonal is always 1 (patristic self-distance is 0), so the result is a
# correlation matrix regardless of `standardize`.
phylo_transform_ou <- function(C, alpha) {
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha) || alpha < 0) {
    cli::cli_abort("{.arg alpha} must be a single number {.code >= 0}.")
  }
  d <- diag(C)
  D <- outer(d, d, "+") - 2 * C
  R_ou <- exp(-alpha * D)
  dimnames(R_ou) <- dimnames(C)
  R_ou
}

# Convert a covariance matrix to a correlation matrix: D^{-1/2} C D^{-1/2},
# giving a unit diagonal. Dimnames (tip labels) are preserved so drmTMB can
# align the matrix to the `species` factor levels.
phylo_to_corr <- function(C) {
  d <- 1 / sqrt(diag(C))
  R <- C * outer(d, d)
  dimnames(R) <- dimnames(C)
  R
}
