# check_sem() and its print method.
#
# check_sem() is exported, documented, and — until this file — had exactly ONE
# assertion anywhere in the suite (the `nobs` column, added with the row-alignment
# work). Its convergence, covariance and sampler columns, its print method, and every
# one of its warning branches were untested. The capability surface said so plainly:
# "existence and a plausible-looking implementation are not evidence it reports
# correctly."
#
# Split deliberately by determinism, which is the lesson this lane paid for on
# Windows: the ROW CONTENT is checked against a live fit, but every WARNING BRANCH is
# checked against a hand-built drm_diagnostics object. Asking a live optimizer to
# produce a non-converged node on demand is exactly the test that passes on macOS and
# fails on Windows.
#
# V-97   check_sem() reports correct rows for a healthy live SEM
# V-98   print() warns on non-convergence
# V-99   print() warns on a missing covariance and says how to fix it
# V-100  print() informs on a missing realized-value sampler
# V-101  print() warns when nodes were fitted on different numbers of observations
# V-102  print() is silent and clean when every node is healthy

# A drm_diagnostics object is a plain data frame with a class and an `exogenous`
# attribute. Building one directly is what makes the branch tests deterministic.
fake_diag <- function(...,
                      node = "y", family = "gaussian", components = "mu",
                      nobs = 100L, converged = TRUE, vcov_available = TRUE,
                      sampler = TRUE, exogenous = character(0)) {
  out <- data.frame(
    node = node, family = family, components = components, nobs = nobs,
    converged = converged, vcov_available = vcov_available, sampler = sampler,
    stringsAsFactors = FALSE
  )
  attr(out, "exogenous") <- exogenous
  class(out) <- c("drm_diagnostics", "data.frame")
  out
}

test_that("V-98: print() warns when a node did not converge", {
  d <- fake_diag(converged = FALSE)
  expect_warning(print(d), "did not converge")
})

test_that("V-98b: an unknown convergence status is treated as not-converged", {
  # drm_fit_converged() returns NA when the engine will not say. NA must NOT be read
  # as "fine" -- silence about convergence is not evidence of it.
  d <- fake_diag(converged = NA)
  expect_warning(print(d), "did not converge")
})

test_that("V-99: print() warns on a missing covariance and names the remedy", {
  d <- fake_diag(vcov_available = FALSE)
  expect_warning(print(d), "lack a fixed-effect covariance")
  # A diagnostic that does not say what to do next is only half a diagnostic.
  w <- tryCatch(print(d), warning = function(cond) conditionMessage(cond))
  expect_match(w, "se = TRUE", fixed = TRUE)
})

test_that("V-100: print() informs (not warns) on a missing sampler", {
  # Deliberately cli_inform, not cli_warn: mean fallback is a documented degradation,
  # not a defect, so it must not be escalated to a warning.
  d <- fake_diag(sampler = FALSE)
  expect_no_warning(print(d))
  expect_message(print(d), "no realized-value sampler")
})

test_that("V-101: print() warns when nodes used different numbers of observations", {
  d <- fake_diag(node = c("m", "y"), family = c("gaussian", "gaussian"),
                 components = c("mu", "mu"), nobs = c(270L, 240L),
                 converged = c(TRUE, TRUE), vcov_available = c(TRUE, TRUE),
                 sampler = c(TRUE, TRUE))
  expect_warning(print(d), "different numbers of observations")
  w <- tryCatch(print(d), warning = function(cond) conditionMessage(cond))
  expect_match(w, "na_action", fixed = TRUE)
})

test_that("V-101b: equal nobs, and an NA nobs, do not trigger the alignment warning", {
  equal <- fake_diag(node = c("m", "y"), family = c("gaussian", "gaussian"),
                     components = c("mu", "mu"), nobs = c(300L, 300L),
                     converged = TRUE, vcov_available = TRUE, sampler = TRUE)
  expect_no_warning(print(equal))
  # An engine that will not report nobs must not manufacture a mismatch.
  unknown <- fake_diag(node = c("m", "y"), family = c("gaussian", "gaussian"),
                       components = c("mu", "mu"), nobs = c(NA_integer_, 300L),
                       converged = TRUE, vcov_available = TRUE, sampler = TRUE)
  expect_no_warning(print(unknown))
})

test_that("V-102: a fully healthy diagnostics object prints clean", {
  d <- fake_diag(exogenous = c("temp", "habitat"))
  expect_no_warning(print(d))
  # The cli header is itself a message, so "no messages at all" is the wrong bar.
  # The bar is: none of the PROBLEM messages fire on a healthy object.
  msgs <- paste(
    utils::capture.output(print(d), type = "message"), collapse = " "
  )
  expect_false(grepl(
    "no realized-value sampler|did not converge|lack a fixed-effect|different numbers",
    msgs
  ))
  # print() must return its input invisibly so `x <- print(chk)` round-trips.
  expect_invisible(print(d))
  expect_identical(attr(print(d), "exogenous"), c("temp", "habitat"))
  # The table itself does reach stdout (the exogenous line goes through cli, which
  # testthat does not capture here -- asserting on that would test cli, not drmSEM).
  expect_output(print(d), "gaussian")
})

# --- live half: the row CONTENT, on a well-behaved SEM ------------------------

test_that("V-97: check_sem() reports correct rows for a healthy live SEM", {
  skip_if_not_installed("drmTMB")
  set.seed(77)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.6 * m + stats::rnorm(n)
  d <- data.frame(x = x, m = m, y = y)
  sem <- drm_sem(
    m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
    y = drm_node(drmTMB::bf(y ~ m + x), family = stats::gaussian()),
    data = d
  )
  chk <- check_sem(sem)
  expect_s3_class(chk, "drm_diagnostics")
  expect_named(chk, c("node", "family", "components", "nobs", "converged",
                      "vcov_available", "sampler"))
  expect_setequal(chk$node, c("m", "y"))
  # Rows must follow the SEM's topological order, not argument order.
  expect_identical(chk$node, sem$order)
  expect_true(all(chk$family == "gaussian"))
  expect_true(all(chk$nobs == n))
  expect_true(all(chk$converged))
  expect_true(all(chk$vcov_available))
  expect_true(all(chk$sampler))
  expect_identical(attr(chk, "exogenous"), sem$exogenous)
  # Healthy SEM: nothing to complain about.
  expect_no_warning(print(chk))
})
