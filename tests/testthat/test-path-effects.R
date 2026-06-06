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

test_that("by-component: mean channel is exact, distributional channel matches the lognormal form", {
  skip_on_cran()
  set.seed(7)
  a <- 0.4; k <- 0.5; s0 <- -0.2; x0 <- 0; x1 <- 1
  pe_engine2 <- function(name, mu_fn, sigma_fn) {
    list(name = name, identifier = name, family = "gaussian",
         components = c("mu", "sigma"), coef = list(), vcov = NULL,
         predict = function(scenario, beta = NULL)
           data.frame(mu = mu_fn(scenario), sigma = sigma_fn(scenario)))
  }
  scen <- list(lo = pe_rows(data.frame(x = x0, M = 0, Y = 0), 120),
               hi = pe_rows(data.frame(x = x1, M = 0, Y = 0), 120), column = "x")
  run <- function(s1) {
    eng <- list(
      M = pe_engine2("M", function(s) a * s$x, function(s) exp(s0 + s1 * s$x)),
      Y = pe_engine("Y", function(s) exp(k * s$M))
    )
    drmSEM:::drm_path_contrasts(eng, scen, "Y", "M", mediation = "distribution",
                                B = 1, n_sim = 2000, draw = FALSE)
  }
  pc <- run(0.9)
  # mean channel is deterministic: exp(k*a*x1) - exp(k*a*x0)
  expect_equal(mean(pc$mean_inclusion$M), exp(k * a * x1) - exp(k * a * x0), tolerance = 1e-8)
  # distributional channel matches the V-28 lognormal closed form
  sig <- function(x) exp(s0 + 0.9 * x)
  D <- (exp(k * a * x1 + 0.5 * k^2 * sig(x1)^2) - exp(k * a * x1)) -
       (exp(k * a * x0 + 0.5 * k^2 * sig(x0)^2) - exp(k * a * x0))
  dist_ch <- mean(pc$inclusion$M - pc$mean_inclusion$M)
  expect_equal(dist_ch, D, tolerance = 0.06)
  # the two channels partition the inclusion effect exactly
  expect_equal(mean(pc$mean_inclusion$M) + dist_ch, mean(pc$inclusion$M), tolerance = 1e-12)
  # negative control: a LINEAR outcome has no Jensen gap, so the distributional
  # channel is zero regardless of the scale path. (A flat sigma does NOT zero the
  # channel under a nonlinear outcome: the constant variance-inflation still moves
  # with the mean through the nonlinearity.)
  eng_lin <- list(
    M = pe_engine2("M", function(s) a * s$x, function(s) exp(s0 + 0.9 * s$x)),
    Y = pe_engine("Y", function(s) 0.6 * s$M)
  )
  pc_lin <- drmSEM:::drm_path_contrasts(eng_lin, scen, "Y", "M",
                                        mediation = "distribution",
                                        B = 1, n_sim = 2000, draw = FALSE)
  expect_equal(mean(pc_lin$inclusion$M - pc_lin$mean_inclusion$M), 0, tolerance = 0.02)
})

test_that("by-component freeze attributes the sigma channel (OQ-5 per-component)", {
  skip_on_cran()
  a <- 0.4; k <- 0.5; s0 <- -0.2; x0 <- 0; x1 <- 1
  sig <- function(x) exp(s0 + 0.9 * x)
  ms_engine <- function(s1) list(
    M = list(name = "M", identifier = "M", family = "gaussian",
             components = c("mu", "sigma"), coef = list(), vcov = NULL,
             predict = function(scenario, beta = NULL)
               data.frame(mu = a * scenario$x, sigma = exp(s0 + s1 * scenario$x))),
    Y = pe_engine("Y", function(s) exp(k * s$M))
  )
  scen <- list(lo = pe_rows(data.frame(x = x0, M = 0, Y = 0), 120),
               hi = pe_rows(data.frame(x = x1, M = 0, Y = 0), 120), column = "x")
  # seed gives common random numbers across the full / frozen contrasts.
  cc <- drmSEM:::drm_component_contrasts(ms_engine(0.9), scen, "Y", "M",
                                         B = 1, n_sim = 4000, draw = FALSE, seed = 1)
  # mean channel is deterministic
  expect_equal(mean(cc$mean), exp(k * a * x1) - exp(k * a * x0), tolerance = 1e-8)
  # sigma channel: exp(ka + 0.5 k^2 sig1^2) - exp(ka + 0.5 k^2 sig0^2)
  pce_sigma <- exp(k * a * x1 + 0.5 * k^2 * sig(x1)^2) -
               exp(k * a * x1 + 0.5 * k^2 * sig(x0)^2)
  expect_equal(mean(cc$channels$sigma), pce_sigma, tolerance = 0.06)
  # the channels do NOT partition exactly under the nonlinear outcome; the
  # remainder is (e^{ka}-1)(e^{0.5 k^2 sig0^2}-1), reported rather than hidden
  rem <- (exp(k * a) - 1) * (exp(0.5 * k^2 * sig(x0)^2) - 1)
  expect_equal(mean(cc$remainder), rem, tolerance = 0.06)
  # the pieces reconstruct the inclusion effect exactly (by construction)
  expect_equal(mean(cc$mean) + mean(cc$channels$sigma) + mean(cc$remainder),
               mean(cc$inclusion), tolerance = 1e-12)
  # negative control: a flat scale path (s1 = 0) -> sigma channel is exactly 0
  cc0 <- drmSEM:::drm_component_contrasts(ms_engine(0), scen, "Y", "M",
                                          B = 1, n_sim = 4000, draw = FALSE, seed = 1)
  expect_equal(mean(cc0$channels$sigma), 0, tolerance = 1e-9)
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

test_that("recanting-witness detection flags sequential mediators (OQ-5 natural)", {
  # parallel mediators (x -> m1 -> y, x -> m2 -> y): neither recants
  obj_par <- structure(list(var_edges = data.frame(
    from = c("x", "x", "m1", "m2"), to = c("m1", "m2", "y", "y"),
    stringsAsFactors = FALSE)), class = "drm_sem")
  expect_false(drmSEM:::drm_recanting_witness(obj_par, "x", "m1", c("m1", "m2")))
  expect_false(drmSEM:::drm_recanting_witness(obj_par, "x", "m2", c("m1", "m2")))

  # sequential mediators (x -> m1 -> m2 -> y): m1 recants for m2 (descendant of x
  # AND ancestor of m2); m2 does not recant for m1
  obj_seq <- structure(list(var_edges = data.frame(
    from = c("x", "m1", "m2"), to = c("m1", "m2", "y"),
    stringsAsFactors = FALSE)), class = "drm_sem")
  expect_true(drmSEM:::drm_recanting_witness(obj_seq, "x", "m2", c("m1", "m2")))
  expect_false(drmSEM:::drm_recanting_witness(obj_seq, "x", "m1", c("m1", "m2")))
})
