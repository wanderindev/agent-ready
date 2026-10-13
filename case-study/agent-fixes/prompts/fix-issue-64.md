# Fix brief — issue #64: Educator model lacks verify_code_attempts / verify_code_last_attempt_at columns (prerequisite for rate limiting)

> ⚠️ HELD AT GATE 3 (production-touch). The brief-writing agent's verdict: **production-touch YES, tractable for autonomy: no.** This authors an Alembic schema migration against the `educators` table — a production-carried PII/auth-gating table. NOT auto-dispatched. The operator must explicitly override to proceed (agent authors the file artifact only; never applies the migration to prod). Brief preserved below for that case.

> ⚠️ PRODUCTION-TOUCH BLOCKER (read first). This issue authors an Alembic schema migration against the `educators` table — a production-carried PII/auth-gating table. Authoring the migration file is a safe, reviewable code artifact. APPLYING it to any production or real database is NOT in your scope and you MUST NOT do it. Do not run `alembic upgrade` against anything but a throwaway test database. The operator applies the migration to prod by hand after review. If this constraint makes the task impossible to complete as a normal PR, that is fine — open the PR for the file artifact only.

## Identification

You are an autonomous agent resolving issue #64 in the `panama-in-context` codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description.

## Operational notes

- This is a BACKEND change: one model edit + one new Alembic revision file. It needs **no live DB and no docker-compose** to author. Do NOT stand up the dev stack.
- TEST DISCIPLINE (binding): the change is additive schema only. Validate by:
  1. Run the two adjacent educator test files scoped + quiet: `pytest tests/test_educator_service.py tests/test_educators_api.py -q --tb=short`. Reuse any existing venv; skip `pip install` if deps are already present. If no venv/deps exist and standing one up is heavy, see the escape hatch — do NOT build a docker stack just for this.
  2. Once those pass, run the FULL suite ONCE as the final gate, quiet: `pytest -q`. This is UNCONDITIONAL (a model/metadata change can break distant tests). A passing run prints ~one line.
  3. If the full run FAILS: fix it, but iterate with SCOPED runs, not the full suite. Re-run full once to confirm green. If you can't reach green within the runaway bounds, open a DRAFT PR naming the failing tests.
- DB DISCIPLINE: do NOT run `alembic upgrade`/`downgrade` against any real or production database. If you want to sanity-check the migration imports cleanly, a Python import of the revision module is sufficient; do not execute DDL against prod.
- STALE-STATE DISCIPLINE: if a command returns empty or is cancelled, re-run it ONCE; if still unclear, proceed from what you know or bail to a draft. No probe storms.

## When this brief and the source disagree — the four shapes

1. Brief said exclude, source implies include → include it and flag in the PR description.
2. Brief is factually wrong about the codebase → follow the source, not the brief; flag in the PR description.
3. Brief is correct for the primary case but didn't anticipate a sub-case → follow the brief AND surface the tension in the PR description.
4. You see a clearly-improvable adjacent thing within the issue's intent → make the improvement and flag it. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

Add two attempt-tracking columns to the `educators` table so a later rate-limiting fix (#53) is unblocked. NO behavior change ships in this PR — columns are added but read/written by nobody yet (verified: `grep -rn "verify_code_attempts" backend/` returns nothing).

**Change 1 — model.** In `backend/app/models/educator.py`, add two columns to the `Educator` class. Place them with the verify-code group (immediately after the `verify_code_expires_at` line at `backend/app/models/educator.py:43`), mirroring the existing `mapped_column` style (e.g. lines 42-46). Add the `Integer` import to the existing `from sqlalchemy import ...` line (currently `from sqlalchemy import String, func` at line 5):

    # Rate-limit tracking for 6-digit verify codes (consumed by #53)
    verify_code_attempts: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    verify_code_last_attempt_at: Mapped[datetime | None] = mapped_column(nullable=True)

`datetime` and `Mapped`/`mapped_column` are already imported (lines 3, 6). `server_default="0"` (string) is required for a NOT NULL column so the DDL backfills existing rows.

**Change 2 — migration.** Create a NEW revision file. IMPORTANT — this repo does NOT use `op.add_column`/`sa.Column` autogenerate. Every existing migration uses raw SQL via `op.execute(...)` / `op.get_bind().exec_driver_sql(...)`. Mirror the canonical header + docstring + raw-SQL body of `backend/alembic/versions/0003_normalize_educator_emails.py` (lines 23-52) and the `ALTER TABLE ... ADD COLUMN` raw-SQL form analogous to the `DROP COLUMN` calls in `backend/alembic/versions/0002_drop_flask_orphans.py:54-55`.

- **Filename:** `backend/alembic/versions/0004_educator_verify_code_attempts.py`. (The `alembic.ini` `file_template` is timestamp-based, but every existing version file is hand-named sequentially `0000_`…`0003_`. Follow the existing files, NOT the template.)
- **Revision header (exact):**
  - `revision = "0004_educator_verify_code_attempts"`
  - `down_revision = "0003_normalize_educator_emails"`  (this is the current head — chain is 0000→0001→0002→0003)
  - `branch_labels = None`
  - `depends_on = None`
- **`upgrade()`** — additive, idempotent, prod-safe:

      op.execute(
          'ALTER TABLE public.educators '
          'ADD COLUMN IF NOT EXISTS verify_code_attempts integer NOT NULL DEFAULT 0'
      )
      op.execute(
          'ALTER TABLE public.educators '
          'ADD COLUMN IF NOT EXISTS verify_code_last_attempt_at timestamp without time zone'
      )

  (`IF NOT EXISTS` mirrors the defensive style of the 0002 drops; the `timestamp without time zone` type matches the other naive-datetime columns in this table, e.g. `verify_code_expires_at`. Keep the `public.` schema prefix — every existing migration uses it.)
- **`downgrade()`** — reverse, additive-safe:

      op.execute('ALTER TABLE public.educators DROP COLUMN IF EXISTS verify_code_last_attempt_at')
      op.execute('ALTER TABLE public.educators DROP COLUMN IF EXISTS verify_code_attempts')

- Write a module docstring in the style of 0003: explain it adds two attempt-tracking columns to `educators`, that it is a pure additive schema change unblocking the rate-limiting logic in #53, references issue #64, and notes the columns are unused by application code as of this revision.

**Drift correction (issue body vs source):** the issue's "Desired state" snippet shows ORM `mapped_column` syntax and does not mention migration style. The repo convention is raw-SQL migrations (no autogenerate) — follow the raw-SQL form above. The issue also omits that the model file must be edited too; both Change 1 and Change 2 are required and must agree (the `env.py` autogenerate guard relies on model↔metadata lockstep).

## Scope

### IN scope
- `backend/app/models/educator.py` — add the two columns + the `Integer` import.
- `backend/alembic/versions/0004_educator_verify_code_attempts.py` — NEW file (the migration).

### OUT of scope (do NOT touch)
- `backend/app/core/config.py` — do NOT add the `verify_code_attempts_max` Settings constant. The issue calls it "also helpful," but it has NO consumer until #53 implements the rate-limiting logic. Adding unused config now is speculative; it belongs in #53. Leave config.py untouched.
- The verify-code rate-limiting LOGIC itself (incrementing, resetting on success, invalidating the code past the cap) — that is #53, not this issue. Add the columns only; wire up nothing.
- `app/services/educator_service.py`, `app/services/mailing_list.py`, any API/schema — no reads/writes of the new columns in this PR.
- The `auth_audit_log` table / #61 — the issue floats it as a "more thorough variant"; it is explicitly NOT this issue. Do the simple per-user columns only.
- Any other migration file (0000–0003) — do not edit existing revisions.
- Do NOT run `alembic upgrade`/`downgrade` against any real or production database.

## Default rules for likely ambiguities

- **Column names — exact:** `verify_code_attempts` (int, NOT NULL, default 0) and `verify_code_last_attempt_at` (nullable datetime). Use these names verbatim in both the model and the migration.
- **Default handling:** model side uses `server_default="0"` (string literal) for the int; migration side uses `DEFAULT 0`. The nullable datetime gets NO default in either place.
- **Datetime type in SQL:** `timestamp without time zone` (matches the existing naive datetime columns on this table; the model's `datetime | None` mapped_column with no `DateTime(timezone=True)` produces a naive column).
- **Migration revision id / down_revision:** as specified above. The current head is `0003_normalize_educator_emails` — do NOT guess; it is verified.
- **Filename numbering:** `0004_` prefix, sequential. Ignore the timestamp `file_template` in alembic.ini; match the existing hand-named files.
- **Model column placement:** group with the other verify-code columns (after line 43), not at the bottom; this matches the file's existing logical grouping (comments group columns by concern).
- **Import:** add `Integer` to the existing `from sqlalchemy import String, func` import (→ `from sqlalchemy import Integer, String, func`). Do not add a separate import line.
- **Tests:** all existing `Educator(...)` constructions in tests use keyword args (verified: `tests/test_educators_api.py`, `tests/test_educator_service.py`, `tests/test_mailing_list.py`), and the new columns have safe defaults, so no test edits should be needed. Do NOT add new tests for an unused additive column unless a test breaks — if one does, the fix is the minimal change to keep it green, not new coverage.

## Failure-mode escape hatch

If the primary path is blocked — e.g. you cannot run the test suite at all in this worktree without standing up infrastructure that would touch a real DB, or the migration head turns out to differ from `0003`, or applying/validating the migration would require touching production — STOP and open the PR as a **draft** with a comment describing exactly what is blocked. Authoring the two files (model + migration) and opening a draft PR for human application is a fully acceptable outcome for this issue, because the production-application step is intentionally out of your hands. If you cannot even run `pytest`, still commit the two-file change and open a draft noting tests were not run locally.

**Runaway-iteration guard (binding).** STOP immediately and open a draft PR if: you've made ~40+ tool calls; you're on your third attempt at the same fix; you've already pushed and are now rewriting your own commits; or a parallel tool batch was cancelled and you're unsure of your state. A stuck retry loop is the most expensive failure mode — bail to a draft and let the operator look.

## Self-review checklist (before opening the PR)

Open the PR as **draft** if any item fails, naming the failed item.

- [ ] Only the two IN-scope files modified (`git diff --name-only` shows exactly `backend/app/models/educator.py` and the new `backend/alembic/versions/0004_*.py`).
- [ ] `config.py` NOT touched (no `verify_code_attempts_max` added).
- [ ] Model: both columns added with the exact names/types/defaults above; `Integer` imported.
- [ ] Migration: `down_revision = "0003_normalize_educator_emails"`; raw-SQL `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`; both upgrade and downgrade present; docstring written.
- [ ] No application code reads/writes the new columns (this PR is schema-only).
- [ ] `ruff check` clean vs main baseline (no new issues): `ruff check backend/app/models/educator.py backend/alembic/versions/0004_*.py`.
- [ ] Scoped educator tests pass, then full `pytest -q` passes once (or draft with the failing tests named, or draft noting tests couldn't be run locally).
- [ ] PR description includes the **"Production touch: yes — schema migration of the educators (PII/auth) table; migration authored only, NOT applied; operator applies to prod by hand"** line.

## PR shape

- **Branch:** `fix/issue-64-educator-verify-code-attempt-columns`
- **Title:** `fix(#64): add verify_code_attempts / last_attempt_at columns to educators`
- **Body must include:** one-line summary; a **"Production touch: yes — additive schema migration of the educators PII/auth table; file authored only, NOT applied to prod (operator applies by hand after review)"** line; the self-review checklist with each item marked; a test plan; an explicit note that `verify_code_attempts_max` (Settings) and the rate-limiting logic are deferred to #53; `Closes #64`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready:** ready-for-review if all self-review items pass; draft otherwise. Given the production-touch posture, it is acceptable for the operator to keep this as a review-then-hand-apply PR regardless.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (model + migration), and any flags you surfaced (especially: did the migration head match `0003`? did any test need touching?).

## Begin by

1. Read the issue (`gh issue view 64`) and `backend/app/models/educator.py`, `backend/alembic/versions/0003_normalize_educator_emails.py`, and `backend/alembic/versions/0002_drop_flask_orphans.py`; confirm `0003_normalize_educator_emails` is still the head (no `0004_*` file exists yet).
2. Edit the model (Change 1).
3. Create the migration file (Change 2), staying strictly within IN scope.
4. Run ruff on the two files; run scoped educator tests, then full `pytest -q` once.
5. Self-review checklist.
6. Open the PR (draft if any item failed or if tests couldn't run; ready-for-review otherwise).
7. Report back and STOP.
