# Fix brief — issue #192: [Quality] Test coverage for admin dashboard endpoints (dashboard.py)

## Identification

You are an autonomous agent resolving issue #192 in the Panama In Context (PIC) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

Backend tests run inside Docker. From the repo root (where `docker-compose.yml` lives):

```bash
docker-compose up -d backend db
docker-compose exec backend pytest backend/tests/test_dashboard.py -x        # iterate
docker-compose exec backend pytest backend/tests/test_dashboard.py -v        # final run
docker-compose exec backend pytest                                            # whole suite (verify no regressions)
docker-compose exec backend ruff check /app                                   # must be clean
docker-compose exec backend ruff format /app                                  # apply formatting
```

The test container is `postgres:17-alpine` started by `testcontainers` via the `postgres_container`/`test_engine`/`test_db` session fixtures in `backend/tests/conftest.py`. You do NOT need to manage migrations — `Base.metadata.create_all` runs against the container.

DO NOT run pytest with `--cov` arguments unless reproducing the issue's claim; the CI workflow (PR #196) handles coverage reporting.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

### What exists today

- `backend/app/api/dashboard.py` is **1697 lines** with **40 `@router.*` decorators** — the single biggest coverage gap by line count (issue cites 27% / 430 uncovered lines from the pre-#196 baseline; file size has grown since).
- All endpoints are gated by `validate_admin_token(token, db)` (defined in `backend/app/api/dependencies.py:19-44`) — the gate itself is already well-tested via the `admin_token` fixture pattern used across the suite.
- The Pydantic schemas live in `backend/app/schemas/dashboard.py` and are 100% covered — they define the request/response oracle for every endpoint.
- **Existing coverage** (do NOT duplicate; do NOT modify these files):
  - `tests/test_article_generation.py` covers 3 endpoints: `POST /articles/generate-outlines`, `POST /articles/{id}/write`, `POST /articles/{id}/generate-tags`.
  - `tests/test_series_sections.py:215-243` covers `POST /articles/{id}/series-sections`.

### What this PR adds

Create **`backend/tests/test_dashboard.py`** (a single new file; you may split into 2-4 files grouped by entity if it gets unwieldy — `test_dashboard_suggestions.py`, `test_dashboard_research.py`, `test_dashboard_articles.py`, `test_dashboard_settings.py` is acceptable). Use the `admin_token` fixture (canonical, real-MagicLink path) — NOT the `_FAKE_ADMIN` patch pattern.

### The oracle: per-endpoint expected behavior

Per the agent-friendly oracle rule (`docs/pilot/agent-friendly-criteria.md` — "Test-writing tasks: the oracle rule"): each test's assertion must be derived from the **schema contract + endpoint docstring**, not from re-reading the implementation. The schemas define what correct output looks like; the docstrings define the precondition for each error branch.

Enumerate tests against each endpoint below. Group by entity. For each endpoint cover:
- **Happy path**: 200 with a response matching the `response_model`.
- **404 branch**: when an `if X is None: raise 404` line exists.
- **400 branch(es)**: every distinct `raise HTTPException(status_code=400, ...)` precondition listed in the source (you may read source for the *list* of preconditions — that's not circular; the oracle is "this precondition fails → 400 with this detail substring").
- **401 / 422**: at least once per file, confirm missing token → 401/422 and invalid token → 401 (mirror `test_media_library.py:519-529`). You do NOT need to repeat this for every endpoint — once per resource group is enough.

#### Endpoints to cover (35; verified by counting `@router.*` lines)

**Stats (1)** — `dashboard.py:86`:
- `GET /stats` → 200, returns `DashboardStats` with 5 `StatusCounts` sub-objects. Test with empty DB → all totals 0. Optionally seed one of each entity → totals reflect.

**Suggestions (6)** — `dashboard.py:135, 201, 367, 393, 436, 472`:
- `GET /suggestions` → 200, list of `SuggestionListItem`. Empty DB → []. Seeded suggestion → one item with `has_research=False`, `articles_status="NONE"`.
- `GET /suggestions/available-for-research` → 200; only suggestions with `status="APPROVED"` and no `Research` row appear.
- `GET /suggestions/available-for-generation` → 200; only "Historical Panama" taxonomy categories that have NO suggestions appear. Use `taxonomy_factory(name="Historical Panama")` and `category_factory(taxonomy=...)`.
- `POST /suggestions/generate` → mock `app.services.suggestion_generation.generate_historical_suggestions` to return a list; assert 200 + `suggestions_created` matches. Test: `num_suggestions=0` → 400 ("between 1 and 20"); `category_id` not found → 404; non-Historical-Panama taxonomy → 400.
- `GET /suggestions/{id}` → 200 happy, 404 missing.
- `PUT /suggestions/{id}` → 200 update, 404 missing. Verify DB-side: re-query and the fields changed.

**Research (8)** — `dashboard.py:241, 282, 517, 571, 618, 645, 677, 709, 746`:
- `POST /research/generate-prompt` → mock `app.services.research.generate_research_prompt` to return `"prompt text"`; happy 200. Branches: suggestion 404, non-APPROVED suggestion 400, existing Research record 400.
- `POST /research/upload` → mock `app.services.research.extract_suggestion_title` and `validate_research_document` (return `{"valid": True, "checks": [], "word_count": 5000, "content": "..."}`). Use `TestClient`'s `files=` kwarg to upload bytes. Happy 200 → creates new Research and a second upload for same suggestion → updates existing. Branches: no title extractable → 400; no matching suggestion → 400; validation fails → 400 with `detail.message`.
- `GET /research` → 200, list of `ResearchListItem`. Empty + seeded variants.
- `GET /research/available-for-outlines` → 200; only one record returned even if multiple APPROVED research exist (it's "next-only" behavior — verify this with 2 APPROVED research records).
- `GET /research/{id}` → 200 happy (returns HTML), 404 missing.
- `PUT /research/{id}` → 200 update (send `content_html`), 404 missing. Verify DB-side: `research.content` now contains the markdown-converted text.
- `GET /research/{id}/download` → 200 with `Content-Disposition: attachment; filename="..._research.md"` header and markdown body. 404 missing.
- `POST /research/{id}/generate-summary` → mock `app.services.research_summary.generate_research_summary` to return `"summary text"`. Happy 200. Branches: 404 missing; non-APPROVED 400; empty-content 400; service raises → 502.
- `GET /research/{id}/download-summary` → 200 with Content-Disposition header. 404 missing; 404 no-summary.

**Articles (15)** — already-covered endpoints listed in "What exists today" above; the remaining endpoints to cover are at `dashboard.py:931, 1027, 1071, 1096, 1197, 1243, 1265, 1295, 1342, 1390, 1419, 1504`:
- `GET /articles` → 200, list of `ArticleListItem`. Verify `has_content`, `has_outline`, `has_spanish`, `has_tags`, `has_feature_image`, `is_series` are computed correctly for a seeded article.
- `GET /articles/available-for-writing` → 200; only articles with `outline_status="APPROVED"` and empty `content`. Set up two articles, only one matches.
- `PATCH /articles/{id}/outline-status` → 200, 404 missing, 400 if no outline.
- `POST /articles/{id}/translate` — IMPORTANT: mock `app.services.translation.get_translation_service`. The function returns `None` if `DEEPL_API_KEY` is unset → that's the 500 branch. Branches: 404 missing; 400 no content; 400 already-has-Spanish; 500 service unavailable; 200 happy (mock service has `translate_text` and `translate_markdown` returning the string with " ES" appended). The endpoint is `async def`; use `pytest.mark.asyncio` only if needed (TestClient handles async endpoints synchronously — no marker needed).
- `PATCH /articles/{id}/publish` → 200 happy (article APPROVED, has content_es, has feature_image, not a series OR has series sections). 404 missing; 400 status not APPROVED; 400 missing content_es; 400 missing feature_image; 400 series article without series sections. Body: `{"published_at": "2026-01-01T00:00:00Z"}`.
- `PATCH /articles/{id}/unpublish` → 200, 404 missing. Verify DB-side `published_at` is None.
- `GET /articles/{id}` → 200 happy with HTML content, 404 missing.
- `PUT /articles/{id}` → 200 update (tags sync), 404 missing. Verify DB-side: when `tag_ids=[]` is sent, article tags cleared.
- `GET /articles/{id}/download?lang=en` → 200 with markdown + Content-Disposition. `lang=es` with Spanish content → 200; without → 404. Missing article → 404.
- `POST /articles/{id}/image-prompt` → mock `app.services.image_prompt.generate_image_prompt`. 200 happy; 404 missing; 400 no content.
- `POST /articles/{id}/upload-image` — uses real filesystem at `/app/static/images/articles/`. Either monkeypatch `IMAGES_DIR` to a `tmp_path` OR test happy path with a small in-memory PNG and clean up. Branches: 404 missing; 400 invalid content_type.
- `POST /articles/{id}/assign-media` → 200 happy (assign an existing `Media` row); 404 article; 404 media.

**Tags (2)** — `dashboard.py:991, 1006`:
- `GET /tags` (with and without `q`) → 200 list. Empty + seeded.
- `POST /tags` → 201 happy, 400 duplicate (case-insensitive).

**Status transitions (1)** — `dashboard.py:1548`:
- `PATCH /{entity}/{entity_id}/status` is the generic status updater. Cover:
  - Invalid entity name → 400 ("Invalid entity type").
  - Entity not found → 404.
  - Valid transition (e.g. PENDING → APPROVED on a `suggestions`) → 200, and `approved_at` is set.
  - Invalid transition (PENDING → PENDING) → 400 ("Invalid transition").
  - Test with all 3 entity types (`suggestions`, `research`, `articles`) — at least one happy path per entity.
  - Transitioning APPROVED → REJECTED should clear `approved_at`.

**Settings: admin emails (3)** — `dashboard.py:1597, 1607, 1633`:
- `GET /settings/admin-emails` → 200 empty + seeded.
- `POST /settings/admin-emails` → 201 happy, 400 duplicate (case-insensitive).
- `DELETE /settings/admin-emails/{id}` → 200 `{"ok": true}`, 404 missing.

**Settings: pricing (2)** — `dashboard.py:1663, 1673`:
- `GET /settings/pricing` → 200 list. Seed `PricingConfig` rows for the 6 keys in `PRICING_KEYS` (`dashboard.py:1653-1660`).
- `PUT /settings/pricing` → 200 happy (updates existing + inserts new). Invalid key → 400.

### Mocking conventions (mirror `test_article_generation.py`)

- **Anthropic / Sonnet calls (suggestion generation, research prompt, research summary, image prompt, translation, article generation already covered):** `@patch("app.services.<service_module>._get_client")` or `@patch("app.services.<service_module>.<top_level_function>")`. Look at `test_article_generation.py:106-110` for the `_get_client` pattern.
- **For services without `_get_client` (suggestion_generation, research, research_summary, image_prompt, translation):** patch the top-level function directly via `@patch("app.api.dashboard.<function>")` since the dashboard module imports them — OR `@patch("app.services.<module>.<function>")` — pick whichever the source supports cleanly.
- **Filesystem (`upload_feature_image`):** use `monkeypatch.setattr("app.api.dashboard.IMAGES_DIR", tmp_path)` to redirect the writes.
- **Always patch external services** — no real network, no real DeepL/Anthropic calls.

## Scope

### IN scope
- NEW: `backend/tests/test_dashboard.py` (or 2-4 split files as noted above, all under `backend/tests/`).
- That is all.

### OUT of scope (do NOT touch)
- `backend/app/api/dashboard.py` — no code changes; the tests must pass against the current implementation. If you find a real bug while writing tests, **document it in the PR description, file a follow-up issue manually if you want, but do NOT fix it here** — fixing app code would change scope and undermine the test-as-spec contract.
- `backend/app/schemas/dashboard.py` — already 100% covered; no changes.
- `backend/app/api/dependencies.py` — auth gate is in scope only for the 401-rejection test pattern, not for modification.
- `backend/tests/conftest.py` — the existing fixtures cover everything you need (`test_db`, `test_client`, `admin_token`, `taxonomy_factory`, `category_factory`, `suggestion_factory`, `research_factory`, `article_factory`). Do NOT add new fixtures to conftest.py — if a test needs custom seeding, put it inline as a helper function or class-level `setup_method` (mirror `test_media_library.py:419` `_seed_candidates` pattern).
- `backend/tests/test_article_generation.py`, `backend/tests/test_series_sections.py`, `backend/tests/test_pricing.py`, `backend/tests/test_media_library.py` — existing tests; do NOT modify. They already exercise certain dashboard endpoints — do not duplicate.
- Frontend, docker, CI workflows.

## Default rules for likely ambiguities

1. **Auth pattern: use the real `admin_token` fixture, not `_FAKE_ADMIN` patches.** Pass `?token={admin_token}` in the URL. Rationale: cleanest pattern is `test_media_library.py:419-643`; the `_FAKE_ADMIN` autouse-patch in `test_article_generation.py` is an alternative that was used for that file's specific need, not the preferred default.
2. **One test class per endpoint group**, e.g. `class TestDashboardSuggestions`, `class TestDashboardResearch`, `class TestDashboardArticles`, `class TestDashboardSettings`, `class TestDashboardStats`. Within a class, one method per endpoint × case (`test_get_suggestion_happy`, `test_get_suggestion_404`, etc.).
3. **File split decision**: If `test_dashboard.py` exceeds ~600 lines, split into `test_dashboard_suggestions.py`, `test_dashboard_research.py`, `test_dashboard_articles.py`, `test_dashboard_settings.py`. Otherwise keep it one file. Either is acceptable; brevity favors one file.
4. **Coverage delta target**: not a hard number. Aim for the 35 uncovered endpoints to each get at least the happy path + the primary error branch (404 or 400) tested. The CI coverage report on the PR will reveal the actual delta.
5. **`test_db` vs `test_client` vs `admin_token`**: always declare them as test method parameters (they're pytest fixtures). Pattern: `def test_x(self, test_client, test_db, admin_token):`.
6. **Seeding `Research`** for endpoints that join through `Research → Suggestion → Category`: use the existing `research_factory(suggestion=suggestion_factory(...))` chain — it handles the joins. For status-transition tests, set `research.status = "PENDING"` after creation since the factory defaults to `"APPROVED"`.
7. **Creating `Article` records**: use `article_factory(research_id=research.id, category=category, ...)`. The `published_at` sentinel pattern (see conftest.py:202) lets you pass `published_at=None` for unpublished articles; the default is `datetime.utcnow() - 1s`.
8. **Test for the OUTLINE_STATUS field on Article**: the model has `outline_status` defaulting to None — set it explicitly to `"APPROVED"` for the `available-for-writing` test.
9. **Series-article tests**: for the `publish_article` series-sections-required branch, set `series_parent_id` on a child article and verify the 400 fires when `ABOUT_MARKER_EN` is not in content. The `ABOUT_MARKER_EN` constant is `"**About this Article**"` (`app/services/series_sections.py:23`).
10. **DateTime in request bodies (e.g. `PublishRequest.published_at`)**: send as ISO 8601 string in JSON: `"2026-01-01T00:00:00Z"` or `"2026-01-01T00:00:00+00:00"`. Pydantic coerces.
11. **TestClient async**: FastAPI's `TestClient` (Starlette) runs async endpoints synchronously. No `pytest.mark.asyncio` needed; do NOT import `httpx.AsyncClient`.
12. **If a test reveals a real bug** (e.g. wrong status code, wrong response shape): document it in the PR description, mark that test as `@pytest.mark.skip(reason="dashboard.py bug: see PR description")` so the suite stays green, and surface the bug in the PR body. Do NOT change `dashboard.py`.
13. **Suggested order of work**: write tests one endpoint group at a time and run after each group, so failures stay scoped. `Stats → Suggestions → Tags → Settings → Research → Articles → Status transitions` is a reasonable order (smallest to largest).

## Failure-mode escape hatch

If the brief's primary path is blocked — a required fixture doesn't exist, an endpoint's behavior is structurally untestable without modifying app code, etc. — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. If you can complete a *partial* coverage subset cleanly (e.g. Stats + Suggestions + Tags + Settings done, Articles partial), that's a valid outcome — open the PR as ready-for-review with the completed scope and note in the description which endpoints were skipped and why.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/tests/test_dashboard.py` (or the agreed split files) added; no other files modified.
- [ ] `docker-compose exec backend pytest` runs green (full suite — no regressions).
- [ ] `docker-compose exec backend ruff check /app` clean (no new issues vs main baseline).
- [ ] `docker-compose exec backend ruff format /app` applied.
- [ ] Every new test uses the `admin_token` fixture (real MagicLink path), not the `_FAKE_ADMIN` patch.
- [ ] At least one 401-rejection test per file (missing token + invalid token).
- [ ] All external services (Anthropic, DeepL, Gemini, research_summary, image_prompt, translation, generate_historical_suggestions, generate_research_prompt) mocked — no real network.
- [ ] No new fixtures added to `conftest.py`; per-file helpers only.
- [ ] PR description includes: summary, **Production touch: no — verified by: tests-only file under `backend/tests/`, no app code modified, all external services mocked**, this checklist marked, a "what was covered / what was skipped" section enumerating endpoints, the test plan, `Closes #192`, and the Claude Code footer.

## PR shape

- **Branch**: `fix/issue-192-dashboard-tests`
- **Title**: `test(#192): add coverage for admin dashboard endpoints`
- **Body must include**: one-line summary; the **"Production touch: no — verified by:"** line; the self-review checklist with each item marked; a "Coverage added" section listing each endpoint covered (or skipped, with reason); a test plan (the docker-compose pytest commands run); `Closes #192`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass AND the full pytest suite is green; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (number of endpoints covered, number of tests added, coverage delta if visible from the CI run), and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 192`) and the verified-facts source files: `backend/app/api/dashboard.py`, `backend/app/schemas/dashboard.py`, `backend/app/api/dependencies.py`, `backend/tests/conftest.py`, `backend/tests/test_media_library.py` (canonical pattern), `backend/tests/test_article_generation.py` (existing dashboard tests — do not duplicate).
2. Confirm the verified facts still hold (endpoint count, existing coverage list, fixture names).
3. Spin up the test container: `docker-compose up -d backend db`.
4. Create `backend/tests/test_dashboard.py` and build out tests one endpoint group at a time, running pytest after each group.
5. When complete, run `pytest` (full suite), `ruff check /app`, `ruff format /app`. Iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
