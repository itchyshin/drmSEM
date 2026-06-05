# Render the README hero DAG from a live drmTMB fit of the canonical example.
# Run from the package root with: Rscript tools/render-readme-hero.R

required <- c("devtools", "drmTMB", "igraph", "ragg")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

devtools::load_all(".", quiet = TRUE)

set.seed(42)
n <- 300L
temp <- stats::rnorm(n)
habitat <- factor(sample(c("A", "B"), n, replace = TRUE))
hb <- as.integer(habitat == "B")

size <- stats::rnorm(
  n,
  mean = 0.3 + 0.6 * temp + 0.4 * hb,
  sd = exp(-0.3 + 0.4 * temp)
)

mu_abundance <- exp(0.5 + 0.3 * size + 0.2 * temp)
zi_abundance <- stats::plogis(-1 + 1.5 * hb)
abundance <- stats::rnbinom(n, mu = mu_abundance, size = 2)
abundance[stats::runif(n) < zi_abundance] <- 0L

p_survival <- stats::plogis(-0.5 + 0.02 * abundance + 0.5 * size)
trials <- 10L
alive <- stats::rbinom(n, size = trials, prob = p_survival)
dead <- trials - alive

dat <- data.frame(temp, habitat, size, abundance, alive, dead)

sem <- drm_sem(
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

out_dir <- file.path("man", "figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out <- file.path(out_dir, "drmsem-hero-dag.png")

ragg::agg_png(
  out,
  width = 1600,
  height = 950,
  units = "px",
  res = 170,
  background = "white"
)
graphics::par(mar = c(0.5, 0.5, 2.2, 0.5), family = "sans")
plot(
  sem,
  main = "Distributional piecewise SEM",
  vertex.label.cex = 0.78,
  edge.width = 1.8,
  edge.arrow.size = 0.45
)
grDevices::dev.off()

message("Wrote ", normalizePath(out))
