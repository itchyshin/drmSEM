---
name: simulation-effects
description: The simulation-based effect engine — do()-style topological propagation, mean vs distribution mediation, direct/indirect/total decomposition, Monte-Carlo coefficient uncertainty. Use whenever computing or describing an effect estimand. Coefficient-product mediation is banned.
---

# drmSEM effects: simulation, never coefficient products

Effects in drmSEM are computed by Monte-Carlo do()-style propagation over the
fitted DAG, NOT by multiplying path coefficients. Kernels live in
`R/simulate_effects.R` (pure, drmTMB-free) and `R/effects.R` (public API).

## Why coefficient products are banned
A coefficient product `a*b` is the correct mediated effect only for fully linear,
identity-link, Gaussian paths. drmSEM paths can be non-Gaussian, cross-link
(e.g. log mu feeding a logit zi), or target `sigma`/`nu`/`zi`/`hu`/`sd`/`rho12`.
For those, `a*b` is simply wrong. Always propagate.

## How propagation works (`drm_propagate`)
1. Build a `scenario` data.frame; set the intervention variable (`do(from = x)`),
   contrasting `hi` vs `lo` (or `at`).
2. Visit nodes in TOPOLOGICAL order. Each node maps its predictors -> response-
   scale distributional parameters via its own linear predictor + inverse link.
3. RANDOM EFFECTS ARE SET TO ZERO (population-level / typical-group prediction).
   `sd(group)` paths change among-group heterogeneity, not this marginal mean.
4. The node hands its value downstream as either:
   - `mediation = "mean"`: the expected (mean) value propagates;
   - `mediation = "distribution"`: a realized draw from the node's family
     propagates, so effects flowing through a mediator's `sigma`/`zi`/`nu`/`hu`
     (distribution-mediated paths) are captured. Inner realizations averaged
     over `n_sim`.
5. Inactive nodes keep their scenario column values.

## Decomposition (the contract)
- `direct_effects()`: controlled direct effect — hold mediators at observed
  values, change only `from`; only direct arrows operate.
- `total_effects(mediation = c("mean","distribution"))`: do()-change `from`, all
  mediators respond.
- `indirect_effects(through=)`: total path effect minus controlled direct,
  decomposed into a MEAN-mediated part and a DISTRIBUTION-mediated part. The
  distribution-mediated part is the difference between `"distribution"` and
  `"mean"` propagation — it is the only honest way to report a `sigma`/`zi`/etc.
  mediated effect.
- All effects are reported as population-average changes in the RESPONSE-scale
  mean of `to` (also expose link scale where relevant).

## Monte-Carlo uncertainty (B / n_sim / draw)
- `B` = outer draws of the coefficient vector from MVN(coef, vcov) via
  `drm_draw_beta(engine, draw = TRUE)`; gives the effect's sampling distribution.
  Requires vcov (model fitted with `drm_control(se = TRUE)`); if vcov is NULL,
  report a point estimate and say SEs are unavailable.
- `n_sim` = inner realizations per draw, only meaningful for
  `mediation = "distribution"` (averages out the family draw).
- `draw = FALSE` uses the MLE (point estimate, for tests/debugging).
- Report estimate = mean over B, plus quantile interval over B.

## Checklist
- [ ] Used propagation, not a coefficient product, for any cross-component or
      non-Gaussian mediated effect.
- [ ] RE = 0 honored; `sd(group)` not conflated with a mean shift.
- [ ] Distribution-mediated contribution reported via the mean-vs-distribution
      difference, labelled by component.
- [ ] `set.seed()` before sampling; B and n_sim stated.
- [ ] New family sampler confirmed against a live fit (see `drmtmb-adapter`) and
      backed by a recovery test (see `validation-harness`).

## Unsupported families
If a node's family has no realized-value sampler, distribution-mediated
propagation falls back to mean propagation; `check_sem()` reports the `sampler`
flag. Say this to the user and suggest a supported family or mean-only mediation.
