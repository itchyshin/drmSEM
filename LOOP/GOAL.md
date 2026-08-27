# GOAL — S6 A7 consumer (IMMUTABLE — re-read at the top of EVERY arc)

## Mission

Prepare drmSEM to consume **one engine family cell at a time** after
drmTMB A7 (item 1, #962) ships per-family C++ `has_mi` wiring. This
kickoff is **docs only**. No drmSEM `R/` until the engine PR for the
**first new family** is mergeable. Capability-status stays `partial`.

## Headline

Consumer contract + V-80 anti-drift + ledger cross-ref. Lift family
gates in `R/imputation.R` only after the matching engine cell exists.
Never treat a whitelist edit as the work.

## Invariants

- ONE lane: `cursor/lane-s6-a7-consumer` at
  `~/local-scratch/lanes/drmSEM-s6-a7-consumer`. Do **not** touch
  MAG-completeness, MAG-wire, or S3-grouping. Do **not** create
  `drmTMB-s6-family-gate` — sibling `0a5d078f` owns that engine lane.
- drmSEM never fits its own likelihoods. A7 C++ `has_mi` is engine
  work. Consumer only assembles `mi()` + `impute_model()` from the DAG.
- Not FIML. Within-node uncertainty only. Incomplete exogenous →
  `na_action`. `impute = "none"` stays default. Independent
  `impute_model()` per parent (option b). Never emit `impute_joint`.
- **No drmSEM `R/` on a wait/prep commit.** A7c-2 (Gamma lift) is
  shipped (#49). A7c-3 (lognormal lift) is a separate consumer PR
  after G-engine-ln (lognormal `has_mi` green or merged).
- One cell at a time. Do not widen `drm_impute_response_families()`
  ahead of `drmTMB:::drm_missing_predictor_families()`. V-80 is the
  anti-drift lock.
- Fail loud for every cell the engine has not recovered. Silent
  “first `mi()` only” remains forbidden.
- Branch on `uncertainty_status`, never `is.na(std_error)`.
- capability-status stays **`partial`**. No `"covered"`. No general
  missing-data SEM sentence.
- Explicit paths on every `git add`. NEVER `git add -A`.

## Authoritative WHAT

`LOOP/ultra-plan.md` (consumer slices only). Contract:
`LOOP/notes/A7-consumer-contract.md`. Phase 1 locks still hold: D-22,
`LOOP/notes/A1-engine-contract.md`, A12 PLAN-ACTUAL
`docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`. This file wins
on "what must never be lost".

## Definition of done

**This A7c-3 prep:** LOOP checkpoint + contract + checklist
committed on this branch; no `R/` edit; capability-status
untouched. Wait for the lognormal engine PR.

**Programme (later, after G-engine-ln):** lift only lognormal ×
Bernoulli, V-80 still matches the engine allow-list, V-123 / V-123b
exist, leftovers (student, …) still fail loud, and
capability-status is still `partial`.

## Pre-authorisation

- This kickoff: scoped docs/LOOP edits; local commits; listed
  checks; optional named-branch push + **draft** PR: CONTINUE.
- Must stop: drmSEM `R/` before G-engine-ln; merge/release/public
  claim; credentials; destructive work outside this worktree;
  MAG-completeness files; creating a second drmTMB A7 worktree;
  flipping capability-status; new compute beyond a later Totoro
  ask.

## Out of scope

- FIML / joint SEM likelihood / Bayesian imputation
- Item 3 option (a) (accept a fitted drmTMB as imputer)
- Incomplete exogenous imputation
- `impute_joint` as the SEM emit shape
- MAG / S3 grouping / `rho12` joint fit
- Engine C++ `has_mi` (sibling lane)
- drmSEM `R/` during this kickoff
- capability-status `"covered"`
