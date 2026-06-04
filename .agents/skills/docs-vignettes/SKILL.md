---
name: docs-vignettes
description: Reader-facing docs for drmSEM — README, the vignette, and pkgdown reference sync. Pair equations + R syntax + interpretation, show component-labelled output and the distribution-mediated decomposition, and tell users what to try when a path/family is unsupported. Use when writing user-facing prose.
---

# drmSEM docs & vignettes

Audience: applied ecology/evolution/environmental-science users, plus method
developers and R contributors. Name the PURPOSE before the mechanics.

## The three-part rule (every model explanation)
Pair, in this order:
1. The symbolic equation (which distributional component, on which link).
2. The R syntax (`drm_node()` / `drm_sem()` / `drm_psem()`).
3. The interpretation in plain language, naming the component.

Example:
```
# sigma of growth depends on temperature (log link):
#   log sigma(growth) = a0 + a1 * temp
drm_node(growth ~ light, sigma ~ temp, family = gaussian())
# Reading: warmer sites have MORE VARIABLE growth, not higher mean growth.
```

## Always show component-labelled output
- Print `paths(object)` output with its `component` column visible; never show a
  path table that hides whether an edge is on `mu`, `sigma`, `nu`, `zi`, `hu`,
  `sd(group)`, or `rho12`.
- In the effects section, SHOW the distribution-mediated decomposition: a worked
  `total_effects(mediation = "distribution")` vs `"mean"`, and
  `indirect_effects(through=)` split into mean-mediated and distribution-mediated
  parts. This is the feature that distinguishes drmSEM — demonstrate it.
- DAG/path figures (`plot.drm_sem()`) colour edges by component; captions and
  surrounding prose must keep that label too. Be honest about uncertainty.

## README
- One-paragraph purpose: distributional piecewise SEM on top of `drmTMB`.
- Minimal worked example a reader can copy. If it fits a node it needs `drmTMB`;
  wrap such code so the README still renders without the engine, or mark it
  clearly as requiring `drmTMB`.
- State the scope ceiling: observed-variable, DAG-only, piecewise, no latents.

## Vignette
- Answer a real biological question end to end (Darwin/Pat test): build nodes,
  assemble the SEM, test d-separation with `dsep()` + `fisher_c()`, decompose
  effects, interpret with component labels.
- Use stable terms verbatim: `mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`,
  `rho12`, "component-labelled path", "distribution-mediated effect".

## When something is unsupported — tell the reader what to try
Never dead-end. If a family lacks a sampler or a component is unsupported, say
so and offer: a supported family, mean-only mediation, or what `check_sem()`
reports (the `sampler` flag). Do the same in error messages.

## pkgdown sync (first-class artifact)
- Every export (`drm_node`, `drm_sem`, `drm_psem`, `paths`, `basis_set`, `dsep`,
  `fisher_c`, `direct_effects`, `total_effects`, `indirect_effects`,
  `standardize`, `check_sem`, plus `plot`) appears in `_pkgdown.yml` reference.
- Substantial features get an article. Run `pkgdown::check_pkgdown()` after
  reference/vignette edits. Reader-facing names in nav, not internal helper names.

## Checklist
- [ ] Equation + R syntax + interpretation paired.
- [ ] Component label shown in every path table, figure, and effect statement.
- [ ] Distribution-mediated decomposition demonstrated.
- [ ] Unsupported cases tell the user what to try next.
- [ ] `_pkgdown.yml` lists all current exports; `check_pkgdown()` clean.
