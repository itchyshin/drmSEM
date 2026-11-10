# Pure-R kernels of the latent / reliability layer (R/latents.R): reliability
# coefficients against their textbook definitions, drm_latent() argument
# validation, score materialisation (cached scoring weights vs the stored-loading
# fallback), and the marginalised-latent (MAG) declarations. No drmTMB needed.

lk_data <- function(n = 400, seed = 7) {
  set.seed(seed)
  eta <- stats::rnorm(n)
  data.frame(
    y1 = 1.0 * eta + stats::rnorm(n, 0, 0.4),
    y2 = 0.8 * eta + stats::rnorm(n, 0, 0.4),
    y3 = 0.6 * eta + stats::rnorm(n, 0, 0.4),
    lab = "a"
  )
}

# ---- Cronbach's alpha / Raykov's rho -----------------------------------------

test_that("drm_cronbach_alpha equals its textbook definition, for matrices and data frames", {
  d <- lk_data()[, c("y1", "y2", "y3")]
  by_hand <- (3 / 2) * (1 - sum(apply(d, 2, stats::var)) / stats::var(rowSums(d)))
  expect_equal(drm_cronbach_alpha(d), by_hand, tolerance = 1e-10)
  expect_equal(drm_cronbach_alpha(as.matrix(d)), by_hand, tolerance = 1e-10)
  # three strongly related indicators -> high but < 1
  expect_gt(by_hand, 0.8)
  expect_lt(by_hand, 1)
})

test_that("drm_cronbach_alpha returns NA when it is undefined", {
  d <- lk_data()
  expect_identical(drm_cronbach_alpha(d$y1), NA_real_) # no column dimension
  expect_identical(drm_cronbach_alpha(d[, "y1", drop = FALSE]), NA_real_) # k < 2
  # exactly cancelling indicators -> non-positive total variance
  m <- cbind(a = d$y1, b = -d$y1)
  expect_identical(drm_cronbach_alpha(m), NA_real_)
})

test_that("drm_raykov_rho recovers the true composite reliability of a congeneric set", {
  set.seed(11)
  n <- 20000
  eta <- stats::rnorm(n)
  lam <- c(1, 0.8, 0.6)
  th <- c(0.16, 0.16, 0.16)
  M <- sapply(seq_along(lam), function(j) lam[j] * eta + stats::rnorm(n, 0, sqrt(th[j])))
  colnames(M) <- c("y1", "y2", "y3")
  truth <- sum(lam)^2 / (sum(lam)^2 + sum(th))
  # data-frame input with no loadings supplied: first-principal-component
  # loadings (an upper bound on the factor-model reliability), computed here
  # directly from the covariance eigen-decomposition
  S <- stats::cov(M)
  ev <- eigen(S, symmetric = TRUE)
  lam_pc <- abs(ev$vectors[, 1] * sqrt(ev$values[1]))
  th_pc <- pmax(diag(S) - lam_pc^2, 1e-6)
  pc_rho <- sum(lam_pc)^2 / (sum(lam_pc)^2 + sum(th_pc))
  expect_equal(drm_raykov_rho(as.data.frame(M)), pc_rho, tolerance = 1e-10)
  expect_gte(pc_rho, truth)
  expect_lt(pc_rho, 1)
  # supplied loadings and error variances reproduce the formula exactly
  expect_equal(
    drm_raykov_rho(M, loadings = lam, error_variances = th, factor_var = 1),
    truth,
    tolerance = 1e-12
  )
  # rho is clamped to [0, 1]
  expect_lte(drm_raykov_rho(M, loadings = lam, error_variances = c(0, 0, 0)), 1)
})

test_that("drm_raykov_rho returns NA for undefined inputs", {
  d <- lk_data()
  expect_identical(drm_raykov_rho(d$y1), NA_real_)
  expect_identical(drm_raykov_rho(d[, "y1", drop = FALSE]), NA_real_)
  m <- cbind(a = d$y1, b = d$y2)
  m[, "b"] <- NA_real_ # covariance with an all-NA column is non-finite
  expect_identical(drm_raykov_rho(m), NA_real_)
  expect_identical(
    drm_raykov_rho(cbind(a = d$y1, b = d$y2), loadings = c(0, 0), error_variances = c(0, 0)),
    NA_real_
  )
  # constant columns -> zero covariance matrix -> no positive leading eigenvalue
  expect_identical(drm_raykov_rho(cbind(a = rep(1, 10), b = rep(2, 10))), NA_real_)
})

test_that("drm_raykov_rho is invariant to the arbitrary sign of the leading eigenvector", {
  d <- lk_data()
  for (flip in list(c(1, 1, 1), c(-1, -1, -1), c(-1, 1, 1), c(1, -1, -1))) {
    M <- sweep(as.matrix(d[, c("y1", "y2", "y3")]), 2, flip, "*")
    S <- stats::cov(M)
    ev <- eigen(S, symmetric = TRUE)
    lam <- ev$vectors[, 1] * sqrt(ev$values[1])
    lam <- lam * sign(lam[which.max(abs(lam))])
    th <- pmax(diag(S) - lam^2, 1e-6)
    expect_equal(
      drm_raykov_rho(M),
      sum(lam)^2 / (sum(lam)^2 + sum(th)),
      tolerance = 1e-10
    )
  }
})

# ---- drm_latent() argument validation ----------------------------------------

test_that("drm_latent accepts mixed indicator lists and honours an indicator-level marker", {
  lat <- drm_latent(
    "eta",
    indicators = list(drm_indicator("y1"), "y2", drm_indicator("y3", marker = TRUE))
  )
  expect_identical(lat$indicators, c("y1", "y2", "y3"))
  expect_identical(lat$marker, "y3")
  expect_s3_class(lat$indicator_specs$y2, "drm_indicator")
  # an explicit `marker` argument wins over the indicator-level flag
  lat2 <- drm_latent(
    "eta",
    indicators = list(drm_indicator("y1"), drm_indicator("y3", marker = TRUE)),
    marker = "y1"
  )
  expect_identical(lat2$marker, "y1")
  # default marker is the first indicator
  expect_identical(drm_latent("eta", c("y2", "y1"))$marker, "y2")
})

test_that("drm_latent rejects malformed indicators, markers, and names", {
  expect_error(drm_latent("eta", list(1, 2)), "must be a character vector or list")
  expect_error(drm_latent("eta", 1:3), "must be a character vector or list")
  expect_error(drm_latent("eta", "y1"), "at least two indicator")
  expect_error(drm_latent("eta", c("y1", "y1")), "must be unique")
  expect_error(drm_latent("eta", c("y1", "y2"), marker = "zz"), "not among declared indicators")
  expect_error(drm_latent(c("a", "b"), c("y1", "y2")), "single non-empty string")
})

test_that("drm_resolve_latent validates its data argument", {
  lat <- drm_latent("eta", c("y1", "y2", "y3"))
  expect_error(drm_latent("eta", c("y1", "y2"), data = 1:3), "must be a data frame")
  expect_error(drm_latent("eta", c("y1", "nope"), data = lk_data()), "not found in")
  expect_error(drm_latent("eta", c("y1", "lab"), data = lk_data()), "must be numeric")
  expect_error(
    drm_latent("eta", c("y1", "y2"), method = "fixed", weights = 1, data = lk_data()),
    "one value per indicator"
  )
  expect_null(lat$loadings)
})

# ---- fixed-weight constructs -------------------------------------------------

test_that("method = 'fixed' defaults to equal weights and scores the weighted sum", {
  d <- lk_data()
  lat <- drm_latent("eta", c("y1", "y2", "y3"), method = "fixed", data = d)
  expect_equal(unname(lat$loadings), rep(1 / 3, 3))
  expect_equal(drm_score_latent(lat, d), rowMeans(d[, c("y1", "y2", "y3")]), tolerance = 1e-12)
})

test_that("standardised fixed constructs score to mean 0 and sd 1", {
  d <- lk_data()
  lat <- drm_latent(
    "eta", c("y1", "y2"),
    method = "fixed", weights = c(2, 1), standardize = TRUE, data = d
  )
  s <- drm_score_latent(lat, d)
  expect_equal(mean(s), 0, tolerance = 1e-10)
  expect_equal(stats::sd(s), 1, tolerance = 1e-10)
  # standardisation is an affine map of the raw weighted score
  raw <- 2 * d$y1 + d$y2
  expect_equal(unname(stats::cor(s, raw)), 1, tolerance = 1e-10)
})

# ---- score materialisation ---------------------------------------------------

test_that("PCA scores are oriented positively with the marker indicator", {
  d <- lk_data()
  d$y1 <- -d$y1 # marker now loads negatively on the common factor
  for (id in c("marker", "unit_variance")) {
    lat <- drm_latent("eta", c("y1", "y2", "y3"), identification = id, data = d)
    s <- drm_score_latent(lat, d)
    expect_gt(stats::cor(s, d$y1), 0)
  }
})

test_that("the stored-loading fallback scorer reproduces the cached-weight scorer", {
  d <- lk_data()
  cases <- list(
    drm_latent("m", c("y1", "y2", "y3"), identification = "marker", data = d),
    drm_latent("u", c("y1", "y2", "y3"), identification = "unit_variance", data = d),
    drm_latent("ms", c("y1", "y2", "y3"), standardize = TRUE, data = d),
    drm_latent("f", c("y1", "y2"), method = "fixed", weights = c(1, 2), data = d),
    drm_latent("fs", c("y1", "y2"), method = "fixed", weights = c(1, 2), standardize = TRUE, data = d)
  )
  for (spec in cases) {
    cached <- drm_score_latent(spec, d)
    legacy <- spec
    legacy$scoring_weights <- NULL
    legacy$scoring_intercept <- NULL
    fallback <- drm_score_latent(legacy, d)
    expect_equal(fallback, cached, tolerance = 1e-8, info = spec$name)
  }
})

test_that("drm_score_latent resolves an unresolved spec and reports missing indicators", {
  d <- lk_data()
  lat <- drm_latent("eta", c("y1", "y2", "y3"))
  s <- drm_score_latent(lat, d)
  expect_length(s, nrow(d))
  expect_equal(s, drm_score_latent(drm_latent("eta", c("y1", "y2", "y3"), data = d), d))
  resolved <- drm_latent("eta", c("y1", "y2", "y3"), data = d)
  expect_error(drm_score_latent(resolved, d[, c("y1", "y2")]), "missing from data")
})

# ---- construct lists ---------------------------------------------------------

test_that("drm_build_latent_constructs normalises, resolves, and validates", {
  d <- lk_data()
  expect_identical(drm_build_latent_constructs(NULL), list())
  one <- drm_latent("eta", c("y1", "y2"))
  out <- drm_build_latent_constructs(one, data = d)
  expect_length(out, 1L)
  expect_false(is.null(out[[1]]$loadings)) # resolved against the data
  expect_error(drm_build_latent_constructs("eta"), "must be a")
  expect_error(
    drm_build_latent_constructs(list(one, drm_latent("eta", c("y2", "y3")))),
    "must be unique"
  )
})

test_that("drm_apply_latents adds each construct score once and never overwrites a column", {
  d <- lk_data()
  lat <- drm_latent("eta", c("y1", "y2", "y3"), data = d)
  out <- drm_apply_latents(d, lat)
  expect_equal(out$eta, drm_score_latent(lat, d))
  d$eta <- 1
  expect_identical(drm_apply_latents(d, lat)$eta, rep(1, nrow(d)))
})

# ---- marginalised latents ----------------------------------------------------

test_that("drm_build_latents validates marginalised latent names", {
  v <- c("U", "x", "y")
  expect_identical(drm_build_latents(NULL, v), character(0))
  expect_identical(drm_build_latents("", v), character(0))
  expect_identical(drm_build_latents("U", v), "U")
  expect_error(drm_build_latents(c("U", "U"), v), "must be unique")
  expect_error(drm_build_latents("W", v), "not found in the structural graph")
})

test_that("drm_mag_compositionality_inform is silent unless the graphoid caveat applies", {
  rec <- function(family, comps) list(family = family, components = comps)
  none <- list(latents = character(0), endogenous = "y", records = list(y = rec("poisson", "mu")))
  expect_silent(drm_mag_compositionality_inform(none))

  gauss <- list(latents = "U", endogenous = "y", records = list(y = rec("gaussian", "mu")))
  expect_silent(drm_mag_compositionality_inform(gauss))

  nongauss <- list(latents = "U", endogenous = "y", records = list(y = rec("poisson", "mu")))
  expect_message(drm_mag_compositionality_inform(nongauss), "compositional graphoid")

  scale_path <- list(
    latents = "U", endogenous = "y",
    records = list(y = rec("gaussian", c("mu", "sigma")))
  )
  expect_message(drm_mag_compositionality_inform(scale_path), "sigma")
})
