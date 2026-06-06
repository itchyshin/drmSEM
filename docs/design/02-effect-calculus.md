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
   prediction. This is the **conditional (typical-group)** convention, NOT the
   marginal mean (see "Conditional vs marginal effects" below); it is stated
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

`indirect_effects()` returns five rows in `quantity` under the default
`effect = "controlled"`:

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

**Controlled vs natural effects (identification caveat).** The default `direct`
above is a *controlled* direct effect — mediators are held at their **observed**
values while `X` moves — and `indirect = total − direct`. This coincides with
the *natural* direct/indirect effect decomposition of mediation analysis
(Pearl; Imai, Keele & Yamamoto) **only under linearity with no
exposure–mediator interaction**. drmSEM paths routinely cross nonlinear links
and the engine permits `X × M` interaction terms — exactly the cases where the
controlled and natural effects differ. For those cases, opt in with
`indirect_effects(object, ..., effect = "natural")`, which holds the mediators
at their predicted `M(x0)` / `M(x1)` distributions and returns the cross-world
`natural_direct`, `natural_indirect`, and `mediated_interaction` rows alongside
`total_path` (see "Counterfactual foundation" and "Estimand precision" below).
The default `effect = "controlled"` keeps the controlled-direct / simulation
total–indirect split and does not assert a natural-effects identification. The
recovery tests that cross-check the natural decomposition use identity-link,
no-interaction Gaussian DAGs (the one regime where controlled and natural
coincide), so they validate the cross-world arithmetic on a case with a known
answer rather than the natural-effect identification in full generality. (See
inference-review B-2; the roxygen for `direct_effects()` states "controlled
direct effect", and `indirect_effects()` documents the `effect` argument.)

## Monte-Carlo coefficient uncertainty

`drm_draw_beta()` draws each node's coefficient vector from
`MVN(coef, vcov)` (per component, keyed by `dpar:term` names), using each node's
own `vcov` from the adapter. With `draw = TRUE` the whole propagation is
repeated `B` times to produce a sampling distribution of the contrast;
`drm_summ()` reports the mean and a percentile interval at `level`. With
`draw = FALSE` (or when `vcov` is unavailable) the MLE is used and only a point
estimate is returned.

## Knobs

- `uncertainty` — `"parametric"` (draw from `MVN(coef, vcov)`, default),
  `"none"` (MLE point), or `"bootstrap"` (OQ-10, not yet implemented).
- `B` — number of uncertainty replicates (outer Monte-Carlo draws).
- `nsim` — inner realizations per draw under distribution mediation.
- `method` — `"gcomp"` (mean) / `"simulate"` (distribution) for `total_effects()`.
- `population` — `"conditional"` (RE = 0, default) or `"marginal"` (OQ-9).
- `at` — override the contrast values.
- `effect` — `"controlled"` (default) or `"natural"` for `indirect_effects()`.
- `target`, `threshold` — outcome functional (on `total_effects()` and
  `direct_effects()`).
- `level`, `seed` — interval width and reproducibility.

(The pre-0.2 knobs `mediation`, `draw`, and `n_sim` are deprecated aliases for
`method`, `uncertainty`, and `nsim`; see "API harmonization" below.)

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

## Estimand precision: what drmSEM computes today

- **`total_path`** equals the correct counterfactual total
  `E[Y(x1,M(x1))] - E[Y(x0,M(x0))]` (both `X` and the mediators move to their
  predicted/realized values under the new `X`). This is exact g-computation.
- **`direct`** under the default `effect = "controlled"` is the **controlled**
  direct effect with mediators held at their *observed* values (CDE averaged over
  the observed `M`), and **`indirect = total − direct`**. This decomposition sums
  to the total and is defensible, but it is **not** the cross-world natural
  NDE/NIE split.
- **The cross-world natural split is implemented** via
  `indirect_effects(..., effect = "natural")`, which holds the mediators at their
  predicted `M(x0)` / `M(x1)` distributions and returns `natural_direct`,
  `natural_indirect`, `mediated_interaction`, and `total_path`. It is
  kernel-verified in `test-effect-kernels.R`: on an identity-link chain
  `x -> m -> y` with a direct `x -> y` edge, `NDE = c`, `NIE = a*b`,
  `total = c + a*b`, and `NIE = 0` when there is no `x -> m` path.

**Status (OQ-8 — PARTIAL).** Natural effects are *implemented and validated on
the linear-Gaussian, no-interaction recovery case*. What remains open is
cross-world generality beyond that regime — sensitivity to the
sequential-ignorability assumption, interaction-heavy and strongly nonlinear
mediators, and bootstrap intervals for the natural rows (OQ-10). The natural
rows already accept the unified `uncertainty` / `nsim` / `population` controls
(OQ-12).

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
| 2 | deterministic g-computation on expectations | `uncertainty = "none"`, `method = "gcomp"` |
| 3 | + parameter uncertainty from `MVN(coef, vcov)` | `uncertainty = "parametric"`, `B` |
| 4 | + mediator-distribution simulation | `method = "simulate"`, `nsim` |
| 5 | parametric/nonparametric **bootstrap** (refit) | `uncertainty = "bootstrap"` (planned, OQ-10) |

drmSEM already implements Tiers 1–4; only the refit-bootstrap (Tier 5) is
roadmap. Default workflow: fit once, draw from `vcov`, predict counterfactuals,
never refit unless a bootstrap is explicitly requested.

## Outcome functionals beyond the mean

Effects need not be reported on the response-scale **mean** of `to`. The same
g-computation propagation reads any functional of the predicted outcome
distribution, exposed through `total_effects(target = , threshold = )`:

| `target` | functional | definition |
| --- | --- | --- |
| `"mean"` (default) | `E[Y]` | the response-scale mean |
| `"p_gt"` | `Pr(Y > threshold)` | exceedance probability |
| `"p_zero"` | `Pr(Y = 0)` | (structural + sampling) zero probability |
| `"var"` | `Var(Y)` | response-scale variance |

These are the **headline estimands of distributional SEM**: a path into a
mediator's `zi` or `sigma` changes `Pr(Y = 0)` or `Var(Y)` downstream even when
it leaves `E[Y]` untouched. The functional effect is the same low/high
counterfactual contrast, read on the chosen functional of the simulated outcome
population.

**Status (OQ-11 — PARTIAL).** A first set of functionals (`p_gt`, `p_zero`,
`var`) is *implemented and recovery-tested* — the `p_zero` effect recovers the
Poisson zero-probability change `exp(-mu_hi) - exp(-mu_lo)` in
`test-effect-kernels.R`. `target` is now exposed on `direct_effects()` as well
as `total_effects()` (OQ-12); what remains open: surfacing it on
`indirect_effects()` (the decomposition-on-a-functional semantics are
unsettled), adding more functionals (quantiles) and analytic (non-simulated)
variants, bootstrap intervals for functional effects (OQ-10), and settling the
default reporting scale.

## API harmonization (OQ-12 — implemented)

The three effect functions share one vocabulary that maps onto the engine knobs
without touching any kernel (`R/effects_api.R`):

| unified argument | values | engine mapping |
| --- | --- | --- |
| `method` (`total_effects` only) | `"gcomp"` / `"simulate"` | `mediation = "mean"` / `"distribution"` |
| `uncertainty` | `"parametric"` / `"none"` / `"bootstrap"` | `draw = TRUE` / `FALSE` / (OQ-10, aborts) |
| `nsim` | integer | `n_sim` (inner realizations) |
| `population` | `"conditional"` / `"marginal"` | RE = 0 / (OQ-9, aborts) |
| `target`, `threshold` | functional | outcome functional (now on `direct_effects()` too) |
| `B` | integer | number of uncertainty replicates (unchanged) |

`indirect_effects()` deliberately has no `method`: the controlled decomposition
needs *both* the mean and distribution legs, and the natural split always uses
distribution mediation. The previous knobs `mediation`, `draw`, and `n_sim`
remain as **deprecated aliases** — they still work but emit a deprecation
warning, and the unified argument wins if both are supplied. Not-yet-implemented
choices (`uncertainty = "bootstrap"`, OQ-10; `population = "marginal"`, OQ-9)
abort early with a pointer to the open question rather than silently doing
something else. The normalization helpers (`drm_effect_controls()`,
`drm_resolve_mediation()`) are pure R and unit-tested in `test-effect-api.R`.

## Per-mediator path-specific attribution (OQ-5 — partial)

`path_effects()` splits the set-level indirect effect into a contribution per
mediator, by toggling which mediators are active in `drm_propagate` — no new
kernel. For exposure `X`, outcome `Y`, mediators `M`, and `T(S)` the response
contrast when the mediators in `S` respond:

| quantity | definition |
| --- | --- |
| `inclusion(Mj)` | `T({Mj}) - direct` — `Mj`'s path with all other mediators frozen |
| `exclusion(Mj)` | `T(all) - T(all \ Mj)` — `Mj`'s marginal given all others active |
| `total_indirect` | `T(all) - direct` |
| `interaction_remainder` | `total_indirect - sum_j inclusion(Mj)` |

**Additivity (stated honestly).** `inclusion` and `exclusion` coincide, and
`sum_j inclusion = total_indirect` (remainder `= 0`), **iff** the effects are
additive — parallel mediators, no downstream nonlinearity, no exposure-mediator
or mediator-mediator interaction (the identity-link Gaussian case, V-26c /
`test-path-effects.R` P-1). Otherwise the remainder is non-zero and is reported
as an explicit row — the per-mediator effects are **never** rescaled to force a
sum. Downstream nonlinearity (P-2) makes `inclusion != exclusion`; sequential
mediators `M1 -> M2` (P-3) make each `inclusion = 0` while each `exclusion =
total` (both are necessary), with the chain effect carried by the remainder.

`path_effects(by = "component")` adds a second granularity: each mediator's
indirect effect is split into a **mean channel** (`T_mean({Mj}) - direct`) and one
channel per non-mean component — `sigma_channel`, `zi_channel`, ... — computed by
**freezing** that component at its reference (`x0`) value and taking the drop in
the distribution-mediated effect (`PCE(c) = T_dist(full) - T_dist(c frozen)`). The
freeze wraps the mediator's prediction and splices the frozen component back in
(`drm_freeze_engine()`), so the core `drm_propagate` is unchanged. Under a
nonlinear outcome the channels do **not** partition exactly — the mean and a
constant variance-inflation interact through the nonlinearity (a flat `sigma` still
moves with the mean: the **Jensen-gap response**) — so a `component_remainder` is
reported rather than hidden. For the lognormal case the sigma channel is
`exp(ka + ½k²σ₁²) − exp(ka + ½k²σ₀²)` and the remainder is
`(e^{ka}−1)(e^{½k²σ₀²}−1)`, both kernel-verified in `test-path-effects.R`.

This is a **model-based decomposition**, not a claim of nonparametric
path-specific identification: the cross-world natural path-specific effects are
identified only under the recanting-witness criterion (Avin, Shpitser & Pearl
2005). **Status (OQ-5 — PARTIAL):** the controlled per-mediator split *and* the
per-component (`mean`/`sigma`/`zi`) split ship and are kernel-verified. Open: the
cross-world natural variant with a recanting-witness guard, `NA` handling for
unconfirmed-sampler families, and a live-fit integration test (the per-component
attribution is exact for hand-built engines; the real-family sampler accuracy
needs the engine) before any "validated" wording.

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
</content>
</invoke>
