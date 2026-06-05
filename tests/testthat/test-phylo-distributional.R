# Phase-1 headline test: a PHYLOGENETIC node with a DISTRIBUTIONAL path.
#
# Claim under test (docs/design/06-phylogenetic-sem.md "temp -> sigma(size) with
# sigma ~ temp + phylo(1|species)", vignette "phylogenetic-sem.Rmd", AGENTS.md
# design rule 1): drmSEM's novel contribution is that a mediator carrying a
# phylogenetic random effect can ALSO route a causal path through its
# distributional scale (sigma), and that path contributes a non-zero
# DISTRIBUTION-MEDIATED indirect effect under shared ancestry -- something a
# mean-only mediation calculus (and a non-distributional SEM) cannot represent.
#
# DGP: chain  x -> m -> y  measured across 12 species related by an ultrametric
# tree `phy`. The mediator m is Gaussian with BOTH
#     mu    ~ x + phylo(1 | species, tree = phy)     (mean path, phylo-structured)
#     sigma ~ x                                       (DISTRIBUTIONAL path)
# so x widens/narrows m's residual scale on top of shifting its mean. y depends
# on m through a convex (log/exp) response so that changes in m's *spread*, not
# only its mean, move E[y] -- the signature of a distribution-mediated effect.
#
# Requires the drmTMB engine (compiles TMB/C++) AND `ape` (the tree); both are
# unavailable on CRAN-style checks without a compiler/network, so the test is
# skipped there and runs in the engine-equipped CI env. Assertions are
# structural / finiteness-based so small-sample sampler noise cannot make a
# correctly-wired model fail; the distribution-mediated quantity is required to
# be finite (its magnitude is reported but not pinned to a tolerance).

skip_if_not_installed("drmTMB")
skip_if_not_installed("ape")

# Known distributional-phylo DGP. Returns the data and the tree so the SEM can
# carry the exact `phylo(1 | species, tree = phy)` term plus the `sigma ~ x`
# distributional sub-formula.
simulate_phylo_distributional <- function(n = 150, seed = 1) {
  set.seed(seed)
  # drmTMB's phylo() requires an ULTRAMETRIC tree (equal root-to-tip distances);
  # a raw ape::rtree() is not, so rescale branch lengths with Grafen's method.
  phy <- ape::compute.brlen(ape::rtree(12), method = "Grafen", power = 1)
  species_levels <- phy$tip.label    # factor levels == tip labels (must match)
  n_sp <- length(species_levels)

  # Per-species (phylogenetic) random intercept on the mediator's mean. Modest
  # amplitude so the fixed-effect chain dominates and the fit stays convergent.
  sp_re_m <- stats::rnorm(n_sp, sd = 0.4)
  names(sp_re_m) <- species_levels

  species <- factor(sample(species_levels, n, replace = TRUE),
                    levels = species_levels)
  sp <- as.character(species)

  x <- stats::rnorm(n)

  # Mediator m: mean shifts with x AND with the phylogenetic offset; the
  # residual SCALE also grows with x (the distributional path). log-sigma is
  # linear in x, so sigma = exp(-0.3 + 0.8 * x): a genuine x -> sigma(m) edge.
  mu_m    <- 0.2 + 0.7 * x + sp_re_m[sp]
  sigma_m <- exp(-0.3 + 0.8 * x)
  m <- mu_m + stats::rnorm(n, sd = sigma_m)

  # Outcome y depends on m through a convex (exp) response. Because E[exp(m)]
  # depends on Var(m) as well as E[m] (log-normal mean = exp(mu + sigma^2/2)),
  # the x -> sigma(m) path leaves a footprint in E[y]: a distribution-mediated
  # effect that a mean-only propagation would miss. Keep y a positive Gaussian
  # response of the exponentiated mediator so the fit is simple and convergent.
  y <- exp(0.5 * m) + stats::rnorm(n, sd = 0.3)

  dat <- data.frame(
    x = x,
    m = as.numeric(m),
    y = as.numeric(y),
    species = species
  )
  list(data = dat, phy = phy)
}

# Build the phylo + distributional SEM once and reuse it across assertions. A
# small phylo / distributional fit can warn (boundary variance, sdreport), so
# wrap the build in suppressWarnings().
make_phylo_dist_sem <- function() {
  sim <- simulate_phylo_distributional(n = 150, seed = 1)
  dat <- sim$data
  phy <- sim$phy
  suppressWarnings(
    drm_sem(
      m = drm_node(
        # mu carries the phylogenetic random intercept; sigma carries the
        # distributional path x -> sigma(m).
        drmTMB::bf(m ~ x + phylo(1 | species, tree = phy), sigma ~ x),
        family = stats::gaussian()
      ),
      y = drm_node(
        drmTMB::bf(y ~ m),
        family = stats::gaussian()
      ),
      data = dat
    )
  )
}

test_that("a phylo + distributional SEM builds as a valid DAG", {
  sem <- make_phylo_dist_sem()
  expect_s3_class(sem, "drm_sem")
  # x -> m -> y forces m before y; neither the phylo term nor the sigma
  # sub-formula perturbs the topological order.
  expect_equal(sem$order, c("m", "y"))
})

test_that("paths() exposes the x -> sigma(m) distributional edge and hides phylo", {
  sem <- make_phylo_dist_sem()
  p <- paths(sem)
  expect_true(all(c("from", "to", "component", "estimate") %in% names(p)))

  # The DISTRIBUTIONAL path is the headline: an edge from `x` into node `m`
  # labelled on the `sigma` component (residual scale), distinct from the mean
  # path x -> mu(m).
  sigma_edge <- p[p$from == "x" & p$to == "m" & p$component == "sigma", ,
                  drop = FALSE]
  expect_true(nrow(sigma_edge) >= 1L)
  expect_true(all(is.finite(sigma_edge$estimate)))

  # The mean path x -> mu(m) and the downstream m -> y arrow are also present.
  fixed <- unique(p[, c("from", "to", "component")])
  has_edge <- function(f, t, comp) {
    any(fixed$from == f & fixed$to == t & fixed$component == comp)
  }
  expect_true(has_edge("x", "m", "mu"))
  expect_true(has_edge("m", "y", "mu"))

  # The phylo marker must NOT leak into the causal edge set: neither the
  # grouping factor `species` nor the tree argument may appear as a path source.
  expect_false(any(p$from %in% c("species", "tree", "phy", "phylo")))

  # Every fixed-effect estimate is finite (the fit converged, not NA-filled).
  expect_true(all(is.finite(p$estimate)))
})

test_that("indirect_effects() returns a finite distribution-mediated effect", {
  sem <- make_phylo_dist_sem()
  eff <- indirect_effects(sem, from = "x", to = "y", B = 40, n_sim = 20)
  expect_s3_class(eff, "drm_effect")

  # The five decomposition quantities are all present...
  expect_true(all(c("total_path", "direct", "indirect",
                    "mean_mediated", "distribution_mediated") %in% eff$quantity))

  # ...and every point estimate is finite (no NA/Inf from the propagation).
  expect_true(all(is.finite(eff$estimate)))

  # The headline quantity: under x -> sigma(m) with the convex m -> y response,
  # the distribution-mediated effect exists and is finite. Magnitude is reported
  # for the ledger but not pinned to a tolerance (small-sample sampler noise).
  dm <- eff$estimate[eff$quantity == "distribution_mediated"]
  expect_length(dm, 1L)
  expect_true(is.finite(dm))
})
