# A7 — `zi_*` × `mi()` named decision

**Status.** **G0 APPROVED 2026-08-27 — option (b).** Locked
implementation path. First engine cell:
`mp-zi-poisson-bernoulli` on isolated drmTMB worktree
`cursor/lane-s6-zi-mi` @ `~/local-scratch/lanes/drmTMB-s6-zi-mi`.
**Lane (this docs tree).** `cursor/lane-s6-a7-zi-mi` at
`~/local-scratch/lanes/drmSEM-s6-a7-zi-mi`.
**Lease.** `cursor:drmSEM-s6-a7-zi-mi` holds `LOOP/notes/` (docs).
Engine work is a **new** lease on the drmTMB worktree. Do not touch
student / nbinom2-gaussian / family-gate trees.
**Did not touch.** `drmTMB-s6-student-mi`,
`drmTMB-s6-nbinom2-gaussian`, `drmTMB-s6-family-gate`,
`drmTMB-s6-multi-mi`.

---

## G0 stamp (CONFIRMED 2026-08-27)

Shinichi approved **(b)**. The six locks from §5 are **CONFIRMED**:

| ID | Lock | CONFIRMED |
|---|---|---|
| **G0-1** | Path **(b)**: `mi()` in `mu` only; ZIP/ZINB mixture in the 2-point sum; `eta_zi` from observed-only predictors. Not forever-(a). | **CONFIRMED** |
| **G0-2** | Implement on a **new isolated** drmTMB worktree. Do **not** collide with the live student or nbinom2-gaussian lanes. | **CONFIRMED** |
| **G0-3** | First `zi` formula: **`zi ~ 1`** for the recovery DGP; **`zi ~` fully observed covariates** allowed in the spec if they are complete. `zi ~ mi(x)` and any incomplete `zi` symbol stay refused. | **CONFIRMED** |
| **G0-4** | Kernel: **inline** the ZIP mixture in `model_type == 8`. Do **not** extend `drm_response_log_density` with `eta_zi`. | **CONFIRMED** |
| **G0-5** | Consumer: refuse-now on `model_type` if `impute = "auto"` would emit-then-crash; **then lift** when this cell exists. Never alias `zi_*` as `poisson` for V-80. | **CONFIRMED** |
| **G0-6** | Compute: **Totoro**, n small, one seed. Ask again before a replicated grid. | **CONFIRMED** |

Decision id: **D-23** (`zi + mi() = mu-only mixture`). Not FIML.
Capability stays **`partial`**. Keep refuse until this leaf exists;
then lift carefully.

**Sources.** drmTMB `R/drmTMB.R` Poisson refuse ~7127–7131 and nbinom2
refuse ~7670–7675; `src/drmTMB.cpp` `model_type == 6` Bernoulli `mi()`
(~3774–3821) vs `model_type == 8` ZIP mixture (~3826–3893);
`src/drm_response_kernels.h` (no case 8/9; `default` returns `0.0`);
`LOOP/notes/A7-post-lognormal-queue.md` (family-gate worktree; rank 3
**L — wait**); GitHub [#962](https://github.com/itchyshin/drmTMB/issues/962)
(comments name Gamma then lognormal; they do **not** unlock zi);
drmSEM `LOOP/notes/A7-consumer-contract.md` §4 (`mi()` on `zi` refused;
`mu` only); `R/imputation.R` family-name gate;
`docs/design/19-family-link-contract.md` (`zi` = structural-zero
probability, not the conditional mean).

**Locks this note does not reopen.** D-22; #962 is C++ `has_mi`, not a
gate flip; capability-status stays **`partial`**; this is **not FIML**;
`mi()` remains legal only as a bare additive term in **`mu`**.

---

## Verdict (read this first)

**Recommend option (b) as the locked future cell, not as work to start
now.**

| Option | One line | Call |
|---|---|---|
| **(a)** Keep refuse forever, better message | Correct *until* a mixture leaf exists; “forever” over-claims | **Keep the refuse as the live product.** Improve the message. Do not ratify “never”. |
| **(b)** Allow `mi()` in `mu` only; 2-point sum uses the ZIP/ZINB mixture; `eta_zi` from observed predictors only | The only honest first cell if Shinichi unlocks L-scope | **Locked implementation path.** First cell must be narrower than “any zi formula”. |
| **(c)** Other (`mi()` on `zi`; `mi()` on both; two-stage / complete-case zi) | Different estimand, or unidentified from zeros | **Reject** as a first cell. |

**Human G0 is required.** This is a composition and identification
decision, not a Gamma-style clone. The post-lognormal queue already
marked it **L — wait**. Student (`nu` ABI) is a live L-scope tree —
do not start a second L-scope C++ derivation until Shinichi names
the order.

**Spike: none.** Scope is not bounded enough to write likelihood
code. Stop here.

---

## 1. What the product does today

Zero inflation is a **formula**, not a family constructor.
`family = poisson()` + `zi ~ …` becomes `model_type == 8`
(`zi_poisson`). `family = nbinom2()` + `zi ~ …` becomes
`model_type == 9` (`zi_nbinom2`). There is no public `zi_poisson()`.

**Missing response** on those routes is implemented (G5 on
`zi_poisson` include-mask). **Missing predictor** is not.

| Response | `mi()` + no `zi` | `mi()` + `zi ~` |
|---|---|---|
| Poisson | Wired. Bernoulli predictor only. Fixed `mu`. Cell `mp-poisson-bernoulli`. | **Hard abort** (~7127): *“Poisson-response `mi` predictor models are not implemented with zero inflation yet.”* |
| nbinom2 | Wired. Bernoulli predictor only. Fixed `mu`/`sigma`. Cell `mp-nbinom2-bernoulli`. | **Hard abort** (~7670): first slice is *“fixed-effect `mu`/`sigma` only”* — `zi` is listed with RE/structured as a thing to remove. |

Those are two different messages for the same composition hole.
Poisson names zero inflation. nbinom2 buries it inside a
fixed-effects leftover. A user who removes RE and keeps `zi ~ 1`
still dies, and the hint does not say why.

`has_mi` is a global `DATA_INTEGER`. Wiring is per `model_type`
block. `drm_response_log_density` has leaves for 1, 4, 5, 6, 7, 10,
14, 18. Cases **8 and 9 are absent**. The `default` returns
`Type(0.0)`. Admitting `zi_*` by flipping
`drm_missing_predictor_families()` would drop the response density
in the 2-point sum. That is the #962 failure mode. The refuse is
the lock working.

#962 comments (2026-08-26 sequencing; 2026-08-27 A7 first family)
confirm item 1 is per-family C++ after k=2, first cell Gamma, next
named family lognormal. They do **not** authorize zi. The
family-gate scout (`A7-post-lognormal-queue.md`) ranks
`mp-zi-poisson-bernoulli` as **L — wait (`zi` + `mi` conflict)**
and treats `mp-zi-nbinom2-bernoulli` as the same wait plus
`sigma`. That ranking still holds after beta_binomial landed.

---

## 2. How Poisson / nbinom2 `mi()` works (the thing zi cannot reuse)

For a Poisson response and one Bernoulli missing predictor
(`mi_family == 1`), the engine already does this:

**Observed `x`.** Add the Bernoulli log-density and shift
`eta_mu` by `β_μ · (x − X_μ[, mi_col])`. Then the main loop adds
`dpois(y, exp(eta_mu))`.

**Missing `x`.** Two-point sum over `{0, 1}`:

```
log P(y, x missing) = logsumexp(
  log p(x=1) + log f(y | η₁),
  log p(x=0) + log f(y | η₀)
)
```

`f` is the **plain Poisson** leaf (`drm_response_log_density` case 6).
`eta_zi` is not in that signature
`(model_type, y, eta, log_sigma, V_known, trials, link_code)`.
The main-loop `dpois` is skipped on missing-`x` rows
(`!(has_mi && mi_family != 0 && mi_observed == 0)`), so the 2-point
sum is the whole contribution.

nbinom2 is the same shape with case 7 and a live `log_sigma`.
`sigma` is not marginalized over `x` because `mi()` is illegal
outside `mu`.

ZIP / ZINB cannot call that leaf. The fitted density is already a
mixture. For ZIP (`model_type == 8`):

```
P(y = 0 | μ, π) = π + (1 − π) e^{−μ}
P(y > 0 | μ, π) = (1 − π) Pois(y | μ)
```

with `μ = exp(eta_mu)` and `π = logit⁻¹(eta_zi)` (log-space
`logspace_add` in the engine). A path to `zi` is **not** a path to
the conditional mean. Substituting case 6 into the 2-point sum
would treat structural zeros as Poisson zeros and silently
mis-target `π`.

---

## 3. Options

### (a) Keep refuse forever, better message

**What ships.** No `has_mi` on cases 8/9. Spec builders keep
aborting. drmSEM never adds `zi_*` to
`drm_impute_response_families()`.

**Better messages (draft; do not land without G0).**

Poisson:

```
Zero-inflated Poisson cannot yet carry a modelled missing predictor.
x  mi() on mu of a zi_* node needs the ZIP mixture in the 2-point
   sum, and the shared response leaf has no eta_zi.
i  Fit without zi, or complete the predictor.
i  mi() is legal only in mu. A path to zi is not a path to the
   conditional mean. See LOOP/notes/A7-zi-mi-decision.md.
```

nbinom2: same sentence, plus “this is not the RE leftover.” Stop
bundling `zi` with random/structured terms.

**Risks of “forever”.** Ecology count nodes are often ZIP/ZINB.
A SEM that already recovers Poisson × Bernoulli `mi()` loses
`mi()` the moment the user adds `zi ~ 1`. That is a real product
hole, not a forgotten clone. Ratifying never closes #962’s last
named pair by policy rather than by evidence.

**Risks of keeping the refuse (recommended until G0).** Honest.
Cheap. Matches the L-scope queue. The current wording is the
weak part, not the abort.

### (b) `mi()` in `mu` only; mixture density; `eta_zi` observed-only

**Estimand.** One Bernoulli missing predictor in **`mu`**.
`zi` is a second linear predictor that does **not** contain
`mi(x)`. For missing `x`:

```
P(y | x missing, π) = p(x=1) ZIP(y | μ(x=1), π)
                    + p(x=0) ZIP(y | μ(x=0), π)
```

`π` is the same in both arms (or depends only on fully observed
covariates). That is a well-defined observed-data likelihood. It
is **within-node** re-estimation of the parent Bernoulli, same as
every other `mi()` cell. **Not FIML** across the SEM.

**First cell (recommended narrowing).**

| Knob | First cell | Still refuse |
|---|---|---|
| Response | `zi_poisson` only | `zi_nbinom2` (extra `sigma`) |
| Predictor | one Bernoulli | Gaussian / other; k=2 |
| `zi` formula | `zi ~ 1`, or `zi ~` fully observed covariates | `zi ~ mi(x)`; `zi ~` any incomplete symbol |
| Effects | fixed `mu` and `zi` | RE / structured / phylo / spatial |
| Missing `y` | off | `mi()` + response mask together |
| Phase-1 terms | none | transforms, interactions, offsets on `zi` |

zi_nbinom2 is the same composition plus a dispersion dpar. Do not
start there “to get both families.”

**C++ (only after G0).** Inline the 2-point ZIP mixture inside
`model_type == 8`. Do **not** extend
`drm_response_log_density` with `eta_zi` (that is the student/`nu`
ABI problem). Do **not** stuff `eta_zi` through `V_known_val` or
`trials_val`. Do **not** flip the allow-list first. After the leaf
and a recovery test exist: one honest
`mp-zi-poisson-bernoulli` row, then the allow-list.

**Identification.** Zeros are generated two ways: structural (`π`)
and Poisson (`e^{−μ}`). `mi()` on `mu` only keeps `π` from
depending on the missing `x`, which is what makes the split
possible:

- `y > 0` rows identify `μ(x)` the same way Poisson `mi()` does.
- The extra-zero mass, shared across `x ∈ {0,1}`, identifies `π`.
- Missing-`x` zeros still contribute, but they are a mixture of
  two ZIPs with the **same** `π`.

This fails when most zeros coincide with missing `x`, when `π` is
near 0 or 1, or when `μ(x=0)` and `μ(x=1)` are not separated by
enough observed-`x` positives. That is a DGP design problem, not a
reason to put `mi()` on `zi`.

**Testing (minimum, after G0).** Symbolic alignment first (ZIP
mixture, not Poisson). Then:

1. **Identity.** Auto-derived SEM emit ≡ hand-written
   `y ~ mi(x) + …, zi ~ 1` plus `impute_model(x ~ …, binomial())`.
2. **MAR recovery.** Outcome-dependent missingness on `x`. Recover
   `β_μ` on `x` **and** `β_zi`. MCAR-only is plumbing.
3. **Null / control.** DGP with `π = 0` (or tiny): `β_zi` goes to
   the boundary; `β_μ` still recovers. DGP with `β_μ(x) = 0` and
   `π > 0`: do not let extra zeros load onto `x`.
4. **Swap test.** A fit that drops `zi` must *not* recover the ZIP
   DGP’s `β_μ` as if the zeros were Poisson. If it does, the cell
   is unidentified and must stay refused.

Totoro for smoke. Ask again before a replicated grid. Not GitHub
Actions. Compute is a default condition.

**SEM emit.** `drm_wrap_mi()` already rewrites **only** the `mu`
entry and leaves `zi ~` untouched. That is the right shape for
(b). The consumer gate is not. `drm_check_impute_legal()` keys on
`family$family` (`"poisson"` / `"nbinom2"`), not `model_type`
(`zi_poisson` / `zi_nbinom2`). drmTMB folds zi into `model_type`
and leaves the base family name in place (same split as hurdle;
see `drm_fit_model_type()`). So today a ZIP node with an
incomplete parent **looks legal**, emits `mi()` on `mu`, and the
engine aborts with less graph context. The consumer contract
forbids that. After (b) lands, admitting the cell as `"poisson"`
would also hide it from V-80. The consumer must key leftover
`zi_*` on **`model_type`**, keep V-80 locked to the engine list,
and never call this FIML.

**Capability.** One ZIP × Bernoulli cell does not flip S6 to
`"covered"`. Leftovers remain: piecewise ≠ FIML; k>2; non-Gaussian
k=2; `zi_nbinom2`; `mi()` on `zi`; student; exogenous →
`na_action`.

### (c) Other — rejected as a first cell

| Variant | Why not first |
|---|---|
| **(c1) `mi()` on `zi` only** | A path to `zi` is a path to the structural-zero probability. Missing `x` then identifies `π(x)` from zeros. Useful ecology later; different estimand; no Poisson-`mi()` clone. |
| **(c2) `mi()` on both `mu` and `zi`** | `π(x=0)` vs `π(x=1)` and `μ(x=0)` vs `μ(x=1)` are not separated by zeros alone. Identification trap. |
| **(c3) Two-stage / complete-case `zi`, then Poisson `mi()`** | Not the ZIP observed-data likelihood. Would claim a mixture and fit a truncated or dropped-zero model. |
| **(c4) Wait for student ABI, then add `eta_zi` to the shared leaf** | Couples two L-scope items. Student needs `nu`; zi does not need a kernel ABI change if the 2-point sum is inlined in case 8. |
| **(c5) Hurdle (`hu`) in the same PR** | Extra-#962. `hu` is a different zero process (truncation, not mixture). Do not bundle. |

---

## 4. Recommendation and risks

**Live product:** (a) until G0 — keep the refuse. Rewrite the two
messages so they name the mixture leaf and stop conflating nbinom2
`zi` with RE.

**Locked path after G0 yes-to-implement:** (b), first cell
`mp-zi-poisson-bernoulli`, `zi ~ 1` (or observed-only `zi`),
inline mixture, Bernoulli predictor, no ABI change.

**Not forever-(a)** unless Shinichi explicitly decides the
identification / L-scope cost is not worth a count-SEM cell.

| Risk | Why it matters | Mitigation |
|---|---|---|
| **Identification of `π` vs `μ(x)`** | Zeros are shared. Missing `x` blurs the split. | First cell: `mi()` in `mu` only; `zi` intercept or observed covariates; MAR + null/swap tests. Fail loud if the swap test cannot tell them apart. |
| **Silent wrong density** | Shared leaf `default → 0.0`. | Never whitelist first. Inline ZIP in case 8. No case-6 call from a zi node. |
| **Kernel ABI creep** | Adding `eta_zi` touches every `has_mi` call site (student/`nu` already blocked on this). | Inline. Do not stuff `eta_zi` through unused slots. |
| **SEM emit / V-80** | Family name is `poisson`; `model_type` is `zi_poisson`. Emit-then-crash today; silent fold-in later. | Consumer leftover on `model_type` **now** is a separate small slice (other lease). After the engine cell: named admit, not a poisson alias. |
| **Testing cost** | L-scope recovery + identification controls, not a clone. | One family. Totoro smoke. No grid until Shinichi asks. |
| **Lane collision** | Student and family-gate trees are live. | This lane writes `LOOP/notes/` only. No `src/`. |
| **Overclaim** | “zi missing-data is covered”; FIML. | Cell name + leftovers + “not FIML”. S6 stays `partial`. |

---

## 5. G0 checklist (Shinichi)

**G0 APPROVED 2026-08-27 — all six CONFIRMED.** See the stamp at
the top of this note. Boxes below record the locked answers.

- [x] **G0-1. Path.** **(b)** locked. Not forever-(a).
- [x] **G0-2. Order vs student.** Isolated new worktree
      `cursor/lane-s6-zi-mi`. Do not touch student or
      nbinom2-gaussian trees.
- [x] **G0-3. First `zi` formula.** **`zi ~ 1`** for the recovery
      DGP; observed covariates allowed if complete.
- [x] **G0-4. Kernel.** **Inline** in `model_type == 8`.
- [x] **G0-5. Consumer refuse-now.** Yes if emit-then-crash is
      still live; then lift when this cell exists. Never alias
      `zi_*` as `poisson` for V-80.
- [x] **G0-6. Compute.** **Totoro**, n small, one seed.

If G0-1 is “forever (a)”: land the better messages only (engine
spec abort + nbinom2 wording). Still not a capability flip.

If G0-1 is “(b)” and G0-2 says go: new drmTMB worktree, not
family-gate, not student. Symbolic alignment page first. Then
C++. Allow-list last. drmSEM consumer repeats the A7c-2 pattern
for one named cell. capability-status stays `partial`.

---

## 6. What this note did not do

- No C++. No `drm_missing_predictor_families()` edit.
- No drmSEM `R/` (leased; would also be a G0-5 slice).
- No ledger row. No NEWS. No capability-status edit.
- No commit unless Shinichi asks. Never `git add -A`.
- Did not treat #962 comments as a zi unlock.
- Did not start nbinom2 × Gaussian (expand-gated; other trees).

---

## 7. Pointers

| Thing | Where |
|---|---|
| This decision | `LOOP/notes/A7-zi-mi-decision.md` (this file, this worktree) |
| L-scope queue | `~/local-scratch/lanes/drmTMB-s6-family-gate/LOOP/notes/A7-post-lognormal-queue.md` §2.3 |
| Consumer contract | `LOOP/notes/A7-consumer-contract.md` §4 (`mi()` on `zi` refuse) |
| Engine refuse | drmTMB `R/drmTMB.R` ~7127 (Poisson), ~7670 (nbinom2) |
| ZIP density | drmTMB `src/drmTMB.cpp` `model_type == 8` ~3877–3885 |
| Shared leaf | drmTMB `src/drm_response_kernels.h` (no 8/9) |
| #962 | https://github.com/itchyshin/drmTMB/issues/962 |

**STATE.** PLATFORM: cursor | ON BRANCH:
`cursor/lane-s6-a7-zi-mi` | LANE: s6-a7-zi-mi (decision docs).
OTHER LANES: `cursor/lane-s6-a7-consumer`,
`cursor/lane-s6-a7c2-gamma`, MAG/S3 Claude trees; drmTMB
family-gate / student-mi / multi-mi / #1033 Codex. Do not touch
them.
