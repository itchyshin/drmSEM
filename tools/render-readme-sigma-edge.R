# Render the "what the dashed arrow means" figure — SAME system as the hero DAG.
# Run from the package root with: Rscript tools/render-readme-sigma-edge.R
#
# WHY THIS FIGURE EXISTS. The hero DAG already shows `temp` reaching `size`
# TWICE: a solid black arrow into the mean and a green dashed arrow into the
# spread. That is the whole distinctive claim of the package, drawn — but a
# reader has to take the dashed arrow on trust. This figure decodes it, on the
# SAME data generating process, so nothing on the page asks the reader to switch
# systems.
#
# The DGP is copied verbatim from tools/render-readme-hero.R (same seed, same n,
# same coefficients) so the two figures are provably the same example. If the
# hero's DGP changes, change it here too — that is the one maintenance cost of
# keeping them in lockstep, and it is worth paying to avoid a second unrelated
# example on the landing page.

required <- c("devtools", "drmTMB", "ggplot2", "patchwork", "ragg", "png", "grid", "igraph")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}
devtools::load_all(".", quiet = TRUE)

# ---- 1. The canonical DGP, identical to render-readme-hero.R ---------------
set.seed(42)
n <- 300L
temp <- stats::rnorm(n)
habitat <- factor(sample(c("A", "B"), n, replace = TRUE))
hb <- as.integer(habitat == "B")
size <- stats::rnorm(n, mean = 0.3 + 0.6 * temp + 0.4 * hb, sd = exp(-0.3 + 0.4 * temp))
mu_abundance <- exp(0.5 + 0.3 * size + 0.2 * temp)
zi_abundance <- stats::plogis(-1 + 1.5 * hb)
abundance <- stats::rnbinom(n, mu = mu_abundance, size = 2)
abundance[stats::runif(n) < zi_abundance] <- 0L
p_survival <- stats::plogis(-0.5 + 0.02 * abundance + 0.5 * size)
alive <- stats::rbinom(n, size = 10L, prob = p_survival)
dat <- data.frame(temp, habitat, size, abundance, alive, dead = 10L - alive)

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
fit <- sem$nodes[["size"]]
cf <- stats::coef(fit)

# ---- 2. Fitted size distribution across temperature -------------------------
# Habitat held at its reference level; temperature at its 10th / 50th / 90th
# percentile, so the three panels are real positions in the data rather than
# arbitrary round numbers.
tq <- stats::quantile(dat$temp, c(0.1, 0.5, 0.9))
cells <- data.frame(
  temp = as.numeric(tq),
  lab = c("cool (10th pct)", "typical (median)", "warm (90th pct)")
)
cells$mu <- cf$mu[["(Intercept)"]] + cf$mu[["temp"]] * cells$temp
cells$sd <- exp(cf$sigma[["(Intercept)"]] + cf$sigma[["temp"]] * cells$temp)
cells$lab <- factor(cells$lab, levels = cells$lab)

gx <- seq(min(cells$mu) - 3.4 * max(cells$sd), max(cells$mu) + 3.4 * max(cells$sd),
  length.out = 500
)
dens <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  data.frame(
    x = gx, y = stats::dnorm(gx, cells$mu[i], cells$sd[i]),
    lab = cells$lab[i]
  )
}))

mu_col <- "#000000" # drm_component_style("mu")$col is the NAME "black"
sig_col <- drm_component_style("sigma")$col

# Neutral grey fill: the package's sigma teal means "the sigma component" in the
# DAG's key, and these curves are the joint result of BOTH the mu and sigma
# edges. Colouring them teal would say "sigma only" and collide with that key.
p <- ggplot2::ggplot(dens, ggplot2::aes(x = x, y = y)) +
  ggplot2::geom_area(fill = "grey88", colour = "grey35", linewidth = 0.5) +
  ggplot2::facet_wrap(~lab, nrow = 1) +
  ggplot2::geom_text(
    data = cells,
    ggplot2::aes(x = mu, y = 0, label = sprintf("mean %.2f\nSD %.2f", mu, sd)),
    inherit.aes = FALSE, vjust = -0.4, size = 3.1, colour = "grey25"
  ) +
  ggplot2::labs(
    title = "What the dashed arrow means",
    subtitle = "Fitted distribution of size across temperature, from the model above",
    x = "Size", y = NULL
  ) +
  ggplot2::scale_y_continuous(breaks = NULL) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.y = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold", size = 13),
    plot.subtitle = ggplot2::element_text(size = 9.6, colour = "grey30"),
    plot.caption = ggplot2::element_text(hjust = 0, size = 8.4, colour = "grey35"),
    strip.text = ggplot2::element_text(size = 9.6, colour = "grey15")
  ) +
  ggplot2::labs(caption = paste(
    sprintf(
      "Same simulated example as the diagram above (n = %d), fitted with drmSEM on a live drmTMB engine.",
      n
    ),
    sprintf(
      "The solid arrow temp -> size is the mean sliding right (%.2f -> %.2f).",
      cells$mu[1], cells$mu[3]
    ),
    sprintf(
      "The dashed arrow temp -> sigma(size) is the curve widening (SD %.2f -> %.2f) -- a mean-only SEM cannot draw it.",
      cells$sd[1], cells$sd[3]
    ),
    sep = "\n"
  ))

out_dir <- file.path("man", "figures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 3. The DAG, rendered from the SAME fitted object ----------------------
# plot.drm_sem() is base graphics, so it cannot enter patchwork directly; render
# it to a raster and wrap it. It gets roughly half the figure width here, so its
# two legends stay legible -- the reason an earlier inset attempt was abandoned.
dag_png <- tempfile(fileext = ".png")
# SMALLER canvas at the SAME resolution. plot.drm_sem() hardcodes both legends at
# cex = 0.8 with no argument to override, so the only lever on their size is the
# canvas: text is fixed in POINTS, so shrinking the device makes every label a
# larger fraction of it, and patchwork then scales the whole raster up to panel
# width. Node labels ride along, which is why vertex.size rises to match.
ragg::agg_png(dag_png, width = 1500, height = 1150, units = "px", res = 200, background = "white")
graphics::par(mar = c(0.2, 0.2, 2.4, 0.2), family = "sans")
plot(
  sem,
  main = "temp reaches size twice",
  cex.main = 1.15,
  # asp = 1 (igraph's default) is RESTORED. Setting asp = 0 to reclaim canvas
  # width broke two things Florence caught by pixel inspection: six of the eight
  # edges lost their arrowheads (they meet the node tangentially and igraph's
  # arrow geometry assumes asp = 1), and two of five nodes rendered as ellipses.
  # A causal diagram whose arrows have no heads is a correctness failure, not a
  # polish issue. The real fix for the wasted width is a NEAR-SQUARE canvas, so
  # the square plot region asp = 1 enforces fills most of it.
  # Legends are drawn at fixed top-left and bottom-left corners, so keep both
  # clear: `temp` sits mid-left rather than top-left.
  layout = rbind(
    temp = c(-1.00, 0.10), size = c(-0.05, 0.92),
    abundance = c(0.00, -1.00), habitat = c(1.00, 0.60), survival = c(1.00, -0.85)
  ),
  # vertex.size raised so the longest label ("abundance") fits inside its circle.
  vertex.size = 46, vertex.label.cex = 1.05, edge.width = 2.0, edge.arrow.size = 0.7
)
grDevices::dev.off()
# --- DAG as its OWN image -------------------------------------------------
# It is rendered near-square and written directly, NOT wrapped into a composite:
# pkgdown scales each image to the column width, so a square sharing a composite
# with a wide panel can only ever use a fraction of it. Alone, it fills the column.
dag_out <- file.path(out_dir, "drmsem-dag.png")
file.copy(dag_png, dag_out, overwrite = TRUE)

# --- The decode as its own image ------------------------------------------
spread_out <- file.path(out_dir, "drmsem-spread.png")
ragg::agg_png(spread_out, width = 1500, height = 780, units = "px", res = 200, background = "white")
print(p)
grDevices::dev.off()

message("\n--- the two temp -> size edges this figure decodes ---")
print(as.data.frame(paths(sem))[1:3, c("from", "to", "component", "estimate", "std.error")])
message("Wrote ", normalizePath(dag_out))
message("Wrote ", normalizePath(spread_out))
