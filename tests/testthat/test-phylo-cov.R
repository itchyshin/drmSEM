# Phase-3 evolutionary-covariance tests for drm_phylo_cov() and its internal
# pure-matrix transforms (lambda / OU / kappa / standardisation).
#
# Claim under test (docs/design/06-phylogenetic-sem.md Phase 3, AGENTS.md design
# rule 1): drmSEM can build the phylogenetic relatedness matrix that a drmTMB
# node consumes via relmat(1 | species, K = <matrix>), under a fixed evolutionary
# model. The covariance-transform matrix algebra is PURE BASE R and is verified
# here against a hand-built, known Brownian-motion covariance -- no ape, no
# drmTMB needed. The ape-only (kappa, vcv) and drmTMB-only (node fit) paths are
# gated and run in the engine-equipped CI env.

# ---------------------------------------------------------------------------
# A hand-built ULTRAMETRIC Brownian-motion covariance on 3 tips. Topology:
# ((t1, t2), t3) with total root-to-tip height T = 3. t1 and t2 share an
# ancestor at height 2 from the root (so their shared path length is 2); t3
# splits at the root, sharing path length 1 with both t1 and t2 (the root edge).
# diag = T = 3; off-diagonals are the shared path lengths. Symmetric and PSD.
known_bm_cov <- function() {
  C <- matrix(
    c(
      3,
      2,
      1,
      2,
      3,
      1,
      1,
      1,
      3
    ),
    nrow = 3,
    byrow = TRUE
  )
  dimnames(C) <- list(c("t1", "t2", "t3"), c("t1", "t2", "t3"))
  C
}

# --- Pagel's lambda --------------------------------------------------------

test_that("lambda = 1 is the identity transform (recovers BM)", {
  C <- known_bm_cov()
  out <- drmSEM:::phylo_transform_lambda(C, 1)
  expect_equal(out, C)
})

test_that("lambda = 0 yields the star phylogeny (diagonal of C)", {
  C <- known_bm_cov()
  out <- drmSEM:::phylo_transform_lambda(C, 0)
  expect_equal(out, diag(diag(C)), ignore_attr = TRUE)
  # off-diagonals must all be zero
  expect_true(all(out[upper.tri(out)] == 0))
  expect_true(all(out[lower.tri(out)] == 0))
  # diagonal (tip variances) is preserved
  expect_equal(diag(out), diag(C))
})

test_that("0 < lambda < 1 scales off-diagonals by exactly lambda and keeps diag", {
  C <- known_bm_cov()
  lam <- 0.6
  out <- drmSEM:::phylo_transform_lambda(C, lam)
  # diagonal unchanged
  expect_equal(diag(out), diag(C))
  # each off-diagonal scaled by exactly lambda
  off <- upper.tri(C)
  expect_equal(out[off], lam * C[off])
  # symmetric, dimnames preserved
  expect_true(isSymmetric(out))
  expect_equal(dimnames(out), dimnames(C))
})

test_that("lambda outside [0, 1] aborts", {
  C <- known_bm_cov()
  expect_error(drmSEM:::phylo_transform_lambda(C, -0.1))
  expect_error(drmSEM:::phylo_transform_lambda(C, 1.5))
  expect_error(drmSEM:::phylo_transform_lambda(C, NA_real_))
  expect_error(drmSEM:::phylo_transform_lambda(C, c(0.2, 0.3)))
})

# --- Ornstein-Uhlenbeck ----------------------------------------------------

test_that("OU returns a symmetric correlation matrix with entries in (0, 1]", {
  C <- known_bm_cov()
  out <- drmSEM:::phylo_transform_ou(C, 1)
  expect_true(isSymmetric(out))
  expect_equal(diag(out), rep(1, nrow(C)), ignore_attr = TRUE)
  expect_true(all(out > 0))
  expect_true(all(out <= 1))
  expect_equal(dimnames(out), dimnames(C))
})

test_that("larger OU alpha shrinks off-diagonals monotonically", {
  C <- known_bm_cov()
  a1 <- drmSEM:::phylo_transform_ou(C, 0.5)
  a2 <- drmSEM:::phylo_transform_ou(C, 2)
  off <- upper.tri(C)
  # every off-diagonal strictly smaller under the larger alpha
  expect_true(all(a2[off] < a1[off]))
})

test_that("OU alpha large -> identity; alpha -> 0 -> all-ones", {
  C <- known_bm_cov()
  big <- drmSEM:::phylo_transform_ou(C, 50)
  off <- upper.tri(C)
  expect_true(all(big[off] < 1e-6)) # approaches identity
  expect_equal(diag(big), rep(1, nrow(C)), ignore_attr = TRUE)

  tiny <- drmSEM:::phylo_transform_ou(C, 1e-8)
  expect_true(all(abs(tiny - 1) < 1e-6)) # approaches all-ones
})

test_that("OU result is positive semi-definite for a reasonable alpha", {
  C <- known_bm_cov()
  out <- drmSEM:::phylo_transform_ou(C, 1)
  ev <- eigen(out, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8)
})

test_that("OU alpha < 0 aborts", {
  C <- known_bm_cov()
  expect_error(drmSEM:::phylo_transform_ou(C, -1))
})

# --- standardisation -------------------------------------------------------

test_that("phylo_to_corr yields unit diagonal, symmetry, preserved dimnames", {
  C <- known_bm_cov()
  R <- drmSEM:::phylo_to_corr(C)
  expect_equal(diag(R), rep(1, nrow(C)), ignore_attr = TRUE)
  expect_true(isSymmetric(R))
  expect_equal(dimnames(R), dimnames(C))
  # off-diagonals are the BM covariances divided by sqrt(var_i * var_j)
  expect_equal(R["t1", "t2"], 2 / sqrt(3 * 3))
})

test_that("standardising an already-correlation matrix is a near-identity", {
  C <- known_bm_cov()
  R <- drmSEM:::phylo_to_corr(C) # a correlation matrix (unit diag)
  R2 <- drmSEM:::phylo_to_corr(R) # re-standardising it
  expect_equal(R2, R, tolerance = 1e-12)
})

# --- drm_phylo_cov() input validation --------------------------------------

test_that("drm_phylo_cov() aborts on a non-phylo object (before needing ape)", {
  # A plain matrix is not a phylo tree; the class check fires first, so this
  # path is exercised whether or not ape is installed.
  expect_error(drm_phylo_cov(matrix(1, 2, 2), "BM"))
  expect_error(drm_phylo_cov(list(a = 1), "lambda", lambda = 0.5))
})

test_that("drm_phylo_cov() gives a clear error when ape is unavailable", {
  # Only meaningful when ape is genuinely absent: a fake phylo object passes the
  # class check, then the ape guard must abort. When ape IS installed this path
  # cannot be reached with a fake tree (vcv would error first), so skip it.
  skip_if(
    requireNamespace("ape", quietly = TRUE),
    "ape is installed; the ape-missing guard is unreachable here"
  )
  fake <- structure(list(), class = "phylo")
  expect_error(drm_phylo_cov(fake, "BM"))
})

# --- ape-gated: full builder over a real tree ------------------------------

test_that("drm_phylo_cov() builds BM / lambda / OU / kappa over a real tree", {
  skip_if_not_installed("ape")
  set.seed(1)
  tree <- ape::compute.brlen(ape::rtree(6), "Grafen")
  tips <- tree$tip.label

  # BM, standardised -> correlation matrix with tip-label dimnames.
  K <- drm_phylo_cov(tree, "BM")
  expect_equal(dim(K), c(6L, 6L))
  expect_equal(rownames(K), tips)
  expect_equal(colnames(K), tips)
  expect_true(isSymmetric(K))
  expect_equal(diag(K), rep(1, 6), ignore_attr = TRUE) # standardised

  # BM without standardisation keeps the raw vcv (diag = root-to-tip height).
  K_raw <- drm_phylo_cov(tree, "BM", standardize = FALSE)
  expect_equal(K_raw, ape::vcv(tree))

  # lambda model runs and stays a valid correlation matrix.
  K_lam <- drm_phylo_cov(tree, "lambda", lambda = 0.6)
  expect_true(isSymmetric(K_lam))
  expect_equal(diag(K_lam), rep(1, 6), ignore_attr = TRUE)

  # OU is a correlation matrix regardless of standardize.
  K_ou <- drm_phylo_cov(tree, "OU", alpha = 2, standardize = FALSE)
  expect_equal(diag(K_ou), rep(1, 6), ignore_attr = TRUE)

  # kappa = 1 recovers BM (genuinely uses branch lengths via the ape path).
  K_kappa1 <- drm_phylo_cov(tree, "kappa", kappa = 1)
  expect_equal(K_kappa1, K, tolerance = 1e-10)
})

# --- drmTMB-gated: a node carrying relmat() over the phylo matrix -----------

test_that("a relmat() node built from drm_phylo_cov() forms a valid SEM", {
  skip_if_not_installed("ape")
  skip_if_not_installed("drmTMB")

  set.seed(1)
  # Ultrametric tree; species factor levels must equal tip labels.
  tree <- ape::compute.brlen(ape::rtree(10), "Grafen")
  species_levels <- tree$tip.label
  n_sp <- length(species_levels)
  K <- drm_phylo_cov(tree, "lambda", lambda = 0.7)

  # A Gaussian chain x -> y over species; a modest per-species offset so the
  # relmat() random effect has something to absorb. Keep amplitudes small so
  # the fit stays convergent.
  sp_re <- stats::rnorm(n_sp, sd = 0.4)
  names(sp_re) <- species_levels
  n <- 120
  species <- factor(
    sample(species_levels, n, replace = TRUE),
    levels = species_levels
  )
  sp <- as.character(species)
  x <- stats::rnorm(n)
  y <- 0.2 + 0.7 * x + sp_re[sp] + stats::rnorm(n, sd = 0.5)
  dat <- data.frame(x = x, y = as.numeric(y), species = species)

  sem <- suppressWarnings(
    drm_sem(
      y = drm_node(
        drmTMB::bf(y ~ x + relmat(1 | species, K = K)),
        family = stats::gaussian()
      ),
      data = dat
    )
  )
  expect_s3_class(sem, "drm_sem")

  # paths() must show the fixed-effect DAG only: the relmat marker is stripped,
  # so neither the grouping factor `species` nor the matrix arg `K` may appear
  # as a path source. Only x -> y survives.
  p <- paths(sem)
  expect_false(any(p$from %in% c("species", "K", "relmat")))
  fixed <- unique(p[, c("from", "to")])
  expect_true(any(fixed$from == "x" & fixed$to == "y"))
  expect_true(all(is.finite(p$estimate)))
})
