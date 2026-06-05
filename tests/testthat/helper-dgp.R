# Simulate a known size -> abundance -> survival DAG for integration tests.
# size:      gaussian, mu ~ temp + habitat, sigma ~ temp
# abundance: nbinom2,  mu(log) ~ size + temp,  zi(logit) ~ habitat
# survival:  binomial, mu(logit) ~ abundance + size
simulate_drmsem_dgp <- function(n = 400, seed = 1) {
  set.seed(seed)
  temp <- stats::rnorm(n)
  habitat <- factor(sample(c("A", "B"), n, replace = TRUE))
  hb <- as.integer(habitat == "B")

  size <- stats::rnorm(n, mean = 0.3 + 0.6 * temp + 0.4 * hb,
                       sd = exp(-0.3 + 0.4 * temp))
  mu_ab <- exp(0.5 + 0.3 * size + 0.2 * temp)
  zi <- stats::plogis(-1 + 1.5 * hb)
  abundance <- stats::rnbinom(n, mu = mu_ab, size = 2)
  abundance[stats::runif(n) < zi] <- 0L

  p_surv <- stats::plogis(-0.5 + 0.02 * abundance + 0.5 * size)
  trials <- 10L
  alive <- stats::rbinom(n, size = trials, prob = p_surv)
  dead <- trials - alive

  data.frame(temp, habitat, size, abundance, alive, dead)
}
