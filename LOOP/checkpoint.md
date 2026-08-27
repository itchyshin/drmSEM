# Checkpoint — OVERWRITTEN every arc

GOAL: see LOOP/GOAL.md. STATE: **A7c-2 local-green** on
`cursor/lane-s6-a7c2-gamma` (worktree
`~/local-scratch/lanes/drmSEM-s6-a7-consumer`).
`test-imputation.R`: **70 pass / 0 fail / 0 skip** against drmTMB
`6e553879`.

ARCS DONE (verified):
- **A7c-0** — LOOP kit + `LOOP/notes/A7-consumer-contract.md` (#48
  `1593a23`).
- **A7c-1** — wait for first new-family engine PR. drmTMB **#1088
  MERGED** `6e553879753a2a932ed09d2bba19b21a4b1e00d2`.
  Cell `mp-gamma-bernoulli` (Gamma × one Bernoulli `mi()`).

ARC IN PROGRESS: **A7c-2** Gamma consumer lift (this branch).

NEXT: finish local tests → PR → merge if CI green. Then wait for
the next *engine* family (lognormal). Do not start lognormal here.

FIRST CELL (locked): **Gamma × Bernoulli** (`mp-gamma-bernoulli`,
#962 first *unwired* family). **Not** nbinom2 × Gaussian.

G-ENGINE OPEN STEPS (this branch):
1. Branch `cursor/lane-s6-a7c2-gamma` from drmSEM `main` @ `c033bda`.
2. Installed engine confirmed: drmTMB `6e553879` —
   `drmTMB:::drm_missing_predictor_families()` includes `"gamma"`.
3. `"gamma"` added to `drm_impute_response_families()`.
   `drm_impute_family_key()` maps `stats::Gamma()` → `"gamma"`.
4. V-80b: Gamma + **binary** parent emits; Gamma + continuous parent
   fails loud. V-80d: lognormal leftover still fails loud.
5. V-122 identity + V-122b MAR recovery.
6. Ledger V-122 / V-122b ↔ engine `mp-gamma-bernoulli` / #1088
   `6e553879`.
7. `13-missing-data.md` names the cell. capability-status stays
   `partial`. No `"covered"`. Not FIML. Not `impute_joint`.

OPEN GATES:
- **G-engine** — **discharged** (#1088 on drmTMB `main` @ `6e553879`).
- **G-claim** — keep `partial`. No `"covered"`.

TRUTH LIVES IN:
- This worktree / `cursor/lane-s6-a7c2-gamma`
- Contract: `LOOP/notes/A7-consumer-contract.md`
- Engine: drmTMB #1088 `6e553879` (Gamma `has_mi`)
- MAG-completeness: **do not touch**

RESUME: You are the S6 A7 **consumer** lane on A7c-2.
READ FIRST: LOOP/GOAL.md → LOOP/checkpoint.md → LOOP/ultra-plan.md
→ LOOP/notes/A7-consumer-contract.md → repo AGENTS.md.
CONTINUE FROM: local test evidence, then PR. capability-status stays
`partial`. Never `git add -A`.
