# The nominal link table (R/edges.R).
#
# Display-and-standardization labels only -- this never alters a drmTMB computation.
# But `paths()` shows the link to the reader, and standardize() consults it, so a
# wrong label misinforms silently.
#
# Pure lookup: no engine, no fitting, deterministic on every platform. That is
# deliberate. The lesson from this lane's Windows CI failure is that a mechanism
# should be tested where it is deterministic, and only the CONTRACT tested live.
#
# V-95  every family drmSEM can sample has an explicit, correct link label
# V-96  component-driven links win over the family, and the fallback is reserved
#       for genuinely unknown families

test_that("V-95: every samplable family has an EXPLICIT link label", {
  # The risk this pins: skew_normal and the three bivariate families used to reach
  # the fallback and be labelled "identity" by accident. That label happened to be
  # right, which is exactly why it survived -- a right answer for the wrong reason
  # is invisible until a family arrives for which the fallback is wrong.
  expected <- c(
    gaussian = "identity", student = "identity", lognormal = "identity",
    skew_normal = "identity",
    biv_gaussian = "identity", biv_lognormal = "identity", biv_student = "identity",
    Gamma = "log", gamma = "log", tweedie = "log", poisson = "log",
    nbinom2 = "log", truncated_nbinom2 = "log",
    beta = "logit", beta_binomial = "logit", zero_one_beta = "logit",
    binomial = "logit", cumulative_logit = "logit"
  )
  for (fam in names(expected)) {
    expect_identical(
      drmSEM:::drm_nominal_link(fam, "mu"), unname(expected[[fam]]),
      label = paste0("nominal link for family '", fam, "'")
    )
  }

  # Anything drm_sample_family() can draw must be in that table, or paths() would
  # print a fallback label for a family we fully support.
  expect_true(all(drmSEM:::drm_supported_sampler_families() %in% names(expected)))
})

test_that("V-96: component links override the family, and the fallback still exists", {
  # A path to sigma is a path to scale, on the log scale, whatever the family is.
  expect_identical(drmSEM:::drm_nominal_link("gaussian", "sigma"), "log")
  expect_identical(drmSEM:::drm_nominal_link("poisson", "nu"), "log")
  expect_identical(drmSEM:::drm_nominal_link("beta", "sd_site"), "log")
  expect_identical(drmSEM:::drm_nominal_link("nbinom2", "zi"), "logit")
  expect_identical(drmSEM:::drm_nominal_link("nbinom2", "hu"), "logit")
  expect_identical(drmSEM:::drm_nominal_link("zero_one_beta", "zoi"), "logit")
  expect_identical(drmSEM:::drm_nominal_link("zero_one_beta", "coi"), "logit")
  expect_identical(drmSEM:::drm_nominal_link("biv_gaussian", "rho12"), "tanh")
  # The fallback is now reserved for families the table genuinely does not know.
  expect_identical(drmSEM:::drm_nominal_link("a_family_we_do_not_model", "mu"), "identity")
})
