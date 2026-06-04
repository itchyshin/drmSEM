# d-separation graph logic and Fisher's C (no drmTMB required).

test_that("Fisher's C combines p-values with 2k df", {
  fc <- drm_fisher_c_from_p(c(0.5, 0.5))
  expect_equal(fc$df, 4L)
  expect_equal(fc$C, -2 * sum(log(c(0.5, 0.5))))
  expect_equal(fc$k, 2L)
})

test_that("basis set excludes adjacent pairs and respects causal order", {
  obj <- structure(list(
    order = c("size", "abund"),
    endogenous = c("size", "abund"),
    exogenous = c("temp", "habitat"),
    edges = data.frame(
      from = c("temp", "temp", "size", "habitat"),
      to   = c("size", "abund", "abund", "abund"),
      component = c("mu", "mu", "mu", "zi"),
      stringsAsFactors = FALSE
    )
  ), class = "drm_sem")
  bs <- basis_set(obj)
  # habitat -> size is a legitimate missing-arrow claim
  expect_true(any(bs$x == "habitat" & bs$y == "size"))
  # temp is a direct parent of abund (mu) -> adjacent, no claim
  expect_false(any(bs$x == "temp" & bs$y == "abund"))
  # habitat targets zi of abund -> adjacent under any-component rule, no claim
  expect_false(any(bs$x == "habitat" & bs$y == "abund"))
})
