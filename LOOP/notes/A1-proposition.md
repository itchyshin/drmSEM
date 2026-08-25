# A1 — Proposition a MAG basis set needs + corpus

Status: **DONE** (verified against `docs/design/14-m-separation.md`, 2026-08-25).
Written **before** any new literature read (seeded only from the arc doc and design doc).

---

## Formal proposition (what a basis set needs)

Let \(G\) be a **maximal ancestral graph (MAG)** on observed vertices \(V\), obtained
from a DAG by marginalising latents \(L_M\) (drmSEM v1: selection set \(S = \emptyset\);
conditioned latents are structurally unrepresentable).

**Pairwise soundness already in hand (not this hunt's target).** Richardson & Spirtes
Cor. 5.3 licenses, for non-adjacent \(a, b \in V\), the *pairwise* claim

\[
a \;\perp\!\!\!\perp\; b \mid \operatorname{ant}_G(a) \cup \operatorname{ant}_G(b)
\]

(m-separation in \(G\)), where the conditioning set is the **anteriors in the MAG**,
**not** the observed parents used by Shipley & Douma. That is pairwise soundness only.

**Where \(\cup S\) enters (construction / orientation, not the Cor. 5.3 claim itself).**
In R&S §4.2.1 orientation / adjacency construction, the selection set appears as
\(\cup S\). Shipley & Douma's published recipe **drops** \(\cup S\); their rules coincide
with R&S only when \(S = \emptyset\). drmSEM's marginalised-only MAG path is exactly that
\(S = \emptyset\) case. The completeness hunt below must still name \(\cup S\) so a
near-miss theorem that assumes selection, or that silently changes the conditioning set,
is not accepted as the result we need.

**Completeness proposition (THIS arc's target).** A basis set for independence testing
needs more than pairwise soundness. State:

> **(P)** For MAG \(G\), let \(\mathcal{B}(G)\) be the collection of all pairwise
> m-separation claims of the Cor. 5.3 form (anteriors as conditioning sets). Does
> \(\mathcal{B}(G)\) **imply every** m-separation statement entailed by \(G\) — i.e.
> pairwise claims \(\Rightarrow\) **global** m-separation / the full independence model
> of \(G\)?

Equivalently for drmSEM: if every claim in \(\mathcal{B}(G)\) holds in the data
(any-component LRT), does that license concluding that the MAG's full independence
model holds? Without (P), wiring MAG claims into `basis_set()` / `dsep()` on the
strength of "each pairwise claim is individually sound" is the plausible-and-wrong
failure mode `14-m-separation.md` gates against.

**Out of scope for (P):** proving Cor. 5.3 itself; re-deriving DAG→MAG orientation;
implementing option (b); selection (\(S \neq \emptyset\)).

---

## Corpus (reachable routes)

Cite by **section/theorem**, never page. Exclude drmSEM's own vignettes/design docs
from any NotebookLM corpus (GOAL invariant 5).

| # | Source | Why in corpus | Reachable route |
|---|--------|---------------|-----------------|
| 1 | Richardson, T. & Spirtes, P. — *Ancestral Graph Markov Models*. UW Dept. of Statistics **TR 375** (Annals 2002 version exists; cite TR section/theorem). | Primary: Cor. 5.3 (pairwise / anteriors); §4.2.1 orientation and \(\cup S\); global Markov language if any. | **Preferred free:** UW TR 375 PDF (historical path `https://www.stat.washington.edu/research/reports/2002/tr375.pdf` → sites path). **As of 2026-08-25:** that chain redirects to `stat.uw.edu` and returns **404** — recover via Wayback Machine snapshot of the washington.edu URL, a local copy from the 2026-08-15 lane, or author/dept. **Paywalled Annals:** Project Euclid (do not cite by page). |
| 2 | Zhang, J. (2008). *On the completeness of orientation rules for causal discovery in the presence of latent confounders and selection bias.* *Artificial Intelligence*. | Completeness of FCI / augmented orientation rules — possible near-miss or forward cite for MAG/global properties. | DOI `10.1016/j.artint.2008.08.001` (resolves; Elsevier). |
| 3 | Ali, R. A., Richardson, T. S. & Spirtes, P. (2009). *Markov equivalence for ancestral graphs.* *Ann. Statist.* 37(5B). | Markov equivalence of ancestral graphs / MAGs — may state or cite what shared m-separation means globally. | DOI `10.1214/08-AOS626`; open PDF `https://www.cmu.edu/dietrich/philosophy/docs/spirtes/AOS626.pdf`; arXiv `https://arxiv.org/abs/0908.3605`. |
| 4 | Shipley, B. & Douma, J. C. (2021). *Testing piecewise SEMs in the presence of latent variables…* *Struct. Equ. Modeling* 28(4). | Applied MAG / m-sep claim sets; parent-based conditioning (contrast with anteriors); printed examples already used in V-112–V-114. | DOI `10.1080/10705511.2020.1871355`; already in `inst/REFERENCES.bib` (`ShipleyDouma2021`). |
| 5 | Forward cites from (1)–(4) that state a **global Markov property** for MAGs / ancestral graphs (or claim pairwise ⇒ global). | Catch successors that might hold (P). | Added only when (1)–(4) name them in A2; each new item needs its own reachable route before a verdict. |
| 6 | **Sadeghi, K. & Lauritzen, S. (2014).** *Markov properties for mixed graphs.* *Bernoulli* 20(2), 676–696. | **Added at G0 (AGENT-INFERRED lead):** likely pairwise ⇔ global for mixed/ribbonless graphs under compositional graphoid axioms — treat as **UNVERIFIED lead** until A2 primary-check. | DOI `10.3150/12-BEJ502`; arXiv `https://arxiv.org/abs/1109.5909` / PDF `https://arxiv.org/pdf/1109.5909`. |
| 7 | **Lauritzen, S. & Sadeghi, K. (2018).** *Unifying Markov properties for graphical models.* *Ann. Statist.* 46(5), 2251–2278. | **Added at G0 (AGENT-INFERRED lead):** same family — pairwise ⇔ global for CMGs (includes ancestral graphs) under compositional graphoids — **UNVERIFIED lead** until A2. | DOI `10.1214/17-AOS1618`; arXiv `https://arxiv.org/abs/1608.05810`; UCL OA `https://discovery.ucl.ac.uk/id/eprint/10058842/1/unifying-Markov-properties-for-graphical-models.pdf`. |

**Not corpus (guard):** drmSEM `docs/design/*`, vignettes, `R/*` — may *frame* the gap, never *answer* it.

---

## A1 verify vs `docs/design/14-m-separation.md`

**Check:** re-read this proposition against the design doc's "NOT implemented" /
gated basis-set note.

| Design-doc claim (`14-m-separation.md` §§ "Sourcing" / "What remains GATED") | A1 proposition |
|---|---|
| Cor. 5.3 → each **pairwise** claim sound; conditioning = **anteriors in the MAG**, not S&D **parents** | Same: pairwise soundness assumed; (P) asks for pairwise ⇒ **global** |
| S&D drop R&S \(\cup S\); coincide only when \(S = \emptyset\) | Same: \(\cup S\) named; drmSEM path is \(S = \emptyset\) |
| Pairwise ⇒ global **never located** — that is what a basis set needs | Same: (P) is exactly that missing step |
| `drm_dag_to_mag()` converts and **stops**; nothing wired into `basis_set()` / `dsep()` | Same: out of scope; evidence packet only |

**Verdict:** **SAME GAP.** A1 describes the identical missing completeness step that gates
wiring in `14-m-separation.md` (and `VALIDATION_LEDGER.md` V-112…V-115b note:
"pairwise ⇒ global was never located, and that is exactly what a basis set needs").

**Verified:** 2026-08-25, Cursor lane, worktree `drmSEM-mag-completeness`.
