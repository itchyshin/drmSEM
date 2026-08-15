# 14 — m-separation and latent variables (DESIGN ONLY — not implemented)

**Status: design, not code.** Nothing in `R/` implements any of this. The file exists so
the drmSEM-side integration can be reviewed independently of the graph theory, and so
the one part that must not be written from memory is visible as a gate rather than
discovered halfway through an implementation.

## Why this is worth doing at all

`R/dsep.R:86-90` already records the idea: a declared covariance edge is *equivalent to
a latent common cause* (Shipley & Douma 2021; Pearl 2009 thm 5.2.3), and the same
argument generalises to a full DAG → MAG conversion with m-separation replacing
d-separation.

The strategic case is narrower than "add latents", and it is worth stating honestly
because it cuts against the obvious framing:

- **This is parity, not differentiation.** `because` (von Hardenberg et al. 2026)
  already ships m-separation on the implied MAG. drmSEM's differentiator is that a path
  can target a **non-mean component**; m-separation does not extend that.
- **It is nonetheless in charter and cheap in architecture.** m-separation is a *graph*
  operation, not a likelihood one. It needs no joint likelihood, so it reaches the
  latent problem from the side the charter allows (`00-charter.md`: drmSEM never fits
  its own likelihoods). The roadmap's only latent item — a reflective measurement model
  — is blocked precisely because it *would* need one.
- **A reviewer who knows one package will ask about the other.** Being unable to say
  anything about unmeasured confounding is a real gap in review, independent of novelty.

## What v1 must NOT do

**Marginalised latents only.** A latent may be declared as marginalised over (`L_M`) —
an unmeasured common cause. It may **not** be declared as implicitly conditioned on
(`L_C`, i.e. selection). The two are not interchangeable: conditioning on a collider
*opens* a path that marginalising leaves closed, so treating a selection variable as if
it were marginalised produces **silently wrong independence claims** — a confident
"these are independent" that is the opposite of the truth.

That is this package's defining failure mode and the whole subject of the 2026-08-15
defect lane. So v1 accepts `latent = c(...)` meaning marginalised, and **aborts** on any
attempt to declare a conditioned latent, rather than approximating it.

## The drmSEM-side integration (specifiable now, from the codebase)

This half needs no external source and can be reviewed today.

| piece | where it plugs in |
|---|---|
| declaration | a `latent =` argument on `drm_sem()`/`drm_psem()`, normalised by a `drm_build_latents()` mirroring `drm_build_composites()` (`R/composite.R:229`) |
| graph construction | after `drm_build_edges()`/`drm_collapse_edges()` (`R/edges.R`), producing a MAG alongside `sem$var_edges` rather than replacing it |
| claim generation | `basis_set()` gains a MAG branch; the union basis set is taken over m-separation instead of d-separation |
| testing a claim | **unchanged.** Each claim still becomes an any-component LRT via `drm_refit_augmented()` — the drmSEM contribution (D-2) is orthogonal to which claims are generated |
| combination | **unchanged.** `fisher_c()` consumes the p-values as-is |
| reporting | `paths()` must keep bidirected (`↔`) edges out of the directed table, exactly as `covary()` edges are kept out today |

The important structural point: **m-separation changes only which claims are
generated.** It does not touch the effect calculus, the component labelling, or the
likelihood. That is what makes it charter-compatible and reviewable in isolation.

Relationship to `covary()`: the existing bidirected-edge rule at `R/dsep.R:76` (a
declared covariance drops the `y1 ⊥ y2` claim, OQ-14) is the same idea in miniature. A
MAG layer generalises it, and whether `covary()` should be *reimplemented* on top of the
MAG rather than kept parallel is an open design question — not a v1 requirement.

## The part that is GATED on a source

**DAG → MAG conversion, and specifically the edge-orientation rules.**

The candidate construction — stated so a reviewer can check it, **not** as a spec to
implement from — is the classical one for the marginalised-only case: for observed
variables `A`, `B`, adjacency in the MAG iff there is an inducing path between them in
the DAG relative to the latents; orientation from the ancestor relation, `A → B` when
`A` is an ancestor of `B`, `A ↔ B` when neither is an ancestor of the other.

**That must be verified against Richardson & Spirtes (2002), *Ancestral graph Markov
models*, before any implementation.** It is not in `inst/REFERENCES.bib` and there is no
local copy. Writing it from memory is exactly the failure this design exists to prevent:
an orientation rule that is subtly wrong yields a basis set that is *plausible and
wrong*, and every downstream Fisher's C inherits it without any test noticing — because
the tests would be written from the same wrong memory.

Two acceptance conditions follow, and neither is optional:

1. **Reproduce a printed claim set.** Shipley & Douma (2021) work the
   `A → X ← L → Y → B` example and print **both** its d-separation and m-separation
   claim sets. That paper *is* cited already (`inst/REFERENCES.bib:413`). Reproducing
   its printed m-sep claims exactly is the acceptance test — not "the code runs".
2. **A DGP where d-sep is wrong and m-sep is right.** An unmodelled latent common cause
   should make plain `dsep()` reject a true model while m-sep does not. This is the test
   that would catch a wrong orientation rule, because a wrong rule generally fails it in
   one direction or the other.

## Recommended next step

Commission a grounded search (`/notebook`, Ranga) for Richardson & Spirtes (2002) §3–4
and the Shipley & Douma (2021) worked example, and distil the orientation rules *with
citations* before writing code. That is cheap, it is the house method for exactly this,
and it converts the gate above into a reviewable artifact.

Until that lands, this file is the design and there is deliberately no implementation.

## References

Richardson, T. & Spirtes, P. (2002). Ancestral graph Markov models. *Annals of
Statistics* 30(4), 962–1030. **Not yet in `inst/REFERENCES.bib` — add it with the
implementation.**

Shipley, B. & Douma, J. C. (2021). Testing piecewise structural equations models in the
presence of latent variables and including correlated errors. *Structural Equation
Modeling* 28(4). Already cited (`inst/REFERENCES.bib:413`).
