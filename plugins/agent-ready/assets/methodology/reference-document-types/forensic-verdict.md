# Forensic verdict

## Purpose

A short, evidence-backed determination of whether a feature, integration, or code path is live, dormant, or dead in production. Produced when the **forensic-first** adaptation is active for an area — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md). The verdict reshapes every subsequent severity decision in the area: if the path is dead, half the findings drop to nice-to-have; if it's live, recent near-misses become criticals retroactively.

The verdict's deeper value is **uncertainty management**. Without it, the audit either over-classifies dormant code (every PayPal-touching issue is critical) or under-classifies live code (the credential-mismatch was harmless, said the optimist; nobody checked the prod data). The verdict forces the auditor to ground the aliveness claim in concrete forensic fingerprints — and to enumerate, ahead of time, the ways the claim could be wrong.

## When it's produced

When the forensic-first adaptation is active. Triggers:

- A vendor integration whose Sentry breadcrumbs are conspicuously absent.
- A code path with credentials that have drifted from the production vendor console.
- A feature whose schema exists but whose business owner says they "do it out of band."
- A worker / cron / webhook whose execution evidence is sparse in logs.
- Code added by a previous developer whose intentions are no longer accessible.

## Template

The verdict has these sub-sections, in this order:

### Sub-section 1 — Verdict (one line)

A single sentence stating the conclusion: **"{X} is DEAD in production. Never exercised."** Or **"{X} is LIVE in production. Evidence A, B, C."** Or **"{X} status is INCONCLUSIVE. Here's what we'd need to determine it."**

Bold the verdict — it's the line every downstream severity decision will cite.

### Sub-section 2 — Evidence (table)

A row-per-forensic-fingerprint table. Columns:

| Forensic fingerprint | Prod result | Interpretation |
|---|---|---|

Each row is a specific query or check that would have left evidence in prod if the code path had executed. Five rows is a strong evidence base; three rows is minimal; two is shaky.

Examples of good forensic fingerprints (the pilot's PayPal verdict had all five):

- A column whose `IS NOT NULL` count reveals successful API calls (`paypal_invoice_id`).
- A row count for an audit-log entry the path would have created (`BookingStatusLog WHERE changed_by = 'paypal_webhook'`).
- A non-existent table that the audit confirms is non-existent (no parallel logging mechanism could have hidden activity).
- A timestamp pattern that would have existed if the path were exercised regularly (clustering of `paid_at` timestamps showing batch-backfill vs. organic activity).
- A cross-reference with a known time boundary (orders created before vs. after a credential-drift date).

### Sub-section 3 — Context numbers

The system's state in numbers, scoped to the period the audit covers. Provides the calibration anchor that grounds the verdict. The pilot's PayPal verdict included: total orders in the time window, status distribution, payment-method distribution, the batch-backfill pattern observation. These numbers let a reader spot-check the verdict.

### Sub-section 4 — Why X (the near-miss or the dormant pattern) was harmless

If the verdict is "dead," explain why a known near-miss didn't fire. The pilot's example: *"If anything in the admin flow had ever clicked 'create invoice,' the call would have hit PayPal OAuth with the wrong client secret → 401 → uncaught propagation → 5xx response to admin browser → Sentry capture. The total absence of Sentry noise for PayPal calls confirms the calls never happened."* The negative argument is part of the evidence.

### Sub-section 5 — Process clarification (where applicable)

If the verdict reveals an out-of-band operational pattern (the feature exists in code but is being done by humans via vendor consoles), document it. The pilot's example: *"Diego processes PayPal invoices directly through PayPal's admin console, bypassing the in-app integration entirely."* This is institutional knowledge the audit just made explicit.

### Sub-section 6 — Implications for severity calibration

State the rule the verdict implies for the rest of the area. The pilot's PayPal rule:

> PayPal-specific findings drop one rung if the bug only fires when the integration is live. They stay at the original severity if:
> - The bug class is broader than PayPal (e.g. shared with `mark_paid`, which IS exercised in production).
> - The bug is dormant only because of operational accident, not by design (the next deploy could activate it).
> - The bug guarantees a failure mode the moment the integration is turned on.

This is the calibration the agent applies to every subsequent finding in the area.

### Sub-section 7 — What changes if the verdict is wrong (risk register)

Enumerate the ways the conclusion could be wrong, with explicit elimination logic for each. Even if every path is eliminated, listing them out is what makes the verdict load-bearing instead of overconfident. The pilot's PayPal verdict listed three ways the conclusion could be wrong, each with the elimination logic:

1. A parallel record-keeping system exists. (Eliminated: no other audit tables exist.)
2. PayPal calls succeeded but DB writes failed. (Eliminated: writes happen immediately after successful API calls.)
3. Data was wiped or migrated. (Eliminated: magic-link history predates PayPal commit by 3 weeks; continuous data is preserved.)

State, in the final paragraph, what re-grading would be required if the verdict turned out wrong. This makes the verdict's risk register actionable.

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from a bookings/payments area report (full instance in the case study, `case-study/pilot/phase-1-area-2-report.md`):

```
## PayPal integration status

### Verdict: DEAD in production. Never exercised.

### Evidence

| Forensic fingerprint | Prod result | Interpretation |
|---|---|---|
| Order.paypal_invoice_id IS NOT NULL | 0 | Admin never successfully called create-invoice. |
| Order.paypal_invoice_url IS NOT NULL | 0 | Admin never successfully called send-invoice. |
| BookingStatusLog WHERE changed_by = 'paypal_webhook' | 0 | The webhook handler has never committed a transaction. |
| BookingStatusLog WHERE notes LIKE 'PayPal invoice%sent%' | 0 | The admin send-invoice path's log signature is absent. |
| Webhook-event audit table | does not exist | No parallel logging mechanism could have captured webhook activity invisibly. |

### The orders system in numbers (April 1 → May 10 2026)

- 14 orders total, all within the credential-drift window (March 10 → May 17).
- Status distribution: 12 PAID, 1 PENDING, 1 CANCELLED.
- Payment method distribution: 8 YAPPY, 3 CUANTO, 3 PAYPAL (customers selected these in checkout).
- All 12 PAID orders were marked paid by the admin in a single ~2-minute window on April 4, 2026 02:30–02:32 UTC — a backfill/cleanup session, not organic.
- 49 magic links spread across 14 orders (~3.5 per order) — likely a mix of customer + admin links plus admin re-issues.

### Why the credential mismatch was harmless

If anything in the admin flow had ever clicked "create invoice," the
call would have hit PayPal OAuth with the wrong client secret → 401 →
httpx.HTTPStatusError → uncaught propagation → 5xx response to admin
browser → Sentry capture. The total absence of Sentry noise for PayPal
calls confirms the calls never happened.

### Process clarification

Diego processes PayPal invoices directly through PayPal's admin console,
bypassing the in-app integration entirely. The 3 PAYPAL-marked PAID
orders represent customers who picked PayPal in checkout; Diego invoiced
them via PayPal's web UI and then admin-marked the order paid via mark_paid.

### Implications for severity calibration

PayPal-specific findings drop one rung if the bug only fires when the
integration is live. They stay at the original severity if:
- The bug class is broader than PayPal.
- The bug is dormant only because of operational accident, not by design.
- The bug guarantees a failure mode the moment the integration is turned on.

### What changes if the verdict is wrong

Three ways the conclusion could be wrong; none plausible given the evidence:

1. A parallel record-keeping system exists. No webhook-event tables exist
   in prod schema; the only audit table is booking_status_log which would
   have captured webhook activity. Eliminated.
2. PayPal calls succeeded but DB writes failed. The create/send flow
   always writes paypal_invoice_id immediately after a successful API
   call; you can't have zero paypal_invoice_id rows despite successful
   API calls. Eliminated.
3. The data was wiped/migrated. Magic-link history goes back to 2026-02-17
   (predates PayPal integration commit by 3 weeks), so continuous data
   is preserved. Eliminated.

If the verdict turns out wrong despite this evidence, every PayPal-related
severity needs re-grading.
```

## Pitfalls

- **Verdict without forensic fingerprints.** A verdict that says "I think it's dead" without three+ specific queries showing zero rows is not load-bearing. The verdict's value is its evidence; without evidence, it's an opinion.
- **No "what changes if wrong" register.** The risk register is what makes the verdict tractable as a basis for severity calibration. Without it, the verdict is overconfident or under-actionable.
- **Skipping the operational-pattern clarification.** The verdict often reveals an out-of-band human process that the codebase doesn't reflect (vendor consoles, manual exports, hidden cron jobs). Documenting this is part of the audit's value — institutional knowledge made explicit.
- **No severity-calibration implications.** The verdict's purpose is to reshape severity calibration. If the verdict's section doesn't end with the calibration rule, the area will not actually use the verdict.
- **One-fingerprint verdicts.** A single forensic fingerprint can be misleading (one query can be wrong). The audit needs corroborating evidence; the corroboration is what distinguishes a verdict from a guess.

## Cross-references

The forensic verdict is the deliverable a **forensic-first** adaptation produces — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md). The verdict is approved as part of the adaptation's Slot 10 approval gate, before the rest of the area's findings are filed.
