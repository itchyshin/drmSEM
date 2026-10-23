# d-separation graph logic and Fisher's C (no drmTMB required).

test_that("Fisher's C combines p-values with 2k df", {
  fc <- drm_fisher_c_from_p(c(0.5, 0.5))
  expect_equal(fc$df, 4L)
  expect_equal(fc$C, -2 * sum(log(c(0.5, 0.5))))
  expect_equal(fc$k, 2L)
})

test_that("Fisher's C drops NA claims but keeps them counted in 2k otherwise", {
  fc <- drm_fisher_c_from_p(c(0.5, NA, 0.2))
  expect_equal(fc$k, 2L)
  expect_equal(fc$df, 4L)
  expect_equal(fc$C, -2 * sum(log(c(0.5, 0.2))))
})

test_that("a p == 0 claim inflates Fisher's C rather than being dropped", {
  # A decisively rejected independence (p == 0) is the strongest evidence of a
  # missing arrow; it must be floored (not discarded) so C -> large and the SEM
  # is rejected. The claim still counts toward k / df.
  fc <- drm_fisher_c_from_p(c(0.5, 0))
  expect_equal(fc$k, 2L)
  expect_equal(fc$df, 4L)
  expect_true(is.finite(fc$C))
  expect_equal(fc$C, -2 * sum(log(c(0.5, .Machine$double.xmin))))
  # huge C with df = 4 -> the SEM is rejected (tiny p.value)
  expect_lt(fc$p.value, 1e-8)
  # and it is strictly larger than if the p == 0 claim were (wrongly) dropped
  expect_gt(fc$C, drm_fisher_c_from_p(0.5)$C)
})

test_that("basis set excludes adjacent pairs and respects causal order", {
  obj <- structure(
    list(
      order = c("size", "abund"),
      endogenous = c("size", "abund"),
      exogenous = c("temp", "habitat"),
      edges = data.frame(
        from = c("temp", "temp", "size", "habitat"),
        to = c("size", "abund", "abund", "abund"),
        component = c("mu", "mu", "mu", "zi"),
        stringsAsFactors = FALSE
      )
    ),
    class = "drm_sem"
  )
  bs <- basis_set(obj)
  # habitat -> size is a legitimate missing-arrow claim
  expect_true(any(bs$x == "habitat" & bs$y == "size"))
  # temp is a direct parent of abund (mu) -> adjacent, no claim
  expect_false(any(bs$x == "temp" & bs$y == "abund"))
  # habitat targets zi of abund -> adjacent under any-component rule, no claim
  expect_false(any(bs$x == "habitat" & bs$y == "abund"))
})

test_that("Fisher's C reports how many claims were extreme or excluded (#41)", {
  # One underflowed claim dominates C. The floor is kept, but the user must be
  # able to tell a numerical rejection from a genuine one.
  fc <- drm_fisher_c_from_p(c(0.4, 1e-12, 0, 0.3), n_excluded = 2L)
  expect_equal(fc$k, 4L)
  expect_equal(fc$n_extreme, 2L)
  expect_equal(fc$n_excluded, 2L)
  clean <- drm_fisher_c_from_p(c(0.4, 0.3))
  expect_equal(clean$n_extreme, 0L)
  expect_equal(clean$n_excluded, 0L)
  expect_equal(drm_fisher_c_from_p(numeric(0))$n_extreme, 0L)
})

test_that("fisher_c() surfaces n_extreme and n_excluded from a drm_dsep (#41)", {
  bs <- data.frame(x = "a", y = "b", p.value = 1e-14, status = "ok")
  attr(bs, "fisher_c") <- drm_fisher_c_from_p(1e-14, n_excluded = 3L)
  class(bs) <- c("drm_dsep", "data.frame")
  out <- fisher_c(bs)
  expect_equal(out$n_extreme, 1L)
  expect_equal(out$n_excluded, 3L)
})

test_that("failed claims are named in a warning, not dropped silently (#41)", {
  bs <- data.frame(
    x = c("a", "b"), y = c("c", "c"),
    status = c("refit_failed", "ok"), stringsAsFactors = FALSE
  )
  expect_warning(
    n <- drm_warn_excluded_claims(bs),
    "refit_failed"
  )
  expect_equal(n, 1L)
  ok <- bs[2, ]
  expect_no_warning(n0 <- drm_warn_excluded_claims(ok))
  expect_equal(n0, 0L)
  # wrong_scale already has its own warning, so it is counted but not re-warned
  ws <- data.frame(x = "a", y = "c", status = "wrong_scale")
  expect_no_warning(nw <- drm_warn_excluded_claims(ws))
  expect_equal(nw, 1L)
})
