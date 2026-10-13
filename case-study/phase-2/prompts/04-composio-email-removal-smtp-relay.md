# Phase 2 — Session 04: Composio email removal (SMTP relay) + cluster-B contract cleanup

## Identification

You are running **Phase 2 Session 04** of the Panama In Context (PIC) audit-and-fix pilot. Phase 2 is the **fix-execution** phase — Phase 0 (baseline + safety nets) and Phase 1 (the area-by-area audit) are complete; Phase 2 ships fixes through PRs against the labelled backlog. Sessions 01 (kickoff), 02 (articles 39/40 cleanup + safety-net), and 03 (full #99 fix) have already shipped. The Phase 2 working model (auto-approve fence, prompt-preservation, outcomes log, cross-session register) is established and operational.

You are running in a **fresh Claude Code instance**, separate from the orchestrator's main session. The orchestrator preserves their context window to review your work and brief subsequent sessions. Everything you need is in files this prompt points at — do not assume conversational context.

**This is an urgent session.** Composio (the third-party wrapper PIC uses for Gmail) had a vendor breach in May 2026; the operator rotated the Gmail API key, but the new key has not been re-attached to OAuth for `diego@panamaincontext.com` because the Composio dashboard section for that operation is down (still recovering from the breach). **Email sending is broken in production right now.** Contact-form submissions, order confirmations, mailing-list confirmation emails, educator access codes — all failing silently because of the bug that `composio_client.send_email` returns `True` even on Gmail-side failures (issue #67, filed `critical`).

This session restores email sending and cleans up most of cluster B (the Composio-contract cluster from snapshot §6-B) in one PR.

## Read these first, in order

Read each one fully before proposing a plan. Don't skim.

1. **`docs/phase-2/01-kickoff-report.md`** — the Phase 2 working model. Especially the auto-approve fence sections.
2. **`docs/phase-2/02-articles-39-40-cleanup-report.md`** and **`03-issue-99-full-fix-report.md`** — the two prior fix-work sessions. They establish the session-shape conventions you'll mirror: gated phases, in-session asserts, PR-open outcomes-log row, session report at end. Note especially session 02's "auto-approve fence earned its keep" process notes and session 03's "splitting commit 2 and commit 3 was worth the small extra effort" framing.
3. **The cluster-B issues**, in order:
   - **#67** (critical) — `composio_client.send_email` returns True when Composio reports Gmail-side failure. **This is why emails are silently failing in prod right now.**
   - **#68** (critical) — No explicit timeouts on Composio, DeepL, or Anthropic SDK calls. (This session addresses the SMTP/email half; the DeepL/Anthropic halves are out of scope.)
   - **#70** (moderate) — `notifications.py` misuses `_send_email` bool return; `customer_sent or admin_sent` (short-circuits), discarded admin return.
   - **#74** (moderate) — `mailing_list` Sheets helpers return bool; subscribe/confirm/unsubscribe discard it.
   - **#59** (critical) — Educator email-dispatch failures silently swallowed; user told "check your email" but no email arrives.
   - **#37** (moderate) — Email/notification dispatch failures silently swallowed in payment flow.
   Run `gh issue view 67`, etc., and read each body.
4. **`backend/app/services/composio_client.py`** (full file) — the wrapper you're replacing.
5. **`backend/app/services/notifications.py`** (full file) — 6 send_email call sites. The biggest caller-side change.
6. **`backend/app/services/educator_service.py`** (focus lines around `send_email` use) — 2 call sites (`_send_confirmation_email`, `_send_verify_code_email`).
7. **`backend/app/services/mailing_list.py`** — 1 send_email call site (the `_send_confirmation_email` near the top of the file). **Sheets calls are OUT of scope** for this session (session 05 handles them); leave the `get_composio()` / `composio.tools.execute("GOOGLESHEETS_*")` calls alone.
8. **`backend/app/api/contact.py`** — 1 send_email call site.
9. **`backend/app/core/config.py`** and **`backend/.env.example`** — current Composio settings + sender config.
10. **`.claude/settings.json`** — the auto-approve fence. The deny rules will fire on prod-touching commands; surface for approval, don't fight them.
11. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log; you'll append rows when the PR opens.
12. **`docs/methodology/cross-session-register.md`** — append entries only for genuine cross-session decisions.
13. **`CLAUDE.md`** — project conventions. Update the "Email" portion of the tech-stack table to reflect SMTP relay instead of Composio Gmail once the work lands.

## Why this session matters

**Emails are silently failing in production right now.** The Composio breach moved cluster B from "filed-critical-but-dormant" (per Phase 1 reasoning) to "live and actively firing." Synthesis §8's two-dimensional severity check — blast-radius × evidence-of-impact — was already at critical-blast-radius; the breach moved evidence-of-impact to "every email is failing right now."

This session resolves that. It also takes the opportunity to clean up most of cluster B in the same PR — flipping the contract from `bool` (silent on failure) to `raise on failure` is the same change that resolves #67/#70/#74/#59/#37. Doing the contract flip alongside the implementation swap is the natural shape, and it follows the **cleanup-then-refactor sequencing pattern** the orchestrator added to the cross-session register on 2026-05-25 (after sessions 02 + 03 demonstrated it). Session 04 is the next instance of that pattern: the urgent-broken-thing fix + the structural contract cleanup land together.

## Scope

### IN scope

- **Replace `composio_client.send_email` implementation** with SMTP via Google Workspace's SMTP relay (`smtp-relay.gmail.com:587`, STARTTLS). The operator will allowlist the production droplet's IP address in Workspace admin (Apps → Google Workspace → Gmail → Routing → SMTP relay service) out-of-band — surface this dependency in Phase 1 planning and confirm it's been done before any prod cutover.
- **Flip the email-sending contract** from `(to, subject, body) -> bool` to `(to, subject, body) -> None; raise EmailDeliveryError on failure`. Define `EmailDeliveryError` in the same module; Sentry-capture the exception at the wrapper layer.
- **Use Python stdlib `smtplib` + `email.mime`** for the SMTP transport. No new dependencies. Set explicit timeout (e.g., 10 seconds) on the SMTP connection — this resolves the SMTP/email half of #68.
- **Update all 10 caller sites** to handle the new contract (10 sites = 6 in `notifications.py` + 2 in `educator_service.py` + 1 in `mailing_list.py._send_confirmation_email` + 1 in `api/contact.py`):
  - Some callers (e.g., `notifications.py`'s `customer_sent or admin_sent` short-circuit, `mailing_list._send_confirmation_email` returning bool, `api/contact.py` recording `submission.email_error` on failure) need restructuring: catch `EmailDeliveryError`, log via Sentry, record the failure in the appropriate persistence layer (e.g., `submission.email_error`), surface the user-visible outcome appropriately. **Don't silently drop the new exception** — the whole point is fail-loud.
  - Some callers (e.g., the educator-service `send_email` calls in `_send_confirmation_email` and `_send_verify_code_email`) need to propagate the failure to the API layer so the user sees an honest "we couldn't send the email — try again" response instead of "check your email" when no email was sent (issue #59).
- **Add tests** for the new `send_email` implementation (mock `smtplib.SMTP`) and for the caller-site behavior changes. At minimum: happy-path; SMTP connection failure raises `EmailDeliveryError`; auth failure raises; timeout raises. Use the existing test conventions from `backend/tests/`.
- **Two new env vars in `.env.example`** (and document in `CLAUDE.md`): `SMTP_RELAY_HOST` (default `smtp-relay.gmail.com`), `SMTP_RELAY_PORT` (default `587`). The relay does **not** require username/password when the source IP is allowlisted — confirm this with the operator during Phase 1 planning before adding any auth config. If auth is required after all, add `SMTP_USERNAME` / `SMTP_PASSWORD` to the env-var list (the password lives in DigitalOcean droplet env only — `.env*` writes are denied by the fence).
- **Remove `composio` from the email path** but **keep `composio` in `requirements.txt`** and **keep `get_composio()` in `composio_client.py`** for now — `mailing_list.py` still uses it for Sheets in this PR. The full `composio` removal happens in session 05.
- **PR opens; do not merge.** Append rows to the outcomes log (one per closed issue) when the PR opens. Open a comment on each closed issue linking the PR. Session report at `docs/phase-2/04-composio-email-removal-report.md`.

### OUT of scope (do NOT touch)

- **Sheets-side Composio calls** in `mailing_list.py` (`_find_row`, `_append_row`, `_update_row`). Session 05's job.
- **DeepL and Anthropic timeouts** — the other half of #68. Keep #68 open after this PR with a comment noting which half landed.
- **Issue #80** — `mailing_list._send_confirmation_email` uses raw f-string HTML, parallel to closed #31. Same file but a separate concern (Jinja2 migration); defer to a focused PR.
- **Dropping `composio` from `requirements.txt`** — session 05.
- **The full Educator Access System** (the gate flow with confirmation links, 6-digit codes, etc.) — out of scope. This session only fixes the email-sending wrapper that the educator-service currently calls.
- **Any frontend changes** unless an API response shape changes in a way the frontend already handles (the existing `admin.js:341-351` pattern from session 03 should keep working).

## Plan — four phases, gated step-by-step

### Phase 1 — Local prep (no prod touch, no code writes until approved)

1. Read the inputs above in order. Don't skim.
2. Confirm the cluster-B issue bodies match the current code (10 call sites; the bool-discard patterns; the swallowed failures).
3. Produce a **plan** that specifies:
   - The new `EmailDeliveryError` class signature and module location.
   - The new `send_email` implementation outline (SMTP connection lifecycle, timeout handling, From header construction, STARTTLS).
   - For each caller site: the before/after shape (what it does today; what it'll do after the contract flip).
   - The test list (mock cases).
   - The env-var additions and the `.env.example` / `CLAUDE.md` updates.
   - The Workspace-allowlist dependency: confirm with the operator whether the droplet IP is already allowlisted, OR surface the need so the operator can do it before Phase 3.
4. **Surface the plan and WAIT for operator approval before any code write.**

### Phase 2 — Local implementation + tests

Once Phase 1 is approved:

1. Create the feature branch: `fix/composio-cluster-b-smtp-relay`.
2. Implement `EmailDeliveryError` and the new `send_email` in `backend/app/services/composio_client.py` (or rename the module if you prefer — `email_sender.py` would be more honest now, but the rename inflates the PR; keep the filename for this PR and consider renaming in a follow-up).
3. Update each caller site one logical group at a time, keeping the test tree green between groups. Suggested commit boundaries:
   - Commit 1: `send_email` reimplementation + `EmailDeliveryError` + new tests.
   - Commit 2: `notifications.py` caller updates (6 sites).
   - Commit 3: `educator_service.py` caller updates (2 sites) + any API-layer changes to surface the failures honestly.
   - Commit 4: `mailing_list.py._send_confirmation_email` + `api/contact.py` caller updates.
   - Commit 5: `.env.example` + `CLAUDE.md` doc updates.
4. Run the test suite. If `testcontainers` fixtures fail under `docker-compose exec backend pytest` (per session 02/03 reports and issue #139), run from the host as the prior sessions did. Surface the workaround in the session report. **All tests must pass before pushing.**

### Phase 3 — Production cutover

This is where the auto-approve fence will fire repeatedly. Each prod-touching command surfaces for explicit per-invocation approval.

1. **Confirm with the operator** that the droplet IP is allowlisted in Workspace admin. The operator handles this out-of-band (it's a Google admin console action, not a Claude-Code-tool action). Do NOT proceed to step 2 until confirmed.
2. **Surface for operator approval**: the env-var changes that need to land on the production droplet (`SMTP_RELAY_HOST`, `SMTP_RELAY_PORT`, optionally auth credentials if allowlist alone is insufficient). `.env*` writes are denied by the fence; the operator updates the prod `.env` out-of-band, you don't.
3. **Deploy.** Production deploy routes through the `deploy` skill (which is L2 fence-gated). The skill builds the new image, pushes to the DO registry, and Watchtower pulls within ~5 minutes. Surface the deploy step for explicit operator approval. The fence's `Bash(docker push registry.digitalocean.com*)` deny rule will fire — that's expected.
4. **Smoke test in prod** — trigger one safe email path (e.g., a contact-form submission with `diego@panamaincontext.com` as the recipient, NOT a real customer's email) and verify the email lands. Use the `database-ops` skill if you need to inspect any DB state post-deploy.
5. If the smoke test fails, surface the failure; do not retry blindly. The most likely failure modes: IP not yet allowlisted; sender-email-not-allowed; DNS-not-propagated; auth-required-after-all. Each has a different fix.

### Phase 4 — PR + housekeeping

1. Push the branch. Open the PR. **Do not merge.** The `gh pr merge*` deny rule will block you anyway.
2. PR description must include a **"Production touch: yes — gated by:"** line per Phase 2 working-model L3. List each gate that fired: the fence's deny rules, the Workspace IP allowlist requirement, the `deploy` skill mediation, the per-invocation approvals.
3. **Append rows to `docs/phase-2/agent-friendly-outcomes.md`** when the PR opens. One row per closed issue (#67, #70, #74, #59, #37; partial-close on #68 with a note). Each row: `Filed agent-friendly?: no`; `Agent attempted?: pair`; `PR #: <the PR>`; `Outcome: not-yet-attempted` (update at merge per PR-#135-shape convention).
4. **Comment on each closed issue** linking the PR.
5. **Write the session report** at `docs/phase-2/04-composio-email-removal-report.md`. Mirror the shape of sessions 02 and 03's reports (executive summary; by the numbers; what was done; what's next; process notes; what surprised me; cross-cutting checklist dispositions).
6. **Update `docs/phase-2/prompts/INDEX.md`** to add the session 04 entry and reflect the produced report's actual path.
7. **Append to the cross-session register** if a genuine cross-session decision crystallized (e.g., a methodology pattern; a re-scope; a stop-the-line). Don't force one — most fix-sessions don't need them.

## Production data access policy

- **No production database reads** are required for this session. The fix is pure code + env var changes. If you find yourself reaching for `database-ops` for a prod query, you've drifted — surface and pause.
- **Email send is the prod touch**, mediated by the deploy. The Phase-3 smoke test is the explicit acceptance criterion; pick a low-blast-radius email path (contact form to Diego himself) for the smoke test.
- **Do not edit `.env*` files** under any path. The fence denies it. Surface the required env-var changes; the operator applies them.

## Working style

- **Gate-at-each-phase.** Phase 1 → Phase 2 → Phase 3 → Phase 4. Each phase ends at an operator-approval surface. Don't bundle Phase 2 implementation with Phase 3 deploy.
- **Don't expand scope.** No DeepL/Anthropic timeouts. No Jinja2 #80 work. No Sheets removal. The temptation will be present; resist. Surface as process notes if relevant.
- **Fail-loud is the whole point of the contract flip.** If you find yourself writing `try: send_email(...) except: pass`, you've recreated #67. Caller sites either propagate the exception, persist the failure (e.g., `submission.email_error`), or surface to the user honestly — never swallow.
- **Sentry-capture at the wrapper layer.** Use `sentry_sdk.capture_exception(...)` inside the `except` block before re-raising in `send_email`. Each caller then doesn't need to re-Sentry — the wrapper does it.
- **Tests pass locally before push.** ruff clean on changed files. Match session 02/03's bar.
- **PR opened, not merged.** Operator merges.

## Stop-the-line triggers

If any of these fire during the session, STOP and surface immediately:

- The Workspace IP allowlist isn't in place by Phase 3 time. **Halt the deploy.** Don't deploy with broken email and hope the allowlist lands in flight; the smoke test will fail and there's no point.
- The SMTP relay rejects the connection from the droplet IP with `530 Authentication required` (or similar). This means the allowlist isn't sufficient and auth is needed — surface for operator decision (generate app password? configure XOAUTH2? add full SMTP credentials?).
- A caller-site change reveals a downstream consumer (e.g., a frontend that depends on a specific bool-return shape, or a test that asserts the bool). Stop and surface; the contract flip's blast radius needs to be visible.
- The deploy goes through but the smoke test still fails. Don't retry. Diagnose. Possible causes include: DigitalOcean droplet's outbound port 587 not open (firewall); image not actually pulled by Watchtower; env vars not actually present in the container; cached connections to old composio_client.

## Scope estimate

~1 session, 1 PR. **5-6 commits** in the PR. Should close **#67, #70, #74, #59, #37** outright; **#68** partially closed (SMTP-side timeout landed, DeepL/Anthropic deferred — comment on #68 explaining the partial close). Session 05 (Sheets removal, drop `composio` from `requirements.txt`) follows this one.

If by the third hour you haven't done the prod smoke test, something's wrong — surface for re-scoping.

## Begin by

1. Read the inputs in the order listed in "Read these first." Don't skim.
2. Confirm the cluster-B issue bodies against the current code (10 call sites; the bool-discard patterns).
3. Produce a Phase-1 plan with: the new exception + wrapper API; the per-caller before/after; the test list; the env-var additions; the Workspace-allowlist confirmation.
4. **Wait for operator approval on the Phase-1 plan before any code write.** The plan goes to the operator; the operator approves or pushes back; then Phase 2 begins.
