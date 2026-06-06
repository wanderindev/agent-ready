# Fix brief — issue #194: Test coverage for public read endpoints (search, public_media, categories, zones)

## Identification

You are an autonomous agent resolving issue #194 in the Panama In Context codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- All backend commands run inside Docker containers per `CLAUDE.md`. From the worktree root:
  - Bring up the test stack: `docker-compose up -d backend db`
  - Run only the new tests: `docker-compose exec backend pytest tests/test_search.py tests/test_public_media.py tests/test_categories.py tests/test_zones.py -v`
  - Run the full suite to confirm no regressions: `docker-compose exec backend pytest`
  - Lint: `docker-compose exec backend ruff check /app` and `docker-compose exec backend ruff format --check /app` (touch only `backend/tests/` and optionally `backend/tests/conftest.py`).
- The test infra uses a real PostgreSQL 17 testcontainer (`backend/tests/conftest.py:17-34`). Tables are created via `Base.metadata.create_all`; each test runs inside a transaction that is rolled back (`test_db` fixture, line 37). The `test_client` fixture (line 61) overrides `get_db` for FastAPI.
- API prefix is `/api/v1` (registered in `backend/app/main.py:88-97`). All routes below are absolute paths a `TestClient` should hit.
- These are **public, unauthenticated** read endpoints — do NOT use `admin_token`.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Add pytest test files for four public read routers. The issue cites these coverage gaps (2026-05-29 baseline): `search.py` 40%, `public_media.py` 37%, `categories.py` 53%, `zones.py` 50%. **Per the oracle rule (`docs/pilot/agent-friendly-criteria.md`), the oracle is the schema contracts + the route's documented filters — NOT the implementation as-written. Derive expected behavior from the Pydantic response models and the query-param signatures, then assert against that.**

### Canonical patterns to mirror

- **Endpoint test shape**: `backend/tests/test_articles.py:1-116`. One `class TestX` per endpoint; methods named `test_<behavior>`; use `test_client.get(...)`; assert `response.status_code` and `response.json()` fields. Empty-result, happy-path, filter, and 404 cases each get their own method.
- **Media+MediaCandidate seeding (for `public_media`)**: `backend/tests/test_media_library.py:419-446` (`_seed_candidates` helper, raw inserts on `test_db`, then `test_db.commit()` and `test_db.refresh(...)`). You will need to also create `Media` rows for `public_media` tests because `_to_item` (public_media.py:43) reads `media.title`, `media.thumbnail_path`, etc., and the public list query joins `MediaCandidate.media_id == Media.id` (public_media.py:34).
- **Zone/Hotel seeding (for `zones`)**: `backend/tests/test_tours.py:10-24` (raw `Zone(...)` insert) and the Hotel model fields at `backend/app/models/hotel.py:14-33` (raw `Hotel(...)` insert with `name`, `name_es`, `address`, `address_es`, `zone_id`, `is_active`).
- **Category/Taxonomy seeding (for `categories` and `search`)**: use the existing `taxonomy_factory` (conftest.py:101) and `category_factory` (conftest.py:117). For search, also use `article_factory` (conftest.py:194) which already wires `category` + `published_at`.

### Endpoint inventory and oracle (what each test must assert)

#### `backend/app/api/search.py` — 1 endpoint
**`GET /api/v1/search?q=<str>&limit=<int>`** (line 16) → `list[ArticleSearchResult]`
- `q` is required, `min_length=2`. Missing or 1-char `q` → 422 (FastAPI validation).
- `limit` defaults 20, `ge=1, le=50`. Out-of-range → 422.
- Filters: `Article.status == "APPROVED"` AND `Taxonomy.id != 5` (Notable Figures exclusion).
- Matches `q` (ILIKE `%q%`) in `title`, `content`, OR `excerpt` (line 36-42).
- Order: title matches first, then `published_at desc nullsfirst`.
- Response items have: `id`, `title`, `slug`, `excerpt`, `published_at`, `category_name`, `highlight` (snippet from `_extract_highlight`, line 66).

**Tests to write** (one method each):
- `test_search_empty_db_returns_empty_list` — no articles, `q=panama`, expect 200 + `[]`.
- `test_search_short_query_returns_422` — `q=a`, expect 422.
- `test_search_missing_query_returns_422` — no `q`, expect 422.
- `test_search_matches_title` — seed article titled "Panama Canal History", search `q=Canal`, expect 1 result, `data[0]["title"]` matches, `data[0]["highlight"]` is a non-empty str.
- `test_search_matches_content` — seed article with title="Other", content="The story of Canal Zone", search `q=Canal`, expect 1 result.
- `test_search_matches_excerpt` — seed article with excerpt="A Canal essay", search `q=Canal`, expect 1 result.
- `test_search_excludes_non_approved` — seed one APPROVED + one PENDING with matching title; expect 1 result (the approved one).
- `test_search_excludes_taxonomy_5` — seed taxonomy with `id` set to 5 (Notable Figures), category under it, article matching the query; expect 0 results. (Use `Taxonomy(id=5, name="Notable Figures")` direct insert if `taxonomy_factory` doesn't allow setting id; check it — if it doesn't, raw-insert per the test_tours.py pattern.)
- `test_search_title_match_ranked_first` — seed two matching articles, one in title, one only in content; expect the title-match first in the response.
- `test_search_respects_limit` — seed 5 matching articles, request `limit=2`, expect 2 results.
- `test_search_limit_out_of_range_returns_422` — `limit=100`, expect 422.

#### `backend/app/api/public_media.py` — 5 endpoints

Public filter (applied to all): `MediaCandidate.status == "APPROVED"` AND `MediaCandidate.relevance_score >= 0.7` AND `Media.id NOT IN (SELECT feature_image_id FROM articles WHERE feature_image_id IS NOT NULL)` (lines 27-40).

**Seeding helper**: write a `_seed_public_media(test_db, n, *, status="APPROVED", relevance=0.9, with_tags=None)` helper in the test file (mirror `test_media_library.py:419`). Each row needs a `Media` row (required fields per `backend/app/models/media.py:42-63`: `filename`, `original_filename`, `file_path`, `file_size`, `mime_type`, `media_type`, `source` — set `title`, `thumbnail_path`, `search_terms`, `attribution`, `license`, `license_url`, `source_url`, `width`, `height` for response coverage) and a `MediaCandidate` row with `media_id=<media.id>`.

**`GET /api/v1/public-media?search=&tag=&page=1&page_size=30`** (line 64) → `PublicMediaListResponse{items, total, page, page_size}`
- `page >= 1`, `page_size` in `[1, 60]`. Out-of-range → 422.
- `search` does ILIKE on `Media.search_terms` (line 76).
- `tag` filters `MediaCandidate.tags` array contains the tag (line 78).

Tests:
- `test_list_empty` — no data, expect 200 + `total=0`, `items=[]`, `page=1`, `page_size=30`.
- `test_list_excludes_pending` — seed 1 PENDING + 1 APPROVED (both score 0.9); expect `total=1`.
- `test_list_excludes_low_relevance` — seed 1 APPROVED score 0.6 + 1 APPROVED score 0.9; expect `total=1`.
- `test_list_excludes_feature_images` — seed an Article with `feature_image_id` set to a qualifying Media's id (you'll need a category + research_id; the existing `article_factory` works — pass `category=` and set `feature_image_id` directly post-create OR use the model). The feature-image media should be excluded; expect `total=0` (or seed two and assert only the non-feature one returns). NOTE: `article_factory` does not expose `feature_image_id` — set it via `test_db` after creation: `art.feature_image_id = media.id; test_db.commit()`.
- `test_list_search_matches_search_terms` — seed media with `search_terms="canal locks engineering"`; request `?search=locks`; expect 1 match.
- `test_list_tag_filter` — seed two candidates, one with `tags=["historical"]`, one with `tags=["modern"]`; request `?tag=historical`; expect `total=1`.
- `test_list_pagination` — seed 5; request `?page=1&page_size=2`; expect `len(items)==2`, `total==5`, `page==1`, `page_size==2`. Request `?page=3&page_size=2`; expect `len(items)==1`.
- `test_list_page_size_out_of_range_returns_422` — `?page_size=100`; expect 422.
- `test_list_orders_by_relevance_desc` — seed two with relevance 0.8 and 0.95; expect 0.95 first.

**`GET /api/v1/public-media/stats`** (line 101) → `{total: int}`
- `test_stats_empty` — expect `{"total": 0}`.
- `test_stats_counts_only_qualifying` — seed 1 PENDING + 2 APPROVED (relevance 0.9); expect `total=2`.

**`GET /api/v1/public-media/tags`** (line 111) → `{tags: list[str]}` (distinct, sorted alphabetically)
- `test_tags_empty` — expect `{"tags": []}`.
- `test_tags_returns_distinct_sorted` — seed candidates with `tags=["zebra", "alpha"]` and `tags=["alpha", "mid"]`; expect `["alpha", "mid", "zebra"]`.
- `test_tags_excludes_non_qualifying` — seed PENDING candidate with `tags=["pending-tag"]`; expect `pending-tag` NOT present.

**`GET /api/v1/public-media/{media_id}`** (line 137) → `PublicMediaDetail`
- 404 if not found or not qualifying.
- `test_get_detail_found` — seed qualifying media, request its id; expect 200, response includes `search_terms` (the field unique to detail vs list).
- `test_get_detail_not_found` — request id `99999`; expect 404, detail "Media not found".
- `test_get_detail_excludes_pending` — seed PENDING candidate; expect 404 (does not bypass public filter).

**`GET /api/v1/public-media/{media_id}/download`** (line 170) — proxies the file from object storage.
- 404 if not found / not qualifying / `file_path` is None.
- 502 if upstream fetch fails.
- 200 streams with `Content-Disposition: attachment; filename=...`.
- **Mock `httpx.Client`** (per `CLAUDE.md` testing requirement: mock external services).
- `test_download_not_found` — request id `99999`; expect 404.
- `test_download_success` — seed qualifying media with `file_path="https://example.com/img.jpg"`; `@patch("app.api.public_media.httpx.Client")` so the context-manager returns a mock with `.get(...)` returning an object with `status_code=200` and `content=b"fakebytes"`; expect 200, `response.headers["content-disposition"]` contains `attachment; filename="img.jpg"`, body == `b"fakebytes"`.
- `test_download_upstream_502` — same as above but upstream `status_code=500`; expect 502.
- `test_download_missing_file_path` — seed qualifying media with `file_path=None`; expect 404. **Source check first**: `Media.file_path` is `nullable=False` in the model (`media.py:45`) so this case may be unreachable at the DB level. If `Media(file_path=None)` raises on commit, **skip this test and note in the PR description (shape #2)** — do not invent a way around the constraint.

#### `backend/app/api/categories.py` — 4 endpoints

All filter `Category.taxonomy_id != 5` (Notable Figures).

**`GET /api/v1/categories?taxonomy_id=<int>`** (line 17) → `list[CategoryBase]` with `article_count`
- `test_list_empty` — no categories; expect `[]`.
- `test_list_returns_categories_with_counts` — seed one taxonomy, one category, two APPROVED articles + one PENDING; expect 1 category with `article_count=2`.
- `test_list_excludes_taxonomy_5` — seed taxonomy id=5 with a category; expect 0 results.
- `test_list_filters_by_taxonomy_id` — seed two taxonomies + one category each; request `?taxonomy_id=<first>`; expect 1 result.

**`GET /api/v1/categories/with-content`** (line 55) → `list[CategoryBase]` — only categories that HAVE approved articles.
- `test_with_content_excludes_empty_categories` — seed two categories, articles only under the first; expect 1 result.
- `test_with_content_excludes_pending_only_categories` — seed a category whose only article is PENDING; expect 0 results.

**`GET /api/v1/categories/{category_slug}`** (line 85) → dict (no response_model)
- 404 if no category's `generate_slug(name)` matches.
- `test_get_by_slug_found` — seed category named "Colonial Era"; request `/categories/colonial-era`; expect 200, response includes `id`, `name`, `slug`, `taxonomy_id`, `taxonomy_name`, `article_count`.
- `test_get_by_slug_not_found` — request `/categories/nonexistent`; expect 404.
- `test_get_by_slug_counts_only_approved` — seed category + 2 APPROVED + 1 PENDING article; expect `article_count == 2`.

**`GET /api/v1/categories/taxonomies`** (line 120) → `list[TaxonomyBase]`
- **KNOWN LATENT ROUTING BUG (flag in PR description, shape #4; do NOT fix in this PR)**: `/{category_slug}` at line 85 is declared BEFORE `/taxonomies` at line 120. FastAPI matches by declaration order, so a GET to `/api/v1/categories/taxonomies` is captured by the slug handler, which calls `generate_slug(c.name) == "taxonomies"` against existing categories — almost certainly no match → 404. The taxonomies handler is effectively unreachable via HTTP today.
- `test_taxonomies_endpoint_unreachable_due_to_routing` — seed a taxonomy; request `/api/v1/categories/taxonomies`; assert `response.status_code == 404` (current observed behavior). Add a comment in the test body explaining this characterizes a routing-order bug and that the fix (re-ordering the route declarations) is OUT of scope for this issue.
- Surface this in the PR description: "Found latent routing bug in `categories.py`: `/{category_slug}` declared before `/taxonomies` shadows the taxonomies route. Test characterizes current 404 behavior. Recommend a follow-up issue to swap declaration order."

#### `backend/app/api/zones.py` — 3 endpoints

All filter `is_active.is_(True)`. `lang` param defaults `"en"`; `"es"` swaps to `name_es` / `description_es` / `address_es`.

**`GET /api/v1/zones?lang=en|es`** (line 13) → `list[ZoneListItem]`
- `test_list_empty` — expect `[]`.
- `test_list_active_only` — seed `is_active=True` and `is_active=False`; expect only the active one.
- `test_list_ordered_by_display_order` — seed `display_order=2` then `display_order=1`; expect order=1 first.
- `test_list_default_lang_english` — seed `name="Casco"`, `name_es="Casco ES"`; expect `data[0]["name"] == "Casco"`.
- `test_list_spanish` — `?lang=es`; expect `name_es` value.

**`GET /api/v1/zones/hotels/search?q=<str>&lang=&limit=`** (line 37) → `list[HotelSearchResult]`
- `q` required, `min_length=2`. Missing/short → 422.
- `limit` in `[1, 50]`.
- Filters `is_active=True`, matches `Hotel.name` OR `Hotel.name_es` (ILIKE), ordered by `name`, joined-loads zone.
- `test_search_short_q_returns_422` — `?q=a`.
- `test_search_matches_english_name` — seed hotel name="Hilton Panama"; `?q=Hilton`; expect 1.
- `test_search_matches_spanish_name` — seed hotel `name="X"`, `name_es="Hotel Panamá"`; `?q=Panamá`; expect 1.
- `test_search_excludes_inactive` — seed `is_active=False` hotel matching; expect 0.
- `test_search_returns_zone_info` — seed hotel + zone; `data[0]["zone_id"]` and `data[0]["zone_name"]` present.
- `test_search_respects_limit` — seed 3 matching, `?limit=1`; expect 1 result.
- `test_search_spanish_lang_swaps_fields` — seed hotel with `name_es` and `address_es`; `?q=...&lang=es`; expect `data[0]["name"]` is the `name_es` value, `data[0]["address"]` is `address_es`, `data[0]["zone_name"]` is `zone.name_es`.

**`GET /api/v1/zones/hotels/{hotel_id}?lang=`** (line 74) → `HotelSearchResult`
- 404 if not found or inactive.
- `test_get_hotel_found` — expect 200 with `id`, `name`, `address`, `zone_id`, `zone_name`.
- `test_get_hotel_not_found` — request `99999`; expect 404.
- `test_get_hotel_inactive_returns_404` — seed `is_active=False`; expect 404.
- `test_get_hotel_spanish` — `?lang=es`; expect spanish field values.

## Scope

### IN scope
- Create `backend/tests/test_search.py` — tests for `/api/v1/search`.
- Create `backend/tests/test_public_media.py` — tests for `/api/v1/public-media/*` (5 endpoints).
- Create `backend/tests/test_categories.py` — tests for `/api/v1/categories/*` (4 endpoints).
- Create `backend/tests/test_zones.py` — tests for `/api/v1/zones/*` (3 endpoints).
- (Optional, only if it reduces duplication) tiny additions to `backend/tests/conftest.py` for shared `zone_factory`, `hotel_factory`, `media_factory`, `media_candidate_factory`. Per the existing precedent (`test_media_library.py` uses an in-file `_seed_candidates`; `test_tours.py` defines its `zone`/`attraction`/`tour` as in-file fixtures), it is also fine to keep helpers in each test file. **Do not refactor existing tests.**

### OUT of scope (do NOT touch)
- Any file under `backend/app/api/` — production code is untouched. This is a test-only PR.
- Any file under `backend/app/models/`, `backend/app/schemas/`, `backend/app/services/`.
- Existing test files: `test_articles.py`, `test_media_library.py`, `test_tours.py`, `test_orders.py`, `test_pricing.py`, etc. Do not edit them.
- The `categories.py` route-order bug — characterize it in a test, surface it in the PR description, do NOT fix it.
- `backend/app/api/dashboard.py` (owned by issue #192, parallel) and `backend/app/services/{media_scoring,image_storage,loc,wikimedia}.py` + `backend/app/utils/{markdown,slug}.py` (owned by issue #195, parallel). Zero file overlap is expected.
- Coverage configuration (`pyproject.toml`, `.coveragerc`) — already in place from PR #196.
- No new dependencies; no `requirements.txt` changes.

## Default rules for likely ambiguities

- **Oracle source**: derive every assertion from the Pydantic response schemas (`backend/app/schemas/{article,public_media,category,zone}.py`) and the query-param signatures, NOT from re-reading the implementation. If the implementation contradicts what the schema/contract implies, write the test to the contract and flag the divergence in the PR description (shape #2). The issue explicitly invokes the oracle rule.
- **Factory vs raw-insert**: use existing factories (`taxonomy_factory`, `category_factory`, `article_factory`, `suggestion_factory`, `research_factory`) where they fit. For `Media`, `MediaCandidate`, `Zone`, `Hotel`, raw inserts on `test_db` are the established pattern (`test_media_library.py:419`, `test_tours.py:11`). Either define a small `_seed_*` helper at the top of the file (preferred — keeps blast radius small) or add a fixture to `conftest.py` (only if shared across multiple new files).
- **Taxonomy id=5 test for search/categories**: `taxonomy_factory` doesn't expose `id`. Insert directly: `tax = Taxonomy(id=5, name="Notable Figures"); test_db.add(tax); test_db.commit()`. The testcontainer is fresh per session and the SAVEPOINT-rollback per test means id=5 can be re-claimed cleanly. If a UNIQUE/PK conflict arises across tests, scope the seeding to one method or use `test_db.merge`.
- **Article `feature_image_id` for public_media exclusion test**: `article_factory` doesn't set `feature_image_id`. After creating the article, mutate it: `art.feature_image_id = media.id; test_db.commit()`.
- **Mocking external HTTP** (`httpx.Client` in `public_media.download`): use `unittest.mock.patch` on `app.api.public_media.httpx.Client` exactly like `test_media_library.py:583` patches `app.api.media_library.WikimediaService`. The `Client()` is used as a context manager (line 192), so the patch must return a `MagicMock()` whose `__enter__` returns an object whose `.get(...)` returns a response-like mock.
- **422 vs 400**: FastAPI returns 422 (Unprocessable Entity) for query-param validation failures (`min_length`, `ge`, `le`). Assert 422, not 400.
- **Test class naming**: one `class TestX` per endpoint (mirror `test_articles.py`). Methods: `test_<scenario>`. Use snake_case throughout.
- **`Media.file_path` is `nullable=False`** — if the "missing file_path" test scenario can't be constructed without violating the constraint, skip it and note in the PR description. Do not invent a workaround.
- **`pyproject.toml` / line length**: follow existing test files' style. Run `ruff format --check` on the new files; if it complains, run `ruff format` and commit the result.
- **No coverage assertions in tests** — do not write tests that check coverage percentages. The PR's value is the tests themselves; coverage delta is a side effect the reviewer reads from CI output.
- **Don't try to hit a coverage target number.** Write tests that meaningfully exercise each endpoint's filters/branches; the percentage will improve naturally. If you finish the inventory above and want more, add edge cases for the same endpoints — don't drift to other files.

## Failure-mode escape hatch

If the brief's primary path is blocked — for example, the testcontainer fails to start, a required model field constraint makes a test scenario structurally impossible, or you discover the route declaration order actually returns the taxonomies list (contradicting this brief's analysis) — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. If a test scenario is impossible (e.g. the `file_path=None` case), skip it and note in the PR description rather than monkey-patching the model.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Four new test files exist: `test_search.py`, `test_public_media.py`, `test_categories.py`, `test_zones.py`.
- [ ] All endpoints listed in "The task" have at least the tests enumerated for them (or a skip+note if structurally impossible).
- [ ] `docker-compose exec backend pytest tests/test_search.py tests/test_public_media.py tests/test_categories.py tests/test_zones.py -v` is fully green.
- [ ] `docker-compose exec backend pytest` (full suite) is green — no regressions to existing tests.
- [ ] `docker-compose exec backend ruff check /app` exits 0 (no new issues in new files).
- [ ] `docker-compose exec backend ruff format --check /app` exits 0 for the new files.
- [ ] Only the IN-scope files are modified (no production-code edits, no edits to existing test files).
- [ ] PR description includes the production-touch line, the test plan, the route-order bug surfacing for `categories.py`, and any other shape-#2/#3/#4 flags.
- [ ] No coverage thresholds added or modified.

## PR shape

- **Branch**: `fix/issue-194-public-read-endpoint-tests`
- **Title**: `test(#194): add coverage for search, public_media, categories, zones`
- **Body must include**:
  - One-line summary.
  - **"Production touch: no — verified by:"** line stating no files under `backend/app/` were modified.
  - The self-review checklist with each item marked.
  - A test plan listing the four new test files and the `pytest` invocation.
  - A "Findings to surface" section noting the `categories.py` `/{category_slug}` vs `/taxonomies` route-order bug (with file:line) as a follow-up.
  - Any shape #2/#3/#4 flags from the four-shape taxonomy.
  - `Closes #194`.
  - `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (file count + test count), and any flags you surfaced (including the route-order finding). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Bring up the test stack: `docker-compose up -d backend db`. Run the existing suite once (`docker-compose exec backend pytest`) to confirm a green baseline before you start.
2. Read this issue (`gh issue view 194`) and the four router files (`backend/app/api/{search,public_media,categories,zones}.py`); confirm the verified facts above still hold against current source.
3. Read the canonical patterns: `backend/tests/test_articles.py`, `backend/tests/test_media_library.py:419-446`, `backend/tests/test_tours.py:1-79`, `backend/tests/conftest.py`.
4. Write the four test files one at a time, running each as you go.
5. Run the full suite + lint; iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
