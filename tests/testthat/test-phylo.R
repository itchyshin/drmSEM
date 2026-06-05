# Phase-1 phylogenetic-mode integration test.
#
# Claim under test (docs/design/06-phylogenetic-sem.md, vignette
# "phylogenetic-sem.Rmd", AGENTS.md design rule 1): a SEM whose nodes carry a
# `phylo(1 | species, tree = phy)` random effect builds, and paths()/dsep()/
# effects all run over the FIXED-EFFECT DAG -- the phylo marker is stripped from
# the causal edge set but preserved inside each node's likelihood (and inside
# the d-separation augmented refit).
#
# This needs the drmTMB engine (compiles TMB/C++ from source) AND `ape` (for the
# tree). Both are unavailable on CRAN-style checks without a compiler/network;
# the test is skipped there and runs in the engine-equipped CI env. Assertions
# are deliberately structural/finiteness-based so small-sample noise cannot make
# a correctly-wired model fail.

skip_if_not_installed("drmTMB")
skip_if_not_installed("ape")

# A known phylogenetic DGP: a Gaussian chain x -> y1 -> y2 measured across
# species related by `phy`, with a per-species (phylogenetic) random intercept
# on each endogenous node. Returns the data plus the tree so the SEM can carry
# the exact `phylo(1 | species, tree = phy)` term the vignette documents.
simulate_phylo_chain <- function(n = 150, seed = 1) {
  set.seed(seed)
  # drmTMB's phylo() requires an ULTRAMETRIC tree (equal root-to-tip distances);
  # a raw ape::rtree() is not, so rescale branch lengths with Grafen's method.
  phy <- ape::compute.brlen(ape::rtree(12), method = "Grafen", power = 1)
  species_levels <- phy$tip.label    # factor levels == tip labels (must match)
  n_sp <- length(species_levels)

  # Species-level random intercepts. A proper phylogenetic effect would draw
  # these from a tree-derived covariance; for a fast, convergent fit we only
  # need a non-trivial per-species offset for the engine to soak up via the
  # phylo() term. Keep amplitudes modest so the fixed-effect chain dominates.
  sp_re_y1 <- stats::rnorm(n_sp, sd = 0.4)
  sp_re_y2 <- stats::rnorm(n_sp, sd = 0.4)
  names(sp_re_y1) <- species_levels
  names(sp_re_y2) <- species_levels

  species <- factor(sample(species_levels, n, replace = TRUE),
                    levels = species_levels)
  sp <- as.character(species)

  x  <- stats::rnorm(n)
  y1 <- 0.2 + 0.7 * x + sp_re_y1[sp] + stats::rnorm(n, sd = 0.5)
  y2 <- -0.1 + 0.6 * y1 + 0.3 * x + sp_re_y2[sp] + stats::rnorm(n, sd = 0.5)

  dat <- data.frame(
    x = x,
    y1 = as.numeric(y1),
    y2 = as.numeric(y2),
    species = species
  )
  list(data = dat, phy = phy)
}

# Build the phylogenetic SEM once and reuse it across assertions. The ONLY
# departure from a plain Gaussian chain is the phylo(1 | species, tree = phy)
# random intercept added to each node. A small phylo fit can warn (boundary
# variance, sdreport), so wrap the fit in suppressWarnings().
make_phylo_sem <- function() {
  sim <- simulate_phylo_chain(n = 150, seed = 1)
  dat <- sim$data
  phy <- sim$phy
  suppressWarnings(
    drm_sem(
      y1 = drm_node(
        drmTMB::bf(y1 ~ x + phylo(1 | species, tree = phy)),
        family = stats::gaussian()
      ),
      y2 = drm_node(
        drmTMB::bf(y2 ~ y1 + x + phylo(1 | species, tree = phy)),
        family = stats::gaussian()
      ),
      data = dat
    )
  )
}

test_that("a phylogenetic SEM builds as a valid DAG in topological order", {
  sem <- make_phylo_sem()
  expect_s3_class(sem, "drm_sem")
  # x -> y1 -> y2 forces y1 before y2; the phylo term does not perturb the order.
  expect_equal(sem$order, c("y1", "y2"))
})

test_that("paths() shows the fixed-effect DAG only; the phylo term is stripped", {
  sem <- make_phylo_sem()
  p <- paths(sem)
  expect_true(all(c("from", "to", "component", "estimate") %in% names(p)))

  # The structured-effect marker must NOT leak into the causal edge set: neither
  # the grouping factor `species` nor the tree argument `tree`/`phy` may appear
  # as a path source.
  expect_false(any(p$from %in% c("species", "tree")))
  expect_false(any(p$from %in% c("phy", "phylo")))

  # The genuine fixed-effect causal arrows ARE present (all into mu): x -> y1,
  # y1 -> y2, x -> y2. Compare on the (from, to) pairs to stay robust to extra
  # columns / coefficient-name encodings.
  fixed <- unique(p[, c("from", "to")])
  has_edge <- function(f, t) any(fixed$from == f & fixed$to == t)
  expect_true(has_edge("x", "y1"))
  expect_true(has_edge("y1", "y2"))
  expect_true(has_edge("x", "y2"))

  # Every fixed-effect estimate is finite (the fit converged, not NA-filled).
  expect_true(all(is.finite(p$estimate)))
})

test_that("dsep() runs over the phylo DAG and Fisher's C is finite", {
  sem <- make_phylo_sem()
  # The full make_phylo_sem() DAG (x->y1, x->y2, y1->y2) is saturated, so its
  # basis set is empty (dsep() warns and returns 0 rows; Fisher's C = 0). That
  # still exercises the machinery; the augmented-refit path is exercised below
  # by an UNSATURATED model.
  d <- suppressWarnings(dsep(sem))
  expect_s3_class(d, "data.frame")
  expect_true(all(c("x", "y") %in% names(d)))

  fc <- fisher_c(sem)
  expect_s3_class(fc, "data.frame")
  expect_true(is.finite(fc$fisher_c))
})

test_that("dsep() augmented refit preserves the phylo term on a real claim", {
  # Drop the true x -> y2 arrow so the basis set contains x _||_ y2 | {y1}.
  # Testing that claim forces dsep() to refit node y2 with `x` ADDED to a model
  # that still carries phylo(1 | species, tree = phy) -- the Phase-1 guarantee
  # that the augmented refit keeps the structured random effect. If the refit
  # dropped or choked on phylo(), the claim would come back status != "ok".
  sim <- simulate_phylo_chain(n = 150, seed = 1)
  dat <- sim$data
  phy <- sim$phy
  sem <- suppressWarnings(
    drm_sem(
      y1 = drm_node(
        drmTMB::bf(y1 ~ x + phylo(1 | species, tree = phy)),
        family = stats::gaussian()
      ),
      y2 = drm_node(
        drmTMB::bf(y2 ~ y1 + phylo(1 | species, tree = phy)),
        family = stats::gaussian()
      ),
      data = dat
    )
  )
  d <- suppressWarnings(dsep(sem))
  expect_s3_class(d, "data.frame")
  claim <- d[d$x == "x" & d$y == "y2", ]
  expect_equal(nrow(claim), 1L)
  # The refit must have succeeded (phylo preserved), producing a usable LRT.
  expect_identical(claim$status, "ok")
  expect_true(is.finite(claim$p.value))

  fc <- fisher_c(sem)
  expect_true(is.finite(fc$fisher_c))
})

test_that("total_effects() propagates through a phylogenetic node", {
  sem <- make_phylo_sem()
  te <- total_effects(sem, from = "x", to = "y2", B = 50, n_sim = 20)
  expect_s3_class(te, "drm_effect")
  expect_true(is.finite(te$estimate))
})
