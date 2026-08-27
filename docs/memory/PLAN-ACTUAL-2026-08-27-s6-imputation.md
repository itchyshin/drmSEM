# Plan vs actual — S6 generality multi-`mi()` (2026-08-27, A12)

Reconciler: Ada + Rose + Melissa (written closeout; no extra agent
launches). Plan: `LOOP/GOAL.md` / `LOOP/ultra-plan.md` / A1 contract
`LOOP/notes/A1-engine-contract.md`. Charter:
`docs/memory/2026-08-26-next-arc-s6-imputation.md`. D-22.

Counts as filed: **adaptive 4 · drift 0 · unclear 0**.

Filed here, not at `docs/dev-log/plan-actual/`: that path is
**gitignored** in this repo.

---

## Shipped claim (what the evidence supports)

A Gaussian response node with **two incomplete endogenous Gaussian
parents** emits two **independent** `mi()` terms from the DAG
(`y ~ mi(m1) + mi(m2) + x`), each with that parent's own
`impute_model()`. drmTMB 0.7.0 accepts that emit. drmSEM recovers a
known two-parent MAR DGP for that cell.

This is **not** FIML, **not** `impute_joint`, **not** a general
missing-data SEM, and **not** capability-status `"covered"`.

---

## G2 decision (public-claim review)

**Keep `partial`. Do not flip capability-status to `covered`.**
Shinichi authorised A12 closeout and did **not** ask for a covered
row. NEWS already names two Gaussian parents, within-node
uncertainty, and the fail-loud leftovers — no NEWS edit (an edit
that widened the sentence would be an overclaim).

| Gate | Outcome |
|---|---|
| **G0** | Approved 2026-08-26 (all 10 defaults). |
| **G1** | Discharged. Engine item 2 on drmTMB `main` @ `1cc1985cd` (#1086). Consumer `R/` shipped in #46. |
| **G2** | **Resolved 2026-08-27: retain `partial`.** Consumer merge already on main (#46). Public capability claim stays narrow. |
| **G3** | Never fired. Independence was usable; no silent switch to `impute_joint`. |

---

## Slice table (A0–A12)

| ID | planned | actual | tag | note |
|---|---|---|---|---|
| A0 | Lane + charter + LOOP kit + D-22 | Landed. D-22 in `DECISIONS.md`. LOOP kit committed via #45. | — | Worktree `~/local-scratch/lanes/drmSEM-s6-imputation` |
| A1 | Engine contract (docs only) | `LOOP/notes/A1-engine-contract.md`. Option (b) independence. | — | No drmSEM `R/` until G1 |
| A2 | Attach prototype to #963 / #962 | Comments `#issuecomment-5429119689` / `#5429120815` | — | Authorised after G0 |
| A3 | Recon `drmTMB-joint-mi` vs option (b) | Leave clone. `LOOP/notes/A3-joint-mi-verdict.md` | — | Different estimand (`impute_joint`) |
| A4 | drmTMB item 2: k ≥ 2 independent `mi()` | drmTMB **#1086 MERGED** `1cc1985cd` (0.7.0) | — | New engine lane from `origin/main` |
| A5 | Item 5: `missing_predictor` axis | One honest row `mp-gaussian-gaussian-k2-indep` on the **existing** axis | adaptive | Plan first skimmed “no axis”; live TSV already had one-parent rows |
| A6 | Two-predictor MCAR + MAR + sentinel | Engine recovery on #1086; drmSEM V-120 is MAR-to-truth for the same cell | — | Totoro smoke; no replicated grid |
| A7 | drmTMB item 1: per-family C++ `has_mi` | **Not started.** Explicitly deferred to Phase 2 | adaptive | Charter DoD allowed “shipped or deferred”. Do not start here |
| A8 | Lift one-parent abort; multi-`mi()` from DAG | `R/imputation.R` on #46. k = 2 Gaussian planned; k > 2 / non-Gaussian k = 2 fail loud | — | After G1 |
| A9 | `imputation()` / `imputed()` on `uncertainty_status` | Stacked parents; never first-`mi()` only. Extractor in `R/extractors.R` | — | Never `is.na(std_error)` |
| A10 | Keep V-77; two-parent DGP; fail-loud | V-77 kept. V-79/79b/79c, V-82 k=2 identity, V-120, V-121. `test-imputation.R` **61 / 0 / 0** | — | Against drmTMB `1cc1985cd` |
| A11 | Docs + ledgers + capability honesty | `13-missing-data.md` two-Gaussian wording; capability stays `partial`; ledger dated 2026-08-26 | — | No FIML sentence |
| A12 | Review + reconcile; human G2 | This file. G2 = keep `partial`; no NEWS overclaim | — | Shinichi: “A12 closeout” |

---

## PRs and merge shas

| PR | Repo | Merge sha | What |
|---|---|---|---|
| [#45](https://github.com/itchyshin/drmSEM/pull/45) | drmSEM | `ec5692aa302f201891ba1b8ce19299cff6953aa2` | Docs/LOOP/D-22/A0–A3 |
| [#1086](https://github.com/itchyshin/drmTMB/pull/1086) | drmTMB | `1cc1985cd87303d2300b0f311cb0ca91f4d06c34` | k ≥ 2 independent `mi()`; cell `mp-gaussian-gaussian-k2-indep`; 0.7.0 |
| [#46](https://github.com/itchyshin/drmSEM/pull/46) | drmSEM | `7280125d26dc99359aa63048d74d3df05bf18742` | A8–A11 consumer + tests + honest docs |
| stamp | drmSEM | `6c9d6ca4497967d7432fade1785f8c7f90c697f3` | #46 sha on LOOP; G2 still waiting |

Parent `main` at A12 start: `6c9d6ca`.

---

## Evidence vs claim (Ada)

| Claim in docs | Evidence | Match? |
|---|---|---|
| Auto ≡ hand-written one-parent emit | V-77 | yes |
| MAR bias reduction (one-parent Gaussian chain) | V-78 | yes, narrowly worded |
| Two Gaussian parents planned, not aborted | V-79 | yes (V-number reused from the old abort) |
| k > 2 still fails loud | V-79b | yes |
| Non-Gaussian k = 2 still fails loud | V-79c | yes |
| Two-parent auto ≡ hand-written emit | V-82 (k=2 identity) | yes; distinct from sampler V-82 tweedie |
| Two-parent MAR recovery-to-truth | V-120 (`m1`/`m2` 0.5/0.4 within 0.15, seeds 11/21/34, n = 400) | yes, **this cell only** |
| Branch on `uncertainty_status` | V-121 | yes |
| Engine accepts two independent Gaussian `mi()` | drmTMB #1086; cell `mp-gaussian-gaussian-k2-indep` | yes |
| capability-status `partial` | `docs/design/capability-status.md` S6 row | yes — **leave it** |

V-80 / V-81 (family anti-drift; `mi()` name resolution) remain from the
2026-08-14 prototype and were not reopened.

**Not in the evidence, therefore not in the claim:** FIML; cross-node
uncertainty; `impute_joint` / estimated \(\rho\); k > 2; non-Gaussian
response × two incomplete parents; incomplete exogenous imputation;
item 1 C++ `has_mi` (A7); capability `"covered"`.

---

## Ada + Rose + Melissa reconcile

### Ada (integrator)

Phase 1 engine + Phase 3 consumer are on `main`. The programme
definition of done in `LOOP/GOAL.md` is met for the locked first
cell: k ≥ 2 independent `mi()` on the engine with recovery + ledger;
drmSEM lifts the abort and recovers a known two-incomplete-parent
DGP; honest limits still in the docs. A7 is Phase 2 and was never
this closeout. MAG-completeness was not touched. Do not start A7
from this packet.

### Rose (claims / drift)

Public surfaces already match the cell:

- `capability-status.md` stays **`partial`**, and the “Does not cover”
  list names piecewise re-estimation, no FIML, k > 2, non-Gaussian
  k = 2, and the one-parent “not beats complete-case” wording.
- `NEWS.md` Missing-data bullet already says two Gaussian parents,
  drmTMB 0.7.0, fail-loud leftovers, `uncertainty_status`, never FIML.
  **No NEWS edit.**
- `13-missing-data.md`: “Two incomplete Gaussian parents, not a
  general graph” / “not a general missing-data SEM, and it is not
  FIML.”

A `"covered"` flip would erase those leftovers. A12 does not flip it.

### Melissa (plan vs actual)

**Adaptive 1 — A5 is a row, not a new axis.** The kickoff skim said
the live TSV had no `missing_predictor` axis. The engine already had
one-parent rows. A5 added `mp-gaussian-gaussian-k2-indep` on that
axis (`d327996`). Honest; not a second ledger.

**Adaptive 2 — G2 split.** The frozen plan stopped G2 before merge
*and* before a public claim. Standing overnight approval merged #45
and #46 when CI was green. The remaining G2 half was the public
capability sentence. A12 closes that half as **keep partial**.

**Adaptive 3 — A7 deferred.** Charter DoD allowed item 1 to be
shipped family-by-family *or* explicitly deferred. Deferred. Not
drift: G0 item 1 order is 2+5, then 1, and 1 was never the A12 job.

**Adaptive 4 — branch name.** Lane invariant named
`cursor/lane-s6-imputation`; consumer work shipped on
`cursor/lane-s6-a8`. Same worktree. Path collision with MAG LOOP
filenames was avoided by replacing the closed S3 kit, not by
inheriting it.

**Drift.** None. Independence held (no G3). `impute_joint` was not
emitted. `R/imputation.R` is not edited in A12.

---

## Honest limits (still true after closeout)

- Not FIML across the SEM. Within-node Hessian only.
- Independent `impute_model()` per parent (option b). Not
  `impute_joint`.
- Incomplete exogenous → `na_action`.
- `impute = "none"` remains the default.
- k > 2 and non-Gaussian k = 2 still abort.
- A7 / drmTMB item 1 (per-family C++ `has_mi`) is future work.
- capability-status **`partial`**.

---

## Worktree archive

`~/local-scratch/lanes/drmSEM-s6-imputation` on `cursor/lane-s6-a8`
@ `a873f46` is **stale** versus drmSEM `main` @ `6c9d6ca` (and versus
this A12 branch). After this closeout merges:

```bash
# only this worktree — never MAG-completeness / MAG-wire / S3-grouping
git -C "/Users/z3437171/Dropbox/Github Local/drmSEM" worktree remove \
  ~/local-scratch/lanes/drmSEM-s6-imputation
```

Optional: delete remote `cursor/lane-s6-a8` after #46 is long-merged.
Do **not** remove `~/local-scratch/lanes/drmSEM-mag-completeness`.

---

## The lesson worth keeping

A public capability row is a *sentence about leftovers*, not a
reward for shipping the first honest cell. Two-parent Gaussian
recovery (V-120) widens the prototype; it does not finish missing-
data SEM. G2 is the review that refuses that promotion.
