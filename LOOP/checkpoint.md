# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-4 LIFT.** Engine #1094
MERGED `4c34c9bb` (`mp-beta-binomial-bernoulli`). Consumer tests
**88 pass / 0 fail / 0 skip**. Opening the consumer PR.
Worktree `~/local-scratch/lanes/drmSEM-s6-a7-consumer` on
`cursor/lane-s6-a7-consumer`. capability-status stays **`partial`**.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + contract (#48 `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
- **A7c-2** — consumer Gamma lift. drmSEM **#49 MERGED**
  `ae2b925521555e604101a58ed821e33d95c3661b`.
- **A7c-3** — consumer lognormal lift. drmSEM **#50 MERGED**
  `1e5d4cfbef3d1e130f205a910b86750ecf5f1fc0`.

ARC IN PROGRESS: **A7c-4** beta_binomial × Bernoulli consumer lift.
`R/` + tests + ledger written. Engine on `main`.

NEXT after this consumer: #962 leftovers are **student** (`nu` ABI
— wait) and **zi_*** (mixture — wait). Extra-#962
`truncated_nbinom2` only if Shinichi asks. **Not** nbinom2 ×
Gaussian.

OPEN GATES:
- **G-engine-bb** — **DISCHARGED.** #1094 on `main` with C++
  `has_mi` + recovery + `missing_predictor` row. Not a whitelist-only
  diff.
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- This worktree / `cursor/lane-s6-a7-consumer`
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1094 `4c34c9bb`
- MAG-completeness: **do not touch**

RESUME: Push this branch and open the consumer PR. Merge if CI
green. Stamp merge sha. Never `git add -A`.
