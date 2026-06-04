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
