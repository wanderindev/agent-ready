# Phase 2 — Session 04 Report: Composio email removal (SMTP relay) + cluster-B contract cleanup

**Date:** 2026-05-25
**Duration:** ~1 session (Phase 1 plan → Phase 2 implement → Phase 3 prod cutover → Phase 4 PR)
**Prompt:** `docs/phase-2/prompts/04-composio-email-removal-smtp-relay.md`
**PR:** [#143](https://github.com/wanderindev/panama-in-context/pull/143)

---

## Executive summary

Urgent session triggered by the Composio vendor breach in May 2026 — the production email path had been silently failing for unknown duration because `composio_client.send_email` returned `True` regardless of whether Gmail actually accepted the message (issue #67's structural bug). Five-commit PR that:

1. Replaces `composio_client.send_email`'s Composio Gmail call with a direct Python-stdlib SMTP submission to Google Workspace's `smtp-relay.gmail.com:587` over STARTTLS. No new dependencies. Explicit 10-second timeout (resolves the SMTP half of #68).
2. Flips the email-sending contract from `(to, subject, body) -> bool` (silent on failure) to `(to, subject, body) -> None; raise EmailDeliveryError on failure`. Wrapper Sentry-captures the underlying exception before re-raising, so caller sites do not need to re-capture.
3. Updates all 12 caller sites across `notifications.py` (8 sites), `educator_service.py` (2), `mailing_list.py` (1), `api/contact.py` (1) — and the 6 API-layer try/except wrappers in `orders.py`, `booking_admin.py`, `webhooks.py`, `auth.py` that were swallowing notification failures (#37). The bare `except Exception` clauses become typed `except EmailDeliveryError`; behavior is unchanged at the API layer but intent is now explicit and truly-unexpected exceptions no longer get swallowed.
4. Adds 13 new tests (8 wrapper + 5 dispatch-behavior) covering happy path, transport failures, auth failure, OS-level failures, timeouts, and the contract semantics across `NotificationService`'s customer/admin dual-recipient methods.
5. Updates `CLAUDE.md` to reflect the SMTP-relay reality (Composio remains listed for the Sheets path until session 05).

**Issues addressed (6 total):** #67 (critical), #70 (moderate), #74 partial (moderate), #59 (moderate), #37 (moderate) close on PR merge; #68 partial — the SMTP timeout half landed, DeepL/Anthropic halves deferred to follow-up.

The session was deliberately gated step-by-step. Two friction moments — both anticipated by the brief, both resolved cleanly:

- **The operator's `.env.example` change removed COMPOSIO_API_KEY entirely**, not just the SMTP_RELAY_* additions. Surfaced before deploy; operator confirmed Composio key was also removed from the production droplet's actual `.env`. The Sheets path was already broken via Composio's own breach (the dashboard section needed to reconfigure the Gmail OAuth was down) — removing the key shifts the failure shape from "opaque Composio error → 500" to "`RuntimeError('COMPOSIO_API_KEY not configured') → 500`" with the same net outcome (mailing list 500s until session 05 lands the DB migration). Decision: proceed; the Sheets path was already non-functional pre-deploy.
- **The fence's L1 `Bash(docker push registry.digitalocean.com*)` deny rule fired** as designed when I attempted the push. The fix was the session-02 pattern: operator runs the push themselves via `!` from the terminal. The deploy skill mediated the build; the operator mediated the push.

Production smoke test: operator requested an admin magic-link; email landed in their inbox. This exercises the full new path (`send_admin_magic_link → _send_email → smtplib.SMTP → STARTTLS → relay → Gmail`) which is the same call chain every other email site now uses — strong end-to-end signal.

---

## By the numbers

| Metric | Count |
|---|---|
| Commits in branch | 5 (4 code + 1 docs) — matches the brief's "5-6 commits" estimate |
| Files added | 3 (`tests/test_composio_client.py`, `tests/test_notifications_dispatch.py`, this report) |
| Files modified | 11 (`composio_client.py`, `notifications.py`, `educator_service.py`, `mailing_list.py`, `core/config.py`, `api/contact.py`, `api/educators.py`, `api/orders.py`, `api/booking_admin.py`, `api/webhooks.py`, `api/auth.py`) |
| Files modified (docs) | 3 (`CLAUDE.md`, `docs/phase-2/agent-friendly-outcomes.md`, `docs/phase-2/prompts/INDEX.md`) |
| Files modified (operator, out-of-band) | 1 (`.env.example` — operator edited per Q4 plan) |
| Call sites updated | 12 send_email-line sites (vs. 10 the brief estimated — diff explained in the session report's "What surprised me §3") + 6 API-layer try/except sites |
| Unit tests added | 13 (8 wrapper + 5 dispatch) |
| Unit tests passing on changed code | 156/156 (full suite, host pytest) |
| Ruff status on changed lines | clean; pre-existing `F401` × 2 (`auth.py`, `orders.py`) and `UP017` × 4 (`mailing_list.py`) carried forward per session-02/03 precedent |
| Auto-approve-fence fires (legitimate) | 1 (`docker push registry.digitalocean.com*` — resolved by operator running it themselves via `!`) |
| Stop-the-line incidents | 1 (operator's `.env.example` deleted `COMPOSIO_API_KEY` — surfaced before deploy, operator confirmed the choice, deploy proceeded) |
| Prod-touching commands surfaced for explicit approval | 1 deploy (build local, push gated, operator-executed) |
| Prod smoke test | admin magic-link email landed in operator inbox |
| Issues addressed | 6 (5 + 1 partial) |
| Outstanding decisions awaiting operator at session end | 0 (PR open for review; merge is operator-driven) |

---

## What was done

### Phase 1 — Local prep + plan

Read all inputs in order per the brief: session 01/02/03 reports, all 6 cluster-B issue bodies (`gh issue view 67`/`68`/`70`/`74`/`59`/`37`), full `composio_client.py` / `notifications.py` / `educator_service.py` / `mailing_list.py` / `api/contact.py`, `core/config.py`, `.env.example`, `.claude/settings.json`, the outcomes-log + register conventions, `CLAUDE.md`. Cross-referenced API-layer callers in `orders.py`, `booking_admin.py`, `webhooks.py`, `auth.py`, and `api/educators.py` to understand the existing swallowed-exception patterns.

Surfaced a Phase-1 plan covering the new `EmailDeliveryError` signature, the new `send_email` outline (SMTP lifecycle with STARTTLS + timeout), per-caller before/after for all 12 sites, the test list, the env-var additions, and the Workspace-allowlist dependency. Five open questions surfaced to the operator:

| Q | Topic | Operator decision |
|---|---|---|
| Q1 | Allowlist status | Not yet set; will land out-of-band when operator returns. Code changes can proceed now. |
| Q2 | Auth posture | Assume off; verify if `530 Authentication required` fires. |
| Q3 | `Order.notification_failed_at` migration | **Option B** — close #37 with the wrapper-Sentry covering layer 1 systemically; defer layer 2 (the column + admin-dashboard view). |
| Q4 | `.env.example` edit (fence denies) | Operator pastes the three lines; agent surfaces the diff. |
| Q5 | Tests for educator + mailing_list dispatch failures | Skip — pattern is mechanically the same. |

Plan was approved; Phase 2 began.

### Phase 2 — Implementation

Branch `fix/composio-cluster-b-smtp-relay`. Five commits, each keeping the test tree green:

**Commit 1 — `feat(email): SMTP relay implementation + EmailDeliveryError + tests (#67, #68)`.** Rewrites `composio_client.send_email` to use stdlib `smtplib.SMTP` + `email.mime.text.MIMEText`. New exception `EmailDeliveryError` defined in the same module. Catches `(smtplib.SMTPException, OSError, TimeoutError)` — covers transport, auth, DNS, connection-refused, timeout. `sentry_sdk.capture_exception` inside the failure branch before re-raise. Three new settings (`smtp_relay_host`, `smtp_relay_port`, `smtp_relay_timeout`) with production-aligned defaults. `get_composio()` stays in the module (Sheets path).

Eight unit tests in `tests/test_composio_client.py`. Pure stdlib — no DB or testcontainer. Each failure-mode test asserts the original exception is Sentry-captured before re-raise. One small surprise during test authoring: `MIMEText` base64-encodes its body by default; assertions had to use `msg.get_payload(decode=True).decode("utf-8")` rather than `msg.get_payload()`.

**Commit 2 — `fix(notifications): propagate customer EmailDeliveryError, log admin (#37, #70)`.** Each `NotificationService` method returns `None` instead of `bool`. Two-recipient methods (`notify_new_order`, `notify_payment_received`) propagate customer-side failures (the stranded-customer mode behind #36/#37) and catch+log admin-side failures (the wrapper already Sentry-captured). Four single-recipient methods propagate uniformly. API-layer callers in `orders.py`, `booking_admin.py`, `webhooks.py`, `auth.py` now catch `EmailDeliveryError` specifically rather than bare `Exception` — behavior unchanged at the API layer, intent explicit.

Five new dispatch tests in `tests/test_notifications_dispatch.py`. `SimpleNamespace` stand-ins for Order/Booking/Tour — no DB needed (the existing `test_notifications.py` template-rendering tests use the same approach).

**Commit 3 — `fix(educators): propagate EmailDeliveryError to honest API surface (#59)`.** Internal helper signatures flip from `-> bool` to `-> None`; the log-the-result lines simplify accordingly. `api/educators.py` adds a typed `except EmailDeliveryError` clause before the existing generic catch on the two endpoints that trigger email sends (`login`, `signup`), returning HTTP 502 with `"We couldn't send the confirmation email. Please try again in a few minutes."` Other endpoints (`confirm`, `verify-code`, `check-access`, `unsubscribe`) don't send email; no typed catch needed.

**Commit 4 — `fix(mailing-list, contact): typed catches for EmailDeliveryError (#74 partial)`.** `mailing_list._send_confirmation_email` propagates; three `subscribe()` paths catch and return user-honest `{success: false, message: ...}` instead of misleading "check your email." Sheets-side bool-discards stay per the brief. `api/contact.py` catches `EmailDeliveryError` specifically; the dead "send_email returned False" code path is gone (new contract never returns False). One small adjacent cleanup that was in scope: removed the stale `if not settings.composio_api_key` guard in `api/contact.py` that would silently skip emails after session 05 removes Composio (the SMTP path doesn't depend on `composio_api_key`; gating it there was a hidden regression hazard).

**Commit 5 — `chore(docs): update CLAUDE.md tech stack — email moves to SMTP relay`.** One row replaced (Email | Composio → Email | SMTP relay); one row added (Mailing list | Sheets via Composio | planned for replacement in session 05). The defaults in `app/core/config.py` already match production values, so the `.env.example` template update was operator-applied out-of-band (per Q4).

**Test infrastructure note.** Same pre-existing state as sessions 02 + 03: `testcontainers`-backed conftest.py can't run inside `docker-compose exec backend pytest` because dev compose doesn't mount `/var/run/docker.sock`. Ran from host with `ENVIRONMENT=test /home/javier/anaconda3/bin/pytest`. 156/156 pass.

### Phase 3 — Production cutover

**Step 0 — operator preflight.** Operator confirmed they'd allowlisted the production droplet's outbound IP in Workspace admin and updated the prod droplet's `.env` with the three SMTP_RELAY_* variables. The operator also did two adjacent edits I hadn't planned for: they replaced `COMPOSIO_API_KEY`/`COMPOSIO_USER_ID` with `SMTP_RELAY_*` in the top-level `.env.example` template (rather than additive), and they removed `COMPOSIO_API_KEY` from the production droplet's actual `.env` (not just the template).

**Stop-the-line moment.** Before invoking the deploy skill, I surfaced the COMPOSIO_API_KEY-removed-from-droplet concern: the mailing-list Sheets path still calls `get_composio()`, which raises `RuntimeError("COMPOSIO_API_KEY not configured")` when the key is missing. Operator confirmed: the Sheets path was already broken via Composio's own breach (the OAuth reconfiguration UI is down); removing the key shifts the failure shape but the net outcome is unchanged (mailing list 500s until session 05 lands). Verified `get_composio()` callers are exclusively in `mailing_list.py` (3 helpers) — no other module would be affected. Deploy proceeded.

**Step 1 — deploy.** Invoked the `deploy` skill (backend-only — frontend and cert-watcher unchanged). Image build local: `docker build -f docker/backend/Dockerfile.prod -t registry.digitalocean.com/wanderindev/pic-backend:latest .` — completed in ~50 seconds. Surfaced the push step for explicit operator approval per the brief.

**Fence fire (anticipated).** The first push attempt (`docker push ...`) was correctly blocked by the L1 deny rule `Bash(docker push registry.digitalocean.com*)`. Surfaced two paths: (a) operator runs it themselves via `!` from the terminal, or (b) approves it via IDE permission prompt. Operator chose (a) — clean session-02-shape mediation.

**Step 2 — smoke test.** Operator requested an admin magic-link via the prod admin UI. Email arrived in operator inbox. Confirms the full new path is working end-to-end in production:

```
admin UI POST → /api/v1/auth/admin/request-access
  → NotificationService.send_admin_magic_link
    → composio_client.send_email
      → smtplib.SMTP("smtp-relay.gmail.com", 587, timeout=10)
        → STARTTLS → send_message → Gmail
```

No retry needed; no fence fires beyond the anticipated push; no allowlist surprises. Workspace IP allowlist held; "Require SMTP Authentication" off held; no `530 Authentication required` from the relay.

### Phase 4 — PR + housekeeping

Pushed branch (fence's `git push * main*` deny rules don't fire for feature-branch pushes). Opened PR [#143](https://github.com/wanderindev/panama-in-context/pull/143) with the structured description the Phase-2 working-model L3 requires (`Production touch: yes — gated by:`).

Appended 6 rows to `docs/phase-2/agent-friendly-outcomes.md` — one per addressed issue (`Outcome = not-yet-attempted` until merge, per session 02/03 convention).

Posted comments on all 6 closed issues (#67, #68, #70, #74, #59, #37) linking the PR and explaining what landed vs. what's deferred. #67 and #68 were already auto-closed by the session-04 prompt commit's body referencing "Closes #67, …" — flagged in the comments so the trail is honest about the auto-close.

This report. INDEX.md update. Cross-session register entry below (one genuine cross-session decision crystallized this session — see §What's next).

---

## What's next

1. **Operator merges PR #143.** The `gh pr merge*` deny rule blocks me from merging; correctly. Once merged, update the `Outcome` column in `docs/phase-2/agent-friendly-outcomes.md` from `not-yet-attempted` to `clean-merge` (or `needs-revision`) for all 6 appended rows via the tiny-PR-after-merge convention.
2. **Session 05 (Composio Sheets removal + mailing list → DB).** This session's deferred work (Composio API key removed from prod, Sheets path 500-ing) makes session 05 more urgent than originally scoped. The mailing list is currently down. Session 05 lands the DB migration + drops `composio` from `requirements.txt` + removes `composio_client.py`.
3. **Follow-ups worth filing as their own issues** (not done this session):
   - **#37 layer 2 — `Order.notification_failed_at` column + admin dashboard view of stranded customers.** TODO breadcrumb in `api/orders.py:create_order`. Lower priority now that the wrapper-Sentry covers the systemic-visibility gap; still useful for per-row audit and triage.
   - **#68 deferred halves — DeepL + Anthropic SDK timeouts.** Comment on #68 notes the SMTP half landed; the DeepL half needs subclassing or wrapping the underlying `requests.Session` (SDK doesn't expose per-call timeout); the Anthropic half pairs with #F10 (unified LLM wrapper) and is mechanically simpler (`client.messages.create(..., timeout=N)` at 6+ sites).
   - **Educator "show support email after N failed retries" UX fallback** (from #59's original "desired state §3"). Frontend change; defer until Diego sees failure rate climb post-deploy.
   - **Mailing list 500s until session 05 lands.** Worth a one-line ops note: any user hitting `POST /api/v1/subscribe` between now and session 05's deploy will see a 500. Acceptable risk per the operator's confirmation (Sheets was broken pre-deploy anyway).

---

## Process notes

- **The brief's gate-at-each-phase discipline paid for itself twice.** First during Phase 1 when I surfaced 5 open questions (Q1–Q5) before any code write — the operator's decisions on Q3 (defer layer 2 of #37) and Q5 (skip educator/mailing dispatch tests) materially scoped the PR. Second during Phase 3 when I surfaced the `.env.example` Composio-key-removed observation *before* invoking the deploy skill — if I'd skipped that and just pushed, the deploy would have been "clean" but the mailing list would have started 500-ing with a slightly different error shape, surfacing post-deploy as a "wait, what changed?" question. The session-02 report named this discipline as the brief's load-bearing structure; session 04 confirmed it.
- **The fence fired once, exactly as designed.** The `docker push registry.digitalocean.com*` deny rule on Phase 3 step 2 forced the operator-runs-it-themselves mediation. The same shape as session 02's full `pg_dump` interception, just for a different command class. The L1 rules are doing their job: making prod-touching commands a surface-and-approve moment rather than an autopilot moment. Disposition: **fired clean, mediated as expected.**
- **The operator's "Composio key removed entirely from .env.example" was a benign surprise that the gate caught.** They went beyond Q4's "paste these three lines" to do a more aggressive cleanup — natural for someone reading the diff and seeing the Composio Gmail lines no longer needed. The mailing-list Sheets dependency on `composio_api_key` was the second-order coupling that would have been invisible without the gate. The 90 seconds spent surfacing the question prevented the deploy from creating a follow-up "why is the mailing-list 500 shape different now?" mystery. Disposition: **stop-the-line, resolved without escalation; gate did its job.**
- **Pre-existing ruff debt: leave it.** Same call sessions 02 and 03 made. Touched `auth.py` and `orders.py` and `mailing_list.py` for the email-path changes; the pre-existing `F401`s and `UP017`s were already there. Fixing them would be trivial individually but expand scope and conflate unrelated changes. Noted in commit messages.
- **The brief's "12 sites vs. 10 sites" estimate.** The brief said "10 sites = 6 in notifications.py + 2 in educator_service.py + 1 in mailing_list.py + 1 in api/contact.py" but I counted 12 (8 in notifications.py — two methods have two `_send_email` calls each — + 2 + 1 + 1). Mentioned in the Phase 1 plan and surfaced here in the session report. Not a real discrepancy; the brief was counting NotificationService *methods* and I'm counting *send_email-line sites*. Either count produces the same set of changes.
- **The contract-flip-as-a-tool worked.** Each cluster-B issue had its own filing rationale (different sites, different severities, different suggested fixes), but the underlying remediation collapsed into one change: replace the bool contract with a raise contract. The brief named this: "flipping the contract from bool (silent on failure) to raise on failure is the same change that resolves #67/#70/#74/#59/#37." Phase 2 implementation confirmed it — once the wrapper raises, every caller-side `bool`-discard either becomes a propagate (correct) or a typed catch (correct), and the previously-distinct bugs all become "fixed by the same line."

---

## What surprised me

- **#67 and #68 were already CLOSED at session start.** Both auto-closed at 2026-05-25T13:49:12Z by the merge of PR #142 (the session-04 prompt commit body referenced "Closes #67, #70, #74, #59, #37; partially closes #68"). The work this session did was what those closures were anticipating — but anyone navigating the issue tracker between 2026-05-25 13:49 and this PR's merge would see "Closed" on #67/#68 with no linked PR, a confusing state. Surfaced this in the Phase 1 plan and noted in the issue comments. Not a real regression — both will remain closed once PR #143 merges, and the outcomes-log rows track the actual work — but a small methodology lesson: **commit-body issue closures should be reserved for the implementing PR**, not the prompt-drafting commit. Future Phase 2 prompt commits should avoid `Closes #N` references in their body to keep the issue tracker's audit trail tied to the actual implementation merge.
- **The operator's `.env.example` cleanup was more aggressive than I'd planned for.** Q4 was "paste these three lines"; the operator paste-replaced the entire Composio Gmail block. This is a defensible cleanup (the lines aren't needed for Gmail anymore) and matched the project's "remove what's not needed" tendency. The second-order effect — that `composio_api_key` is still load-bearing for the Sheets path — was the gate-caught issue. Future operator-paste prompts could mention "additive only, don't tidy adjacent lines" if I want to prevent this class of surprise, but I'd rather keep the gate doing the work than constrain the operator's natural cleanup instinct.
- **The `MIMEText` body base64-encoding gotcha.** Wrote a test that asserted `<p>Hi</p>` was in `msg.get_payload()`; got `'PHA+SGk8L3A+\n'` (base64). The Python stdlib auto-encodes non-7-bit-ASCII content with Content-Transfer-Encoding: base64 by default when the email contains HTML, and `get_payload()` returns the raw transfer-encoded form. Fix: `msg.get_payload(decode=True).decode("utf-8")`. Not a production concern — SMTP submission handles the encoded form transparently — but a 30-second test-authoring surprise. Worth knowing for future stdlib-email-related tests.
- **The session was less eventful than I'd budgeted.** The brief warned of multiple stop-the-line trigger classes (allowlist not in place, 530 Auth required, downstream consumer assumes bool, deploy succeeds but smoke test fails). None fired. The fence-fire on push was anticipated. The `.env.example`-Composio-key-removal stop-the-line was resolved in two messages. The smoke test passed on first try. Session-02 had a stop-the-line on byte-level continue-section drift; session 03 was a 5-commit straight line; session 04 was a 5-commit straight line with one minor gate-caught moment. Pattern emerging: **cleanup-then-refactor sequencing (the cross-session register pattern from sessions 02-03) plus prompt-time over-budgeting yields routinely uneventful execution.** The orchestrator's prompts are doing their job well enough that the in-session friction is low; the budget should compress.

---

## Cross-cutting checklist dispositions

Fix-execution session, not an audit. Recording the ones that fired or were materially checked:

- **Two-dimensional severity: blast-radius × evidence-of-impact (synthesis §8).** Applied throughout. The whole reason this session was urgent is that #67's blast radius (every email path) × evidence-of-impact (Composio breach → live failures in prod) crossed the urgent threshold. The session's own sub-decisions used the same lens: Q3 (defer layer 2 of #37) — wrapper-Sentry covers the high-blast-radius observability gap; per-row dashboard is lower-impact. The `.env.example` stop-the-line — Sheets path was already-broken (no new blast radius from the operator's removal); proceed. Disposition: **fired clean; the framing is now a habit, not a checklist item.**
- **Danger is not where complexity is (synthesis §8).** Most of the implementation complexity sat in commit 2 (notifications.py's two-recipient try/except restructure). None of it was load-bearing for correctness — the customer-vs-admin propagate-vs-catch split is a simple invariant once stated. The actual *risk* in the session was the prod cutover step (image not pulled? wrong env? allowlist insufficient? auth required?) — and that was a one-step single-image push followed by a one-action smoke test, mediated by the fence and the operator. Risk and complexity lived in different commits / phases. Disposition: **complexity in commit 2, risk in Phase 3, both correctly localized.**
- **Partial-correction debt umbrella.** Two partial corrections land here: #74 partial (email half landed; Sheets half is session 05) and #37 partial (layer 1 systemic via wrapper-Sentry; layer 2 column-and-dashboard deferred). Both have explicit deferral documentation: #74 in the PR description + #74 comment; #37 via TODO comment in `api/orders.py` + #37 comment + follow-up in "What's next §3". The umbrella's risk (deferred work staying deferred indefinitely) is managed by the cross-session register + outcomes log + the explicit session-05 brief existing. Disposition: **acknowledged; not closed; tracked.**
- **Latent-but-uncrystallized risk.** Test-infra `docker.sock` and ruff-debt-on-wider-backend still uncrystallized from sessions 02-03. This session adds one more: **mailing-list 500 between this PR's merge and session 05's deploy.** Acceptable risk per operator confirmation (Sheets was non-functional pre-deploy via the breach), but a candidate uncrystallized risk if session 05 slips. Disposition: **surfaced; tracked in "What's next §3d"; resolved by session 05 landing.**
- **Swallowed-failure umbrella.** This PR is itself the largest swallowed-failure remediation in Phase 2 so far. Six issues (#67/#68/#70/#74/#59/#37) all reduce to the same shape: a wrapper returned bool, callers ignored it. The contract flip closes the umbrella for the email path. Sheets remains under the umbrella until session 05. Disposition: **email path: closed. Sheets path: tracked under session 05's scope.**
- **Orchestrator's prior as a check (framing).** Priors stated in the brief: (1) "10 call sites" — broke (actual: 12 send_email-line sites; brief was counting NotificationService methods). (2) "Composio stays in requirements.txt; the mailing_list Sheets calls are explicitly out of scope" — held (Composio in requirements.txt, Sheets unchanged). (3) "Email sending is broken in production right now" — held (the Composio breach + #67's bool-return mask matches the operator's description). (4) "The droplet IP allowlist needs operator action" — held (operator did it out-of-band). One of four priors required correction; corrections were the cheap-to-discover-now kind. Disposition: **priors broadly held; correction was a numerical count, not a substantive misframing.**
- **Agent-friendly grading prior (synthesis §10).** Filed grades vs. in-session experience:
  - **#67 (filed: no).** Held — the wrapper-contract change cascaded as predicted; the unified-replacement-with-SMTP was operator-judgment-driven, not agent-decidable.
  - **#68 (filed: borderline).** Held — the mechanical `timeout=N` change was agent-friendly; the SMTP value (10s) matched the brief's recommendation, no policy debate.
  - **#70 (filed: no).** Held — depended on #67's contract shape; once #67's contract was decided (raise on failure), #70's resolution was mechanical.
  - **#74 (filed: no).** Held — depended on #67; partial closure also matched the "session 05 finishes this" structural plan.
  - **#59 (filed: borderline).** Mostly held — the API-message wording was a one-line operator-approvable surface; the rest was mechanical.
  - **#37 (filed: no).** Held — the layer-1 vs. layer-2 split *was* a decision that needed human judgment (Q3 in the plan); the operator chose Option B.
  - Aggregate: all 6 filings broadly held. The pattern: cluster-B's "filed: no" issues were correct because they couldn't be agent-decided in isolation, but **with the prompt doing the coupling decision upfront**, the in-session implementation was mechanical for all six. The "agent-friendly grade describes the issue in isolation; with a good prompt, even no-grade issues become agent-friendly in execution" pattern is now well-established across sessions 02, 03, and 04. Disposition: **filings correct; in-session execution easier than the file-time grading suggested, *because the prompt did the planning*.**

---

## Cross-references

- Phase 1 synthesis: `docs/pilot/phase-1-synthesis.md` (especially §5 fence operationalization, §8 two-dimensional severity, §10 agent-friendly grading)
- Phase 1 Area 4a report (cross-cutting services audit that surfaced #67/#68): `docs/pilot/phase-1-area-4a-report.md`
- Session 01 report (planning): `docs/phase-2/01-kickoff-report.md`
- Session 02 report (articles 39/40 cleanup): `docs/phase-2/02-articles-39-40-cleanup-report.md`
- Session 03 report (full #99 fix): `docs/phase-2/03-issue-99-full-fix-report.md`
- Session 04 prompt: `docs/phase-2/prompts/04-composio-email-removal-smtp-relay.md`
- Session 05 prompt (next): `docs/phase-2/prompts/05-composio-sheets-removal-mailing-list-to-db.md`
- Outcomes log: `docs/phase-2/agent-friendly-outcomes.md`
- Cross-session register: `docs/methodology/cross-session-register.md`
- Memory: `memory/composio_breach_2026-05.md` (vendor-breach context that triggered urgency)
- GitHub: PR [#143](https://github.com/wanderindev/panama-in-context/pull/143); issues #67 (closed), #68 (closed), #70 (open until merge), #74 (open until merge), #59 (open until merge), #37 (open until merge)
