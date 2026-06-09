# Bridge tests for the drmSEM -> symbolizer integration. Both packages are
# Suggests, so every test is gated on installation; the engine-free smoke check
# does not need drmTMB.

test_that("symbolize.drm_sem errors when symbolizer is not installed", {
  skip_if(requireNamespace("symbolizer", quietly = TRUE))
  fake <- structure(list(records = list(), order = character(0), edges = NULL),
                    class = "drm_sem")
  expect_error(symbolize.drm_sem(fake), "symbolizer")
})

test_that("symbolize.drm_sem dispatches per node and returns a typed object", {
  skip_if_not_installed("symbolizer")
  skip_if_not_installed("drmTMB")

  dat <- simulate_drmsem_dgp(n = 300, seed = 13)
  sem <- drm_sem(
    size = drm_node(
      drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
      family = stats::gaussian()
    ),
    abundance = drm_node(
      drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
      family = drmTMB::nbinom2()
    ),
    data = dat
  )

  sym <- symbolizer::symbolize(sem)
  expect_s3_class(sym, "symbolized_drm_sem")
  expect_s3_class(sym, "symbolized_model_set")
  expect_setequal(names(sym$parts), c("size", "abundance"))
  expect_equal(sym$order, c("size", "abundance"))
  for (p in sym$parts) expect_s3_class(p, "symbolized_model")
})

test_that("renderers collate per-node output", {
  skip_if_not_installed("symbolizer")
  skip_if_not_installed("drmTMB")

  dat <- simulate_drmsem_dgp(n = 300, seed = 17)
  sem <- drm_sem(
    size = drm_node(
      drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
      family = stats::gaussian()
    ),
    abundance = drm_node(
      drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
      family = drmTMB::nbinom2()
    ),
    data = dat
  )
  sym <- symbolizer::symbolize(sem)

  tex <- symbolizer::as_latex(sym)
  expect_type(tex, "character")
  # Each node should appear as a labelled block in the collated output.
  expect_match(tex, "Node: size",      fixed = TRUE)
  expect_match(tex, "Node: abundance", fixed = TRUE)

  eq <- symbolizer::equations(sym)
  expect_s3_class(eq, "data.frame")
  expect_true("node" %in% names(eq))
  expect_setequal(unique(eq$node), c("size", "abundance"))

  at <- symbolizer::assumption_table(sym)
  expect_s3_class(at, "data.frame")
  expect_true("node" %in% names(at))
  expect_setequal(unique(at$node), c("size", "abundance"))
})
