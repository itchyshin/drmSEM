# Plan vs actual — Step 2 S3 grouping (2026-08-26)

Reconciler: Melissa (Cursor closeout). Plan: `LOOP/GOAL.md` / `LOOP/ultra-plan.md`.
Counts as filed: **adaptive 2 · drift 0 · unclear 0**.

Filed here, not at `docs/dev-log/plan-actual/`: that path is **gitignored**
in this repo.

| axis | planned | actual | tag | note |
|---|---|---|---|---|
| Scope | Estimand A: `wrong_scale` excluded from C; no auto-refit; Q3 inherit C | Landed. S1 `03-dsep.md` + D-21 + OQ-17. S2 scale block only. MAG `basis_set_mag()` untouched. | adaptive | Flattened p-value kept in the table for inspection; C filter is `status == "ok"` |
| Evidence | V-109c on existing fixture; V-110 silent; suite green | V-109c 6 assertions. `test-scale.R` 27/0. Suite **1032 / 0 / 3 / 10**. | adaptive | +6 vs MAG-wire 1026; warn/skip held |
| Branch | After MAG-wire merge, not stacked | PR #43 merge `04307ee`; lane from `origin/main` | — | S0 recon discharged the Q2 wait |
| LOOP kit | Fresh; do not inherit defect/MAG-wire LOOP | Archived inherited `notes/` + `workflow-ci-gate.patch`; new GOAL/arcs/checkpoint/ultra-plan | — | MAG-completeness worktree untouched |
| Public claims | Update 03-dsep + capability-status sentence | capability-status d-sep cell notes D-21 / V-109c | adaptive | documents C-membership, not a new public capability |
| Remote | no push/PR | No push | — | — |

## Drift → owner

None.

## Judgement calls (not drift)

1. **Keep flattened p-value in the table.** G0 said "those p-values do not enter C". Computing the LRT then excluding it is more inspectable than `next` (NA p). C membership is what changed.
2. **Q3 needs no `model_set.R` edit.** `compare()` already calls `fisher_c()`, which uses remaining `"ok"` claims.
3. **OQ-17** records orthogonal-hierarchy skipping so D-21 does not silently eat that leftover.

## S6 review (Fisher + Rose, this closeout)

**Fisher.** C membership matches `n_mismatch`: invalid LRs do not enter C. On the V-109 fixture the only claim is `trait _||_ z`, so k = 0 and C p is NA — incomplete-but-honest, not a silent pass. Auto-refit would have made C a GOF test of a different SEM than `paths()`. D-2 any-component LRT unchanged.

**Rose.** Do not call this "S3 fixed" as if the user's SEM now models `(1 | g)`. Detection + C-exclusion shipped; the stored node is still ungrouped. The capability-status sentence states that limit. Inherited LOOP kit was replaced, not overwritten in place as if it were this lane's state.

## The lesson worth keeping

A detect-only warning that still feeds C is a silent-wrong-answer: the table looks honest and the combined statistic is not. Status membership is the load-bearing fix, not a louder message.
