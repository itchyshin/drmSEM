# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: G0 approved 2026-08-26 (all 10
defaults). **IN PROGRESS.** A1 + A3 drafted; A2 skipped.

ARCS DONE (verified):
- S0 / A0 @ `ec41d94` / `40fb85c` — LOOP kit, charter, D-22.
  Verified: `git log` on this worktree; `R/` unchanged.
- **G0** — Shinichi approved all 10 checklist items with defaults
  (2026-08-26).
- **A1** — `LOOP/notes/A1-engine-contract.md`. Independence, emit
  shape `y ~ mi(m1)+mi(m2)+x`, `impute_model()` per parent,
  `imputed()` tiers, family cells, G1 criteria. Verified: file
  exists; no `R/` diff.
- **A3** — `LOOP/notes/A3-joint-mi-verdict.md`. Read-only on
  `drmTMB-joint-mi` @ `cbbf380bd` (3 ahead / 207 behind
  `origin/main` `fc8ee77a6`). Verdict: leave; do not rebase.
  Verified: note cites clone SHA and the live `length(mi_calls) != 1L`
  gate on `origin/main`.

ARC IN PROGRESS: none on this drmSEM lane. A2 paused (G0 item 8).

NEXT: **drmTMB Phase 1 lane creation** from `origin/main` (not the
dirty primary checkout, not `drmTMB-joint-mi`). Then A4 + A5
together, then A6 on Totoro. No drmSEM `R/` until G1.

OPEN GATES (need human):
- Push / PR / merge / GitHub comments — denied (A2 waits)
- **G1** — before any drmSEM `R/`
- **G2** — before merge / public claim
- **G3** — if independence fails and only `impute_joint` works

TRUTH LIVES IN:
- Lane `cursor/lane-s6-imputation` @ `~/local-scratch/lanes/drmSEM-s6-imputation`
- Parent `main` @ `0852f9f` (`R/` untouched)
- Contract: `LOOP/notes/A1-engine-contract.md`
- Joint-mi verdict: `LOOP/notes/A3-joint-mi-verdict.md`
- Charter: `docs/memory/2026-08-26-next-arc-s6-imputation.md`
- Plan: `LOOP/ultra-plan.md` (frozen at G0)
- Order lock: D-22 in `docs/memory/DECISIONS.md`
- MAG-completeness worktree: **do not touch**

RESUME: read LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md
→ LOOP/notes/A1-engine-contract.md. Continue from NEXT (new drmTMB
lane from `origin/main`). Do not start drmSEM `R/`. Do not push.
Do not comment on #963/#962.

HUMAN GATE: G1 before drmSEM `R/`. No push/merge from this commit.
