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
