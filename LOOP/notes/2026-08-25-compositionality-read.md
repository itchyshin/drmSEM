# Compositionality read — does drmSEM's regime license S&L Thm 3 / L&S Thm 4?

Claude (Fable), 2026-08-25 · commissioned by Shinichi after the A4 packet · feeds the G1 call.
Sources: the primary PDFs in `LOOP/notes/corpus/` (page refs are PDF pages of those files).
Verdict up front: **composition is NOT free for drmSEM — it must be assumed, and the honest
wire states the assumption. Three routes below; only one is family-agnostic.**

## What the primaries establish (checked against the PDFs on disk)

1. **Composition is necessary, not a convenience.** S&L 2014 §7 (p20): the six compositional
   graphoid axioms are sufficient, and Figure 9 shows intersection and composition are
   **necessary** for pairwise ⇔ global. There is no weaker route around it.
2. **Every probabilistic model is a semi-graphoid; positive density adds the graphoid
   (intersection) axiom — but NOT composition.** S&L §2 (p5): "Probabilistic independence
   models with positive densities are not in general compositional graphoids; this only holds
   for special types of multivariate distributions."
3. **Regular multivariate Gaussian IS compositional.** S&L §2 (p5), with the concentration-
   matrix argument spelled out (setwise CI reduces to nodewise zeros). Symmetric binary
   distributions are the other named class.
4. **Graph-induced independence models are ALWAYS compositional graphoids.** S&L Thm 1 /
   L&S 2018 Thm 1 and the closing discussion (L&S p29): m-separation in any graph of these
   classes yields a compositional graphoid; "this is not always the case for the independence
   model induced by any probability distribution."

## What that means for drmSEM, family by family

- **Homoscedastic linear-Gaussian SEM** (all nodes gaussian, no `~ sigma` modelling): the
  joint observed distribution is multivariate Gaussian; fact 3 applies. **Composition holds;
  the wire is unconditionally licensed here.**
- **Location-scale gaussian** (drm's `sigma` formulas — the package's signature feature):
  conditional variance depending on parents breaks joint Gaussianity, so fact 3 does NOT
  cover it. [INFERENCE, elementary: a distribution with parent-dependent conditional
  variance is not jointly Gaussian; no primary on disk addresses this class either way.]
- **Poisson / ordinal / hurdle / other GLM-family nodes:** no guarantee (fact 2). Composition
  can genuinely fail for discrete distributions — the standard counterexample shape is a
  parity/XOR mechanism: X⊥Y and X⊥W separately while X depends on (Y,W) jointly.
  [STANDARD-TEXTBOOK; not verified against a primary on disk — a near-parity ecological
  mechanism (e.g. an interaction-only effect) is exactly the case a pairwise basis would
  miss without composition.]

## The family-agnostic route: faithfulness

If the data-generating distribution P is **faithful** to some graph G in these classes
(J(P) = J(G) — the data contain no independencies beyond the graph's), then J(P) is a
compositional graphoid **by fact 4**, whatever the families. This follows directly from the
primary-checked theorems; no further source is needed for the implication itself.
Faithfulness is the standard working assumption of all causal discovery, but it is an
ASSUMPTION about nature, not a checkable property of the fit.

Note the pleasing shape: the null hypothesis Fisher's C actually tests — "the data are
Markov AND generated compatibly with this graph" — is closest in spirit to the faithfulness
world where the license is automatic. The license fails exactly for data whose dependence
structure is *stranger than any graph can draw* (parity-type joint-only dependence).

## Recommendation for G1

**Wire it — option (a) — with the assumption made loud, not silent.** Concretely:

1. Implement `basis_set()`/`dsep()` on **anteriors** (never S&D parents — L&S §5.3 Ex. 1),
   `S = ∅` only, per the A4 packet.
2. State the license chain in the design doc and the user-facing docs: Cor. 5.3 (each claim
   sound) + S&L Thm 3 / L&S Thm 4 (claims jointly sufficient) + **composition assumed**,
   holding automatically for homoscedastic all-gaussian models and under faithfulness
   otherwise.
3. One `cli_inform()` (once per call, not per claim) when the model contains non-gaussian or
   sigma-modelled nodes: the MAG test's validity additionally assumes composition /
   faithfulness. Honest, cheap, and exactly the transparency-over-mystery house style.
4. Do NOT gate the feature on proving composition per-fit — it is not decidable from a fit,
   and refusing to ship a clearly-stated assumption every competitor states silently would
   be usability lost for no accuracy gained (D-139's usability principle).

Residual honesty note for the docs: Shipley & Douma's published parent-based recipe remains
unlicensed even WITH composition (L&S §5.3 Ex. 1 — wrong separators are not a basis); drmSEM
implementing anteriors would be, to our knowledge, the first correctly-licensed applied
version of this test. Worth a methods paragraph, possibly a standalone note.

**STOP.** This read implements nothing (G1 remains Shinichi's). No push beyond this note (G2
approval covers this branch).
