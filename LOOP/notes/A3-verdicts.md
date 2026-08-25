# A3 — Adversarial verdicts (default REFUTED)

Status: **DONE** (2026-08-25). Primary-checked. Every candidate starts REFUTED until
conditioning set, selection, and simultaneity checks pass.

**Target (P):** \(\mathcal{B}(G)=\) all Cor. 5.3 pairwise claims (anteriors) \(\Rightarrow\) every
m-separation in \(\operatorname{Im}(G)\).

---

## Checks applied to every candidate

1. **Conditioning set** vs R&S Cor. 5.3 (UW TR 375 / Annals): \(\operatorname{ant}_G(\{\alpha,\beta\})\setminus\{\alpha,\beta\}\)?
2. **Selection / \(\cup S\)** trap (S&D drop \(\cup S\); coincide only when \(S=\emptyset\))?
3. **Simultaneity:** full collection \(\mathcal{B}(G)\) + axioms ⇒ all of \(\operatorname{Im}(G)\), or only pairwise existence of *some* separator?
4. **drmSEM compositionality:** does the theorem’s hypothesis hold for any-component LRT / piecewise SEM?

---

## C1 — Sadeghi & Lauritzen (2014) Theorem 3

| Check | Result |
|---|---|
| Conditioning set | **MATCH** Cor. 5.3 — §6.1 pairwise uses \((\operatorname{ant}(i)\cup\operatorname{ant}(j))\setminus\{i,j\}\) |
| Selection / \(\cup S\) | Ribbonless/ancestral class includes selection (undirected edges). drmSEM v1 is \(S=\emptyset\) (marginalised-only) — **no conflict** for drmSEM’s MAG path; S&D \(\cup S\) drop is a separate orientation trap already gated |
| Simultaneity | **MATCH (P)** — Thm 3: compositional graphoid \(\mathcal{J}\) satisfies pairwise **iff** global; pairwise statements + axioms generate the full model |
| Compositionality (drmSEM) | **FAIL / residual** — Thm 3 **requires** compositional graphoid. §2: positive density ⇒ graphoid, **not** generally compositional; Gaussian/some binary are. drmSEM’s any-component LRTs do **not** establish that the empirical independence model is a compositional graphoid |

**Verdict on (P) as published math:** **CONFIRMED** under the paper’s hypotheses (maximal ribbonless + compositional graphoid). Primary: Bernoulli/arXiv Thm 3 §6.2.

**Verdict as unconditional drmSEM wiring license:** **REFUTED** — compositionality not shown for drmSEM’s testing regime.

---

## C2 — Lauritzen & Sadeghi (2018) Theorem 4

| Check | Result |
|---|---|
| Conditioning set | **MATCH** Cor. 5.3 — pairwise (P): \(\langle i,j\mid\operatorname{ant}(\{i,j\})\rangle\) with \(\operatorname{ant}(\{i,j\})=\operatorname{ant}(i)\cup\operatorname{ant}(j)\setminus\{i,j\}\) (§5.1; ant def §2). Explicitly specialises to AGs / R&S (§5.1) |
| Selection / \(\cup S\) | CMGs include ancestral graphs; same as C1 for drmSEM \(S=\emptyset\) |
| Simultaneity | **MATCH (P)** — Thm 4 §5.2: pairwise (P) iff global for compositional graphoids on maximal CMGs. §5.3 Ex. 1: **not** every alternate separator system works — anterior choice matters |
| Compositionality (drmSEM) | **FAIL / residual** — same as C1 (Cor. 5; §3.4) |

**Verdict on (P) as published math:** **CONFIRMED** (generalises C1 to CMGs; for MAGs same content). Primary: AOS/arXiv/UCL Thm 4 §5.2.

**Verdict as unconditional drmSEM wiring license:** **REFUTED** — same compositionality gap.

---

## Near-misses REFUTED

| Candidate | Why REFUTED for (P) |
|---|---|
| R&S Cor. 5.3 alone | Pairwise **soundness** only; **silent** on pairwise ⇒ global (S&L 2014 §1 note) |
| R&S Thm 7.6 “completeness” | Completeness of global Markov in faithfulness/extension sense (§7.4.1) — **not** basis-set (P) |
| Zhang 2008 AIJ / JMLR 2008a “completeness” | FCI **orientation-rule** completeness — wrong sense of completeness |
| Ali et al. 2009 | Markov **equivalence**; maximality = some separator exists — not anterior \(\mathcal{B}(G)\Rightarrow\operatorname{Im}(G)\) |
| Shipley & Douma 2021 union basis | **Parents** not anteriors; assumes basis = independence model; **no** theorem for (P); \(\cup S\) drop (orientation) |

---

## Summary for A4

- Published answer to (P) under compositional graphoids: **yes** — S&L 2014 Thm 3; L&S 2018 Thm 4 (same anteriors as Cor. 5.3).
- drmSEM residual gap **Y**: compositionality of the independence model implied by any-component LRT / Fisher’s \(C\) is **not** licensed by these theorems; positive density alone insufficient (S&L §2; L&S §3.4).
- S&D parent-based claims remain **non-licensed** even given C1/C2 (wrong conditioning set; L&S §5.3 Ex. 1 shows alternate separators need not generate the model).
