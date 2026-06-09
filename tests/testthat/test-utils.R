# Pure-logic tests: run anywhere (no drmTMB required).

test_that("fixed-effect predictor extraction drops bars and markers", {
  rhs <- function(f) f[[2L]]
  expect_setequal(
    drm_fixed_predictors(rhs(~ temp + habitat + (1 | site))),
    c("temp", "habitat")
  )
  expect_setequal(
    drm_fixed_predictors(rhs(
      ~ size + temp + mi(x) + phylo(1 | species) + (1 | site)
    )),
    c("size", "temp", "x")
  )
  expect_length(drm_fixed_predictors(rhs(~1)), 0L)
  expect_length(drm_fixed_predictors(NULL), 0L)
})

test_that("topological sort orders a DAG and flags cycles", {
  e <- data.frame(
    from = c("x", "size", "temp", "size"),
    to = c("size", "abund", "abund", "fit")
  )
  ts <- drm_toposort(c("size", "abund", "fit"), e)
  expect_true(ts$acyclic)
  expect_lt(which(ts$order == "size"), which(ts$order == "abund"))

  ec <- data.frame(from = c("a", "b"), to = c("b", "a"))
  expect_false(drm_toposort(c("a", "b"), ec)$acyclic)
})

test_that("ancestors and simple paths are correct", {
  e <- data.frame(
    from = c("x", "size", "temp", "size"),
    to = c("size", "abund", "abund", "fit")
  )
  expect_setequal(drm_ancestors("abund", e), c("size", "temp", "x"))
  sp <- drm_simple_paths("x", "abund", e)
  expect_true(any(vapply(
    sp,
    function(p) identical(p, c("x", "size", "abund")),
    logical(1)
  )))
})

test_that("coefficient names map back to predictor variables", {
  expect_equal(drm_coef_variable("habitatB", c("temp", "habitat")), "habitat")
  expect_equal(drm_coef_variable("temp", c("temp", "habitat")), "temp")
  expect_equal(drm_coef_variable("unmatched", c("temp")), "unmatched")
})

# Structured-effect markers (phylo/animal/spatial/relmat) with named args like
# tree=/pedigree=/coords= must be stripped from the causal predictor set, never
# leaking the grouping or auxiliary objects as predictors (phylo Phase 1).
test_that("structured-effect markers do not leak species/tree as predictors", {
  rhs <- (~ x + habitat + phylo(1 | species, tree = tree))[[2L]]
  expect_setequal(drm_fixed_predictors(rhs), c("x", "habitat"))
  expect_false("species" %in% drm_fixed_predictors(rhs))
  expect_false("tree" %in% drm_fixed_predictors(rhs))

  rhs2 <- (~ z +
    animal(1 | id, pedigree = ped) +
    spatial(1 | site, coords = xy))[[2L]]
  expect_setequal(drm_fixed_predictors(rhs2), "z")
})
