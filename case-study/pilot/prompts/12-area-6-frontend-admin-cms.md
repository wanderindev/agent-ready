We're starting Phase 1 Part B Area 6: Frontend admin CMS.

This is the final Phase 1 audit area. After this, the next session is the
Phase 1 synthesis report.

Read these first:
- docs/pilot/phase-1-area-5-report.md, especially the "Newly observed for
  Area 6" subsection — Area 5 mapped the admin surface and left specific
  pointers (12 admin pages, services/admin.js at 26 KB, components/admin/*
  including TipTap RichTextEditor and AG Grid renderers, AdminAuthContext,
  AdminLayout)
- docs/pilot/phase-1-area-3-report.md — admin authentication and the
  admin route protection model live here
- Issue #18 (2.6 MB bundle) — Area 5 confirmed this is largely admin code
  shipping to public visitors; #18 is shared between Area 5 and Area 6
- Issue #57 (admin tokens in URL query strings) — Area 3's finding that
  may have frontend admin implications
- Issue #58 (no admin route protection beyond client checks) — same
- The "Newly observed for Area 5 / Area 6" subsections of earlier reports

## Why this area matters

The admin CMS is the operator's daily tool. Diego (and you) drive every
piece of content through it. Bugs here cost productivity rather than
user trust, but the blast radius per finding can be high because admin
actions touch production data directly.

Three differences from the public-site audit (Area 5):

1. **User population is bounded — Diego plus you.** Single-digit. That
   changes the cost-benefit on every finding. A papercut a public user
   hits once is a real issue; a papercut Diego hits 50 times a day is
   urgent. A papercut Diego hits once a year and works around is not.

2. **Failure modes shift toward "operator can't do their job" rather
   than "user sees broken UI."** Stuck states, mysterious errors, lost
   work in editors, mis-saved drafts.

3. **Security is internal but still consequential.** Admin actions
   touch production. An admin route that doesn't actually require
   admin (Area 3 #58 territory) or a frontend that loses unsaved
   editor state has real cost.

## Scope

In-scope files:
- `frontend/src/pages/admin/*` (12 pages per Area 5)
- `frontend/src/components/admin/*` (TipTap RichTextEditor, AG Grid
  renderers, MediaPickerModal, anything admin-specific)
- `frontend/src/services/admin.js` (the 26 KB service module Area 5
  didn't open)
- `frontend/src/contexts/AdminAuthContext` and `AdminLayout`
- Any admin-specific Pydantic schemas only used by these pages
- The interaction surface between admin frontend and the backend
  admin routes (cross-reference with Area 3's auth findings)

Out of scope:
- Public site (Area 5 done)
- Backend code (Areas 1-4 done)
- Checkout/booking pages (Area 2 done)
- The shared layout components Area 5 already covered (AppShell,
  Navbar, Footer)

## What to look for

**Admin route protection on the frontend**
- AdminAuthContext: what does it check on mount? What does it do on
  failure (redirect to login, blank page, error)?
- Race conditions: does any admin page render sensitive data *before*
  the auth check resolves? Area 5 flagged this as worth verifying.
- AdminLayout's gating: is every admin route actually wrapped, or
  are there routes that bypass it?
- Logout: does it actually clear all admin state, or just the token?
  Stale data in memory after logout is a leak.

**TipTap RichTextEditor**
- Unsaved-changes protection: does navigating away from an edit lose
  work? Is there a confirmation prompt? An autosave?
- The HTML output: per Area 5's #111 finding, article content is
  rendered with `dangerouslySetInnerHTML` without sanitization on
  the public side. Does TipTap on the admin side produce HTML that
  reaches the public site unchanged? If yes, the HTML sanitization
  story has two endpoints: where it's created (here) and where it's
  rendered (#111, public side).
- Paste behavior: pasting from Word/Google Docs typically injects
  garbage HTML/style attributes. Does TipTap clean this, or does it
  pass through to storage?
- Image insertion: how does the editor reference images? URLs to DO
  Spaces? Inline base64? Are there orphan-image risks (image
  uploaded, then editor never saves)?

**AG Grid usage**
- AG Grid is the largest admin dependency. How is it configured?
  Server-side row model, client-side, infinite scroll?
- Are large grids paginated on the backend or do they fetch the
  whole table client-side? (The latter scales poorly past a few
  thousand rows; relevant for blog research and article suggestion
  lists.)
- Cell renderers: any that do expensive computation on every render?
- Sorting and filtering: backend-driven or frontend-only? If
  frontend-only on a large dataset, that's a UX issue.

**Admin services and state**
- services/admin.js at 26 KB — what's in it? Look for:
  - Inconsistent error handling vs the public services (Area 5 #107
    found educators.js and subscribe.js skip response.ok; verify
    admin.js doesn't have the same gap or has a different one)
  - Hardcoded URLs that should be env-driven
  - Functions that do too much (god functions)
  - Duplicated logic across functions (paste-mode rather than
    extract-helper)
- Admin state management: any global stores (Redux, Zustand, Context)?
  If state is scattered across many contexts, where does it
  duplicate?

**Editor and form UX**
- Long-running operations: research generation, article writing,
  edu material generation can take minutes. Does the UI show
  progress? Allow cancellation? Survive a page refresh mid-operation?
- Optimistic updates: any places where the UI updates immediately
  on a click and then has to roll back if the backend rejects?
- Error surfacing: when a backend call fails, does the admin see a
  specific error message or a generic toast?

**Code splitting (shared with #18)**
- Area 5 confirmed the production bundle is one 2.65 MB chunk and
  the admin code is the bulk of that. The admin track owns the
  code-splitting work. Specifically:
  - Route-level: every admin route should lazy-load
  - Component-level: TipTap and AG Grid should both load only when
    the editor or grid pages mount
  - The natural split is the public/admin route boundary, which is
    one PR serving both #18 and any Area 6 admin code-splitting
    finding
- Don't file a separate code-splitting issue for admin — annotate
  #18's scope to reflect the admin track ownership.

**Security on the admin side**
- Admin tokens in URLs (Area 3 #57): does the frontend pass admin
  tokens via query string anywhere? Headers preferred.
- CSRF: does the admin backend require CSRF tokens for state-
  changing operations, and if so, does the frontend send them?
- Admin actions that touch production data: any that lack
  confirmation prompts? "Delete article" without a confirm is a
  classic operator-error vector.
- The educator-access cluster (Area 3 #50/#52, Area 5 confirmed
  cosmetic on frontend): is the admin UI for educator management
  any better, or does it have the same client-trust shape?

**Things from earlier areas to verify**
- Area 3 #57 (admin tokens in URL): confirm or refute on the
  frontend admin side
- Area 3 #58 (no admin route protection beyond client checks):
  this is partly a backend finding (Area 3 covered) and partly a
  frontend question (does the frontend assume the backend will
  reject unauthorized requests, or does it duplicate the check
  client-side and trust it?)
- Area 2 cart persistence pattern: any admin equivalents
  (draft article persistence, unsaved edit recovery)?
- Sentry config: Area 5 noted `sendDefaultPii: true` on the
  frontend. Same configuration covers admin pages. Don't re-file;
  reference.

## Working style

- **Batch-and-confirm** as before.
- **Severity calibration:** A bug that loses operator work
  (unsaved edits, mid-flight pipeline state) is moderate to critical
  depending on recoverability. A bug that lets non-admin users
  reach admin pages is critical. UX papercuts the operator hits
  daily are moderate; rare ones are nice-to-have. The "user
  population is bounded" framing means frequency matters more than
  it does on the public side.
- **Agent-friendly is moderately available.** Cosmetic refactors,
  hardcoded-string migrations, missing confirmation prompts, single-
  file fixes are typically agent-friendly. State management
  changes, editor configuration, route protection refactors are
  not.
- **Stop-the-line:** An admin route that's reachable without auth.
  An XSS vector reachable through admin actions. A path where
  admin tokens leak (logs, URLs, error pages). An operation that
  destroys data without confirmation and has no undo.
- **No prod data access this session.** Same as Area 5 — frontend
  audits don't need it.

## Fix-ordering section

Yes, include one. This is the fourth (after edu, article, public
frontend). Same format. The admin-track issues filed in this
session, plus pre-existing issues that touch the admin frontend:

- #18 (bundle / code-splitting) — admin track owns this
- #57 (admin tokens in URL) — confirm or refute frontend side
- #58 (admin route protection) — frontend half of an Area 3 finding
- Any Area 5 issues that materially affect admin (probably few —
  Area 5 was scoped to public)

## "Toward a global fix ordering" continuation

The fourth and final bridge section before the Phase 1 synthesis.
Same format as Area 5's. Identify:

- Where the admin track is independent of other backlogs
- Where it interacts (the code-splitting work shared with Area 5,
  the admin-auth work shared with Area 3, the TipTap HTML
  sanitization story shared with #111 backend-side)
- Where shared foundations slot in (admin work has no LLM
  foundation dependency — it's a UI layer — but check whether
  any admin pages depend on services-layer work that's still in
  progress)

After this section, the Phase 1 final report has all four bridge
sections as inputs for the global synthesis.

## End-of-session report

Save as `docs/pilot/phase-1-area-6-report.md`. Same shape as
previous reports. Required sections:

- Executive summary
- By-the-numbers
- What was audited
- Item-by-item findings
- Stop-the-line discussion
- What's filed vs deferred
- Newly observed (for the Phase 1 synthesis report specifically,
  not for further audit areas — there are none after this)
- What surprised me
- Process notes for the Phase 1 final report
- Fix ordering for admin frontend
- Toward a global fix ordering

The "Newly observed" section in this report has a different role
than the previous ones: it's no longer feeding the next audit; it's
feeding the synthesis. Specifically capture:

- Cross-cutting findings that haven't been filed as issues but
  belong in the synthesis report (e.g. the partial-correction
  pattern, which Area 5 flagged as the fourth instance — a fifth
  might surface here)
- Reference documents this audit produces or refines (the admin
  surface map, any admin-specific failure-mode notes)
- Things to verify or close out before the synthesis report can
  be written (e.g. the function-local-import correction Area 4b-2
  flagged for the module inventory)

## Scope estimate

Bounded but not trivial. Expect 1.5-2 hours and 6-10 issues filed.
The admin frontend is the largest single contributor to the bundle
(per Area 5) but most of its complexity is in two third-party
components (TipTap, AG Grid) that have their own behaviors and
quirks rather than being deep custom code. The audit walks the
admin pages, characterizes the editor and grid usage, and files
specific concerns.

If you're approaching 15+ findings, you've drifted into re-auditing
public-side code or into territory that's actually backend
(admin.js makes API calls, but those endpoints' behaviors are
backend findings, already covered).

Begin by:
1. Reading the inputs above, especially Area 5's admin-surface
   notes and Area 3's admin-auth findings
2. Mapping the admin route structure (12 pages per Area 5; verify
   the count and list them)
3. Identifying the audit walk order — probably: AdminAuthContext
   and route protection first (foundational), then services/admin.js
   (cross-cutting concerns), then TipTap editor (highest UX stakes),
   then AG Grid usage (performance + correctness), then per-page
   surface checks
4. Proposing the session structure

Wait for my approval on the route map and walk order before
starting the per-page audit.
