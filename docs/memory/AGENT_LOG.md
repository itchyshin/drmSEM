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

## 2026-06-06 — OQ-14 covariance-edge grammar (pure-R layer; branch claude/resume-aybDD)

After OQ-12 merged (PR #7, squash 6ca9980), reset the branch to main and built
the next bounded step: the pure-R grammar + d-separation layer of OQ-14
(first-class bivariate covariance edges), chosen because the marquee feature's
graph semantics are fully testable here while joint bivariate fitting is not.

- **New `R/covariances.R`:** `covary(y1, y2, level=)` declares a residual
  (`rho12`) or higher-level (`corpair`) covariance edge; `drm_build_covariances()`
  validates declarations against node records and builds a labelled `$covariances`
  table; `covariances(sem)` accessor reports residual vs higher-level separately;
  `drm_covariance_pairs()` feeds basis_set. Edges live in a dedicated `$covariances`
  slot, NEVER in `$edges`, so `paths()` stays directed-only (the class-1 vs
  class-2/3 split of D-12/D-14).
- **`R/drm_sem.R`:** `new_drm_sem()`, `drm_sem()`, `drm_psem()` gain a
  `covariances =` argument threaded to the constructor.
- **`R/dsep.R`:** `basis_set.drm_sem()` drops the `y1 _||_ y2` claim for any
  declared covariance pair (unordered key; Shipley's bidirected-edge rule).
  Back-compatible: a missing slot ⇒ no covariance pairs ⇒ unchanged behaviour.
- **Tests `test-covariances.R`:** pure-R (no drmTMB) — covary construction +
  validation, node resolution/labelling/de-dup, the accessor, and basis_set
  dropping for residual AND higher-level edges, plus the missing-slot no-op.
- **Docs/memory:** NAMESPACE (covary/covariances exports + 3 S3 methods) and
  man/ hand-updated (covary.Rd, covariances.Rd, basis_set/drm_sem/drm_psem Rd);
  `_pkgdown.yml` "Covariance edges" reference section; design doc 07 current-state
  + feature table updated; OQ-14 → PARTIAL; D-14 + V-25 + NEWS recorded.

Deferred to the Codex lane (need a live bivariate drmTMB fit): `drm_pair()` joint
fitting, `rho12(fit)`/`corpairs(fit)` read-back, double-headed-arc plotting, deep
RE-block level-compatibility validation.

## 2026-06-06 — 0.2 inference-hardening push (6 design agents + 2 parallel implementers)

Drove the 0.2 "inference hardening" milestone with a large parallel agent batch,
honest about the lane limit (no R/drmTMB here; engine-dependent items are CI/Codex).

**Design/spec/audit (6 parallel read-only agents):** Fisher (Fisher's C calibration
study design + acceptance criteria, OQ-6), Noether (the analytic effect identities
with derivations + tolerances + harness contract), Jason (standardization landscape
-> OQ-4 recommendations, with citations), Emmy (standardize code review + 0.3
composite-construct architecture), Rose (0.1->0.2 drift punch-list), Grace
(reproducibility: 0.2 version mechanics + the precomputed-calibration pattern + CI).

**Implementation (2 parallel edit agents on disjoint file-sets + orchestrator):**
- Grace built the calibration scaffold: `vignettes/calibration.Rmd` (precomputed,
  `eval=FALSE`, `knit_exit` until the cache exists), `inst/calibration/generate.R`
  (live-drmTMB regenerator, engine-gated, self-contained), `_pkgdown.yml` article,
  and two safe CI tweaks (timeout 30->45, fixed the stale "no man/ committed" note).
- A doc-sweep agent reconciled the user-facing docs to the shipped OQ-14 grammar
  (README version, the four vignettes, paper.md scope, roadmap status, validation-
  plan counts) per Rose's punch-list.
- Orchestrator (disjoint, no collision): `test-analytic-effects.R` (V-26..V-30,
  pure-R analytic cross-checks from Noether's plan); standardization conventions
  finalized + documented (`R/standardize.R` roxygen, `man/standardize.Rd`,
  `docs/design/08-standardization.md`, non-breaking — SD=1 default kept); all
  memory files (NEWS, ledger V-26..30 + V-17 scaffold note, D-15, OQ-4 RESOLVED,
  OQ-6 SCAFFOLDED).

File ownership was partitioned up front (calibration files | user-facing docs |
standardization+memory) so the two background editors and the orchestrator never
touched the same file; the orchestrator owned all `docs/memory/*` + `NEWS.md`
centrally to serialize the shared-file writes.

PROCESS LESSON (Rose): when an OQ ships, sweep ALL user-facing surfaces in the
same pass — the OQ-14 grammar landed in NEWS/DECISIONS/design-doc-07 but the four
vignettes + paper.md still called it "roadmap" until this sweep. Add "sweep the 5
vignettes + paper.md + roadmap status tables" to the OQ-shipping checklist next to
the existing "regenerate man/NAMESPACE" rule.

Still 0.2-blocking and Codex-only: the Fisher's C calibration cache (OQ-6), the
standardization `sigma_E` refinement (OQ-4), and flipping V-7/V-10/d-sep from
kernel-validated to validated on a live fit.

## 2026-06-06 — 0.3 first increment: composite constructs (orchestrator)

After merging the post-0.1 hardening batch (#8), started 0.3 per Emmy's
architecture: composite (formative) constructs, fully pure-R (no engine change).

- **New `R/composite.R`:** `drm_composite()` (fixed weighted-sum / pca first-PC,
  sign-fixed, prop_var), `drm_score_composite()`, `drm_build_composites()`,
  `drm_apply_composites()` (materialize before fit), and the `loadings()` accessor
  (separate from `paths()`, mirroring `covariances()`).
- **`R/drm_sem.R`:** `drm_sem()`/`drm_psem()`/`new_drm_sem()` take `composites=`;
  `drm_sem()` materializes construct columns before fitting; stored in a
  `$composites` slot; `print.drm_sem()` notes them.
- **Tests `test-composite.R`** (pure-R): construction, scoring, validation, build/
  apply, loadings accessor. **NAMESPACE + man/ hand-updated** (drm_composite.Rd,
  loadings.Rd, drm_sem/drm_psem Rd); `_pkgdown.yml` "Latent constructs" section.
- **Docs/memory:** design doc `09-latent-variables.md` (composite vs reflective
  boundary); NEWS; D-16; V-31; OQ-15 (follow-ups); this entry.

Deferred (OQ-15): indicator-intervention propagation (needs a live fit),
measurement-arc plotting (needs rendering), reflective constructs (0.4 / joint
likelihood).

## 2026-06-06 — OQ-5 per-mediator path-specific effects (orchestrator + Fisher spec)

Fisher (inference-reviewer) spec'd OQ-5 (per-path / per-component attribution):
estimands, the additivity/identifiability boundary (recanting-witness), the API,
and a pure-R test plan. Implemented the bounded, lower-risk half: per-mediator
attribution.

- **New `R/path_effects.R`:** kernel `drm_path_contrasts()` (inclusion/exclusion/
  total/remainder by active-set toggling, pure function of engines) + the
  `path_effects()` accessor (drm_effect table, reuses drm_summ/drm_build_scenarios/
  drm_effect_controls). No new simulation kernel.
- **Tests `test-path-effects.R`** (pure-R, deterministic mean-channel closed
  forms): P-1 additive, P-2 nonlinear non-additive, P-3 sequential, single-mediator.
- **NAMESPACE + man/path_effects.Rd + _pkgdown** Effects section; 02-effect-calculus
  gains a per-mediator section with the additivity table; OQ-5 -> PARTIAL; D-17,
  V-32, NEWS.

Deferred (OQ-5 follow-up, riskier / engine-gated): per-component (mu/sigma/zi)
attribution via a `freeze` plumbing arg in drm_propagate; the natural cross-world
variant + recanting-witness guard; NA for unconfirmed-sampler families; a live-fit
integration test before "validated".

## 2026-06-06 — CRAN-readiness: examples + refreshed Codex handoff (orchestrator + Grace)

CRAN-readiness polish (Option A). Every exported function now carries an
`@examples` block (only the package doc is exempt).
- **Orchestrator:** runnable pure-R examples for `covary()` and `drm_composite()`
  (they execute under R CMD check — verified by signature), and `\dontrun` examples
  for the new `covariances()` / `loadings()` / `path_effects()`. Refreshed
  `docs/memory/CODEX_HANDOFF.md` to the current post-0.1 state (P0 calibration
  cache + tier flips, P1 OQ-5 freeze / OQ-14 joint fit / composites integration,
  P2 samplers / sdreport / plotting, P3 CRAN / 0.4).
- **Grace (parallel, disjoint files):** `\dontrun` examples for the 12
  engine-dependent exports (effects, paths, basis_set/dsep/fisher_c, standardize,
  plot.drm_sem/plot.drm_effect, check_sem, drm_psem), roxygen + hand-synced man/.
  All use the canonical size->abundance chain and the new effect-API surface
  (method=/uncertainty=/nsim=).

File ownership partitioned up front (orchestrator: covariances.R/composite.R/
path_effects.R + handoff; Grace: effects.R/paths.R/dsep.R/standardize.R/plotting.R/
diagnostics.R/drm_sem.R) so the concurrent edits never touched the same file.
NOT done (submission-time / engine): drop `Remotes:`, `--as-cran` lane (would red
on the Remotes NOTE until drmTMB is on CRAN) — recorded in CODEX_HANDOFF P3.

## 2026-06-06 — 0.2.0 release cut

Cut drmSEM 0.2.0: DESCRIPTION 0.1.0.9000 -> 0.2.0; NEWS dev heading promoted to
`# drmSEM 0.2.0` with a release lead; cran-comments + roadmap updated. 0.2.0 ships
OQ-12 unified effect API, OQ-14 covariance-edge grammar, OQ-5 per-mediator +
per-component path attribution, composites (0.3 first increment), analytic
cross-checks (V-26..V-34), finalized standardization conventions. The Fisher's C
calibration STUDY stays experimental/scaffolded (compute-heavy live-drmTMB run,
issue #13) -- 0.2.0 is honest about that single item. After merge: tag GitHub
Release v0.2.0 (deploys release-mode pkgdown site to root + R-CMD-check on the
tag), then bump to 0.2.0.9000 dev.

## 2026-06-06 — OQ-5 natural per-mediator variant + recanting-witness (parallel-safe)

Post-0.2.0 dev (0.2.0.9000). Parallel-safe Claude work while Codex runs the
calibration lane (avoided inst/calibration/*, vignettes/calibration.Rmd, and
docs/memory/OPEN_QUESTIONS.md).
- `path_effects(effect = "natural")`: per-mediator cross-world natural indirect
  effect (reuses the validated `drm_natural_target` kernel) + an `identified`
  column flagged FALSE under a recanting witness. `drm_recanting_witness()` is
  pure graph logic (Avin-Shpitser-Pearl 2005), kernel-tested in
  `test-path-effects.R` (parallel -> identified; sequential M1->M2 -> M2 not).
- Bumped DESCRIPTION to 0.2.0.9000 + NEWS dev section; man/path_effects.Rd,
  02-effect-calculus updated. Kept d-sep/Fisher's C wording untouched (experimental).
- DEFERRED to avoid collision with Codex: the OQ-5 entry in OPEN_QUESTIONS.md is
  NOT edited here; the natural-variant status update there is pending Codex's
  calibration closeout / handoff back of that file.

## 2026-06-06 — 0.3 latent push (increment A): composite reliability + standardize

Parallel-safe 0.3 work while Codex runs the calibration lane. Touched ONLY
non-shared files (R/composite.R, NAMESPACE, man/drm_composite.Rd, test-composite.R,
docs/design/09-latent-variables.md, AGENT_LOG) -- avoided NEWS/ledger/DECISIONS/
OPEN_QUESTIONS/roadmap/paper/overview/calibration (Codex-owned), so their rebase
stays clean. Holding NEWS/ledger bullets for a reconciliation pass after Codex lands.
- `drm_composite()` now records **reliability** (Cronbach's alpha, `drm_cronbach_alpha()`,
  unclamped, NA for a single indicator) and accepts `standardize = TRUE`
  (mean-0/sd-1 score). `print()`/new `summary.drm_composite()` report loadings +
  prop_var + reliability. Tests in test-composite.R (alpha formula on identical /
  single / uncorrelated indicators; standardize moments; summary no-error).
- 09-latent-variables.md expanded: reliability, standardize, formative vs
  reflective-flavoured (pca) reading.
Next increments (B) composite-as-response + effects/d-sep through a composite;
(C) latent-variables vignette.

## 2026-06-06 — Codex live-drmTMB OQ-6 calibration closeout

Codex picked up the live-engine handoff on branch `codex/live-drmtmb-closeout`
from `origin/main` (`3ab2c63`, after PR #12), then rebased the uncommitted
calibration work onto `c951d31` after the 0.2.0 release and OQ-5 natural-variant
work landed. Baseline GitHub `main` was green on R-CMD-check and pkgdown before
the calibration run. Local runtime had R 4.5.2 and TMB 1.9.21. A broad local
test run exposed a stale `drmTMB` install (missing exported `zero_one_beta` and
failing phylo/relmat environment tests), so Codex updated `drmTMB` from GitHub to
0.1.3.9000 at SHA `17b1321` and reran the calibration cache.

Found a handoff/spec discrepancy: `CODEX_HANDOFF.md` referred to five acceptance
criteria, but the current vignette/OQ-6 text only had qualitative criteria.
Added explicit C1-C5 checks to `inst/calibration/generate.R`, stored them in
`cal$acceptance`, made `vignettes/calibration.Rmd` render the criteria table, and
let the source-tree cache override `system.file()` so freshly generated caches
render before reinstalling the package. Routine fit messages are suppressed in
the generator; warnings would still reach the log.

Ran `Rscript inst/calibration/generate.R`: 14,400 live `drm_sem()`/`dsep()`
calibration replicates completed in 14.5 minutes under `drmTMB@17b1321` and
wrote `inst/calibration/calibration-results.rds` with `drmSEM` 0.2.0.9000 at git
SHA `c951d31`. The cache passed all five checks:
Type-I family/n range 0.025-0.080 inside the 99% band 0.015-0.095; Type-I by
claim_df passed (`claim_df=1`: 0.0525 and 0.05625; `claim_df=2`: 0.045);
Fisher's C null uniformity KS p=0.631, median=0.499; beta=0.8 and beta=0.5
n>=250 power were 1.0 in all required cells. Rendered
`vignettes/calibration.Rmd` from the source-tree cache.

Promoted V-17 to "validated for OQ-6 grid" and swept stale calibration wording in
NEWS, paper.md, the overview vignette, roadmap, CODEX_HANDOFF, OPEN_QUESTIONS,
VALIDATION_LEDGER, and DECISIONS. Remaining P0 live-engine work: V-7/live-fit
analytic identities and OQ-4 `sigma_E`.

Verification: `vignettes/calibration.Rmd` rendered from the source-tree cache;
`devtools::test()` passed (`FAIL 0 | WARN 5 | SKIP 1 | PASS 383`) under
`drmTMB@17b1321`; `pkgdown::check_pkgdown()` reported no problems; and
`devtools::check()` finished with 0 errors, 0 warnings, and 1 existing NOTE
(`LICENSE` file not mentioned in DESCRIPTION). Removed the unused `utils` import
from DESCRIPTION during this pass, clearing the second check NOTE.

## 2026-06-06 — post-#18 reconciliation (Claude lane)

After Codex's OQ-6 calibration PR (#18) merged to main, merged main into the 0.3
branch (only AGENT_LOG conflicted -- both lanes appended; kept both). Then folded
in the deferred shared-doc bullets that were held during the freeze:
- NEWS 0.2.0.9000: added the "Latent constructs (0.3)" section (composite
  reliability/standardize/summary.drm_composite, composite-as-response, the
  latent-variables vignette).
- drmSEM-overview roadmap table: added "now" rows for path_effects attribution and
  composite constructs; softened "Latent variables out of scope" -> "reflective
  measurement models out of scope (0.4); composites ship".
Codex's calibration cache + V-17 (OQ-6-grid validated) + the utils-import removal
are in. d-sep/Fisher's C wording stays scoped to the OQ-6 grid.

## 2026-06-06 — 0.5 design doc (cyclic/feedback graphs)

Drafted `docs/design/10-cyclic-feedback.md` (the 0.5 design of record) and pointed
05-roadmap at it. Honest framing: feedback in a piecewise distributional SEM is two
hard problems -- consistent ESTIMATION (simultaneity bias; needs IV/2SLS or a joint
likelihood = engine) and effect PROPAGATION (equilibrium / fixed point, not a path
product). Estimand: linear reduced form `(I-B)^-1 Gamma`; nonlinear = fixed-point
iteration of drm_propagate with a `rho(B)<1`/max-iter stability guard and honest
non-convergence reporting. Staged 0.5.0: a `drm_cycle()`/`feedback=` declaration
(cycles stay an error unless declared), relaxed toposort, fixed-point propagation,
basis-set suppression among motif nodes; consistent estimation + full
sigma-separation deferred to the engine/research lane. Pure-R prototypable:
declaration grammar, fixed-point engine, closed-form 2-cycle recovery tests.

## 2026-06-06 — 0.4 drm_pair() pure-R bivariate-node declaration grammar

Built `R/pair.R` (+ `test-pair.R`): the bivariate-node *declaration* layer for
OQ-14 / 0.4, all pure-R (no engine).
- `drm_pair(formula1, formula2, rho12 =, family =, family2 =, level =, names =)`
  records a bivariate node: two response formulas + families, an optional
  `rho12 ~ x` residual-correlation model (predictors recorded as a directed path
  INTO the rho12 component), and auto-detected higher-level `corpair` edges
  wherever the two formulas share a grouping factor. Validates distinct
  responses, well-formed rho12, and warns on a level not shared by both
  responses (level-compatibility). Parsing helpers `drm_formula_response()` /
  `drm_formula_groups()` are base-R (the latter ignores the brms `|p|`
  correlation label, taking the rightmost bar term as the grouping).
- `drm_expand_pair()` bridges the pair onto the shipped `covary()` grammar (two
  `drm_node()` sub-nodes + residual/corpair edges) -- the documented hook point
  where the 0.4 engine swaps the two independent node fits for one joint fit.
- `rho12()` / `corpairs()` S3 accessors (methods for `drm_pair` and `drm_sem`)
  return the declared edges, kept separate from `paths()`, with `estimate = NA`
  BY CONSTRUCTION: the fitted correlation must be read back from a live bivariate
  drmTMB fit (the 0.4 engine deliverable). Nothing is fabricated.
HONEST BOUNDARY: the joint fit (estimating rho12 in one drmTMB model) and the
non-NA read-back stay the engine/Codex deliverable (CODEX_HANDOFF item 5). drmSEM
still never fits its own likelihoods. Updated NEWS, 07-bivariate doc current-state
+ feature table, 05-roadmap 0.4, CODEX_HANDOFF, _pkgdown reference.

## 2026-06-06 — 0.4 plot polish: covariance arcs in plot.drm_sem

Drew the covariance edges we can already declare. plot.drm_sem now renders
covary()/drm_pair() edges as DOUBLE-HEADED arcs (igraph arrow.mode = 3): residual
rho12 solid grey, higher-level corpair dashed grey, curved more than directed
paths so the three edge classes (directed component-coloured path; residual
covariance; higher-level covariance) are visually distinct. New `show =
c("all","paths")` arg toggles the arcs off. Legend gains "rho12 (covary)" /
"corpair (covary)" rows when arcs are drawn. CI smoke tests (`test-plotting.R`,
pdf(NULL)) cover all/paths/no-covariance. ggplot2/igraph is the Claude lane per
CODEX_HANDOFF; this closes the last non-engine piece of 0.4 (joint fit +
rho12(fit)/corpairs(fit) read-back remain the engine deliverable). Updated NEWS,
07-bivariate doc (shipped list + feature table), CODEX_HANDOFF item 5.
