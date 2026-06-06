This is a Phase 1.5 detour — a single-session, single-PR fix for issue #31
(HTML injection in notification emails). We're interrupting the Phase 1
audit sequence because #31 is a live, exploitable vulnerability on a
public unauthenticated endpoint that targets the admin inbox. The Area 2
report flagged this as stop-the-line and the operational decision at
the time was file-and-continue. We're correcting that now before
starting Area 3.

Read these first for context:
- The full text of GitHub issue #31
- The relevant section of docs/pilot/phase-1-area-2-report.md
- `backend/app/services/notifications.py` end to end
- docs/pilot/agent-friendly-criteria.md (the stop-the-line policy
  specifically)

## Goal

Eliminate HTML injection from all notification emails. The exploit path
is: an attacker POSTs an order with HTML-injected `customer_name` (or
any other attacker-controlled field), the notification service renders
that field into an HTML f-string template, the admin receives a
legitimate-looking email from a trusted internal sender, and the
injected HTML renders in their inbox — enabling phishing from a
trusted source.

The fix is to escape every attacker-controllable value before it
enters the email body. The right way to do this is migrate the HTML
templates to Jinja2, which auto-escapes by default. This also
addresses the broader template-quality concern that the Area 2 report
queued for Area 4, but we're doing it now because the security fix
and the template migration are the same change.

## Scope

In-scope:
- All HTML email templates currently constructed via f-string in
  `backend/app/services/notifications.py`. Migrate each to a Jinja2
  template.
- The plumbing changes to render Jinja2 templates from the
  notifications service (template loader, environment config, file
  layout).
- Tests for the notification service that specifically cover the
  injection vector — at minimum, one test per template confirming
  that HTML-bearing input is escaped in the rendered output.
- Updates to any caller that needs to change due to API shifts in
  the notification methods (probably none — the public method
  signatures shouldn't change).

Out of scope (defer to the Area 4 notifications work):
- Refactoring the structure of the notification service itself
  beyond what the Jinja2 migration requires.
- Adding new notification types.
- Changing what triggers notifications.
- Touching the Composio Gmail wrapper or the swallowed-error pattern
  (that's #37 and is a separate fix).
- The `paypal_service.cancel_invoice` swallowed-exception pattern
  flagged for Area 4.
- Plain-text email body changes unless they also have an injection
  vector (they probably don't — plain text doesn't render HTML —
  but verify).

If you find that the Jinja2 migration *requires* touching something
on the out-of-scope list to be coherent, stop and tell me. Don't
expand scope unilaterally.

## Approach

1. **Inventory.** Read `notifications.py` end to end and list every
   HTML template currently rendered, every variable interpolated
   into each template, and which of those variables are
   attacker-controllable (originating from request bodies or other
   untrusted sources). Show me this inventory before writing any
   code. The list defines the surface of the fix and the surface
   of the tests.

2. **Template structure.** Propose a directory layout for the
   Jinja2 templates (probably `backend/app/templates/email/` with
   one `.html` file per notification, or one per template family).
   Show me the proposal before creating files.

3. **Migration.** Convert each template to Jinja2, verify
   auto-escaping is on (it's the default for `.html` templates in
   Jinja2's `Environment` with `autoescape=select_autoescape(['html',
   'xml'])`), and update the calling code in `notifications.py` to
   render via the template loader.

4. **Tests.** For each template, write a test that:
   - Renders the template with an attacker-controlled value
     containing HTML payload (e.g. `<script>alert(1)</script>`
     or `<a href="https://evil/">Click</a>`)
   - Asserts the rendered output contains the escaped form
     (`&lt;script&gt;`) and does NOT contain the raw HTML
   - Confirms legitimate values still render correctly (sanity
     check the migration didn't break the happy path)
   
   These tests are the regression gate — if anyone re-introduces
   an injection vector later (e.g. by using `{{ var | safe }}` or
   constructing HTML in the calling code), the tests should catch
   it.

5. **Verification.** Run the full test suite. The 99 passing
   tests should stay passing. The new tests should pass. CI on
   the PR should be green.

## Working style

- **Show inventory and proposed structure before writing code.**
  Same show-before-act pattern as the previous sessions. The
  inventory in particular is load-bearing — if it misses a
  template, the fix is incomplete.
- **Don't merge from your end.** Open the PR, link it to issue
  #31 with `Fixes #31`, let me review and merge.
- **PR title:** `fix: escape HTML in notification email templates
  (closes #31)`.
- **PR description:** Brief — explain the vulnerability, the fix
  (Jinja2 migration), what's in scope and what's not, link to the
  Area 2 report section that originally surfaced this.

## Stop-the-line within this session

If during the migration you discover *additional* injection vectors
that weren't covered by #31 — e.g. another endpoint also reflecting
unescaped input into email — surface immediately. Either expand
the PR to cover them (small additional scope is fine if the fix
is the same shape) or file a follow-up issue if the fix is
substantially different. Tell me which you'd recommend before
acting.

## End-of-session note

When the PR is up, write a 1-page note as a comment on the PR (not
a separate file) summarizing:
- What templates were migrated
- What attacker-controllable fields are now escaped
- What tests were added
- Anything you noticed during the migration that should feed back
  into the Area 4 notifications audit

This becomes the record that the stop-the-line fix actually happened,
and the seed for Area 4's deeper notifications work.

Begin with the inventory. Wait for my approval before proposing
the template structure.
