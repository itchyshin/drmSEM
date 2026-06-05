---
name: validation-harness
description: Testing discipline for drmSEM — pure-logic kernels run without drmTMB, integration tests gated by skip_if_not_installed, every effect/estimand/d-sep rule needs a known-DGP recovery test, evidence tiers recorded in the validation ledger. Use when adding tests or any new estimand/rule.
---

# drmSEM validation harness

Two test tiers, kept strictly separate so the suite runs on a toolchain-free
machine and still proves correctness where it counts.

## Tier 1 — pure-logic kernels (NO drmTMB)
- Live in `test-dsep-kernels.R`, `test-effect-kernels.R`, `test-utils.R`.
- Exercise the numeric/graph kernels directly (Fisher's C math, basis-set
  construction, topological propagation, family samplers) with hand-built
  inputs. NEVER load or fit drmTMB here.
- These MUST pass with `drmTMB` absent. If a kernel needs a fit, it is in the
  wrong tier — refactor the pure math out of the adapter.

## Tier 2 — integration (drmTMB required)
- Live in `test-integration.R`. First line of the file/block:
  `skip_if_not_installed("drmTMB")`.
- Fit real `drmTMB` nodes, build a `drm_sem`, run `paths()`, `dsep()`,
  `fisher_c()`, effects end to end. Keep these small and fast.

## Recovery tests (the non-negotiable rule)
Per AGENTS.md design rule 1: do NOT add a public effect type, estimand, or
d-separation rule without a simulation test that recovers a KNOWN
data-generating process.
- Simulate from a DGP with known coefficients/effects (`set.seed()` always; reuse
  `helper-dgp.R`).
- Assert the recovered estimate is within Monte-Carlo tolerance of the truth.
- A recovery test is required for: each new family sampler, each new mediation
  mode, each new estimand (direct/indirect/total variant), and each new d-sep
  rule. A green integration test that only checks "it runs" is NOT enough.

## Checklist for a new estimand / sampler / rule
- [ ] Pure kernel unit test (Tier 1) for the math.
- [ ] Integration smoke test (Tier 2), `skip_if_not_installed` guarded.
- [ ] Known-DGP recovery test proving the number is correct.
- [ ] Seeds set; tolerances justified by B / n_sim, not hand-tuned to pass.
- [ ] Component label asserted where relevant (don't recover a `sigma` effect and
      report it as `mu`).

## Evidence tiers — record them
After validating a claim, record it in `docs/memory/VALIDATION_LEDGER.md` with a
tier:
- `validated` — recovery test passes against a known DGP.
- `experimental` — implemented, smoke-tested, recovery still pending.
- `assumed` — relies on an unverified drmTMB parameterization (link to the
  `drmtmb-adapter` confirmation TODO).
Each entry: claim, test file/line, tier, date. Update the ledger in the same
change that adds the test; also note it in `docs/memory/AGENT_LOG.md`.

## Speed
Keep recovery DGPs small (low n, few draws) so the suite stays fast; use a
larger N only when a tolerance genuinely requires it. Cover ordinary, edge, and
malformed inputs (Curie's mandate).
