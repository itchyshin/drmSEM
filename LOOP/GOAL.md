# Next arc (designed, NOT started) — m-separation completeness

Status: **READY, needs its own plan gate.** Designed 2026-08-15 during the Step-4 close,
at Shinichi's request, then parked when he stopped the lane. Nothing here has been run.

This arc is READ-ONLY evidence gathering. It exists so Shinichi can decide handover
Step 1. It does **not** implement option (b), and must not be allowed to drift into it.

## GOAL (would become `LOOP/GOAL.md`)

Read this first, every cycle. Auto-compact eats messages, not this file. Unsure after a
compaction? Re-read THIS, then `LOOP/checkpoint.md`, then continue.

## Mission

Answer one question with citations, so Shinichi can decide drmSEM handover §6 Step 1:

> **Is there a published result that pairwise m-separation claims imply GLOBAL
> m-separation for a MAG — i.e. the completeness a basis set actually needs?**

`drm_dag_to_mag()` already works and is verified against Shipley & Douma's printed MAGs
(V-112/V-113/V-114). It is deliberately **not** wired into `basis_set()`/`dsep()` because
Richardson & Spirtes Cor. 5.3 proves each *pairwise* claim is sound (conditioning on
**anteriors**, not the parents S&D use), while **pairwise ⇒ global was never located**.

The deliverable is a **decision packet**: an addendum to `docs/design/14-m-separation.md`
that states what the literature does and does not license, with citations by
section/theorem, and a one-paragraph recommendation among:
(a) the completeness result exists — here it is;
(b) it does not appear to exist — implementing on Cor. 5.3 would cost X and carry gap Y;
(c) leave it.

## Headline

Find the theorem, or **prove honestly that it is not there**. A confident "not found" that
is really "my search missed it" is the failure mode this arc exists to avoid — which is why
adversarial verification is its own arc, not a step.

## Invariants (never violated, even after compaction)

1. **READ-ONLY with respect to package code.** No edits to `R/mag.R`, `R/dsep.R`,
   `R/model_set.R`, or anything under `R/`. No edits to `tests/`. The ONLY file this lane
   writes in the package is `docs/design/14-m-separation.md` (an appended addendum) plus
   the `LOOP/` kit.
2. **Do NOT implement option (b).** The handover forbids picking it silently. Producing the
   evidence for a decision is the job; making the decision is not.
3. **Cite by section/theorem, never by page** — Richardson & Spirtes is read via UW TR 375;
   Project Euclid is paywalled. A claim without a locatable citation is not a finding.
4. **A negative search result is not a finding** until a second, differently-shaped search
   agrees. State the query that returned nothing.
5. **NotebookLM self-citation guard**: exclude drmSEM's own vignettes/design docs from any
   corpus, or the sweep will cite us back to ourselves and report the idea already settled.
6. Treat every NotebookLM/web finding as **UNVERIFIED** until checked against the primary
   source. Mark it so in the addendum.
7. One lane only. Do not touch `main` in the parent checkout.

## Authoritative WHAT

`LOOP/ultra-plan.md` holds the binding detail. This file wins on "what must never be lost."

## Definition of done

`docs/design/14-m-separation.md` carries an addendum that a reader can act on:
- the exact proposition a basis set needs, stated formally;
- what R&S / Zhang / Ali-Richardson / successors do and do not prove about it;
- every claim cited by section or theorem, UNVERIFIED ones marked;
- a recommendation among (a)/(b)/(c) with its cost and residual gap;
- an explicit list of what was searched and what returned nothing.

**Then STOP.** Wiring anything into `basis_set()` is Shinichi's call, not this lane's.

---

## ARCS (would become LOOP/arcs.md)

Status: `TODO` / `DOING` / `DONE (verified: <how>)` / `BLOCKED`.
Dependency-ordered. Re-read `GOAL.md` before each.

---

## A1 — State the proposition, then assemble the corpus  ·  ~40 min  ·  TODO

**In:** `docs/design/14-m-separation.md`, `docs/memory/VALIDATION_LEDGER.md` (V-112…V-115b).
**Out:** `LOOP/notes/A1-proposition.md` — the exact formal statement a basis set needs, and
the corpus list with how each source is reachable.

Write the proposition FIRST, before reading anything new. A search for "the completeness
result" without a written target is how a near-miss theorem gets accepted. Name explicitly
what the conditioning set must be (anteriors vs parents) and where `∪ S` enters.

Corpus: Richardson & Spirtes *Ancestral Graph Markov Models* (UW TR 375); Zhang 2008 (on
completeness of FCI / augmented rules); Ali & Richardson (Markov equivalence of ancestral
graphs); Shipley & Douma; plus anything they cite forward for a global Markov property.

**Done when:** the proposition is written and every corpus item has a reachable route.
**Verify:** re-read the proposition against `14-m-separation.md`'s own "NOT implemented" note
— they must describe the same gap.

---

## A2 — Interrogate the corpus with narrow, cited questions  ·  ~70 min  ·  TODO

**In:** A1's proposition + corpus.  **Out:** `LOOP/notes/A2-findings.md`.

Run the `/notebook` loop (Ranga) over the corpus. Ask NARROW questions, one proposition at a
time — "does <source> state a global Markov property for MAGs, and under which conditioning
set?" — not "is there a completeness result?".

**Guard:** exclude drmSEM's own docs from the corpus (GOAL invariant 5).

**Done when:** each corpus item has a verdict: states it / states something weaker / silent.
**Verify:** every verdict carries a section or theorem number. No bare "yes".
**Risk branch:** if nothing is located by ~70 min, STOP searching and go to A3 with the
strongest available result — do not keep hunting. The honest negative IS a deliverable.

---

## A3 — Adversarially verify the near-misses  ·  ~35 min  ·  TODO

**In:** A2's findings.  **Out:** `LOOP/notes/A3-verdicts.md`.

For every candidate that looks like the result, try to REFUTE it. Default to refuted. The
specific trap already paid for once in this repo: S&D's printed rules drop R&S's `∪ S` and
coincide only when `S = ∅`. So for each candidate ask: what is the conditioning set, does it
cover selection, and does it hold for ALL pairs simultaneously or only pairwise?

**Done when:** each candidate is CONFIRMED or REFUTED with the reason.
**Verify:** read the primary source for any candidate still standing — a NotebookLM summary
is UNVERIFIED and cannot be the last word (GOAL invariant 6).

---

## A4 — Write the decision packet  ·  ~35 min  ·  TODO  ·  writes to the package

**In:** A1–A3.  **Out:** appended addendum in `docs/design/14-m-separation.md`.

State the proposition, the verdicts, the recommendation among (a)/(b)/(c) with cost and
residual gap, and — required — the list of what was searched that returned nothing.

**Done when:** a reader who knows nothing of this lane can act on it.
**Verify:** re-read against GOAL "Definition of done", item by item.

---

## GATES (loop STOPS here)

- **G1 — implementing anything.** Wiring MAG into `basis_set()`/`dsep()` is Shinichi's
  call. The loop never crosses this, whatever A3 concludes.
- **G2 — `git push`.** Denied by lane settings. Commit locally; surface for approval.
- **G3 — a genuine surprise that invalidates the plan** (e.g. the conversion in `R/mag.R`
  turns out to be wrong, not just incomplete). Stop, do not improvise, bring it back to G0.
