# 03 — d-separation: the any-component independence test

This document defines how drmSEM tests whether its DAG omits a needed arrow. The
rule is drmSEM's own *definition* of a missing arrow, not a borrowed standard:
**a missing arrow X → Y asserts that X has no effect on _any_ modelled
distributional component of Y.** Code: `R/dsep.R` (graph logic and Fisher's C)
and `R/extractors.R` (the augmented refit). If this semantics changes, this file
changes (AGENTS.md rule 4).

## The any-component definition

In a mean-only piecewise SEM, a missing arrow X → Y means "X does not predict the
mean of Y given Y's parents". drmSEM nodes model several distributional
components (`mu`, `sigma`, `nu`, `zi`, `hu`, `sd(group)`, `rho12`), so the
question is sharper: a missing X → Y arrow claims X predicts *none* of them.

Consequently, adjacency is also any-component: `drm_is_parent(x, y, edges)` is
true if X enters Y through *any* component. In the canonical example,
`habitat -> abundance` exists only through `zi`, but that still makes `habitat`
adjacent to `abundance`, so no independence claim is generated for that pair
(see `test-dsep-kernels.R`).

## Basis set construction

`basis_set()` enumerates the independence claims to test. For each endogenous
node Y in topological order and each variable X (endogenous or exogenous):

1. **Causal ordering.** X must be causally no later than Y: `ord(X) <= ord(Y)`,
   where `drm_order_index()` gives exogenous variables index 0 and endogenous
   nodes their topological position. This avoids testing an arrow against the
   causal direction.
2. **Non-adjacency.** Skip the pair if X is a parent of Y (`drm_is_parent`, any
   component) or if Y is a parent of X.
3. The surviving pairs become claims `X _||_ Y | {parents of Y}`, conditioning
   on Y's existing parents (the union over all components).

The output is a data frame with `claim`, `x`, `y`, `given`.

## The LRT-of-augmented-node test

`dsep()` tests each claim by a likelihood-ratio test of Y's node against an
augmented refit:

1. Read Y's base fit and its log-likelihood / df (`drm_fit_logLik`).
2. `drm_refit_augmented(fit, X)` rebuilds Y's `bf()` adding `+ X` to **every
   modelled component sub-formula** — `mu`, `sigma`, `zi`, ... — then refits the
   node with the same family and data (standard errors requested).
3. `LR = 2 * (logLik_aug − logLik_base)`; `df = df_aug − df_base` = the number of
   added terms (one per augmented component, more for multi-column factors);
   `p = P(chi^2_df > LR)`.

A small p-value means X carries information about *some* component of Y beyond
Y's parents — evidence for a missing arrow. Claims whose refit cannot be formed
are flagged (`status` in {`no_data_column`, `refit_failed`, `degenerate`}) and
dropped from Fisher's C rather than silently scored.

## Fisher's C

The claim p-values are combined into Fisher's C:

```
C = -2 * sum(log p),   df = 2k,   p = P(chi^2_{2k} > C)
```

for the k well-formed claims (`drm_fisher_c_from_p`). A small overall p-value
indicates the DAG omits at least one needed path. `fisher_c()` returns
`fisher_c`, `df`, `n_claims`, `p.value`; it accepts either a `drm_sem` (runs
`dsep()` first) or a `drm_dsep` result.

## Honest note: this is an open research choice

The any-component definition is deliberate and, as far as we know, novel. It
treats "X is irrelevant to Y" as a statement about the *whole conditional
distribution* of Y, not only its mean. Reasonable alternatives exist — testing
each component separately, or only `mu` — and we have not yet established the
calibration of Fisher's C under the any-component augmentation by simulation.
This is recorded as an open question and the test is labelled experimental in the
validation ledger.

## Limitations

- **Refit cost.** Every claim refits a full drmTMB node; on large graphs or slow
  fits this dominates runtime. There is no shortcut (no covariance-based test) by
  design — the test is likelihood-based per node.
- **Complete-case.** Refits use the node's own model data. Different nodes built
  on different complete-case subsets can make claims only loosely comparable;
  align the data up front.
- **Augmentation can fail.** Adding X to a component that cannot identify it
  (e.g. a single-level factor in a subset) yields a degenerate or failed refit;
  those claims are reported with a `status` and excluded from C rather than
  contributing a misleading p-value.
- **df counting.** `df` is read from the augmented vs base fit, so it correctly
  counts factor-expansion terms, but it assumes the base and augmented nodes
  differ *only* by the added predictor.
