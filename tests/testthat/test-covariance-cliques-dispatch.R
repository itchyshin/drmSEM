# Engine-free tests for the covariance-clique API in R/covariances.R:
# S3 dispatch of covariance_cliques(), the min_size filter, the internal
# clique finder / block partitioner on hand-built tables, the print method,
# and covary_clique() arguments. No drmTMB is needed.

# Hand-built covariance table in the shape drm_build_covariances() returns.
cov_table <- function(pairs, class = "residual", level = NA_character_) {
  data.frame(
    y1 = vapply(pairs, `[[`, character(1), 1L),
    y2 = vapply(pairs, `[[`, character(1), 2L),
    class = class,
    level = level,
    structure = "unstructured",
    label = vapply(pairs, paste, character(1), collapse = ","),
    stringsAsFactors = FALSE
  )
}

two_cliques <- cov_table(list(
  c("a", "b"), c("b", "c"), c("a", "c"), # triangle a-b-c
  c("x", "y") # disjoint edge
))
triangle_pendant <- cov_table(list(
  c("a", "b"), c("b", "c"), c("a", "c"), c("c", "d")
))
path_abc <- cov_table(list(c("a", "b"), c("b", "c")))

# ---- (a) covariance_cliques.default -----------------------------------------

test_that("default method flattens a list of covary() objects", {
  covs <- list(covary("a", "b"), covary(c("x", "y", "z")))
  res <- covariance_cliques(covs)
  expect_s3_class(res, "drm_covariance_cliques")
  expect_identical(nrow(res), 2L)
  expect_identical(res$nodes, c("x, y, z", "a, b"))
  expect_identical(res$size, c(3L, 2L))
})

test_that("default method wraps a single drm_covary object", {
  res <- covariance_cliques(covary("a", "b"))
  expect_identical(nrow(res), 1L)
  expect_identical(res$nodes, "a, b")
  expect_identical(res$pairs_count, 1L)
  expect_true(res$complete)
})

test_that("default method flattens a nested covary_clique() list", {
  res <- covariance_cliques(list(covary_clique(c("p", "q", "r")), covary("r", "s")))
  expect_identical(res$nodes, c("p, q, r", "r, s"))
})

test_that("default method passes a data.frame straight through", {
  res <- covariance_cliques.default(two_cliques)
  expect_identical(res, covariance_cliques(two_cliques))
  expect_identical(nrow(res), 2L)
})

test_that("default method aborts on unsupported input", {
  expect_error(
    covariance_cliques(1),
    "No `covariance_cliques\\(\\)` method for object of class <numeric>"
  )
  expect_error(
    covariance_cliques("a"),
    "No `covariance_cliques\\(\\)` method for object of class <character>"
  )
  expect_error(covariance_cliques(NULL), "No `covariance_cliques\\(\\)` method")
  # A list that is not all covary() declarations is rejected too.
  expect_error(
    covariance_cliques(list(covary("a", "b"), 1)),
    "No `covariance_cliques\\(\\)` method for object of class <list>"
  )
})

# ---- (b) data.frame and drm_covariances methods -----------------------------

test_that("data.frame method finds cliques in a hand-built table", {
  res <- covariance_cliques(two_cliques)
  expect_s3_class(res, "drm_covariance_cliques")
  expect_identical(res$nodes, c("a, b, c", "x, y"))
  expect_identical(res$clique_id, 1:2)
})

test_that("drm_covariances method agrees with the data.frame method", {
  cv <- structure(two_cliques, class = c("drm_covariances", "data.frame"))
  res <- covariance_cliques(cv)
  expect_identical(res$nodes, c("a, b, c", "x, y"))
  expect_identical(res$size, c(3L, 2L))
  expect_identical(
    as.data.frame(res),
    as.data.frame(covariance_cliques(two_cliques))
  )
})

# ---- (c) min_size -------------------------------------------------------------

test_that("min_size = 3 drops 2-node cliques", {
  res <- covariance_cliques(triangle_pendant, min_size = 3L)
  expect_identical(nrow(res), 1L)
  expect_identical(res$nodes, "a, b, c")
  expect_true(all(res$size >= 3L))
  # Default keeps the pendant edge as a 2-clique.
  expect_identical(nrow(covariance_cliques(triangle_pendant)), 2L)
})

test_that("min_size is honoured by every method", {
  covs <- list(covary("a", "b"), covary(c("x", "y", "z")))
  expect_identical(covariance_cliques(covs, min_size = 3L)$nodes, "x, y, z")
  expect_identical(covariance_cliques(covary("a", "b"), min_size = 3L)$size, integer(0))
  expect_identical(covariance_cliques(two_cliques, min_size = 3L)$nodes, "a, b, c")
})

test_that("min_size above every clique gives the typed empty result", {
  res <- covariance_cliques(triangle_pendant, min_size = 4L)
  expect_identical(nrow(res), 0L)
  expect_s3_class(res, "drm_covariance_cliques")
  expect_identical(attr(res, "members"), list())
})

# ---- (d) clique finder and block partitioner on small tables ---------------

test_that("two disjoint cliques are both found, largest first", {
  res <- drmSEM:::drm_find_covariance_cliques(two_cliques)
  expect_identical(res$size, c(3L, 2L))
  expect_identical(res$pairs_count, c(3L, 1L))
  expect_true(all(res$complete))
  expect_identical(
    attr(res, "members"),
    list(c("a", "b", "c"), c("x", "y"))
  )

  blocks <- drmSEM:::drm_partition_covariance_blocks(two_cliques)
  expect_identical(nrow(blocks), 2L)
  expect_identical(blocks$nodes, c("a, b, c", "x, y"))
  expect_identical(blocks$type, c("complete_clique", "complete_clique"))
  # Only a 2-node complete block is an admissible joint block.
  expect_identical(blocks$admissible_joint_block, c(FALSE, TRUE))
})

test_that("a triangle plus a pendant edge gives a 3-clique and a 2-clique", {
  res <- drmSEM:::drm_find_covariance_cliques(triangle_pendant)
  expect_identical(res$nodes, c("a, b, c", "c, d"))
  expect_identical(res$size, c(3L, 2L))

  blocks <- drmSEM:::drm_partition_covariance_blocks(triangle_pendant)
  expect_identical(nrow(blocks), 1L)
  expect_identical(blocks$size, 4L)
  expect_identical(blocks$edges_count, 4L)
  expect_identical(blocks$type, "structured_network")
  expect_false(blocks$admissible_joint_block)
})

test_that("a path a-b-c is not a 3-clique", {
  res <- drmSEM:::drm_find_covariance_cliques(path_abc)
  expect_identical(res$nodes, c("a, b", "b, c"))
  expect_true(all(res$size == 2L))
  expect_identical(nrow(drmSEM:::drm_find_covariance_cliques(path_abc, min_size = 3L)), 0L)

  blocks <- drmSEM:::drm_partition_covariance_blocks(path_abc)
  expect_identical(blocks$size, 3L)
  expect_identical(blocks$edges_count, 2L)
  expect_identical(blocks$type, "structured_network")
  expect_false(blocks$admissible_joint_block)
})

test_that("residual and higher-level edges are never merged into one clique", {
  mixed <- rbind(
    cov_table(list(c("a", "b"))),
    cov_table(list(c("a", "b")), class = "higher_level", level = "site")
  )
  res <- drmSEM:::drm_find_covariance_cliques(mixed)
  expect_identical(nrow(res), 2L)
  expect_setequal(res$class, c("residual", "higher_level"))
  expect_setequal(res$level, c(NA, "site"))
})

test_that("the empty table gives drm_empty_covariance_cliques()", {
  empty <- drmSEM:::drm_empty_covariance_cliques()
  expect_identical(drmSEM:::drm_find_covariance_cliques(NULL), empty)
  expect_identical(
    drmSEM:::drm_find_covariance_cliques(drmSEM:::drm_empty_covariances()),
    empty
  )
  expect_s3_class(empty, "drm_covariance_cliques")
  expect_identical(nrow(empty), 0L)
  expect_identical(
    names(empty),
    c("clique_id", "class", "level", "size", "nodes", "pairs_count", "complete")
  )
  expect_identical(attr(empty, "members"), list())
  # A table lacking the required columns is also treated as empty.
  expect_identical(
    drmSEM:::drm_find_covariance_cliques(data.frame(u = "a", v = "b")),
    empty
  )

  blocks <- drmSEM:::drm_partition_covariance_blocks(drmSEM:::drm_empty_covariances())
  expect_identical(nrow(blocks), 0L)
  expect_true("admissible_joint_block" %in% names(blocks))
})

# ---- (e) print.drm_covariance_cliques ---------------------------------------

test_that("print reports an empty result", {
  empty <- drmSEM:::drm_empty_covariance_cliques()
  expect_message(print(empty), "covariance cliques: none")
  expect_identical(suppressMessages(print(empty)), empty)
})

test_that("print reports a non-empty result and returns it invisibly", {
  res <- covariance_cliques(two_cliques)
  expect_message(capture.output(print(res)), "covariance cliques: 2 cliques \\(K >= 3: 1\\)")
  expect_output(suppressMessages(print(res)), "a, b, c")
  expect_output(suppressMessages(print(res)), "x, y")
  out <- NULL
  suppressMessages(capture.output(out <- withVisible(print(res))))
  expect_false(out$visible)
  expect_identical(out$value, res)

  # Singular wording for a single clique.
  one <- covariance_cliques(covary("a", "b"))
  expect_message(capture.output(print(one)), "1 clique \\(K >= 3: 0\\)")
})

# ---- (f) covary_clique() arguments ------------------------------------------

test_that("covary_clique() carries level and structure onto every edge", {
  res <- covary_clique(c("a", "b", "c"), level = "site", structure = "diagonal")
  expect_length(res, 3L)
  expect_true(all(vapply(res, function(e) identical(e$class, "higher_level"), logical(1))))
  expect_true(all(vapply(res, function(e) identical(e$level, "site"), logical(1))))
  expect_true(all(vapply(res, function(e) identical(e$structure, "diagonal"), logical(1))))

  resid <- covary_clique(c("a", "b"), structure = "diagonal")
  expect_length(resid, 1L)
  expect_identical(resid[[1L]]$class, "residual")
  expect_true(is.na(resid[[1L]]$level))
  expect_identical(resid[[1L]]$structure, "diagonal")
})

test_that("covary_clique() default structure is unstructured", {
  res <- covary_clique(c("a", "b", "c"))
  expect_true(all(vapply(res, function(e) identical(e$structure, "unstructured"), logical(1))))
})

test_that("covary_clique() aborts on duplicate responses", {
  expect_error(covary_clique(c("a", "b", "a")), "distinct response names")
  expect_error(covary_clique(c("a", "a")), "distinct response names")
  expect_error(covary_clique(c("a", "")), "at least two")
})
