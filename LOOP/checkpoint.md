# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-3 LIFT.** Engine #1092
MERGED `7c104bbd5` (`mp-lognormal-bernoulli`). Consumer tests
green locally. Opening the consumer PR.
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

ARC IN PROGRESS: **A7c-3** lognormal × Bernoulli consumer lift.
`R/` + tests + ledger written. Waiting on #1092 merge, then
consumer PR.

NEXT CELL (after this consumer lands): **beta_binomial × Bernoulli**
engine (`mp-beta-binomial-bernoulli`). **Not** student (`nu` ABI).
**Not** nbinom2 × Gaussian. Checklist for this cell:
`LOOP/notes/A7c-3-lognormal-checklist.md`.

ENGINE STATUS (2026-08-27):
- Sibling owns `~/local-scratch/lanes/drmTMB-s6-family-gate`
  (`cursor/lane-s6-family-gate`). Do **not** duplicate.
- drmTMB **#1092 MERGED** `7c104bbd5fb796b02e75bf319e01701fb902067e`.
  Cell `mp-lognormal-bernoulli`. C++ first.

OPEN GATES:
- **G-engine-ln** — **DISCHARGED.** #1092 on `main` with C++
  `has_mi` + recovery + `missing_predictor` row. Not a whitelist-only
  diff.
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- This worktree / `cursor/lane-s6-a7-consumer`
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Checklist: `LOOP/notes/A7c-3-lognormal-checklist.md`
- Guardrails: `LOOP/notes/A7-claims-guardrails.md`
- Engine: drmTMB #1092 `7c104bbd5`
- MAG-completeness: **do not touch**

RESUME: Merge #1092 when CI green. Stamp engine sha. Push this
branch and open the consumer PR. Never `git add -A`.
