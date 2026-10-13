# Phase 2 — Session 05: Composio Sheets removal — migrate mailing list to `educators` DB table

## Identification

You are running **Phase 2 Session 05** of the PIC audit-and-fix pilot. Phase 2 is the fix-execution phase. Sessions 01-04 have shipped; session 04 (PR landing imminently as of this writing) restored email sending via SMTP relay and cleaned up the Composio email-contract cluster. This session finishes the Composio removal: rip out the Google Sheets calls from `mailing_list.py`, migrate the mailing-list backend to the existing `educators` DB table, drop `composio` from `requirements.txt` entirely.

You are running in a **fresh Claude Code instance**, separate from the orchestrator's main session. The orchestrator preserves their context to review your work and brief subsequent sessions. Everything you need is in files this prompt points at — do not assume conversational context.

This session is **not** as time-critical as session 04 (which was an emergency — emails were broken in prod). Session 05's urgency comes from finishing what session 04 started: the operator wants Composio gone entirely, not partially. The Composio breach in May 2026 (see MEMORY.md `composio_breach_2026-05.md`) reinforced the "planned for replacement" framing the project had carried since Phase 0.

## Read these first, in order

Read each one fully before proposing a plan. Don't skim.

1. **`docs/phase-2/04-composio-email-removal-report.md`** — session 04's report. Confirms what landed: SMTP relay, contract flip, caller-site fixes for the email path. **Read this before assuming anything about the current state of `composio_client.py` or the email callers.** If session 04 didn't actually ship the way the plan suggested, this prompt's scope assumptions may need adjusting.
2. **`docs/phase-2/01-kickoff-report.md`**, **`02-articles-39-40-cleanup-report.md`**, **`03-issue-99-full-fix-report.md`** — the Phase 2 working model. Especially the gate-at-each-phase discipline, the prompt+report pairing, and the outcomes-log + cross-session register conventions.
3. **Issue #75** (`gh issue view 75`) — the race in `mailing_list._find_row` / `_append_row`. The body explicitly recommends the Sheets→DB migration this session does. **This session closes #75.**
4. **`backend/app/services/mailing_list.py`** (full file) — the file you're refactoring. Note especially the three Composio Sheets helpers (`_find_row`, `_append_row`, `_update_row`) and the three public functions that consume them (`subscribe`, `confirm`, `unsubscribe`). Also note `_send_confirmation_email` — it still uses raw f-string HTML (issue #80) which is **OUT of scope for this session** (a separate Jinja2-migration PR, parallel to the closed #31).
5. **`backend/app/models/educator.py`** (full file) — the existing DB table you're migrating to. Note the schema: `email` (unique, indexed), `status` (PENDING/CONFIRMED/UNSUBSCRIBED), `source` (CTA tag), `confirm_token`, `language`, `mailing_list` (bool), all the educator-gate fields (verify_code, access_expires_at, etc.). **No schema migration is needed** — the model is already shaped for this. Confirm this against the current state at session start.
6. **`backend/app/api/subscribe.py`** — the API surface (`/subscribe`, `/confirm-subscription`, `/unsubscribe`). The external contract stays the same; only the internal implementation changes.
7. **`backend/app/services/composio_client.py`** (post-session-04 state) — `get_composio()` should still be present (used by `mailing_list.py` for Sheets); `send_email` should be SMTP-relay-based per session 04. Confirm at session start.
8. **`backend/app/services/educator_service.py`** — relevant because the `educators` table is also used by the educator-access flow. Confirm your changes don't conflict with the educator-access reads/writes. Specifically: educator-access flow writes rows with `confirm_token`, `verify_code`, `access_expires_at`; mailing-list flow writes rows with `confirm_token`, `mailing_list=true`, no verify code or access expiry. The `source` field disambiguates: mailing-list rows have sources like `"MailingListEducators"`, `"MailingListBlog"`, while educator-gate rows have `"media_library"` / `"classroom_assets"`.
9. **`backend/.env`** (do NOT edit) and **`backend/.env.example`** — the Composio + Sheets env vars (`COMPOSIO_API_KEY`, `COMPOSIO_USER_ID`, `MAILING_LIST_SHEET_ID`). All three should be removed from `.env.example` after this session. The prod `.env` change is operator-driven (`.env*` writes are denied by the fence).
10. **`backend/requirements.txt`** — `composio>=0.1.0` will be dropped by this session.
11. **`.claude/settings.json`** — the auto-approve fence. The deny rules cover prod DB writes (this session writes prod via the migration script), `gh pr merge*`, force-push, etc.
12. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log; append a row when the PR opens.
13. **`docs/methodology/cross-session-register.md`** — append only for genuine cross-session decisions.
14. **`CLAUDE.md`** — project conventions. The tech-stack table mentions Composio; this session removes that row. The "NotebookLM Integration" and other sections are unrelated; leave alone.
15. **`MEMORY.md` (in `~/.claude/projects/.../memory/`)** — auto-loaded by Claude Code. Note the `composio_breach_2026-05.md` reference and the Educator Access System plan. This session's migration partially advances that plan (the Sheets→DB part), but does NOT implement the gate flow.

## Why this session matters

Three reasons, in order of weight:

1. **Closes the "remove Composio entirely" goal** the operator articulated after session 04. After this PR, `composio` is gone from the codebase — no imports, no env vars, no dependency. The Composio breach's tail can be retired from the project's attention.
2. **Closes #75** — the race condition between `_find_row` and `_append_row` in mailing_list. The race is real (the issue body documents the reproduction); the migration to a DB table with `UNIQUE(email)` makes the race a constraint violation (handled atomically) rather than a silent duplicate. This is the synthesis §8 "latent-but-uncrystallized risk" closing out — the risk crystallizes if volume grows, and getting ahead of it now is the right move.
3. **Advances the Educator Access System plan** (MEMORY.md). The full plan has more parts than this session ships (the gate flow, the 7-day access window, the 6-digit verification code on re-entry), but the foundational Sheets→DB migration is half of the work. Pulling it forward decouples the mailing-list functionality from the educator-gate's eventual implementation.

## Scope

### IN scope

- **Migrate `mailing_list.subscribe / confirm / unsubscribe`** from Composio Sheets calls to ORM queries against the `educators` table:
  - `subscribe(email, source, language)`: INSERT a row with `status="PENDING"`, the supplied source (e.g., `"MailingListEducators"`, `"MailingListBlog"`), language, fresh `confirm_token` (UUID), `mailing_list=True`. Handle the race naturally via `UNIQUE(email)`: on integrity error, look up the existing row and branch on its status (re-send confirmation if pending; respond "already subscribed" if confirmed; resurrect if unsubscribed).
  - `confirm(token, language)`: SELECT by `confirm_token`, flip `status=CONFIRMED`, set `confirmed_at=now()`, clear the token. Match the existing Sheet-based behavior.
  - `unsubscribe(email)`: SELECT by `email`, flip `status=UNSUBSCRIBED`, set `unsubscribed_at=now()`. Match the existing Sheet-based behavior.
- **Drop the Composio Sheets helpers** (`_find_row`, `_append_row`, `_update_row`) from `mailing_list.py`. They no longer have callers after the migration.
- **Drop `get_composio()` and the Composio module** entirely (`composio_client.py`). If session 04 already removed the `Composio` import and kept just `get_composio` as a stub for Sheets, this session removes the stub.
- **Drop `composio>=0.1.0` from `requirements.txt`**.
- **One-off migration script** at `scripts/one_off/migrate_mailing_list_sheet_to_db.py` (follow the session-02 pattern):
  - Reads the existing Google Sheet (via `google-api-python-client` directly, with Workspace-scoped service-account or OAuth-refresh-token credentials — operator-decision on which approach, surfaced in Phase 1 planning) — OR an exported CSV if the operator prefers that path.
  - Maps each row to an `Educator` row: email (column A), source (column B), confirm_token (column C), status (column D — map "confirmed" → "CONFIRMED", "pending" → "PENDING", "unsubscribed" → "UNSUBSCRIBED"), language (column G if present, else default `"es"`), timestamps if present.
  - Asserts `UNIQUE(email)` won't conflict (i.e., the educator-gate flow hasn't already written rows for the same emails — unlikely but possible).
  - Dry-run default; `--no-dry-run` writes; `--confirm-prod` required for prod-shaped DB URLs.
  - Timestamped JSON backup of (a) the input Sheet rows and (b) any pre-existing `educators` rows that might be in conflict, to `scratch/` (the convention established in session 02).
- **Drop env vars** `COMPOSIO_API_KEY`, `COMPOSIO_USER_ID`, `MAILING_LIST_SHEET_ID` from `.env.example` and `CLAUDE.md` (the tech-stack table). The prod `.env` change is operator-driven (`.env*` writes are denied).
- **Tests** for the migrated `subscribe / confirm / unsubscribe` functions. At minimum: subscribe-new; subscribe-existing-pending (resend); subscribe-existing-confirmed; subscribe-existing-unsubscribed (resurrect); confirm-valid-token; confirm-invalid-token; unsubscribe-found; unsubscribe-not-found; concurrent-subscribe-doesn't-duplicate (asserts on `UNIQUE` constraint behavior — this is the #75 closer).
- **PR opens; do not merge.** Append outcomes-log row(s) when the PR opens (one for #75; this PR completes #75's recommended fix). Open a comment on #75 linking the PR. Session report at `docs/phase-2/05-composio-sheets-removal-report.md`. Update prompts INDEX.

### OUT of scope (do NOT touch)

- **The Educator Access System gate flow** (`/api/v1/educators/*` endpoints, the 7-day-access window logic, the 6-digit verify code, the `EducatorAuthContext` in the frontend). MEMORY.md has the detailed plan; that's a separate, larger initiative. This session only touches the `mailing_list` flow that incidentally writes to the same `educators` table.
- **Issue #80** — raw f-string HTML in `_send_confirmation_email`. Same file, but a separate concern (Jinja2 migration, same shape as closed #31). Defer to its own PR.
- **Issues #51, #52, #53, #58, #61, #62, #63, #64, #65, #50** — the educator-gate-flow issues from Area 3. They share the `educators` table but address different code paths.
- **Sheets API auth setup** beyond what the migration script needs once. The script runs once (or maybe twice — dry-run + live); after that, no Google Sheets credentials are needed anywhere in the codebase.
- **Renaming `composio_client.py`** to something more honest now that it doesn't use Composio. If session 04 didn't already do this, leave it for a follow-up cleanup PR — the rename inflates the diff without adding value here.

## Plan — four phases, gated step-by-step

### Phase 1 — Local prep (no prod touch, no code writes until approved)

1. Read the inputs above in order.
2. Confirm session 04's state — what's in `composio_client.py`, what's in the email callers, what `requirements.txt` looks like.
3. Confirm the `educators` table's schema is what this session expects — no migration needed.
4. Inspect the current Google Sheet (operator can provide a CSV export if Composio's dashboard is still down; otherwise use `google-api-python-client` with service-account credentials operator provides). Count rows, distinct emails, status distribution, source distribution.
5. Check for conflicts between Sheet emails and existing `educators` rows (from the educator-gate flow). If there are any, surface for operator decision before the migration runs.
6. Produce a **plan** that specifies:
   - The new `mailing_list.subscribe / confirm / unsubscribe` implementation outlines (ORM queries, race handling via `IntegrityError` catch + lookup).
   - The migration script's CLI shape, input source (live Sheet via API or CSV), the assert-list, the dry-run output format.
   - The test list (8-9 cases enumerated).
   - The env-var and CLAUDE.md doc edits.
   - The order of commits.
7. **Surface the plan and WAIT for operator approval before any code write.**

### Phase 2 — Local implementation + tests

1. Create the feature branch: `refactor/composio-sheets-removal-mailing-list-to-db`.
2. Implement the new `mailing_list` functions, one at a time, keeping the test tree green:
   - Commit 1: `subscribe` reimplementation + tests.
   - Commit 2: `confirm` reimplementation + tests.
   - Commit 3: `unsubscribe` reimplementation + tests.
   - Commit 4: Remove `_find_row`, `_append_row`, `_update_row`, `get_composio`, the Composio module; remove `composio` from `requirements.txt`.
   - Commit 5: `.env.example` + `CLAUDE.md` doc updates.
   - Commit 6: Migration script in `scripts/one_off/`.
3. Run the full test suite locally. If the `docker.sock` issue (#139) still blocks `docker-compose exec backend pytest`, run from the host as prior sessions did. Surface in the session report.
4. **Local dry-run of the migration script** against the local DB (which may or may not have stale data). Inspect the planned INSERTs. Surface for operator review.

### Phase 3 — Production migration

This is the load-bearing phase. The auto-approve fence will fire on each prod-touching command.

1. **Surface for operator approval**: a prod DB backup of the `educators` table BEFORE the migration script runs. Use the `database-ops` skill.
2. **Surface for operator approval**: the migration script's `--no-dry-run --confirm-prod` invocation against prod. Backup file written to `scratch/` first.
3. Run the migration. The script's internal asserts must pass; if any fail, halt and surface — same stop-the-line discipline as session 02's continue-section drift.
4. **Verify** post-migration: row counts in `educators` match expected; status distribution matches; no duplicates by email.
5. **Deploy** the new code (via the `deploy` skill — L2 fence-gated). Watchtower pulls within ~5 minutes.
6. **Smoke test in prod**: subscribe a test email (e.g., `diego+mailingtest@panamaincontext.com`), confirm via the link, unsubscribe. End-to-end happy path.
7. If the smoke test fails, surface. Don't retry blindly.

### Phase 4 — PR + housekeeping

1. Push the branch. Open the PR. Do not merge.
2. PR description: `Closes #75`. **"Production touch: yes — gated by:"** line listing each gate.
3. Append outcomes-log row for #75. `Filed agent-friendly?: no`; `Agent attempted?: pair`; `Outcome: not-yet-attempted` (update at merge per the tiny-PR-after-merge convention).
4. Comment on #75 linking the PR.
5. Write the session report at `docs/phase-2/05-composio-sheets-removal-report.md`.
6. Update `docs/phase-2/prompts/INDEX.md` with the session-05 entry.
7. Append to the cross-session register only if a genuine cross-session decision crystallized.

## Production data access policy

- **Production DB writes are required** for the migration (the INSERT loop on the `educators` table). The fence's deny rules will fire on any prod-credentialed command; surface for explicit per-invocation approval.
- **Backup before write** is mandatory. The migration script writes a timestamped JSON dump of the current `educators` table to `scratch/` before any INSERT.
- **Do not edit `.env*` files** under any path. The fence denies it. Surface the env-var changes; operator applies.
- **Sheets API auth credentials** (whatever flavor — service account JSON or OAuth refresh token) are sensitive. Do NOT commit them. If the migration script needs to read the Sheet directly, the operator provides credentials via env var at runtime; you do not persist them.

## Working style

- **Gate-at-each-phase.** Phase 1 → 2 → 3 → 4.
- **Don't expand scope.** No #80 Jinja2 work. No educator-gate-flow implementation. No `composio_client.py` rename. Surface temptations as process notes.
- **The race-condition fix is the killer feature.** The `UNIQUE(email)` constraint making concurrent subscribes a database-level concern (not application-level locking) IS the synthesis §8 "latent-but-uncrystallized risk" closing out. Tests must include a concurrent-subscribe case.
- **Sentry-capture the new error paths** (`IntegrityError` from concurrent insert; missing Sheet on first import; auth failure on the migration script). Fail-loud over silent.
- **Tests pass locally before push.** Match session 02-04's bar.
- **PR opened, not merged.**

## Stop-the-line triggers

If any of these fire, STOP and surface:

- Conflicts between Sheet emails and existing `educators` rows (the educator-gate flow may have written some, or a prior partial migration left some). The migration script must surface and the operator must decide: merge them (which one wins?) or skip them (and what's the user-facing implication?).
- The Sheet has rows with shapes that don't fit the migration mapping (missing columns, unexpected statuses, multi-language rows that the existing `language` column can't represent). Don't guess.
- The `UNIQUE(email)` constraint trips during the migration (which means the Sheet has duplicates — #75 manifesting in the existing data). Surface and decide which row to keep.
- Post-deploy, the smoke test fails on a flow that worked pre-deploy. Don't retry blindly; the most likely cause is a missed caller-site update or an env-var that didn't actually land in the container.

## Scope estimate

~1 session, 1 PR. 6 commits in the PR. **Closes #75.** Drops `composio` from `requirements.txt`. Removes `composio_client.py`. Removes Composio-related env vars from `.env.example` + `CLAUDE.md`.

If by the third hour you haven't done the prod migration, something's wrong — surface for re-scoping.

## Begin by

1. Read the inputs in the order listed in "Read these first." Don't skim.
2. Confirm session 04's state — what's actually in `composio_client.py`, `notifications.py`, `educator_service.py`, etc. The scope assumptions above are predicated on session 04 landing as planned; if it didn't, surface the divergence.
3. Inspect the current Google Sheet (count rows, distinct emails, status distribution). Operator can provide a CSV export if Composio's dashboard is still down.
4. Produce a Phase-1 plan with: the new `mailing_list` implementations; the migration script CLI shape and asserts; the test list; the env-var and doc edits; the commit order.
5. **Wait for operator approval on the Phase-1 plan before any code write.**
