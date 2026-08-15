# drm_psem() — the "assemble already-fitted drmTMB objects" entry point.
#
# Named in DESCRIPTION and in the charter as one of the package's two interfaces,
# exported, documented — and until this file, referenced by ZERO tests. Every SEM in
# the suite was built through drm_sem(). The shared graph internals (new_drm_sem())
# are therefore heavily exercised, but drm_psem's OWN path — validating its inputs
# and deriving default `data` from the first fit — was not.
#
# Same defect class as the rest of this lane: a capability the surface advertises with
# nothing checking it.
#
# V-105  drm_psem() assembles pre-fitted nodes into the same object drm_sem() builds
# V-106  it rejects non-drmTMB input, and points at the right interface
# V-107  it derives default `data` from the FIRST fit when none is supplied

skip_if_not_installed("drmTMB")

psem_fixture <- function(n = 300, seed = 606) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.6 * m + 0.3 * x + stats::rnorm(n)
  d <- data.frame(x = x, m = m, y = y)
  list(
    dat = d,
    fit_m = drmTMB::drmTMB(drmTMB::bf(m ~ x), family = stats::gaussian(), data = d),
    fit_y = drmTMB::drmTMB(drmTMB::bf(y ~ m + x), family = stats::gaussian(), data = d)
  )
}

test_that("V-105: drm_psem() builds the same graph drm_sem() would", {
  f <- psem_fixture()
  psem <- drm_psem(m = f$fit_m, y = f$fit_y, data = f$dat)
  expect_s3_class(psem, "drm_sem")

  # The two interfaces are documented as producing the same object. Assert that
  # against a drm_sem() built from the same data, rather than against a hand-written
  # expectation of what the graph "should" be.
  dsem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m + x), family = stats::gaussian()),
    data = f$dat
  )
  expect_identical(psem$order, dsem$order)
  expect_setequal(names(psem$nodes), names(dsem$nodes))

  pp <- as.data.frame(paths(psem))
  pd <- as.data.frame(paths(dsem))
  expect_identical(nrow(pp), nrow(pd))
  expect_setequal(paste(pp$from, pp$to, pp$component), paste(pd$from, pd$to, pd$component))
  # Same data, same formulas, same engine: the coefficients must agree, not merely
  # the shape.
  expect_equal(sort(pp$estimate), sort(pd$estimate), tolerance = 1e-6)
})

test_that("V-105b: the assembled object supports the downstream surface", {
  f <- psem_fixture()
  psem <- drm_psem(m = f$fit_m, y = f$fit_y, data = f$dat)

  # `y ~ m + x` makes this DAG SATURATED -- every pair is connected -- so an empty
  # basis set is the correct answer, not a failure. Pinned because "dsep returned
  # nothing" is easy to misread as broken.
  # It says so out loud, too -- asserted rather than left to leak into the suite's
  # warning count, which is where an unexplained warning hides.
  expect_warning(ds_sat <- dsep(psem), "fully saturated")
  expect_identical(nrow(as.data.frame(ds_sat)), 0L)

  # A non-saturated assembly does yield a testable claim.
  fit_y_ns <- drmTMB::drmTMB(drmTMB::bf(y ~ m), family = stats::gaussian(),
                             data = f$dat)
  psem_ns <- drm_psem(m = f$fit_m, y = fit_y_ns, data = f$dat)
  ds <- as.data.frame(dsep(psem_ns))
  expect_identical(nrow(ds), 1L)
  expect_identical(ds$status, "ok")
  expect_true(is.finite(fisher_c(psem_ns)$fisher_c))

  ie <- suppressWarnings(
    indirect_effects(psem, from = "x", to = "y", uncertainty = "none", nsim = 200)
  )
  q <- stats::setNames(ie$estimate, ie$quantity)
  expect_true(all(is.finite(q)))
  expect_equal(q[["total_path"]], q[["direct"]] + q[["indirect"]], tolerance = 1e-8)
  chk <- check_sem(psem)
  expect_true(all(chk$nobs == nrow(f$dat)))
})

test_that("V-106: non-drmTMB input is rejected, naming the other interface", {
  f <- psem_fixture(n = 100)
  # A drm_node spec is the classic mistake: it is what drm_sem() wants, not drm_psem().
  expect_error(
    drm_psem(m = drm_node(drmTMB::bf(m ~ x)), data = f$dat),
    "fitted"
  )
  msg <- tryCatch(
    drm_psem(m = drm_node(drmTMB::bf(m ~ x)), data = f$dat),
    error = function(e) conditionMessage(e)
  )
  # An error that does not say where to go next is half an error.
  expect_match(msg, "drm_sem", fixed = TRUE)

  expect_error(drm_psem(m = 1:10, data = f$dat), "fitted")
  expect_error(drm_psem(m = f$fit_m, y = "not a fit", data = f$dat), "fitted")
})

test_that("V-107: `data` defaults to the first fit's data when not supplied", {
  f <- psem_fixture()
  # This is the branch with no other coverage: drm_psem(data = NULL) reaches into
  # fit 1 via drm_fit_data(). If it silently produced an empty or wrong frame, every
  # downstream scenario would be built on it.
  psem <- drm_psem(m = f$fit_m, y = f$fit_y)
  expect_identical(nrow(psem$data), nrow(f$dat))
  expect_true(all(c("x", "m", "y") %in% names(psem$data)))
  # And it must agree with the explicit-data form.
  explicit <- drm_psem(m = f$fit_m, y = f$fit_y, data = f$dat)
  expect_equal(
    as.data.frame(paths(psem))$estimate,
    as.data.frame(paths(explicit))$estimate,
    tolerance = 1e-10
  )
})
