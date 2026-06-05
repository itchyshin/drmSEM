# 01 — Semantics: the graph grammar

This document defines what a drmSEM graph *is*: nodes, typed edges, how edges
are extracted from drmTMB formulae, identifiers, and the DAG rule. If the
grammar changes, this file changes (AGENTS.md rule 3). The relevant code lives
in `R/edges.R`, `R/extractors.R`, `R/utils.R`, and `R/drm_sem.R`.

## Nodes

An **endogenous node** is one fitted drmTMB model. Its name (the argument name
in `drm_sem(...)` / `drm_psem(...)`) is the canonical node identifier. Each node
carries a record (`drm_build_node_records()`) with: `name`, `fit`, `family`,
`response_label`, `response_vars`, `components`, and `identifiers`.

An **exogenous variable** is any predictor that is not itself a node — it has no
fitted model, so it is a source only. Exogenous variables are computed in
`new_drm_sem()` as predictors that appear as `from` but are not node names.

## Component-labelled typed edges

The fundamental object is the typed edge:

```
(from, to, component, link, term, endogenous)
```

- `to` is always an endogenous node.
- `from` is another node (a node-to-node path) or an exogenous variable.
- `component` is the distributional parameter of `to` that `from` targets:
  `mu`, `sigma`, `nu`, `zi`, `hu`, `rho12`, or a random-effect scale `sd_*`.
  This is the **component label**, and it is load-bearing: an edge into `sigma`
  is a claim about residual scale, not the mean.
- `link` is a *nominal* link for that `(family, component)` (`drm_nominal_link`),
  used for display and standardization only — it never alters a drmTMB
  computation. Defaults: `sigma`/`nu`/`sd*` → `log`; `zi`/`hu` → `logit`;
  `rho12` → `tanh`; `mu` → the family's link (e.g. `log` for `nbinom2`,
  `logit` for `beta_binomial`, `identity` for `gaussian`).
- `term` is the predictor token as it appears in the sub-formula.
- `endogenous` flags whether `from` resolved to another node.

The typed edge table is produced by `drm_build_edges()`. A variable-level
collapse (`drm_collapse_edges()`, stored as `var_edges`) drops the component
column and is what the DAG / topological-sort / path machinery operates on.

## How edges are extracted from `bf()` entries

Each node's formula is a `drmTMB::bf()` / `drm_formula` object whose `$entries`
list contains one entry per distributional-parameter sub-formula, with
`$dpar` (the component), `$response`, `$lhs`, and `$rhs`. For every entry:

1. `drm_fit_component_predictors()` reads the sub-formula `rhs` and calls
   `drm_fixed_predictors()`.
2. `drm_fixed_predictors()` (pure base R, `R/utils.R`) drops random-effect bar
   groups `(g | h)` / `(g || h)` via `drm_drop_bars()`, strips structured-effect
   and smooth markers via `drm_strip_markers()` (`phylo`, `spatial`, `animal`,
   `gr`, `s`, `te`, `poly`, `I`, ...), special-cases `mi(x)` to keep `x`, and
   removes intercept tokens. The remaining `all.vars()` are the predictors.
3. Each predictor becomes one typed edge, with `component = entry$dpar`.

So `bf(size ~ temp + habitat, sigma ~ temp)` yields three edges:
`temp -> size (mu)`, `habitat -> size (mu)`, `temp -> size (sigma)`. The
`temp -> size` arrow exists on *two* components and is two distinct typed edges.

## Node identifiers: node name vs response variable

A predictor token is matched to a node by `drm_match_node()`, which checks the
node's `identifiers`: the union of its **node name**, its **response label**
(the deparsed `mu` LHS), and its **response variables** (`all.vars(lhs)`). This
is why a downstream formula may refer to an upstream node either by its name or
by its response variable name.

For a multivariate / binomial LHS such as `cbind(alive, dead)`, the response
*label* is the deparsed `cbind(alive, dead)` and the response *vars* are
`alive` and `dead`. The node is referenced downstream by its **node name** (e.g.
`survival`), because that is the stable identifier; matching on the bare
`alive`/`dead` columns also works but the node name is preferred. Open question
OQ-3 tracks edge cases here.

Self-reference (a node's response appearing in its own formula) never creates a
self-loop: `drm_build_edges()` skips `from == nm`, and `drm_match_node()`
excludes `self`.

## DAG / cycle rule

`new_drm_sem()` runs Kahn's topological sort (`drm_toposort()`) on the
variable-level edges. If the graph is not acyclic, drmSEM **aborts** with the
nodes involved in or downstream of the cycle. Cycles / feedback are out of scope
for 0.x; this is an error, not a warning. The resulting `$order` is the
topological order used by the effect engine and by d-separation's causal
ordering.

## Exogenous vs endogenous, summarized

- **Endogenous**: has a fitted node; appears as `to`; has modelled components.
- **Exogenous**: predictor with no node; appears only as `from`; sorts before
  all nodes (order index 0 in `drm_order_index()`).
