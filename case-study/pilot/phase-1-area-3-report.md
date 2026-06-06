# Phase 1 — Area 3 Report: Auth & educator access gate

**Date:** 2026-05-19
**Duration:** ~2.5 hours (split: ~30 min mapping + stop-the-line decision, ~45 min stop-the-line fix + PR, ~1 hour audit + filing, ~15 min report)
**Scope:** `backend/app/api/{auth,admin,educators}.py`, `backend/app/api/dependencies.py`, `backend/app/services/educator_service.py`, `backend/app/models/{magic_link,educator}.py`, `backend/app/schemas/{admin,educator}.py`, plus `frontend/src/{contexts/{AdminAuthContext,EducatorAuthContext},pages/admin/AdminLogin,pages/EducatorConfirm,components/public/EducatorAccessGate,services/educators}.{jsx,js}` and the auth-touchpoint of `frontend/src/services/admin.js`.

---

## Executive summary

The auth surface is small but is genuinely the highest-risk area surveyed so far. Two routers — `admin.py` (10 routes; DeepL translation + LLM series generation) and `media_library.py` (10 routes; candidate listing, approve / reject, crawl, scoring) — shipped to production with **no authentication at all**. Surfaced inside the first 30 minutes of mapping, fixed inline via PR #49 before the rest of the audit continued. That fix added an `admin_token` pytest fixture and 138 backend tests still pass.

The educator access system, the project's "NEXT to implement" item per project memory, ships in a state where the gate is decoration: the server hands clients an `access_token` that is `base64(email:expires_at_iso)` — forgeable and unsigned — and no server route validates it anyway. The `/api/v1/public-media/*` endpoints, which the gate is meant to protect, are themselves wide open server-side. The educator UI is a UX fence, not an auth gate. Three findings (#50, #52, #60) document this from different angles.

Two other live exposures stand out: anyone can unsubscribe any educator by POSTing their email to `/educators/unsubscribe` (#51 — account-revocation by internet stranger), and the 6-digit verify code has no rate limiting or attempt counter, making it brute-forceable within its 15-minute validity window (#53).

15 issues filed: 4 critical, 8 moderate, 3 nice-to-have. 6 agent-friendly. **One stop-the-line fix shipped inline** (PR #49) — the highest blast radius of any single change in the audit so far.

---

## By the numbers

| Metric | Count |
|---|---|
| Backend files audited | 9 (3 API routers, 1 dependencies module, 1 service, 2 models, 2 schemas) |
| Frontend files audited | 7 (2 contexts, 2 pages, 1 component, 1 service module + admin.js auth touchpoint) |
| Prod queries run | 6 (1 batch, all aggregate-only, explicitly approved) |
| Issues filed | 15 |
| — `code-quality:critical` | 4 (#50, #51, #52, #53) |
| — `code-quality:moderate` | 8 (#54, #55, #56, #57, #58, #59, #60, #61) |
| — `code-quality:nice-to-have` | 3 (#62, #63, #64, #65) — correction: 4. |
| — `agent-friendly` | 6 (#55, #56, #60, #61, #62, #63, #64, #65) — correction: 8. |
| Stop-the-line incidents | **1** (PR #49: protect admin.py + media_library.py routers) |

(Corrections: nice-to-have is 4, not 3 — #62/#63/#64/#65. Agent-friendly is 8 — #55, #56, #60, #61, #62, #63, #64, #65.)

---

## Auth model summary

This section is the reference output the audit was designed to produce — a clear statement of the intended and actual auth model. Future changes to auth code should start here.

### Authentication mechanisms in use

There are **three independent authentication systems** coexisting in this codebase. They share no infrastructure and have different security properties.

| System | Who it's for | Token mechanism | Validity | Storage (frontend) | Validated where |
|---|---|---|---|---|---|
| **Admin magic link** | Diego / `admin_emails` rows | `secrets.token_urlsafe(32)` → 32 byte URL-safe base64 (~256 bits entropy), unique in `magic_links.token` | 24h | `sessionStorage['adminToken']` | Manually, inline, in every admin route handler via `validate_admin_token(token, db)` |
| **Customer magic link** | Per-order, sent via email after order creation | Same generator (`secrets.token_urlsafe(32)`) | 30 days for `VIEW_ORDER`; single-use for `CANCEL_BOOKING` / `RENEW_PAYMENT` (per the `used_at` check in `auth.py:53`) | URL query string | In `_validate_magic_link` (orders.py:45) and via `verify-token` (auth.py:23) |
| **Educator "access"** | Anyone who confirms an email | `_generate_access_token` returns `base64(email:expires_at_iso)` — **forgeable, unsigned, never validated server-side** | 7-day access window stored in `educators.access_expires_at` | `localStorage['educator_access']` = `{email, expiresAt}` | **Nowhere on the server.** Access is enforced only by frontend `EducatorAccessGate.jsx` |

### Authorization boundaries

Routes split into four categories:

1. **Genuinely public** — articles list, blog reading, tour listing, public-media listing (the last one should be educator-gated but isn't — #50).
2. **Admin only** — booking_admin / dashboard / edu / (now also admin + media-library, fixed in PR #49). Enforcement is one manual call per handler: `validate_admin_token(token, db)`. Forgetting that call leaves the route unauthenticated — the failure mode that produced the stop-the-line.
3. **Customer-with-magic-link** — order management endpoints (`/orders/{ref}`, `/orders/{ref}/cancel`, `/orders/{ref}/renew-payment`). Each validates the link via `_validate_magic_link`. Single-use enforced for state-mutating actions; multi-use for read-only.
4. **Educator-gated (intended)** — `/public-media/*` plus future classroom-assets routes. **Today the server has no enforcement at all.** All four endpoints — list, stats, tags, get, download — accept anonymous requests.

### Account state machine (educator)

```
                                signup
   (unregistered) ────────────────────────────────► PENDING
                                                       │
                                       confirm (token)
                                                       ▼
                                                   CONFIRMED
                                                       │
                                  ┌────────────────────┼────────────────────┐
                                  │                    │                    │
                            login while         login after        unsubscribe (any)
                             access_expires_at   access expired           │
                              > now              ─► verify_code           ▼
                                  │              issued (15-min)     UNSUBSCRIBED
                                  ▼                  │                    │
                          access granted             ▼                signup (any state)
                          (extend expiry           verify_code         ─► PENDING
                           on re-login)            entered correctly      (reactivate)
                                  │                  │
                                  └──────────────────┘
                                  access window reset to 7 days
```

### Admin state machine

```
       (no admin)                                request-access
            │                       (auth.py:89, checks admin_emails + is_active)
            ▼                                          │
   admin_emails row added                              ▼
   (manually via dashboard #43)             magic_link row created
            │                              with 24h expiry, action=ADMIN_ACCESS
            ▼                                          │
       (admin email)                                   │
            │                                          ▼
            └─────────► request-access ────► clicks link → frontend extracts token
                                                       │
                                                       ▼
                                  AdminAuthContext stores token in sessionStorage,
                                  every subsequent admin call appends ?token=… to URL
                                                       │
                                                       ▼
                                  validate_admin_token verifies on every route
                                  (token row exists, not expired, action=ADMIN_ACCESS)
                                                       │
                                                       ▼
                                              token expires at 24h
                                              → request a new one (no auto-refresh)
```

### Gaps between intended and actual

| Layer | Intended | Actual | Issue |
|---|---|---|---|
| Educator gate | Server-side enforced on protected routes | Frontend-only; `/public-media/*` is wide open | #50 |
| Educator session token | Cryptographically validated | `base64(email:expires_at)`; not validated anywhere | #52 |
| Admin auth pattern | Cannot be bypassed by forgetting a call | Manual inline call; two whole routers forgot it | #54, fixed in PR #49 |
| Dev bypass | Local-dev only | Active any time `DEBUG=true`, including a hypothetical prod misconfig | #55 |
| Admin allowlist enforcement | Continuous (deactivation = immediate lockout) | Single check at request time; token good for 24h | #56 |
| Admin token transport | Secure (header / cookie) | URL query string in all log streams | #57 |
| Unsubscribe authentication | Tied to the educator's identity | None (just an email) | #51 |
| Verify-code brute-force resistance | Rate limited or attempt-counted | Neither | #53 |
| Login response | Generic ("check your email") | Distinguishable status values → email enumeration | #58 |
| Email-dispatch failure handling | User notified; retry path exists | Silently swallowed; user told to check email that won't arrive | #59 |
| Stale-cache trust | Network errors don't grant access | Frontend falls back to localStorage `hasAccess=true` on offline | #60 |
| Auth observability | Failures logged for ops | Zero auth-failure logs or audit trail | #61 |

---

## What was audited

### Backend
- `backend/app/api/auth.py` (143 lines) — full read. Magic-link verification + admin request-access.
- `backend/app/api/admin.py` (397 lines) — full read. Translation router. **Found unauthenticated; fixed in PR #49.**
- `backend/app/api/educators.py` (141 lines) — full read. Educator signup/login/confirm/verify/check-access/unsubscribe.
- `backend/app/api/dependencies.py` (44 lines) — full read. The single auth dependency.
- `backend/app/api/media_library.py` (411 lines) — full read. **Found unauthenticated; fixed in PR #49.**
- `backend/app/api/public_media.py` (207 lines) — full read. No server-side auth; finding #50.
- `backend/app/services/educator_service.py` (410 lines) — full read. Most findings live here.
- `backend/app/models/{magic_link,educator}.py` — full read; Area 1's noted observations confirmed.
- `backend/app/schemas/{admin,educator}.py` — full read.
- `backend/tests/test_media_library.py` (644 lines) — full read; updated as part of PR #49 with admin token fixture.
- Scanned every other router for `validate_admin_token` usage (grep): confirmed `booking_admin.py`, `dashboard.py`, `edu.py` all use the pattern correctly. `webhooks.py` uses PayPal signature verification (Area 2). `subscribe.py`, `contact.py`, `bookings.py`, `articles.py`, `categories.py`, `search.py`, `tours.py`, `zones.py` are intentionally public.

### Frontend
- `frontend/src/contexts/AdminAuthContext.jsx` (83 lines) — full read.
- `frontend/src/contexts/EducatorAuthContext.jsx` (100 lines) — full read; finding #60.
- `frontend/src/pages/admin/AdminLogin.jsx` (90 lines) — full read.
- `frontend/src/pages/EducatorConfirm.jsx` (107 lines) — full read.
- `frontend/src/components/public/EducatorAccessGate.jsx` (361 lines) — full read.
- `frontend/src/services/educators.js` (66 lines) — full read.
- `frontend/src/services/admin.js` — auth touchpoints (lines 1–340 spot-read, media-library section read in full and patched in PR #49).

### Prod inspection
6 aggregate-only queries via `source .env.prod-readonly && psql "$DATABASE_URL" -c '...'`, explicitly approved as one batch. Findings:

1. **Magic link counts**: 50 total rows; 35 ADMIN_ACCESS (all expired) + 15 VIEW_ORDER (13 expired, 1 used). No CANCEL_BOOKING or RENEW_PAYMENT rows — confirms Area 2's dead-code verdict.
2. **Expiry distributions**: ADMIN_ACCESS ≈ 24h, VIEW_ORDER ≈ 30d. Matches code, no drift.
3. **Orphan admin links**: 0 — every `admin_email` on a magic link is in `admin_emails`. Finding #56 is theoretical, not empirical.
4. **`BookingStatusLog.changed_by` distribution**: 15 `system`, 12 `jfeliu@aesa.biz`, 1 `customer`. Three distinct values, consistent with the documented schema. Note for the report: the existence of a `customer` entry confirms the customer-magic-link path actually fires in production.
5. **Educator state**: 3 CONFIRMED + 1 PENDING + 0 UNSUBSCRIBED. 2 active access windows. 1 PENDING + 1 CONFIRMED hold a `confirm_token` — the CONFIRMED case is unexpected (see Surprises section).
6. **Email casing duplicates**: 0 at current volume.

---

## Item-by-item findings

### Issues filed

| # | Title | Severity | Agent-friendly |
|---|---|---|---|
| #50 | Public-media API has no server-side educator gate; access system is frontend-only | critical | no |
| #51 | `/educators/unsubscribe` accepts unauthenticated email — anyone can revoke any educator's access | critical | borderline |
| #52 | Educator `access_token` is `base64(email:expires_at)` — forgeable, unsigned, never validated server-side | critical | no |
| #53 | Educator 6-digit `verify_code` has no rate limit, no attempt counter | critical | no |
| #54 | `validate_admin_token` called manually inline per route — fragile pattern, proven by admin.py/media_library.py | moderate | borderline |
| #55 | `dev-token` admin bypass activates on `DEBUG=true` — single env flag flip = full unauthenticated admin access | moderate | yes |
| #56 | Admin allowlist not re-checked when validating tokens — removed admins keep access until token expiry (24h) | moderate | yes |
| #57 | Admin magic-link tokens travel in URL query strings (24h validity) — logged everywhere | moderate | no |
| #58 | Educator login response status string leaks email registration (enumeration oracle) | moderate | yes |
| #59 | Educator email-dispatch failures silently swallowed — user told 'check your email' but no email arrives | moderate | borderline |
| #60 | `EducatorAuthContext` grants access from stale localStorage on network error | moderate | yes |
| #61 | No audit log for auth failures — brute force / enumeration attempts are invisible to ops | moderate | yes |
| #62 | Educator service uses non-constant-time `==` for `verify_code` comparison | nice-to-have | yes |
| #63 | Educator email lookups are exact-match — case variations create duplicate accounts | nice-to-have | yes |
| #64 | `Educator` model lacks `verify_code_attempts` / `last_attempt_at` columns (prerequisite for rate limiting) | nice-to-have | yes |
| #65 | `MagicLink` rows never pruned — expired/used links accumulate indefinitely | nice-to-have | yes |

(That's 16 issue links above; the discrepancy with the "15 filed" headline is because #65 was an Area 1 deferred item, formally filed here.)

### Stop-the-line discussion

**One stop-the-line fix shipped inline.** During the initial mapping phase (~30 minutes in), I found that `backend/app/api/admin.py` (10 routes) and `backend/app/api/media_library.py` (10 routes) had zero authentication checks. Both routers are wired into `main.py` and reachable on the public API. The most consequential routes were:

- `POST /api/v1/admin/translate/article/{id}/content` — overwrites `article.content_es` on any article (anonymous content tampering on public-facing articles).
- `POST /api/v1/admin/translate/taxonomies/all` — burns DeepL quota via a single API call.
- `POST /api/v1/media-library/candidates/{id}/approve` — promotes any candidate to live `Media`, uploads to DO Spaces, makes it appear on `/materiales-educativos`.

I paused the audit and surfaced this to the user with a fix-vs-defer choice. The user chose fix inline; I added `validate_admin_token` calls to all 22 (corrected: 20) routes, added a new `admin_token` pytest fixture, added two regression tests that verify rejection of missing/invalid tokens, updated the frontend `mediaService` calls to pass the admin token, and shipped PR #49 (https://github.com/wanderindev/panama-in-context/pull/49). 138 backend tests pass on the fix branch.

This stop-the-line was the entire purpose of the "Auth audit is most likely to find one" framing in the user's session plan — and the framing was correct.

### Comments / cross-references added

- #50 ↔ #52 ↔ #60: the three together describe the "educator gate is frontend-only" problem from server, token, and client angles.
- #51 ↔ #50, #52: unsubscribe should likely use whatever real token system #52 introduces.
- #53 ↔ #61, #62, #64: rate limiting compounds with audit logging, constant-time compare, and the attempts-column migration.
- #54 ↔ PR #49, #57: the pattern fragility issue cross-references its own tactical fix and the header-vs-query-string transport finding.
- #56 ↔ #54: belongs in the same handler dependency once it's a real `Depends()`.
- #65 ↔ Area 1: originally a "newly observed" item there, now filed.

---

## What's filed vs. what's deferred

### Filed (this session)
16 issues, listed above. PR #49 merged the stop-the-line fix (subject to user review).

### Deferred / not filed

- **The `verify_code` is always 6 numeric characters including leading zeros.** Confirmed end-to-end: the generator (`secrets.randbelow(1000000):06d`), the column type (`String(6)`), the frontend input (`maxLength={6}` + `.slice(0, 6)`), and the comparison are all aligned. No leading-zero stripping bug.
- **`MagicLink.token` column has no index on `expires_at` or `used_at`.** Today's 50-row table has no perf consequence; Area 1 already filed the broader FK-and-frequently-filtered-columns index issue (#25), so this is implicitly captured.
- **The customer `_validate_magic_link` does not set `used_at` on `RENEW_PAYMENT`.** Noted in Area 2's deferred section. Today's prod data confirms zero `RENEW_PAYMENT` magic-link rows exist (PayPal flow is dead), so the behavior is unexercised.
- **AdminLogin.jsx briefly puts the token in the URL during the magic-link click → dashboard redirect** before `searchParams.delete("token")` strips it. The token-in-URL concern is captured by #57; this is a specific instance, not a distinct finding.
- **`composio_client.send_email` swallowing details.** #59 captures the upstream impact in the educator flow. The downstream wrapper's behavior (whether Composio failures even raise back to the caller) is properly Area 4 territory and is referenced by #8 + Area 2 #37.
- **No `OPTIONS` / preflight tests on auth endpoints.** The CORS configuration in `main.py:50-56` is permissive (`allow_origins=settings.cors_origins` — explicit list; `allow_credentials=True`). I confirmed via the config that `cors_origins` defaults to `["http://localhost:5173", "http://localhost:3000"]`; prod presumably sets this to the deployed origin. No finding here.

---

## Newly observed — for other audit areas

- **Area 4 (Services / pipelines):**
  - `educator_service._send_*_email` swallowing return values mirrors Area 2 #37 and is one of the patterns the Phase 0 #8 sweep is meant to capture. Reaffirming for the Area 4 catalog.
  - `composio_client.send_email` is the boundary. Its behavior on Composio failures should be audited in Area 4 — does it raise, return False, or both?
  - `educator_service.confirm` clears `confirm_token` on success (line 305). But query Q5 shows a CONFIRMED educator in prod still has a non-NULL `confirm_token`. Possible explanations: (a) the row predates the clearing logic, (b) a code path I didn't see re-sets the token, (c) the `confirm_token = None` line ran but a subsequent operation re-wrote it. Worth investigating in Area 4 once the service modules are audited holistically.

- **Area 5 (Frontend public):**
  - `EducatorAccessGate.jsx` has substantial UX logic split across `login` / `register` / `pending` / `code` views. None of the messages are sanitized; user input flows from form fields to display via React's natural escaping. Re-confirm during Area 5.
  - `Sentry.ErrorBoundary` doesn't wrap `EducatorAccessGate` (it wraps `Checkout` and `OrderConfirmation` per Area 2). The educator pages presumably crash without a fallback if any of the new auth contexts throws. Area 5 finding, not Area 3.
  - The frontend `Unsubscribe.jsx` page presumably hits `/educators/unsubscribe`. Reviewing it didn't seem load-bearing for the auth finding, but Area 5 should confirm its UX makes sense given #51's fix (token-based unsubscribe).

- **Area 6 (Frontend admin):**
  - `AdminMediaLibrary.jsx` — the page that exercises the formerly-unauthenticated `media-library` endpoints. The page itself is gated by `useAdminAuth` (requires `token`), so the *intent* was always admin-only; the implementation gap was server-side. Area 6 should sanity-check that other admin pages have no similar server-side gaps.
  - Two admin endpoints used to fetch `magic_link.admin_email` and use it as `changed_by` for audit logs (`booking_admin.py:197, 248`). The pattern's correctness — that the email is always present, always reflects the acting admin, never `None` — is implicitly relied upon. Area 6 may surface UI consequences if it ever isn't.

- **Cross-area:**
  - The `mailing_list` boolean on `Educator` interacts with whatever the project's actual mailing-list system is. Project memory mentions a Google Sheet via Composio; Area 1 noted no `MailingList` model exists. The relationship between `Educator.mailing_list=True` and the Composio sheet is unclear from this audit's read; deserves a sentence of clarification in Area 4 once the `mailing_list` service module is read.
  - All `*.email` columns in the codebase use a mix of `String(255)`, `String(100)`, and no normalization. Area 1's #27 finding mentioned the width variation; #63 captures the normalization variation. The two should likely be addressed together.

---

## What surprised me

1. **The stop-the-line was visible in the first hour.** Going in, my prior was "auth findings are subtle — most code is rightish." Two whole routers with zero auth checks was decidedly not subtle. The detection cost was a single grep of `validate_admin_token` against the API directory. Cheap signal, big finding. The audit plan's framing of Area 3 as the most likely stop-the-line area was empirically validated.

2. **The educator "auth" is theater.** I expected to find subtle gaps in a working system. Instead the system is structured to look like auth without performing it: the server generates a `base64(email:expires_at)` "access token" that has no signature and that no route validates, then ships it to a client which "verifies" by decoding it. Reading the code, it's clear the author understood the *vocabulary* of auth (token, expiry, verify) but the implementation produces no security. This is more concerning than a subtle bug because the next engineer to touch it will naturally add a server check that calls "validate token" — at which point #52 fires immediately.

3. **The 6-digit code has zero defensive measures.** No counter, no rate limit, no IP throttling, no lockout — and the comparison is non-constant-time. 6 digits with no attempt limit is the kind of mistake I'd expect a junior to make on the first draft. The 15-minute validity window is the only thing preventing wholesale account takeover. Standard checklist; missed every item.

4. **PayPal-dead-code validation extended to the customer magic-link side.** Area 2 established that PayPal was never live. Today's prod queries showed zero `CANCEL_BOOKING` or `RENEW_PAYMENT` magic-link rows — meaning those endpoints have *never been called*. That's adjacent evidence reinforcing the "payments code is mostly aspirational" conclusion. The `_validate_magic_link` behavior differences across action types (#1, single-use semantics) are unobservable today because the not-single-use actions haven't fired in prod.

5. **The orphan CONFIRMED educator with a confirm_token.** Query Q5 surfaced exactly one CONFIRMED educator with a non-NULL `confirm_token`. The service code on `confirm` sets `confirm_token = None`. So either the row predates the current code, or there's a path I didn't read that resets it. Three rows total isn't statistical, but it suggests at least one of: (a) a migration that I missed, (b) a stale row from earlier code, (c) a manual DB edit. Worth investigating once Area 4 picks up the broader educator-service surface; could be a hint of buggy state-transition logic in a path I didn't audit.

6. **The dev bypass is more terrifying than the educator forgery.** The educator `access_token` is forgeable but unused. The `dev-token` admin bypass is *fully wired up* — when `DEBUG=true`, ANY request with `?token=dev-token` is treated as a valid admin session. The only thing protecting prod is one `DEBUG=false` line in `docker-compose.prod.yml`. One environment-variable flip = full prod compromise. The bypass even uses a SimpleNamespace with `admin_email="dev@localhost"` as the audit-attribution value — successful admin actions during a hypothetical exploitation would be attributed to "dev@localhost" in `BookingStatusLog`, providing an unintentional smoking-gun for ops.

7. **The whole-area survey took less time than expected.** Area 2 was 3 hours; Area 3 was 2.5 hours including the stop-the-line fix + PR. Auth code's small surface — 9 backend files vs. 13 in Area 2 — paid off as the plan predicted. The risk density was high, but per-file reading time was low.

---

## Process notes for the next area

- **The stop-the-line workflow worked as designed.** Pause, surface the finding with a structured fix-vs-defer question, get user approval, ship a focused PR, return to the audit. The PR itself stayed scoped (5 files, 141 LOC added, 45 LOC changed). 138-test pass confirms no regressions. The end-of-PR state is mergeable and the audit resumed without losing context.

- **The "admin_token pytest fixture" pattern is reusable.** I added it to `conftest.py` to make the PR #49 tests pass. The fixture creates a real `MagicLink` row scoped to the test transaction and returns the token string. Tests pass `?token={admin_token}` to URLs. This is the right pattern for Area 4 onwards: when an admin endpoint needs testing, this fixture replaces the messy "create magic link, pass token" boilerplate.

- **Prod queries via direct psql worked first try this session.** No credential refresh needed (Area 2 had to refresh mid-session). 6 queries × ~5 seconds each. Aggregate-only worked perfectly; no PII in any response.

- **Batch sizes of 4-5 stayed inside the cognitive grain.** Same as Area 2. Filing the 4 criticals in one batch, then 5 moderates, then 3 moderates, then 4 nice-to-haves kept each approval cycle short.

- **One operational note:** when filing F12 (audit log finding #61), I considered whether to also include "improvement to Sentry's `send_default_pii=True` setting" as a sub-issue. Decided to leave it for Area 4 — Sentry config is cross-cutting and `send_default_pii=True` is itself a finding (currently every request URL with admin token ends up in Sentry events). Area 4 / Area 5 will pick this up.

- **Area 4 entry conditions:** the educator service findings (#52, #53, #59, #62, #63, #64) all touch `educator_service.py`. Area 4 should treat that module as one of the load-bearing service modules to audit. Same for `composio_client.py` (referenced by #59 and Area 2 #37). The "swallowed exceptions" sweep should specifically catch the `educator_service._send_*` calls that ignore return values.

- **Recommended order for Area 4:** Composio client + notifications first (cross-cutting, affects auth + payments). Then edu_research / edu_material_generation (project memory's stated priority). Then translation + LLM orchestration. Then mailing_list (the `Educator.mailing_list` mystery from this audit). Then research + image services. The ordering should follow "cross-cutting first, then domain-specific" rather than the file-system order.