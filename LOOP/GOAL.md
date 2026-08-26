# GOAL — S6 generality multi-mi() (IMMUTABLE — re-read at the top of EVERY arc)

## Mission

Make graph-derived imputation general for ordinary graphs: a node with
two or more incomplete **endogenous** parents emits independent `mi()`
terms from the DAG, after drmTMB accepts k ≥ 2 independent `mi()` terms
and a `missing_predictor` ledger exists. drmSEM does not implement
engine likelihoods. This run starts in **planning**: no drmSEM `R/`
until G1.

## Headline

Engine items **2 + 5, then 1**, then the drmSEM consumer. Independent
predictor models (option b), not `impute_joint`, not FIML.

## Invariants

- ONE lane: `cursor/lane-s6-imputation` at
  `~/local-scratch/lanes/drmSEM-s6-imputation`. Do **not** touch
  MAG-completeness, MAG-wire, or S3-grouping worktrees. Do **not**
  edit the dirty drmTMB primary checkout.
- drmSEM never fits its own likelihoods.
- Not FIML. Within-node uncertainty only. Incomplete exogenous →
  `na_action`. `impute = "none"` stays default.
- Consumer contract = independent `impute_model()` per parent
  (drmTMB #963 option b). `impute_joint` is sister prior art only.
- No drmSEM `R/` until G1 (engine contract + item 2 available).
- Branch on `uncertainty_status`, never `is.na(std_error)`.
- Explicit paths on every `git add`. NEVER `git add -A`.
- Never push, merge, or publish — those are HUMAN GATES.

## Authoritative WHAT

`LOOP/ultra-plan.md` (G0 approved 2026-08-26). Arc charter:
`docs/memory/2026-08-26-next-arc-s6-imputation.md`. Order lock: D-22.
This file wins on "what must never be lost".

## Definition of done

Planning phase (this kickoff): lane + charter + LOOP kit + D-22 +
AGENT_LOG committed; G0 approved 2026-08-26 (all 10 defaults).
A1 + A3 drafted; A2 authorised (GitHub issue comments).

Programme done (later, after G0→G1→G2): k ≥ 2 independent `mi()` on
the engine with recovery + ledger; drmSEM lifts the abort and recovers
a known two-incomplete-parent DGP; honest limits still in the docs.

## Pre-authorisation

- After G0: scoped docs/LOOP edits; routine local commands; local
  commits; listed checks: CONTINUE.
- Optional remote: none (no push, no PR) until a later human gate.
- Must stop: drmSEM `R/` before G1; merge/release/public claim;
  credentials; destructive work outside this worktree; MAG-completeness
  files; new compute beyond the estimate; switching to `impute_joint`
  or FIML without a new G0.

## Out of scope

- FIML / joint SEM likelihood / Bayesian imputation
- Item 3 option (a) (accept a fitted drmTMB as imputer)
- Incomplete exogenous imputation
- MAG / S3 grouping / `rho12` joint fit
- drmSEM `R/` during Phase 0
