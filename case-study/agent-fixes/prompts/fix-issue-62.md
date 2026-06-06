# Fix brief — issue #62: [Quality] Educator service uses non-constant-time '==' for verify_code comparison

## Identification

You are an autonomous agent resolving issue #62 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a one-line backend change plus one import. It needs no live API access and no docker-compose stack — the only verification is the existing pytest suite for the educator service, which runs against a PostgreSQL testcontainer.

Run tests the simplest way: install backend requirements locally and run pytest natively against the testcontainer (it spins up its own Postgres via the conftest fixture; Docker daemon must be reachable, which it is in this environment). From the worktree root:

- `pip install -r backend/requirements.txt` (if not already available)
- `cd backend && python -m pytest tests/test_educator_service.py -q`

If native pytest is not workable in your worktree, fall back to the Docker path from CLAUDE.md, but use a dedicated compose project name to avoid colliding with the operator's running dev stack: `docker-compose -p agent-issue-62 exec backend pytest tests/test_educator_service.py`. The native path is preferred for this change.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Replace the non-constant-time `!=` comparison of the educator's verify code with `hmac.compare_digest`.

**Location (CORRECTED — the issue body says line 336; that is now the function docstring).** The actual comparison is at **`backend/app/services/educator_service.py:361`**, inside the `verify_code(...)` function:

```python
    if not educator.verify_code or educator.verify_code != code:
```

Change it to:

```python
    if not educator.verify_code or not hmac.compare_digest(educator.verify_code, code):
```

Add `import hmac` to the import block at the top of the file. **`hmac` is NOT currently imported** — verified. Insert it alphabetically among the existing stdlib imports (current order: `base64`, `logging`, `secrets`, `uuid` on lines 8–11). Place `import hmac` between `import base64` and `import logging`.

The existing `not educator.verify_code` guard is retained and short-circuits first, so `hmac.compare_digest` is only reached when `educator.verify_code` is a non-empty `str`. `code` is typed `str` (function signature `def verify_code(db, email, code: str, ...)`). Thus `compare_digest` never receives `None` on either argument. Do not alter the guard.

No drift other than the line number. The code snippet in the issue matches source exactly.

## Scope

### IN scope
- `backend/app/services/educator_service.py` — add `import hmac`; change the one comparison at line 361.

### OUT of scope (do NOT touch)
- The `confirm_token` lookup at line 298 (`select(Educator).where(Educator.confirm_token == token)`) — this is a SQL `WHERE` clause evaluated DB-side, not a Python-level string comparison, so it is not an application-layer timing leak. Leave it.
- `access_token` — it is only generated (`_generate_access_token`), never compared in this file. Leave it.
- Rate-limiting / brute-force keyspace concerns — tracked separately in issue #53. Do NOT add rate limiting.
- Any test files. The existing tests at `backend/tests/test_educator_service.py:389` (`test_wrong_code_rejected`) and `:419` (`test_valid_code_extends_access_and_clears_code`) already cover both the rejected-wrong-code and accepted-valid-code paths and must continue to pass. Do NOT add new tests unless one of these regresses (it should not — `compare_digest` returns the same boolean as `==` for the equal-length 6-digit codes used here).

## Default rules for likely ambiguities

- **Import placement:** `import hmac` goes between `import base64` (line 8) and `import logging` (line 9). Stdlib group, alphabetical.
- **Argument order to `compare_digest`:** `hmac.compare_digest(educator.verify_code, code)` — order is irrelevant to correctness; match this for consistency.
- **Don't refactor the surrounding `if` block, logging, or Sentry breadcrumb.** Only the boolean comparison expression changes.
- **`ruff`:** the project lint is `ruff check`. `import hmac` is used, so no unused-import warning. Run `ruff check backend/app/services/educator_service.py` and confirm clean.

## Failure-mode escape hatch

If the change is structurally blocked (e.g., `code` turns out to be non-`str` at runtime in a way that breaks `compare_digest`, or an existing test fails for a reason you cannot resolve in-scope), STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X" comment is a good outcome.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/services/educator_service.py` modified.
- [ ] `import hmac` added; comparison at (now-)line ~361 uses `not hmac.compare_digest(...)`.
- [ ] The `not educator.verify_code` None/empty guard is still present and still short-circuits first.
- [ ] `ruff check backend/app/services/educator_service.py` clean (no new issues vs main).
- [ ] `python -m pytest tests/test_educator_service.py -q` passes (especially `test_wrong_code_rejected` and `test_valid_code_extends_access_and_clears_code`).
- [ ] PR description complete, including the production-touch line.

## PR shape

- **Branch**: `fix/issue-62-verify-code-constant-time`
- **Title**: `fix(#62): constant-time verify_code comparison via hmac.compare_digest`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: service-layer comparison change only, no DB/schema/env/deploy change; behavior identical for valid/invalid inputs"** line; the self-review checklist with each item marked; a test plan (the two named existing tests); `Closes #62`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 62`) and `backend/app/services/educator_service.py`; confirm the comparison is at ~line 361 and `hmac` is not yet imported.
2. Add `import hmac` and change the comparison.
3. Run `ruff check` and `pytest tests/test_educator_service.py`; iterate until clean.
4. Self-review checklist.
5. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
6. Append the outcomes-log row.
7. Report back and STOP.
