# 0.3 — composite constructs. Construction, scoring, validation, materialization,
# and the loadings() accessor are pure-R (no drmTMB), tested here.

dat3 <- data.frame(
  i1 = c(1, 2, 3, 4, 5, 6),
  i2 = c(2, 1, 4, 3, 6, 5),
  i3 = c(0, 1, 0, 1, 0, 1),
  y  = rnorm(6)
)

# ---- drm_composite(): construction -----------------------------------------

test_that("drm_composite('fixed') records equal or explicit weights", {
  eq <- drm_composite("C", c("i1", "i2", "i3"), method = "fixed", data = dat3)
  expect_s3_class(eq, "drm_composite")
  expect_identical(eq$method, "fixed")
  expect_equal(unname(eq$loadings), rep(1 / 3, 3))
  expect_false(eq$scale)
  expect_true(is.na(eq$prop_var))

  wt <- drm_composite("C", c("i1", "i2"), weights = c(1, 2), method = "fixed", data = dat3)
  expect_equal(unname(wt$loadings), c(1, 2))
  expect_identical(names(wt$loadings), c("i1", "i2"))
})

test_that("drm_composite('pca') returns sign-fixed PC1 loadings and prop_var", {
  # two perfectly (positively) correlated indicators -> PC1 explains all variance,
  # equal loadings ~ 1/sqrt(2), made positive by the sign convention.
  d <- data.frame(a = 1:10, b = 2 * (1:10))
  pc <- drm_composite("C", c("a", "b"), method = "pca", data = d)
  expect_true(pc$scale)
  expect_equal(unname(pc$loadings), rep(1 / sqrt(2), 2), tolerance = 1e-6)
  expect_equal(pc$prop_var, 1, tolerance = 1e-6)
})

test_that("drm_composite() rejects malformed declarations", {
  expect_error(drm_composite("C", "i1", data = dat3), "at least two")
  expect_error(drm_composite("C", c("i1", "ghost"), data = dat3), "not found")
  dat_chr <- data.frame(i1 = 1:3, s = letters[1:3], stringsAsFactors = FALSE)
  expect_error(drm_composite("C", c("i1", "s"), data = dat_chr), "numeric")
  expect_error(
    drm_composite("C", c("i1", "i2"), weights = 1, method = "fixed", data = dat3),
    "one value per indicator"
  )
  expect_error(drm_composite(c("C", "D"), c("i1", "i2"), data = dat3), "single non-empty")
  expect_error(drm_composite("C", c("i1", "i2")), "is required")
})

# ---- drm_score_composite(): the materialized column -------------------------

test_that("drm_score_composite computes the construct column", {
  eq <- drm_composite("C", c("i1", "i2", "i3"), method = "fixed", data = dat3)
  s <- drmSEM:::drm_score_composite(eq, dat3)
  expect_equal(s, (dat3$i1 + dat3$i2 + dat3$i3) / 3)

  wt <- drm_composite("C", c("i1", "i2"), weights = c(1, 2), method = "fixed", data = dat3)
  expect_equal(drmSEM:::drm_score_composite(wt, dat3), dat3$i1 + 2 * dat3$i2)

  d <- data.frame(a = 1:10, b = 2 * (1:10))
  pc <- drm_composite("C", c("a", "b"), method = "pca", data = d)
  sc <- drmSEM:::drm_score_composite(pc, d)
  # scaled, equal-loading combination -> proportional to the scaled indicator
  expect_equal(sc, as.numeric(scale(d$a) * sqrt(2)), tolerance = 1e-6)
})

# ---- drm_build_composites() / drm_apply_composites() ------------------------

test_that("drm_build_composites normalizes and rejects duplicate names", {
  expect_identical(length(drmSEM:::drm_build_composites(NULL)), 0L)
  one <- drm_composite("C", c("i1", "i2"), data = dat3)
  expect_identical(length(drmSEM:::drm_build_composites(one)), 1L)
  expect_error(
    drmSEM:::drm_build_composites(list(one, one)),
    "unique"
  )
  expect_error(drmSEM:::drm_build_composites(list(1, 2)), "drm_composite")
})

test_that("drm_apply_composites materializes columns and guards collisions", {
  spec <- drm_composite("C", c("i1", "i2", "i3"), method = "fixed", data = dat3)
  aug <- drmSEM:::drm_apply_composites(dat3, spec)
  expect_true("C" %in% names(aug))
  expect_equal(aug$C, (dat3$i1 + dat3$i2 + dat3$i3) / 3)
  # NULL is a no-op
  expect_identical(drmSEM:::drm_apply_composites(dat3, NULL), dat3)
  # a construct name that already exists in data is an error
  clash <- drm_composite("i1", c("i2", "i3"), data = dat3)
  expect_error(drmSEM:::drm_apply_composites(dat3, clash), "collides")
})

# ---- loadings() accessor ----------------------------------------------------

test_that("loadings() reports indicator loadings, empty when there are none", {
  c1 <- drm_composite("C1", c("i1", "i2"), method = "fixed", data = dat3)
  c2 <- drm_composite("C2", c("i1", "i3"), weights = c(2, 1), method = "fixed", data = dat3)
  obj <- structure(list(composites = list(c1, c2)), class = "drm_sem")
  lt <- loadings(obj)
  expect_s3_class(lt, "drm_loadings")
  expect_identical(sort(unique(lt$composite)), c("C1", "C2"))
  expect_identical(nrow(lt), 4L)
  expect_equal(lt$loading[lt$composite == "C2" & lt$indicator == "i1"], 2)

  expect_identical(nrow(loadings(structure(list(), class = "drm_sem"))), 0L)
})
