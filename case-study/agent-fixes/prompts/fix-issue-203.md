# Fix brief — issue #203: [Bug] /api/v1/search 500s on every request — invalid func.case() in SQLAlchemy 2.0

## Identification

You are an autonomous agent resolving issue #203 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend Python fix verifiable entirely by pytest against a testcontainer — NO live API and NO docker-compose needed. The test suite (`backend/tests/conftest.py`) spins up its own `PostgresContainer("postgres:17-alpine")` via `testcontainers`, so the simplest path is native pytest:

- From the repo root in your worktree, install backend deps into a venv and run pytest directly. Requirements live in `backend/`. Example:
  - `python -m venv .venv && . .venv/bin/activate`
  - `pip install -r backend/requirements.txt` (and `backend/requirements-dev.txt` if present)
  - Run from inside `backend/` so imports resolve: `cd backend && python -m pytest tests/test_search.py -v`
- testcontainers requires a reachable Docker daemon; the host has Docker. If the testcontainer cannot start in your environment, fall back to the docker-compose path with a dedicated project name (`-p agent-issue-203`) and a temp `docker-compose.agent.yml` override (alternate host ports for 5432/8000, `user: "0:0"` on backend) referenced via `-f docker-compose.yml -f docker-compose.agent.yml`; `rm` the override before opening the PR so it is not committed. Prefer native pytest — only escalate to compose if the testcontainer is unreachable.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

`GET /api/v1/search` raises a 500 on every request that reaches the ORM query because `backend/app/api/search.py:45` uses `func.case(...)`, which SQLAlchemy 2.0 misinterprets as a generic SQL function that does not accept the `else_` keyword. `case` is a top-level construct that must be imported from `sqlalchemy`.

Two changes, both verified against current source:

1. **`backend/app/api/search.py` line 2** — currently exactly:
   ```python
   from sqlalchemy import func, or_
   ```
   Change to (add `case`, keep alphabetical/existing order — `case` before `func`):
   ```python
   from sqlalchemy import case, func, or_
   ```

2. **`backend/app/api/search.py` line 45** — currently exactly:
   ```python
               func.case((Article.title.ilike(search_term), 1), else_=2),
   ```
   Change to (drop the `func.` prefix only — keep identical args and indentation):
   ```python
               case((Article.title.ilike(search_term), 1), else_=2),
   ```

   `func` is still used elsewhere? Verify: as of brief-writing, `func` is NOT referenced anywhere else in `search.py` after this change. Confirm with `grep -n "func" backend/app/api/search.py` after editing — if `func.case` was its only use, the import would have an unused `func`. **Resolution: keep `func` in the import only if it is still referenced; if line 45 was its sole use, remove `func` from the import to keep ruff clean** (final form would then be `from sqlalchemy import case, or_`). Let `ruff check` be the arbiter — see default rules.

3. **`backend/tests/test_search.py`** — remove the `@pytest.mark.xfail(reason=_BROKEN_SEARCH_REASON, strict=True)` decorator line from each of these 8 test methods (they currently carry `strict=True` xfail, which becomes XPASS → suite failure once the bug is fixed, so they MUST be unmarked):
   - `TestSearchArticles.test_search_empty_db_returns_empty_list` (line 31 decorator)
   - `TestSearchArticles.test_search_matches_title` (line 48)
   - `TestSearchArticles.test_search_matches_content` (line 63)
   - `TestSearchArticles.test_search_matches_excerpt` (line 74)
   - `TestSearchArticles.test_search_excludes_non_approved` (line 89)
   - `TestSearchArticles.test_search_excludes_taxonomy_5` (line 102)
   - `TestSearchArticles.test_search_title_match_ranked_first` (line 121)
   - `TestSearchArticles.test_search_respects_limit` (line 146)

   These are all 8 `xfail` occurrences in the file (verified: `grep -n xfail` returns exactly 8 decorator lines plus 2 references inside the module docstring, which you leave alone). The 3 `*_returns_422` tests are NOT xfail-marked — do not touch them.

No issue-body-vs-source drift: every line number and string in the issue body matches current source exactly.

## Scope

### IN scope
- `backend/app/api/search.py` — the 2 edits (import line 2, order_by line 45; plus dropping `func` from import if it becomes unused).
- `backend/tests/test_search.py` — remove the 8 `xfail` decorators listed above.

### OUT of scope (do NOT touch)
- The module docstring in `backend/tests/test_search.py` (lines 3–20) and the `_BROKEN_SEARCH_REASON` constant — leave both as-is even though they describe the now-fixed bug; rewording test documentation is not in this issue's intent.
- The 3 `test_search_*_returns_422` tests — they are not xfail-marked and exercise FastAPI validation; do not modify.
- `_extract_highlight`, the filters, joins, and response shape in `search.py` — the issue confirms these are correct.
- `backend/tests/conftest.py` and any factories.
- Any other endpoint, model, or schema file.

## Default rules for likely ambiguities

- **Unused `func` import:** After editing line 45, run `grep -n "func\b" backend/app/api/search.py`. If `func` no longer appears anywhere in the file, remove it from the import so the final line 2 is `from sqlalchemy import case, or_`. If `func` is still used, keep it: `from sqlalchemy import case, func, or_`. Defer to `ruff check` — it will flag an unused import; resolve to a clean lint.
- **Import ordering:** ruff/isort orders the names alphabetically within the import (`case, func, or_`). Run `ruff check --fix` / `ruff format` on the touched files to match the repo's enforced style.
- **Removing the decorator:** delete the entire `@pytest.mark.xfail(...)` line above each named method; do not change the method body, signature, or its docstring.
- **`pytest` import:** `import pytest` (line 22) is still needed elsewhere? After removing all 8 decorators, `pytest` is no longer referenced in the file. Let ruff decide: if it flags `pytest` as unused, remove the `import pytest` line. (The `_returns_422` tests do not use `pytest`.) Verify with `grep -n "pytest" backend/tests/test_search.py` after editing.
- **Lint baseline:** run `ruff check` on the two touched files; the diff must introduce zero new ruff findings versus `main`. Note (from project memory) ruff is unpinned — match whatever version is installed.

## Failure-mode escape hatch

If the testcontainer cannot start (no Docker daemon reachable) AND the compose fallback also fails, STOP and open the PR as a **draft** with a comment stating the code change is made but tests could not be executed locally, and that CI must validate. The code change itself is unambiguous and low-risk; a draft PR with an honest "tests not run locally because X" note is acceptable. Do not fabricate test results.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/api/search.py` and `backend/tests/test_search.py` are modified.
- [ ] `search.py` line 45 uses bare `case(...)`, not `func.case(...)`.
- [ ] `case` is imported from `sqlalchemy`; `func` retained only if still used.
- [ ] All 8 listed test methods have their `@pytest.mark.xfail` decorator removed; the 3 `*_returns_422` tests are untouched; the docstring and `_BROKEN_SEARCH_REASON` are untouched.
- [ ] `cd backend && python -m pytest tests/test_search.py -v` → all 11 tests PASS, zero XPASS, zero xfail (or draft-with-explanation if Docker unreachable).
- [ ] `ruff check` on both touched files is clean (no new findings vs main).
- [ ] PR description complete, including the production-touch line.

## PR shape

- **Branch**: `fix/issue-203-search-func-case`
- **Title**: `fix(#203): correct func.case() to top-level case() in search endpoint`
- **Body must include**: a one-line summary; a **"Production touch: yes — verified by: 8 un-xfailed contract tests in test_search.py now pass against the testcontainer; change is a 2-line ORM correction, no schema/auth/payment/PII"** line; the self-review checklist with each item marked; a test plan (the pytest command above + expected all-pass); `Closes #203`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. (No node_modules symlink needed — backend issue.)
2. Read the issue (`gh issue view 203`) and open `backend/app/api/search.py` + `backend/tests/test_search.py`; confirm the verified facts still hold (import line 2, order_by line 45, 8 xfail decorators).
3. Make the change, staying strictly within IN scope.
4. Set up the test env (native venv + pytest against testcontainer) and run `cd backend && python -m pytest tests/test_search.py -v`; iterate until clean; run `ruff check` on the touched files.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed or tests could not run; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
