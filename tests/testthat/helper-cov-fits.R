# Shared, memoised drmTMB-backed fixtures for the effect / path / adapter tests.
# Fitting once per session (not once per test) keeps the suite fast. Every
# fixture is simulated from a known data-generating process so tests can assert
# recovery against the truth, not just that a call returns.

cov_cache <- new.env(parent = emptyenv())

cov_memo <- function(key, builder) {
  if (is.null(cov_cache[[key]])) {
    cov_cache[[key]] <- builder()
  }
  cov_cache[[key]]
}

# DGP "chain": x -> m -> y plus a direct x -> y arrow, Gaussian throughout.
#   g  : two-level factor
#   m  = 0.5 x + 0.4 (g == "B") + e_m,   e_m ~ N(0, 0.5^2)
#   y  = 0.3 x + 0.8 m + e_y,            e_y ~ N(0, exp(-0.2 + 0.3 x)^2)
# so d E[y] / d x (total) = 0.3 + 0.8 * 0.5 = 0.7, direct = 0.3, indirect = 0.4,
# and `sigma` of y moves with x.
cov_chain_dgp <- function(n = 300, seed = 20260901) {
  set.seed(seed)
  x <- stats::rnorm(n)
  g <- factor(sample(c("A", "B"), n, replace = TRUE))
  m <- 0.5 * x + 0.4 * (g == "B") + stats::rnorm(n, 0, 0.5)
  y <- 0.3 * x + 0.8 * m + stats::rnorm(n, 0, exp(-0.2 + 0.3 * x))
  data.frame(x, g, m, y)
}

cov_chain_sem <- function() {
  cov_memo("chain", function() {
    drm_sem(
      m = drm_node(drmTMB::bf(m ~ x + g), family = stats::gaussian()),
      y = drm_node(drmTMB::bf(y ~ x + m, sigma ~ x), family = stats::gaussian()),
      data = cov_chain_dgp()
    )
  })
}

# DGP "count": x -> m (Gaussian) -> cnt (nbinom2, log link).
#   cnt | x, m ~ NB2(mu = exp(0.4 + 0.5 m + 0.2 x), size = 2)
cov_count_dgp <- function(n = 300, seed = 20260902) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.6 * x + stats::rnorm(n, 0, 0.6)
  cnt <- stats::rnbinom(n, mu = exp(0.4 + 0.5 * m + 0.2 * x), size = 2)
  data.frame(x, m, cnt)
}

cov_count_sem <- function() {
  cov_memo("count", function() {
    drm_sem(
      m = drm_node(drmTMB::bf(m ~ x), family = stats::gaussian()),
      cnt = drm_node(drmTMB::bf(cnt ~ x + m), family = drmTMB::nbinom2()),
      data = cov_count_dgp()
    )
  })
}
