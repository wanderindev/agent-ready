# Fix brief — issue #63: Educator email lookups are exact-match — case variations create duplicate accounts

## Identification

You are an autonomous agent resolving issue #63 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

**PII / production-touch note (read first):** The `educators` table stores email addresses (PII) and backs both the educator-access gate and the mailing list. Your change is application-layer normalization PLUS one forward-only, additive, collision-safe Alembic data migration that lowercases existing rows. No schema change (the `UNIQUE(email)` constraint already exists), no citext, no `.env`, no deploy. But because the migration mutates production PII rows on the next `alembic upgrade head`, you MUST make it collision-safe (see Default Rules) and you MUST put a loud "Production touch: yes — additive data migration touching PII; operator must review before running against prod" line in the PR body.

## Operational notes

This is a backend, test-only-execution issue (no live API needed). The operator's main checkout usually has the dev stack running, so do NOT run a naïve `docker-compose up`. Run tests natively against a throwaway testcontainer instead:

- The test suite uses `testcontainers` (`PostgresContainer("postgres:17-alpine")`) — see `backend/tests/conftest.py`. It spins up its own ephemeral Postgres; no port collisions with the operator's stack.
- From the worktree: install deps and run pytest natively.
  ```bash
  cd backend
  python -m venv .venv && . .venv/bin/activate   # or use uv/existing interpreter
  pip install -r requirements.txt
  pytest tests/test_educator_service.py tests/test_educators_api.py tests/test_mailing_list.py -q
  ```
  Requires a working Docker daemon for testcontainers (already available in this environment). Do NOT commit `.venv`.
- Lint: `ruff check app tests` and `ruff format --check app tests` from `backend/`. Note ruff is unpinned in this repo; if your local ruff flags pre-existing issues unrelated to your diff, only fix what your change introduced.
- Do NOT run `alembic upgrade` against any real database. Verify the migration only by: (a) it imports cleanly, (b) `alembic upgrade head` succeeds against the testcontainer (the conftest uses `Base.metadata.create_all`, not migrations, so to exercise the migration write a small test or just confirm it's syntactically valid and the down_revision chains correctly).

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

**Goal:** normalize educator emails (strip whitespace + lowercase) on every write/lookup path so `User@Example.com` and `user@example.com` resolve to the same row, preventing duplicate accounts. The `educators.email` column already has `UNIQUE` (`backend/app/models/educator.py:25`) — no schema change.

Do all three layers:

### 1. Pydantic request-schema normalization (primary fix)

Add an email-normalizing validator to every request schema whose `email` field targets the `educators` table:

- `backend/app/schemas/educator.py` — classes with `email: EmailStr`: `EducatorLoginRequest` (L9), `EducatorSignupRequest` (L21), `EducatorVerifyCodeRequest` (L48), `EducatorCheckAccessRequest` (L60), `EducatorUnsubscribeRequest` (L69). (`EducatorConfirmRequest` has no email — skip it.)
- `backend/app/schemas/subscribe.py` — `SubscribeRequest` (L7), `UnsubscribeRequest` (L30). (`ConfirmRequest` has no email — skip it.)

Preferred implementation: a shared `field_validator("email")` that returns `v.strip().lower()`. `EmailStr` validates RFC syntax but does NOT lowercase. Because `EmailStr` runs first, apply your normalizer in `mode="after"` (or use a plain `field_validator` returning the lowercased string — `EmailStr` resolves to `str`, so returning a lowercased `str` is fine). Define one tiny reusable validator (e.g., a module-level function or a small mixin/base) rather than copy-pasting six times, but copy-paste is acceptable if a shared helper feels heavier than the duplication.

There is no existing email-normalizing validator in the repo. `backend/app/schemas/booking.py:99,141` show the project's `@model_validator(mode="after")` idiom if you want a reference for validator placement.

### 2. Defensive service-layer normalization

Each public service function receives `email: str` and queries by it. Add `email = email.strip().lower()` as the first line of each (defensive depth — a future non-schema caller, e.g. an internal script, won't bypass normalization):

- `backend/app/services/educator_service.py`: `login` (param L141, lookup L153), `signup` (param L213, lookup L228), `verify_code` (param L336, lookup L343), `check_access` (param L411, lookup L414), `unsubscribe` (param L434, lookup L437).
- `backend/app/services/mailing_list.py`: `subscribe` (param L66, lookups L78 & L99), `unsubscribe` (param L232, lookup L240).

This makes the stored `Educator(email=...)` rows (educator_service.py L271; mailing_list.py L83) get the normalized value too, so writes and reads agree.

**Canonical in-repo pattern for case-insensitive email handling:** `backend/app/api/dashboard.py:1621` already does `func.lower(AdminEmail.email) == body.email.lower()`. You are choosing the *normalize-on-write* variant (lowercase the input rather than `func.lower()` every comparison) because writes are also normalized, so a plain `==` against an already-lowercased column is correct and cheaper. Do NOT switch the existing `==` lookups to `func.lower(...)`; instead normalize the inputs as above so `==` stays correct.

### 3. Forward-only data-normalization Alembic migration

Create `backend/alembic/versions/0003_normalize_educator_emails.py`:
- `revision = "0003_normalize_educator_emails"`, `down_revision = "0002_drop_flask_orphans"` (current head — verified chain: 0000_baseline → 0001_align_prod_to_models → 0002_drop_flask_orphans).
- `upgrade()`: lowercase + trim existing rows **collision-safely** (see Default Rules). Only update rows where the normalized value differs AND no other row already holds the normalized value.
- `downgrade()`: no-op with a comment (lowercasing is lossy and irreversible; `def downgrade(): pass`).

### Drift corrections vs the issue body (the source wins)
- The issue's line numbers (143/209/281/326/362/388) are stale — use the lines above.
- The issue lists only `educator_service.py`; it MISSES the 3 `mailing_list.py` sites (L78, L99, L240) that hit the same table — they ARE in scope (same bug class, same table).
- The issue's `MagicLink.admin_email` claim is imprecise and OUT of scope (see below).

## Scope

### IN scope
- `backend/app/schemas/educator.py` — add email-normalizing validator to the 5 email-bearing request classes.
- `backend/app/schemas/subscribe.py` — add email-normalizing validator to `SubscribeRequest`, `UnsubscribeRequest`.
- `backend/app/services/educator_service.py` — defensive `email = email.strip().lower()` in the 5 public fns named above.
- `backend/app/services/mailing_list.py` — defensive normalization in `subscribe` and `unsubscribe`.
- `backend/alembic/versions/0003_normalize_educator_emails.py` — NEW collision-safe forward-only data migration.
- `backend/tests/test_educator_service.py`, `backend/tests/test_educators_api.py`, `backend/tests/test_mailing_list.py` — add case-insensitivity tests.

### OUT of scope (do NOT touch)
- `backend/app/models/magic_link.py` (`MagicLink.admin_email`, `AdminEmail`) and `backend/app/api/auth.py` AdminEmail lookups. The issue mentions `MagicLink.admin_email` but there is no such `==` lookup, and `AdminEmail` is a different table/model. Leave it. If you believe it's worth fixing, note it in the PR as a follow-up only.
- `backend/app/api/dashboard.py:1621` — already case-insensitive; it's your reference pattern, do not modify.
- The `educators` model schema (`backend/app/models/educator.py`). No citext, no new constraint — `UNIQUE(email)` already exists.
- Any actual row-merge/dedup of colliding accounts. If two rows would collapse to one normalized email, the migration LOGS and SKIPS them (do not delete or merge). Real dedup is a separate human-reviewed task per the issue.
- Other `email: EmailStr` schemas not targeting the `educators` table (`order.py`, `contact.py`, `admin.py`, `dashboard.py`) — out of scope.

## Default rules for likely ambiguities

- **Normalization rule**: `email.strip().lower()`. Lowercase BOTH local-part and domain (the issue's Option 1; real providers all normalize the local-part too). Strip leading/trailing whitespace.
- **Validator style**: prefer a single shared `field_validator("email")` helper imported into both schema modules; copy-paste into each class is acceptable if cleaner. Keep it minimal — return the normalized string, do not re-validate syntax (EmailStr already did).
- **Don't break EmailStr ordering**: ensure the normalizer runs AFTER EmailStr validation. A plain `@field_validator("email")` returning `v.strip().lower()` works because the field is already an `EmailStr` (str subclass) by the time the validator sees it. Verify with a test feeding `Test@Example.COM`.
- **Migration collision-safety (critical)**: in `upgrade()`, use raw SQL via `op.execute` (mirrors the style in `0001_align_prod_to_models.py`). Update only non-colliding rows. A safe form:
  ```python
  op.execute("""
      UPDATE educators e
      SET email = lower(btrim(e.email))
      WHERE e.email <> lower(btrim(e.email))
        AND NOT EXISTS (
            SELECT 1 FROM educators o
            WHERE o.id <> e.id AND o.email = lower(btrim(e.email))
        )
  """)
  ```
  This lowercases/trims every row whose normalized form is free, and silently leaves any row whose normalized form would collide with an existing row (so the UNIQUE constraint can never fire). Do NOT attempt to merge/delete collided rows.
- **down_revision**: `"0002_drop_flask_orphans"` (verified head). If `alembic heads` shows a different head when you run, follow the source and update accordingly.
- **Tests**: add at minimum — (a) service test: signup with `New@Example.COM` then login with `new@example.com` returns the same row / grants access (educator_service); (b) API test: POST `/api/v1/educators/signup` with mixed-case email creates a lowercased row (assert via `db.query(Educator)`); (c) mailing_list test: subscribe with mixed-case then again with lowercase routes to the existing-row branch (not a second insert). Use the existing `test_db` / `test_client` / `patched_emails` fixtures and the `_make_educator` helper already in `test_educator_service.py`. Mirror existing test structure; email senders are patched (`app.services.educator_service._send_confirm_email`, `_send_verify_code_email`, and the mailing_list equivalents).
- **Do not weaken existing security tests** (the `# ORACLE:` assertions encode access-control policy). Your normalization must not change which branch a correctly-cased email hits.

## Failure-mode escape hatch

If the primary path is blocked — e.g., a validator placement breaks EmailStr parsing in a way you can't resolve, or the migration can't be made collision-safe — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X; did Y instead" comment is a good outcome.

## Self-review checklist (before opening the PR)

- [ ] Only the IN-scope files were modified; no OUT-of-scope file touched.
- [ ] All 7 schema request classes (5 educator + 2 subscribe) lowercase+strip email; verified with a mixed-case test.
- [ ] All 7 service-fn entry points normalize email defensively.
- [ ] New migration `0003_normalize_educator_emails` exists, chains `down_revision="0002_drop_flask_orphans"`, is collision-safe (skips would-be collisions), and `downgrade` is a documented no-op.
- [ ] New tests added and the three target test files pass against the testcontainer.
- [ ] `ruff check app tests` and `ruff format --check app tests` clean for the diff (no NEW issues vs main baseline).
- [ ] No schema/constraint change to `educators`; no citext; no `.env`/deploy touched.
- [ ] PR body has the loud "Production touch: yes — additive PII data migration; operator must review before `alembic upgrade head` against prod" line.

## PR shape

- **Branch**: `fix/issue-63-educator-email-normalization`
- **Title**: `fix(#63): normalize educator emails to prevent case-variant duplicate accounts`
- **Body must include**: one-line summary; a **"Production touch: yes — additive PII data migration; operator must review before running against prod. Verified by: <how>"** line; the self-review checklist with each item marked; a test plan; the drift note (stale line numbers corrected; mailing_list.py sites added; MagicLink/AdminEmail left out of scope); `Closes #63`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (schemas + services + migration + tests), and any flags you surfaced (especially the PII-migration production touch and the MagicLink/AdminEmail out-of-scope decision). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 63`) and open the files named in "The task"; confirm the verified facts and line numbers still hold (the issue's own line numbers are stale — trust the source).
2. Confirm the alembic head (`grep down_revision/revision in backend/alembic/versions/*.py`) is still `0002_drop_flask_orphans`.
3. Make the change, staying strictly within IN scope.
4. Run ruff + the three target test files against the testcontainer per Operational notes; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
