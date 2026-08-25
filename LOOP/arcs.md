# Arcs — MAG m-separation completeness (from arc doc / LOOP/ultra-plan.md)

Status vocabulary: `TODO` / `DOING` / `DONE (verified: <how>)` / `BLOCKED`.
Dependency-ordered. Re-read `LOOP/GOAL.md` before each.

| # | arc | status | gate? |
|---|-----|--------|-------|
| A1 | State the proposition, then assemble the corpus | **DONE** (verified: same gap as `docs/design/14-m-separation.md` "NOT implemented" / basis-set gate) | — |
| A2 | Interrogate the corpus with narrow, cited questions | **DONE** (verified: per-source verdicts with §/thm cites in `LOOP/notes/A2-findings.md`) | after G0 |
| A3 | Adversarially verify the near-misses | TODO | after A2 |
| A4 | Write the decision packet (addendum to `docs/design/14-m-separation.md`) | TODO | after A3 |

---

## A1 — State the proposition, then assemble the corpus  ·  ~40 min  ·  DONE

**In:** `docs/design/14-m-separation.md`, `docs/memory/VALIDATION_LEDGER.md` (V-112…V-115b).
**Out:** `LOOP/notes/A1-proposition.md` — formal statement a basis set needs + corpus with reachable routes.

**Done when:** proposition written; every corpus item has a reachable route.
**Verify:** re-read against `14-m-separation.md`'s "NOT implemented" note — same gap.
**Evidence:** `LOOP/notes/A1-proposition.md` §A1 verify — **SAME GAP** (2026-08-25).

---

## A2 — Interrogate the corpus with narrow, cited questions  ·  ~70 min  ·  DONE

**In:** A1's proposition + corpus.  **Out:** `LOOP/notes/A2-findings.md`.

**Done when:** each corpus item has a verdict: states it / states something weaker / silent.
**Verify:** every verdict carries a section or theorem number. No bare "yes".
**Evidence:** `LOOP/notes/A2-findings.md` — R&S silent on (P); S&L 2014 Thm 3 strongest hit;
Zhang/Ali/S&D weaker or silent; NotebookLM UNVERIFIED only.

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

- **G0 — plan approval.** Present kit + A1; wait before A2.
- **G1 — implementing anything.** Wiring MAG into `basis_set()`/`dsep()` is Shinichi's
  call. The loop never crosses this, whatever A3 concludes.
- **G2 — `git push`.** Denied by lane settings. Commit locally; surface for approval.
- **G3 — a genuine surprise that invalidates the plan** (e.g. the conversion in `R/mag.R`
  turns out to be wrong, not just incomplete). Stop, do not improvise, bring it back to G0.
