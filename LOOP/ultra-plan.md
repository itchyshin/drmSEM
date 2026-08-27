# Ultra-plan — S6 A7 consumer (family-gate follow-on)

```
🎯 GOAL
Solo platform: Cursor (this session; Grok). Sibling 0a5d078f owns the
  drmTMB engine lane. This plan is consumer slices only.
Deliverable: a docs-only consumer contract so drmSEM can lift family
  gates in R/imputation.R after the first new-family engine PR is
  mergeable, without claiming a general missing-data SEM.
HEADLINE: wait for C++ has_mi (#962); then one cell at a time; V-80
  anti-drift; ledger cross-ref; capability stays partial.
IN PARALLEL: sibling writes engine has_mi. This lane does not create
  drmTMB-s6-family-gate and does not edit engine C++.
DEFER: drmSEM R/ until G-engine; FIML; impute_joint; exogenous
  imputation; capability "covered"; MAG / S3 / rho12.
DISCIPLINE: verify=log+artefact · no R/ this kickoff ·
  closure=A7c-0 kit + contract; G-engine before any consumer code
```

ARC PROGRAM: N/A (no Arc Card). Predecessor closeout:
`docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`. Order lock: D-22
(engine 2+5 shipped; **then item 1**; then consumer). Item 1 is now
the live engine slice; this kit is the consumer that follows it.

---

## Phase 0.2 — Shannon pre-flight

```
PLATFORM: cursor | ON BRANCH: cursor/lane-s6-a7-consumer
  from main @ e7392d7 | LANE: s6-a7-consumer
OTHER LANES: claude/lane-mag-completeness (DO NOT TOUCH);
  claude/lane-mag-wire; claude/lane-s3-grouping;
  sibling 0a5d078f on drmTMB-s6-family-gate (engine; do not duplicate)
VERDICT: no foreign claude/codex on drmSEM in the last 12h.
  Silence is weak evidence. Lease GRANTED:
  cursor:drmSEM-s6-a7-consumer [LOOP/,docs/memory/]
```

This kit **replaces** the closed Phase 1 LOOP on `main` (same filename
collision as A12 vs MAG). MAG LOOP stays on its worktree. Do not merge
those kits.

---

## Phase 0.25 — Sweep receipt

| Surface | Evidence | Finding | Call |
|---|---|---|---|
| **repo git** | `main` @ `e7392d7` (#47 A12); worktree list | Phase 1 consumer shipped (#45/#46). Gaussian k=2 live. capability `partial`. A7 not started in drmSEM. | **build** a new consumer kit; do not resume `drmSEM-s6-imputation` |
| **sister / engine** | drmTMB #962; A1 §5; after-task 2026-08-09 | Item 1 is C++ `has_mi`, not a whitelist flip. Wired today: gaussian (full predictor catalogue) + beta/binomial/poisson/nbinom2 (bernoulli predictor only). Gamma, lognormal, student, beta_binomial, zi_* have **no** `has_mi`. Sibling created `drmTMB-s6-family-gate`. | **reuse** A1; **do not** create a second engine worktree |
| **brain** | MCP `search_notes` S6/A7/V-80 | Hub hits are unrelated (10-group, TabPFN). Repo D-22 + A12 PLAN-ACTUAL are the lock. | **reuse** D-22 / A1 / A12 |
| **deterministic grep** | `R/imputation.R` gates; V-80/79b/79c; `13-missing-data.md`; capability-status S6 row | Response allow-list = gaussian/poisson/binomial/nbinom2/beta. Non-Gaussian × non-binary fails loud. k=2 only for two Gaussians. V-80 locks to `drm_missing_predictor_families()`. | do not lift any gate in this kickoff |
| **Verdict** | | Genuinely new: per-family **consumer** contract after item 1. | **reuse** Phase 1 emit shape; **build** A7c kit |

---

## Consumer slices only (no engine C++)

| # | slice | what | gate |
|---|---|---|---|
| A7c-0 | This kickoff | LOOP kit, `A7-consumer-contract.md`, AGENT_LOG stubs | — |
| A7c-1 | Wait | First new-family engine PR **mergeable** | **G-engine** |
| A7c-2 | Lift one cell | `drm_impute_response_families()` / `drm_check_impute_legal()` / `drm_check_two_gaussian_mi()` only as far as that cell | ← G-engine |
| A7c-3 | V-80 | `expect_setequal` still matches the engine list; V-80b/c leftovers still fail loud | ← A7c-2 |
| A7c-4 | Recovery | Known-DGP for the new cell; keep V-77 and V-82 k=2 identity | ← A7c-2 |
| A7c-5 | Ledger | New V-number in `VALIDATION_LEDGER.md` pointing at the engine `missing_predictor` cell id | ← A7c-4 |
| A7c-6 | Honesty | `13-missing-data.md` names the new cell and the leftovers. capability-status **stays `partial`** | ← A7c-5 |
| A7c-7 | Review | Ada + Rose: no `"covered"` | G-claim |

A later family **repeats A7c-2–A7c-6**. It does not reopen Phase 1
and it does not flip the capability row.

---

## What “first new family” means

The sibling chooses the first #962 cell. This lane does not pick it.
A cell is **new** when it is not already a recovered drmSEM emit:

- already live: one-parent Gaussian chain (V-77/V-78); two independent
  Gaussian `mi()` (V-79/V-82/V-120)
- already **legal to emit, engine-limited**: non-Gaussian response ×
  **binary** predictor (one parent)
- still **illegal to emit**: response outside
  `drm_impute_response_families()`; non-Gaussian × non-binary parent;
  k = 2 unless both response and parents are Gaussian; k > 2

G-engine opens on the first cell that **changes** one of those illegal
rows because C++ `has_mi` now exists — not because someone edited a
character vector.

---

## Gates

- **G-engine (OPEN).** No drmSEM `R/` until the sibling PR for the
  first new family is mergeable (CI green or Shinichi says install
  from that worktree). Promoting a family without `has_mi` is the
  #962 failure mode.
- **G-claim.** Default not-ready: keep `partial`. One extra family is
  not a general missing-data SEM.

---

## Reviewers (when A7c-2 starts — not this kickoff)

| Role | Question |
|---|---|
| Gauss | Does the emit match the shipped engine cell? |
| Curie | Is there a known-DGP recovery, not just “it runs”? |
| Fisher | Does V-80 still lock the two allow-lists? |
| Rose | Did anyone write `"covered"` or FIML? |
| Ada | Code, tests, docs, ledger, git paths consistent? |

---

## Out of scope (G3 if someone “just adds” them)

- Engine C++ / `src/drmTMB.cpp` / drmTMB allow-list
- A second drmTMB A7 worktree
- FIML / `impute_joint` / exogenous imputation
- Widening k > 2 before the engine does
- capability-status `"covered"`
- MAG-completeness files
