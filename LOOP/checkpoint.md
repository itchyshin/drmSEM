# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-0 done (docs only).**
Phase 1 CLOSED on `main` @ `e7392d7`. A7 engine is the sibling lane,
not this kit.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + `LOOP/notes/A7-consumer-contract.md` +
  AGENT_LOG stub on this branch. `R/` empty vs `main`.
  Phase 1 (A0–A12) closed 2026-08-27; see
  `docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`.

ARC IN PROGRESS: none. Waiting on sibling.

NEXT: **A7c-1 / G-engine** — engine PR is **open**:
https://github.com/itchyshin/drmTMB/pull/1088 (Gamma / `mp-gamma-bernoulli`).
Wait until it is mergeable, then A7c-2 (lift Gamma only).

OPEN GATES (need human / sibling):
- **G-engine** — #1088 CI green / mergeable. Until then, no drmSEM `R/`.
- **G-claim** — later; default **keep `partial`**. No `"covered"`.

TRUTH LIVES IN:
- drmSEM `cursor/lane-s6-a7-consumer` @ this worktree
  `~/local-scratch/lanes/drmSEM-s6-a7-consumer`
- Parent `main` @ `e7392d7` (A12 closeout, #47)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine sibling: `~/local-scratch/lanes/drmTMB-s6-family-gate`
  on `cursor/lane-s6-family-gate` (do **not** duplicate)
- Phase 1 engine: drmTMB #1086 `1cc1985cd`
- MAG-completeness: **do not touch**

RESUME: You are the S6 A7 **consumer** lane — docs now, `R/` only
after G-engine. READ FIRST: LOOP/GOAL.md → LOOP/checkpoint.md →
LOOP/ultra-plan.md → LOOP/notes/A7-consumer-contract.md → repo
AGENTS.md. WORKSPACE: `cursor/lane-s6-a7-consumer` at
`~/local-scratch/lanes/drmSEM-s6-a7-consumer` (reattach + pull; do
NOT recreate; do NOT create `drmTMB-s6-family-gate`). CONTINUE FROM:
A7c-1. Pause at G-engine. capability-status stays `partial`.
Never `git add -A`. No `R/` until the first new-family engine PR is
mergeable.
