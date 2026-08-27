# A7c-3 — Lognormal × Bernoulli consumer checklist

**Status.** 2026-08-27, docs/prep. **Do not start `R/`** until the
drmTMB lognormal `has_mi` PR exists and is **green or merged**.
This cell is a **mirror of A7c-2** (Gamma × Bernoulli, #49).

**Lane.** `cursor/lane-s6-a7-consumer` at
`~/local-scratch/lanes/drmSEM-s6-a7-consumer`. Do not create
`drmTMB-s6-family-gate` (sibling owns it). Never `git add -A`.
capability-status stays `partial`. See
`LOOP/notes/A7-claims-guardrails.md`.

---

## 0. G-engine-ln (opens `R/`)

Refuse the lift unless **all** of these are true:

1. An engine PR exists (number goes here: **#____**).
2. That PR (or `main` after merge) includes **C++ `has_mi`** for a
   **lognormal response**. A whitelist-only edit of
   `drm_missing_predictor_families()` is the #962 failure mode —
   refuse it.
3. Predictor coverage is **Bernoulli / binary only** (same as
   Gamma). If the engine ships a wider predictor catalogue, stop
   and re-read the contract; do not silently relax V-80c.
4. Recovery test + honest `missing_predictor` row exist. Expected
   cell id: **`mp-lognormal-bernoulli`**. Confirm the real id from
   the engine ledger; do not invent a second axis.
5. Engine sha recorded: **`________`**.

Until 1–5, V-80d (lognormal leftover fails loud) is **correct**.

---

## 1. `R/imputation.R` list update (only after §0)

Mirror A7c-2. One family. Stop.

- [ ] Add `"lognormal"` to `drm_impute_response_families()`.
      Expected list after the lift:
      `gaussian, poisson, binomial, nbinom2, beta, gamma, lognormal`.
- [ ] **Do not** copy `drm_impute_family_key()` Gamma mapping unless
      the engine list uses a different string than
      `drmTMB::lognormal()$family`. Today both are `"lognormal"`.
      Confirm against the installed engine before adding a key.
- [ ] Do **not** widen `drm_impute_predictor_families()`.
- [ ] Do **not** relax `drm_check_impute_legal()` binary-only for
      non-Gaussian responses (lognormal still admits only a binary
      parent).
- [ ] Do **not** touch `drm_check_two_gaussian_mi()`.
- [ ] Do **not** emit `impute_joint`. Option (b) only.

---

## 2. V-80 anti-drift + leftover letters

V-80 stays `expect_setequal` against
`drmTMB:::drm_missing_predictor_families()`. Never skip it.

| id | after A7c-3 | notes |
|---|---|---|
| **V-80** | list includes `lognormal` | fails if drmSEM or engine drifts |
| **V-80b** | unchanged | Gamma + binary emits; Gamma + continuous fails |
| **V-80c** | unchanged | other non-Gaussian × continuous still `"BINARY missing predictor"` |
| **V-80d** | **retarget leftover** | today this *is* lognormal. After the lift, point it at the next unwired #962 family: **`student`** (then beta_binomial, zi_*). Same abort: `"cannot carry a modelled missing predictor"` |
| **V-80e** | **new** | lognormal + **binary** parent **emits**; lognormal + **continuous** parent fails loud (`BINARY missing predictor`). Mirror V-80b |

Fail-loud continuous is load-bearing. Lifting the response family
must not let a Gaussian/continuous parent through on a lognormal
node.

---

## 3. Reserved V-numbers (claim these; do not reuse)

| drmSEM | role | engine pair |
|---|---|---|
| **V-123** | identity: auto-derived fit ≡ hand-written `mi()` + `impute_model()` | `mp-lognormal-bernoulli` |
| **V-123b** | MAR recovery-to-truth (outcome-dependent missingness) | same cell + engine PR/sha |

Do not invent a second ledger axis. Do not mark the engine cell
`covered` from this repo. Distinct from sampler V-60 (lognormal
meanlog/sdlog) and effect V-52/V-53.

`skip_if_not(engine_accepts_lognormal())` — helper mirrors
`engine_accepts_gamma()`, keyed on `"lognormal"` in the engine
allow-list.

---

## 4. Tests (`tests/testthat/test-imputation.R`)

Mirror `gamma_binary_dat()` / `gamma_binary_specs()` /
V-122 / V-122b. **Match the engine recovery DGP** (meanlog/sdlog,
MAR rule, n, seeds) once the engine PR exists. Do not invent a
second parameterization.

Sketch only (fill from the engine test; `mu` is meanlog, identity):

```r
# z -> treatment (Bernoulli) -> w (lognormal)
# meanlog = a + b*z + c*treatment; w ~ logN(meanlog, sdlog)
# MAR: drop treatment depending on the outcome (not MCAR-only)
```

- [ ] Header comment: V-80d leftover = student; V-80e lognormal
      emit + continuous fail-loud; V-123 / V-123b.
- [ ] Identity before recovery (same convention as V-77 / V-122).
- [ ] MAR required to claim the cell. MCAR-only is plumbing.
- [ ] Totoro for smoke if a replicated grid is proposed later.
      Not GitHub Actions for the grid.

---

## 5. Ledger + docs (same PR as the lift)

- [ ] `docs/memory/VALIDATION_LEDGER.md` — V-123 / V-123b row:
      test id, engine cell id, engine PR/sha, leftover list
      (student, …; non-Gaussian k=2; k>2).
- [ ] `docs/design/13-missing-data.md` legality table: add
      `lognormal` to the binary-only response row. Move lognormal
      off the leftover-family sentence. Keep: not FIML; not
      `impute_joint`; exogenous → `na_action`.
- [ ] `docs/design/capability-status.md` S6 row: **name the cell**,
      stay **`partial`**. No `"covered"`. See guardrails.
- [ ] NEWS: one named-cell sentence + leftovers + closer
      (template in `LOOP/notes/A7-claims-guardrails.md`).
- [ ] `docs/memory/AGENT_LOG.md` — what shipped, engine sha, next
      leftover (student).
- [ ] Update this checklist + `LOOP/checkpoint.md` after merge.

---

## 6. After local green → PR → merge

Shinichi: keep going. When G-engine-ln is discharged:

1. Implement §1–§5 on this branch (explicit `git add` paths).
2. `testthat::test_file("tests/testthat/test-imputation.R")`
   against the engine sha. Record pass/fail/skip.
3. Push `cursor/lane-s6-a7-consumer` and open the consumer PR.
4. Merge if CI green. Stamp merge sha. capability stays `partial`.

Then wait for the next *engine* family (student). Do not batch.

---

## Out of scope

- Engine C++ / a second `drmTMB-s6-family-gate`
- nbinom2 × Gaussian (later expand-gated-family)
- FIML / `impute_joint` / exogenous imputation / k>2
- capability-status `"covered"`
- MAG / S3 / `rho12`
