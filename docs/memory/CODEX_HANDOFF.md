# Codex handoff — tasks that need a live drmTMB environment

This file lists work the Codex team (running in a cloud env that can compile
drmTMB/TMB) should do, because the Claude Code lane that built drmSEM 0.1 and the
post-0.1 increments **cannot**: it has no R or compiler in-container, so it
validates everything through CI and pure-R kernel tests. Every item below needs a
**live drmTMB fit** (or rendering, or drmTMB-repo access).

Coordinate on a separate branch; the launchable team is mirrored in
`.codex/agents/*.toml` (Ada/Gauss/Curie/Fisher/Florence/Grace/Rose…). Update
`docs/memory/` (`AGENT_LOG.md`, `VALIDATION_LEDGER.md`, `DECISIONS.md`,
`OPEN_QUESTIONS.md`) as you go.

## What shipped (pure-R / CI-green) up to this handoff

drmSEM 0.1.0 released; then, on the `0.1.0.9000` dev line (all merged, CI-green on
3 OSes): **OQ-12** unified effect API (`method`/`uncertainty`/`nsim`/`population`,
deprecated `mediation`/`draw`/`n_sim`), **OQ-14** covariance-edge *grammar*
(`covary()`/`covariances()`/covariance-aware d-sep), **0.2** analytic effect
cross-checks (V-26..V-30) + standardization conventions (OQ-4) + calibration
scaffold (OQ-6), **0.3** composite constructs (`drm_composite()`/`loadings()`),
**OQ-5** per-mediator + per-channel path attribution (`path_effects()`), and the
GitHub Pages deploy fix. The whole pure-R surface is kernel-validated.

## P0 — close out 0.2 (gates the 0.2.0 tag)

1. **OQ-6 — run the Fisher's C calibration study.** `Rscript inst/calibration/generate.R`
   (engine-gated, self-contained) → produce **`inst/calibration/calibration-results.rds`**;
   confirm `vignettes/calibration.Rmd` renders from the cache. Design + acceptance
   criteria are in the vignette / `OQ-6`: DGP ladder (mean-only / distributional
   `zi`+`sigma` / cross-link), `n in {100,250,500,1000}`; the centrepiece diagnostic
   is empirical Type-I **stratified by augmented-component count `q`**. Promote
   **V-17 -> validated** only when criteria 1-5 pass. Until then no doc may call the
   d-sep test "validated/calibrated/near nominal".
2. **Flip the kernel tiers to *validated*.** Integration tests on a live fit that
   promote **V-7** (distribution-mediated mechanism) and the d-sep claims from
   "kernel-validated" -> "validated" — run the `test-analytic-effects.R` identities
   through a real `drm_sem()` fit, not just hand-built engines.
3. **OQ-4 — standardization `sigma_E` term.** `R/standardize.R`'s `latent` divisor
   omits the distribution-specific theoretical variance (`pi^2/3` logit, etc.) for
   non-identity-link **`mu`** paths -> mild over-standardization. Add it, cross-check
   on a live GLM fit, update `test-standardize.R`. Spec: `docs/design/08-standardization.md`.

## P1 — feature completion needing a live fit

4. **OQ-5 follow-up.** (a) per-component **sigma-vs-zi** split: add a one-arg
   `freeze` to `drm_propagate` (hold one component of a mediator at its x0 value),
   so `path_effects(by="component")` can split the distributional channel by
   component; return **`NA`** for mean-fallback families. (b) the **natural**
   per-mediator variant with a **recanting-witness** guard. (c) a `path_effects()`
   integration test on the canonical fit. Spec: `OQ-5`, `DECISIONS.md` D-17,
   `docs/design/02-effect-calculus.md`.
5. **OQ-14 — bivariate joint fit.** Grammar ships; still need a **live bivariate
   drmTMB fit** for: **`drm_pair()`** joint node, **`rho12(fit)` / `corpairs(fit)`**
   read-back accessors, **double-headed/dashed-arc plotting** in
   `plot(sem, show="all")`, and **deep level-compatibility validation**. Spec:
   `docs/design/07-bivariate-covariance-edges.md`.
6. **0.3 composites — integration test.** Confirm `drm_composite()` +
   `drm_sem(composites=)` fits end-to-end and `loadings()`/d-sep behave; document
   the indicator-intervention limitation. `docs/design/09-latent-variables.md`.

## P2 — robustness / parameterization

7. **OQ-1 / V-19** — confirm family-sampler parameterizations against
   `drmTMB::simulate()`: `zero_one_beta` (zoi/coi), `tweedie` (mean-fallback),
   beta_binomial trials. Extend `test-oq1-samplers.R`.
8. **OQ-7** — root-cause the `sdreport` NaN on the canonical n=300 DGP (recondition
   or confirm a drmTMB robustness gap; file upstream). `docs/memory/DRMTMB_ISSUES.md`.
9. **`plot.drm_sem` visual polish** (needs rendering): standardized-coefficient
   edge labels + significance encoding without colliding with the component
   linetype; CI smoke test (`pdf(NULL); plot(sem); dev.off()`). `R/plotting.R`.

## P3 — release

10. **CRAN.** drmTMB must be on CRAN first; then drop `Remotes:` from `DESCRIPTION`
    (CRAN forbids it), keep `drmTMB` in `Suggests` (engine use is
    `requireNamespace`-guarded), get `R CMD check --as-cran` clean. The Claude lane
    has added runnable / `\dontrun` examples for the exported functions.
11. **0.4** — joint multivariate SEM / reflective latent measurement models (need a
    joint likelihood; deliberately out of scope for 0.x piecewise).

## What does NOT need Codex
Everything pure-R/logic and ggplot2 (the effect kernels, grammar layers, d-sep
graph logic, recovery/analytic tests, standardization math) is already validated
and stays in the Claude Code lane via CI.
