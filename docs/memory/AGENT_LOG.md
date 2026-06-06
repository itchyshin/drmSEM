# AGENT LOG — drmSEM

Chronological log of meaningful agent work. Newest entries at the bottom. Leave
enough context for the next agent to continue without rediscovering the problem
(AGENTS.md, Multi-Agent Collaboration).

---

## 2026-06-04 — Bootstrap (Stage 0): scaffold + full R core + tests + memory

**Orchestrated by Ada**, with the standing review roles (Boole, Gauss, Noether,
Darwin, Florence, Fisher, Pat, Jason, Curie, Emmy, Grace, Rose).

**What shipped.**
- Stage 0 package scaffold (DESCRIPTION, NAMESPACE, LICENSE, README, `.github/`,
  `CLOUD.md`, `AGENTS.md`, vignettes/man stubs).
- Full R core — 13 files under `R/`:
  `drmSEM-package.R`, `drm_node.R`, `drm_sem.R` (declarative + `drm_psem` core),
  `edges.R`, `extractors.R` (the drmTMB adapter), `utils.R`, `paths.R`,
  `dsep.R`, `effects.R`, `simulate_effects.R`, `standardize.R`, `diagnostics.R`
  (`check_sem`), `plotting.R`.
- Tests under `tests/testthat/`: `helper-dgp.R` (the canonical
  `size -> abundance -> survival` DGP), `test-utils.R`, `test-dsep-kernels.R`,
  `test-effect-kernels.R` (pure-logic), and `test-integration.R` (drmTMB-gated).
- Design docs `docs/design/00-charter.md`, `01-semantics.md`,
  `02-effect-calculus.md`, `03-dsep.md`, `04-validation-plan.md`,
  `05-roadmap.md`.
- Project memory `docs/memory/`: `PROJECT_MEMORY.md`, `DECISIONS.md`,
  `VALIDATION_LEDGER.md`, `OPEN_QUESTIONS.md`, and this log.

**Validation state.**
- R 4.3.3 in the dev container; all 13 R/ source files parse clean.
- **18/18 pure-logic kernel tests PASS** locally: predictor extraction
  (bar/marker dropping), topological sort + cycle detection, ancestors + simple
  paths, Fisher's C, basis-set construction under the any-component rule, inverse
  links, family samplers (incl. zero-inflation), and — load-bearing — the
  distribution-mediated mechanism (contrast = 0.99 when a mediator's `sigma`
  depends on x, ~0 when `sigma` is constant).
- **drmTMB-integration tests are WRITTEN but PENDING runtime.** The dev
  container's network allowlist blocks CRAN/Posit/r-universe (`host_not_allowed`),
  so TMB and drmTMB cannot be installed/compiled here. They run in the Codex
  cloud env via `CLOUD.md`. The drmTMB adapter (`R/extractors.R`) was written
  against drmTMB 0.1.3.9000 real source.

**Locked decisions recorded** in `DECISIONS.md`: D-1 interface = both
(`drm_psem` core / `drm_sem` wrapper), D-2 d-separation = any modelled component,
D-3 effects = simulation (never coefficient products), plus D-4 naming, D-5
igraph for layout only, D-6 `model.matrix()` coding assumption.

**Open items** (see `OPEN_QUESTIONS.md`): exact drmTMB family-sampler
parameterizations (OQ-1), `model.matrix()` vs drmTMB contrast coding (OQ-2),
node-name vs response-var matching for `cbind()` (OQ-3), standardization
conventions (OQ-4), path-specific effect attribution (OQ-5), Fisher's C
calibration (OQ-6).

**Next for the following agent.** Run the cloud env (full internet) to install
drmTMB and execute `test-integration.R`. Confirm OQ-1 (family parameterizations)
and OQ-2 (contrast coding) against a live fit, then flip V-7/V-9/V-10 to
"validated" and V-11/V-12/V-13 from "pending" in `VALIDATION_LEDGER.md`. Do not
re-architect the engine/layer split or the locked decisions without a task,
evidence, and review.

(Authoring of the design docs and project memory in this entry by
Darwin + Rose, per the standing roles.)

## 2026-06-04 - Push, draft PR #1, CI hardening (Ada/Grace)

- Pushed branch `claude/distributional-sem-tmb-evbmH`; opened draft PR
  itchyshin/drmSEM#1. Subscribed to PR activity for CI/review events.
- Environment note: the dev sandbox network allowlist blocks CRAN, Posit,
  r-universe, and api.github.com (host_not_allowed); GitHub git/codeload is
  allowed. So drmTMB/TMB cannot be installed or compiled here, and CI cannot
  be polled from the sandbox. We rely on the PR-activity webhook (delivers CI
  failures) and act on those.
- Grace: the standard r-lib workflow does not run document(), and no man/*.Rd
  is committed, which would fail R CMD check on undocumented objects. Added an
  `any::roxygen2` dep and a `roxygen2::roxygenise()` step before check so man/
  and NAMESPACE are generated in CI.
- The vignette's model-fitting chunks are set to `eval = FALSE` (illustrative)
  while drmTMB-integration is pending validation, so vignette build is not a
  failure surface. Integration test-integration.R still runs in CI when drmTMB
  installs, serving as the integration validation.

## 2026-06-04 — Launchable agent roster mirrored (.codex + .claude)

**Orchestrated by Ada.**

**What shipped.**
- Materialized the 13 standing review roles from `AGENTS.md` as launchable
  agents in two mirrored directories: `.codex/agents/<slug>.toml` (Codex) and
  `.claude/agents/<slug>.md` (Claude Code). One-to-one, with **verbatim-identical
  instruction bodies** (generated from a single shared body per agent and diff-
  verified). Role→slug map recorded in the `AGENTS.md` Multi-Agent Collaboration
  table (e.g. Ada=`orchestrator-integrator`, Curie=`simulation-tester`,
  Rose=`systems-auditor`).
- Each body re-scopes the drmTMB persona to drmSEM: opens "You are <Persona>, the
  <role> for drmSEM", states the observed-variable/piecewise/DAG-only scope, the
  role's primary questions, and the concrete files/skills to consult. Review-only
  roles get read tools (Read, Grep, Glob); engineer/tester/orchestrator roles get
  Bash/Edit/Write as needed.
- Updated `AGENTS.md`: the mirror paragraph now says the agents exist (was "when
  added") and carries the role→slug table.

**Mirror rule (enforce going forward).** Changing any agent updates BOTH
`.codex/agents/<slug>.toml` and `.claude/agents/<slug>.md` in the same commit;
bodies must stay byte-identical. Rose audits this.

**Verified.** All 13 `.md`/`.toml` body pairs diffed identical. All `R/*.R` and
`tests/**/*.R` parse cleanly under R 4.3.3. Full `devtools::test()` /
`R CMD check` not run locally: CRAN is unreachable in this container and drmTMB
needs TMB compilation, so the suite runs in CI (`.github/workflows/R-CMD-check.yaml`).

## 2026-06-04 — Independent kernel re-verification (Gauss/Curie)

Ran a base-R-only harness (no testthat/MASS/cli/drmTMB needed) that sources
`R/simulate_effects.R` and re-checks the effect kernels outside the test suite.
All pass; the distribution-mediated effect reproduces independently (+0.99 when a
mediator's sigma rises in x, ≈0 when constant). Recorded under VALIDATION_LEDGER
"Independent kernel re-verification". Confirmed all `R/*.R` + tests parse under
R 4.3.3. drmTMB-integration + OQ-1/OQ-2 still require the cloud env (no CRAN/TMB
in this container).

## 2026-06-04 — CI evidence triage + NaN-vcov robustness fix (Ada/Gauss/Curie)

PR #1 CI (run 26981892600) went green on 3 OSes; read the ubuntu job log to
verify it was real, not skipped: `FAIL 0 | WARN 3 | SKIP 0 | PASS 39`, nodes
fitted with live drmTMB. Promoted V-10/11/12/13/20 to validated and largely
resolved OQ-2 in the ledger. Found + fixed a latent bug: `drm_draw_beta()` drew
from NaN vcov blocks (from sdreport `NaNs produced`), which would poison effects;
now falls back to the per-component point estimate. Strengthened the effect
integration test to assert `is.finite(estimate)`. Logged the sdreport NaN itself
as OQ-7 (root cause still needs a live drmTMB bisect).

## 2026-06-04 — OQ-1 closed: sampler parameterization (Gauss/Fisher/Curie)

Used a CI introspection probe (CI run 26982805627) to read drmTMB's
predict_parameters()/simulate() shapes and fitted (mu, sigma), then deduced that
drmTMB's sigma is SD-like with dispersion = 1/sigma^2. Fixed drm_sample_family()
for nbinom2/truncated_nbinom2 (size=1/sigma^2) and beta (phi=1/sigma^2);
lognormal/Gamma were already correct. Replaced the probe with an asserting
moment-recovery test (test-oq1-samplers.R). Recorded as D-7; OQ-1 resolved;
V-19 validated pending this commit's CI. Recovery suite (V-14/15/16) passed in the
prior run (PASS 66, FAIL 0). OQ-7 (sdreport NaN) still open.

## 2026-06-04 — OQ-1 fully confirmed; effect-decomposition plot added (Jason/Florence/Gauss)

CI runs 26983330989 / 26983569684 drove OQ-1 to closure: gaussian, poisson,
nbinom2, beta, lognormal samplers all PASS against live drmTMB (PASS 74/FAIL 1);
the only remaining failure was the Gamma *link* (stats::Gamma defaults to
"inverse"; drmTMB needs link="log"), now fixed. drmTMB's error confirmed Gamma
sigma = CV, validating the existing shape=1/sigma^2 sampler (D-9). Two earlier
self-inflicted failures: drmTMB::poisson/Gamma (not exported -> stats::), then the
Gamma link. Added plot.drm_effect() (ggplot2-gated forest plot of the
direct/mean-mediated/distribution-mediated/total decomposition) + test-plotting.R;
landscape scan (D-8) shows no peer plots this. pkgdown: flatly+teal theme, README
badges, pages URL. V-17 calibration test still queued (separate push).

## 2026-06-04 — Vignettes, calibration, pkgdown deploy (parallel agents)

Two general-purpose subagents authored, in parallel (non-conflicting new files),
`vignettes/effect-decomposition.Rmd` (marquee: the direct/mean-mediated/
distribution-mediated/total decomposition; the forest plot renders live via a
hand-built drm_effect, engine chunks gated eval=has_engine) and
`vignettes/comparison.Rmd` (drmSEM vs lavaan/piecewiseSEM/glmmTMB/dsem; prose +
table, nothing evaluated). Added: V-17 calibration test (test-calibration.R:
d-sep Type-I rate + power over 20 reps); `.github/workflows/pkgdown.yaml` (deploy
on main/release only, no PR impact); `docs/memory/DRMTMB_ISSUES.md` (upstream
tracker — can't file on drmTMB from this scope; none confirmed yet). Wired
plot.drm_effect + the two articles into _pkgdown.yml.

## 2026-06-04 — drmSEM 0.1 feature-complete and green

Authoritative check (MCP get_check_runs) on run 26984153215: all three OS jobs
success; PASS 83 / FAIL 0. The package now has: node/sem/psem builders;
component-labelled paths(); any-component d-sep + Fisher's C; simulation-based
direct/indirect/total effects with the distribution-mediated decomposition;
validated family samplers (OQ-1 closed); plot.drm_sem (DAG) + plot.drm_effect
(decomposition forest plot, an ecosystem first); recovery (V-14/15/16) +
calibration (V-17) tests; three vignettes; a themed pkgdown site + deploy
workflow; the agent operating kit mirrored to .codex/.claude. Note: the CI
monitor's per-job conclusion grep mis-parses GitHub's nested JSON — verify CI via
the MCP check-runs API, not the monitor's SUCCESS/FAILURE line.

## 2026-06-04 — pkgdown source-docs fix before first merge (Grace/Ada)

PR #1's pkgdown check failed because the workflow used pkgdown's default
`docs/` destination, but this repo already uses `docs/` for source design and
memory files. Moved generated site output to `pkgdown-site/`, ignored and
R-build-ignored that directory, and changed deploy to publish `pkgdown-site/`.
Committed generated `man/*.Rd` files plus the roxygen-generated NAMESPACE so
GitHub installs and users see the same source documentation. Local verification:
`R CMD INSTALL .` passed; `pkgdown::build_site_github_pages(dest_dir =
"pkgdown-site", new_process = FALSE, install = FALSE)` passed. Local warning
only: glmmTMB was built against TMB 1.9.17 while the local TMB is 1.9.21.

## 2026-06-04 — README hero DAG rendered locally (Ada/Florence/Grace)

Picked up issue #2 task 5 from the local-computer lane. Added
`tools/render-readme-hero.R`, which fits the canonical `size -> abundance ->
survival` example with live drmTMB and renders a component-labelled DAG to
`man/figures/drmsem-hero-dag.png`. Florence/Pat visual check: the first render
clipped the `abundance` label; the committed render uses smaller node labels and
the final PNG was inspected directly. Grace evidence: `Rscript
tools/render-readme-hero.R` passed; `pkgdown::build_site()` passed and copied the
hero image into `pkgdown-site/reference/figures/`; the generated homepage
contains the image and all three article HTML files exist. GitHub Pages evidence:
`gh-pages` exists and `https://itchyshin.github.io/drmSEM/` returned HTTP 200.

## 2026-06-05 — Phylogenetic Phase 1 (agent group: Jason/Emmy/Curie + vignette)

A four-agent group worked phylogenetic models in parallel. Emmy (architecture)
audited the marker path and returned PASS end-to-end: `phylo(1|species, tree=)`
is stripped from causal edges (R/utils.R drmsem_marker_funs/drm_strip_markers),
never made a node/response, preserved verbatim in d-sep augmented refits
(drm_refit_augmented), and excluded from the effect design matrix (drm_fixed_design).
Added: tests/testthat/test-phylo.R (Curie — phylo SEM builds; paths() strip the
phylo term; dsep() augmented refit preserves phylo on an unsaturated claim;
total_effects propagates), a marker no-leak unit test in test-utils.R (verified
locally), vignettes/phylogenetic-sem.Rmd (gated), and docs/design/06-phylogenetic-sem.md.
ape added to Suggests. Jason's drmTMB phylo() API recon pending — reconcile the
test's tree/phylo() usage with it before un-drafting.

## 2026-06-05 — Phylo PR #6 first CI run: 2 findings (Gauss/Ada)

PR #6 R-CMD-check (run 26998231239) failed but PASS 104: the phylo SEM built and
fit against live drmTMB (ultrametric fix worked), paths() stripped phylo,
total_effects() propagated. Two issues surfaced:
(1) REAL BUG (fixed): dsep() crashed on a *saturated* DAG because `bs$df <-
NA_integer_` assigns a scalar to a 0-row data.frame. Guarded the empty-basis case
to return an empty typed drm_dsep with Fisher's C = 0. Not phylo-specific; prior
tests never used a saturated graph.
(2) LIMITATION (OQ-13): dsep()'s augmented refit of a phylo node returns
"refit_failed" (tree not resolvable in the refit env). d-sep degrades gracefully;
test now asserts robustness (status in {ok, refit_failed}, Fisher's C finite).
Needs an engine-side fix (capture/re-inject the tree, or drmTMB exposes it).

## 2026-06-05 — OQ-13 resolved: phylo d-sep refit works (Gauss/Curie)

CI run 27006262081 green with the strict assertion (phylo-node augment-refit
status == "ok"). The fit_env capture + envir-eval fix lets dsep() re-fit a
phylo() node (tree resolves). Phylogenetic Phase 1 is complete end-to-end:
build/paths/dsep/fisher_c/effects on live drmTMB. Docs marked resolved.

## 2026-06-05 — Parallel "finish" batch green (Ada)

Four parallel agents (Phase 2 model comparison, more samplers, distributional-
phylo demo, paper+overview) integrated on PR #6; after three CI-surfaced fixes
(test-model-set ordering/expect_silent, drm_node NSE auto-wrap, pkgdown pak dep
conflict) the whole batch is green on 3 OSes + pkgdown build (run 27007984275).
Phase 2 compare()/best()/average() validated end-to-end on live drmTMB.

## 2026-06-05 — Phase 3 covariance + audit-driven closeout (Ada, parallel agents)

Phase 3 evolutionary covariance shipped + a full audit-driven closeout, run as
parallel agents on disjoint files:
- **Curie** built `R/phylo_cov.R` (`drm_phylo_cov()`: BM / Pagel's λ / Martins-
  Hansen OU / Pagel's κ → relatedness matrix for `relmat()`) + `test-phylo-cov.R`.
  Pure-matrix transforms verified locally (base R); ape/drmTMB paths CI-gated.
- **Rose** (systems audit) produced the closeout punch-list.
- **Grace** hand-wrote the 5 stale Phase-2 `man/*.Rd`; whole `man/` passes
  `tools::checkRd()` with no broken links.
- **Ada (Boole-style integration)** reclassified Phase 2/3 as shipped across
  vignettes/paper/overview; switched the paper marquee node off `beta_binomial`
  (no sampler) to `nbinom2` so the headline mediated effect is real; fixed the
  `NEWS.md` `standardize()` over-claim (link-scale only).
- Orchestrator: NAMESPACE export + `_pkgdown.yml` entry for `drm_phylo_cov`;
  `zero_one_beta` added to `drm_supported_sampler_families()`; removed a broken
  internal `\link` from the phylo_cov roxygen; design-doc Phase-1 contradiction
  cleared; OQ-9/OQ-11 defined, OQ-13 marked resolved; ledger V-rows added and
  sampler claims downgraded to continuous-part-only.

PROCESS LESSON (Rose): when adding an `@export`ed R file, regenerate + commit
`NAMESPACE` + `man/` and update NEWS/ledger/OQ in the SAME commit. CI's
`roxygenise()` masks stale committed artifacts, so source/GitHub/pkgdown-from-
source installs can ship an incomplete man/ even while CI is green.

## 2026-06-06 — PR #4 reconciled into the phylo branch (release prep)

Per the approved release plan (merge #6 → tag v0.1.0; reconcile #4 fully), PR #4
(`effects-counterfactual-theory`) turned out to carry a MORE ADVANCED effect
engine than #6, not just docs. Reconciled fully via parallel agents on disjoint
files:
- **Code (orchestrator):** `R/effects.R` + `test-effect-kernels.R` were identical
  to main on #6, so #4's versions (controlled + natural NDE/NIE + outcome
  functionals) were taken wholesale; `R/simulate_effects.R` merged (#4's
  natural/functional helpers + #6's zero_one_beta/tweedie samplers re-injected).
  All R/ parse; dsep/effect/standardize kernels pass under a base-R harness incl.
  the natural NDE/NIE and Poisson p_zero recoveries.
- **Narrative (Ada):** paper.md / NEWS.md / overview.Rmd were already upgraded in
  the closeout pass; 02-effect-calculus.md merged to one coherent essay with
  OQ-8/OQ-11 marked PARTIAL (implemented + kernel-verified).
- **Memory (Ada):** DECISIONS D-10/D-11 appended; OPEN_QUESTIONS de-duplicated to
  a single OQ-1..13 (OQ-8/10/12 from #4, OQ-9/13 from #6); 05-roadmap phylo
  pointer added.
- **man (Grace):** indirect_effects.Rd (+effect), total_effects.Rd (+target,
  +threshold) updated; full man/ passes tools::checkRd.
- **Ledger:** V-22 (natural effects, PARTIAL) + V-23 (outcome functionals,
  PARTIAL) recorded.

After this lands and #6 CI is green: merge #6 → main, bump 0.1.0 + NEWS +
cran-comments, tag v0.1.0, and close #4 as reconciled (its unique content now
lives on #6).

## 2026-06-06 — OQ-12 unified effect-API surface (post-0.1, branch claude/resume-aybDD)

Resumed after the 0.1.0 release (PR #6 merged; tree == main). Picked OQ-12 — the
pure-R/CI-validatable next step from issue #5 — over the drmTMB-dependent handoff
tasks in #2 (this lane still cannot compile drmTMB).

- **New file `R/effects_api.R`:** `drm_effect_controls()` maps
  `uncertainty`/`nsim`/`population` (+ deprecated `draw`/`n_sim`) onto the engine
  `draw`/`n_sim`; `drm_resolve_mediation()` maps `method` (+ deprecated
  `mediation`) onto mean/distribution. No simulation kernel touched.
- **`R/effects.R`:** all three effect functions take the unified surface;
  `total_effects()` gains `method`, `direct_effects()` gains `target`/`threshold`
  (controlled functional direct effect via the existing functional kernel).
  Deprecated aliases warn (plain `cli_warn`, every call, so reliably testable) and
  are overridden by the new args. `uncertainty="bootstrap"`→OQ-10 abort,
  `population="marginal"`→OQ-9 abort, both fired before `drm_require_drmTMB()`.
- **Hand-wrote `man/{direct,total,indirect}_effects.Rd`** to match the new
  roxygen (no R/roxygen in this lane; per the standing process lesson, man/ ships
  in the same commit). NAMESPACE unchanged (helpers are internal).
- **Tests `test-effect-api.R`:** pure-R unit tests for both normalizers (mapping,
  deprecation warnings, OQ-9/OQ-10 aborts) that need no drmTMB, plus drmTMB-gated
  parity (new surface == deprecated aliases under a fixed seed) and a
  `direct_effects(target="p_zero")` smoke.
- **Docs/memory:** 02-effect-calculus "API harmonization" flipped planned→
  implemented (+ knob list + speed tiers + OQ-8/OQ-11 status lines); vignettes
  migrated `mediation=`→`method=`; OQ-12 marked RESOLVED; D-13 added; V-24
  recorded; NEWS dev section + version bump to 0.1.0.9000.

Engine-path parity is CI-gated (the lane cannot run drmTMB locally); the pure-R
normalizer tests run everywhere.
