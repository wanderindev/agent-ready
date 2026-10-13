# Fix brief — issue #198: /api/v1/categories/taxonomies is unreachable due to route declaration order

## Identification

You are an autonomous agent resolving issue #198 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend, test-only-runtime issue. The only thing you need to run is `pytest`, which spins up a PostgreSQL **testcontainer** (see `backend/tests/conftest.py:16-19`, `postgres:17-alpine`). You do NOT need the live docker-compose stack and you must NOT use it — the operator's main checkout often has the dev stack running on ports 5432/8000, and a naïve `docker-compose up` from your worktree would collide or attach to their containers.

Run tests natively against the testcontainer:
- From the worktree, install backend deps into a fresh venv: `python -m venv .venv && . .venv/bin/activate && pip install -r backend/requirements.txt`
- The test process needs a reachable Docker socket for testcontainers — it is available in this environment.
- Run: `cd backend && python -m pytest tests/test_categories.py -v`
- Also run the full suite once before opening the PR: `cd backend && python -m pytest -q` (route-order changes can affect other routing tests; confirm nothing else broke).

Lint: `ruff check backend/app/api/categories.py backend/tests/test_categories.py` and `ruff format --check` on the same files. Note: ruff is unpinned in this repo (`ruff>=0.1.9`) and CI uses latest — if your local ruff version differs, prefer not introducing any new findings over reformatting unrelated lines.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

**The bug.** In `backend/app/api/categories.py`, FastAPI matches routes in declaration order. The catch-all parameterized route `@router.get("/{category_slug}")` is declared at **line 85**, BEFORE the literal route `@router.get("/taxonomies", ...)` at **line 120**. So every request to `/api/v1/categories/taxonomies` is captured by `get_category_by_slug`, which searches categories for one whose `generate_slug(c.name) == "taxonomies"` (line 96), finds none, and raises 404 (lines 98-99). The `list_taxonomies` handler (lines 120-134) is unreachable. The handler itself is correct.

Current `@router.get` declaration order (verified in `main` via `git show`):
- line 17:  `@router.get("")`               — list_categories
- line 55:  `@router.get("/with-content")`   — list_categories_with_content  (correctly placed static route — mirror this)
- line 85:  `@router.get("/{category_slug}")` — get_category_by_slug          (the catch-all)
- line 120: `@router.get("/taxonomies")`     — list_taxonomies               (unreachable)

**The fix.** Move the entire `list_taxonomies` route block (the `@router.get("/taxonomies", response_model=list[TaxonomyBase])` decorator plus its function, currently lines 120-134) so it is declared BEFORE the `@router.get("/{category_slug}")` block at line 85. The natural placement is immediately after `list_categories_with_content` (after line 82) and before `get_category_by_slug` (line 85), joining the static routes ahead of the catch-all. Do NOT change any function body, signature, decorator args, or the `EXCLUDED_TAXONOMY_ID = 5` constant. This is FastAPI's standard idiom for mixing literal and parameterized paths on one prefix.

**CRITICAL — drift correction vs the issue body.** The issue body says the characterization test was added "in PR for #194" and treats updating it as a loose follow-up. That is stale: **#194 is already merged (PR #202) and the test is present in current `main`** at `backend/tests/test_categories.py:146`, in class `TestListTaxonomies` (line 143). The test `test_taxonomies_endpoint_unreachable_due_to_routing` asserts `status_code == 404` on purpose to characterize the bug. Once you reorder the routes, that assertion becomes FALSE and the test will fail. You MUST rewrite it in the same PR — this is in-scope, not a follow-up.

Replace the body of `test_taxonomies_endpoint_unreachable_due_to_routing` (lines 146-161) with a passing test that verifies the now-reachable endpoint. Rename the method to something like `test_taxonomies_endpoint_returns_taxonomies`. Use the verified fixtures and schema:
- `taxonomy_factory(name=..., description=...)` exists at `conftest.py:104-116` (returns a persisted `Taxonomy` with `.id`).
- Response schema `TaxonomyBase` (verified at `backend/app/schemas/category.py:6-11`) serializes exactly `{id, name, description}`.
- The handler excludes taxonomy `id == 5` (Notable Figures), per `categories.py:125`.

The replacement test should assert: (a) `GET /api/v1/categories/taxonomies` returns `200`; (b) the JSON is a list whose entries have `id`, `name`, `description`; (c) a seeded taxonomy appears. Add (or extend) a second test that seeds a `Taxonomy(id=5, ...)` and a normal taxonomy and asserts the id=5 one is excluded from the response — mirror the existing exclusion-test pattern at `test_categories.py:49-60` (which constructs `Taxonomy(id=5, ...)` directly via `test_db`). To seed an explicit id you must use `test_db.add(Taxonomy(id=5, ...))` + `commit()` directly (the factory does not accept an id), then `taxonomy_factory(name="Historical Panama")` for a normal one; assert the response contains the normal one and not id=5.

Also update the **misleading module docstring** at `backend/tests/test_categories.py:8-18` (the "shape-#4 finding" / "fix is OUT of scope" note) — once fixed it is no longer accurate. Replace it with the simple endpoint list (keep lines 3-6) and drop the obsolete NOTE paragraph. Keep the `from app.models.category import Category, Taxonomy` import (line 21) — `Taxonomy` is still needed for the id=5 seeding test.

## Scope

### IN scope
- `backend/app/api/categories.py` — reorder only: move the `/taxonomies` route block to before the `/{category_slug}` block. No logic changes.
- `backend/tests/test_categories.py` — rewrite the characterization test in `TestListTaxonomies` to assert the fixed (200 + exclusion) behavior; remove the obsolete NOTE docstring paragraph.

### OUT of scope (do NOT touch)
- Any handler logic, query, or the `EXCLUDED_TAXONOMY_ID` constant in `categories.py`.
- The other three routes' bodies (`list_categories`, `list_categories_with_content`, `get_category_by_slug`) — do not modify them; only `get_category_by_slug` moves relative to `/taxonomies`, and only because `/taxonomies` moves above it.
- `backend/app/schemas/category.py`, `conftest.py`, any other test file, the frontend (no callers exist), migrations, docker-compose files.
- Do not "improve" unrelated tests in `test_categories.py` (the `TestListCategories`, `TestListCategoriesWithContent`, `TestGetCategoryBySlug` classes are correct as-is).

## Default rules for likely ambiguities

- **Placement of the moved block:** put `list_taxonomies` immediately after `list_categories_with_content` and before `get_category_by_slug`. Keep two blank lines between top-level route functions (match existing spacing).
- **Test method name:** rename `test_taxonomies_endpoint_unreachable_due_to_routing` → `test_taxonomies_endpoint_returns_taxonomies`. Do not leave the old name (it now lies).
- **Seeding a taxonomy with id=5:** the `taxonomy_factory` does NOT accept an `id` arg (verified signature: `create(name=..., description=...)`). Construct it directly via `test_db.add(Taxonomy(id=5, name="Notable Figures", description="..."))` then `test_db.commit()`, exactly as `test_list_excludes_taxonomy_5` does at line 51-53.
- **Response field assertions:** `TaxonomyBase` emits exactly `id`, `name`, `description` (no `taxonomy_id`, no `article_count`). Assert against those three only.
- **Do not add a slug-still-works test** unless trivial — the existing `test_get_by_slug_found` (line 110) already proves the slug route works; reordering does not break it because real category slugs never equal `"taxonomies"`. You may optionally add an assertion in your new test that the slug route is unaffected, but it is not required.
- If the line numbers above are off by a few (the file may have shifted), locate by the decorator/function names, not the numbers.

## Failure-mode escape hatch

If the primary path is blocked — e.g., the testcontainer cannot start, or the route reorder somehow breaks an unrelated route test you cannot reconcile — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Do not silently work around it.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/api/categories.py` and `backend/tests/test_categories.py` are modified (`git status` confirms).
- [ ] In `categories.py`, the `/taxonomies` route decorator now appears at a lower line number than the `/{category_slug}` decorator; no handler body changed (diff is a pure move + nothing else).
- [ ] The old `test_taxonomies_endpoint_unreachable_due_to_routing` (asserting 404) is gone; a replacement asserts 200 + correct shape + id=5 exclusion and PASSES.
- [ ] The obsolete NOTE docstring paragraph (old lines 8-18) is removed/corrected.
- [ ] `cd backend && python -m pytest tests/test_categories.py -v` passes; full `python -m pytest -q` passes (no new failures vs main).
- [ ] `ruff check` on the two files reports no NEW issues vs the main baseline.
- [ ] PR description includes the "Production touch: no" line.

## PR shape

- **Branch**: `fix/issue-198-categories-taxonomies-route-order`
- **Title**: `fix(#198): declare /taxonomies route before /{category_slug} catch-all`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: route-handler reorder in a public read endpoint; no schema/DB/auth/payment/PII change"** line; the self-review checklist with each item marked; a test plan (reorder + rewritten characterization test now asserts 200 and id=5 exclusion); `Closes #198`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- Note in the PR body the drift you corrected: the #194 characterization test was already merged to main (PR #202), so it was rewritten in this PR rather than left as a follow-up.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 198`) and open `backend/app/api/categories.py`, `backend/tests/test_categories.py`, `backend/tests/conftest.py`, and `backend/app/schemas/category.py`; confirm the verified facts still hold (especially that `test_taxonomies_endpoint_unreachable_due_to_routing` is present and asserts 404).
2. Move the `/taxonomies` route block above `/{category_slug}` in `categories.py`.
3. Rewrite the `TestListTaxonomies` test(s) and fix the module docstring in `test_categories.py`.
4. Install deps and run `pytest` against the testcontainer; iterate until green; run the full suite once.
5. Run the self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
