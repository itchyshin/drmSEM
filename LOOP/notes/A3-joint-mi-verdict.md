# A3 — `drmTMB-joint-mi` vs #963 option (b)

**Verdict.** Leave the clone. Do **not** rebase
`codex/joint-mi-two-predictor` onto `origin/main` as the S6 engine
path. It implements a **different estimand** (`impute_joint`,
correlated pair) from the G0 consumer contract (independent
`impute_model()` per parent).

**Read-only.** Clone
`/Users/z3437171/Dropbox/Github Local/drmTMB-joint-mi`. No writes.
Primary drmTMB checkout was not edited.

---

## What was read

| Surface | Evidence |
|---|---|
| Clone HEAD | `cbbf380bd` `test(missing): accept family-specific predictor rejection` |
| Branch | `codex/joint-mi-two-predictor` |
| vs drmTMB `origin/main` | **3 ahead / 207 behind** `fc8ee77a6` |
| `impute_joint` on `origin/main` | **absent** (`git grep` empty) |
| After-task | `docs/dev-log/after-task/2026-08-13-joint-mi-two-predictor.md` |
| Alignment | `docs/dev-log/2026-08-13-joint-mi-two-predictor-alignment.md` |
| Public API | `R/missing-data.R` `impute_joint()`; `man/impute_joint.Rd` |
| Grammar | `docs/design/01-formula-grammar.md` joint-route row |
| Engine on `origin/main` | `R/missing-data.R:628` still `length(mi_calls) != 1L` |

#963 was not fetched this pass (G0 item 8: no public GitHub write;
GitHub MCP unavailable). Option (b) is taken from
`docs/memory/DRMTMB_ISSUES.md` item 2 and the 2026-08-14 evidence
update: \(k \ge 2\) simultaneous `mi()` terms with **independent
predictor models**. The joint-mi after-task itself names #963 as the
matching tracker and says the wider \(k \ge 2\) / mixed-family request
**remains open**.

---

## Two estimands

### Option (b) — S6 contract (A1)

```r
bf(y ~ mi(m1) + mi(m2) + x)
impute = list(
  m1 = impute_model(m1 ~ pa(m1), family = <node m1 family>),
  m2 = impute_model(m2 ~ pa(m2), family = <node m2 family>)
)
```

Product of two (or \(k\)) predictor densities. No \(\rho(m_1,m_2)\).
Each RHS is that parent's own node formula. This is what a piecewise
SEM can emit from the DAG.

### `impute_joint` — sister prior art

```r
bf(y ~ z + mi(x1) + mi(x2), sigma ~ 1)
impute = impute_joint(cbind(x1, x2) ~ z)
```

One bivariate Gaussian predictor model, **shared** RHS \(z\), two
residual SDs, estimated residual correlation \(\rho_x\). After-task
§3a: *“`impute_joint()` was chosen rather than two independent
`impute` list entries because the residual correlation is part of the
fitted model.”*

Alignment (clone):

\[
\begin{pmatrix}x_{1i}\\x_{2i}\end{pmatrix} \mid w_i
\sim N\!\left(
  \begin{pmatrix}w_i^\top\alpha_1\\w_i^\top\alpha_2\end{pmatrix},
  \begin{pmatrix}
    \sigma_{x1}^2 & \rho_x\sigma_{x1}\sigma_{x2}\\
    \rho_x\sigma_{x1}\sigma_{x2} & \sigma_{x2}^2
  \end{pmatrix}
\right).
\]

That \(\rho_x\) is the load-bearing difference. Shipping it as S6
would claim a joint residual structure the DAG did not specify, and
would force drmSEM to emit `impute_joint` instead of per-parent
`impute_model()` — the opposite of D-22 / G0 item 2.

---

## Reuse vs leave

**Reuse as ideas (copy by hand into a new `origin/main` lane if
useful; do not fast-forward the branch):**

- Proof that **two `mi()` tokens in the `mu` formula can parse**.
  `drm_find_mi_calls()` on `origin/main` already walks the tree; the
  clone shows the downstream payload cannot stay scalar.
- **Pattern-wise observed-data likelihood** thinking: integrate each
  missingness pattern rather than pretending both parents are always
  latent.
- Test *shape*: sentinel-invariance, fixed-seed recovery smoke,
  independent R oracle for a Gaussian latent block, malformed-grammar
  rejects.
- Extractor plurality: `imputed(fit, "x1")` and `imputed(fit, "x2")`
  as separate calls (clone already does this for the joint route).
- Team lesson (after-task §11): a second `mi()` is not a parser flip —
  TMB data contract, latent-vector ordering, extractors, and the
  capability inventory must change together.

**Leave (do not merge, do not rebase, do not adopt as emit shape):**

- Public `impute_joint()` / class `drm_joint_impute_model`.
- Shared `cbind(x1, x2) ~ z` RHS.
- Estimated \(\rho_x\) and the bivariate residual block.
- C++ joint-latent wiring on a branch **207 commits behind**
  `origin/main`.
- Exactly-two, continuous-only, fixed-effect-only, no-REML, no
  response-mask fence (correct for *that* route; wrong as S6's first
  cell).
- Poisson proof route that reuses the **same joint continuous latent
  block** — not an independent `impute_model()` pair, and not item 1.

**Do not treat the clone's recovery campaign as A6 evidence.** It
recovers the joint-\(\rho\) route (Totoro MCAR `point_fit_recovery`
for MD9b). A6 must recover the **independent** two-`impute_model()`
cell under MCAR **and** MAR.

---

## Why a rebase is the wrong engine path

1. **Wrong estimand.** Option (b) is the tractable SEM branch. The
   clone rejected that branch on purpose.
2. **Stale base.** 207 commits behind `origin/main` (`fc8ee77a6`).
   Rebasing C++ latent-vector changes across that gap is a merge
   project, not a shortcut.
3. **`impute_joint` is not on `origin/main`.** Starting from main
   keeps the public surface clean. Phase 1 adds independent
   multi-`mi()`; joint remains a later, separately gated estimand.
4. **G3 exists** if independence later fails numerically. That is a
   new G0, not a silent import of this clone.

---

## Implication for Phase 1

Open a **new** drmTMB worktree from `origin/main`. Implement A4 as
“accept \(k \ge 2\) independent `impute_model()` entries” against
`R/missing-data.R:628` and `:697`. Use A1 as the emit-shape contract.
Use this note only as a “what not to become” check.

A2 (comments on #963 / #962) stays **paused** per G0 item 8.
