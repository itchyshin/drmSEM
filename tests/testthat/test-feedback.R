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
    list(drm_cycle("y1", "y2"), drm_cycle("y2", "y3")), records3
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
  from = c("y1", "y2", "y2"), to = c("y2", "y1", "y3"),
  stringsAsFactors = FALSE
)

test_that("drm_toposort_feedback accepts a declared motif and orders the rest", {
  topo <- drmSEM:::drm_toposort_feedback(
    c("y1", "y2", "y3"), fb_edges, list(c("y1", "y2"))
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
  structure(list(
    order = c("y1", "y2"), endogenous = c("y1", "y2"), exogenous = "x",
    edges = data.frame(from = c("x", "x"), to = c("y1", "y2"),
                       component = c("mu", "mu"), stringsAsFactors = FALSE),
    covariances = NULL, feedback = fb
  ), class = "drm_sem")
}

test_that("a declared feedback motif drops the y1 _||_ y2 independence claim", {
  bs_plain <- basis_set(make_fb_sibling(NULL))
  expect_true(any(bs_plain$x == "y1" & bs_plain$y == "y2"))

  fb <- data.frame(motif = c(1L, 1L), node = c("y1", "y2"),
                   stringsAsFactors = FALSE)
  bs_fb <- basis_set(make_fb_sibling(fb))
  expect_false(any((bs_fb$x == "y1" & bs_fb$y == "y2") |
                   (bs_fb$x == "y2" & bs_fb$y == "y1")))
})

# ---- spectral radius and the linear reduced form ----------------------------

test_that("drm_spectral_radius and drm_reduced_form match the closed form", {
  B <- matrix(c(0, 0.2, 0.4, 0), nrow = 2)   # b12 = 0.4 (row1,col2), b21 = 0.2
  Gamma <- matrix(c(0.5, 0.3), ncol = 1)
  rho <- drmSEM:::drm_spectral_radius(B)
  expect_equal(rho, sqrt(0.4 * 0.2), tolerance = 1e-12)

  Tm <- drmSEM:::drm_reduced_form(B, Gamma)
  expect_true(attr(Tm, "stable"))
  expect_equal(as.numeric(Tm), as.numeric(solve(diag(2) - B) %*% Gamma),
               tolerance = 1e-12)

  # rho(B) >= 1 is flagged unstable
  Bun <- matrix(c(0, 1.0, 1.2, 0), nrow = 2)
  expect_false(attr(drmSEM:::drm_reduced_form(Bun, Gamma), "stable"))
})

# ---- fixed-point equilibrium propagation ------------------------------------

lin_engine <- function(name, fn) {
  list(name = name, identifier = name, family = "gaussian",
       predict = function(scenario, beta = NULL) data.frame(mu = fn(scenario)))
}

test_that("V-42: propagate_fixedpoint recovers the linear 2-cycle equilibrium (I-B)^-1 Gamma", {
  a1 <- 0.5; a2 <- 0.3; b12 <- 0.4; b21 <- 0.2
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  scen <- data.frame(x = rep(1, 6))
  res <- drmSEM:::propagate_fixedpoint(eng, scen, active = c("y1", "y2"),
                                       max_iter = 500L, tol = 1e-12)
  expect_true(res$converged)

  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  Gamma <- matrix(c(a1, a2), ncol = 1)
  eq <- as.numeric(solve(diag(2) - B) %*% Gamma)   # equilibrium at x = 1
  expect_equal(mean(res$mean$y1), eq[[1L]], tolerance = 1e-8)
  expect_equal(mean(res$mean$y2), eq[[2L]], tolerance = 1e-8)
})

test_that("propagate_fixedpoint reports non-convergence when rho(B) >= 1", {
  a1 <- 0.5; a2 <- 0.3; b12 <- 1.2; b21 <- 1.0   # spectral radius > 1: diverges
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  scen <- data.frame(x = rep(1, 4))
  res <- drmSEM:::propagate_fixedpoint(eng, scen, active = c("y1", "y2"),
                                       max_iter = 200L, tol = 1e-10)
  expect_false(res$converged)
})

test_that("V-43: drm_equilibrium_contrast recovers the reduced-form total effect of x", {
  a1 <- 0.5; a2 <- 0.3; b12 <- 0.4; b21 <- 0.2
  eng <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + b12 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + b21 * s$y1)
  )
  # contrast x: 0 -> 1, so the equilibrium contrast equals T[, 1] (one unit of x)
  scen <- list(lo = data.frame(x = rep(0, 5)), hi = data.frame(x = rep(1, 5)),
               column = "x")
  B <- matrix(c(0, b21, b12, 0), nrow = 2)
  Gamma <- matrix(c(a1, a2), ncol = 1)
  Tm <- as.numeric(solve(diag(2) - B) %*% Gamma)   # total-effect column for x

  eq1 <- drmSEM:::drm_equilibrium_contrast(eng, scen, "y1", B = 1L, draw = FALSE)
  expect_true(eq1$converged)
  expect_equal(mean(eq1$vals), Tm[[1L]], tolerance = 1e-8)

  eq2 <- drmSEM:::drm_equilibrium_contrast(eng, scen, "y2", B = 1L, draw = FALSE)
  expect_equal(mean(eq2$vals), Tm[[2L]], tolerance = 1e-8)

  # a diverging system is flagged non-convergent (effect undefined, not a number)
  engd <- list(
    y1 = lin_engine("y1", function(s) a1 * s$x + 1.2 * s$y2),
    y2 = lin_engine("y2", function(s) a2 * s$x + 1.0 * s$y1)
  )
  expect_false(drmSEM:::drm_equilibrium_contrast(engd, scen, "y1",
                                                 B = 1L, draw = FALSE)$converged)
})

test_that("V-73: propagate_fixedpoint solves a NONLINEAR feedback fixed point", {
  # A nonlinear reciprocal pair (saturating coupling), a contraction so a unique
  # stable equilibrium exists. There is no closed form, so the known answer is the
  # fixed-point PROPERTY: at convergence, re-applying the structural map must
  # reproduce the values (self-consistency), and an independent fixed-point solve
  # must agree.
  a1 <- 0.6; a2 <- -0.4; b12 <- 0.5; b21 <- 0.3
  f1 <- function(x, y2) a1 * x + b12 * tanh(y2)
  f2 <- function(x, y1) a2 * x + b21 * tanh(y1)
  eng <- list(
    y1 = lin_engine("y1", function(s) f1(s$x, s$y2)),
    y2 = lin_engine("y2", function(s) f2(s$x, s$y1))
  )
  xval <- 0.8
  scen <- data.frame(x = rep(xval, 5))
  res <- drmSEM:::propagate_fixedpoint(eng, scen, active = c("y1", "y2"),
                                       max_iter = 1000L, tol = 1e-12)
  expect_true(res$converged)
  y1s <- mean(res$mean$y1); y2s <- mean(res$mean$y2)

  # self-consistency: the converged values satisfy the structural equations
  expect_equal(y1s, f1(xval, y2s), tolerance = 1e-8)
  expect_equal(y2s, f2(xval, y1s), tolerance = 1e-8)

  # independent solve (plain Gauss-Seidel reference) reaches the same fixed point
  z1 <- 0; z2 <- 0
  for (i in seq_len(1000L)) { z1 <- f1(xval, z2); z2 <- f2(xval, z1) }
  expect_equal(y1s, z1, tolerance = 1e-8)
  expect_equal(y2s, z2, tolerance = 1e-8)
})

# ---- cycles() accessor ------------------------------------------------------

test_that("cycles() reports the declared motifs of a drm_sem", {
  fb <- data.frame(motif = c(1L, 1L), node = c("y1", "y2"),
                   stringsAsFactors = FALSE)
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
  x <- stats::rnorm(n); z <- stats::rnorm(n)
  y1 <- 0.5 * x + stats::rnorm(n)
  y2 <- 0.4 * z + 0.3 * y1 + stats::rnorm(n)
  y1 <- y1 + 0.2 * y2            # mutual dependence -> a declared y1 <-> y2 cycle
  dat <- data.frame(x, z, y1, y2)

  # the declared motif relaxes the DAG check but warns about simultaneity bias
  expect_warning(
    sem <- drm_sem(
      y1 = drm_node(drmTMB::bf(y1 ~ x + y2), family = stats::gaussian()),
      y2 = drm_node(drmTMB::bf(y2 ~ z + y1), family = stats::gaussian()),
      data = dat, feedback = drm_cycle("y1", "y2")
    ),
    "simultaneity"
  )
  expect_identical(nrow(cycles(sem)), 2L)
  # total_effects routes through the equilibrium propagator for a feedback SEM
  te <- total_effects(sem, from = "x", to = "y2", uncertainty = "none")
  expect_identical(te$mediation, "equilibrium")
  expect_true(is.finite(te$estimate))            # this system is stable
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
