# Arcs — MAG m-separation completeness (from arc doc / LOOP/ultra-plan.md)

Status vocabulary: `TODO` / `DOING` / `DONE (verified: <how>)` / `BLOCKED`.
Dependency-ordered. Re-read `LOOP/GOAL.md` before each.

| # | arc | status | gate? |
|---|-----|--------|-------|
| A1 | State the proposition, then assemble the corpus | **DONE** (verified: same gap as `docs/design/14-m-separation.md` "NOT implemented" / basis-set gate) | — |
| A2 | Interrogate the corpus with narrow, cited questions | **DONE** (verified: per-source verdicts with §/thm cites; G0 leads S&L 2014 + L&S 2018 primary-checked) | after G0 |
| A3 | Adversarially verify the near-misses | **DONE** (verified: C1/C2 CONFIRMED for abstract (P) under compositional graphoid; REFUTED as unconditional drmSEM wire; near-misses REFUTED) | after A2 |
| A4 | Write the decision packet (addendum to `docs/design/14-m-separation.md`) | **DONE** (verified: GOAL definition-of-done checklist below) | after A3 |

---

## A1 — State the proposition, then assemble the corpus  ·  ~40 min  ·  DONE

**Evidence:** `LOOP/notes/A1-proposition.md` §A1 verify — **SAME GAP** (2026-08-25). Corpus rows 6–7 added at G0 (S&L 2014, L&S 2018).

---

## A2 — Interrogate the corpus with narrow, cited questions  ·  ~70 min  ·  DONE

**Evidence:** `LOOP/notes/A2-findings.md` — R&S silent on (P); S&L 2014 Thm 3 + L&S 2018 Thm 4 strongest hits (primary); Zhang/Ali/S&D weaker or silent.

---

## A3 — Adversarially verify the near-misses  ·  ~35 min  ·  DONE

**Evidence:** `LOOP/notes/A3-verdicts.md` — conditioning set MATCH Cor. 5.3; compositionality residual for drmSEM; S&D parents REFUTED.

---

## A4 — Write the decision packet  ·  ~35 min  ·  DONE  ·  writes to the package

**Out:** addendum in `docs/design/14-m-separation.md` (heading “Addendum — m-separation completeness decision packet”).

**GOAL definition of done (verified item-by-item):**
- [x] exact proposition a basis set needs, stated formally
- [x] what R&S / Zhang / Ali / S&D / S&L / L&S do and do not prove
- [x] every claim cited by section/theorem; UNVERIFIED marked where applicable
- [x] recommendation among (a)/(b)/(c) with cost and residual gap → **(a)** + gap Y
- [x] explicit list of searches that returned nothing
- [x] STOP — no wire into `basis_set()` / `dsep()`


---

## GATES (loop STOPS here)

- **G0 — plan approval.** Approved 2026-08-25.
- **G1 — implementing anything.** Wiring MAG into `basis_set()`/`dsep()` is Shinichi's
  call. The loop never crosses this, whatever A3 concludes.
- **G2 — `git push`.** Denied by lane settings. Commit locally; surface for approval.
- **G3 — a genuine surprise that invalidates the plan** (e.g. the conversion in `R/mag.R`
  turns out to be wrong, not just incomplete). Stop, do not improvise, bring it back to G0.
