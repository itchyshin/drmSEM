---
name: drmsem-semantics
description: THE core skill. Enforces component-labelled paths — never describe or compute a non-mu path as a mean effect. Use for ANY prose, docs, message, or code that states what a drmSEM path MEANS.
---

# drmSEM semantics: component-labelled paths

A drmSEM edge is `(from, to, component, link, term)`. `component` is the
distributional parameter of the endogenous node `to` that `from` targets. The
recurring fatal mistake this skill prevents: treating EVERY path as a mean
effect. A path to `sigma` is not a path to the mean; a path to `zi` is not a
path to the conditional mean.

## The seven components — say exactly what each means
| component | targets | link (typical) | correct reading of an X→Y path |
| --- | --- | --- | --- |
| `mu` | conditional mean/location | family link (identity/log/logit/...) | X shifts the expected value of Y |
| `sigma` | residual scale / dispersion | log | X changes spread/dispersion of Y, not its mean |
| `nu` | shape (e.g. Student df) | log | X changes tail/shape of Y's distribution |
| `zi` | zero-inflation probability | logit | X changes the chance of a structural (extra) zero |
| `hu` | hurdle probability | logit | X changes the probability of crossing the hurdle |
| `sd(group)` (`sd_*`) | random-effect scale | log | X changes among-group heterogeneity, not the mean |
| `rho12` | bivariate residual correlation | tanh | X changes the residual correlation between two responses |

(Links match `drm_nominal_link()` in `R/edges.R`. mu's link follows the family.)

## Checklist before stating what a path MEANS
1. Identify the `component` from `paths(object)` / the edge table — never assume `mu`.
2. State the component explicitly: "effect on `sigma` of Y", not "effect on Y".
3. Name the link scale of the coefficient (sigma/nu/sd on log; zi/hu on logit;
   rho12 on tanh; mu on the family link).
4. For interpretation of magnitude, do not report a coefficient product or a raw
   link-scale slope as a response-mean change. Use the simulation effect engine.
5. Use stable terms verbatim: `mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`,
   `rho12`, "component-labelled path", "distribution-mediated effect".

## Do / Don't
- DO: "temp → `sigma`(abundance): a log-scale increase in residual dispersion."
- DON'T: "temp → abundance: increases abundance" when the edge is on `sigma`.
- DO: route a sigma/zi/nu mediator's contribution through
  `total_effects(mediation = "distribution")` / `indirect_effects()`; this is the
  distribution-mediated effect.
- DON'T: multiply a `mu`-path coefficient by a `sigma`-path coefficient — there
  is no coefficient-product mediation across components or for non-Gaussian /
  cross-link paths. It is banned (see AGENTS.md, `simulation-effects`).
- DON'T: collapse all arrows into "the DAG" without their component label in
  plots, tables, or prose. `plot.drm_sem()` colours edges by component for this
  reason; keep that distinction in text too.

## When a component or family is unsupported
Say so and say what to try: a different family, mean-only mediation, or noting
that distribution-mediated effects fall back to mean propagation when no
realized-value sampler exists (`check_sem()` reports the `sampler` flag).
