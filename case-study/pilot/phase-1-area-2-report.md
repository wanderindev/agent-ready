# Phase 1 — Area 2 Report: Payments, bookings, orders & PayPal webhook

**Date:** 2026-05-18
**Duration:** ~3 hours (split: ~45 min PayPal forensics, ~2 hours code audit, ~15 min report)
**Scope:** `backend/app/api/{orders,bookings,tours,webhooks,booking_admin}.py`, `backend/app/services/{paypal,availability,pricing,notifications}.py`, `backend/app/schemas/{order,booking,tour}.py`, the order/booking/tour models, and the frontend checkout flow (`frontend/src/pages/{Checkout,OrderConfirmation,BookingManage,BookingCancel,BookingRenewPayment}.jsx` plus `frontend/src/services/booking.js`).

---

## Executive summary

The payments/bookings code is functionally live for a low-volume Cuanto/Yappy/manual flow, but the PayPal integration is dead code in production — verified empirically via prod queries. The credential mismatch discovered in Phase 0 was not a near-miss; it was harmless because nothing was ever calling PayPal. Diego operates PayPal directly through PayPal's admin console, bypassing the in-app integration entirely.

That verdict reframes severity for the audit: PayPal-specific bugs that would have been "critical, fix immediately" if the integration were live drop to "critical, fix before re-enabling." But several bugs in the same code stay critical regardless of PayPal's status, because they affect either active code paths (admin-bound email injection from a public unauthenticated endpoint — F1/#31) or active code patterns (the same lock-less state mutation in `mark_paid` that's broken in the webhook handler).

The biggest non-PayPal finding is the swallowed-notification failure mode (#37): if the customer-confirmation email fails to send (Composio Gmail outage or address typo), the customer has no path to their booking — the order-confirmation page doesn't fetch or display the order (#36), and the magic-link token is only delivered via that email. This is the most likely class of failure in the current low-volume flow.

One real visible bug shipping today: every booking on the customer `/booking/manage` page renders as "Afternoon" / "Tarde" regardless of actual time slot (#35).

17 issues filed: 4 critical, 8 moderate, 5 nice-to-have. 3 agent-friendly. No stop-the-line fixes performed (F1 surfaced for explicit fix-vs-defer decision; user chose file-and-continue).

---

## By the numbers

| Metric | Count |
|---|---|
| Backend files audited | 13 (5 API routers, 4 services, 3 schemas, plus models on the side) |
| Frontend files audited | 6 (5 pages + 1 service module) |
| Prod queries run | 13 (5 batches, all aggregate-only, all explicitly approved) |
| Issues filed | 17 |
| — `code-quality:critical` | 4 (#31, #32, #33, #34) |
| — `code-quality:moderate` | 8 (#35, #36, #37, #38, #39, #40, #41, #42, #43 — 9; correction: 9) |
| — `code-quality:nice-to-have` | 4 (#44, #45, #46, #47) |
| — `agent-friendly` | 3 (#35, #44, #46) |
| Stop-the-line incidents | 0 (F1 surfaced; user opted file-and-continue) |

(Correction noted: moderate count is 9, not 8 as initially written — #35 through #43.)

---

## PayPal integration status

### Verdict: **DEAD in production. Never exercised.**

### Evidence

| Forensic fingerprint | Prod result | Interpretation |
|---|---|---|
| `Order.paypal_invoice_id IS NOT NULL` | **0** | Admin never successfully called `create-invoice`. The first PayPal API call on the happy path has never returned a real ID. |
| `Order.paypal_invoice_url IS NOT NULL` | **0** | Admin never successfully called `send-invoice`. |
| `BookingStatusLog WHERE changed_by = 'paypal_webhook'` | **0** | The webhook handler has never committed a transaction. |
| `BookingStatusLog WHERE notes LIKE 'PayPal invoice%sent%'` | **0** | The admin send-invoice path's log signature is absent. |
| Webhook-event audit table | **does not exist** | No parallel logging mechanism could have captured webhook activity invisibly. |

### The orders system in numbers (April 1 → May 10 2026)

- 14 orders total, all within the credential-drift window (March 10 → May 17).
- Status distribution: 12 PAID, 1 PENDING, 1 CANCELLED.
- Payment method distribution: 8 YAPPY, 3 CUANTO, 3 PAYPAL (customers selected these in checkout).
- All 12 PAID orders were marked paid by `jfeliu@aesa.biz` in a single ~2-minute window on **April 4, 2026 02:30–02:32 UTC** — a backfill/cleanup session, not organic. No `paid_at` timestamps after April 4 despite new orders arriving until May 10.
- 49 magic links spread across 14 orders (~3.5 per order) — likely a mix of customer + admin links plus admin re-issues.
- Of the 3 PAYPAL-payment-method orders: 2 are PAID, 1 is CANCELLED. None have `paypal_invoice_id` set.

### Why the credential mismatch was harmless

If anything in the admin flow had ever clicked "create invoice," the call would have hit PayPal OAuth with the wrong client secret → 401 → `httpx.HTTPStatusError` → uncaught propagation → 5xx response to admin browser → Sentry capture. The total absence of Sentry noise for PayPal calls confirms the calls never happened.

### Process clarification

Diego processes PayPal invoices directly through PayPal's admin console (out of band), bypassing the in-app integration entirely. The 3 PAYPAL-marked PAID orders represent customers who picked PayPal in checkout; Diego invoiced them via PayPal's web UI and then admin-marked the order paid via `mark_paid`.

### Implications for severity calibration

PayPal-specific findings drop one rung if the bug only fires when the integration is live. They stay at the original severity if:

- The bug class is broader than PayPal (e.g. F4's lock-less mutation pattern is shared by `mark_paid`, which is exercised in production).
- The bug is dormant only because of operational accident, not by design (F2's signature-fallback would activate the next time `PAYPAL_WEBHOOK_ID` is omitted from a deploy).
- The bug guarantees a failure mode the moment the integration is turned on (F3's async-loop in sync route).

### What changes if the verdict is wrong

Three ways the conclusion could be wrong; none plausible given the evidence:

1. **A parallel record-keeping system exists.** No webhook-event tables exist in prod schema; the only audit table is `booking_status_log` which would have captured webhook activity. Eliminated.
2. **PayPal calls succeeded but DB writes failed.** The create/send flow always writes `paypal_invoice_id` immediately after a successful API call; you can't have zero `paypal_invoice_id` rows despite successful API calls. Eliminated.
3. **The data was wiped/migrated.** Magic-link history goes back to 2026-02-17 (predates PayPal integration commit by 3 weeks), so continuous data is preserved. Eliminated.

If the verdict turns out wrong despite this evidence, every PayPal-related severity needs re-grading — F2 becomes immediate-action, F3 becomes a live bug (probably the cause of any "PayPal sometimes fails" reports), F4 becomes a recently-active state-machine concern requiring data audit.

---

## What was audited

### Backend

- `backend/app/api/orders.py` (508 lines) — full read. Customer-facing order create/get/cancel/renew + magic-link validation.
- `backend/app/api/bookings.py` (96 lines) — full read. Price calc + availability check (public).
- `backend/app/api/tours.py` (156 lines) — full read. Looked for `AttributeError` siblings to the Phase 0 `tours.py` bug; none found.
- `backend/app/api/webhooks.py` (155 lines) — full read. PayPal webhook receipt + dispatch.
- `backend/app/api/booking_admin.py` (766 lines) — full read with PayPal/order/payment focus; non-payment admin routes (calendar view, stats) scanned only for patterns matching the audit themes.
- `backend/app/services/paypal.py` (253 lines) — full read.
- `backend/app/services/availability.py` (237 lines) — full read.
- `backend/app/services/pricing.py` (388 lines) — full read.
- `backend/app/services/notifications.py` (453 lines) — full read (focused on payment-flow notifications; admin/educator notifications skimmed).
- `backend/app/schemas/{order,booking,tour}.py` — full read.
- `backend/app/models/{order,booking,tour}.py` — full read (filled gaps in models not covered by Area 1's pass).
- `backend/tests/test_orders.py` (265 lines) — full read for coverage inventory.

### Prod inspection

13 queries across 5 batches via `source .env.prod-readonly && psql "$DATABASE_URL" -c '...'`. All aggregate-only (counts, min/max dates, group-bys). No PII rows pulled. Each batch explicitly approved before execution. The `.env.prod-readonly` credentials were stale on first attempt — user refreshed the file mid-session.

### Frontend

- `frontend/src/pages/Checkout.jsx` (363 lines) — full read.
- `frontend/src/pages/OrderConfirmation.jsx` (86 lines) — full read.
- `frontend/src/pages/BookingManage.jsx` (251 lines) — full read.
- `frontend/src/pages/BookingCancel.jsx` (167 lines) — full read.
- `frontend/src/pages/BookingRenewPayment.jsx` (167 lines) — full read.
- `frontend/src/services/booking.js` (235 lines) — full read.
- i18n keys `booking.modal.morning` / `booking.modal.afternoon` cross-checked against `frontend/public/locales/{en,es}/translation.json` to confirm the time-slot display bug (#35).

### Out of scope (and stayed that way)

- `backend/app/api/dashboard.py` (1,736 lines) — adjacent; skimmed via grep for payment touchpoints, none load-bearing. Area 4 (services) or Area 6 (admin CMS) territory.
- `backend/app/api/{auth,admin,educators}.py` — Area 3.
- `backend/app/services/composio_client.py` — Area 4.
- The admin UI for invoice management — Area 6.

---

## Item-by-item findings

### Issues filed

| # | Title | Severity | Agent-friendly |
|---|---|---|---|
| #31 | HTML injection in notification emails | critical | no |
| #32 | PayPal webhook signature verification falls open when `PAYPAL_WEBHOOK_ID` is unset | critical | no |
| #33 | PayPal webhook handler creates asyncio event loop inside sync route | critical | no |
| #34 | PayPal webhook handler has no row-level lock or idempotency key | critical | no |
| #35 | BookingManage.jsx renders every booking as "Afternoon" | moderate | yes |
| #36 | OrderConfirmation page doesn't fetch or display order details | moderate | no |
| #37 | Email/notification dispatch failures silently swallowed in payment flow | moderate | no |
| #38 | `renew_payment_link` endpoint promises automation that doesn't exist | moderate | no |
| #39 | `Order.subtotal` always equals `Order.grand_total` — no order-level discount accumulator | moderate | no |
| #40 | Availability check has no row-level lock — double-booking race | moderate | no |
| #41 | PayPal admin endpoints have inconsistent transactional boundaries | moderate | no |
| #42 | No test coverage for webhook, admin booking endpoints, or non-create order endpoints | moderate | no |
| #43 | Magic-link tokens passed in URL query strings | moderate | no |
| #44 | PayPal dead-code cleanup: unused `webhook_id` parameter + unused `OrderStatus.PARTIALLY_PAID` | nice-to-have | yes |
| #45 | `AttractionListItem` schema omits `ticket_infant_*` fields but pricing engine charges for them | nice-to-have | no |
| #46 | DRY cleanups: duplicate availability query, hardcoded 48-hour `payment_link_expires_at` | nice-to-have | yes |
| #47 | OrderConfirmation Meta Pixel `Purchase` event fires with hardcoded `value: 0` | nice-to-have | no |

### Stop-the-line discussion

F1 (filed as #31) was surfaced for explicit fix-vs-defer decision. The exploit: an attacker POSTs an order with HTML-injected `customer_name`, Diego receives a legitimate-looking "new order" email in Gmail, the embedded HTML renders as a phishing link from a trusted source. User chose file-and-continue; the vulnerability remains live until #31 is addressed.

### Comments / cross-references added

- #36 references #37 (compound risk: failed email + no in-page recovery).
- #37 references backlog #8 (broader swallowed-exceptions sweep — this is the payment-flow-specific subset).
- #41 references #31-#34 (coordinated PayPal-hardening pass).
- #42 references backlog #13 (pytest-cov coverage baseline).
- #47 references #36 (depends on it for the page having order data).
- The four critical PayPal findings cross-reference each other and the PayPal-status section of this report.

---

## What's filed vs. what's deferred

### Filed (this session)
17 issues, listed above.

### Deferred / not filed

- **`paypal_invoice_id` uniqueness constraint.** `Order.paypal_invoice_id` has no UNIQUE constraint. Two orders with the same PayPal invoice ID would both be updated by the webhook handler's `.first()` query. Today: impossible because nothing creates invoices. Bundled implicitly under #34's scope.
- **Order/booking status transition state machine.** No formal state machine exists — transitions are enforced by ad-hoc `if order.status in [...]` checks in each endpoint. This is convention, not constraint. Cross-cutting with `code-quality:moderate` Area 1 finding #24 (unify status-column implementation). Not pulled out as its own finding because the fix path overlaps with #24.
- **Refund flow.** No automated refund path exists — refunds are entirely manual in PayPal's admin console. By design today (PayPal integration dead). Worth a separate issue if/when PayPal is turned on.
- **Followup email scheduler.** `notify_payment_received` and `notify_order_cancelled` exist as service methods. `request_followup_email` also exists but is **never called** from any audited code. The `Order.followup_1_sent_at` / `followup_2_sent_at` / `followup_3_sent_at` columns suggest a scheduled job is intended but no scheduler is wired up. Listed as a deferred finding — Area 4 territory once we audit `backend/app/services/`.
- **`order.payment_method` enum validation.** I initially worried this was unvalidated; confirmed enforced by `CreateOrderRequest`'s `pattern="^(PAYPAL|CUANTO|YAPPY)$"` in `backend/app/schemas/order.py:25`. Not a finding.
- **Customer phone format mismatch.** Backend allows 5–50 chars (`backend/app/schemas/order.py:16`); frontend regex requires 7–20. Minor inconsistency; not worth a separate issue.

---

## Newly observed — for other audit areas

Items I noticed during this audit that don't belong in Area 2, in the order I expect they'll surface again:

- **Area 3 (Auth/educator gate):**
  - `MagicLinkAction.VIEW_ORDER` and `MagicLinkAction.ADMIN_LOGIN` exist (per `orders.py` imports). The customer's view-order magic link is 30-day validity; admin magic link is 24-hour. Reasonable per use case, but #43 flags both for query-string-leak risk. Worth checking during Area 3 whether the educator-access 7-day flow uses the same magic-link infrastructure or its own.
  - `_validate_magic_link` (orders.py:45-63) does NOT mark the magic link as used on `renew_payment_link` (only on `cancel_order`). For an action that customers can spam (and that produces side effects on the PayPal-side state), repeated calls are tolerated. Probably fine but worth a thought.
  - `magic_link.admin_email` is accessed throughout `booking_admin.py` as `changed_by` for audit logs (e.g. line 197, 248). The actual model field name should be verified against `MagicLink` model — Area 3 covers this surface.

- **Area 4 (Services / pipelines):**
  - `NotificationService` is the most fragile component on the critical path. The HTML f-string templates (basis for #31) should be migrated to Jinja2 wholesale during Area 4. Once that's done, all 4 `notify_*` methods become consistent.
  - `request_followup_email` exists but is never called. Confirms a scheduled-job gap. Look for the missing scheduler during Area 4.
  - `composio_client.send_email` is the boundary that swallows actual Gmail API errors. #37 captures the upstream sites; the downstream wrapper deserves its own audit during Area 4 to check whether Composio failures even raise back to the caller, or whether they're caught further down.
  - The `paypal_service.cancel_invoice` call in `orders.py:495-498` swallows exceptions with `except Exception: pass # Old invoice may already be cancelled`. Specifically the "pass" without logging is worse than the "log but swallow" pattern in #37. Worth surfacing during Area 4's swallowed-exceptions sweep (#8).

- **Area 5 (Frontend public):**
  - `useCart` from `CartContext` — Checkout.jsx imports it but the context implementation wasn't read. Cart persistence (localStorage? sessionStorage?) is part of the customer's order recovery story; worth checking during Area 5.
  - Meta Pixel events fire from multiple pages (Checkout `InitiateCheckout`, OrderConfirmation `Schedule` + `Purchase`). #47 covers the value=0 issue. Whether the Pixel ID is hardcoded or env-driven, and whether it should fire at all in development environments, are Area 5 questions.
  - `Sentry.withErrorBoundary` wraps `Checkout` and `OrderConfirmation`. The error fallback for Checkout says "your cart is saved" — accurate IF cart persistence works. Area 5 should verify.
  - `frontend/public/locales/{en,es}/translation.json` shape — should be sanity-checked for missing keys during Area 5, especially after #35 surfaces.

- **Area 6 (Frontend admin):**
  - All `booking_admin.py` admin endpoints have a corresponding frontend service method (`bookingService.markPaid`, `bookingService.createInvoice`, etc. in `frontend/src/services/booking.js`). The admin UI for these wasn't audited — Area 6. Confirms PayPal admin flow is implemented frontend-side; just unused.
  - `frontend/src/pages/admin/` directory exists; not opened during this audit. Likely contains the invoice management UI.

- **Cross-area:**
  - The `pricing_config` table is used for tunable parameters (`base_fee`, `senior_discount_percent`, `reservation_validity_days`). #46 proposes adding `payment_link_validity_hours`. The pattern is good; worth standardizing during Area 4 or as part of #24's status-column work.

---

## What surprised me

1. **The forensic verdict was crisper than expected.** Going in, I expected "probably dead, can't fully rule out a parallel path." The data was decisive — zero rows on every PayPal fingerprint, in a system where the orders system itself is clearly active. That makes the verdict load-bearing rather than provisional.

2. **The PayPal integration is high-quality dead code.** It's not a hack-it-together stub — it's a coherent implementation of PayPal Invoicing API v2 with OAuth caching, signature verification, draft/send/cancel/status flows, reschedule handling, and frontend admin UI. Someone spent real time building it. It just was never adopted operationally because Diego's preexisting PayPal-console workflow worked fine. The cost of the dead code is mostly its size + the bugs in it that nobody noticed.

3. **The HTML-injection in admin emails is the most active risk in the area.** It's a public unauthenticated endpoint → admin inbox. Even with the integration dead, this one fires today. Severity calibration here was straightforward; what was surprising was that no other auditor had caught it earlier — the f-string pattern is right there in the source.

4. **The `BookingManage.jsx` time-slot bug affects 100% of orders.** Diego sees this every time he opens his admin tools (or any customer who clicks their email magic link). Yet no one noticed enough to file it. Plausible explanation: customer manage pages are rarely opened, and Diego uses his own admin views which display `time_slot` directly as "AM"/"PM" rather than translating it. The bug is invisible to the person operating the system.

5. **The async-loop-in-sync-route pattern (`webhooks.py:38-42`) is the kind of bug that survives until production load reveals it.** If PayPal were live, this would either work intermittently (depending on Starlette internals) or fail in ways that look like generic 500s. The whole webhook handler should have been `async def` from the start — there's no reason for it to be sync.

6. **Test coverage is dramatically lower in payments than I expected.** Area 1 surfaced a generally-healthy data layer with low test coverage but a coherent codebase. Area 2 has high-quality code with essentially zero test coverage of the most critical paths. Filed as #42 but it's also a calibration signal for the rest of the audit: the test-coverage situation may be worse than headlines suggest in other domains too.

7. **`OrderConfirmation.jsx` doing nothing is the saddest discovery.** It's a one-screen file that just shows static text + a reference. Combined with the magic-link token not being in the API response, the customer is genuinely stranded if email fails. This is a one-PR fix that meaningfully improves recovery, but it's not been done.

---

## Process notes for the next area

- **Forensic-first was the right call.** Spending 45 minutes establishing the PayPal dead-code verdict made every subsequent severity decision faster and more defensible. Area 3 doesn't have an analogous "is this thing alive" question, but Area 4 (services) might — multiple service modules may be live, dormant, or experimental. Worth a brief usage-data check before the per-service code audit.

- **Prod queries via direct `psql + .env.prod-readonly` worked once credentials were refreshed.** The user fixed the credential file mid-session in under a minute. For Area 3 (educator gate, auth) the same pattern should work; the gating is "explicit approval per batch" which fits the per-area sensitivity.

- **Batch-and-confirm with 4-5 findings per batch worked.** Stayed inside the cognitive grain that produced clean approvals on every batch.

- **Bundling related nice-to-haves was the right call to keep the issue count manageable.** F14 bundled two PayPal dead-code cleanups; F16 bundled two DRY tweaks. Total filed: 17, well inside the 25 ceiling. Without bundling I'd have had 19, still acceptable but noisier.

- **Cross-references between issues were valuable.** #36/#37 compound, #41 ties to the PayPal-hardening cluster, #47 depends on #36. Future Area 3+ should keep using `#N` references inline since the agent picking up the fix needs the connection.

- **One additional verification habit:** for any UI-bug claim, I cross-checked the i18n keys / model fields to confirm the bug actually fires. For #35 specifically, the comparison-against-`'morning'` claim is only a bug if the i18n keys exist and the backend really returns `'AM'/'PM'`. Both confirmed before filing. This added ~2 minutes per finding but caught one potential false positive (the `child_under_5` infant pricing concern, where I initially worried about a charge mismatch and confirmed via grep that today's infant prices are zero — kept as a nice-to-have at #45 with a "would bump if non-zero" caveat).

- **Recommended order for Area 3:** auth → magic-link infrastructure → educator gate → admin gate. The magic-link infrastructure is shared between customer order management (audited here) and admin auth (referenced but not deeply audited). The 30-day customer token (#43) and 24-hour admin token coexist on the same `magic_links` table.
