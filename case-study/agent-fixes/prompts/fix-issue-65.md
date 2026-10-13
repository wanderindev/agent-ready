# Fix brief — issue #65: [Quality] MagicLink rows never pruned — expired/used links accumulate indefinitely

## Identification

You are an autonomous agent resolving issue #65 in the `panama-in-context` (wanderindev/panama-in-context) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend, test-only change (no live API access needed — the test only needs a database). The operator very likely has the dev stack running from the main checkout (`docker-compose up`), so DO NOT run `docker-compose up` from your worktree — you would hit port conflicts (5433/8000) and/or attach to the operator's containers (whose code volume is the main checkout, not your worktree).

Use the simplest path: install backend requirements locally and run `pytest` natively against an ephemeral testcontainer. `backend/tests/conftest.py` spins up its own `PostgresContainer("postgres:17-alpine")` per session via testcontainers — it needs only a reachable Docker daemon (the operator's Docker is fine; testcontainers names its own throwaway container, no collision with the dev stack).

```bash
# from your worktree root
python -m venv .venv-agent && . .venv-agent/bin/activate
pip install -r backend/requirements.txt
cd backend && python -m pytest tests/test_prune_magic_links.py -v
```

pytest config lives in `backend/pyproject.toml` (`pythonpath = ["."]`, `testpaths = ["tests"]`), so run pytest **from the `backend/` directory**. With `pythonpath=["."]` both `app.*` and `scripts.*` (there is a `backend/scripts/__init__.py`) are importable in tests. Do NOT commit `.venv-agent/` — it is outside the repo's tracked tree, but `git status` it before opening the PR to be sure.

Lint: `cd backend && ruff check scripts/prune_magic_links.py tests/test_prune_magic_links.py` and `ruff format`. ruff config is in `backend/pyproject.toml` (line-length 100; rules E, F, I, UP). Note: ruff is unpinned in this repo — run `ruff --version` and if your local ruff diverges, prefer fixing real findings over churn.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

The `magic_links` table has no pruning mechanism. Add a periodic-cleanup script that deletes long-expired magic-link rows, mirroring the project's standard standalone-maintenance-script pattern.

**Model (verified `backend/app/models/magic_link.py`):**
- `MagicLink.__tablename__ = "magic_links"`.
- `expires_at: Mapped[datetime]` (line 42, `nullable=False`) — naive UTC datetimes (the codebase writes `datetime.utcnow()` everywhere; see `backend/app/api/orders.py:52`, `backend/app/api/dependencies.py:55`).
- `used_at: Mapped[datetime | None]` (line 43).
- `order_id` / `booking_id` are **nullable FKs with no cascade** (lines 36-37); nothing references `magic_links` as a parent, so deleting rows is safe with zero cascade effects.

**The exact change — create `backend/scripts/prune_magic_links.py`:**

Mirror the canonical script `backend/scripts/cleanup_tags.py` (read it — it is the in-repo exemplar for this exact shape):
- Module docstring with a `Usage:` block (use the `python -m scripts.prune_magic_links` invocation form, like cleanup_tags.py line 9-11).
- `from app.core.database import SessionLocal` and `from app.models.magic_link import MagicLink`.
- A **pure, testable function** — `def prune_magic_links(db: Session, *, grace_days: int = 30, dry_run: bool = False) -> int:` — that:
  - Computes the cutoff as a **naive UTC** datetime: `cutoff = datetime.utcnow() - timedelta(days=grace_days)` (must be naive to compare against the naive `expires_at` column — do NOT use `datetime.now(UTC)` aware datetimes here; the column is naive).
  - Deletes exactly the rows where `MagicLink.expires_at < cutoff`. Use `db.query(MagicLink).filter(MagicLink.expires_at < cutoff)`; count first, then `.delete(synchronize_session=False)`.
  - On `dry_run=True`: count the matching rows, log the count, do NOT delete (and do NOT commit — `db.rollback()` or simply don't commit, matching cleanup_tags.py's dry-run branch).
  - On `dry_run=False`: delete, `db.commit()`, return the deleted count.
  - Logs the deleted (or would-delete) count via the `logging` module (cleanup_tags.py lines 24-29 show the logging setup to copy).
- A `main()` with `argparse` exposing `--dry-run` (store_true) and `--grace-days` (int, default 30), creating a session via `SessionLocal()`, calling the function, and `finally: db.close()` (cleanup_tags.py lines 57-62, 181-182).
- `if __name__ == "__main__": main()`.

**The DELETE predicate is the load-bearing spec.** It is EXACTLY: `expires_at < (now - grace_days)`, default grace 30 days. This is the issue's settled desired-state (`expires_at < now() - INTERVAL '30 days'`). Do NOT also filter on `used_at` — `ADMIN_ACCESS` links are reusable (not single-use; see `backend/tests/test_auth.py:97-104` "used admin action still valid"), so `used_at` is not a safe "done" signal. Expiry-plus-grace is the single safe criterion. Do NOT widen this predicate under any circumstance — `magic_links` backs live admin sessions; over-deletion is an auth-availability bug.

**Create `backend/tests/test_prune_magic_links.py`:**

Mirror the test idioms in `backend/tests/test_auth.py` (the `_make_link` helper at lines 41-52 shows how to construct a `MagicLink` in tests — `token`, `action=MagicLinkAction.ADMIN_ACCESS.value`, `expires_at`). Import the function under test: `from scripts.prune_magic_links import prune_magic_links`. Use the existing `test_db` fixture (session-scoped testcontainer, function-scoped session — `conftest.py:49-80`). Cover at minimum:
1. A row with `expires_at` older than the grace window IS deleted (returns count 1; row gone).
2. A row expired but WITHIN the grace window (e.g. `expires_at = utcnow() - timedelta(days=1)`) is NOT deleted.
3. A still-valid future-expiry row is NOT deleted.
4. `dry_run=True` returns the count but deletes nothing (re-query confirms rows still present).
5. A `used_at`-set but not-yet-past-grace row is NOT deleted (proves the predicate keys on expiry+grace, not on `used_at`).

Use `datetime.utcnow()` for all test timestamps (naive), matching the column and the conftest `admin_token` fixture (`conftest.py:119`). Each `MagicLink` needs a unique `token` (UNIQUE constraint, `String(64)`).

## Scope

### IN scope
- NEW `backend/scripts/prune_magic_links.py`
- NEW `backend/tests/test_prune_magic_links.py`

### OUT of scope (do NOT touch)
- `backend/app/models/magic_link.py` — no schema change, no migration. The fix is application-layer only.
- `backend/app/api/auth.py`, `backend/app/api/orders.py`, `backend/app/api/dependencies.py` — the magic-link issuance/validation paths. Do not modify token logic.
- `backend/tests/conftest.py` and any other existing test file — reuse fixtures, do not edit them.
- No Alembic migration. No `docker-compose` / `docker/` changes. No cron wiring on the server (the issue asks for the script; actually scheduling it on the droplet is an operator deploy step, NOT your job — do not edit `scripts/research-cron.sh` or add a cron file).
- Do NOT add an API endpoint. The issue specifies a script/scheduled job, and the canonical pattern is a standalone script.

## Default rules for likely ambiguities

- **Filename / module name:** `backend/scripts/prune_magic_links.py` (snake_case, matches sibling `cleanup_tags.py`). Function name `prune_magic_links`.
- **Grace window:** default `30` days, exposed as `--grace-days`. Hard-code the default to 30 (matches the issue's `INTERVAL '30 days'`).
- **Naive vs aware datetimes:** use `datetime.utcnow()` (naive UTC). The `expires_at` column is naive; mixing in an aware datetime would raise `TypeError` on comparison in Postgres-via-SQLAlchemy. This is the single most likely bug — get it right.
- **Bulk delete:** use `.delete(synchronize_session=False)` on the filtered query (no ORM objects need to stay in sync; this is a one-shot script). Count with a separate `.count()` before deleting so you can log/return the number.
- **`used_at`:** ignore it in the predicate. (Reason in "The task" above.)
- **Logging:** copy the `logging.basicConfig(...)` + `logger = logging.getLogger(__name__)` block from `cleanup_tags.py:24-29`.
- **Dry-run default:** `--dry-run` is opt-in (store_true, default False) — same as `cleanup_tags.py:59`. (Note: `cleanup_articles_39_40.py` defaults to dry-run; do NOT follow that one here — follow `cleanup_tags.py`, the closer match for a low-risk recurring prune.)
- **Return value:** the function returns the int count (deleted, or would-be-deleted in dry-run) so the test can assert on it.
- **`Session` type import:** `from sqlalchemy.orm import Session` for the type hint.
- **`from __future__ import annotations`:** optional; cleanup_tags.py does not use it — omit for consistency with the canonical pattern.

## Failure-mode escape hatch

If the primary path is blocked — e.g. `scripts.prune_magic_links` is not importable in the test despite `pythonpath=["."]`, or testcontainers cannot reach Docker — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Do not silently work around it. There is no required-but-missing field here (model verified), so a structural block is unlikely; if you hit one, document it precisely.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only the two new in-scope files are added; no existing file modified (`git status` / `git diff --stat` confirm).
- [ ] The DELETE predicate is exactly `expires_at < (utcnow() - grace_days)`; it does NOT reference `used_at` and is not widened.
- [ ] `cutoff` is a naive UTC datetime (`datetime.utcnow() - timedelta(...)`).
- [ ] All 5 test cases present and the test file imports `prune_magic_links` from `scripts.prune_magic_links`.
- [ ] `cd backend && python -m pytest tests/test_prune_magic_links.py -v` passes (all green).
- [ ] `cd backend && ruff check scripts/prune_magic_links.py tests/test_prune_magic_links.py` is clean (no new issues vs main baseline) and `ruff format` applied.
- [ ] PR description includes the `Production touch: no — verified by:` line.
- [ ] No migration, no docker/compose change, no API endpoint, no server-cron wiring added.

## PR shape

- **Branch**: `fix/issue-65-prune-magic-links`
- **Title**: `fix(#65): prune long-expired magic_link rows`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (verified by: new application-layer script + testcontainer test; no prod DB / schema / deploy touch); the self-review checklist with each item marked; a test plan (the pytest invocation above); `Closes #65`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the canonical script `backend/scripts/cleanup_tags.py` and the model `backend/app/models/magic_link.py`; confirm the verified facts (predicate columns, naive datetimes, `SessionLocal` import path).
2. Read the issue (`gh issue view 65`) and `backend/tests/test_auth.py` lines 41-104 for the `_make_link` / used-vs-expired test idioms.
3. Set up the local venv + testcontainer pytest path (Operational notes); confirm `import scripts.prune_magic_links` will resolve.
4. Write the script, then the test, staying strictly within IN scope.
5. Run pytest and ruff; iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
