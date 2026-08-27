# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-3 MERGED.** G-engine-ln
discharged. drmSEM `main` @ `1e5d4cf` lifts lognormal × Bernoulli.
capability-status stays **`partial`**.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + contract (#48 `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
- **A7c-2** — consumer Gamma lift. drmSEM **#49 MERGED**
  `ae2b925521555e604101a58ed821e33d95c3661b`.
- **A7c-3** — consumer lognormal lift. drmSEM **#50 MERGED**
  `1e5d4cfbef3d1e130f205a910b86750ecf5f1fc0`.
  `test-imputation.R`: **79 pass / 0 fail / 0 skip** locally against
  drmTMB `7c104bbd5`. CI: macos / ubuntu / windows green.

ARC IN PROGRESS: none on this commit.

NEXT: wait for the next *engine* family (**beta_binomial** `has_mi`,
drmTMB #1094). Do not lift beta_binomial here until that PR is on
`main` with C++. Student waits (`nu` ABI). Do not start nbinom2 ×
Gaussian.

CELL JUST CONSUMED: **lognormal × Bernoulli**
(`mp-lognormal-bernoulli`). Ledger: V-123 / V-123b ↔ #1092
`7c104bbd5` / #50 `1e5d4cf`.

OPEN GATES:
- **G-engine-ln** — **discharged.**
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- drmSEM `main` @ this commit (post #50)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1092 `7c104bbd5`; next engine #1094
- MAG-completeness: **do not touch**

RESUME: A7c-3 is closed. Next consumer cell waits on engine
beta_binomial. Never `git add -A`.
