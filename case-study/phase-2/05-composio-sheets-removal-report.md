# Phase 2 — Session 05 Report: Composio Sheets removal — mailing list → `educators` DB table; full Composio retirement

**Date:** 2026-05-25
**Duration:** ~1 session (Phase 1 plan → Phase 2 implement → Phase 3 deploy + smoke test → Phase 4 PR)
**Prompt:** `docs/phase-2/prompts/05-composio-sheets-removal-mailing-list-to-db.md`
**PR:** [#144](https://github.com/wanderindev/panama-in-context/pull/144)

---

## Executive summary

Closes the Composio retirement that session 04 began. Four-commit PR that:

1. Migrates `mailing_list.subscribe / confirm / unsubscribe` from Composio Google Sheets calls to ORM queries against the existing `educators` DB table. No schema migration needed — the model was already shaped from Phase 1's Educator Access System plan.
2. Closes #75 — the prior `_find_row`/`_append_row` check-then-act race becomes a `UNIQUE(email)` constraint violation that's caught and recovered from at the application layer via SELECT-first + IntegrityError fallback. Exactly one row per email is now guaranteed at the database level.
3. Drops the `composio` dependency entirely from `requirements.txt`. Removes `get_composio()`, the `from composio import Composio` import, `_composio_client`, and three dead Settings fields (`composio_api_key`, `composio_user_id`, `mailing_list_sheet_id`).
4. **Renames** `app/services/composio_client.py` → `app/services/email_sender.py` (and `tests/test_composio_client.py` → `tests/test_email_sender.py`). 12 import sites updated. Operator override of the brief's "leave the rename for a follow-up" guidance — recorded in the cross-session register.

The session ran cleaner than session 04 (no fence fires beyond the anticipated `docker push`, no stop-the-line incidents, no scope-creep moments). End-to-end production smoke test: operator subscribed to educator materials (educator-gate path → exercises the renamed `email_sender.send_email`) AND subscribed to the mailing list (new ORM path → INSERT into `educators`, confirmation email via SMTP relay). Both worked.

The session is also a **methodology refinement** session — three cross-session register entries surfaced:
- The `Closes #N` prompt-commit-body anti-pattern (carried forward from session 04, applied here — #75 was auto-closed at prompt-commit time as expected).
- **Skip-the-data-migration pattern** — when a dependency has been operationally dead before the cutover session, interrogate the data-migration step before executing it. Saved a migration script + Sheet-API auth work + ~30 minutes.
- **Operator-override-of-brief pattern** — first instance in Phase 2 of the operator pushing back on the brief's scope decision (the rename). The brief's defer-rename argument was correct on diff size but wrong on long-term value; the override was correct.

---

## By the numbers

| Metric | Count |
|---|---|
| Commits in branch | 4 (vs. brief's planned 6 — see below) + 1 docs commit |
| Files added | 3 (`tests/test_mailing_list.py`, this report, +1 renamed test file) |
| Files modified | 13 (incl. 9 import-site updates for the rename) |
| Files renamed via `git mv` | 2 (`composio_client.py` → `email_sender.py`; `test_composio_client.py` → `test_email_sender.py`) |
| Files deleted | 1 (`composio_client.py` — via the rename) |
| Files modified (docs) | 4 (`CLAUDE.md`, `agent-friendly-outcomes.md`, `prompts/INDEX.md`, `cross-session-register.md`) |
| Files modified (operator, out-of-band) | 2 (`backend/.env.example`, top-level `.env.example`) |
| Unit tests added | 15 (mailing_list ORM tests, incl. the #75 race-closure regression) |
| Unit tests passing on changed code | 171/171 (full suite, host pytest) |
| Ruff status on changed lines | clean; pre-existing `F401` × 2 (`auth.py`, `orders.py`) carried forward per session-02/03/04 precedent |
| Auto-approve-fence fires (legitimate) | 1 (`docker push registry.digitalocean.com*` — resolved by operator running it themselves via `!`) |
| Stop-the-line incidents | 0 |
| Prod-touching commands surfaced for explicit approval | 1 deploy (image build local; push gated, operator-executed) |
| Prod smoke test | mailing-list subscribe + educator-materials signup; both worked end-to-end |
| Issues addressed | 1 (#75) |
| Outstanding decisions awaiting operator at session end | 0 (PR open for review; merge is operator-driven) |

**Commit-count refinement.** Brief estimated 6; final count is 4. The reductions:
- Three planned commits (subscribe / confirm / unsubscribe — one per function) collapsed into one `feat(mailing-list): migrate subscribe/confirm/unsubscribe to ORM` because the three functions are one logical unit; separate commits would have been review-friction without conceptual benefit.
- One commit dropped (the migration script in `scripts/one_off/`) because the operator chose to skip the data migration in Phase 1.
- The rename added one commit that wasn't in the brief (operator override).
- The doc-commit landed as commit 4 — folded the CLAUDE.md scrub with the `NotificationService` docstring fix.

---

## What was done

### Phase 1 — Local prep + plan

Read all session-04 + session-05 inputs in order: session 04's report (to confirm what shipped), full `mailing_list.py`, `Educator` model, `api/subscribe.py`, current `composio_client.py`, `educator_service.py`, `.env.example` (top-level + `backend/`), `requirements.txt`, `.claude/settings.json`, outcomes-log conventions, cross-session register, CLAUDE.md, memory.

Confirmed post-session-04 state: PR #143 merged into main; `composio_client.py` has `send_email` (SMTP) + `get_composio()` (Sheets); `composio>=0.1.0` in requirements.txt; the operator's `.env.example` change removed the Composio Gmail vars but left `MAILING_LIST_SHEET_ID`.

**One context-preservation observation surfaced** to the operator: session 05's brief said "fresh Claude Code instance, separate from the orchestrator's main session," but I was carrying full session-04 context from the same conversation. Operator chose to continue in the same instance ("the work that you just did is loosely related to this new task"). The "fresh instance" pattern is a soft convention that the operator can override when the carried context is load-bearing for the new work — recorded as a process-note for future sessions.

**Five sub-decisions surfaced** for operator approval, all about how the mailing-list flow interacts with the existing educator-gate rows in the shared `educators` table:

| Sub | Scenario | Operator decision |
|---|---|---|
| 1 | Column semantics | `mailing_list: bool` is the marketing-opt-in flag; `status` shared with gate |
| 2 | Subscribe on CONFIRMED gate row | Flip flag to True; no new email |
| 3 | Subscribe on PENDING gate row | Reuse existing `confirm_token`; flip flag |
| 4 | Unsubscribe on row with gate access | Flip `mailing_list=False` only; status stays CONFIRMED |
| 5 | Subscribe on UNSUBSCRIBED row | Resurrect to PENDING with new token |

All five resolved to option (A) — preserve the existing schema, treat `mailing_list` as the opt-in flag, share `status` semantics. Sub-4 (preserve gate access on mailing-list unsubscribe) has its own regression test (`test_confirmed_with_gate_access_preserves_gate`) so a future change can't accidentally revoke gate access.

**Five Q-questions for the operator:**
- Q1: confirm conflict semantics (all A). **Confirmed.**
- Q2: prod `educators` row count. **4 rows.**
- Q3: data migration source. **Skip the migration; start empty.**
- Q4: `.env.example` edits. **Operator pastes.**
- Q5: rename `composio_client.py`. **My lean was "no, per brief." Operator override: "yes, rename now."**

Q5 was the meaningful one. The brief's "defer the rename" argument was about diff size; the operator's override was about long-term clarity of a misleading filename. The diff-size cost (12 single-line import changes) was small; the long-term value (no misleading import in indefinite future code reading) was real. **The override was correct and the agent's initial "follow the brief" lean was wrong.** Recorded as a cross-session register entry; first instance in Phase 2 of an operator overriding the brief's scope.

### Phase 2 — Implementation

Branch `refactor/composio-sheets-removal-mailing-list-to-db`. Four commits:

**Commit 1 — `feat(mailing-list): migrate subscribe/confirm/unsubscribe to ORM (#75)`** (3804195).

Rewrites all three public functions in `mailing_list.py`. Each takes a `Session` (threaded through `api/subscribe.py`'s three endpoints via `Depends(get_db)`). The Composio Sheets helpers `_find_row` / `_append_row` / `_update_row` become dead code in this commit (removed in commit 2 to keep the behavior change separate from the dead-code drop).

The race-closure pattern in `subscribe`:

```python
def subscribe(email, source, language, db):
    existing = db.query(Educator).filter(Educator.email == email).first()
    if existing is not None:
        return _subscribe_existing(existing, source, language, db)

    # New email — INSERT
    educator = Educator(...)
    db.add(educator)
    try:
        db.commit()
    except IntegrityError:
        # Race window: concurrent subscribe inserted between our SELECT and INSERT.
        db.rollback()
        existing = db.query(Educator).filter(Educator.email == email).one()
        return _subscribe_existing(existing, source, language, db)

    _send_confirmation_email(...)
    return {"success": True, "status": "pending", ...}
```

15 unit tests in `tests/test_mailing_list.py`:
- `TestSubscribeNew` (2): insert+email; send-failure-keeps-row.
- `TestSubscribeExistingPending` (2): token-reuse; gate-row flag-flip.
- `TestSubscribeExistingConfirmed` (2): already-subscribed; gate-row flag-flip with access preservation.
- `TestSubscribeExistingUnsubscribed` (1): resurrection.
- `TestSubscribeRaceClosure` (1): IntegrityError branch — the #75 closer.
- `TestConfirm` (2): valid-token + invalid-token.
- `TestUnsubscribe` (5): confirmed-mailing-only; confirmed-with-gate-access (sub-4 regression); not-found; gate-only-row; PENDING-rejects.

**One test-iteration moment worth recording.** First test run hit 6 failures: the `_subscribe_existing` function used `db.query(...).one()` after `db.rollback()`, which under the fixture's outer-transaction wrap rolled back the pre-created row inserted by the test. Diagnosis: the fixture rolls back the entire transaction (not just a savepoint), so any rollback inside the SUT erases the test setup. Fix: refactor `subscribe` to SELECT-first, only INSERT/rollback in the genuine no-row case. The SELECT-first pattern is also cleaner production code — most subscribes don't hit a race; pre-checking avoids the commit/rollback gymnastics on the common path. 15/15 pass after the fix. Moved on.

**Commit 2 — `refactor(composio): drop Sheets helpers, env vars, and composio dependency`** (317e2ec).

The dead-code purge. Removes from `composio_client.py`: `_composio_client`, `get_composio()`, `from composio import Composio`. Removes from `core/config.py`: `composio_api_key`, `composio_user_id`, `mailing_list_sheet_id`. Removes from `requirements.txt`: `composio>=0.1.0` and its comment header. Grep confirms zero remaining references to those names in `app/` or `tests/`. Full test suite (171) passes.

**Commit 3 — `refactor(email): rename composio_client.py → email_sender.py`** (0845afc).

`git mv` for both the implementation and the test file. 12 import sites updated:
- `app/services/`: `educator_service.py`, `mailing_list.py`, `notifications.py`
- `app/api/`: `auth.py`, `booking_admin.py`, `contact.py`, `educators.py`, `orders.py`, `webhooks.py`
- `tests/`: `test_email_sender.py` (renamed; also mock-patch paths `patch("app.services.composio_client.smtplib.SMTP")` → `patch("app.services.email_sender.smtplib.SMTP")`), `test_mailing_list.py`, `test_notifications_dispatch.py`

Three docstring scrubs (rename-related; the deeper Composio scrubs are commit 4). One historical reference left intact: `test_notifications_dispatch.py` mentions the session-04 PR branch name `fix/composio-cluster-b` as an accurate breadcrumb to the contract flip's history. 171/171 still pass.

**Commit 4 — `chore(docs): scrub stale Composio references from CLAUDE.md and notifications.py`** (81278ad).

Three CLAUDE.md updates (architecture ASCII diagram, tech-stack table mailing-list row, testing-guidance mock list). One stale class docstring in `notifications.py` (was "via Composio Gmail SDK"; now "via the Google Workspace SMTP relay"). Three intentional historical references kept (in `email_sender.py`, `mailing_list.py`, `test_notifications_dispatch.py` docstrings) — these are about *what changed*, not *what the code uses today*.

**Test infrastructure note.** Same pre-existing state as sessions 02-04: `testcontainers` won't run inside `docker-compose exec backend pytest` because the dev compose doesn't mount `/var/run/docker.sock`. Ran from the host with `ENVIRONMENT=test /home/javier/anaconda3/bin/pytest`. 171/171 pass.

### Phase 3 — Production deploy + smoke test

**Pre-deploy operator preflight.** Operator confirmed they'd removed `COMPOSIO_API_KEY`, `COMPOSIO_USER_ID`, and `MAILING_LIST_SHEET_ID` from the production droplet's `.env`, and from both `backend/.env.example` and the top-level `.env.example` templates.

**Step 1 — deploy (backend-only).** Invoked the `deploy` skill. `docker build` completed in ~50 seconds (SHA `826fb3aafa2a`). Surfaced the `docker push` for explicit operator approval per the brief.

**Fence fire (anticipated).** L1 deny rule `Bash(docker push registry.digitalocean.com*)` blocked my push attempt. Operator ran the push themselves via `!` from terminal — same mediation pattern as session 04.

**Step 2 — smoke test.** Operator exercised **two paths end-to-end**:
- **Mailing list:** subscribe at the public CTA → confirmation email arrived → confirm link → unsubscribe. Net result: row inserted into `educators` with `mailing_list=True, status=PENDING`, then `status=CONFIRMED`, then `mailing_list=False, status=UNSUBSCRIBED`.
- **Educator materials:** signup at the educator gate → confirmation email arrived → access granted. This is the educator-gate flow which uses the *renamed* `email_sender.send_email` and the unchanged `educator_service.signup`. Confirms the rename didn't break anything.

Both flows worked first try. No allowlist issues (Workspace IP allowlist from session 04 still in effect). No fence fires beyond the anticipated push.

### Phase 4 — PR + housekeeping

Pushed branch (feature-branch push; no fence rule fires). Opened PR [#144](https://github.com/wanderindev/panama-in-context/pull/144) with the structured description Phase-2 working-model L3 requires.

Appended one row to `docs/phase-2/agent-friendly-outcomes.md` for #75 (`Outcome = not-yet-attempted` until merge).

Posted comment on issue #75 linking the PR. Note: #75 was auto-closed at session-05 prompt-commit time (same `Closes #N` mechanism as #67/#68 from session 04); the comment is informational and the PR description references the closed issue rather than re-closing.

Updated memory file `composio_breach_2026-05.md` to reflect that the Composio retirement is **complete** — both halves (email + Sheets) now landed; the memory itself is candidate for future deletion once Composio drops out of project context.

This report. INDEX.md update (session 05 entry refreshed with actual scope). Two new cross-session register entries (skip-the-data-migration pattern; operator-override-of-brief pattern).

---

## What's next

1. **Operator merges PR #144.** Outcomes-log `Outcome` column updates from `not-yet-attempted` to `clean-merge` via the tiny-PR-after-merge convention.
2. **The Composio retirement is complete.** No follow-up issues from this PR specifically. Adjacent unfinished work:
3. **Follow-ups worth filing** (not done this session):
   - **#80** — raw f-string HTML in `_send_confirmation_email`. Same shape as closed #31 (Jinja2 migration). Standalone PR.
   - **#37 layer 2** — `Order.notification_failed_at` column + admin-dashboard view (carried forward from session 04). Schema change needed.
   - **#68 deferred halves** — DeepL and Anthropic SDK timeouts (carried forward from session 04).
   - **Educator Access System gate flow** improvements per MEMORY.md (7-day window refinements, 6-digit code UX, frontend `EducatorAuthContext`). Separate larger initiative.
   - **Memory cleanup** — the `composio_breach_2026-05.md` memory entry can probably be deleted in a future session once Composio context is no longer load-bearing. Marked it as candidate for deletion in the file itself.

---

## Process notes

- **The brief's "fresh Claude Code instance" pattern is a soft convention, not a hard rule.** Session 05 ran in the same instance as session 04 because the carried context (12 sites, contract flip, breach context) was load-bearing for the new work. The operator's explicit override ("the work you just did is loosely related") was the right call — re-reading session 04's artifacts in a fresh instance would have produced the same final plan but more slowly. Pattern: **when sessions are tightly sequential and the prior session's structural decisions inform the next one, continuing the same instance is fine.** When they're independent (e.g., kicking off Wave 1's autonomous frontend agents), the fresh-instance convention earns its keep.
- **Phase 1's Q-questions are the load-bearing artifact.** Five questions surfaced this session; four were "lean A, confirm or override" defaults and one (Q5: rename) was a genuine "I went one way, here's the trade-off, what do you think?" The operator override on Q5 was the most valuable single output of the session. **Phase-1 plans should make at least one Q question a real ambiguity the operator can resolve cheaper than the agent can guess**, not just a checklist of pre-decided defaults. This session got that right by accident; future plans should aim for it deliberately.
- **The skip-the-data-migration moment was a methodology refinement.** The brief's Phase 1 step 4 ("Inspect the current Google Sheet ... count rows, distinct emails, status distribution, source distribution") assumed migration. The operator's Q3 answer ("skip the data migration — start the educators table empty") collapsed the brief's migration-script commit, the Sheet-API auth choice, the CSV-or-service-account dilemma, and the conflict-detection step into nothing. Saved ~30 minutes of work and one commit. **Pattern: when a dependency has been operationally dead before the cutover session, interrogate the data-migration step before executing it.** Recorded in the cross-session register.
- **The test-fixture rollback diagnostic was a 90-second debug, not a stop-the-line.** The first test run failed 6/15 because `_subscribe_existing` used `db.rollback()` after `IntegrityError`, which under the fixture's outer-transaction wrap nuked the test-setup row. Diagnosed by reading the conftest fixture once and matching it to the failure pattern. The fix (SELECT-first, only fall through to INSERT+IntegrityError-rollback in the genuine no-row case) is **also cleaner production code** — most subscribes don't race; pre-checking avoids commit/rollback gymnastics on the common path. The diagnostic that the test fixture was forcing me toward turned out to be the right production pattern.
- **The session was uneventful in the deliberate way session 03 was.** Session 02 had a stop-the-line on continue-section drift; session 03 had a dropped test plus a 5-commit straight line; session 04 had the `.env.example` stop-the-line + the fence fire on push; session 05 had only the anticipated fence fire on push and a 90-second test-fixture iteration. The trajectory across the four fix-execution sessions is **friction decreasing as the working model matures.** Prompts get sharper, the auto-approve fence's classes are well-understood, the operator-mediated mediations are routine. Worth recording: the *first* fix-execution session in any new repo will be choppy; the third or fourth should be straight lines.
- **Pre-existing ruff debt: leave it.** Same call sessions 02-04 made. Touched `mailing_list.py`, `email_sender.py`, `core/config.py`, `api/subscribe.py`, and the 12 import-site files for the rename; the pre-existing `F401`s in `auth.py` and `orders.py` were already there. Same precedent as session 04.

---

## What surprised me

- **The "skip the data migration" answer reduced the session's scope significantly.** I'd Phase-1-planned an entire migration-script commit (Sheet API auth choice, CSV ingestion, conflict detection, dry-run output, backup writes, etc.). The operator's single answer "skip" collapsed all of that. The friction reduction was 30 minutes minimum, probably more. **Phase 1 plans that surface "we could skip step X entirely" as an explicit option, not buried in prose, would let operators make these scope-collapse calls earlier.** Future Phase 2 Phase-1 plans should include a "what could we skip?" sub-question when there's a brief-listed step that might not be necessary.
- **The operator override on the rename was clarifying for me, too.** My Phase-1 lean was "leave it as-is per brief." The operator's "Q5 clarify, we would not have any composio logic, right? So the file would contain the new utilities to send email directly with Gmail? Why not rename it?" was a flat-out better argument than my deference-to-brief lean. Once I heard it stated, I agreed immediately. The agent default of "follow the brief" is right *most* of the time but **not when the brief's logic doesn't survive contact with the new reality**. The brief was written when session 04 was still hypothetical; after session 04 actually landed and Composio was actually gone from the email path, the rename's cost/value math had shifted. The brief didn't update; the operator did.
- **The `educator_service.signup` path was unchanged by this PR but exercised it for free during the smoke test.** Operator's "I tested signing up for materials and the mailing list" tested both the new ORM mailing-list path AND the educator-gate path (which uses the renamed `email_sender.send_email`). Two smoke-test signals for the price of one. Worth knowing for future test plans: a single user-facing flow that touches multiple subsystems can give multiple independent confidence signals.
- **#75 was already CLOSED at session start — same auto-close mechanism that affected #67/#68 in session 04.** The methodology lesson is the same one captured in the session-04 register entry ("Avoid `Closes #N` in prompt-drafting commit bodies"). Session-05's prompt commit (74a9252) also used `Closes #75` in its body. The cross-session register entry from session 04 was a prevention rule for *future* prompts; it didn't retroactively fix the session-05 prompt that had already shipped. **Lesson the methodology-discipline-decay lesson again:** rules added to the register only protect future work, not in-flight work that predates the rule. A *retroactive* sweep (e.g., a prompt-rewrite to drop the `Closes #N` syntax) would have prevented #75 from auto-closing — too late now, accepting the consequences, moving on.
- **The session went from start to PR-open in well under three hours.** Brief's "If by the third hour you haven't done the prod migration, something's wrong" trigger never fired. Phase 1: ~20 min. Phase 2: ~30 min (incl. the test-fixture diagnostic and re-run). Phase 3: ~10 min for deploy + smoke test (operator-driven smoke test was near-instant). Phase 4: ~30 min for PR + outcomes-log + comments + report + register. The session's actual budget pressure was less than half of what the brief budgeted. **Phase 2 sessions are getting fast; the prompts are doing more of the planning work, so the in-session execution compresses.**

---

## Cross-cutting checklist dispositions

Fix-execution session, not an audit. Recording the ones that fired or were materially checked:

- **Two-dimensional severity: blast-radius × evidence-of-impact (synthesis §8).** Applied to the rename decision (Q5). Blast radius of "leave the misleading filename" = every future import; evidence-of-impact = the brief itself acknowledged the misleading name (just argued the timing). The operator's override moved the rename inside-scope on the basis of structural-clarity > diff-size-conservatism. Disposition: **fired clean; the framing produced the better decision.**
- **Danger is not where complexity is (synthesis §8).** Most of the implementation complexity sat in commit 1 (the three-function rewrite + the IntegrityError race recovery + the existing-row branching). None of it was load-bearing for the risky parts of the session. The actual *risk* moments were (a) the deploy (mitigated by the fence + operator-runs-push pattern) and (b) the test-fixture rollback debug (mitigated by reading the fixture once and matching the failure pattern). Complexity in commit 1, risk distributed across phases 2-3, correctly localized. Disposition: **fired clean.**
- **Partial-correction debt umbrella.** This PR is the *closing* end of the Composio-retirement partial correction that session 04 began. The umbrella closes here. Session 04's PR was the partial; session 05's PR is the completion. The cross-session register and outcomes log both carry the breadcrumb. Disposition: **closed clean; umbrella discharged for the Composio dependency.**
- **Latent-but-uncrystallized risk.** From session 04, two carried forward: `docker.sock` test-infra and ruff-debt-wider-backend. Both still uncrystallized. Session 05 adds none new — the rename-related-import-site sweep gave high confidence that no consumer pattern was missed. Disposition: **two carried; none new this session.**
- **Swallowed-failure umbrella.** N/A for this session — no new swallowing introduced. The new IntegrityError branch in `subscribe` is the *opposite* of swallowing: a previously-silent duplicate-row outcome (race-induced) becomes a deliberate database-level rejection that the application layer catches and routes through the correct branch. The mailing-list flow is now more fail-loud than it was. Disposition: **fired clean; new code is fail-loud.**
- **Orchestrator's prior as a check (framing).** Priors stated in the brief:
  - "6 commits in the PR" — broke (actual: 4 + 1 docs).
  - "One-off migration script" — broke (operator skipped).
  - "The race-condition fix is the killer feature" — held (test exercised; pattern documented).
  - "Don't rename" — broke (operator override).
  - Two of four priors broke, both on the operator's call. The corrections were the cheap-to-discover-now kind. Disposition: **priors directionally held but ~50% required correction; operator authority was the trump card both times.**
- **Agent-friendly grading prior (synthesis §10).** #75 was filed `agent-friendly: no` (depends on the Sheets→DB migration shape decision; concurrency semantics need human judgment). In practice: with the prompt doing the concurrency-pattern decision upfront ("Handle the race naturally via UNIQUE(email): on integrity error, look up the existing row and branch on its status"), the in-session implementation was mechanical. Same pattern as session 04's cluster-B issues: **"agent-friendly: no" issues become agent-friendly in execution when the prompt does the planning.** Disposition: **filed grade correct for the issue in isolation; in-session execution easier because the prompt did the planning work.**

---

## Cross-references

- Phase 1 synthesis: `docs/pilot/phase-1-synthesis.md` (§5 fence, §8 two-dimensional severity, §10 agent-friendly grading)
- Phase 1 Area 4a report (cross-cutting services audit that surfaced #75): `docs/pilot/phase-1-area-4a-report.md`
- Session 01 report (planning): `docs/phase-2/01-kickoff-report.md`
- Session 02 report (articles 39/40 cleanup): `docs/phase-2/02-articles-39-40-cleanup-report.md`
- Session 03 report (full #99 fix): `docs/phase-2/03-issue-99-full-fix-report.md`
- Session 04 report (Composio email removal): `docs/phase-2/04-composio-email-removal-report.md`
- Session 05 prompt: `docs/phase-2/prompts/05-composio-sheets-removal-mailing-list-to-db.md`
- Outcomes log: `docs/phase-2/agent-friendly-outcomes.md`
- Cross-session register: `docs/methodology/cross-session-register.md`
- Memory: `memory/composio_breach_2026-05.md` (now reflects full Composio retirement; candidate for future deletion)
- GitHub: PR [#144](https://github.com/wanderindev/panama-in-context/pull/144); issue #75 (auto-closed; this PR is the implementation)
