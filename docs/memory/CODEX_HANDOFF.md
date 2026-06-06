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

drmSEM 0.2.0 released, and `main` is now on the `0.2.0.9000` dev line. The merged
post-0.1/0.2 surface includes **OQ-12** unified effect API
(`method`/`uncertainty`/`nsim`/`population`, deprecated `mediation`/`draw`/
`n_sim`), **OQ-14** covariance-edge *grammar* (`covary()`/`covariances()`/
covariance-aware d-sep), analytic effect cross-checks (V-26..V-30),
standardization conventions (OQ-4), **OQ-6** calibration scaffold,
**0.3** composite constructs (`drm_composite()`/`loadings()`), **OQ-5**
per-mediator, per-component, and natural path attribution (`path_effects()`),
and the GitHub Pages deploy fix. The pure-R surface is kernel-validated unless
the ledger names a live-fit gate.

## P0 — live-engine closeout for the next dev slice

1. **DONE 2026-06-06 — OQ-6 Fisher's C calibration study.**
   `Rscript inst/calibration/generate.R` produced
   **`inst/calibration/calibration-results.rds`** (`drmTMB` 0.1.3.9000,
   `drmTMB` Git SHA `17b1321`, `drmSEM` 0.2.0.9000, git SHA `c951d31`,
   14,400 replicates) and
   `vignettes/calibration.Rmd` rendered from the source-tree cache. All five
   C1-C5 checks in `cal$acceptance` passed, so **V-17 -> validated** for the
   OQ-6 grid only. Keep future Fisher's C / d-sep claims scoped to that grid
   unless new calibration scenarios are added.
2. **Flip the remaining kernel tiers to *validated*.** Integration tests on a live fit that
   promote **V-7** (distribution-mediated mechanism) and the d-sep claims from
   "kernel-validated" -> "validated" — run the `test-analytic-effects.R` identities
   through a real `drm_sem()` fit, not just hand-built engines.
3. **OQ-4 — standardization `sigma_E` term.** `R/standardize.R`'s `latent` divisor
   omits the distribution-specific theoretical variance (`pi^2/3` logit, etc.) for
   non-identity-link **`mu`** paths -> mild over-standardization. Add it, cross-check
   on a live GLM fit, update `test-standardize.R`. Spec: `docs/design/08-standardization.md`.

## P1 — feature completion needing a live fit

4. **OQ-5 follow-up.** Per-component **sigma-vs-zi** attribution and the
   **natural** per-mediator variant with a **recanting-witness** guard now ship
   and are kernel-validated (V-34/V-35). Remaining live-fit work: return **`NA`**
   for mean-fallback/unconfirmed-sampler families where attribution is not
   defensible, and add a `path_effects()` integration test on the canonical fit.
   Spec: `OQ-5`, `DECISIONS.md` D-17/D-19,
   `docs/design/02-effect-calculus.md`.
5. **OQ-14 — bivariate joint fit.** Grammar **and** the pure-R bivariate-node
   *declaration* now ship (`R/pair.R`): **`drm_pair()`** records the bivariate
   node, **`drm_expand_pair()`** bridges it to two `drm_node()` sub-nodes + the
   `covary()` edges, and **`rho12()` / `corpairs()`** return the declared edges
   with an `NA` estimate. The engine work remaining: a **live bivariate drmTMB
   fit** that estimates `rho12` jointly (replacing the two independent node fits
   in `drm_expand_pair()`), wired into `drm_sem()`; **`rho12(fit)` /
   `corpairs(fit)`** returning a real (non-`NA`) `estimate` read back from that
   fit (hook: a `drm_fit_rho12()` extractor in the adapter); and **deep
   level-compatibility validation** against the fitted RE blocks. Double-headed
   (`rho12`) / dashed (`corpair`) arc plotting already ships in the Claude lane
   (`plot.drm_sem`, `show = "all"`). Do **not** fake the joint estimate — keep
   `estimate = NA` until a real fit supplies it. Spec:
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
8b. **Effect-interval honesty (from the 2026-06-06 decomposition audit).** Two
    secondary engine-review findings, not decomposition-specific, need a live fit
    to fix/validate: (i) `drm_draw_beta()` silently falls back to the point
    estimate for a node whose `vcov` is non-PD / `NULL` (or non-convergent per
    `drm_fit_converged()`, which the effect path never consults), so that node
    contributes **zero** parameter uncertainty and the reported interval is too
    narrow with **no flag** — surface a `drm_warn_once`/attribute. (ii) `log`-link
    `drm_inv_link` can overflow to `Inf` on an extreme MVN draw; the resulting NA
    is dropped by `na.rm` in `drm_effect_contrast`, biasing the average over a
    shrinking row set — clamp `eta` or count/flag dropped rows. The pairing bug
    and the framing/over-claims from that audit are already fixed in the Claude
    lane (`drm_decomp_legs()`, V-36..V-41).
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
