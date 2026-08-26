# A1 — Engine contract for S6 multi-`mi()` (docs only)

**Status.** Draft after G0 (2026-08-26). Binding for the drmTMB Phase 1
lane. Not an implementation. No drmSEM `R/` until **G1**.

**Audience.** The person who opens a new drmTMB worktree from
`origin/main` and implements items 2 + 5 (arcs A4–A6).

**Locks.** D-22; G0 checklist items 1–10 (all defaults). Charter:
`docs/memory/2026-08-26-next-arc-s6-imputation.md`.

---

## 1. Independence assumption

S6 asks the engine for **k ≥ 2 independent predictor models**, not a
joint residual correlation among the missing parents.

For a Gaussian response node \(y\) with two incomplete endogenous
parents \(m_1, m_2\) and a complete covariate \(x\),

\[
\begin{aligned}
y_i \mid m_{1i}, m_{2i}, x_i
  &\sim N(\beta_0 + \beta_1 m_{1i} + \beta_2 m_{2i} + \beta_x x_i,\;
          \sigma_y^2), \\
m_{1i} \mid \mathrm{pa}(m_1)
  &\sim N(\alpha_{10} + \mathrm{pa}(m_1)_i^\top\alpha_1,\;
          \sigma_{m1}^2), \\
m_{2i} \mid \mathrm{pa}(m_2)
  &\sim N(\alpha_{20} + \mathrm{pa}(m_2)_i^\top\alpha_2,\;
          \sigma_{m2}^2).
\end{aligned}
\]

There is **no** \(\rho(m_1,m_2 \mid \mathrm{parents})\) in this
estimand. The two predictor densities multiply. Missingness is
integrated **separately** for each parent, inside **one** node-\(y\)
likelihood.

That is #963 option **(b)**. It matches the piecewise SEM: each
endogenous parent already has its own node formula and family. drmSEM
will re-estimate those two models inside node \(y\); it will not share
node-\(m_1\) or node-\(m_2\) estimates. Uncertainty is **within-node
only**. This is not FIML across the SEM.

**If independence is numerically unusable and only a correlated pair
works, that is G3 — stop and return to G0.** Do not silently switch to
`impute_joint`.

---

## 2. Emit shape drmSEM will send (after G1)

Today the prototype emits one parent (`docs/design/13-missing-data.md`,
`R/imputation.R`). After G1 it must emit two (or more) **independent**
terms from the DAG. The engine must accept this call without aborting:

```r
drmTMB(
  bf(y ~ mi(m1) + mi(m2) + x),
  family = gaussian(),
  data = d,
  impute = list(
    m1 = impute_model(m1 ~ x, family = gaussian()),
    m2 = impute_model(m2 ~ x, family = gaussian())
  ),
  missing = miss_control(predictor = "model")
)
```

Invariants of that call:

- Each `mi()` is a **bare additive symbol in the `mu` formula**. No
  `mi(log(m))`, no interaction, no `sigma ~ mi(...)`.
- `impute` is a **named list**, one `impute_model()` per `mi()`
  variable, names matching the `mi()` symbols.
- Predictor-model formula and family come from that parent's **own
  node** (option b). The user never writes an `impute_model()`.
- `miss_control(predictor = "model")` is set only on nodes that have at
  least one incomplete endogenous parent. Zero `mi()` terms under
  `predictor = "model"` remains a hard abort — complete nodes stay
  untouched.
- Incomplete **exogenous** parents are not imputed. They stay on
  `na_action`.

Current engine aborts (read on drmTMB `origin/main` @ `fc8ee77a6`,
**do not edit that checkout**):

| Gate | File | What S6 needs |
|---|---|---|
| `length(mi_calls) != 1L` | `R/missing-data.R:628` | accept \(k \ge 2\) |
| `length(impute) != 1L` | `R/missing-data.R:697` | accept a named list of length \(k\) |
| `imputed(..., variable=)` default | `R/missing-data.R:4856` | default only when \(k = 1\); require `variable` when \(k \ge 2\) |

`drm_find_mi_calls()` already walks the `mu` RHS and can return more
than one call. The binding constraint is the length-1 gate, not the
walker.

---

## 3. `impute_model()` per parent — not `impute_joint`

| | S6 consumer (this contract) | Sister prior art (leave) |
|---|---|---|
| Public object | `impute_model(formula, family =)` | `impute_joint(cbind(x1, x2) ~ z)` |
| Count | \(k \ge 2\) list entries | exactly two, one object |
| Families | each parent keeps its node family | both continuous Gaussian |
| Residual dependence | none (product of margins) | estimated \(\rho_x\) |
| RHS | each parent's own parents | one shared RHS |

First engine cell (G0 item 3): **two independent Gaussian `mi()`
terms**, matching `y ~ mi(m1) + mi(m2) + x`. Do not start with
Gaussian + discrete. Do not start by merging `impute_joint`.

See `LOOP/notes/A3-joint-mi-verdict.md`.

---

## 4. `imputed()` tiers

`imputed()` already takes `variable` and already returns
`uncertainty_status`. Consumers **must** branch on
`uncertainty_status`, never on `is.na(std_error)` (0.6.0 vs 0.7.0
semantics). Levels on current `origin/main`:

| `uncertainty_status` | Meaning |
|---|---|
| `"ok"` | usable `std_error`, or an observed row |
| `"sdreport_skipped"` | `se = FALSE` |
| `"sdreport_failed"` / `"sdreport_non_pd_hessian"` | Hessian unusable |
| `"sdreport_unavailable"` | no `sdreport` object |
| `"route_conditional_se_unavailable"` | route has no well-defined SE (unordered categorical today) |

For \(k \ge 2\):

- `imputed(fit)` with no `variable` **aborts** (or returns a stacked
  frame with a `variable` column — pick one and document it). Silent
  “first `mi()` only” is forbidden.
- `imputed(fit, "m1")` and `imputed(fit, "m2")` each return that
  parent's rows.
- drmSEM `imputation()` (A9, after G1) reports one row per
  (node, parent) pair. `imputation()` today is one parent per node;
  that is a consumer change, not an engine change.

This is not multiple imputation, not Rubin's rules, not MCMC.

---

## 5. Family cells (honest gate, not a whitelist edit)

**Phase 1 (A4–A6) ships one cell:**

| Response | Predictor 1 | Predictor 2 | Estimand | Ledger |
|---|---|---|---|---|
| `gaussian()` | `gaussian()` `impute_model()` | `gaussian()` `impute_model()` | independent | new `missing_predictor` row, honest tier |

**Still refused after Phase 1** (fail loud with the engine reason):

| Cell | Why |
|---|---|
| \(k \ge 2\) when the response is not Gaussian | item 1 / #962 — C++ `has_mi`, not a gate flip |
| non-Gaussian response × non-binary predictor | already one-parent law; do not widen |
| mixed predictor families in one fit | later cell; not the first |
| `impute_joint` / estimated \(\rho\) | different estimand (A3) |
| incomplete exogenous | no node model |
| `mi()` on `sigma` / `zi` / other dpars | engine: `mu` only |
| transformed or interaction `mi()` | engine: bare additive only |

Item 1 (A7) is **per-family C++ observed-data likelihood**, not
editing `drm_missing_predictor_families()`. Promoting a family without
`has_mi` wiring is the #962 failure mode.

Item 5 (A5) pairs with A4: add a `missing_predictor` ledger axis and
one honest-tier row for the Gaussian × two-independent-Gaussian cell
that actually ships. Do not invent rows for cells that were not
recovered.

---

## 6. G1 acceptance criteria (opens drmSEM `R/`)

G1 is a named human gate. All of the following must be true:

1. **This contract still matches the shipped emit shape.** Independence
   (option b). No silent `impute_joint`.
2. **Item 2 available on an engine this suite can see** — merged to
   drmTMB `main`, or an installed branch/worktree the drmSEM tests can
   load. The abort `length(mi_calls) != 1L` is gone for the Phase 1
   cell.
3. **A6 recovery is real, not plumbing.**
   - MCAR **and** MAR (outcome-dependent missingness). MCAR-only does
     not open G1.
   - Sentinel-invariance still holds.
   - Compute: **Totoro** for the two-predictor smoke (G0 item 7). Ask
     again before a replicated grid. Not GitHub Actions.
4. **Item 5:** at least one `missing_predictor` ledger row for the
   shipped cell, at an honest tier.
5. **Honest limits still written** in `13-missing-data.md`: not FIML;
   within-node uncertainty; exogenous → `na_action`; `impute = "none"`
   default.
6. **`capability-status` stays `partial`** until two-parent evidence
   exists on the drmSEM side (G0 item 10). No “general missing-data
   SEM” sentence.

Until G1, the drmSEM one-parent abort in `R/imputation.R:74-81` is
**correct behaviour**.

---

## 7. What the Phase 1 drmTMB lane does (and does not)

**Does.** New worktree from drmTMB `origin/main` (currently
`fc8ee77a6`). Parser + setup accept \(k \ge 2\) independent
`impute_model()` entries. First cell = two Gaussian `mi()` terms.
Recovery + sentinel-invariance (A6). `missing_predictor` ledger axis
(A5).

**Does not.** Edit the dirty primary checkout
(`claude/ledger-biv-gaussian-residual-covered`). Rebase
`drmTMB-joint-mi` (`codex/joint-mi-two-predictor`, 3 ahead / **207
behind**). Implement item 1 C++ family wiring. Touch MAG-completeness.
Comment on GitHub #963/#962 until Shinichi allows a public write
(A2 paused).

---

## 8. Out of scope (G3 if someone “just adds” them)

- FIML / joint SEM likelihood / Bayesian imputation
- Item 3 option (a): accept a fitted `drmTMB` as the imputer
- Incomplete exogenous imputation
- MNAR, multiple imputation, Rubin's rules, MCMC
- MAG / S3 grouping / `rho12` joint fit
- drmSEM `R/` before G1
