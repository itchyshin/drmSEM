# OQ-5 — per-mediator path-specific attribution. The kernel (drm_path_contrasts)
# is pure-R: tested with hand-built engines and mean mediation + draw = FALSE, so
# every contrast is deterministic and asserted at closed form (1e-8). The
# user-facing path_effects() wrapper needs a live fit and is CI-gated.

pe_engine <- function(name, mu_fn) {
  list(name = name, identifier = name, family = "gaussian", components = "mu",
       coef = list(), vcov = NULL,
       predict = function(scenario, beta = NULL) data.frame(mu = mu_fn(scenario)))
}
pe_rows <- function(df, n) df[rep(1, n), ]
pe_scen <- function() {
  list(lo = pe_rows(data.frame(x = 0, M1 = 0, M2 = 0, Y = 0), 20),
       hi = pe_rows(data.frame(x = 1, M1 = 0, M2 = 0, Y = 0), 20),
       column = "x")
}
pc_mean <- function(eng, meds) {
  drmSEM:::drm_path_contrasts(eng, pe_scen(), "Y", meds, mediation = "mean",
                              B = 1, n_sim = 1, draw = FALSE)
}

test_that("P-1: parallel additive mediators -> inclusion = a*b, remainder = 0", {
  a1 <- 0.5; a2 <- -0.3; b1 <- 0.4; b2 <- 0.7
  eng <- list(
    M1 = pe_engine("M1", function(s) a1 * s$x),
    M2 = pe_engine("M2", function(s) a2 * s$x),
    Y  = pe_engine("Y",  function(s) b1 * s$M1 + b2 * s$M2)
  )
  pc <- pc_mean(eng, c("M1", "M2"))
  expect_equal(mean(pc$inclusion$M1), a1 * b1, tolerance = 1e-8)
  expect_equal(mean(pc$inclusion$M2), a2 * b2, tolerance = 1e-8)
  # additive: inclusion == exclusion, and the pieces sum to the total
  expect_equal(mean(pc$exclusion$M1), a1 * b1, tolerance = 1e-8)
  expect_equal(mean(pc$exclusion$M2), a2 * b2, tolerance = 1e-8)
  expect_equal(mean(pc$total_indirect), a1 * b1 + a2 * b2, tolerance = 1e-8)
  expect_equal(mean(pc$remainder), 0, tolerance = 1e-8)
})

test_that("P-2: downstream nonlinearity -> not additive, remainder != 0", {
  a1 <- 0.5; a2 <- 0.4; k <- 0.5
  eng <- list(
    M1 = pe_engine("M1", function(s) a1 * s$x),
    M2 = pe_engine("M2", function(s) a2 * s$x),
    Y  = pe_engine("Y",  function(s) exp(k * (s$M1 + s$M2)))
  )
  pc <- pc_mean(eng, c("M1", "M2"))
  # closed forms with x0 = 0, x1 = 1
  expect_equal(mean(pc$inclusion$M1), exp(k * a1) - 1, tolerance = 1e-8)
  expect_equal(mean(pc$total_indirect), exp(k * (a1 + a2)) - 1, tolerance = 1e-8)
  rem <- mean(pc$remainder)
  # e^{u+v} - e^u - e^v + 1 = (e^u - 1)(e^v - 1) > 0
  expect_equal(rem, (exp(k * a1) - 1) * (exp(k * a2) - 1), tolerance = 1e-8)
  expect_gt(rem, 0)
  # inclusion and exclusion diverge under the nonlinearity
  expect_false(isTRUE(all.equal(mean(pc$inclusion$M1), mean(pc$exclusion$M1))))
})

test_that("P-3: sequential mediators -> inclusion under-attributes, exclusion = total", {
  a <- 0.5; cc <- 0.8; b <- 0.6
  eng <- list(
    M1 = pe_engine("M1", function(s) a * s$x),
    M2 = pe_engine("M2", function(s) cc * s$M1),   # M1 -> M2
    Y  = pe_engine("Y",  function(s) b * s$M2)
  )
  pc <- pc_mean(eng, c("M1", "M2"))
  acb <- a * cc * b
  expect_equal(mean(pc$total_indirect), acb, tolerance = 1e-8)
  # each inclusion freezes the other mediator, breaking the chain -> 0
  expect_equal(mean(pc$inclusion$M1), 0, tolerance = 1e-8)
  expect_equal(mean(pc$inclusion$M2), 0, tolerance = 1e-8)
  # each is necessary, so exclusion attributes the whole effect to both
  expect_equal(mean(pc$exclusion$M1), acb, tolerance = 1e-8)
  expect_equal(mean(pc$exclusion$M2), acb, tolerance = 1e-8)
  # the inclusion-based remainder carries the unattributed chain effect
  expect_equal(mean(pc$remainder), acb, tolerance = 1e-8)
})

test_that("a single mediator: inclusion = exclusion = total, remainder 0", {
  a <- 0.5; b <- 0.6
  eng <- list(
    M1 = pe_engine("M1", function(s) a * s$x),
    Y  = pe_engine("Y",  function(s) b * s$M1)
  )
  pc <- pc_mean(eng, "M1")
  expect_equal(mean(pc$inclusion$M1), a * b, tolerance = 1e-8)
  expect_equal(mean(pc$exclusion$M1), a * b, tolerance = 1e-8)
  expect_equal(mean(pc$remainder), 0, tolerance = 1e-8)
})
