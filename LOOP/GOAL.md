# GOAL — Wire MAG m-separation into basis_set()/dsep()

**IMMUTABLE.** Re-read at the top of every arc.

## Definition of done
- [ ] `latent=` on `drm_sem()`/`drm_psem()`; MAG basis set on Cor. 5.3 anteriors (`S=∅`)
- [ ] Compositionality guardrail 3 (`cli_inform` when non-Gaussian / sigma nodes)
- [ ] Tests: S&D claim set + DGP recovery (DAG dsep wrong, MAG msep right)
- [ ] Docs/roxygen + memory ledgers + full test suite green

## Invariants
- Never push/merge without Shinichi
- Do not edit evidence worktree `drmSEM-mag-completeness`
- dsep LRT machinery unchanged (any-component); only claim generation changes
- Selection latents out of scope

## Pre-authorisation
- Scoped edits in mag-wire worktree; local commits; parallel subagents; no push

## Out of scope
- Selection latents; wiring parent-based S&D separators; merge to main
