# OQ-14 / 0.4 — drm_pair(): the bivariate-node declaration grammar. The parsing,
# the covary() bridge, and the rho12()/corpairs() accessors are pure-R, so they
# are tested here without drmTMB. The joint bivariate FIT (estimating rho12) and
# reading fitted estimates back are the engine deliverable: every `estimate`
# below is asserted to be NA, never fabricated.

# ---- formula parsing helpers ------------------------------------------------

test_that("drm_formula_response reads the response label", {
  expect_identical(drmSEM:::drm_formula_response(activity ~ x + (1 | id)), "activity")
  expect_identical(drmSEM:::drm_formula_response(cbind(succ, fail) ~ x), "succ")
  expect_error(drmSEM:::drm_formula_response(~ x), "two-sided")
})

test_that("drm_formula_groups extracts grouping factors, ignoring the |p| label", {
  expect_identical(drmSEM:::drm_formula_groups(y ~ x + (1 | id)), "id")
  expect_identical(
    sort(drmSEM:::drm_formula_groups(y ~ (1 | id) + (1 | site))),
    c("id", "site")
  )
  # brms-style shared-label block (1 | p | id): grouping is `id`, not `p`
  expect_identical(drmSEM:::drm_formula_groups(y ~ (1 | p | id)), "id")
  expect_identical(drmSEM:::drm_formula_groups(y ~ x), character(0))
})

# ---- drm_pair(): declaration + validation -----------------------------------

test_that("drm_pair records responses, families, rho12, and shared level", {
  pair <- drm_pair(
    activity ~ x + (1 | id),
    boldness ~ x + (1 | id),
    rho12 = ~ x
  )
  expect_s3_class(pair, "drm_pair")
  expect_identical(pair$responses, c("activity", "boldness"))
  expect_false(pair$rho12$constant)
  expect_identical(pair$rho12$predictors, "x")
  # the shared (1 | id) grouping auto-declares one corpair edge at level "id"
  expect_identical(pair$levels, "id")
  expect_length(pair$corpairs, 1L)
  expect_s3_class(pair$residual, "drm_covary")
  expect_identical(pair$residual$class, "residual")
})

test_that("drm_pair defaults to a constant residual correlation and no corpair", {
  pair <- drm_pair(activity ~ x, boldness ~ x)
  expect_true(pair$rho12$constant)
  expect_identical(pair$rho12$predictors, character(0))
  expect_identical(pair$levels, character(0))
  expect_length(pair$corpairs, 0L)
})

test_that("drm_pair honours explicit and suppressed levels", {
  # NA suppresses the corpair even when a grouping is shared
  pair_na <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id), level = NA)
  expect_identical(pair_na$levels, character(0))

  # an explicit level not shared by both responses warns (level-compatibility)
  expect_warning(
    drm_pair(activity ~ x + (1 | id), boldness ~ x, level = "site"),
    "not a grouping shared"
  )
})

test_that("drm_pair validates its inputs", {
  expect_error(drm_pair(~ x, boldness ~ x), "two-sided")
  expect_error(drm_pair("y ~ x", boldness ~ x), "must both be formulas")
  expect_error(drm_pair(y ~ x, y ~ z), "distinct")
  expect_error(drm_pair(activity ~ x, boldness ~ x, rho12 = "x"), "one-sided formula")
  expect_error(
    drm_pair(activity ~ x, boldness ~ x, names = c("a", "a")),
    "distinct"
  )
})

test_that("names= overrides the response labels", {
  pair <- drm_pair(y1 ~ x, y2 ~ x, names = c("alpha", "beta"))
  expect_identical(pair$responses, c("alpha", "beta"))
  expect_identical(pair$residual$y1, "alpha")
})

# ---- rho12() / corpairs() accessors on a drm_pair ---------------------------

test_that("rho12(pair) reports the declared residual edge with NA estimate", {
  pair <- drm_pair(activity ~ x, boldness ~ x, rho12 = ~ x)
  r <- rho12(pair)
  expect_s3_class(r, "drm_rho12")
  expect_identical(nrow(r), 1L)
  expect_identical(r$predictors, "x")
  expect_false(r$constant)
  expect_true(is.na(r$estimate))           # never fabricated
})

test_that("corpairs(pair) reports declared higher-level edges with NA estimate", {
  pair <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id))
  cp <- corpairs(pair)
  expect_s3_class(cp, "drm_corpairs")
  expect_identical(cp$level, "id")
  expect_true(is.na(cp$estimate))

  # no shared grouping -> empty corpairs table
  expect_identical(nrow(corpairs(drm_pair(a ~ x, b ~ x))), 0L)
})

# ---- the covary() bridge: rho12/corpair flow into d-separation ---------------

test_that("a pair's residual edge drops the y1 _||_ y2 independence claim", {
  pair <- drm_pair(y1 ~ x, y2 ~ x)
  # feed the pair's covariance edges into a sibling SEM and confirm the claim drops
  cov_df <- drmSEM:::drm_build_covariances(
    c(list(pair$residual), pair$corpairs),
    list(y1 = list(identifiers = "y1"), y2 = list(identifiers = "y2"))
  )
  obj <- structure(list(
    order = c("y1", "y2"), endogenous = c("y1", "y2"), exogenous = "x",
    edges = data.frame(from = c("x", "x"), to = c("y1", "y2"),
                       component = c("mu", "mu"), stringsAsFactors = FALSE),
    covariances = cov_df
  ), class = "drm_sem")
  bs <- basis_set(obj)
  expect_false(any((bs$x == "y1" & bs$y == "y2") | (bs$x == "y2" & bs$y == "y1")))
})

# ---- rho12() / corpairs() on a drm_sem (declared edges, NA estimate) ---------

test_that("rho12()/corpairs() on a drm_sem read the declared covariance edges", {
  cov_df <- rbind(
    data.frame(y1 = "activity", y2 = "boldness", class = "residual",
               level = NA_character_, structure = "unstructured",
               label = "rho12(activity, boldness)", stringsAsFactors = FALSE),
    data.frame(y1 = "activity", y2 = "boldness", class = "higher_level",
               level = "id", structure = "unstructured",
               label = "corpair(id: activity, boldness)", stringsAsFactors = FALSE)
  )
  obj <- structure(list(
    covariances = cov_df,
    edges = data.frame(from = character(0), to = character(0),
                       component = character(0), term = character(0),
                       stringsAsFactors = FALSE)
  ), class = "drm_sem")

  r <- rho12(obj)
  expect_identical(nrow(r), 1L)
  expect_identical(r$y1, "activity")
  expect_true(is.na(r$estimate))

  cp <- corpairs(obj)
  expect_identical(cp$level, "id")
  expect_true(is.na(cp$estimate))
})

# ---- drm_expand_pair(): the engine hook point (needs drmTMB to build nodes) --

test_that("drm_expand_pair returns covary edges without an engine", {
  pair <- drm_pair(activity ~ x + (1 | id), boldness ~ x + (1 | id))
  # The covariance edges are pure-R and available regardless of the engine.
  expect_error(drm_expand_pair(42), "drm_pair")
  if (requireNamespace("drmTMB", quietly = TRUE)) {
    ex <- drm_expand_pair(pair)
    expect_named(ex$nodes, c("activity", "boldness"))
    expect_s3_class(ex$nodes$activity, "drm_node")
    expect_true(all(vapply(ex$covariances, inherits, logical(1), "drm_covary")))
  }
})
