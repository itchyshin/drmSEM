# A2 — Corpus findings (narrow questions)

Status: **DONE** (2026-08-25). Primary PDFs checked; NotebookLM used only as UNVERIFIED corroboration (notebook `fca2f8ec-cea9-4238-bac6-19a30eeeb51b`). drmSEM own docs excluded from corpus (GOAL invariant 5).

**Target proposition (P)** from A1: does the collection \(\mathcal{B}(G)\) of all Cor. 5.3 pairwise claims
\(a \perp\!\!\!\perp b \mid \operatorname{ant}_G(a)\cup\operatorname{ant}_G(b)\) (anteriors; endpoints excluded) imply **every**
m-separation in \(\operatorname{Im}(G)\)?

Narrow question per source: *Does this source state a global Markov property for MAGs /
ancestral graphs, and under which conditioning set? Does it prove pairwise ⇒ global?*

---

## Corpus verdicts

### 1. Richardson & Spirtes — *Ancestral Graph Markov Models* (UW TR 375 / Ann. Statist. 2002)

**Primary:** CMU PDF `annals2002.pdf` (Annals text; cite as UW TR 375 section/theorem per design doc).

| Question | Verdict | Cite |
|---|---|---|
| Global Markov via m-separation? | **States it** — \(\operatorname{Im}(G)\) is the independence model from m-separation; called a global Markov property | §2.1.1 (separation criterion = global Markov); §3.4 (pathwise m-separation); Fig. 7 caption |
| Pairwise claim with anteriors? | **States it** — for MAG, nonadjacent \(\alpha,\beta\): \(\{\alpha\}\perp\!\!\!\perp\{\beta\}\mid\operatorname{ant}_G(\{\alpha,\beta\})\setminus\{\alpha,\beta\}\) | Cor. 5.3; previewed as PAIRWISE MARKOV PROPERTY in §3.7 |
| Pairwise ⇒ global / \(\mathcal{B}(G)\Rightarrow\operatorname{Im}(G)\)? | **Silent** on equivalence of pairwise and global Markov properties | No theorem equates them. §7.4.1 Thm 7.6 is *completeness of the global Markov property* in the faithfulness/extension sense — **not** (P) |
| \(\cup S\) / selection? | **States** orientation/adjacency construction with selection | §4.2.1 and Thm 4.2 (inducing paths w.r.t. \(S,L\)) |

**Near-miss trap:** Thm 7.6 “completeness” ≠ basis-set completeness (P).

**NotebookLM:** UNVERIFIED corroboration agrees Cor. 5.3 + no pairwise⇒global theorem.

---

### 2. Zhang (2008) — orientation-rule completeness (*Artif. Intell.*) / companion JMLR 2008a

**Primary for AIJ 2008:** paywalled (Unpaywall: not OA). **Primary for companion:** Zhang, J. (2008a). *Causal reasoning with ancestral graphs.* *JMLR* 9 — open PDF.

| Question | Verdict | Cite |
|---|---|---|
| Global Markov for ancestral graphs? | **States something weaker** — defines global Markov by m-separation; recalls maximality / pairwise for DAGs vs MAGs | JMLR 2008a Def. 2 (m-separation); discussion of maximality and pairwise Markov property of DAGs |
| Pairwise ⇒ global for MAG basis? | **Silent** on (P) | — |
| “Completeness” in AIJ 2008? | **States something weaker / different** — completeness of **FCI orientation rules** (arrow/tail), not basis-set completeness | Title + AIJ abstract (Unpaywall metadata); JMLR 2008a cites AIJ 2008b for orientation completeness |

**Near-miss trap:** “completeness” here = orientation rules for FCI/PAGs, not \(\mathcal{B}(G)\Rightarrow\operatorname{Im}(G)\).

---

### 3. Ali, Richardson & Spirtes (2009) — *Markov equivalence for ancestral graphs*

**Primary:** arXiv `0908.3605` / CMU `AOS626.pdf`.

| Question | Verdict | Cite |
|---|---|---|
| Global Markov? | **States it** — \(\operatorname{I}_m(G)\) via m-separation “comprise the global Markov property for \(G\)” | Def. 2.3 and following paragraph |
| Pairwise for MAGs? | **States something weaker** — maximality: every missing edge has *some* m-separating set; contrasts with DAGs’ pairwise Markov | §3 (after Def. 3.1); Prop. 3.3 is DAG pairwise (not MAG) |
| Pairwise ⇒ global with anteriors? | **Silent** on (P) | Paper characterises Markov *equivalence* (Thm 3.7 / Cor. 3.28), not generation of \(\operatorname{Im}(G)\) from Cor. 5.3 claims |

---

### 4. Shipley & Douma (2021) — piecewise SEM with latents

**Primary:** WUR depot PDF `edepot.wur.nl/542481`.

| Question | Verdict | Cite |
|---|---|---|
| Global Markov / m-sep test? | **States something weaker** — treats union basis set of m-separation claims as “the independence model” and runs an m-sep / Fisher’s \(C\) test | Section “An m-sep test for DAGs involving latent variables”, steps (4)–(8) |
| Conditioning set? | **Parents, not anteriors** — “conditional on the set (Z) of observed causal parents of either X or Y” (+ \(L_C\)) | Same section, union-basis-set paragraph |
| Pairwise ⇒ global proved? | **Silent** — assumes basis set tests the independence model; no theorem equating parent-based claims to full \(\operatorname{Im}(G)\) or to Cor. 5.3 | — |
| \(\cup S\)? | Orientation rules drop R&S \(\cup S\) (already documented in design doc); coincides with R&S when \(S=\emptyset\) | Orientation rules (i)–(iv) in MAG construction section |

**Near-miss trap:** applied basis-set *practice* ≠ published completeness proof; wrong conditioning set vs Cor. 5.3.

---

### 5. Forward cite (added in A2) — Sadeghi & Lauritzen (2014)

**Primary:** arXiv `1109.5909` → *Bernoulli* 20(2):676–696. DOI `10.3150/12-BEJ502`.

Located by second-shaped search: “pairwise Markov” + MAG / maximal ancestral + global Markov equivalent.

| Question | Verdict | Cite |
|---|---|---|
| Global Markov? | **States it** — \(A\perp_m B\mid C \Rightarrow \langle A,B\mid C\rangle\in\mathcal{J}\) | §6.1 |
| Pairwise with anteriors? | **States it** — \(i\not\sim j \Rightarrow \langle i,j\mid(\operatorname{ant}(i)\cup\operatorname{ant}(j))\setminus\{i,j\}\rangle\in\mathcal{J}\) | §6.1 (same anteriors as R&S Cor. 5.3) |
| Pairwise ⇔ global? | **States it** (under hypotheses) | **Theorem 3** (§6.2): for **maximal ribbonless** \(G\), if \(\mathcal{J}\) is a **compositional graphoid**, then pairwise iff global. Ancestral graphs / MAGs are a subclass (§1, §4.3; authors note R&S defined both properties “without considering conditions under which they are equivalent”) |
| Probabilistic specialisation? | **States something weaker** — Cor. 2: probabilistic \(\mathcal{J}\) with intersection + composition | Cor. 2 (§6.2) |
| Compositionality automatic? | **States gap** — positive density ⇒ graphoid, **not** always compositional; Gaussian / some binary are | §2 (probabilistic independence models paragraph); §6.3 necessity |

**This is the strongest hit for (P).** Residual: compositional-graphoid hypothesis (and whether drmSEM’s any-component LRT “independence model” is one).

**NotebookLM:** UNVERIFIED corroboration of Theorem 3 + anterior conditioning + compositional graphoid requirement — **matches primary.**

---

### Related forward (not elevated to candidate for (P) alone)

- **Lauritzen & Sadeghi (2018?) / AOS “Unifying Markov properties”** — pairwise ⇔ global for compositional graphoids on maximal CMGs (broader class). Web/Euclid summary **UNVERIFIED** until needed; S&L 2014 Thm 3 already covers MAGs.

---

## Searches that returned nothing (for A4 list)

1. Within R&S primary text: theorem equating pairwise Markov property to full \(\operatorname{Im}(G)\) / global Markov for MAGs — **none** (Thm 7.6 is a different “completeness”).
2. Within Ali et al. 2009: pairwise (anteriors) ⇒ global — **none**.
3. Within Zhang JMLR 2008a / AIJ 2008 metadata: basis-set pairwise⇒global — **none** (orientation-rule completeness only).
4. Within Shipley & Douma 2021: proof that parent-conditioned union basis implies all m-separations — **none**.
5. UW TR 375 live URL `stat.washington.edu/.../tr375.pdf` — **404** (2026-08-25); Annals/CMU PDF used instead.
6. Zhang AIJ 2008 OA PDF via Unpaywall — **no OA location**.
7. Crossref query `pairwise global Markov maximal ancestral graph` — returned R&S and related titles; did **not** surface a third independent proof beyond S&L-type results (S&L found via Bernoulli / arXiv search, not this Crossref hit list).

---

## Strongest available for A3

**Candidate C1:** Sadeghi & Lauritzen (2014) **Theorem 3** — pairwise (anteriors) ⇔ global for compositional graphoids on maximal ribbonless graphs (includes MAGs).

Default in A3: try to REFUTE (conditioning set mismatch? selection? only pairwise existence vs simultaneous collection? compositionality?).
