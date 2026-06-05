---
name: dsep-basis
description: Build basis sets and run any-component d-separation / Fisher's C correctly — adjacency = direct parent on ANY component, causal ordering, conditioning on parents, LRT df bookkeeping, honest framing as drmSEM's definition.
---

# d-separation & basis sets (any-component)

drmSEM's d-separation is the ANY-COMPONENT definition (DECISIONS.md #2,
`docs/design/03-dsep.md`): a missing arrow X → Y asserts X has NO effect on ANY
modelled distributional component of Y. This is drmSEM's *definition* of a
missing arrow — frame it that way, not as a generic graphical-SEM claim.

## Adjacency = direct parent on ANY component
- X is adjacent to Y if X is a direct parent of Y on `mu`, `sigma`, `nu`, `zi`,
  `hu`, `sd(group)`, or `rho12` — any one suffices (`drm_is_parent`, scanning the
  full typed edge table from `drm_build_edges`).
- A predictor that appears only in Y's `sigma` formula still makes X adjacent to
  Y. Do not restrict adjacency to `mu`.

## Basis set construction (`basis_set.drm_sem`)
For each endogenous Y and each variable X (endogenous or exogenous):
1. Skip X == Y.
2. Skip if X is causally LATER than Y (`drm_order_index`: topological position;
   exogenous variables sort at index 0, before all nodes).
3. Skip if X is already a parent of Y (adjacent → not a missing arrow).
4. Skip if Y is a parent of X (orientation guard).
5. Otherwise emit claim `X _||_ Y | {parents(Y)}`. The conditioning set is Y's
   existing parents (`drm_parents`), so the LRT controls for them.

## Testing a claim (`dsep.drm_sem`)
- Refit Y's node adding X to EVERY modelled component sub-formula
  (`drm_refit_augmented`, with `se = TRUE`). This realizes the any-component
  alternative hypothesis.
- LRT: `LR = 2*(logLik_aug - logLik_base)`, `df = df_aug - df_base`.
- df bookkeeping: df is the number of extra coefficients across ALL augmented
  components (one per component sub-formula in the simplest case, more with
  factors/interactions). Read both df values from `drm_fit_logLik` — never
  hard-code df = 1.
- Guard degenerate cases: status `no_data_column`, `refit_failed`, `degenerate`
  (df <= 0 or NA LR) are recorded and EXCLUDED from Fisher's C.

## Fisher's C (`fisher_c`, `drm_fisher_c_from_p`)
- `C = -2 * sum(log p)` over the `ok` claims with `p > 0`; `df = 2k` where k is
  the number of contributing claims; `p = pchisq(C, df, lower.tail = FALSE)`.
- A SMALL Fisher p-value means the DAG omits a needed path (reject the model's
  independence claims). Report C, df = 2k, k, and p together.

## Do / Don't
- DO: state results as "X carries information about some component of Y beyond
  Y's parents" when a claim's p is small — not "X affects the mean of Y".
- DO: require nodes fitted with `se = TRUE` (declarative `drm_sem()` does this)
  so refits converge and `vcov`/LRT work; warn via `check_sem()` if not.
- DON'T: build claims only from `mu` edges, or condition on non-parents.
- DON'T: feed failed/degenerate claims into Fisher's C.
- DON'T: add or change a d-sep rule without a recovery test (a DGP where the
  true missing arrow is known) — see `validation-harness`.
