We're starting Phase 1 Part B Area 3: Auth & educator access gate.

The audit plan at docs/pilot/phase-1-audit-plan.md remains authoritative.
Read the Area 1 and Area 2 reports (docs/pilot/phase-1-area-1-report.md,
docs/pilot/phase-1-area-2-report.md) for context and especially for the
"Newly observed for Area 3" subsections in each. Treat those as known
inputs to verify, not findings to rediscover.

Specifically from earlier areas:
- Area 1 flagged: `MagicLink` rows persist indefinitely with no cleanup
  job implied (worth checking whether expired/used links are pruned in
  services); `Educator.confirm_token` and `Educator.verify_code` are
  stored plaintext (defensible for short-lived single-use tokens but
  worth a security pass).
- Area 1 also flagged: `BookingStatusLog.changed_by` is `String(100)`
  storing "admin email or 'system'" — worth checking how admin actions
  are attributed in the auth/admin code.
- Area 2 may have added more — read its newly-observed section.

## Why this area matters

Narrow surface, high blast radius. Auth bugs are how unauthorized
parties get access to data or actions they shouldn't. The educator
access system is newer code (per project memory) — newer means less
battle-tested. The 7-day access window logic and the 6-digit
re-verification flow are exactly the kind of code where small bugs
have outsized consequences.

## Scope

In-scope files (read all in full):
- `backend/app/api/auth.py`, `admin.py`, `educators.py`
- Service-layer code for auth, sessions, tokens, magic links,
  educator confirmation, and the re-verification flow
- Pydantic schemas for the above
- Any middleware or dependencies that enforce auth on routes
- The educator access window logic (7-day) and the 6-digit code path
- Frontend admin auth UI (login, session handling, logout)
- Frontend educator confirmation/verification flow

Out of scope (note in "newly observed"):
- Service modules not related to auth (Area 4)
- Public site outside the educator confirmation flow (Area 5)
- Admin CMS internals beyond auth (Area 6)
- Payment code (Area 2, already done)

## What to look for

**Session and token handling**
- Are session tokens cryptographically random? Sufficient entropy?
- Token storage: in cookies (httpOnly, Secure, SameSite settings)?
  In localStorage (a red flag for session tokens)? In memory only?
- Are tokens rotated on privilege escalation (e.g. when an educator
  upgrades to verified)?
- Expiration: is it enforced server-side, or only by client-side
  countdown?
- Logout: does it actually invalidate the token server-side, or just
  clear the client?

**Magic link flow**
- Single-use enforcement: is a magic link actually one-time? Is
  `used_at` set atomically with the access grant?
- Expiry enforcement: is `expires_at` checked server-side on every
  use, not just at generation?
- Cleanup: do expired/used links ever get pruned, or do they
  accumulate forever? (Area 1 flagged this.)
- Token entropy: is the magic-link token long and random enough that
  enumeration is infeasible?
- Email delivery: are tokens ever logged on the way out (Sentry
  breadcrumbs, application logs, request logs)?

**Educator confirmation and re-verification**
- The 6-digit code: is it rate-limited per educator? Per IP?
  Globally? Brute force at 6 digits is 1M tries — without rate
  limiting, a few thousand requests per second cracks it in minutes.
- Is the 6-digit code actually 6 digits, or could it have leading
  zeros that get stripped somewhere?
- The 7-day access window: is the window checked on every request,
  or only at login? If only at login, a session that started on day
  6 might extend indefinitely.
- Re-verification trigger: what causes re-verification to be
  required? Is the trigger logic consistent with the security model?
- `confirm_token` and `verify_code` plaintext storage: defensible if
  they're short-lived and single-use, but verify that's actually the
  case. If either could be reused or persists beyond intended
  lifetime, the plaintext storage becomes a real finding.

**Admin auth**
- How is admin identified? A boolean flag on User? A separate model?
  Role-based? Whatever it is, audit the consistency of enforcement.
- `BookingStatusLog.changed_by` storing "admin email or 'system'" —
  audit whether this attribution is actually trustworthy, or if a
  bug could attribute an admin action to 'system' (or vice versa).
- Admin password storage: are passwords hashed with a modern algorithm
  (bcrypt, argon2, scrypt)? Or something brittle (MD5, SHA1, plain
  SHA256)?
- Admin session timeout: is there one? Idle vs absolute?
- Are admin actions logged anywhere beyond `BookingStatusLog`?

**Authorization enforcement**
- Every route that should require auth — is it actually wired up to
  the auth dependency? Look for routes that forgot the dependency.
- Every route that should require admin specifically — same check.
- Educator-only routes: are they actually gated on educator status,
  or just on "logged in"?
- Object-level authorization: can educator A access educator B's
  resources by guessing/enumerating an ID?

**Frontend auth**
- Token storage on the frontend (localStorage vs cookies vs memory)
- CSRF protection if cookies are used
- Login form: is there protection against credential stuffing?
- Auth state management: is there a path where a stale auth state
  could be displayed (e.g. showing the admin UI for half a second
  after logout)?

**General security hygiene**
- Are there any auth-related secrets hardcoded? (Phase 0 already
  rotated, but worth re-checking now that we know how.)
- Is HTTPS enforced on auth endpoints?
- Are auth errors specific enough to leak info? ("Email not found"
  vs "Invalid credentials" — the former enables enumeration.)
- Are there debug or development-only auth bypasses that could be
  reachable in production?

## Production data access

Same pattern as Area 2: surface for explicit approval before any
prod query. Use `.env.prod-readonly` for the connection. Aggregates
only — no row-level PII queries on `educators`, `users`, or
`magic_links`. Specifically useful prod queries you might propose:

- Counts of expired-but-not-cleaned-up magic links
- Distribution of `MagicLink.expires_at` to confirm expiry policy
- Counts of admin actions by `changed_by` in `BookingStatusLog`
  (aggregate only)
- Whether any educator confirm_tokens are older than their intended
  lifetime

Propose, wait for approval, then run.

## Working style

- **Batch-and-confirm** as before.
- **Severity calibration for auth is strict.** A missing rate limit on
  the 6-digit code is `code-quality:critical`. A magic link that can
  be replayed is `code-quality:critical`. An overly informative auth
  error message that enables email enumeration is
  `code-quality:moderate`. A confusing variable name in a session
  helper is `code-quality:nice-to-have`.
- **Agent-friendly is rare in auth.** Anything touching token
  generation, session handling, authorization checks, or rate
  limiting is NOT agent-friendly. Cosmetic refactors of error
  message wording might be. The category is "small, well-bounded,
  no security judgment required" — most auth findings fail at least
  one of those.
- **Stop-the-line is most likely here of any area.** If you find:
  - A route that should be protected but isn't
  - A token replay vulnerability
  - A path where authorization is missing entirely
  - Credentials or tokens being logged in plaintext
  - A way to escalate from educator to admin (or unauthenticated to
    authenticated) through the API
  ...surface immediately. We fix inline before continuing the audit.

## End-of-session report

Save as `docs/pilot/phase-1-area-3-report.md`. Same shape as previous
reports. Add one section specific to this area:

**"Auth model summary."** A clear, concise statement of how auth
actually works in this project right now: who can authenticate,
what session/token mechanism is used, what the authorization
boundaries are, what state transitions an account can go through
(unauthenticated → educator pending → educator confirmed → educator
expired → educator re-verified, plus the admin path). This becomes
a reference document for every future change to auth code. If the
audit reveals that the *intended* model differs from the *actual*
model, both should be documented with the gap called out.

## Scope estimate

This is the smallest of the six areas per the audit plan, but the
risk density is the highest. Expect 1-2 hours of focused work and
5-10 issues filed. The smaller volume estimate is appropriate because
auth code tends to be either correct or dramatically wrong — there's
less "convention drift" territory than in models or services. If
you're approaching 15+ findings, either the auth surface is much
larger than I think, or you've drifted into Area 6 admin-UI
territory.

Begin by:
1. Reading the audit plan, the Area 1 and Area 2 reports (especially
   newly-observed for Area 3), and the Phase 0 report's auth-relevant
   findings if any.
2. Mapping the actual auth surface: list every route, every middleware,
   every dependency, every state transition. The map itself is half the
   audit — many auth bugs are about gaps in the map.
3. Proposing a session structure. My suggestion: build the auth model
   summary first (read everything, produce the section that goes into
   the report), then audit against it. The summary doubles as the
   mental model the audit uses.

Wait for my approval on the structure before starting any prod queries.
