# Track 3: K >= 3 Covariance Clique Partitioning & d-Separation Suppression (0.4)
# Tests V-145 .. V-147.

# ---- Pure-R Graph & Clique Partitioning Logic (No Engine) -------------------

test_that("covary_clique declares all pairwise combinations", {
  cl <- covary_clique(c("y1", "y2", "y3"))
  expect_type(cl, "list")
  expect_length(cl, 3L)
  expect_true(all(vapply(cl, inherits, logical(1), "drm_covary")))

  pairs <- lapply(cl, function(cv) sort(c(cv$y1, cv$y2)))
  expect_true(any(vapply(pairs, identical, logical(1), c("y1", "y2"))))
  expect_true(any(vapply(pairs, identical, logical(1), c("y2", "y3"))))
  expect_true(any(vapply(pairs, identical, logical(1), c("y1", "y3"))))

  # Higher-level corpair clique
  hl_cl <- covary_clique(c("a", "b", "c", "d"), level = "site")
  expect_length(hl_cl, 6L)
  expect_true(all(vapply(hl_cl, function(cv) cv$class == "higher_level", logical(1))))
  expect_true(all(vapply(hl_cl, function(cv) cv$level == "site", logical(1))))

  # covary() with a vector delegates to covary_clique()
  vec_cl <- covary(c("a", "b", "c"))
  expect_length(vec_cl, 3L)
})

test_that("covary_clique validates inputs", {
  expect_error(covary_clique("y1"), "at least two")
  expect_error(covary_clique(c("y1", "y1")), "distinct")
  expect_error(covary_clique(c("y1", NA)), "distinct")
  expect_error(covary_clique(1:3), "character vector")
})

test_that("covariance_cliques detects maximal cliques and partitions blocks", {
  # Triangle y1-y2-y3 plus attached edge y3-y4
  covs <- list(
    covary("y1", "y2"),
    covary("y2", "y3"),
    covary("y1", "y3"),
    covary("y3", "y4")
  )
  records4 <- list(
    y1 = list(identifiers = "y1"),
    y2 = list(identifiers = "y2"),
    y3 = list(identifiers = "y3"),
    y4 = list(identifiers = "y4")
  )
  cv_df <- drmSEM:::drm_build_covariances(covs, records4)
  expect_identical(nrow(cv_df), 4L)

  cliques <- covariance_cliques(cv_df)
  expect_s3_class(cliques, "drm_covariance_cliques")
  expect_identical(nrow(cliques), 2L)

  # Largest clique is (y1, y2, y3) of size 3
  expect_identical(cliques$size[[1L]], 3L)
  expect_identical(cliques$nodes[[1L]], "y1, y2, y3")
  expect_identical(cliques$pairs_count[[1L]], 3L)
  expect_true(cliques$complete[[1L]])

  # Second clique is (y3, y4) of size 2
  expect_identical(cliques$size[[2L]], 2L)
  expect_identical(cliques$nodes[[2L]], "y3, y4")

  # Block partitioning classifies the connected component as structured network
  blocks <- drmSEM:::drm_partition_covariance_blocks(cv_df)
  expect_identical(nrow(blocks), 1L)
  expect_identical(blocks$size[[1L]], 4L)
  expect_identical(blocks$edges_count[[1L]], 4L)
  expect_identical(blocks$type[[1L]], "structured_network")
  expect_false(blocks$admissible_joint_block[[1L]])

  # Print method output check
  expect_message(print(cliques), "covariance cliques: 2 cliques")
  expect_output(print(cliques), "y1, y2, y3")
})

# ---- V-145: 3-Response Covariance Block Basis-Set Suppression ----------------

test_that("3-response covariance block suppresses all 3 pairwise claims (V-145)", {
  # SEM with 3 endogenous nodes and complete residual covariance clique
  sem_obj <- structure(
    list(
      order = c("y1", "y2", "y3"),
      endogenous = c("y1", "y2", "y3"),
      exogenous = character(0),
      edges = data.frame(
        from = character(0),
        to = character(0),
        component = character(0),
        term = character(0),
        stringsAsFactors = FALSE
      ),
      covariances = data.frame(
        y1 = c("y1", "y2", "y1"),
        y2 = c("y2", "y3", "y3"),
        class = c("residual", "residual", "residual"),
        level = c(NA_character_, NA_character_, NA_character_),
        structure = rep("unstructured", 3L),
        label = c("rho12(y1, y2)", "rho12(y2, y3)", "rho12(y1, y3)"),
        stringsAsFactors = FALSE
      )
    ),
    class = "drm_sem"
  )

  # Check clique detection on the SEM
  cliques <- covariance_cliques(sem_obj)
  expect_identical(nrow(cliques), 1L)
  expect_identical(cliques$size[[1L]], 3L)
  expect_identical(cliques$nodes[[1L]], "y1, y2, y3")
  expect_true(cliques$complete[[1L]])

  # Basis set must drop all 3 pairwise claims: y1 _||_ y2, y1 _||_ y3, y2 _||_ y3
  bs <- basis_set(sem_obj)
  expect_identical(nrow(bs), 0L)
  expect_false(any(
    (bs$x == "y1" & bs$y == "y2") |
      (bs$x == "y2" & bs$y == "y1") |
      (bs$x == "y2" & bs$y == "y3") |
      (bs$x == "y3" & bs$y == "y2") |
      (bs$x == "y1" & bs$y == "y3") |
      (bs$x == "y3" & bs$y == "y1")
  ))
})

# ---- V-146: d-Separation Test Accuracy for External Predictors & Descendants -

test_that("d-separation tests external predictors and downstream descendants of covariance block (V-146)", {
  # DAG: x -> y1, {y1, y2, y3} clique, y3 -> z
  edges <- data.frame(
    from = c("x", "y3"),
    to = c("y1", "z"),
    component = c("mu", "mu"),
    term = c("x", "y3"),
    stringsAsFactors = FALSE
  )
  cov_df <- data.frame(
    y1 = c("y1", "y2", "y1"),
    y2 = c("y2", "y3", "y3"),
    class = rep("residual", 3L),
    level = rep(NA_character_, 3L),
    structure = rep("unstructured", 3L),
    label = c("rho12(y1, y2)", "rho12(y2, y3)", "rho12(y1, y3)"),
    stringsAsFactors = FALSE
  )

  sem_dag <- structure(
    list(
      order = c("y1", "y2", "y3", "z"),
      endogenous = c("y1", "y2", "y3", "z"),
      exogenous = c("x"),
      edges = edges,
      covariances = cov_df
    ),
    class = "drm_sem"
  )

  bs <- basis_set(sem_dag)
  # Expected claims:
  # x _||_ y2 | {}
  # x _||_ y3 | {}
  # x _||_ z | {y3}
  # y1 _||_ z | {y3}
  # y2 _||_ z | {y3}
  expect_identical(nrow(bs), 5L)

  # Check all expected claims are present
  expect_true(any(bs$x == "x" & bs$y == "y2"))
  expect_true(any(bs$x == "x" & bs$y == "y3"))
  expect_true(any(bs$x == "x" & bs$y == "z" & grepl("y3", bs$given)))
  expect_true(any(bs$x == "y1" & bs$y == "z" & grepl("y3", bs$given)))
  expect_true(any(bs$x == "y2" & bs$y == "z" & grepl("y3", bs$given)))

  # Zero within-clique claims among y1, y2, y3
  clique_vars <- c("y1", "y2", "y3")
  expect_false(any(bs$x %in% clique_vars & bs$y %in% clique_vars))
})

# ---- Live Engine Recovery Tests (drmTMB Gated) -------------------------------

skip_if_not_installed("drmTMB")

simulate_trivariate_clique <- function(n, rho12 = 0.40, rho23 = 0.50, rho13 = 0.30, seed = 20260828) {
  set.seed(seed)
  x <- stats::rnorm(n)
  
  # Covariance matrix for residuals
  sigma_mat <- matrix(c(
    1.0,   rho12, rho13,
    rho12, 1.0,   rho23,
    rho13, rho23, 1.0
  ), nrow = 3L, ncol = 3L, byrow = TRUE)
  
  # Cholesky decomposition for correlated noise
  chol_s <- chol(sigma_mat)
  raw_e <- matrix(stats::rnorm(n * 3L), nrow = n, ncol = 3L)
  eps <- raw_e %*% chol_s
  
  y1 <- 0.2 + 0.6 * x + eps[, 1L]
  y2 <- -0.1 + eps[, 2L]
  y3 <- 0.4 + eps[, 3L]
  z <- 0.5 + 0.7 * y3 + stats::rnorm(n, sd = 0.8)
  
  data.frame(x = x, y1 = y1, y2 = y2, y3 = y3, z = z)
}

test_that("d-separation and Fisher's C accurately evaluate clique SEM (V-146 live)", {
  dat <- simulate_trivariate_clique(n = 500, rho12 = 0.40, rho23 = 0.50, rho13 = 0.30, seed = 20260828)

  sem <- drm_sem(
    y1 = drm_node(y1 ~ x, family = stats::gaussian()),
    y2 = drm_node(y2 ~ 1, family = stats::gaussian()),
    y3 = drm_node(y3 ~ 1, family = stats::gaussian()),
    z  = drm_node(z ~ y3, family = stats::gaussian()),
    covariances = covary_clique(c("y1", "y2", "y3")),
    data = dat
  )

  # Check covariance cliques accessor
  cl <- covariance_cliques(sem)
  expect_identical(nrow(cl), 1L)
  expect_identical(cl$size[[1L]], 3L)
  expect_identical(cl$nodes[[1L]], "y1, y2, y3")

  # Basis set has 5 external/descendant claims, zero within-clique claims
  bs <- basis_set(sem)
  expect_identical(nrow(bs), 5L)
  expect_false(any(bs$x %in% c("y1", "y2", "y3") & bs$y %in% c("y1", "y2", "y3")))

  # Run d-separation LRT
  ds <- dsep(sem)
  expect_s3_class(ds, "drm_dsep")
  expect_identical(nrow(ds), 5L)
  expect_true(all(ds$status == "ok"))
  # All true conditional independences should pass (p > 0.05)
  expect_true(all(ds$p.value > 0.05))

  # Fisher's C combines the 5 independent tests
  fc <- fisher_c(ds)
  expect_identical(fc$n_claims, 5L)
  expect_identical(fc$df, 10L)
  expect_gt(fc$p.value, 0.05)
})

test_that("pairwise bivariate models recover true rho_jk coefficients in a 3-response system (V-147)", {
  r12_true <- 0.40
  r23_true <- 0.50
  r13_true <- 0.30
  dat <- simulate_trivariate_clique(n = 600, rho12 = r12_true, rho23 = r23_true, rho13 = r13_true, seed = 20260828)

  # Fit pairwise joint bivariate models
  pair12 <- drm_pair(y1 ~ x, y2 ~ 1)
  sem12 <- drm_sem(pair12, data = dat)
  r12_fit <- rho12(sem12)
  expect_s3_class(r12_fit, "drm_rho12")
  expect_lt(abs(tanh(r12_fit$estimate[[1L]]) - r12_true), 0.12)

  pair23 <- drm_pair(y2 ~ 1, y3 ~ 1)
  sem23 <- drm_sem(pair23, data = dat)
  r23_fit <- rho12(sem23)
  expect_lt(abs(tanh(r23_fit$estimate[[1L]]) - r23_true), 0.12)

  pair13 <- drm_pair(y1 ~ x, y3 ~ 1)
  sem13 <- drm_sem(pair13, data = dat)
  r13_fit <- rho12(sem13)
  expect_lt(abs(tanh(r13_fit$estimate[[1L]]) - r13_true), 0.12)

  # Piecewise SEM with declared clique reports all 3 residual correlation edges
  sem_clique <- drm_sem(
    y1 = drm_node(y1 ~ x, family = stats::gaussian()),
    y2 = drm_node(y2 ~ 1, family = stats::gaussian()),
    y3 = drm_node(y3 ~ 1, family = stats::gaussian()),
    covariances = covary(c("y1", "y2", "y3")),
    data = dat
  )

  r_all <- rho12(sem_clique)
  expect_identical(nrow(r_all), 3L)
  expect_true(all(r_all$constant))
  covs <- covariances(sem_clique)
  expect_identical(nrow(covs), 3L)
  expect_true(all(covs$class == "residual"))
})
