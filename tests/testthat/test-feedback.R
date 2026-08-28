# 0.5.0 — cyclic/feedback graphs. The declaration grammar, the relaxed
# topological sort, the basis-set suppression, and the fixed-point equilibrium
# propagator are pure-R, so they are tested here without drmTMB. The closed-form
# recovery checks the simulated equilibrium against (I - B)^{-1} Gamma.

# ---- drm_cycle(): the declaration primitive ---------------------------------

test_that("drm_cycle records a motif of distinct node names", {
  cy <- drm_cycle("activity", "boldness")
  expect_s3_class(cy, "drm_cycle")
  expect_identical(cy$nodes, c("activity", "boldness"))
  # duplicates collapse; order preserved
  expect_identical(drm_cycle("a", "b", "a")$nodes, c("a", "b"))
})

test_that("drm_cycle rejects malformed declarations", {
  expect_error(drm_cycle("a"), "at least two")
  expect_error(drm_cycle(), "node names")
  expect_error(drm_cycle("a", 1), "node names")
  expect_error(drm_cycle("a", c("b", "c")), "node names")
})

# ---- drm_build_feedback(): validation against node records ------------------

records3 <- list(
  y1 = list(identifiers = c("y1")),
  y2 = list(identifiers = c("y2")),
  y3 = list(identifiers = c("y3"))
)

test_that("drm_build_feedback resolves nodes and builds the motif table", {
  expect_identical(nrow(drmSEM:::drm_build_feedback(NULL, records3)), 0L)

  fb <- drmSEM:::drm_build_feedback(drm_cycle("y1", "y2"), records3)
  expect_identical(nrow(fb), 2L)
  expect_setequal(fb$node, c("y1", "y2"))
  expect_identical(unique(fb$motif), 1L)

  two <- drmSEM:::drm_build_feedback(
    list(drm_cycle("y1", "y2"), drm_cycle("y2", "y3")),
    records3
  )
  expect_identical(length(unique(two$motif)), 2L)
})

test_that("drm_build_feedback errors on unknown nodes and bad input", {
  expect_error(
    drmSEM:::drm_build_feedback(drm_cycle("y1", "ghost"), records3),
    "not a node"
  )
  expect_error(
    drmSEM:::drm_build_feedback(covary("y1", "y2"), records3),
    "drm_cycle"
  )
})

# ---- relaxed topological sort -----------------------------------------------

# y1 <-> y2 reciprocal pair, plus y2 -> y3 downstream.
fb_edges <- data.frame(
  from = c("y1", "y2", "y2"),
  to = c("y2", "y1", "y3"),
  stringsAsFactors = FALSE
)

test_that("drm_toposort_feedback accepts a declared motif and orders the rest", {
  topo <- drmSEM:::drm_toposort_feedback(
    c("y1", "y2", "y3"),
    fb_edges,
    list(c("y1", "y2"))
  )
  expect_true(topo$acyclic)
  # the motif members are contiguous and y3 (downstream) comes last
  expect_identical(topo$order[[3L]], "y3")
  expect_setequal(topo$order[1:2], c("y1", "y2"))
})

test_that("drm_toposort_feedback still rejects an UNdeclared cycle", {
  topo <- drmSEM:::drm_toposort_feedback(c("y1", "y2", "y3"), fb_edges, list())
  expect_false(topo$acyclic)
})

# ---- basis-set suppression among motif nodes --------------------------------

# x -> y1, x -> y2 (siblings): without feedback the basis set claims y1 _||_ y2.
make_fb_sibling <- function(fb = NULL) {
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
      covariances = NULL,
      feedback = fb
    ),
    class = "drm_sem"
  )
}

test_that("a declared feedback motif drops the y1 _||_ y2 independence claim", {
  bs_plain <- basis_set(make_fb_sibling(NULL))
  expect_true(any(bs_plain$x == "y1" & bs_plain$y == "y2"))

  fb <- data.frame(
    motif = c(1L, 1L),
    node = c("y1", "y2"),
    stringsAsFactors = FALSE
  )
  bs_fb <- basis_set(make_fb_sibling(fb))
  expect_false(any(
    (bs_fb$x == "y1" & bs_fb$y == "y2") |
      (bs_fb$x == "y2" & bs_fb$y == "y1")
  ))
})

# ---- spectral radius and the linear reduced form ----------------------------

test_that("drm_spectral_radius and drm_reduced_form match the closed form", {
  B <- matrix(c(0, 0.2, 0.4, 0), nrow = 2) # b12 = 0.4 (row1,col2), b21 = 0.2
  Gamma <- matrix(c(0.5, 0.3), ncol = 1)
  rho <- drmSEM:::drm_spectral_radius(B)
  expect_equal(rho, sqrt(0.4 * 0.2), tolerance = 1e-12)

  Tm <- drmSEM:::drm_reduced_form(B, Gamma)
  expect_true(attr(Tm, "stable"))
  expect_equal(
    as.numeric(Tm),
    as.numeric(solve(diag(2) - B) %*% Gamma),
    tolerance = 1e-12
  )

  # rho(B) >= 1 is flagged unstable
  Bun <- matrix(c(0, 1.0, 1.2, 0), nrow = 2)
  expect_false(attr(drmSEM:::drm_reduced_form(Bun, Gamma), "stable"))
})

# ---- fixed-point equilibrium propagation ------------------------------------

lin_engine <- function(name, fn) {
  list(
    name = name,
    identifier = name,
    family = "gaussian",
    predict = function(scenario, beta = NULL) data.frame(mu = fn(scenario))
  )
}

test_that("V-42: propagate_fixedpoint recovers the linear 2-cycle equilibrium (I-B)^-1 Gamma", {
  a1 <- 0.5
  a2 <- 0.3
  b12 <- 0.4
  b21 <- 0.2
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  scen <- data.frame(x = rep(1, 6))
  res <- drmSEM:::propagate_fixedpoint(
    eng,
    scen,
    active = c("y1", "y2"),
    max_iter = 500L,
    tol = 1e-12
  )
  expect_true(res$converged)

  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  Gamma <- matrix(c(a1, a2), ncol = 1)
  eq <- as.numeric(solve(diag(2) - B) %*% Gamma) # equilibrium at x = 1
  expect_equal(mean(res$mean$y1), eq[[1L]], tolerance = 1e-8)
  expect_equal(mean(res$mean$y2), eq[[2L]], tolerance = 1e-8)
})

test_that("propagate_fixedpoint reports non-convergence when rho(B) >= 1", {
  a1 <- 0.5
  a2 <- 0.3
  b12 <- 1.2
  b21 <- 1.0 # spectral radius > 1: diverges
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  scen <- data.frame(x = rep(1, 4))
  res <- drmSEM:::propagate_fixedpoint(
    eng,
    scen,
    active = c("y1", "y2"),
    max_iter = 200L,
    tol = 1e-10
  )
  expect_false(res$converged)
})

test_that("V-43: drm_equilibrium_contrast recovers the reduced-form total effect of x", {
  a1 <- 0.5
  a2 <- 0.3
  b12 <- 0.4
  b21 <- 0.2
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  # contrast x: 0 -> 1, so the equilibrium contrast equals T[, 1] (one unit of x)
  scen <- list(
    lo = data.frame(x = rep(0, 5)),
    hi = data.frame(x = rep(1, 5)),
    column = "x"
  )
  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  Gamma <- matrix(c(a1, a2), ncol = 1)
  Tm <- as.numeric(solve(diag(2) - B) %*% Gamma) # total-effect column for x

  eq1 <- drmSEM:::drm_equilibrium_contrast(
    eng,
    scen,
    "y1",
    B = 1L,
    draw = FALSE
  )
  expect_true(eq1$converged)
  expect_equal(mean(eq1$vals), Tm[[1L]], tolerance = 1e-8)

  eq2 <- drmSEM:::drm_equilibrium_contrast(
    eng,
    scen,
    "y2",
    B = 1L,
    draw = FALSE
  )
  expect_equal(mean(eq2$vals), Tm[[2L]], tolerance = 1e-8)

  # a diverging system is flagged non-convergent (effect undefined, not a number)
  engd <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + 1.2 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + 1.0 * s$y1)
  )
  expect_false(
    drmSEM:::drm_equilibrium_contrast(
      engd,
      scen,
      "y1",
      B = 1L,
      draw = FALSE
    )$converged
  )
})

test_that("V-73: propagate_fixedpoint solves a NONLINEAR feedback fixed point", {
  # A nonlinear reciprocal pair (saturating coupling), a contraction so a unique
  # stable equilibrium exists. There is no closed form, so the known answer is the
  # fixed-point PROPERTY: at convergence, re-applying the structural map must
  # reproduce the values (self-consistency), and an independent fixed-point solve
  # must agree.
  a1 <- 0.6
  a2 <- -0.4
  b12 <- 0.5
  b21 <- 0.3
  f1 <- function(x, y2) a1 * x + b12 * tanh(y2)
  f2 <- function(x, y1) a2 * x + b21 * tanh(y1)
  eng <- list(
    y1 = lin_engine("y1", function(s) f1(s$x, s$y2)),
    y2 = lin_engine("y2", function(s) f2(s$x, s$y1))
  )
  xval <- 0.8
  scen <- data.frame(x = rep(xval, 5))
  res <- drmSEM:::propagate_fixedpoint(
    eng,
    scen,
    active = c("y1", "y2"),
    max_iter = 1000L,
    tol = 1e-12
  )
  expect_true(res$converged)
  y1s <- mean(res$mean$y1)
  y2s <- mean(res$mean$y2)

  # self-consistency: the converged values satisfy the structural equations
  expect_equal(y1s, f1(xval, y2s), tolerance = 1e-8)
  expect_equal(y2s, f2(xval, y1s), tolerance = 1e-8)

  # independent solve (plain Gauss-Seidel reference) reaches the same fixed point
  z1 <- 0
  z2 <- 0
  for (i in seq_len(1000L)) {
    z1 <- f1(xval, z2)
    z2 <- f2(xval, z1)
  }
  expect_equal(y1s, z1, tolerance = 1e-8)
  expect_equal(y2s, z2, tolerance = 1e-8)
})

# ---- cycles() accessor ------------------------------------------------------

test_that("cycles() reports the declared motifs of a drm_sem", {
  fb <- data.frame(
    motif = c(1L, 1L),
    node = c("y1", "y2"),
    stringsAsFactors = FALSE
  )
  obj <- structure(list(feedback = fb), class = "drm_sem")
  cy <- cycles(obj)
  expect_s3_class(cy, "drm_cycles")
  expect_setequal(cy$node, c("y1", "y2"))

  # an object without the slot yields an empty (not error) table
  expect_identical(nrow(cycles(structure(list(), class = "drm_sem"))), 0L)
})

# ---- end-to-end wiring through drm_sem() (needs the engine) ------------------

test_that("drm_sem(feedback=) builds a cyclic SEM, lists it, warns, and guards effects", {
  skip_if_not_installed("drmTMB")
  set.seed(3)
  n <- 300
  x <- stats::rnorm(n)
  z <- stats::rnorm(n)
  y1 <- 0.5 * x + stats::rnorm(n)
  y2 <- 0.4 * z + 0.3 * y1 + stats::rnorm(n)
  y1 <- y1 + 0.2 * y2 # mutual dependence -> a declared y1 <-> y2 cycle
  dat <- data.frame(x, z, y1, y2)

  # the declared motif relaxes the DAG check but warns about simultaneity bias
  expect_warning(
    sem <- drm_sem(
      y1 = drm_node(drmTMB::bf(y1 ~ x + y2), family = stats::gaussian()),
      y2 = drm_node(drmTMB::bf(y2 ~ z + y1), family = stats::gaussian()),
      data = dat,
      feedback = drm_cycle("y1", "y2")
    ),
    "simultaneity"
  )
  expect_identical(nrow(cycles(sem)), 2L)
  # total_effects routes through the equilibrium propagator for a feedback SEM
  te <- total_effects(sem, from = "x", to = "y2", uncertainty = "none")
  expect_identical(te$mediation, "equilibrium")
  expect_true(is.finite(te$estimate)) # this system is stable
  # the mean/distribution DECOMPOSITION through a cycle is refused
  expect_error(indirect_effects(sem, from = "x", to = "y2"), "feedback motif")
  # an UNdeclared reciprocal pair is still a hard error
  expect_error(
    drm_sem(
      y1 = drm_node(drmTMB::bf(y1 ~ x + y2), family = stats::gaussian()),
      y2 = drm_node(drmTMB::bf(y2 ~ z + y1), family = stats::gaussian()),
      data = dat
    ),
    "cycle"
  )
})

# ---- V-135..V-138: Multi-component & Distributional Feedback Equilibria -------

test_that("V-135: linear 2-node reciprocal feedback matches theoretical (I-B)^-1 Gamma and diagnostics", {
  # Linear Gaussian system:
  # y1 = a1 * x + b12 * y2
  # y2 = a2 * x + b21 * y1
  a1 <- 0.8
  a2 <- 0.5
  b12 <- 0.35
  b21 <- 0.40
  eng <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a1, y2 = b12)),
      predict = function(s, beta = NULL) data.frame(mu = a1 * s$x + b12 * s$y2)
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a2, y1 = b21)),
      predict = function(s, beta = NULL) data.frame(mu = a2 * s$x + b21 * s$y1)
    )
  )
  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  Gamma <- matrix(c(a1, a2), ncol = 1)
  rho_true <- sqrt(b12 * b21)
  Tm_true <- as.numeric(solve(diag(2) - B) %*% Gamma)

  scen <- data.frame(x = rep(1.5, 10))
  res <- drmSEM:::propagate_fixedpoint(
    eng,
    scen,
    active = c("y1", "y2"),
    max_iter = 500L,
    tol = 1e-12
  )
  expect_true(res$converged)
  expect_equal(res$spectral_radius, rho_true, tolerance = 1e-10)
  expect_true(is.finite(res$contraction_constant) && res$contraction_constant < 1.0)
  expect_equal(mean(res$mean$y1), Tm_true[[1L]] * 1.5, tolerance = 1e-8)
  expect_equal(mean(res$mean$y2), Tm_true[[2L]] * 1.5, tolerance = 1e-8)

  # Check total effect contrast across x: 0 -> 1
  scen_contrast <- list(
    lo = data.frame(x = rep(0, 5)),
    hi = data.frame(x = rep(1, 5)),
    column = "x"
  )
  eq1 <- drmSEM:::drm_equilibrium_contrast(eng, scen_contrast, "y1", B = 1L, draw = FALSE)
  expect_true(eq1$converged)
  expect_identical(eq1$status, "converged")
  expect_equal(mean(eq1$vals), Tm_true[[1L]], tolerance = 1e-8)
  expect_equal(eq1$spectral_radius, rho_true, tolerance = 1e-10)

  eq2 <- drmSEM:::drm_equilibrium_contrast(eng, scen_contrast, "y2", B = 1L, draw = FALSE)
  expect_true(eq2$converged)
  expect_identical(eq2$status, "converged")
  expect_equal(mean(eq2$vals), Tm_true[[2L]], tolerance = 1e-8)
})

test_that("V-136: stability boundary detection flags non-convergence when rho(B) >= 1", {
  # Boundary case 1: rho(B) > 1 (divergent feedback)
  a1 <- 0.5
  a2 <- 0.3
  b12 <- 1.25
  b21 <- 0.90 # rho(B) = sqrt(1.25 * 0.90) = sqrt(1.125) > 1
  eng_div <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a1, y2 = b12)),
      predict = function(s, beta = NULL) data.frame(mu = a1 * s$x + b12 * s$y2)
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a2, y1 = b21)),
      predict = function(s, beta = NULL) data.frame(mu = a2 * s$x + b21 * s$y1)
    )
  )
  scen <- data.frame(x = rep(1, 5))
  res_div <- drmSEM:::propagate_fixedpoint(
    eng_div,
    scen,
    active = c("y1", "y2"),
    max_iter = 100L,
    tol = 1e-8
  )
  expect_false(res_div$converged)
  expect_gte(res_div$spectral_radius, 1.0)

  scen_contrast <- list(
    lo = data.frame(x = rep(0, 5)),
    hi = data.frame(x = rep(1, 5)),
    column = "x"
  )
  eq_div <- drmSEM:::drm_equilibrium_contrast(eng_div, scen_contrast, "y1", B = 1L, draw = FALSE)
  expect_false(eq_div$converged)
  expect_identical(eq_div$status, "non_convergent")
  expect_true(all(is.na(eq_div$vals)))

  # Boundary case 2: exact unit spectral radius rho(B) == 1.0
  b12_unit <- 1.0
  b21_unit <- 1.0
  eng_unit <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a1, y2 = b12_unit)),
      predict = function(s, beta = NULL) data.frame(mu = a1 * s$x + b12_unit * s$y2)
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a2, y1 = b21_unit)),
      predict = function(s, beta = NULL) data.frame(mu = a2 * s$x + b21_unit * s$y1)
    )
  )
  res_unit <- drmSEM:::propagate_fixedpoint(
    eng_unit,
    scen,
    active = c("y1", "y2"),
    max_iter = 100L,
    tol = 1e-8
  )
  expect_false(res_unit$converged)
  expect_equal(res_unit$spectral_radius, 1.0, tolerance = 1e-10)

  # Boundary case 3: negative oscillatory loop with magnitude >= 1
  b12_osc <- -1.2
  b21_osc <- 1.0 # rho(B) = sqrt(1.2) > 1
  eng_osc <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a1, y2 = b12_osc)),
      predict = function(s, beta = NULL) data.frame(mu = a1 * s$x + b12_osc * s$y2)
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "gaussian",
      links = c(mu = "identity"),
      coef = list(mu = c(x = a2, y1 = b21_osc)),
      predict = function(s, beta = NULL) data.frame(mu = a2 * s$x + b21_osc * s$y1)
    )
  )
  res_osc <- drmSEM:::propagate_fixedpoint(
    eng_osc,
    scen,
    active = c("y1", "y2"),
    max_iter = 100L,
    tol = 1e-8
  )
  expect_false(res_osc$converged)
})

test_that("V-137: nonlinear feedback equilibrium with lognormal and ZIP models solves multi-component fixed point", {
  # Node y1: Lognormal response (meanlog = a1*x + b12*log(y2), sdlog = sigma1)
  # Expected response: E[y1] = exp(meanlog + 0.5*sigma1^2)
  # Node y2: Zero-inflated Poisson (log(lambda) = a2*x + b21*log(y1), logit(zi) = c0 + c1*y1)
  # Expected response: E[y2] = (1 - zi) * lambda
  a1 <- 0.4
  b12 <- 0.25
  sigma1 <- 0.35

  a2 <- 0.5
  b21 <- 0.20
  c0 <- -1.5
  c1 <- 0.1

  eng_nonlin <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "lognormal",
      links = c(mu = "identity", sigma = "log"),
      predict = function(s, beta = NULL) {
        y2_val <- pmax(s$y2, 0.05)
        meanlog <- a1 * s$x + b12 * log(y2_val)
        data.frame(mu = meanlog, sigma = rep(sigma1, nrow(s)))
      }
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "poisson",
      links = c(mu = "log", zi = "logit"),
      predict = function(s, beta = NULL) {
        y1_val <- pmax(s$y1, 0.05)
        lambda <- exp(a2 * s$x + b21 * log(y1_val))
        zi_prob <- stats::plogis(c0 + c1 * y1_val)
        data.frame(mu = lambda, zi = zi_prob)
      }
    )
  )

  xval <- 1.2
  scen <- data.frame(x = rep(xval, 6))
  res <- drmSEM:::propagate_fixedpoint(
    eng_nonlin,
    scen,
    active = c("y1", "y2"),
    max_iter = 500L,
    tol = 1e-12
  )

  expect_true(res$converged)
  expect_true(res$contraction_constant < 1.0)
  expect_named(res$components$y1, c("mu", "sigma"))
  expect_named(res$components$y2, c("mu", "zi"))

  # Check self-consistency at equilibrium:
  y1_eq <- mean(res$mean$y1)
  y2_eq <- mean(res$mean$y2)

  # Check y1 formula from y2_eq
  meanlog_eq <- a1 * xval + b12 * log(y2_eq)
  y1_expected <- exp(meanlog_eq + 0.5 * sigma1^2)
  expect_equal(y1_eq, y1_expected, tolerance = 1e-8)

  # Check y2 formula from y1_eq
  lambda_eq <- exp(a2 * xval + b21 * log(y1_eq))
  zi_eq <- stats::plogis(c0 + c1 * y1_eq)
  y2_expected <- (1 - zi_eq) * lambda_eq
  expect_equal(y2_eq, y2_expected, tolerance = 1e-8)

  # Check total effect contrast across x: 0.5 -> 1.5
  scen_contrast <- list(
    lo = data.frame(x = rep(0.5, 4)),
    hi = data.frame(x = rep(1.5, 4)),
    column = "x"
  )
  eq_res <- drmSEM:::drm_equilibrium_contrast(eng_nonlin, scen_contrast, "y1", B = 1L, draw = FALSE)
  expect_true(eq_res$converged)
  expect_true(all(is.finite(eq_res$vals)))
  expect_gt(mean(eq_res$vals), 0)
})

test_that("V-138: variance-moderated feedback loop solves coupled distributional equilibrium", {
  # A causal loop where y1 modulates the VARIANCE (sigma) of lognormal y2,
  # and y2 feeds back into the mean of y1:
  # y1 -> sigma(y2) -> E[y2] -> y1
  #
  # Node y2 (lognormal):
  #   meanlog: mu2 = a2 * x
  #   sdlog:   sigma2 = exp(s0 + s1 * y1)
  #   E[y2] = exp(mu2 + 0.5 * sigma2^2) = exp(a2*x + 0.5 * exp(2*(s0 + s1*y1)))
  #
  # Node y1 (Gaussian):
  #   mu1 = a1 * x + b12 * y2
  #   E[y1] = mu1
  a1 <- 0.3
  a2 <- 0.2
  b12 <- 0.25
  s0 <- -0.8
  s1 <- 0.15 # positive variance modulation

  eng_varmod <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      predict = function(s, beta = NULL) {
        data.frame(mu = a1 * s$x + b12 * s$y2)
      }
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "lognormal",
      links = c(mu = "identity", sigma = "log"),
      predict = function(s, beta = NULL) {
        sig <- exp(s0 + s1 * s$y1)
        data.frame(mu = a2 * s$x, sigma = sig)
      }
    )
  )

  xval <- 1.0
  scen <- data.frame(x = rep(xval, 5))
  res <- drmSEM:::propagate_fixedpoint(
    eng_varmod,
    scen,
    active = c("y1", "y2"),
    max_iter = 500L,
    tol = 1e-12
  )

  expect_true(res$converged)
  expect_true(res$contraction_constant < 1.0)
  y1_eq <- mean(res$mean$y1)
  y2_eq <- mean(res$mean$y2)
  sig2_eq <- mean(res$components$y2$sigma)

  # Self-consistency check:
  sig2_expected <- exp(s0 + s1 * y1_eq)
  expect_equal(sig2_eq, sig2_expected, tolerance = 1e-8)

  y2_expected <- exp(a2 * xval + 0.5 * sig2_expected^2)
  expect_equal(y2_eq, y2_expected, tolerance = 1e-8)

  y1_expected <- a1 * xval + b12 * y2_expected
  expect_equal(y1_eq, y1_expected, tolerance = 1e-8)

  # Confirm that variance modulation increases the equilibrium compared to no variance modulation (s1 = 0)
  eng_novarmod <- list(
    y1 = list(
      name = "y1",
      identifier = "y1",
      family = "gaussian",
      links = c(mu = "identity"),
      predict = function(s, beta = NULL) {
        data.frame(mu = a1 * s$x + b12 * s$y2)
      }
    ),
    y2 = list(
      name = "y2",
      identifier = "y2",
      family = "lognormal",
      links = c(mu = "identity", sigma = "log"),
      predict = function(s, beta = NULL) {
        sig <- exp(s0)
        data.frame(mu = a2 * s$x, sigma = rep(sig, nrow(s)))
      }
    )
  )
  res_novar <- drmSEM:::propagate_fixedpoint(
    eng_novarmod,
    scen,
    active = c("y1", "y2"),
    max_iter = 500L,
    tol = 1e-12
  )
  expect_true(res_novar$converged)
  # Because s1 > 0 and y1 > 0, variance moderation amplifies E[y2] and thus E[y1]
  expect_gt(y1_eq, mean(res_novar$mean$y1))
})
