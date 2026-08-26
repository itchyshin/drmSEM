# Next arc — S6 generality: multi-`mi()` imputation

Status: **G0 approved 2026-08-26** (all 10 checklist items; standing
approval to push / PR / issue-comment / new engine lane). Planning docs
A1+A3 drafted. Nothing under `R/` has been touched; G1 still blocks
drmSEM `R/`.

This is a **two-repo programme**. drmSEM already ships a working
single-parent prototype (`drm_sem(impute = "auto")`, V-77–V-81). Generality
is blocked by the engine, not by missing SEM grammar. Do **not** start
drmSEM `R/` until the drmTMB contract exists (G1).

Template sibling: [`2026-08-15-next-arc-mag-completeness.md`](2026-08-15-next-arc-mag-completeness.md).
Authoritative order: handover §6 Step 3 · `DRMTMB_ISSUES.md` items **2 + 5,
then 1** · D-22.

---

## GOAL (would become `LOOP/GOAL.md`)

Read this first, every cycle. Auto-compact eats messages, not this file.

## Mission

Make graph-derived imputation **general enough for ordinary ecological
graphs**: a node with two (or more) incomplete **endogenous** parents can
emit `y ~ mi(m1) + mi(m2) + x` with each parent's own node formula and
family as its `impute_model()`, once drmTMB accepts k ≥ 2 **independent**
`mi()` terms.

The user still never writes an `impute_model()`. The DAG still specifies
the conditioning set. The honest limits below still ship in the docs.

## Headline

**Engine first, consumer second.** Item 2 (more than one `mi()` per fit) is
the binding constraint. Pair it with item 5 (a `missing_predictor` ledger
axis) so the extension is not a dark subsystem. Item 1 (per-family C++
marginalisation, not a whitelist edit) comes after. drmSEM then lifts the
one-parent abort.

## Why now

S5 (row alignment) and the S6 prototype shipped 2026-08-14. MAG-wire and
S3 grouping have landed on `main` (`04307ee`, `0852f9f`). Handover §6
Step 3 is the remaining unblocked engine-gated item. The prototype is the
evidence to attach to drmTMB #963 / #962 — more persuasive than an
abstract ask.

## Invariants (never violated, even after compaction)

1. **drmSEM never fits its own likelihoods.** Both S5 and S6 assemble
   arguments that drmTMB fits inside one node's likelihood
   (`00-charter.md`).
2. **Not FIML across the SEM.** Node `y` re-estimates each parent's model
   inside its own likelihood. Estimates are not shared. Uncertainty is
   **within-node only**.
3. **Independent predictor models (option b), not `impute_joint`.** drmSEM
   emits one `impute_model()` per incomplete endogenous parent. That is
   drmTMB #963's tractable branch. The stale `impute_joint(cbind(x1,x2)~z)`
   prototype (correlated continuous pair) is **sister prior art**, not the
   S6 consumer contract.
4. **Only endogenous parents.** Incomplete exogenous predictors have no
   node model → `na_action`. Do not invent an imputer for them.
5. **Opt-in MAR.** `impute = "none"` stays the default.
6. **Refuse rather than emit an illegal engine call.** Family gates, bare
   additive `mi()` syntax, and `uncertainty_status` (never
   `is.na(std_error)`) stay.
7. **No drmSEM `R/` until G1.** This lane writes docs, LOOP/, and the
   engine-contract draft only.
8. **One lane.** Do not touch MAG-completeness, MAG-wire, or S3-grouping
   worktrees. Do not touch the dirty drmTMB primary checkout.
9. **Never `git add -A`.** Explicit paths. No push/merge without a human
   gate.

## Authoritative WHAT

`LOOP/ultra-plan.md` holds the binding detail. This file wins on "what
must never be lost." D-22 locks the slice order.

## Definition of done

- drmTMB accepts k ≥ 2 independent `mi()` terms for at least a Gaussian
  response with independent predictor models, with MCAR and MAR recovery
  and sentinel-invariance (#963).
- A `missing_predictor` ledger axis exists with one honest-tier row per
  gated (response × predictor) cell that this programme actually ships
  (item 5).
- Item 1 is either shipped family-by-family with C++ + recovery + ledger
  row, or explicitly deferred per family with the reason (not a silent
  whitelist edit).
- drmSEM lifts the one-parent abort, derives multiple `mi()` terms from
  the DAG, keeps `imputation()` honest about tiers, and adds tests that
  recover a known two-incomplete-parent DGP (next V-numbers after V-81 /
  V-119).
- Docs (`13-missing-data.md`, `capability-status.md`, vignette pointer)
  still say: not FIML; within-node uncertainty; exogenous → `na_action`.

**Then STOP.** Correlated `impute_joint`, sharing parent estimates
(item 3 option a), exogenous imputation, and Bayesian FIML are not this
arc.

## Out of scope (the fence)

| Ruled out | Why |
|---|---|
| FIML / joint SEM likelihood | Charter. Piecewise. |
| Sharing parent-node estimates (item 3 option a) | Option (b) already works; (a) is a later engine discussion. |
| `impute_joint` as the drmSEM emit shape | Different estimand (correlated pair, one joint model). Audit it; do not silently adopt it. |
| Incomplete exogenous imputation | No node model in the graph. |
| MNAR, multiple imputation, Rubin's rules, MCMC | Engine and charter both refuse. |
| MAG-completeness / S3 grouping / `rho12` joint fit | Other lanes or other milestones. |
| drmSEM `R/` in Phase 0–1 | G1 gate. |
| Public "general missing-data SEM" claim | Rose. Capability stays `partial` until G2 evidence exists. |

## Two-repo contract

| Repo | Path | Owns | Does not own |
|---|---|---|---|
| **drmTMB** | `/Users/z3437171/Dropbox/Github Local/drmTMB` (local checkout exists; currently on a **foreign** ledger branch — start a **new** engine lane from `origin/main`) | Items 2 + 5, then 1. Parser + eight family marginalisers. Ledger axis. Recovery. Issues #963 / #962. | drmSEM graph derivation, `drm_sem(impute=)`, Fisher's C, effects. |
| **drmSEM** | this lane: `~/local-scratch/lanes/drmSEM-s6-imputation` on `cursor/lane-s6-imputation` | Contract draft, then (after G1) lift abort, multi-`mi()` from DAG, `imputed()` tiers, tests, docs. | Engine likelihoods, C++ `has_mi` wiring, ledger TSV. |

**Sister clone, do not treat as origin/main:**
`/Users/z3437171/Dropbox/Github Local/drmTMB-joint-mi` on
`codex/joint-mi-two-predictor` (3 ahead / **207 behind** `origin/main`).
It implements `impute_joint` for exactly two continuous predictors. Phase 0
recon must read it and say what to reuse vs leave.

**Coordination:** Shannon pre-flight both repos before any engine write.
drmSEM G1 is a **named human gate**: the engine contract file exists and
#963's acceptance is either met or explicitly scoped. No bleed-through
into MAG-completeness.

---

## ARCS (would become `LOOP/arcs.md`)

Status: `TODO` / `DOING` / `DONE (verified: <how>)` / `BLOCKED`.
Dependency-ordered. Re-read `GOAL.md` before each.

| ID | Slice | Repo | Reviewers | Dep |
|---|---|---|---|---|
| **A0** | Lane + charter + LOOP kit + D-22 (this kickoff) | drmSEM | Ada | — |
| **A1** | Engine contract draft (independence, emit shape, `imputed()` tiers, family cells) | drmSEM docs | Ada, Gauss | A0, **G0** |
| **A2** | Attach S6 prototype evidence to #963 / #962; note #964 already answered as (b) | drmTMB issues (comment) | Ada, Darwin | A1 |
| **A3** | Recon `drmTMB-joint-mi` vs #963 option (b); write reuse/leave verdict | drmTMB read-only | Gauss, Rose | A1 |
| **A4** | Item 2: k ≥ 2 independent `mi()` (parser + family marginalisers) | drmTMB | Gauss, Curie | A1, A3, **Phase 1 lane** |
| **A5** | Item 5: `missing_predictor` ledger axis for shipped cells | drmTMB | Fisher, Rose | A4 (pair) |
| **A6** | Two-predictor recovery (MCAR + MAR) + sentinel-invariance | drmTMB | Curie, Fisher | A4 |
| **A7** | Item 1: per-family C++ `has_mi` (not a whitelist edit), one family at a time | drmTMB | Gauss, Curie | A4–A6, **Phase 2** |
| **A8** | Lift one-parent abort; derive k `mi()` + `impute` list from DAG | drmSEM `R/` | Ada, Gauss | **G1**, A4 |
| **A9** | `imputation()` / `imputed()` branch on `uncertainty_status`; version note | drmSEM | Fisher | A8 |
| **A10** | Tests: V-77 still identical; new two-parent recovery; fail-loud; V-80 anti-drift | drmSEM | Curie | A8, A9 |
| **A11** | Docs: `13-missing-data.md`, capability-status, AGENT_LOG, VALIDATION_LEDGER | drmSEM | Darwin, Rose | A10 |
| **A12** | Review + reconcile; human G2 before merge | both | Ada, Rose, Fisher | A11 |

---

## GATES (loop STOPS here)

- **G0 — plan approval.** Shinichi confirms the checklist in
  `LOOP/ultra-plan.md`. No Phase 1 engine work, no drmSEM `R/`.
- **G1 — before drmSEM `R/`.** The engine contract is written and item 2
  is either merged to drmTMB `main` or explicitly available on an
  installed engine this suite can see. Without that, the abort is
  correct behaviour.
- **G2 — before merge / push / public claim.** Suite green; honest
  limits still in the docs; capability-status still does not say
  "covered" if only Gaussian × two independent parents shipped.
- **G3 — surprise that invalidates the plan** (e.g. independence is
  numerically unusable and only `impute_joint` works). Stop, back to G0.
  Do not silently switch estimands.
