# Worked examples (from the pilot)

These are **examples from the pilot codebase** — real fills for the per-area-irreducible slots, lifted from the pilot's audit corpus. They are calibration anchors, not content to carry into your own audit. The methodology-install skill helps an operator replace each `PIC-WORKED-EXAMPLE` block below with the equivalent grounded in *their* repo's domain. Keep the *shape* of each example (concrete, behavior-based, area-grounded); swap the *content* for your codebase's.

Why these examples ship at all: the same point the methodology makes about severity calibration applies to the skill's documentation. Abstract rubrics underperform domain-grounded examples. A new operator reading "list critical / moderate / nice-to-have examples grounded in the area" without seeing what that looks like in practice will produce a thinner fill than one who has seen what good calibration depth looks like. One example per slot is included, chosen to show the calibration depth a good fill needs.

All examples below are tagged `PIC-WORKED-EXAMPLE` so the methodology-install skill (and any later sanitization pass) can find and substitute them. (Full instances of each live in the case study.)

---

## Slot 3 — "Why this area matters" (blast-radius framing)

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> This is the highest-financial-blast-radius area in the codebase. A bug here is a duplicate charge, a lost booking, a webhook idempotency failure, or an unreconciled payment. Audit thoroughness here is worth more than in any other area.

### PIC-WORKED-EXAMPLE: Area 3 (Auth)

> Narrow surface, high blast radius. Auth bugs are how unauthorized parties get access to data or actions they shouldn't. The educator access system is newer code — newer means less battle-tested. The 7-day access window logic and the 6-digit re-verification flow are exactly the kind of code where small bugs have outsized consequences.

### PIC-WORKED-EXAMPLE: Area 5 (Frontend public)

> Three differences from the services-layer audits:
> 1. Failure modes are user-visible, not data-corruption-shaped. A broken component renders wrong, breaks the layout, or fails to handle an error. The blast radius is one user's session, not the database.
> 2. The cost surface is bundle size, accessibility, and i18n correctness rather than token spend or vendor outage.
> 3. Per-finding stakes are typically lower because there's no production data to corrupt.

Notice the calibration: the framing names what makes the area hard *and* what makes it lower-stakes than other areas. Both directions matter — the agent calibrates severities against both.

---

## Slot 5 — "What to look for" (multi-headed checklist, organized by concern)

### PIC-WORKED-EXAMPLE: Area 2 (Payments), excerpted headings

> **Order state machine**
> - Are all status transitions enforced somewhere (service layer, DB constraint, or both)?
> - Terminal states: once an order is `refunded` or `cancelled`, can it transition back? Should it be able to?
> - Concurrency: two webhooks for the same order arriving simultaneously — is there row-level locking, an idempotency key, a unique constraint?
>
> **Webhook handling**
> - PayPal signature verification: is it actually performed, or is the endpoint accepting unsigned requests?
> - Idempotency: if PayPal retries a webhook (it will), does the second delivery produce a duplicate side effect or get safely no-op'd?
>
> **Booking ↔ Order ↔ Payment reconciliation**
> - `Order.subtotal` and `Order.grand_total` exist, but discount lives on `Booking`. Walk through the math — does it reconcile when an order has multiple bookings with different senior-discount totals?

Notice the structure: each heading names a concern the agent should *think about*. Bullets under each are concrete, pointed questions, not generic "review for correctness." The bullets carry the orchestrator's priors — the things the orchestrator *expects* might be wrong are stated, so the agent can verify or refute rather than discover.

---

## Slot 7 — Severity calibration (the hardest fill)

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> A bug in the order state machine that could double-charge is `code-quality:critical` even if the PayPal integration is dead today (because the same machinery may be wired to something live later). A missing webhook signature check is `code-quality:critical` regardless of whether the path is live. An unenumerated `payment_method` string is `code-quality:moderate`. An ungainly variable name in `orders.py` is `code-quality:nice-to-have`.

### PIC-WORKED-EXAMPLE: Area 3 (Auth)

> A missing rate limit on the 6-digit code is `code-quality:critical`. A magic link that can be replayed is `code-quality:critical`. An overly informative auth error message that enables email enumeration is `code-quality:moderate`. A confusing variable name in a session helper is `code-quality:nice-to-have`.

### PIC-WORKED-EXAMPLE: Area 4a (Cross-cutting services)

> A wrapper that silently swallows vendor errors is critical (it creates the invisible-failure class Area 2 identified). A wrapper without timeouts is critical (it creates unbounded-blocking risk). A wrapper hardcoding a model version that's about to be deprecated is moderate. Inconsistent exception types across wrappers is moderate. Variable-naming or formatting issues are nice-to-have.

### PIC-WORKED-EXAMPLE: Area 4b-1 (Edu pipeline)

> A pipeline-state-corruption bug (half-completed run leaves DB in inconsistent state) is critical. An unbounded-cost runaway risk is critical. A missing recovery path that forces start-over on transient failures is moderate. Inconsistent token budgets that produce minor quality drift are nice-to-have.

### What good calibration depth looks like

Notice the pattern across these examples: **each rung names a concrete behavior, not a property**. "Could double-charge" not "financial impact." "Magic link that can be replayed" not "session security issue." "Half-completed run leaves DB in inconsistent state" not "data integrity issue."

The rung is concrete enough that a fresh agent can apply it to a new finding by analogy: "this finding is shaped like the double-charge example, so it's critical."

Generic rubrics ("anything affecting payments is critical") underperform because they don't help with the actual judgment calls — the moderate band is where most findings live, and the moderate band needs the most calibration.

---

## Slot 7 — Agent-friendly calibration

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> Anything touching payment math, state machines, webhook handling, or schema changes is NOT agent-friendly. Mostly only cosmetic or doc-only issues in this area will qualify.

### PIC-WORKED-EXAMPLE: Area 3 (Auth)

> Anything touching token generation, session handling, authorization checks, or rate limiting is NOT agent-friendly. Cosmetic refactors of error message wording might be. The category is "small, well-bounded, no security judgment required" — most auth findings fail at least one of those.

### PIC-WORKED-EXAMPLE: Area 5 (Frontend public)

> Agent-friendly is more available here than in the services layer. Cosmetic CSS/JSX cleanup, hardcoded string → i18n key migrations, adding missing alt text, route-level code-splitting — these are typically agent-friendly. Cross-cutting state refactors and security fixes are not.

Notice: each example names what would qualify AND what wouldn't, in the area's domain vocabulary. "NOT agent-friendly because security judgment required" is more useful than "default to NO" because it gives the agent the *reason*.

---

## Slot 7 — Stop-the-line triggers (concrete vulnerabilities, never abstract)

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> If you find an active vulnerability — unsigned webhook endpoint accepting writes, SQL injection in a public endpoint, a path where a client can manipulate price server-side, an order status that can be flipped without auth — surface immediately. We fix inline before continuing the audit.

### PIC-WORKED-EXAMPLE: Area 3 (Auth) — most likely area of all

> Stop-the-line is most likely here of any area. If you find:
> - A route that should be protected but isn't
> - A token replay vulnerability
> - A path where authorization is missing entirely
> - Credentials or tokens being logged in plaintext
> - A way to escalate from educator to admin (or unauthenticated to authenticated) through the API
>
> ...surface immediately. We fix inline before continuing the audit.

### PIC-WORKED-EXAMPLE: Area 5 (Frontend public) — less-likely framing

> Less likely on the public side than in services. Triggers: an open redirect that takes user input, an XSS vector reachable by public users, a data-leak in a public API response rendered by the site (e.g. a tour endpoint returning admin-only fields), or anything that exposes credentials/tokens client-side.

The triggers are concrete: "unsigned webhook endpoint accepting writes" is a sentence the agent can match a finding against. "Security vulnerability" is not. The asymmetry across areas ("most likely here", "less likely on the public side") tells the agent what to be on the lookout for.

---

## Slot 9 — Scope estimate (with re-scope trigger)

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> This is bigger than Area 1. Expect 2-3 hours of focused work and 10-15 issues filed. If you're approaching 25+ findings, something is wrong — either the codebase has more rot in this area than expected (surface and we'll regroup) or you've drifted into Area 3 or 4 territory.

### PIC-WORKED-EXAMPLE: Area 3 (Auth)

> Expect 1-2 hours of focused work and 5-10 issues filed. The smaller volume estimate is appropriate because auth code tends to be either correct or dramatically wrong — there's less "convention drift" territory than in models or services. If you're approaching 15+ findings, either the auth surface is much larger than I think, or you've drifted into Area 6 admin-UI territory.

Notice: the upper-bound trigger names the *failure mode* the upper bound is detecting (drift into another area, more rot than expected) and names what to do (surface and regroup). Pre-empts unbounded fan-out without being a hard cap.

---

## Slot 10 — Begin-by lead-in (numbered, ending at an approval gate)

### PIC-WORKED-EXAMPLE: Area 2 (Payments)

> Begin by:
> 1. Reading the audit plan, the Area 1 report (especially the "Newly observed for Area 2" subsection), and the Phase 0 report's payment-relevant findings (the `tours.py` bug, the credential mismatch).
> 2. Mapping out the PayPal forensic investigation as a concrete plan: what code reads, what prod queries (with the gating pattern above), what conclusion criteria.
> 3. Proposing a session structure to me — probably "forensic first, then code audit" rather than interleaved, because the forensic conclusion shapes the severity of subsequent findings.
>
> Wait for my approval on the plan before starting any prod queries.

Notice: four numbered steps escalating from re-read inputs → produce a map → propose structure → wait for approval. Every step ends in a deliverable the operator can react to; the final step is the approval gate.

---

## A note for future readers

The above are the pilot's fills. The fills for a new repo will be entirely different. Severity examples for an e-commerce checkout codebase will look different from the pilot's. The *shape* of the fills — concrete, behavior-based, area-grounded — transfers; the *content* does not.

When installing this methodology in a new repo, replace the `PIC-WORKED-EXAMPLE` blocks with that repo's equivalents (the methodology-install skill walks you through this). Leave the structure of "this is what a good fill looks like" intact, but never carry the pilot's content into a different codebase's audit.
