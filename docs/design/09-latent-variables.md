# 09 — Latent variables (0.3): composite constructs

The 0.3 milestone lets a node load on a **latent construct** while staying inside
drmSEM's hard constraints: observed-variable, piecewise, DAG-only, each node one
drmTMB fit, no joint likelihood. The first increment ships **composite
(formative) constructs**; reflective measurement models are deferred. Code:
`R/composite.R`.

## Composite constructs (shipped)

A composite construct is a **deterministic function of observed indicators**,
computed *before* any fit:

- `method = "fixed"` — a weighted sum of the raw indicators (equal weights by
  default, or user-supplied `weights`).
- `method = "pca"` — the first principal-component score of the **scaled**
  indicators; the PC1 loadings are recorded (sign-fixed so the largest-magnitude
  loading is positive) along with the proportion of variance explained.

Because the construct is just a column once materialized, it slots into the
existing machinery with **no engine change**:

- `drm_composite(name, indicators, weights, method, data)` records the spec and
  its loadings (`R/composite.R`).
- `drm_sem(..., composites = )` materializes each construct column from the data
  *before* fitting (`drm_apply_composites()`), so any node formula can use the
  construct name as an ordinary predictor or response. `drm_psem(..., composites =)`
  records the declarations for reporting; the column must already be in the data
  the nodes were fitted on.
- `loadings(sem)` reports the indicator→construct loadings, kept **separate from
  `paths()`** exactly as `covariances()` is — a construct's measurement structure
  is not a causal path.

### Construct quality: reliability and standardization

`drm_composite()` records and reports two diagnostics so a user can judge the
construct rather than take it on faith:

- **Reliability** — Cronbach's alpha over the indicator set, an internal-
  consistency measure for a *reflective* reading of the indicators (the degree to
  which they move together as one scale). It is stored on the spec and shown by
  `print()` / `summary()`. It is **not clamped**: a low or negative alpha is an
  honest "these indicators do not form a coherent scale" signal, and `NA` for a
  single indicator. (`drm_cronbach_alpha()`.) For a *formative* construct, where
  indicators are causes rather than effects of the construct, alpha is not the
  right criterion and is reported for information only.
- **`standardize = TRUE`** rescales the materialized score to mean 0, sd 1 (after
  the weighted-sum / PC step), so a construct used as a predictor enters on a
  comparable scale to standardized continuous predictors.

`summary(composite)` prints the loadings table, the PC1 proportion of variance
(for `"pca"`), and the reliability; `print()` gives the one-line form.

### Formative vs reflective reading

`method = "fixed"` is the **formative** composite (the indicators *define* the
construct; weights are a design choice). `method = "pca"` is the closest
piecewise-feasible **reflective-flavoured** construct: the first principal
component approximates the common factor when the indicators are strongly,
positively correlated (high reliability), and its loadings/`prop_var` report how
well a single dimension summarizes them. Neither estimates a latent measurement
*model* — see below.

### Honest limitations (documented, tracked)

- **Indicators are leaves.** The construct is frozen in the data, so an
  intervention on an *indicator* does not propagate into the construct in the
  effect engine; intervene on the **construct** instead. (Propagating from
  indicators would require the engine to re-derive the column inside
  `drm_build_scenarios()`.)
- **Loadings are not drawn as measurement arcs** in `plot()` yet, and they do not
  enter the d-separation basis set (the construct is not a fitted node, so no
  `indicator _||_ construct` claim is ever generated — there is nothing to drop).

## Reflective constructs (out of scope for 0.3)

A reflective latent `eta` is the unobserved *common cause* of its indicators
(`indicator_k = lambda_k * eta + e_k`). Estimating the loadings and factor scores
requires integrating over `eta` in a **measurement likelihood that couples all
indicators simultaneously** — a single joint model. drmSEM is piecewise (one node
= one drmTMB fit over observed responses, no joint likelihood), and drmTMB does
not expose a multi-indicator latent-factor likelihood, so a true reflective
construct cannot be a drmSEM node. Reflective measurement belongs with the **0.4
joint multivariate** work or with lavaan interop. A pre-fit factor-score plug-in
(fit a 1-factor model externally, write predicted scores as a column) is possible
but is just a composite with externally-estimated weights that **ignores score
uncertainty**, and must be labelled as such rather than advertised as reflective
SEM.

## References

- Bollen KA, Bauldry S (2011). Three Cs in measurement models: causal indicators,
  composite indicators, and covariates. *Psychol. Methods* 16(3):265-284.
- Grace JB, Bollen KA (2008). Representing general theoretical concepts in
  structural equation models: the role of composite variables. *Environ. Ecol.
  Stat.* 15:191-213.
