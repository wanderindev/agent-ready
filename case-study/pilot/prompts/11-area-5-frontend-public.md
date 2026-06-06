We're starting Phase 1 Part B Area 5: Frontend public site.

Area 4 (the services layer) is complete: 4a/4b-1/4b-2/4c filed a coherent
backlog and produced the fix-ordering composition pattern. Areas 5 and 6
audit the frontend. Area 5 covers the public site; Area 6 covers the
admin CMS.

Read these first:
- docs/pilot/phase-1-audit-plan.md (the audit plan)
- The "Newly observed for Area 5" subsections of every prior area report,
  in particular:
  - Phase 0 report: #7 (no top-level Sentry.ErrorBoundary), #18 (2.6 MB
    bundle, code-splitting)
  - Area 1: `is_active` filtering should be confirmed on public endpoints
  - Area 2: cart persistence (useCart from CartContext), Meta Pixel
    events firing from multiple pages, Sentry boundaries on Checkout
    and OrderConfirmation, i18n key shape worth a sanity check after #35
  - Area 3: educator-access gate is frontend-only with a forgeable
    base64 token; this is the most consequential Area 5 finding to verify
- Issue #35 (BookingManage time-slot bug — already filed agent-friendly)
- Issue #36 (OrderConfirmation doesn't fetch order details)

## Why this area is different

Three differences from the services-layer audits:

1. **Failure modes are user-visible, not data-corruption-shaped.** A
   broken component renders wrong, breaks the layout, or fails to
   handle an error. The blast radius is one user's session, not the
   database.

2. **The cost surface is bundle size, accessibility, and i18n
   correctness** rather than token spend or vendor outage.

3. **Per-finding stakes are typically lower** because there's no
   production data to corrupt. The exceptions are the security
   findings (Area 3 already filed the most consequential one as #61).

The result: Area 5 will likely produce more nice-to-have findings and
fewer critical ones than the services-layer audits did. That's expected
and correct, not a quality signal.

## Scope

In-scope files:
- `frontend/src/` minus the admin routes — Home, Blog, Tours listing,
  Materiales Educativos, Contact, anything on the public surface
- i18n setup (`frontend/src/i18n.js` or equivalent), and the
  `frontend/public/locales/{en,es}/translation.json` files
- Sentry frontend instrumentation (the public side)
- Public state management (cart context, any other contexts)
- The bilingual fallback paths and any language-switching logic
- The educator-access frontend gate (the forgeable-token mechanism
  Area 3 flagged)
- Frontend service modules used by public pages (booking.js, etc.)

Out of scope (covered by Area 6 or already done):
- Admin routes / admin CMS components (Area 6)
- TipTap editor and AG Grid (Area 6)
- Checkout, OrderConfirmation, BookingManage, BookingCancel,
  BookingRenewPayment — Area 2 already audited the checkout flow.
  Reference Area 2's findings; don't re-audit.
- Backend code (Areas 1-4 done)

## What to look for

**Error handling and observability**
- Top-level `<Sentry.ErrorBoundary>` on `<App>` — Phase 0 flagged its
  absence as #7. Verify the current state.
- Per-page error boundaries — Area 2 noted three pages have them
  (Checkout, OrderConfirmation, Contact). Public pages outside that
  set: what happens to an uncaught error there?
- Loading states — every async fetch should have a loading state,
  an error state, and an empty state. Find the gaps.
- Network failures — what does a user see if the API is unreachable
  during a public-site action (browse blog, view tour, submit
  contact form)?

**i18n correctness**
- The #35 time-slot bug (BookingManage rendering "Afternoon" for
  everything) was an i18n-key-mismatch bug. Sanity-check the
  translation.json files: any other places where the backend returns
  a value that doesn't match an i18n key the frontend expects?
- Missing translations — keys present in `en` but not `es`, or vice
  versa
- Hardcoded strings in JSX that should be i18n keys
- Locale-dependent formatting: dates, prices, numbers. Are they
  formatted with locale-aware APIs (`Intl.DateTimeFormat`,
  `Intl.NumberFormat`), or with hardcoded `.toLocaleString('en-US')`?

**Public state management**
- Cart persistence — Area 2 flagged that Checkout's Sentry fallback
  says "your cart is saved" but the persistence implementation
  wasn't audited. Find it (CartContext, localStorage, sessionStorage,
  something else) and verify the claim.
- Auth state on the public side — what does the public site know
  about whether the user is logged in? Anything? If yes, how is that
  state managed and where is it stored?
- Race conditions on async state — a user clicking twice on a slow
  action, switching languages mid-load, navigating away mid-fetch

**Security on the public side**
- The educator-access gate (Area 3's frontend-only base64 token).
  Confirm what the frontend currently does to gate educator routes,
  and what an attacker would see if they bypass the gate. Area 3
  filed the *backend* fix (#61, gating `/api/v1/public-media/*`);
  what's the frontend story on the same surface?
- XSS surfaces — anywhere the public site renders user-controlled
  HTML (markdown rendering, blog content, etc.). React escapes by
  default; the risk is `dangerouslySetInnerHTML` or third-party
  components that don't escape.
- Meta Pixel and analytics — Area 2 noted the OrderConfirmation
  Purchase event fires with `value: 0`. Other pixel events on the
  public site: are values correct? Should they fire in development
  environments? Is the Pixel ID hardcoded or env-driven?
- Open redirects — any `window.location` or `<a href>` that takes
  user-controllable input

**Performance and bundle**
- #18 (2.6 MB bundle) is filed. Verify it's still the right size
  and identify the biggest single contributors. Suggested fixes:
  code splitting at the route level is the lowest-effort high-impact
  change.
- React rendering issues: components that re-render unnecessarily,
  missing keys on lists, expensive computations not memoized
- Image handling: are images lazy-loaded, properly sized, served
  from a CDN?

**Accessibility (bounded pass)**
- Semantic HTML on key landing pages (Home, Blog list, Tour
  listing). Quick scan for: missing alt text on images, missing
  form labels, headings that skip levels.
- Keyboard navigation on the cart and contact form
- Color contrast on critical CTAs (don't audit the whole design
  system — flag any obvious failures)

This is a bounded pass, not a full accessibility audit. If the site
is significantly inaccessible, file one issue capturing the pattern
rather than enumerating dozens of small ones.

**Things from earlier areas to verify**
- Area 1: `is_active` flag on Tour, Zone, Hotel, Attraction,
  AdminEmail. Public-API endpoints should filter on this. Verify by
  watching what the public site requests and what it gets back.
- Area 2: cart persistence implementation (see above)
- Area 3: educator-access frontend gate (see above)

## Working style

- **Batch-and-confirm** as in all previous sessions.
- **Severity calibration:** A finding that exposes user data or
  bypasses access control is critical. A finding that produces broken
  UX on critical paths (checkout, contact, booking) is moderate.
  Cosmetic or convention-drift findings are nice-to-have. Performance
  findings are moderate if they materially affect load time, nice-to-
  have otherwise.
- **Agent-friendly is more available here than in the services layer.**
  Cosmetic CSS/JSX cleanup, hardcoded string → i18n key migrations,
  adding missing alt text, route-level code-splitting — these are
  typically agent-friendly. Cross-cutting state refactors and security
  fixes are not.
- **Stop-the-line:** Less likely on the public side than in services.
  Triggers: an open redirect that takes user input, an XSS vector
  reachable by public users, a data-leak in a public API response
  rendered by the site (e.g. a tour endpoint returning admin-only
  fields), or anything that exposes credentials/tokens client-side.
- **No prod data access this session.** Frontend audits don't need
  it — the failure modes are visible in the code or by loading the
  site in a browser.

## End-of-session report

Save as `docs/pilot/phase-1-area-5-report.md`. Same shape as previous
reports.

**Fix-ordering section:** Yes, include one for the frontend public
site. The composition pattern is established; this is the third
instance. Pre-existing issues that touch the frontend: #7
(ErrorBoundary), #18 (bundle), #35 (time-slot), #36 (order details),
#43 (magic-link URL tokens — relevant to BookingManage), #47 (Meta
Pixel value), #61 (educator access — Area 3 already filed). Pull
these in.

**"Toward a global fix ordering" continuation:** The 4b-2 report
established the bridge format. Add a short section here noting which
of Area 5's findings interact with the backend orderings (probably
the educator-access ones, the i18n / time-slot cluster, the Meta
Pixel / order-details cluster). This is the third data point for
the Phase 1 final report's global synthesis.

## Scope estimate

Smaller than the services-layer sessions. Expect 1.5-2 hours and
6-10 issues filed. The exact count depends on how much of the
public site is in good shape — if i18n is clean, accessibility is
decent, and the cart persistence works, the count is on the low
end. If there are systemic issues, it's higher.

If you're approaching 15+ findings, you've probably drifted into
admin (Area 6) or expanded scope into the checkout flow (Area 2
done). Stop and re-scope.

Begin by:
1. Reading the inputs above, especially Area 3's educator-access
   finding (#61) and Area 2's frontend observations
2. Mapping the public-site route structure (a quick `ls` of
   `frontend/src/pages/` or wherever the public routes live, plus
   the router config that wires them up)
3. Identifying the audit walk order — probably: error/loading/empty
   states first (foundational), then i18n + state management
   (highest-finding-density), then security (highest-stakes), then
   performance + accessibility (bounded pass)
4. Proposing the session structure

Wait for my approval on the route map and walk order before
starting the per-page audit.
