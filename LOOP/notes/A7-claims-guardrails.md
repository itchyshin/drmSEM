# A7 — Claims guardrails (lognormal and later families)

**Auditor.** Rose, 2026-08-27. Read-only check + this note.
**Pinned.** drmSEM `main` @ `0cb3360` (S6 row already names Gamma
V-122). G2 in
`docs/memory/PLAN-ACTUAL-2026-08-27-s6-imputation.md`: **keep
`partial`**. D-22 honest limits unchanged. No capability-flip PR.

A public capability row is a sentence about leftovers, not a reward
for shipping the next honest cell. Lognormal + consumer does not
reopen G2.

---

## S6 at `0cb3360` (do not promote)

`docs/design/capability-status.md` row **Imputation models derived
from the causal graph** is **`partial`**.

Shipped cells named there: two independent Gaussian parents
(#1086); Gamma × one Bernoulli (`#1088` `6e553879`, V-122).

**Does not cover — and these are why it stays `partial`:**

- piecewise re-estimation is **not** FIML across the SEM
- uncertainty is within-node only, not across nodes
- `k > 2` still aborts
- non-Gaussian response × two incomplete parents still aborts
- non-Gaussian responses admit only a **binary** missing predictor
- responses outside the allow-list still abort
- measured claim is “recovers the intercept and reduces
  mediator-coefficient bias”, **not** “beats complete-case”

After lognormal (and every later family) those leftovers still
exist. Adding one name to the allow-list does not retire them.

---

## Forbidden phrases

Do not write any of these as a drmSEM claim, NEWS closer, PR title,
or capability-status edit:

| Forbidden | Why |
|---|---|
| `FIML` / “full-information” / “FIML-like” / “joint SEM likelihood” | Piecewise re-estimation. Charter + D-22 + G2. |
| S6 status `"covered"` / “now covered” / “missing-data covered” | G2 resolved keep `partial` (A12). One family is not the leftover list. |
| “general missing-data SEM” / “missing-data SEM is done” | Cell-by-cell emit, not a missing-data SEM. |
| “beats complete-case” | V-78 is narrower; sometimes worse on `x`. |
| `impute_joint` as the SEM emit | Option (b) only: one independent `impute_model()` per parent. |
| “cross-node uncertainty” as shipped | Within-node Hessian only. |

Naming FIML in a **negation** is required, not forbidden:
“this is not FIML” must stay.

---

## Allowed NEWS one-liner (per family)

Append **one named cell** to the existing Missing-data bullet.
Do not replace the Gamma / two-parent sentences. Do not drop the
closer.

Template:

```text
A **<Family>** response with one <Predictor> parent also emits
(drmTMB #<n>, `mp-<resp>-<pred>`, V-nnn).
```

Then the closer **must** still say, in this order:

1. leftover `k` / leftover families still fail loud
2. “This is not a general missing-data SEM and not FIML.”

Worked lognormal slot (fill sha / V-number only after identity +
MAR exist):

```text
A **lognormal** response with one Bernoulli parent also emits
(drmTMB #<n>, `mp-lognormal-bernoulli`, V-nnn). `k > 2`, a
non-Gaussian `k = 2`, and leftover families (student, …) still
fail loud. This is not a general missing-data SEM and not FIML.
```

Do **not** write “lognormal missing-data is covered”.
Do **not** move lognormal off the leftover list in
`13-missing-data.md` until C++ `has_mi` + consumer identity + MAR
are all landed. Do **not** leave “lognormal (no `has_mi`) still
fails loud” after it lands (that is the opposite lie).

---

## When capability can STILL not flip to `covered`

It cannot flip while **any** of these are true — and they remain
true after lognormal + consumer:

1. The SEM is piecewise (re-estimates the parent inside `y`).
2. Any response family still lacks C++ `has_mi`.
3. `k > 2` still aborts.
4. Non-Gaussian `k = 2` still aborts.
5. Incomplete exogenous predictors still go to `na_action`.
6. The measured claim is still not “beats complete-case”.

G2 already decided this. A later family **repeats** A7c-2–A7c-6.
It does not reopen the capability sentence.

---

## The 5 hard rules

1. **S6 stays `partial`.** No capability-status flip in the
   lognormal PR or any later family PR.
2. **Never claim FIML.** Within-node only. Keep the negation.
3. **Never claim a general missing-data SEM.** Name the cell.
4. **NEWS is one cell + leftovers + the closer.** Not a promotion.
5. **Fail-loud leftovers stay named.** `k > 2`, non-Gaussian
   `k = 2`, unwired families, exogenous → `na_action`. Widening a
   list to silence a leftover is the #962 failure mode.

V-80 stays the anti-drift lock. Do not skip it to land a PR.
