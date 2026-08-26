# G0 approved — drmSEM Step 2 S3 grouping correction

Frozen at approval (2026-08-26). Shinichi locked:

- **Q1 = A** — status `wrong_scale`; exclude those p-values from Fisher's C;
  keep `n_effective` / `scale_group` detection + warning; do **not** auto-refit
  both sides inside `dsep()`.
- **Q2 = wait-for-merge** — branch from main after MAG-wire PR #43. Discharged:
  merged as `04307ee` (`d025698` on origin/main).
- **Q3 = inherit C on remaining claims** — `model_set()` / CICc do not refuse
  a candidate that has any `wrong_scale` claim.

Full G0 packet: `~/.cursor/plans/s3_grouping_g0_29dfcaed.plan.md`.

## Destination

When a claim's added variable lives at a coarser grouping the node does not
model, that claim is **not a valid LR**. It does not enter Fisher's C.
Detection columns and the warning stay. The user's stored node is unchanged.
`03-dsep.md` states the scale rule. The V-109 fixture no longer condemns a
true independence via C.

This is **not** silently testing `(1 | group)` while `paths()` / effects still
use the ungrouped node.

## Slice table

- S1 Design + D-21 — `docs/design/03-dsep.md`, `DECISIONS.md`, `OPEN_QUESTIONS.md`
- S2 Code — `R/dsep.R` scale/status + `fisher_c` filter + roxygen; `man/dsep.Rd`
- S3 Tests — `tests/testthat/test-scale.R` V-109c; V-110 still silent
- S4 Ledgers — VALIDATION_LEDGER, AGENT_LOG, capability-status
- S5 Verify — `devtools::test()` / check / vignette-tangling
- S6 Review — Fisher + Rose
- S7 Reconcile — PLAN-ACTUAL

## Fences

No push/PR. No MAG `basis_set_mag` edits. No Step 3 drmTMB. No orthogonal-
hierarchy skipping. No auto-add `(1 | g)` to the stored node.
