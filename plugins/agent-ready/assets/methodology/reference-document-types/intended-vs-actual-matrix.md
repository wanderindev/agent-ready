# Intended-vs-actual matrix

## Purpose

The intended-vs-actual matrix is the **general device** for areas whose findings are mostly deviations from an invariant. The shape is the same across surfaces: a row per layer / mechanism / boundary, columns for *intended*, *actual*, and *issue number*. Building the matrix makes the deviations countable: every finding ends up framed as "intended X / actual Y / gap Z (filed as #N)".

The pilot audit produced three instances of this shape, each applied to a different surface. The synthesis §7 is explicit that the matrix is *the* primary device and the three surface variations are instances of one shape, not three separate one-offs. This spec treats the matrix as primary and the three surface variations (auth model, public-site error-handling, admin route + auth) as worked examples inside the one spec.

## When it's produced

In any area whose findings are mostly **deviations from an invariant**. The trigger: the area's purpose can be stated as one or more invariants ("every admin route requires a valid token", "every uncaught error has a recovery path", "every external call has a timeout"), and most expected findings will be violations of those invariants rather than independent bugs.

In the pilot: Area 3 (auth) produced the auth-model matrix; Area 5 (frontend public) produced the public-site error-handling matrix; Area 6 (admin CMS) produced the admin route + auth matrix.

## What triggers it

- The area is defined by an invariant or set of invariants.
- Most findings will be missing-thing-that-should-be-there rather than wrong-thing-that-is-there.
- The audit's value is more in surfacing the *gaps* against a model than in independently finding bugs.
- The model-summary-first adaptation is active for the area (see [the adaptations reference](../../../skills/area-audit/references/adaptations.md)).

## Template

The matrix has this shape:

| Layer | Intended | Actual | Issue |
|---|---|---|---|

- **Layer** — one mechanism / boundary / state-transition / route-class. The layer rows together cover the area's full surface.
- **Intended** — what should happen at this layer if the invariant holds. State concretely; "secure" is not an intended; "sessions are cryptographically random, ≥128 bits entropy, expire server-side after 24h" is.
- **Actual** — what currently happens. State as concretely as the Intended column. The point of the matrix is the comparison.
- **Issue** — filed issue number for the gap, or "Sound" / "Acceptable" if the actual matches the intended.

Rows where Actual matches Intended are not noise — they're **disconfirmation of the orchestrator's prior**. The auth-model matrix's three "Sound" rows on the admin perimeter (gate / no data leak before auth / build-time dev bypass) were specifically valuable findings: the audit's prior was that the admin perimeter was wobbly, and the matrix surfaced that it wasn't.

The matrix is usually preceded by 1-3 sub-sections that establish the model: which mechanisms are in use, the state machine(s) the model implies, the authorization boundaries / error-handling tiers / route classes. The matrix itself is the gap analysis; the sub-sections are the model.

## Worked examples (from the pilot — the three surface variations)

Three real instances of this spec, each on a different surface (full instances in the case study).

### Variation 1 — Auth model summary (Area 3)

`PIC-WORKED-EXAMPLE`. From an auth area report (`case-study/pilot/phase-1-area-3-report.md`):

The model is established first:

```
### Authentication mechanisms in use

There are three independent authentication systems coexisting in this codebase.

| System | Who it's for | Token mechanism | Validity | Storage (frontend) | Validated where |
|---|---|---|---|---|---|
| Admin magic link | Diego / admin_emails rows | secrets.token_urlsafe(32) ... | 24h | sessionStorage['adminToken'] | Manually in every admin route handler |
| Customer magic link | Per-order | Same generator | 30 days for VIEW_ORDER; single-use for CANCEL_BOOKING / RENEW_PAYMENT | URL query string | _validate_magic_link (orders.py:45) |
| Educator "access" | Anyone who confirms | base64(email:expires_at_iso) — forgeable, unsigned, never validated server-side | 7-day | localStorage['educator_access'] | Nowhere on the server |
```

Then the state machines (educator + admin) are diagrammed.

Then the gap matrix:

```
### Gaps between intended and actual

| Layer | Intended | Actual | Issue |
|---|---|---|---|
| Educator gate | Server-side enforced on protected routes | Frontend-only; /public-media/* is wide open | #50 |
| Educator session token | Cryptographically validated | base64(email:expires_at); not validated anywhere | #52 |
| Admin auth pattern | Cannot be bypassed by forgetting a call | Manual inline call; two whole routers forgot it | #54, fixed in PR #49 |
| Dev bypass | Local-dev only | Active any time DEBUG=true | #55 |
| Admin token transport | Secure (header / cookie) | URL query string in all log streams | #57 |
| Unsubscribe authentication | Tied to the educator's identity | None (just an email) | #51 |
| ... | ... | ... | ... |
```

Twelve gap rows; each filed as an issue.

### Variation 2 — Public-site error-handling model (Area 5)

`PIC-WORKED-EXAMPLE`. From a public-frontend area report (`case-study/pilot/phase-1-area-5-report.md`):

```
| Layer | Intended | Actual | Issue |
|---|---|---|---|
| Top-level error boundary | Uncaught render error → recovery UI | None — error unmounts the tree to a blank page | #7 (pre-existing) |
| Per-page error boundary | Each page soft-fails | Only Checkout, OrderConfirmation, Contact wrapped | #7 / #106 |
| Unknown URL | "Page not found" page | Blank <main> (no path="*" route) | #106 |
| Async fetch states | loading + error + empty, all three | Blog/Article/FeaturedArticles/MediaLibrary have all three | — (acceptable) |
| Service-layer HTTP errors | Non-2xx surfaced to the user | articles.js/publicMedia.js check response.ok; educators.js/subscribe.js do not | #107 |
| Persisted-state read | Corrupt data tolerated | EducatorAuthContext tolerates it; CartContext crashes the app | #110 |
| Educator route gate | Server-enforced | Client-only; localStorage-settable; API open | #50/#52 (pre-existing) |
| Stale-cache on network error | Deny access | Grants access from stale localStorage | #60 (pre-existing) |
| Rendered article HTML | Sanitized | Unsanitized end to end | #111 |
| Analytics | Production only | Fires in every environment | #112 |
```

Ten layer rows; the healthy rows ("Async fetch states — all three present") are themselves part of the value (Area 5's framing: "the gaps are all in the error tier, not the loading tier").

### Variation 3 — Admin route + auth model (Area 6)

`PIC-WORKED-EXAMPLE`. From an admin-CMS area report (`case-study/pilot/phase-1-area-6-report.md`):

```
| Layer | Intended | Actual | Status |
|---|---|---|---|
| Route gate | Every /admin/* route requires auth | AdminLayout wraps all 12 routes in AdminAuthProvider; renders loading → !isAuthenticated → <Navigate to="/admin/login"> | Sound |
| Data-before-auth | No admin page renders before auth resolves | The <Outlet> renders only when isAuthenticated is true | Sound — Area 5's concern refuted |
| Dev bypass | Local-dev only, cannot reach prod | import.meta.env.DEV → dev-token. Build-time constant — compiled out of production bundles. | Sound |
| Token transport | Header / cookie | URL query string everywhere | #57 (pre-existing) |
| Logout | Clears session + revokes server-side | Clears sessionStorage; does NOT revoke the token server-side | Gap — see Newly observed |
| Service error handling | Non-2xx surfaced | admin.js checks res.ok on all ~50 methods | Sound |
| Inline action error handling | Failure shown to operator | 22 handlers console.error only | #117 |
| Unsaved-work protection | Guarded on every exit path | 4/5 editors guard in-app exits; ResearchEditor unguarded; no beforeunload | #118, #119 |
```

The "Sound" rows here carry the audit's affirmative finding (the admin security perimeter is correct), which would have been lost in a findings-only report shape.

## Pitfalls

- **Treating "Sound" rows as filler.** The Sound rows are disconfirmation of priors — they're the audit's most valuable findings when the operator's prior was that something was broken and it turned out to be correct. Don't drop them.
- **Stating Intended too abstractly.** "Secure" / "correct" / "robust" are not Intended values. The Intended must be as concrete as the Actual or the comparison is empty.
- **Letting the model section eat the matrix.** The matrix is the deliverable; the model section is its support. If the model section is three pages and the matrix is six rows, the layers haven't been chosen tightly enough.
- **One row per finding, instead of one row per layer.** Six findings in the same layer become one row with multiple sub-bullets, not six rows. The layer is the structural unit; the findings are what populate the Actual column for that layer.
- **No "Sound" rows at all.** If every row is a gap, the model has been built too leniently — the operator was already certain everything was broken, and the matrix is just an issue-number table dressed up as a model. The model is only useful when it has room to disconfirm.
- **No state-machine diagram for state-machine layers.** Auth, educator confirmation, order state — when the invariant includes a transition graph, draw it (ASCII is fine). The matrix's "state transitions" row will reference the diagram.

## Cross-references

The matrix is the deliverable a **model-summary-first** adaptation produces — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md). Slot 10 of a model-summary-first prompt has the operator approve the matrix structure before the per-stage audit begins.
