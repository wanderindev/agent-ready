We're starting Phase 1 Part B Area 2: Payments, bookings, orders & PayPal webhook.

The audit plan at docs/pilot/phase-1-audit-plan.md remains the authoritative
scope document. Read it again if context has rolled, plus the Area 1 report
at docs/pilot/phase-1-area-1-report.md — it contains specific findings
seeded for this area in the "Newly observed" section. Treat those as
known inputs to verify, not as findings to rediscover.

## Why this area matters

This is the highest-financial-blast-radius area in the codebase. A bug
here is a duplicate charge, a lost booking, a webhook idempotency failure,
or an unreconciled payment. Audit thoroughness here is worth more than
in any other area.

The Phase 0 work also fixed a real production bug in `tours.py` (the
`ticket_child_*` AttributeError) and found that the PayPal credential in
`docker-compose.prod.yml` did not match the PayPal account console. The
absent Sentry noise from that mismatch is strong signal that either
the integration never ran in real bookings, or it silently swallowed
every failure. **Approach the PayPal portion of this audit assuming
the integration may be dead code.** Verify before assuming anything works.

## Scope

In-scope files (read all in full):
- `backend/app/api/tours.py`, `bookings.py`, `orders.py`, `webhooks.py`
- `backend/app/services/` — anything payment, booking, order, or PayPal
  related (likely `paypal_*.py`, `booking_service.py`, `order_service.py`,
  but locate by reading rather than guessing)
- `backend/app/schemas/` — the Pydantic schemas for the above
- The PayPal webhook handler specifically, including signature
  verification, idempotency, and replay protection
- The order state machine (statuses, transitions, terminal states)
- Frontend checkout flow (`frontend/src/` — pages and components in the
  checkout path)

Out of scope (note in "newly observed" if interesting):
- Auth and educator-gate code (Area 3)
- Non-payment service modules (Area 4)
- Public-site code outside the checkout flow (Area 5)
- Admin CMS (Area 6)

## Forensic question: is PayPal integration alive?

This is the single most important question this audit answers, and it
needs to be answered before any of the other findings can be properly
prioritized. If the integration is dead, half the issues filed for the
PayPal code path are moot; if it's live, the credential mismatch was a
near-miss.

To answer it, you need to inspect production. Read the next section
on prod access before attempting anything.

The investigation:
1. Read the PayPal integration code first. Map every code path that
   should touch a real PayPal API — order creation, capture, webhook
   receipt, refund.
2. Check for any logging, Sentry breadcrumbs, or audit-log writes that
   would leave evidence in prod if the path executed.
3. Query prod (via the gated method below) for: orders with `status =
   'paid'` or equivalent, any rows in a webhook-event audit table if
   one exists, recent rows in `BookingStatusLog`, payment-method
   distribution across orders, the date range of orders that have
   a non-null `paypal_*` column.
4. Cross-reference with the credential-mismatch finding: orders
   created BEFORE the credentials drifted vs. orders created AFTER.
   The dividing date is in the Phase 0 report (credentials were
   committed 2025-12-22; mismatch was discovered during Phase 0
   on 2026-05-17).
5. Report a clear conclusion: "PayPal integration appears live, with
   evidence X, Y, Z" or "PayPal integration appears dead/never-used,
   with evidence X, Y, Z" or "Inconclusive — here's what we'd need
   to determine it."

The conclusion goes into the Area 2 report and shapes the agent-friendly
classification of every PayPal-related issue you file. If it's dead code,
most findings drop to nice-to-have. If it's live, the credential mismatch
itself becomes a critical retroactive finding.

## Production data access

Area 1 hit the auto-mode classifier denying `psql` against the prod URL.
For this area we're going to handle prod access differently:

**Option chosen for Area 2:** Surface for explicit approval at the top of
the session. Before running any prod query, propose the exact command
you want to run, what data it will return, and why you need it. I'll
approve or reject each one. This is slower than auto-approval but gives
me a clear audit trail of every prod read this session performs, which
matters more here than anywhere else given the financial-data sensitivity.

Use the `.env.prod-readonly` source pattern from Phase 0 — that file is
gitignored and chmod 600 on my droplet; sourcing it into the session
gives you DATABASE_URL but no write credentials. If a query needs more
than read access, stop and tell me — we don't have a path for that.

**Specifically do not:**
- Query PII tables (`bookings`, `contact_submissions`, `educators`,
  `users`) for actual row data. Aggregates are fine — `SELECT COUNT(*),
  MIN(created_at), MAX(created_at) FROM bookings WHERE status = ...`
  is fine. `SELECT * FROM bookings LIMIT 5` is not.
- Pull any payment amounts at the individual-row level. Sums and
  counts only.
- Touch any PayPal API endpoint, even sandbox. We're auditing code,
  not making test calls.

## Things to look for (beyond the PayPal forensic question)

**Order state machine**
- Are all status transitions enforced somewhere (service layer, DB
  constraint, or both)? If service-layer only, are there gaps where
  a status could be set directly?
- Terminal states: once an order is `refunded` or `cancelled`, can it
  transition back? Should it be able to?
- Concurrency: two webhooks for the same order arriving simultaneously —
  is there row-level locking, an idempotency key, a unique constraint?

**Webhook handling**
- PayPal signature verification: is it actually performed, or is the
  endpoint accepting unsigned requests?
- Idempotency: if PayPal retries a webhook (it will), does the second
  delivery produce a duplicate side effect or get safely no-op'd?
- Replay window: is there protection against an old captured webhook
  being resubmitted?
- Error handling: a webhook that fails — does it return a 5xx so PayPal
  retries, or a 2xx that drops the event?

**Booking ↔ Order ↔ Payment reconciliation**
- The newly-observed item from Area 1: `Order.subtotal` and
  `Order.grand_total` exist, but discount lives on `Booking`. Walk
  through the math — does it reconcile when an order has multiple
  bookings with different senior-discount totals?
- `Order.payment_method` is plain `String(20)` (per #24) — what values
  does the service layer actually insert? Is there an unenumerated
  list of valid values somewhere, or is it free-form?
- Refunds: are partial refunds supported? If yes, how does the
  reconciliation work?

**Public-API contract for bookings**
- `tours.py` had a production bug Phase 0 caught. Look hard at any
  other endpoint serializing model fields — is there a similar
  `AttributeError` waiting to happen?
- Any endpoint that takes user input and uses it in a query without
  proper validation? Especially anything constructing filter clauses
  from query params.

**Frontend checkout flow**
- Is there client-side computation of totals that the backend doesn't
  re-verify? (Classic vulnerability — never trust the client's price.)
- Sentry breadcrumbs on the checkout path: would a failed payment leave
  a clear trail in the frontend Sentry project, or would it surface as
  a generic error?
- The three pages with `Sentry.withErrorBoundary` per Phase 0 (Checkout,
  OrderConfirmation, Contact) — are those boundaries sufficient, or
  would a checkout failure leak past them?

## Working style

- **Batch-and-confirm**, same as previous sessions.
- **Severity calibration is stricter here.** A bug in the order state
  machine that could double-charge is `code-quality:critical` even if
  the PayPal integration is dead today (because the same machinery may
  be wired to something live later). A missing webhook signature check
  is `code-quality:critical` regardless of whether the path is live.
  An unenumerated `payment_method` string is `code-quality:moderate`.
  An ungainly variable name in `orders.py` is `code-quality:nice-to-have`.
- **Agent-friendly is rarer here.** Anything touching payment math,
  state machines, webhook handling, or schema changes is NOT
  agent-friendly. Mostly only cosmetic or doc-only issues in this
  area will qualify.
- **Stop-the-line:** If you find an active vulnerability — unsigned
  webhook endpoint accepting writes, SQL injection in a public endpoint,
  a path where a client can manipulate price server-side, an order
  status that can be flipped without auth — surface immediately. We
  fix inline before continuing the audit.

## End-of-session report

Save as `docs/pilot/phase-1-area-2-report.md`. Same shape as Area 1:
executive summary, by-the-numbers, what was audited, item-by-item
findings, what's filed vs deferred, newly observed for other areas,
what surprised you, process notes for the next area.

**One additional required section for this report:** "PayPal integration
status." A clear conclusion (alive / dead / inconclusive), the evidence
behind it, and what changes if the conclusion is wrong. This becomes a
reference point for every future payment-related decision on this
project.

## Scope estimate

This is bigger than Area 1. Expect 2-3 hours of focused work and
10-15 issues filed. If you're approaching 25+ findings, something is
wrong — either the codebase has more rot in this area than expected
(surface and we'll regroup) or you've drifted into Area 3 or 4
territory.

Begin by:
1. Reading the audit plan, the Area 1 report (especially the "Newly
   observed for Area 2" subsection), and the Phase 0 report's
   payment-relevant findings (the `tours.py` bug, the credential
   mismatch).
2. Mapping out the PayPal forensic investigation as a concrete plan:
   what code reads, what prod queries (with the gating pattern above),
   what conclusion criteria.
3. Proposing a session structure to me — probably "forensic first,
   then code audit" rather than interleaved, because the forensic
   conclusion shapes the severity of subsequent findings.

Wait for my approval on the plan before starting any prod queries.
