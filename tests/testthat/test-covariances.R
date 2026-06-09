# OQ-14 — covariance edges (rho12 / corpair). The grammar, accessor, and the
# d-separation consequence are pure graph logic, so they are tested here without
# drmTMB (reading rho12()/corpairs() back from a live bivariate fit is the
# engine-dependent remainder of OQ-14).

# ---- covary(): the declaration primitive ------------------------------------

test_that("covary() builds residual and higher-level declarations", {
  res <- covary("activity", "boldness")
  expect_s3_class(res, "drm_covary")
  expect_identical(res$class, "residual")
  expect_true(is.na(res$level))

  hl <- covary("activity", "boldness", level = "id")
  expect_identical(hl$class, "higher_level")
  expect_identical(hl$level, "id")
  expect_identical(hl$structure, "unstructured")
})

test_that("covary() rejects malformed declarations", {
  expect_error(covary("a", "a"), "distinct")
  expect_error(covary("a", 1), "string")
  expect_error(covary("a", "b", level = c("x", "y")), "grouping name")
  expect_error(covary(c("a", "b"), "c"), "string")
})

# ---- drm_build_covariances(): validation against node records ---------------

records3 <- list(
  activity = list(identifiers = c("activity")),
  boldness = list(identifiers = c("boldness")),
  fitness = list(identifiers = c("fitness"))
)

test_that("drm_build_covariances resolves nodes, labels, and de-duplicates", {
  expect_identical(nrow(drmSEM:::drm_build_covariances(NULL, records3)), 0L)

  one <- drmSEM:::drm_build_covariances(
    covary("activity", "boldness"),
    records3
  )
  expect_identical(nrow(one), 1L)
  expect_identical(one$class, "residual")
  expect_identical(one$label, "rho12(activity, boldness)")

  hl <- drmSEM:::drm_build_covariances(
    covary("activity", "boldness", level = "id"),
    records3
  )
  expect_identical(hl$label, "corpair(id: activity, boldness)")

  # the same unordered residual pair declared twice collapses to one row
  dup <- drmSEM:::drm_build_covariances(
    list(covary("activity", "boldness"), covary("boldness", "activity")),
    records3
  )
  expect_identical(nrow(dup), 1L)
})

test_that("drm_build_covariances errors on unknown or self-referential responses", {
  expect_error(
    drmSEM:::drm_build_covariances(covary("activity", "ghost"), records3),
    "not a response node"
  )
  records_alias <- list(
    activity = list(identifiers = c("activity", "act")),
    boldness = list(identifiers = c("boldness"))
  )
  expect_error(
    drmSEM:::drm_build_covariances(covary("activity", "act"), records_alias),
    "same node"
  )
})

# ---- covariances() accessor -------------------------------------------------

test_that("covariances() returns a classed table, separating residual vs higher-level", {
  cov_df <- rbind(
    data.frame(
      y1 = "activity",
      y2 = "boldness",
      class = "residual",
      level = NA_character_,
      structure = "unstructured",
      label = "rho12(activity, boldness)",
      stringsAsFactors = FALSE
    ),
    data.frame(
      y1 = "activity",
      y2 = "boldness",
      class = "higher_level",
      level = "id",
      structure = "unstructured",
      label = "corpair(id: activity, boldness)",
      stringsAsFactors = FALSE
    )
  )
  obj <- structure(list(covariances = cov_df), class = "drm_sem")
  cv <- covariances(obj)
  expect_s3_class(cv, "drm_covariances")
  expect_identical(sort(cv$class), c("higher_level", "residual"))

  # an object built before this slot existed yields an empty (not error) table
  obj0 <- structure(list(), class = "drm_sem")
  expect_identical(nrow(covariances(obj0)), 0L)
})

# ---- the d-separation consequence: basis_set drops y1 _||_ y2 ---------------

# x -> y1 (mu), x -> y2 (mu): y1 and y2 are non-adjacent siblings, so the basis
# set normally contains the claim y1 _||_ y2 | {x}.
make_sibling_obj <- function(cov_df = NULL) {
  structure(
    list(
      order = c("y1", "y2"),
      endogenous = c("y1", "y2"),
      exogenous = "x",
      edges = data.frame(
        from = c("x", "x"),
        to = c("y1", "y2"),
        component = c("mu", "mu"),
        stringsAsFactors = FALSE
      ),
      covariances = cov_df
    ),
    class = "drm_sem"
  )
}

test_that("a declared covariance edge drops the y1 _||_ y2 independence claim", {
  bs_plain <- basis_set(make_sibling_obj(NULL))
  expect_true(any(bs_plain$x == "y1" & bs_plain$y == "y2"))

  cov_df <- data.frame(
    y1 = "y1",
    y2 = "y2",
    class = "residual",
    level = NA_character_,
    structure = "unstructured",
    label = "rho12(y1, y2)",
    stringsAsFactors = FALSE
  )
  bs_cov <- basis_set(make_sibling_obj(cov_df))
  expect_false(any(bs_cov$x == "y2" & bs_cov$y == "y1"))
  expect_false(any(bs_cov$x == "y1" & bs_cov$y == "y2"))

  # a higher-level (corpair) edge drops the claim just the same
  cov_hl <- data.frame(
    y1 = "y2",
    y2 = "y1",
    class = "higher_level",
    level = "id",
    structure = "unstructured",
    label = "corpair(id: y2, y1)",
    stringsAsFactors = FALSE
  )
  bs_hl <- basis_set(make_sibling_obj(cov_hl))
  expect_false(any(
    (bs_hl$x == "y1" & bs_hl$y == "y2") |
      (bs_hl$x == "y2" & bs_hl$y == "y1")
  ))
})

test_that("drm_covariance_pairs is empty when no covariance slot is present", {
  expect_identical(
    drmSEM:::drm_covariance_pairs(structure(list(), class = "drm_sem")),
    character(0)
  )
})
