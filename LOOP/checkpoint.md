# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: S0 planning kickoff landed locally; awaiting G0.

ARCS DONE (verified):
- S0 / A0 in progress until this commit is on `cursor/lane-s6-imputation`:
  fresh LOOP kit (not the inherited Step 2 S3-grouping kit), arc charter,
  D-22 draft, AGENT_LOG entry. No drmSEM `R/` edits.

ARC IN PROGRESS: none (planning closed pending G0)

NEXT: Shinichi G0 approval (checklist in LOOP/ultra-plan.md). After G0,
A1 engine-contract draft in this lane (docs only). No drmSEM `R/`.
Phase 1 engine work is a **separate drmTMB lane** from `origin/main`.

OPEN GATES (need human):
- **G0** — plan approval (required before A1 / Phase 1)
- Push / PR / merge — denied; surface if wanted later
- **G1** — before any drmSEM `R/`
- **G2** — before merge / public claim

TRUTH LIVES IN:
- Lane `cursor/lane-s6-imputation` @ `~/local-scratch/lanes/drmSEM-s6-imputation`
- Parent `main` @ `0852f9f` (untouched by this lane's `R/`)
- Charter: `docs/memory/2026-08-26-next-arc-s6-imputation.md`
- Plan: `LOOP/ultra-plan.md`
- Order lock: D-22 in `docs/memory/DECISIONS.md`
- MAG-completeness worktree: **do not touch**

RESUME: read LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md.
Continue from NEXT. Do not start drmSEM `R/`. Do not push.

HUMAN GATE: G0. No push/merge from this kickoff.
