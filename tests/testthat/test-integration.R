# End-to-end tests that require the drmTMB engine. Skipped where unavailable
# (e.g. CRAN-style checks without compilation); run in the Codex cloud env.

skip_if_not_installed("drmTMB")

make_sem <- function() {
  dat <- simulate_drmsem_dgp(n = 300, seed = 11)
  drm_sem(
    size = drm_node(
      drmTMB::bf(size ~ temp + habitat, sigma ~ temp),
      family = stats::gaussian()
    ),
    abundance = drm_node(
      drmTMB::bf(abundance ~ size + temp, zi ~ habitat),
      family = drmTMB::nbinom2()
    ),
    survival = drm_node(
      drmTMB::bf(cbind(alive, dead) ~ abundance + size),
      family = drmTMB::beta_binomial()
    ),
    data = dat
  )
}

test_that("drm_sem builds a valid DAG with component-labelled edges", {
  sem <- make_sem()
  expect_s3_class(sem, "drm_sem")
  expect_equal(sem$order, c("size", "abundance", "survival"))
  # the zi ~ habitat and sigma ~ temp edges are recovered with the right component
  expect_true(any(sem$edges$component == "zi" & sem$edges$term == "habitat"))
  expect_true(any(sem$edges$component == "sigma" & sem$edges$term == "temp"))
})

test_that("paths() returns a component-labelled coefficient table", {
  sem <- make_sem()
  p <- paths(sem)
  expect_true(all(c("from", "to", "component", "estimate") %in% names(p)))
  expect_true(any(p$component == "zi"))
})

test_that("d-separation flags a true omitted edge and Fisher's C runs", {
  # omit the real size -> survival arrow; d-sep should detect it
  dat <- simulate_drmsem_dgp(n = 300, seed = 11)
  sem <- drm_sem(
    size = drm_node(drmTMB::bf(size ~ temp + habitat), family = stats::gaussian()),
    survival = drm_node(drmTMB::bf(cbind(alive, dead) ~ temp),
                        family = drmTMB::beta_binomial()),
    data = dat
  )
  d <- dsep(sem)
  claim <- d[d$x == "size" & d$y == "survival", ]
  expect_true(nrow(claim) == 1L)
  expect_lt(claim$p.value, 0.05)
  fc <- fisher_c(sem)
  expect_true(is.finite(fc$fisher_c))
})

test_that("effects run and total decomposes into direct + indirect", {
  sem <- make_sem()
  de <- direct_effects(sem, from = "temp", to = "survival", B = 50)
  expect_s3_class(de, "drm_effect")
  # Effects must stay finite even when a node's sdreport returned NaN SEs:
  # drm_draw_beta() falls back to the point estimate for non-finite vcov blocks.
  expect_true(is.finite(de$estimate))
  ie <- indirect_effects(sem, from = "temp", to = "survival", B = 40, n_sim = 20)
  expect_true(all(c("total_path", "direct", "indirect",
                    "distribution_mediated") %in% ie$quantity))
  expect_true(all(is.finite(ie$estimate)))
})
