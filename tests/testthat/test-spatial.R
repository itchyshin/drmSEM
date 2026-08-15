# Spatially-structured nodes via relmat(K = <any matrix>).
#
# Why this file exists separately from test-phylo-cov.R. The relmat() slot was
# already exercised there ("a relmat() node built from drm_phylo_cov() forms a valid
# SEM"), so the mechanism had retained evidence — but only under a PHYLOGENETIC
# label. Anyone asking "does drmSEM support spatial structure?" would grep for
# spatial, find only drmTMB's `spatial()` marker, and conclude no. The capability was
# real and unfindable, which is its own kind of missing evidence.
#
# The substantive point, verified against drmTMB 0.6.0: `relmat(K = )` accepts ANY
# positive-definite matrix, so it is strictly MORE flexible for spatial work than
# drmTMB's own `spatial()` marker, whose only implemented kernel is a fixed
# exponential with a heuristic (non-estimated) range and whose `mesh=` argument
# aborts as unimplemented. Documenting the weaker route as the spatial one would
# mislead.
#
# V-93  a distance-kernel relmat() node forms a valid SEM and strips its markers
# V-94  d-separation and effects run over a spatially-structured node

skip_if_not_installed("drmTMB")

# Exponential spatial kernel over a small site grid. Any PSD matrix works; this one
# is the standard exp(-d/range) an ecologist would reach for.
spatial_fixture <- function(n = 240, n_site = 12, range = 0.3, seed = 404) {
  set.seed(seed)
  xy <- cbind(stats::runif(n_site), stats::runif(n_site))
  rownames(xy) <- paste0("s", seq_len(n_site))
  D <- as.matrix(stats::dist(xy))
  K <- exp(-D / range)
  diag(K) <- 1
  site <- factor(sample(rownames(xy), n, replace = TRUE), levels = rownames(xy))
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.7 * m + stats::rnorm(n)
  list(K = K, dat = data.frame(x = x, m = m, y = y, site = site))
}

test_that("V-93: a distance-kernel relmat() node forms a valid SEM, markers stripped", {
  f <- spatial_fixture()
  K <- f$K
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m + relmat(1 | site, K = K)),
                 family = stats::gaussian()),
    data = f$dat
  )
  expect_s3_class(sem, "drm_sem")
  p <- as.data.frame(paths(sem))
  # The structural DAG is x -> m -> y. `site`, `K` and `relmat` are model structure,
  # not causes, and must never surface as edges.
  expect_setequal(p$from, c("x", "m"))
  expect_false(any(grepl("site|relmat|^K$", p$from)))
  expect_false(any(grepl("site|relmat|^K$", p$term)))
  expect_true(all(is.finite(p$estimate)))
})

test_that("V-94: d-separation and effects run over a spatially-structured node", {
  f <- spatial_fixture()
  K <- f$K
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m + relmat(1 | site, K = K)),
                 family = stats::gaussian()),
    data = f$dat
  )
  # The augmented refit must resolve `K` from the environment the SEM was built in,
  # which is the OQ-13 fix; a spatial node exercises the same path a phylo node does.
  ds <- as.data.frame(dsep(sem))
  claim <- ds[ds$x == "x" & ds$y == "y", , drop = FALSE]
  expect_identical(nrow(claim), 1L)
  expect_identical(claim$status, "ok")
  expect_true(is.finite(claim$p.value))
  expect_true(is.finite(fisher_c(sem)$fisher_c))

  ie <- suppressWarnings(
    indirect_effects(sem, from = "x", to = "y", uncertainty = "none", nsim = 300)
  )
  q <- stats::setNames(ie$estimate, ie$quantity)
  expect_true(all(is.finite(q)))
  expect_equal(q[["total_path"]], q[["direct"]] + q[["indirect"]], tolerance = 1e-8)
})
