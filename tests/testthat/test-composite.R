# 0.3 — composite constructs. Construction, scoring, validation, materialization,
# and the loadings() accessor are pure-R (no drmTMB), tested here.

dat3 <- data.frame(
  i1 = c(1, 2, 3, 4, 5, 6),
  i2 = c(2, 1, 4, 3, 6, 5),
  i3 = c(0, 1, 0, 1, 0, 1),
  y = rnorm(6)
)

# ---- drm_composite(): construction -----------------------------------------

test_that("drm_composite('fixed') records equal or explicit weights", {
  eq <- drm_composite("C", c("i1", "i2", "i3"), method = "fixed", data = dat3)
  expect_s3_class(eq, "drm_composite")
  expect_identical(eq$method, "fixed")
  expect_equal(unname(eq$loadings), rep(1 / 3, 3))
  expect_false(eq$scale)
  expect_true(is.na(eq$prop_var))

  wt <- drm_composite(
    "C",
    c("i1", "i2"),
    weights = c(1, 2),
    method = "fixed",
    data = dat3
  )
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
    drm_composite(
      "C",
      c("i1", "i2"),
      weights = 1,
      method = "fixed",
      data = dat3
    ),
    "one value per indicator"
  )
  expect_error(
    drm_composite(c("C", "D"), c("i1", "i2"), data = dat3),
    "single non-empty"
  )
  expect_error(drm_composite("C", c("i1", "i2")), "is required")
})

# ---- drm_score_composite(): the materialized column -------------------------

test_that("drm_score_composite computes the construct column", {
  eq <- drm_composite("C", c("i1", "i2", "i3"), method = "fixed", data = dat3)
  s <- drmSEM:::drm_score_composite(eq, dat3)
  expect_equal(s, (dat3$i1 + dat3$i2 + dat3$i3) / 3)

  wt <- drm_composite(
    "C",
    c("i1", "i2"),
    weights = c(1, 2),
    method = "fixed",
    data = dat3
  )
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
  c2 <- drm_composite(
    "C2",
    c("i1", "i3"),
    weights = c(2, 1),
    method = "fixed",
    data = dat3
  )
  obj <- structure(list(composites = list(c1, c2)), class = "drm_sem")
  lt <- loadings(obj)
  expect_s3_class(lt, "drm_loadings")
  expect_identical(sort(unique(lt$composite)), c("C1", "C2"))
  expect_identical(nrow(lt), 4L)
  expect_equal(lt$loading[lt$composite == "C2" & lt$indicator == "i1"], 2)

  expect_identical(nrow(loadings(structure(list(), class = "drm_sem"))), 0L)
})

# 0.3 — composite reliability (Cronbach's alpha), standardize option, summary.

test_that("Cronbach's alpha matches the formula and handles edge cases", {
  # two identical columns -> perfectly reliable (alpha = 1)
  M <- cbind(a = c(1, 2, 3, 4, 5), b = c(1, 2, 3, 4, 5))
  expect_equal(drmSEM:::drm_cronbach_alpha(M), 1, tolerance = 1e-8)
  # a single indicator is undefined
  expect_true(is.na(drmSEM:::drm_cronbach_alpha(matrix(1:5, ncol = 1))))
  # poorly-correlated indicators give a low (here negative) alpha, not clamped
  M2 <- cbind(c(1, 2, 3, 4, 5), c(5, 1, 4, 2, 3))
  expect_lt(drmSEM:::drm_cronbach_alpha(M2), 1)
})

test_that("drm_composite records reliability and honours standardize", {
  dat <- data.frame(
    a = c(1, 2, 3, 4, 5),
    b = c(1, 2, 3, 4, 5),
    cc = c(1, 2, 3, 4, 5)
  )
  sp <- drm_composite("idx", c("a", "b", "cc"), data = dat)
  expect_equal(sp$reliability, 1, tolerance = 1e-8) # identical indicators
  expect_false(sp$standardize)

  sp2 <- drm_composite("idx", c("a", "b", "cc"), data = dat, standardize = TRUE)
  expect_true(sp2$standardize)
  sc <- drmSEM:::drm_score_composite(sp2, dat)
  expect_equal(mean(sc), 0, tolerance = 1e-8)
  expect_equal(stats::sd(sc), 1, tolerance = 1e-8)

  expect_error(
    drm_composite("idx", c("a", "b"), data = dat, standardize = "yes"),
    "logical"
  )
  expect_no_error(summary(sp))
})

test_that("composites materialize and fit end-to-end (predictor and response)", {
  skip_if_not_installed("drmTMB")
  set.seed(3)
  n <- 200
  z <- rnorm(n)
  dat <- data.frame(
    i1 = z + rnorm(n, sd = .4),
    i2 = z + rnorm(n, sd = .4),
    i3 = z + rnorm(n, sd = .4),
    x = rnorm(n)
  )
  dat$y <- 0.5 * z + 0.3 * dat$x + rnorm(n)

  # composite as a PREDICTOR
  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ size + x), family = stats::gaussian()),
    data = dat,
    composites = drm_composite(
      "size",
      c("i1", "i2", "i3"),
      method = "pca",
      data = dat
    )
  )
  expect_s3_class(sem, "drm_sem")
  expect_true("size" %in% names(sem$data)) # materialized before fitting
  expect_true(any(paths(sem)$from == "size" & paths(sem)$to == "y"))
  expect_equal(sort(loadings(sem)$indicator), c("i1", "i2", "i3"))

  # composite as a RESPONSE (node name == composite name; the construct is modelled)
  sem2 <- drm_sem(
    size = drm_node(drmTMB::bf(size ~ x), family = stats::gaussian()),
    data = dat,
    composites = drm_composite(
      "size",
      c("i1", "i2", "i3"),
      method = "pca",
      data = dat
    )
  )
  expect_true(any(paths(sem2)$from == "x" & paths(sem2)$to == "size"))
})
