# drmTMB upstream issues — to file from drmSEM work

This session's GitHub access is scoped to `itchyshin/drmSEM` only, so issues
cannot be filed on `itchyshin/drmTMB` from here. Collect genuine engine problems
here; file them on drmTMB (or widen this session's repo scope) later. Only list
things that are actually drmTMB's to fix — not drmSEM bugs.

## Status: none confirmed yet

Every CI failure so far has been a drmSEM bug (sampler parameterization,
`drmTMB::poisson`/`Gamma` vs `stats::`, Gamma link), not drmTMB.

### Candidate (needs confirmation, do NOT file yet) — OQ-7
`TMB::sdreport()` emits `NaNs produced` (NaN standard errors) when fitting the
small canonical integration DGP (`size -> abundance -> survival`, n=300). This is
most likely a weakly-identified/boundary fit on a small fixture, not an engine
bug. Before filing: reproduce on a clean, well-conditioned single-node fit and
confirm the Hessian is genuinely non-PD where it should not be. If confirmed, the
ask would be a clearer warning (which parameter) and/or a more robust
`sdreport` fallback.

### Candidate (needs confirmation) — structured-effect object not resolvable on refit
When drmSEM refits a node for d-separation (adds one predictor and re-fits via
`drmTMB::drm_formula()` + `drmTMB::drmTMB()`), a `phylo(1|species, tree=phy)`
term fails because `phy` (the ape tree captured in the original formula's
environment) is not resolvable in the refit. CI: PR #6 run 26998231239 ->
`status="refit_failed"` for the augmented phylo-node refit. Ask: does drmTMB
store the resolved phylo covariance/tree on the fitted object (so a refit could
reuse it), or must the caller keep the tree in scope? If the former, expose it;
if the latter, document that re-fitting a structured node requires the structured
object in the evaluation environment. This blocks d-separation/Fisher's C for
phylogenetic SEMs (all endogenous nodes carry the phylo term). drmSEM-side
workaround (capture+re-inject the tree) is tracked as OQ-13.
