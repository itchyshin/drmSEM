# 14 — m-separation and latent variables

**Status (updated 2026-08-15): the DAG → MAG conversion IS implemented** (`R/mag.R`,
`drm_dag_to_mag()`), verified against Shipley & Douma's printed MAGs. The **basis set
and the `dsep()` wiring are NOT**, and are gated below on a proof that was not found.
The gate that blocked the whole slice — sourcing the orientation rules — is discharged.

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
defect lane. `drm_dag_to_mag()` takes only `latent =`, meaning marginalised: there is no
selection argument, so a conditioned latent is **structurally unrepresentable** rather
than merely discouraged. That is stronger than an abort — there is nothing to mis-call.

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

## Sourcing: DISCHARGED (2026-08-15)

Three independent readings of the primary sources, then adversarial review of each,
then synthesis of only what they agreed on. Sources obtained: Richardson & Spirtes via
**UW Dept. of Statistics TR 375** (the tech-report version — Project Euclid is
paywalled, so citations are by section/theorem, not page) and Shipley & Douma (2021).

**Confirmed and implemented** (R&S §4.2.1 orientation; §4.2.3 / Thm 4.2(ii) adjacency;
Prop. 4.13 edge types; Thm 4.12 / Cor. 4.19 output class):

- **Adjacency.** `α, β` observed are adjacent iff an *inducing path* joins them: every
  collider on it is an ancestor of `{α, β}`, every non-collider is latent.
- **Orientation.** Arrowhead at `α` iff `α ∉ an(β)`; tail otherwise. On a DAG with no
  selection only `→`, `←`, `↔` can arise — `—` needs mutual ancestry.
- **Ancestors are taken in the ORIGINAL DAG, latents present.** For `α → u → β` with
  `u` latent the answer is `α → β`; delete latents first and you get `α ↔ β` — a valid
  MAG, the wrong one, wrong claims downstream, nothing to catch it.

**Two findings that changed the design, both from the review rather than the reading:**

1. **Shipley & Douma's published orientation rules are defective as a general recipe.**
   They drop R&S's `∪ S`, and they attribute the rule to R&S Lemma 3.9, which is about
   *reading* an existing ancestral graph and contains no `S`; the construction is
   §4.2.1. For `S = ∅` their rules (i)–(iii) coincide with R&S exactly and rule (iv)
   cannot fire. **So the marginalised-only restriction is now justified by the source,
   not by caution** — it is the case where the published recipe happens to be right.
2. **The parent-based basis set is unproven.** S&D condition on observed *parents*.
   What R&S actually prove (Cor. 5.3) conditions on **anteriors in the MAG**. No
   marginalised-only counterexample was found, but no proof either — and separately,
   pairwise ⇒ global was never established, which is what a basis set needs.

## What remains GATED, and why

**The basis set over a MAG.** Cor. 5.3 gives soundness for each pairwise claim, but a
d-separation test needs the *collection* of claims to imply every other independence in
the graph, and that step was not located in the source. Implementing a basis set on the
strength of "each claim is individually true" would be precisely the plausible-and-wrong
failure this design exists to prevent. `drm_dag_to_mag()` therefore converts graphs and
stops; nothing is wired into `basis_set()` or `dsep()`.

**Any selection / conditioned latent.** The verdict was an explicit NO: the only worked
example obtained for that case is a negative control, and the published recipe is
demonstrably wrong there. There is no selection argument, so it is structurally
unrepresentable rather than merely discouraged.

Two acceptance conditions were set before implementation. **The first is met** (V-112 / V-113); the second belongs with the `dsep()` wiring, which is not done:

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
Statistics* 30(4), 962–1030. Read via UW Dept. of Statistics **Technical Report 375**
(Project Euclid is paywalled), so citations here are by section/theorem rather than
page. **Still to add to `inst/REFERENCES.bib` when this reaches a user-facing surface;
`R/mag.R` is internal, so nothing exported cites it yet.**

Shipley, B. & Douma, J. C. (2021). Testing piecewise structural equations models in the
presence of latent variables and including correlated errors. *Structural Equation
Modeling* 28(4). Already cited (`inst/REFERENCES.bib:413`).

---

## Addendum — m-separation completeness decision packet (A4, 2026-08-25)

Lane: `claude/lane-mag-completeness` (worktree
`~/local-scratch/lanes/drmSEM-mag-completeness`). Evidence:
`LOOP/notes/A1-proposition.md`, `A2-findings.md`, `A3-verdicts.md`.
**No** `R/` or `tests/` edits; **no** wire into `basis_set()` / `dsep()` (G1).

### Formal proposition (from A1)

Let \(G\) be a MAG on observed \(V\) (drmSEM v1: \(S=\emptyset\)). Let \(\mathcal{B}(G)\) be
all pairwise Cor. 5.3 claims
\(\{\alpha\}\perp\!\!\!\perp\{\beta\}\mid\operatorname{ant}_G(\{\alpha,\beta\})\setminus\{\alpha,\beta\}\)
for nonadjacent \(\alpha,\beta\). **(P):** does \(\mathcal{B}(G)\) imply every m-separation in
\(\operatorname{Im}(G)\) (pairwise ⇒ global)?

### Per-source verdicts (cite §/thm; UNVERIFIED marked)

| Source | Verdict for (P) | Cite |
|---|---|---|
| R&S (UW TR 375 / *Ann. Statist.* 2002) | Global Markov via m-separation **stated**; Cor. 5.3 pairwise with **anteriors** **stated**; pairwise ⇒ global **silent**. Thm 7.6 is a different “completeness.” | §2.1.1, §3.4, §3.7, Cor. 5.3, §7.4.1 Thm 7.6 |
| Zhang 2008 AIJ / JMLR 2008a | **Silent** on (P); “completeness” = FCI orientation rules | JMLR Def. 2; AIJ title (OA PDF unavailable — Unpaywall) |
| Ali, Richardson & Spirtes 2009 | Global Markov **stated**; maximality / equivalence — **not** (P) | Def. 2.3; Thm 3.7 / Cor. 3.28 |
| Shipley & Douma 2021 | Union basis as independence model (**weaker**); conditioning = **observed parents** (+ \(L_C\)), not anteriors; no proof of (P); \(\cup S\) dropped in orientation | m-sep test section; orientation (i)–(iv) |
| Sadeghi & Lauritzen 2014 (*Bernoulli*) | **States (P)** under hypotheses: maximal ribbonless + **compositional graphoid** ⇒ pairwise ⇔ global; conditioning = anteriors (matches Cor. 5.3). G0 lead; **primary-checked** (no longer UNVERIFIED). | §6.1; **Thm 3** §6.2; Cor. 2; §2 compositionality gap |
| Lauritzen & Sadeghi 2018 (*Ann. Statist.*) | **States (P)** for maximal CMGs (includes AGs): pairwise (P) with \(\operatorname{ant}(\{i,j\})\) ⇔ global under compositional graphoid. G0 lead; **primary-checked**. | §5.1; **Thm 4** §5.2; Cor. 5; §5.3 Ex. 1 (wrong separators ≠ basis) |

NotebookLM interrogation used only as corroboration; all load-bearing cites above are
primary-checked except Zhang AIJ full text (closed OA).

### Recommendation

**(a)** — the completeness result exists: Sadeghi & Lauritzen (2014) **Theorem 3** and
Lauritzen & Sadeghi (2018) **Theorem 4** prove that, for a MAG (as maximal ribbonless /
maximal CMG), a compositional-graphoid independence model satisfies the Cor. 5.3
anterior pairwise Markov property if and only if it satisfies the global Markov property
(m-separation). **Cost of wiring (still Shinichi’s G1 call, not this lane):** implement
`basis_set()` / `dsep()` on **anteriors** (not S&D parents), keep \(S=\emptyset\), plus
docs/tests. **Residual gap Y:** compositionality is an assumption, not free — positive
density alone does not imply a compositional graphoid (S&L 2014 §2; L&S 2018 §3.4);
drmSEM’s any-component LRT / Fisher’s \(C\) regime is not shown to induce one. Parent-based
S&D claims remain unlicensed (L&S §5.3 Ex. 1). This lane does **not** implement (b) or
wire anything.

### Searches that returned nothing

1. R&S text: theorem equating pairwise Markov to full \(\operatorname{Im}(G)\) — none.
2. Ali et al. 2009: anterior pairwise ⇒ global — none.
3. Zhang JMLR/AIJ: basis-set pairwise ⇒ global — none (orientation completeness only).
4. Shipley & Douma 2021: proof parent-basis ⇒ all m-separations — none.
5. Live UW TR 375 URL — 404; Annals/CMU PDF used (theorem numbers aligned).
6. Zhang AIJ 2008 OA via Unpaywall — no OA location.
7. Crossref `pairwise global Markov maximal ancestral graph` — did not itself surface
   S&L; those arrived as G0 leads + Bernoulli/arXiv/AOS search.

**STOP.** G1: no `basis_set()`/`dsep()` wire. G2: no push.
