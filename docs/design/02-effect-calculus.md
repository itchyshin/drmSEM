# 02 — Effect calculus: the simulation engine

This document defines how drmSEM computes direct, indirect, and total effects.
The rule is simple and non-negotiable: **effects are computed by Monte-Carlo
do()-style propagation over the fitted DAG, never by multiplying coefficients**
for non-Gaussian or cross-link paths. Code: `R/effects.R` (user-facing) and
`R/simulate_effects.R` (kernels). If effect semantics change, this file changes
(AGENTS.md rule 4).

## Why coefficient products are rejected

The classical mediation identity "indirect = product of path coefficients" is
exact only on a single linear (identity-link) scale. A drmSEM path may cross
links (e.g. a `log`-link `mu` feeding a `logit`-link mean downstream) and may
flow through non-mean components. On those paths the product of coefficients has
no defined response-scale meaning. We therefore *simulate* the intervention and
read off the response-scale change. This also makes the
distribution-mediated effect (below) expressible at all — it has no
coefficient-product analogue.

## Scenarios (the intervention contrast)

`drm_build_scenarios()` builds a paired low/high population from the fitted
data:

- **Numeric `from`**: a one-SD contrast centred on the mean,
  `at = c(mean - 0.5*sd, mean + 0.5*sd)`.
- **Factor `from`**: the first two levels (or first two sorted unique values).
- A user-supplied length-2 `at` overrides both.

The contrast is applied to the *whole data population* (every row gets the low
value, then every row gets the high value), so reported effects are
population-average changes, not effects at a single covariate point.

## Topological propagation and the RE=0 convention

`drm_propagate()` walks the engines in topological `$order`. Each node:

1. Builds its fixed-effect design matrix per component on the current working
   data (`drm_fixed_design()`), forms the linear predictor `eta = X %*% beta`,
   and applies the inverse link (`drm_inv_link()`) to get response-scale
   parameters (`mu`, and any of `sigma`, `zi`, `nu`, ...).
2. **Random effects are held at zero** — population-level / typical-group
   prediction. This is the **conditional (typical-group)** convention, NOT the marginal mean
   (see "Conditional vs marginal effects" below); it is stated
   in the adapter and is the same convention `predict_parameters()` is asked for.
3. If the node is an *active mediator*, it writes a value into the working data
   for downstream nodes to read; otherwise the scenario's own column value
   stands.

## Mean vs distribution mediation

What an active mediator passes downstream is the crux:

- **Mean-mediated** (`mediation = "mean"`): the mediator passes its expected
  `mu`. Only the mediator's mean carries the signal.
- **Distribution-mediated** (`mediation = "distribution"`): the mediator passes
  a **realized draw** from its family (`drm_sample_family()`), using all of its
  response-scale parameters — `sigma`, `zi`, `nu`, trials, etc. Inner draws are
  averaged over `n_sim` realizations.

## The effect taxonomy (key novelty)

- **Direct**: `X -> mu(Y)`. The controlled direct effect (`direct_effects()`)
  holds all mediators inactive and changes only `X`, so only the arrows from `X`
  directly into `Y` operate.
- **Mean-mediated**: `X -> mu(M) -> mu(Y)`. Appears under mean mediation when
  `M` is active.
- **Distribution-mediated**: `X -> sigma(M) -> distribution(M) -> mu(Y)`. An
  indirect effect flowing through a mediator's *scale / zero-inflation / shape*.
  It is **zero under mean mediation** and only appears when realized mediator
  draws propagate through a downstream nonlinearity. This is the effect type
  that motivates the whole simulation machinery.

`indirect_effects()` returns five rows in `quantity`:

| quantity | definition (contrast of population-average response means) |
| --- | --- |
| `total_path` | distribution-mediated total with mediators active |
| `direct` | controlled direct effect (mediators inactive) |
| `indirect` | `total_path − direct` |
| `mean_mediated` | (mean-mediated total) − direct |
| `distribution_mediated` | (distribution total) − (mean total) |

So `indirect ≈ mean_mediated + distribution_mediated`, and the
distribution-mediated row isolates exactly the contribution that no
coefficient-product method can express.

## Monte-Carlo coefficient uncertainty

`drm_draw_beta()` draws each node's coefficient vector from
`MVN(coef, vcov)` (per component, keyed by `dpar:term` names), using each node's
own `vcov` from the adapter. With `draw = TRUE` the whole propagation is
repeated `B` times to produce a sampling distribution of the contrast;
`drm_summ()` reports the mean and a percentile interval at `level`. With
`draw = FALSE` (or when `vcov` is unavailable) the MLE is used and only a point
estimate is returned.

## Knobs

- `B` — number of coefficient draws (outer Monte-Carlo, uncertainty).
- `n_sim` — inner realizations per draw under distribution mediation.
- `draw` — whether to propagate coefficient uncertainty (needs `vcov`).
- `at` — override the contrast values.
- `level`, `seed` — interval width and reproducibility.

All effects are reported on the **response scale** of `to`.

---

## Counterfactual foundation (why simulation, formally)

The product-of-coefficients identity is **not** the definition of an indirect
effect; it is an algebraic shortcut that holds only for linear-Gaussian,
identity-link, mean-only, additive, no-interaction SEMs. Modern causal mediation
defines direct/indirect/total effects as **counterfactual contrasts of predicted
response distributions** (Pearl 2001; Robins & Greenland 1992; Imai, Keele &
Yamamoto 2010). drmSEM adopts that definition and estimates the contrasts by
Monte-Carlo g-computation over the fitted DAG.

For a single mediated path `X -> M -> Y`, with `x0` (low) and `x1` (high):

```
total    = E[ Y(x1, M(x1)) ] - E[ Y(x0, M(x0)) ]
NDE      = E[ Y(x1, M(x0)) ] - E[ Y(x0, M(x0)) ]      # natural direct
NIE      = E[ Y(x0, M(x1)) ] - E[ Y(x0, M(x0)) ]      # natural indirect
CDE(m)   = E[ Y(x1, m)     ] - E[ Y(x0, m)     ]      # controlled direct at M=m
```

The mediator enters through its whole *distribution*, not a slope: e.g. for a
Poisson `M` (log link) and binomial `Y` (logit link),
`NIE = Σ_m [Pr(M=m|x1) - Pr(M=m|x0)] · logit⁻¹(β0 + b·m + c·x0)`, which is
emphatically **not** `a × b`. Because `E[f(M)] ≠ f(E[M])` for nonlinear `f`, a
path acting only on a mediator's `sigma`/`zi`/`nu` can carry a real indirect
effect even when its `mu` path is zero — this is the distribution-mediated
channel, and it is the reason simulation is mandatory.

## Estimand precision: what drmSEM computes today vs the refinement

- **`total_path`** already equals the correct counterfactual total
  `E[Y(x1,M(x1))] - E[Y(x0,M(x0))]` (both `X` and the mediators move to their
  predicted/realized values under the new `X`). This is exact g-computation.
- **`direct`** is currently the **controlled** direct effect with mediators held
  at their *observed* values (CDE averaged over the observed `M`), and
  **`indirect = total − direct`**. This decomposition sums to the total and is
  defensible, but it is **not** the cross-world natural NDE/NIE split (which holds
  `M` at the predicted `M(x0)` / `M(x1)` distributions). Aligning the split to
  natural effects — `NDE` with `M ~ M(x0)`, `NIE` varying `M(x0)→M(x1)` at
  `X=x0` — is a planned refinement (see OQ-8). Until then, read `direct` as a
  controlled direct effect, not a natural direct effect.

## Conditional vs marginal effects (random effects)

Holding random effects at zero gives the **conditional / typical-group**
response (`g⁻¹(η)`), not the **marginal** mean `E_b[g⁻¹(η + b)]`. For nonlinear
links these differ, and the gap grows with the random-effect SD — so a path into
`sd(group)` changes the marginal response even with the fixed-effect linear
predictor fixed. drmSEM 0.1 reports conditional (RE=0) effects. A `population =
c("conditional","marginal")` option that integrates over the fitted RE
distribution is planned (OQ-9); it is required before a path into `sd(group)`
can be given a response-scale marginal effect.

## Speed tiers (estimation cost)

| Tier | What | drmSEM knobs |
| --- | --- | --- |
| 1 | exact linear shortcut `a×b` (validation only) | n/a — used as the recovery check V-15 (sim ≈ product on a Gaussian identity-link chain) |
| 2 | deterministic g-computation on expectations | `draw = FALSE`, `mediation = "mean"` |
| 3 | + parameter uncertainty from `MVN(coef, vcov)` | `draw = TRUE`, `B` |
| 4 | + mediator-distribution simulation | `mediation = "distribution"`, `n_sim` |
| 5 | parametric/nonparametric **bootstrap** (refit) | planned (OQ-10) |

drmSEM already implements Tiers 1–4; only the refit-bootstrap (Tier 5) is
roadmap. Default workflow: fit once, draw from `vcov`, predict counterfactuals,
never refit unless a bootstrap is explicitly requested.

## Outcome functionals beyond the mean

Effects are currently reported on the response-scale **mean** of `to`. The same
g-computation propagation can read any functional of the predicted outcome
distribution — `Pr(Y > t)`, `Var(Y)`, `Pr(Y = 0)` — which is often the
scientifically relevant quantity. Exposing `target = c("mean","prob","var",...)`
is planned (OQ-11).

## API harmonization (planned)

The current knobs (`mediation`, `draw`, `B`, `n_sim`) map onto the tiers above; a
clearer surface `indirect_effects(..., method = c("gcomp","simulate"),
uncertainty = c("none","parametric","bootstrap"), nsim = , population = ,
target = )` is planned (OQ-12) without changing the underlying engine.

## References

- Pearl J (2001). *Direct and indirect effects.* UAI 2001.
- Robins JM, Greenland S (1992). *Identifiability and exchangeability for direct
  and indirect effects.* Epidemiology 3(2):143–155.
- Imai K, Keele L, Yamamoto T (2010). *Identification, inference and sensitivity
  analysis for causal mediation effects.* Statistical Science 25(1):51–71.
- Tingley D, Yamamoto T, Hirose K, Keele L, Imai K (2014). *mediation: R package
  for causal mediation analysis.* J. Stat. Soft. 59(5).
- Lefcheck JS (2016). *piecewiseSEM: Piecewise structural equation modelling in
  R.* Methods Ecol. Evol. 7(5):573–579.
