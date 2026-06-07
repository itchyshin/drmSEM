# LIVE-FIT recovery for the remaining structural machinery on REAL drmTMB fits:
# standardization (incl. the sigma_E latent term), composites, feedback
# equilibrium effects, and natural (cross-world) effects.
#
# These complement the engine-free pins in test-standardize.R (V-44),
# test-composite.R, test-feedback.R (V-42/V-43) and test-analytic-effects.R
# (V-26..V-40) by closing the loop end-to-end on a fitted model. Every assertion
# is robust-by-construction: it compares a PUBLIC output against quantities
# recomputed from the SAME fitted coefficients (paths() / drm_fit_coef /
# drm_fixed_design) or against simulated ground truth -- never a hand formula
# with an uncertain parameterization. Node-wise ML is biased under feedback, so
# the feedback check asserts against the FITTED B/Gamma, not the DGP ones.
#
# V-number -> test map (this file owns the V-65..V-72 block):
#   V-65  standardize(latent) on a LIVE logit GLM == b*sd(x)/sqrt(Var(eta)+pi^2/3)
#   V-66  standardize(latent) on a LIVE Gaussian identity node == sd_x / sd(eta)
#   V-67  composite used as BOTH predictor and response fits; loadings + effect ok
#   V-68  Cronbach alpha on a live composite matches drm_cronbach_alpha closed form
#   V-69  feedback total_effects(equilibrium) == fitted ((I-B)^-1 Gamma) entry
#   V-70  a divergent declared system (rho(B) >= 1) reports NA, not a number
#   V-71  natural effects: NDE+NIE+mediated_interaction sum to total_path (finite)
#   V-72  adding an x:M interaction pushes mediated_interaction off zero

skip_if_not_installed("drmTMB")

# Recompute one component's fitted linear-predictor SD exactly as standardize()
# does: eta = X %*% b over the model data, using the package's own extractors so
# the design construction is byte-identical to the production path.
fitted_eta <- function(sem, node, component) {
  rec <- sem$records[[node]]
  X <- drmSEM:::drm_fixed_design(rec$fit, component, as.data.frame(sem$data))
  b <- drmSEM:::drm_fit_coef(rec$fit, component)
  as.numeric(X %*% b[colnames(X)])
}

pick_std <- function(s, term) s$std.estimate[match(term, s$term)]

# ---------------------------------------------------------------------------
# 1. STANDARDIZATION on a LIVE fit (the OQ-4 sigma_E pipeline, end-to-end).
# ---------------------------------------------------------------------------

test_that("V-65: latent standardization of a live logit GLM uses sqrt(Var(eta)+pi^2/3)", {
  set.seed(60)
  n <- 2000
  x <- stats::rnorm(n)
  eta_true <- -0.3 + 1.1 * x
  y <- stats::rbinom(n, 1, stats::plogis(eta_true))
  dat <- data.frame(x = x, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x), family = stats::binomial()),
    data = dat
  )

  # b_fitted comes from the FITTED coefficients, not the DGP value.
  p <- paths(sem)
  b_fitted <- p$estimate[p$from == "x" & p$to == "y" & p$component == "mu"]
  expect_equal(p$link[p$from == "x" & p$to == "y"], "logit")

  eta <- fitted_eta(sem, "y", "mu")
  divisor <- sqrt(stats::var(eta) + pi^2 / 3)         # the sigma_E latent divisor

  s <- standardize(sem, "latent")
  expect_equal(pick_std(s, "x"), b_fitted * stats::sd(dat$x) / divisor,
               tolerance = 1e-8)

  # the sigma_E inflation strictly shrinks the standardized coefficient relative
  # to the old sd(eta)-only divisor (live confirmation of the OQ-4 correction).
  expect_lt(pick_std(s, "x"), b_fitted * stats::sd(dat$x) / stats::sd(eta))
})

test_that("V-66: latent standardization of a live Gaussian identity node is sd_x / sd(eta)", {
  set.seed(61)
  n <- 2000
  x <- stats::rnorm(n)
  y <- stats::rnorm(n, 0.2 + 0.8 * x, 1)
  dat <- data.frame(x = x, y = y)

  sem <- drm_sem(
    y = drm_node(drmTMB::bf(y ~ x), family = stats::gaussian()),
    data = dat
  )

  p <- paths(sem)
  b_fitted <- p$estimate[p$from == "x" & p$to == "y" & p$component == "mu"]
  expect_equal(p$link[p$from == "x" & p$to == "y"], "identity")

  eta <- fitted_eta(sem, "y", "mu")
  s <- standardize(sem, "latent")

  # identity carries NO sigma_E term: divisor is exactly sd(eta).
  expect_equal(pick_std(s, "x"), b_fitted * stats::sd(dat$x) / stats::sd(eta),
               tolerance = 1e-8)
  # single-predictor identity mean path => |latent| == 1 (sign of b).
  expect_equal(abs(pick_std(s, "x")), 1, tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# 2. COMPOSITE end-to-end: construct used BOTH as a predictor and as a response.
# ---------------------------------------------------------------------------

test_that("V-67: a formative composite fits as both predictor and response; effects flow", {
  set.seed(62)
  n <- 1500
  z <- stats::rnorm(n)                              # latent construct
  dat <- data.frame(
    i1 = z + stats::rnorm(n, sd = 0.4),
    i2 = z + stats::rnorm(n, sd = 0.4),
    i3 = z + stats::rnorm(n, sd = 0.4),
    x  = stats::rnorm(n)
  )
  dat$z_true <- z
  dat$y <- 0.5 * z + 0.3 * dat$x + stats::rnorm(n)

  # "size" is driven BY x (construct-as-response) AND drives y (construct-as-
  # predictor) in the same SEM: x -> size -> y.
  sem <- drm_sem(
    size = drm_node(drmTMB::bf(size ~ x), family = stats::gaussian()),
    y    = drm_node(drmTMB::bf(y ~ size + x), family = stats::gaussian()),
    data = dat,
    composites = drm_composite("size", c("i1", "i2", "i3"),
                               method = "pca", data = dat)
  )

  expect_s3_class(sem, "drm_sem")
  expect_true("size" %in% names(sem$data))           # materialized before fitting

  # loadings() reports exactly the three indicators.
  expect_equal(sort(loadings(sem)$indicator), c("i1", "i2", "i3"))

  # the construct appears on both ends of the path table.
  p <- paths(sem)
  expect_true(any(p$from == "x" & p$to == "size"))
  expect_true(any(p$from == "size" & p$to == "y"))

  # an effect THROUGH the composite (x -> size -> y) is finite and non-trivial.
  ie <- indirect_effects(sem, from = "x", to = "y", through = "size",
                         uncertainty = "none")
  mm <- ie$estimate[ie$quantity == "mean_mediated"]
  tp <- ie$estimate[ie$quantity == "total_path"]
  expect_true(is.finite(mm) && is.finite(tp))
  expect_gt(abs(mm), 0)                              # the construct really mediates
})

test_that("V-68: Cronbach alpha on a live composite matches the closed form", {
  set.seed(63)
  n <- 1200
  z <- stats::rnorm(n)
  dat <- data.frame(
    a = z + stats::rnorm(n, sd = 0.5),
    b = z + stats::rnorm(n, sd = 0.5),
    cc = z + stats::rnorm(n, sd = 0.5)
  )
  spec <- drm_composite("idx", c("a", "b", "cc"), data = dat)

  # closed-form Cronbach alpha on the SAME indicator covariance matrix.
  M <- as.matrix(dat[, c("a", "b", "cc")])
  expect_equal(spec$reliability, drmSEM:::drm_cronbach_alpha(M), tolerance = 1e-10)
  # three positively-correlated indicators => a sensible (0,1) reliability.
  expect_gt(spec$reliability, 0)
  expect_lt(spec$reliability, 1)
})

# ---------------------------------------------------------------------------
# 3. FEEDBACK equilibrium on a LIVE fit.
# ---------------------------------------------------------------------------

# Build the fitted direct-effect matrix B (B[to, from] over the endogenous
# nodes) and the exogenous loading matrix Gamma from paths(), so the reduced
# form is computed from FITTED coefficients (node-wise ML is biased, so DGP B
# would not match -- the assertion must use the fitted B).
fitted_B_Gamma <- function(sem, endo, exo) {
  p <- paths(sem)
  p <- p[p$component == "mu", , drop = FALSE]
  k <- length(endo)
  B <- matrix(0, k, k, dimnames = list(endo, endo))
  Gamma <- matrix(0, k, length(exo), dimnames = list(endo, exo))
  for (i in seq_len(nrow(p))) {
    to <- p$to[[i]]; from <- p$from[[i]]; est <- p$estimate[[i]]
    if (to %in% endo && from %in% endo) B[to, from] <- est
    if (to %in% endo && from %in% exo) Gamma[to, from] <- est
  }
  list(B = B, Gamma = Gamma)
}

test_that("V-69: feedback equilibrium total effect matches the fitted reduced form", {
  set.seed(64)
  n <- 2000
  x <- stats::rnorm(n); zz <- stats::rnorm(n)
  # generate a stable reciprocal system y1 <-> y2 (true |b12*b21| < 1).
  e1 <- stats::rnorm(n); e2 <- stats::rnorm(n)
  a1 <- 0.5; a2 <- 0.4; b12 <- 0.3; b21 <- 0.25
  # solve the structural system for the realized data (reduced form per row)
  det <- 1 - b12 * b21
  y1 <- (a1 * x + b12 * (a2 * zz) + e1 + b12 * e2) / det
  y2 <- (a2 * zz + b21 * (a1 * x) + e2 + b21 * e1) / det
  dat <- data.frame(x, zz, y1, y2)

  suppressWarnings(
    sem <- drm_sem(
      y1 = drm_node(drmTMB::bf(y1 ~ x + y2), family = stats::gaussian()),
      y2 = drm_node(drmTMB::bf(y2 ~ zz + y1), family = stats::gaussian()),
      data = dat, feedback = drm_cycle("y1", "y2")
    )
  )
  expect_identical(nrow(cycles(sem)), 2L)

  endo <- c("y1", "y2"); exo <- c("x", "zz")
  bg <- fitted_B_Gamma(sem, endo, exo)
  # require a stable FITTED system for the comparison to be defined.
  rho <- drmSEM:::drm_spectral_radius(bg$B)
  skip_if(rho >= 1, "fitted feedback system is not stable; reduced form undefined")

  Tm <- solve(diag(2) - bg$B) %*% bg$Gamma     # fitted (I-B)^-1 Gamma

  # the equilibrium contrast scales the x-column of T by the contrast width
  # (mean +/- 0.5 sd => width = sd(x)); compare to total_effects(... y2).
  te <- total_effects(sem, from = "x", to = "y2", uncertainty = "none")
  expect_identical(te$mediation, "equilibrium")
  expect_true(is.finite(te$estimate))

  expected_y2 <- Tm["y2", "x"] * stats::sd(dat$x)
  expect_equal(te$estimate, expected_y2, tolerance = 0.05)

  # and the y1 target, for symmetry.
  te1 <- total_effects(sem, from = "x", to = "y1", uncertainty = "none")
  expect_equal(te1$estimate, Tm["y1", "x"] * stats::sd(dat$x), tolerance = 0.05)
})

test_that("V-70: a divergent declared system reports NA, never a fabricated number", {
  # rho(B) >= 1: no stable equilibrium. We cannot guarantee a *fitted* B diverges,
  # so exercise the equilibrium engine directly on hand engines with such a B
  # (mirrors the live total_effects() NA branch in R/effects.R). b12*b21 = 1.2 > 1.
  a1 <- 0.5; a2 <- 0.3; b12 <- 1.2; b21 <- 1.0
  lin_engine <- function(name, fn) {
    list(name = name, identifier = name, family = "gaussian",
         predict = function(scenario, beta = NULL) data.frame(mu = fn(scenario)))
  }
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  scen <- list(lo = data.frame(x = rep(0, 5)), hi = data.frame(x = rep(1, 5)),
               column = "x")
  eq <- drmSEM:::drm_equilibrium_contrast(eng, scen, "y1", B = 1L, draw = FALSE)
  expect_false(eq$converged)         # the honest "no equilibrium" signal
  # and the matching reduced-form guard flags the same B unstable.
  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  expect_false(attr(drmSEM:::drm_reduced_form(B, matrix(c(a1, a2), ncol = 1)),
                    "stable"))
})

# ---------------------------------------------------------------------------
# 4. NATURAL effects on an identified NONLINEAR case (log-link outcome).
# ---------------------------------------------------------------------------

test_that("V-71: natural effects sum to the total path on a nonlinear single-mediator DAG", {
  set.seed(66)
  n <- 2500
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.5 * x, 0.7)                # x -> M
  # log-link Poisson outcome: nonlinear in M, NO x:M interaction.
  y <- stats::rpois(n, exp(-0.2 + 0.4 * m))
  dat <- data.frame(x, m, y)

  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m), family = stats::poisson()),
    data = dat
  )

  ne <- indirect_effects(sem, from = "x", to = "y", effect = "natural",
                         uncertainty = "none", nsim = 400, seed = 7)
  nde <- ne$estimate[ne$quantity == "natural_direct"]
  nie <- ne$estimate[ne$quantity == "natural_indirect"]
  mi  <- ne$estimate[ne$quantity == "mediated_interaction"]
  tot <- ne$estimate[ne$quantity == "total_path"]

  expect_true(all(is.finite(c(nde, nie, mi, tot))))
  # the natural decomposition closes exactly (mediated_interaction is the
  # residual total - nde - nie, so this is an additive identity end-to-end).
  expect_equal(nde + nie + mi, tot, tolerance = 1e-6)

  # no x:M interaction in the DGP => mediated_interaction is ~0 and the indirect
  # channel carries the action (M genuinely mediates a log-link outcome).
  expect_equal(mi, 0, tolerance = 0.05)
  expect_gt(abs(nie), 0.02)
})

test_that("V-72: adding an x:M interaction moves mediated_interaction off zero", {
  set.seed(67)
  n <- 2500
  x <- stats::rnorm(n)
  m <- stats::rnorm(n, 0.5 * x, 0.7)
  # log-link mean WITH a positive x:M interaction term.
  d_int <- 0.5
  y <- stats::rpois(n, exp(-0.2 + 0.4 * m + d_int * x * m))
  dat <- data.frame(x, m, y)

  sem_int <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m + x:m), family = stats::poisson()),
    data = dat
  )
  ne_int <- indirect_effects(sem_int, from = "x", to = "y", effect = "natural",
                             uncertainty = "none", nsim = 400, seed = 8)
  mi_int  <- ne_int$estimate[ne_int$quantity == "mediated_interaction"]
  tot_int <- ne_int$estimate[ne_int$quantity == "total_path"]
  nde_int <- ne_int$estimate[ne_int$quantity == "natural_direct"]
  nie_int <- ne_int$estimate[ne_int$quantity == "natural_indirect"]

  # decomposition still closes exactly.
  expect_equal(nde_int + nie_int + mi_int, tot_int, tolerance = 1e-6)
  # a real x:M interaction makes mediated_interaction non-negligible. With a
  # positive interaction and a positive a*b channel, the mediated interaction is
  # positive (effect of x amplifies the mediator's pull on the outcome).
  expect_gt(mi_int, 0.02)
})
