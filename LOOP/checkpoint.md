# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-2 MERGED.** G-engine discharged.
drmSEM `main` @ `ae2b925` lifts Gamma × Bernoulli. capability-status
stays **`partial`**.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + contract (#48 `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
- **A7c-2** — consumer Gamma lift. drmSEM **#49 MERGED**
  `ae2b925521555e604101a58ed821e33d95c3661b`.
  `test-imputation.R`: **70 pass / 0 fail / 0 skip** locally against
  drmTMB `6e553879`. CI: macos / ubuntu / windows green.

ARC IN PROGRESS: none on this commit.

NEXT: wait for the next *engine* family (**lognormal** `has_mi`).
Do not lift lognormal here. A later family repeats A7c-2–A7c-6.

FIRST CELL (locked, now consumed): **Gamma × Bernoulli**
(`mp-gamma-bernoulli`). Ledger: V-122 / V-122b ↔ #1088 `6e553879`.

OPEN GATES:
- **G-engine** — **discharged.**
- **G-claim** — keep `partial`. No `"covered"`. Not FIML.

TRUTH LIVES IN:
- drmSEM `main` @ this commit (post #49)
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1088 `6e553879`
- MAG-completeness: **do not touch**

RESUME: A7c-2 is closed. Next consumer cell waits on engine
lognormal. Never `git add -A`.
