# A7 — Consumer contract (docs only)

**Status.** 2026-08-27, post A7c-2 (#49). Binding for the drmSEM
lane that follows drmTMB item 1 (#962). G-engine (Gamma) is
discharged. **A7c-3** is the next family cell: **lognormal ×
Bernoulli**, a mirror of A7c-2. Docs/prep only until the engine
lognormal `has_mi` PR is green or merged. Not an `R/` lift on this
prep commit.

**Audience.** The person who, after the sibling engine PR is
mergeable, opens this worktree and lifts **one** family gate in
`R/imputation.R`.

**Locks.** D-22; A1 (`LOOP/notes/A1-engine-contract.md`); A12
PLAN-ACTUAL; capability-status S6 row stays `partial`. Engine lane:
sibling `0a5d078f` at `~/local-scratch/lanes/drmTMB-s6-family-gate`
(`cursor/lane-s6-family-gate`). Do not create a second copy.

---

## 1. Division of labour

| Layer | Owns | Does not |
|---|---|---|
| drmTMB A7 | Per-family C++ observed-data likelihood (`has_mi` / `mi_family` in `src/drmTMB.cpp`). Ledger row on the existing `missing_predictor` axis. Widening `drm_missing_predictor_families()` **after** that wiring exists. | SEM graph, `drm_sem(impute = "auto")`, capability-status in drmSEM |
| drmSEM A7c | Emit `mi()` + one `impute_model()` per incomplete **endogenous** parent. Refuse cells the engine has not recovered. Keep V-80 locked to the engine list. | Likelihoods, whitelist-only promotions, `"covered"` |

Item 1 is **not** editing a character vector. Promoting a family
without `has_mi` is the #962 failure mode (drmTMB after-task
2026-08-09). drmSEM must not get ahead of that.

---

## 2. What is already wired (do not re-derive)

Honest map after drmTMB #1088 `6e553879` (do not re-derive):

| Response `model_type` | `has_mi` today | Predictor catalogue |
|---|---|---|
| gaussian (`1`) | yes | full predictor list + k=2 independent Gaussians |
| beta / binomial / poisson / nbinom2 (`10` / `18` / `6` / `7`) | yes | **bernoulli / binary only** |
| Gamma (`5`) | **yes** (#1088) | **bernoulli / binary only** (`mp-gamma-bernoulli`) |
| lognormal (`4`) | **yes** (#1092) | **bernoulli / binary only** (`mp-lognormal-bernoulli`) |
| student, beta_binomial, zi_poisson, zi_nbinom2, … | **none** | must stay refused |

First A7 cell (consumed): **Gamma × Bernoulli**. Next cell
(**A7c-3**): **lognormal × Bernoulli**. Not nbinom2 × Gaussian
(later expand-gated-family).

drmSEM mirrors that with three gates in `R/imputation.R` (read-only
this kickoff):

1. `drm_impute_response_families()` — `gaussian`, `poisson`,
   `binomial`, `nbinom2`, `beta`, `gamma`, `lognormal` after A7c-3.
   V-80
   `expect_setequal(..., drmTMB:::drm_missing_predictor_families())`
   is the anti-drift lock. Do not add beta_binomial here until that
   engine cell exists.
2. `drm_check_impute_legal()` — non-Gaussian response admits only a
   **binary** missing predictor (V-80c). Gaussian response admits
   `drm_impute_predictor_families()`.
3. `drm_check_two_gaussian_mi()` — k = 2 only when the response and
   both parents are Gaussian (V-79c). k > 2 still aborts (V-79b).

Phase 1 emit shape is unchanged: independent `impute_model()` per
parent, option (b), never `impute_joint`. See A1 §2.

---

## 3. What drmSEM must do when the engine ships a cell

A **cell** is a recovered (response family × predictor family × k)
tuple with a `missing_predictor` ledger row, not a hope.

When that PR is mergeable, the consumer does **exactly these
steps for that cell**, then stops:

1. **Read the engine reason.** Confirm C++ `has_mi` exists for that
   response, and which predictor families / k the recovery covers.
   If the PR only edits `drm_missing_predictor_families()`, refuse —
   that is a whitelist flip, not A7.
2. **Lift the matching drmSEM gate only.**
   - New **response** family → add it to
     `drm_impute_response_families()` so V-80 still matches.
   - New **predictor** for a non-Gaussian response → relax the
     binary-only branch in `drm_check_impute_legal()` for that
     pair only; leave other non-Gaussian responses binary-only.
   - New **k = 2** for a non-Gaussian response (or mixed Gaussian
     parents) → widen `drm_check_two_gaussian_mi()` to that tuple;
     keep every other k = 2 combination loud.
3. **Keep fail-loud leftovers.** Every cell not in the shipped
   tuple still aborts with the engine reason (family, k, or
   syntax). Do not emit a call drmTMB would reject later with less
   graph context.
4. **Keep V-80 as the anti-drift lock.** If the engine list and
   `drm_impute_response_families()` disagree, the suite fails here,
   not inside TMB. Add V-80d/e only if a new leftover needs a
   named reason (mirror V-80b/c).
5. **Identity before recovery.** Auto-derived fit ≡ hand-written
   `mi()` + `impute_model()` for the new cell (same convention as
   V-77 / V-82). A pretty recovery cannot hide a wrong emit.
6. **Known-DGP recovery.** MAR (outcome-dependent) required to
   claim the cell; MCAR-only is plumbing. Totoro for smoke; ask
   again before a replicated grid. Not GitHub Actions.
7. **Ledger cross-ref.** One new V-number in
   `docs/memory/VALIDATION_LEDGER.md` that names:
   - the drmSEM test id,
   - the engine cell id (e.g. `mp-<resp>-<pred>-…`),
   - the engine PR / sha,
   - the honest leftover list.
   Do not invent a second ledger axis.
8. **Docs.** `13-missing-data.md` legality table names the new
   cell and still says: not FIML; not a general missing-data SEM;
   k leftovers; exogenous → `na_action`.
9. **capability-status stays `partial`.** One extra family does not
   discharge piecewise re-estimation, k > 2, leftover families, or
   the “not beats complete-case” wording. No NEWS overclaim.

Then wait for the next engine cell. Repeat 1–9. Do not batch
unrecovered families into one consumer PR.

---

## 4. Fail-loud rules (must remain true after every cell)

| Situation | drmSEM must |
|---|---|
| Response family has no C++ `has_mi` | abort: “cannot carry a modelled missing predictor” (V-80b) |
| Non-Gaussian response × non-binary parent, unless that pair is the shipped cell | abort: “BINARY missing predictor” (V-80c) |
| k = 2 outside the shipped k = 2 tuple | abort with the engine’s k = 2 cell named (today: “two independent Gaussian”) |
| k > 2 | abort until the engine implements it (V-79b) |
| Incomplete **exogenous** parent | do not impute; leave on `na_action` |
| `mi()` on `sigma` / `zi` / other dpars | refuse (engine: `mu` only) |
| Transformed or interaction `mi()` | refuse: “not a plain additive term” |
| `impute = "auto"` on a complete node | leave the node untouched (`predictor = "model"` with zero `mi()` is an engine abort) |
| `imputed(sem)` with several parents | stack every parent; never silent first-`mi()` only (V-121c) |
| Reading SEs | branch on `uncertainty_status`, never `is.na(std_error)` |

Failing loud is **correct behaviour**, not a defect to “fix” by
widening a list.

---

## 5. V-80 anti-drift (load-bearing)

`tests/testthat/test-imputation.R` V-80 is the consumer’s #962
guard:

```r
engine <- getFromNamespace("drm_missing_predictor_families", "drmTMB")()
expect_setequal(drmSEM:::drm_impute_response_families(), engine)
```

- Engine widens first → V-80 fails until drmSEM adds the same name.
- drmSEM widens first → V-80 fails until the engine list matches,
  which must not happen without C++ `has_mi`.
- Never delete or skip V-80 to land a consumer PR.

V-80b/c stay as leftover reasons. New leftovers get new letters,
not a quieter V-80.

---

## 6. Ledger cross-ref

| drmSEM | drmTMB |
|---|---|
| `docs/memory/VALIDATION_LEDGER.md` (dated V-entry) | `docs/dev-log/dashboard/capability-ledger/cells.tsv` `missing_predictor` axis |
| Test id (`V-nnn`) | Cell id (`mp-…`) + evidence id (`ev-mp-…`) |
| `docs/design/13-missing-data.md` legality table | Engine recovery test path |

Phase 1 precedent: drmSEM V-120 ↔ engine
`mp-gaussian-gaussian-k2-indep` / #1086 `1cc1985cd`. A7c-5 copies
that pairing. Do not mark the engine cell `covered` from this repo.

---

## 7. Capability stays `partial`

`docs/design/capability-status.md` S6 row is `partial` because:

- piecewise re-estimation is not FIML across the SEM;
- k > 2 still aborts;
- non-Gaussian k = 2 still aborts (until a later cell);
- responses outside the allow-list still abort;
- the measured claim is narrow (“recovers the intercept and reduces
  mediator-coefficient bias under outcome-dependent missingness”),
  not “beats complete-case” and not “general missing-data SEM”.

Shipping one new family **does not** retire those leftovers. A12
already resolved G2 as keep `partial`. This programme does not
reopen that claim.

---

## 8. G-engine (opens drmSEM `R/`)

**Gamma (A7c-2) — discharged 2026-08-27.** drmTMB #1088 on `main` @
`6e553879` (`mp-gamma-bernoulli`). drmSEM #49 on `main` @ `ae2b925`.

**Lognormal (A7c-3) — OPEN.** Same five checks, new cell:

1. This contract still matches the emit shape (option b; no silent
   `impute_joint`).
2. The lognormal engine PR is **green or merged** (number not yet
   assigned as of this prep). Sibling
   `~/local-scratch/lanes/drmTMB-s6-family-gate` owns it. Do not
   duplicate that worktree.
3. That PR includes C++ `has_mi` for **lognormal**, a recovery
   test, and an honest `missing_predictor` row. Not a
   whitelist-only diff. Expected cell `mp-lognormal-bernoulli`.
4. Honest limits still written in `13-missing-data.md`.
5. capability-status still `partial`.

Until G-engine-ln, the current gates in `R/imputation.R` (lognormal
absent) are **correct leftovers**. V-80d refusing lognormal is the
lock working. See `LOOP/notes/A7c-3-lognormal-checklist.md`.

---

## 9. Out of scope

- FIML / joint SEM likelihood / Bayesian imputation
- Item 3 option (a): accept a fitted `drmTMB` as the imputer
- Incomplete exogenous imputation
- MNAR, multiple imputation, Rubin's rules, MCMC
- MAG / S3 grouping / `rho12`
- Creating `drmTMB-s6-family-gate` (already exists; sibling owns it)
- drmSEM `R/` before G-engine
- capability-status `"covered"`

---

## 10. Paste-ready drmTMB kickoff stub

drmTMB has no `docs/memory/AGENT_LOG.md`. Sibling should land the
block below on `cursor/lane-s6-family-gate` (suggested path:
`docs/dev-log/after-task/2026-08-27-s6-a7-family-gate-kickoff.md`).
A copy is also left uncommitted in that worktree if the file was
writable. Do not let this consumer lane commit on the engine branch.

```markdown
## 2026-08-27 — S6 A7 engine kickoff (item 1 / #962)

**Sibling consumer.** Cursor lane `cursor/lane-s6-a7-consumer` at
`~/local-scratch/lanes/drmSEM-s6-a7-consumer`. Docs only. No drmSEM
`R/` until this engine PR for the first new family is mergeable.
Contract: drmSEM `LOOP/notes/A7-consumer-contract.md`.

**This lane owns.** Per-family C++ `has_mi` (#962), one family at a
time. Not a whitelist edit. Not `impute_joint`. Not FIML. Ledger row
on the existing `missing_predictor` axis.

**Do not.** Duplicate this worktree. Touch drmSEM `R/`. Flip drmSEM
capability-status to `covered`. Re-open Phase 1 k=2 Gaussian
(`mp-gaussian-gaussian-k2-indep`, #1086 `1cc1985cd`).
```
