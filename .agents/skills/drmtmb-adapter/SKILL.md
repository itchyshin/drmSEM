---
name: drmtmb-adapter
description: How drmSEM talks to drmTMB — ONLY through R/extractors.R. The drmTMB return-shape facts, the dpar:term coefficient convention, and the rule to confirm parameterizations against a live fit before trusting samplers.
---

# drmTMB adapter (R/extractors.R only)

EVERY assumption about a fitted `drmTMB` object's internal shape lives in
`R/extractors.R`. No other file may reach into a `drmTMB` object directly. If
drmTMB's internals shift, only this file changes.

## Rule
- New code that needs something from a fit calls an `extractors.R` helper. If
  the helper doesn't exist, ADD it there — do not poke `fit$...` from
  `effects.R`, `dsep.R`, `paths.R`, etc.
- Guard every drmTMB call with `drm_require_drmTMB()` (aborts with an install
  hint when `drmTMB` is absent).

## Verified drmTMB facts (against 0.1.3.9000, github itchyshin/drmTMB)
- `bf()` / `drmTMB::drm_formula()` → object with `$calls`, `$names`, `$entries`.
  Each entry has `$dpar`, `$response`, `$lhs`, `$rhs`.
- A fitted object carries `$formula` (the bf object), `$family`, `$data`,
  `$coefficients` (named list keyed by dpar → named numeric vector).
- `coef(obj, dpar)`, `fixef(obj, dpar)`, `vcov(obj)` with dimnames `"dpar:term"`
  — `vcov` needs the model fitted with `control = drm_control(se = TRUE)`.
- `logLik(obj)` (with `df` attr), `is_converged(obj)`,
  `predict_parameters(obj, newdata, dpar, type = c("response","link"))`.

## The dpar:term coefficient convention (load-bearing)
- `$coefficients[[dpar]]` is a named numeric vector; names are bare terms
  (`"(Intercept)"`, `"temp"`, `"habitatB"`).
- `vcov` rows/cols are `paste0(dpar, ":", term)`. To look up an SE for a path,
  build the key `"dpar:term"` and index `V[key, key]` (see `paths.drm_sem`).
- `drm_fit_coef_vector()` flattens to `"dpar:term"` names; `drm_draw_beta()`
  rebuilds per-dpar keys to slice the MVN covariance block.

## Helper map (don't duplicate these)
- Identity/metadata: `is_drmTMB_fit`, `drm_fit_formula`, `drm_fit_entries`,
  `drm_fit_family`/`drm_family_name`, `drm_fit_data`, `drm_fit_response`,
  `drm_fit_components`, `drm_fit_component_predictors`.
- Estimates: `drm_fit_coef`, `drm_fit_coef_vector`, `drm_fit_vcov`
  (NULL when SEs unavailable / Hessian not PD), `drm_fit_logLik`,
  `drm_fit_converged`.
- Prediction & refit: `drm_predict_parameters` (wraps `predict_parameters`),
  `drm_refit_augmented` (d-sep: appends `+ X` to every targeted component RHS,
  refits with `se = TRUE`), `drm_fixed_design`.

## model.matrix coding assumption
`drm_fixed_design()` rebuilds the fixed-effect formula per component (bars and
structured markers dropped via `drm_drop_bars`/`drm_strip_markers`), runs
`stats::model.matrix()`, and aligns/zero-fills columns to the fitted coefficient
names. This ASSUMES drmTMB codes fixed effects with standard `model.matrix()`
contrasts. That assumption is isolated here — keep it here.

## Before trusting a sampler or propagation parameterization
The realized-value samplers in `simulate_effects.R` assume specific
response-scale parameterizations (e.g. `nbinom2` size = `1/sigma`,
beta shapes from `mu*phi`). CONFIRM these against a live `drmTMB` fit
(`predict_parameters` + a known DGP recovery test) before trusting any new
sampler or family. Add a recovery test; do not infer the parameterization from
memory.
