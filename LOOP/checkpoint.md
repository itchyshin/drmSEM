# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-3 PREP.** Waiting on engine
lognormal `has_mi`. drmSEM `main` @ `0cb3360` (A7c-2 stamped).
Worktree `~/local-scratch/lanes/drmSEM-s6-a7-consumer` on
`cursor/lane-s6-a7-consumer`. capability-status stays **`partial`**.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + contract (#48 `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
- **A7c-2** — consumer Gamma lift. drmSEM **#49 MERGED**
  `ae2b925521555e604101a58ed821e33d95c3661b`.
  `test-imputation.R`: **70 pass / 0 fail / 0 skip** locally against
  drmTMB `6e553879`. CI: macos / ubuntu / windows green.

ARC IN PROGRESS: **A7c-3** lognormal × Bernoulli (docs/prep only).
No drmSEM `R/` until the engine PR is **green or merged**.

NEXT CELL (locked): **lognormal × Bernoulli**
(`mp-lognormal-bernoulli`, expected). Mirror of Gamma A7c-2.
**Not** nbinom2 × Gaussian. **Not** student. Checklist:
`LOOP/notes/A7c-3-lognormal-checklist.md`.

ENGINE STATUS (2026-08-27, this prep):
- Sibling owns `~/local-scratch/lanes/drmTMB-s6-family-gate`
  (`cursor/lane-s6-family-gate`). Do **not** duplicate.
- No open drmTMB PR for lognormal `has_mi` yet. Do not lift
  `"lognormal"` in `drm_impute_response_families()`.

OPEN GATES:
- **G-engine-ln** — **OPEN.** Wait for drmTMB lognormal × Bernoulli
  `has_mi` PR (C++ + recovery + `missing_predictor` row). Not a
  whitelist-only diff. Then implement the consumer lift.
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- This worktree / `cursor/lane-s6-a7-consumer` (from `0cb3360`)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Checklist: `LOOP/notes/A7c-3-lognormal-checklist.md`
- Guardrails: `LOOP/notes/A7-claims-guardrails.md`
- Engine (last shipped cell): drmTMB #1088 `6e553879`
- MAG-completeness: **do not touch**

RESUME: Docs/prep is on this branch. `R/` opens only after the
lognormal engine PR exists and is green or merged. Never
`git add -A`.
