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
