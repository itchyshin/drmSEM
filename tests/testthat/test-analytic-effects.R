# 0.2 — Analytic effect cross-checks promoted to ASSERTED tests.
#
# These pin the effect engine against closed-form answers, with NO drmTMB: like
# test-effect-kernels.R, engines are hand-built plain lists with a `predict`
# closure (the inverse link is written into the closure, the `identifier` equals
# the downstream design column). Mean-channel contrasts are deterministic, so
# they are asserted at 1e-8; distribution-channel contrasts are Monte-Carlo and
# carry a seeded, derivation-justified tolerance. See docs/design/02-effect-calculus.md.

# Build a one-component ("mu") or two-component ("mu","sigma") Gaussian engine.
gauss_engine <- function(name, mu_fn, sigma_fn = NULL) {
  comps <- if (is.null(sigma_fn)) "mu" else c("mu", "sigma")
  list(
    name = name, identifier = name, family = "gaussian", components = comps,
    coef = list(), vcov = NULL,
    predict = function(scenario, beta = NULL) {
      out <- data.frame(mu = mu_fn(scenario))
      if (!is.null(sigma_fn)) out$sigma <- sigma_fn(scenario)
      out
    }
  )
}

# Deterministic mean-channel contrast (hi - lo) of the response mean of `to`.
mean_contrast <- function(eng, to, active, lo, hi, mediation = "mean", n_sim = 1L) {
  mean(drm_expected_target(eng, hi, to, active, mediation, NULL, n_sim) -
       drm_expected_target(eng, lo, to, active, mediation, NULL, n_sim))
}

rows <- function(df, n) df[rep(1, n), ]

# ---- Identity 1: Gaussian identity-link mean-mediated effect = a*b*w ---------

test_that("V-26a: Gaussian mean-mediated effect equals the bare product a*b*w", {
  a <- 0.4; b <- 0.6
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x),
    Y = gauss_engine("Y", function(s) b * s$M)
  )
  for (w in c(1, 1.3)) {
    lo <- rows(data.frame(x = 0, M = 0, Y = 0), 20)
    hi <- rows(data.frame(x = w, M = 0, Y = 0), 20)
    # no direct x -> Y edge, so the total through M is the mean-mediated effect
    expect_equal(mean_contrast(eng, "Y", "M", lo, hi), a * b * w, tolerance = 1e-8)
  }
})

test_that("V-26b: controlled-direct / mean-mediated split closes (Gaussian, direct edge)", {
  a <- 0.4; b <- 0.6; cc <- 0.3; w <- 1.0; m0 <- 0.5
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x),
    Y = gauss_engine("Y", function(s) cc * s$x + b * s$M)
  )
  # mediator held at a fixed constant m0 in both scenarios so the controlled
  # direct contrast isolates c*w (active = character(0) keeps the scenario M).
  lo <- rows(data.frame(x = 0, M = m0, Y = 0), 20)
  hi <- rows(data.frame(x = w, M = m0, Y = 0), 20)
  direct <- mean_contrast(eng, "Y", character(0), lo, hi)
  total  <- mean_contrast(eng, "Y", "M", lo, hi)
  expect_equal(direct, cc * w, tolerance = 1e-8)
  expect_equal(total, (cc + a * b) * w, tolerance = 1e-8)
  expect_equal(total - direct, a * b * w, tolerance = 1e-8)
})

test_that("V-26c: two parallel mediators sum to a1*b1 + a2*b2", {
  a1 <- 0.5; a2 <- -0.3; b1 <- 0.4; b2 <- 0.7; w <- 1.0
  eng <- list(
    M1 = gauss_engine("M1", function(s) a1 * s$x),
    M2 = gauss_engine("M2", function(s) a2 * s$x),
    Y  = gauss_engine("Y",  function(s) b1 * s$M1 + b2 * s$M2)
  )
  lo <- rows(data.frame(x = 0, M1 = 0, M2 = 0, Y = 0), 20)
  hi <- rows(data.frame(x = w, M1 = 0, M2 = 0, Y = 0), 20)
  total <- mean_contrast(eng, "Y", c("M1", "M2"), lo, hi)
  expect_equal(total, (a1 * b1 + a2 * b2) * w, tolerance = 1e-8)
})

# ---- Identity 2: a non-mean (sigma) path is invisible to the mean channel ----

test_that("V-27a: a sigma path contributes EXACTLY nothing to the mean channel", {
  a <- 0.4; b <- 0.6
  mk <- function(s1) list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(-0.2 + s1 * s$x)),
    Y = gauss_engine("Y", function(s) b * s$M)
  )
  lo <- rows(data.frame(x = 0, M = 0, Y = 0), 20)
  hi <- rows(data.frame(x = 1, M = 0, Y = 0), 20)
  # the mean channel never reads sigma, so the two are bit-identical
  base  <- drm_expected_target(mk(0),   hi, "Y", "M", "mean", NULL, 1)
  withs <- drm_expected_target(mk(0.9), hi, "Y", "M", "mean", NULL, 1)
  expect_identical(base, withs)
})

test_that("V-27b: distribution-mediated effect -> 0 when the outcome is linear in M", {
  skip_on_cran()
  set.seed(11)
  a <- 0.4; b <- 0.6
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(-0.2 + 0.9 * s$x)),
    Y = gauss_engine("Y", function(s) b * s$M)   # linear: E[Y]=b*E[M], sigma irrelevant
  )
  lo <- rows(data.frame(x = 0, M = 0, Y = 0), 200)
  hi <- rows(data.frame(x = 1, M = 0, Y = 0), 200)
  dist <- mean_contrast(eng, "Y", "M", lo, hi, mediation = "distribution", n_sim = 2000)
  mean <- mean_contrast(eng, "Y", "M", lo, hi, mediation = "mean", n_sim = 1)
  # statistical (not algebraic) zero: the distribution-mediated part is dist-mean
  expect_equal(dist, mean, tolerance = 0.02)
})

# ---- Identity 3: distribution-mediated effect across a downstream nonlinearity

test_that("V-28: distribution-mediated effect matches the lognormal closed form and flips sign", {
  skip_on_cran()
  set.seed(7)
  a <- 0.4; k <- 0.5; s0 <- -0.2; x0 <- 0; x1 <- 1
  mk <- function(s1) list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(s0 + s1 * s$x)),
    Y = gauss_engine("Y", function(s) exp(k * s$M))     # downstream nonlinearity
  )
  lo <- rows(data.frame(x = x0, M = 0, Y = 0), 120)
  hi <- rows(data.frame(x = x1, M = 0, Y = 0), 120)
  dist_mediated <- function(s1, n_sim) {
    eng <- mk(s1)
    d <- mean_contrast(eng, "Y", "M", lo, hi, mediation = "distribution", n_sim = n_sim)
    m <- mean_contrast(eng, "Y", "M", lo, hi, mediation = "mean", n_sim = 1)
    d - m
  }
  # closed form via the lognormal MGF E[exp(kM)] = exp(k*mu + 0.5 k^2 sigma^2)
  sig <- function(x, s1) exp(s0 + s1 * x)
  D <- function(s1) {
    (exp(k * a * x1 + 0.5 * k^2 * sig(x1, s1)^2) - exp(k * a * x1)) -
      (exp(k * a * x0 + 0.5 * k^2 * sig(x0, s1)^2) - exp(k * a * x0))
  }
  dm_pos <- dist_mediated(0.9, 2000)
  expect_equal(dm_pos, D(0.9), tolerance = 0.06)
  expect_gt(dm_pos, 0)
  expect_lt(dist_mediated(-0.9, 2000), 0)   # sign flips with the sigma slope
})

# ---- Identity 4: natural vs controlled under an exposure-mediator interaction

test_that("V-29: natural and controlled effects diverge under an x:M interaction", {
  a <- 0.5; b <- 0.6; cc <- 0.3; d <- 0.4
  x0 <- 0.3; x1 <- 1.0; m0 <- 0.2; w <- x1 - x0
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x),
    Y = gauss_engine("Y", function(s) cc * s$x + b * s$M + d * (s$x * s$M))
  )
  lo <- rows(data.frame(x = x0, M = m0, Y = 0), 30)
  hi <- rows(data.frame(x = x1, M = m0, Y = 0), 30)
  scen <- list(lo = lo, hi = hi, column = "x")
  ne <- drm_natural_target(eng, scen, "x", "Y", active = "M",
                           mediation = "mean", beta_list = NULL)
  expect_equal(unname(ne["nde"]), w * (cc + d * a * x0), tolerance = 1e-8)
  expect_equal(unname(ne["nie"]), a * w * (b + d * x0), tolerance = 1e-8)
  med_int <- unname(ne["total"] - ne["nde"] - ne["nie"])
  expect_equal(med_int, d * a * w^2, tolerance = 1e-8)
  # controlled direct holds M at the observed m0 (!= a*x0), so CDE != NDE
  cde <- mean_contrast(eng, "Y", character(0), lo, hi)
  expect_equal(cde, w * (cc + d * m0), tolerance = 1e-8)
  expect_false(isTRUE(all.equal(unname(ne["nde"]), cde)))
})

# ---- Identity 5: outcome functionals ----------------------------------------

test_that("V-30a: Poisson Pr(Y>0) effect equals exp(-mu_lo) - exp(-mu_hi)", {
  skip_on_cran()
  set.seed(3)
  mu_lo <- 2; mu_hi <- 0.5
  eng <- list(
    Y = list(name = "Y", identifier = "Y", family = "poisson", components = "mu",
             coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = mu_lo + (mu_hi - mu_lo) * scenario$x))
  )
  lo <- rows(data.frame(x = 0, Y = 0), 4000)
  hi <- rows(data.frame(x = 1, Y = 0), 4000)
  scen <- list(lo = lo, hi = hi, column = "x")
  v <- drm_functional_contrast(eng, scen, "Y", active = character(0),
                               mediation = "distribution", target = "p_gt",
                               threshold = 0, B = 1, n_sim = 20, draw = FALSE)
  # Pr(Y>0) = 1 - exp(-mu); the contrast is the negative of the p_zero effect
  expect_equal(unname(v), exp(-mu_lo) - exp(-mu_hi), tolerance = 0.03)
})

test_that("V-30b: a pure-sigma path moves Var(Y) on the closed form, with zero mean effect", {
  skip_on_cran()
  set.seed(5)
  b <- 0.5; s0 <- -0.1; s1 <- 0.7; x0 <- 0; x1 <- 1
  eng_var <- list(
    Y = gauss_engine("Y", function(s) b * s$x, function(s) exp(s0 + s1 * s$x))
  )
  lo <- rows(data.frame(x = x0, Y = 0), 4000)
  hi <- rows(data.frame(x = x1, Y = 0), 4000)
  scen <- list(lo = lo, hi = hi, column = "x")
  vv <- drm_functional_contrast(eng_var, scen, "Y", active = character(0),
                                mediation = "distribution", target = "var",
                                threshold = 0, B = 1, n_sim = 40, draw = FALSE)
  expect_equal(unname(vv), exp(2 * (s0 + s1 * x1)) - exp(2 * (s0 + s1 * x0)),
               tolerance = 0.15)

  # constant sigma -> Var(Y) does not move with x (zero, in expectation)
  eng_const <- list(Y = gauss_engine("Y", function(s) b * s$x, function(s) exp(s0)))
  v0 <- drm_functional_contrast(eng_const, scen, "Y", active = character(0),
                                mediation = "distribution", target = "var",
                                threshold = 0, B = 1, n_sim = 40, draw = FALSE)
  expect_equal(unname(v0), 0, tolerance = 0.1)
})

# ---- The pure-R link table (drm_nominal_link) -------------------------------

test_that("drm_nominal_link labels each (family, component) correctly", {
  expect_equal(drm_nominal_link("gaussian", "mu"), "identity")
  expect_equal(drm_nominal_link("lognormal", "mu"), "identity")
  expect_equal(drm_nominal_link("gaussian", "sigma"), "log")
  expect_equal(drm_nominal_link("poisson", "mu"), "log")
  expect_equal(drm_nominal_link("nbinom2", "mu"), "log")
  expect_equal(drm_nominal_link("binomial", "mu"), "logit")
  expect_equal(drm_nominal_link("beta", "mu"), "logit")
  expect_equal(drm_nominal_link("anything", "zi"), "logit")
  expect_equal(drm_nominal_link("anything", "hu"), "logit")
  expect_equal(drm_nominal_link("anything", "nu"), "log")
  expect_equal(drm_nominal_link("anything", "rho12"), "tanh")
  expect_equal(drm_nominal_link("anything", "sd_site"), "log")
})

# ---- Identity 6: the SHIPPED decomposition path (drm_decomp_legs) ------------
#
# V-26..V-30 above validate the effect KERNELS. These pin the production helper
# `drm_decomp_legs()` that indirect_effects() actually calls (R/effects.R), so a
# refactor of the three legs, the pairing, or the mean/distribution labelling
# would fail here -- not only the kernels. Engines are hand-built (no drmTMB).

# Reconstruct the decomposition exactly as indirect_effects() does from the
# shipped, shared-coefficient-draw helper.
decomp <- function(eng, to, active, lo, hi, n_sim, seed = 7L) {
  scen <- list(lo = lo, hi = hi, column = "x")
  legs <- drmSEM:::drm_decomp_legs(eng, scen, to, active, B = 1L, n_sim = n_sim,
                                   draw = FALSE, seed = seed)
  cde <- legs[, "cde"]; tm <- legs[, "tot_mean"]; td <- legs[, "tot_dist"]
  list(direct = mean(cde),
       indirect = mean(td - cde),
       mean_mediated = mean(tm - cde),
       distribution_mediated = mean(td - tm))
}

test_that("V-36: production decomposition closes (indirect == mean + distribution)", {
  a <- 0.4; k <- 0.5
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(-0.2 + 0.9 * s$x)),
    Y = gauss_engine("Y", function(s) exp(k * s$M))
  )
  lo <- rows(data.frame(x = 0, M = 0, Y = 0), 80)
  hi <- rows(data.frame(x = 1, M = 0, Y = 0), 80)
  d <- decomp(eng, "Y", "M", lo, hi, n_sim = 1500, seed = 7L)
  # exact by construction on the shared legs: a broken leg/label fails this
  expect_equal(d$indirect, d$mean_mediated + d$distribution_mediated,
               tolerance = 1e-12)
  expect_equal(d$direct + d$indirect,
               d$direct + d$mean_mediated + d$distribution_mediated,
               tolerance = 1e-12)
})

test_that("V-37: production distribution_mediated matches the lognormal Jensen gap", {
  a <- 0.4; k <- 0.5; s0 <- -0.2; x0 <- 0; x1 <- 1
  mk <- function(s1) list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(s0 + s1 * s$x)),
    Y = gauss_engine("Y", function(s) exp(k * s$M))
  )
  lo <- rows(data.frame(x = x0, M = 0, Y = 0), 80)
  hi <- rows(data.frame(x = x1, M = 0, Y = 0), 80)
  sig <- function(x, s1) exp(s0 + s1 * x)
  D <- function(s1)
    (exp(k * a * x1 + 0.5 * k^2 * sig(x1, s1)^2) - exp(k * a * x1)) -
    (exp(k * a * x0 + 0.5 * k^2 * sig(x0, s1)^2) - exp(k * a * x0))
  dp <- decomp(mk(0.9), "Y", "M", lo, hi, n_sim = 4000, seed = 7L)$distribution_mediated
  expect_equal(dp, D(0.9), tolerance = 0.06)
  expect_gt(dp, 0)
  # sign flip when the mediator's scale DECREASES with x, through the production path
  dn <- decomp(mk(-0.9), "Y", "M", lo, hi, n_sim = 4000, seed = 7L)$distribution_mediated
  expect_lt(dn, 0)
})

test_that("V-38: production distribution_mediated is ~0 when the outcome is linear in M", {
  a <- 0.4; b <- 0.6
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(-0.2 + 0.9 * s$x)),
    Y = gauss_engine("Y", function(s) b * s$M)   # linear: no Jensen gap
  )
  lo <- rows(data.frame(x = 0, M = 0, Y = 0), 150)
  hi <- rows(data.frame(x = 1, M = 0, Y = 0), 150)
  d <- decomp(eng, "Y", "M", lo, hi, n_sim = 4000, seed = 11L)
  expect_equal(d$distribution_mediated, 0, tolerance = 0.02)
  expect_equal(d$mean_mediated, a * b, tolerance = 1e-8)
})

test_that("V-39: production mean_mediated recovers a chain a*c*b through 2 mediators", {
  a <- 0.5; cc <- 0.8; b <- 0.6   # x -> M1 -> M2 -> Y, all linear Gaussian
  eng <- list(
    M1 = gauss_engine("M1", function(s) a  * s$x),
    M2 = gauss_engine("M2", function(s) cc * s$M1),
    Y  = gauss_engine("Y",  function(s) b  * s$M2)
  )
  lo <- rows(data.frame(x = 0, M1 = 0, M2 = 0, Y = 0), 40)
  hi <- rows(data.frame(x = 1, M1 = 0, M2 = 0, Y = 0), 40)
  d <- decomp(eng, "Y", c("M1", "M2"), lo, hi, n_sim = 800, seed = 5L)
  expect_equal(d$mean_mediated, a * cc * b, tolerance = 1e-8)
  expect_equal(d$distribution_mediated, 0, tolerance = 0.02)
})

test_that("V-40: the decomposition is reproducible (seed plumbing through the legs)", {
  a <- 0.4; k <- 0.5
  eng <- list(
    M = gauss_engine("M", function(s) a * s$x, function(s) exp(-0.2 + 0.9 * s$x)),
    Y = gauss_engine("Y", function(s) exp(k * s$M))
  )
  scen <- list(lo = rows(data.frame(x = 0, M = 0, Y = 0), 60),
               hi = rows(data.frame(x = 1, M = 0, Y = 0), 60), column = "x")
  d1 <- drmSEM:::drm_decomp_legs(eng, scen, "Y", "M", 1L, 200, FALSE, seed = 3L)
  d2 <- drmSEM:::drm_decomp_legs(eng, scen, "Y", "M", 1L, 200, FALSE, seed = 3L)
  # same seed -> identical legs: guards the shared-draw / seed wiring
  expect_identical(d1, d2)
})
