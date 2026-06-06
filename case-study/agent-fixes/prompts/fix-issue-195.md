# Fix brief — issue #195: [Quality] Test coverage for pure-logic & parser services (media_scoring, loc, wikimedia, markdown, slug)

## Identification

You are an autonomous agent resolving issue #195 in the `panama-in-context` codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- All backend commands run inside Docker. Use:
  - `docker-compose up -d backend db` to start services if not running.
  - `docker-compose exec backend pytest backend/tests/test_<name>.py -v` for a single file; for the whole suite, `docker-compose exec backend pytest`.
  - `docker-compose exec backend ruff check /app` (then `--fix` if needed) and `docker-compose exec backend ruff format /app`.
- The Postgres testcontainer fixture (`test_db`, `test_engine`, `postgres_container` in `backend/tests/conftest.py`) is **not needed** for the pure-logic and parser tests in this brief — do NOT pull it in unless a test genuinely requires DB state. Mirror `TestCleanHtml` / `TestMakeThumbnailUrl` in `test_media_library.py` which instantiate plain classes with no fixtures.
- Issue #194 (public read endpoints) may be running in parallel in another worktree. It owns `backend/tests/test_search.py`, `backend/tests/test_public_media.py`, `backend/tests/test_categories.py`, `backend/tests/test_zones.py` (and only adds/edits tests against `app/api/*`). Do NOT touch any file under `app/api/`. Do NOT modify `backend/tests/conftest.py` unless strictly necessary (and if so, flag it loudly in the PR description so the operator can resolve any conflict with #194).

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include and flag in PR description.
2. **Brief is factually wrong about the codebase** → follow the source; flag in PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Add unit tests for pure-logic and parser code paths in `backend/app/services/` and `backend/app/utils/`. The issue cites a coverage baseline of 2026-05-29; you do NOT need to hit a specific coverage number — you must add the specific behaviors enumerated below. The oracle for each test comes from this brief, not from reading the implementation and asserting whatever it does (that's a characterization test and is worse than no test).

### Canonical pattern to mirror

- **Primary**: `backend/tests/test_media_library.py` lines 19-365 — class-grouped tests, `setup_method` instantiating service with `rate_limit=0`, `@patch.object(ServiceClass, "_api_request")` for HTTP mocking, plain pure-function tests with no fixtures. Mirror this style exactly for the new test files.
- **Secondary**: `backend/tests/test_translation.py` lines 7-100 — `with patch("app.services.translation.deepl.Translator") as mock:` for mocking external SDK clients. Mirror this for the anthropic client in `media_scoring`.
- **Already covered** in `test_media_library.py` (do NOT duplicate): `_clean_html`, `_make_thumbnail_url`, `_extract_resource_id`, `_determine_license`, `WikimediaService._extract_metadata`, `LOCService._extract_metadata`, `WikimediaService.get_subcategories`, `WikimediaService.get_category_files`, `LOCService.search`, `MediaCandidate` model, media-library API endpoints.

### 1. NEW: `backend/tests/test_slug.py`

Module under test: `backend/app/utils/slug.py`. Functions: `generate_slug(text: str) -> str`, `generate_slug_es(text: str) -> str` (alias).

These are pure — no mocks needed. Add a `TestGenerateSlug` class with these explicit input→output assertions (the oracle is the docstring's stated behavior):

| Input | Expected output |
|---|---|
| `"Panama Canal History"` | `"panama-canal-history"` |
| `"Construcción del Canal"` | `"construccion-del-canal"` (á→a, ó→o, lowercased) |
| `"Año Nuevo en Panamá"` | `"ano-nuevo-en-panama"` (ñ→n, á→a) |
| `"  leading and trailing  "` | `"leading-and-trailing"` |
| `"Multiple   Spaces"` | `"multiple-spaces"` (collapsed) |
| `"snake_case_text"` | `"snake-case-text"` (underscores → hyphens) |
| `"Special!@#$Chars"` | `"specialchars"` (non-alphanumeric stripped) |
| `"---leading---hyphens---"` | `"leading-hyphens"` |
| `""` | `""` |
| `None`-equivalent empty | `""` (only test `""`, do not pass `None` — signature is `str`) |
| `"Niño"` | `"nino"` |
| `"Ñandú"` | `"nandu"` (Ñ→n per source line 33 — verify: source replaces both `ñ` and `Ñ` with lowercase `n`) |

Add a small `TestGenerateSlugEs` class with one test asserting `generate_slug_es("Año")` returns the same value as `generate_slug("Año")` (it's an alias per docstring).

### 2. NEW: `backend/tests/test_markdown.py`

Module under test: `backend/app/utils/markdown.py`. Functions:
- `markdown_to_html(content: str) -> str`
- `extract_series_header(content: str) -> tuple[str, str]`
- `html_to_markdown(html: str) -> str`
- `strip_bio_links(content: str) -> str`

These are pure (markdown library + regex). No mocks needed.

**`TestMarkdownToHtml`** — assert these behaviors:
- Empty string returns `""`.
- `"# Hello"` → output contains `<h1>` and the text `Hello`. (TOC extension is enabled but `permalink: False`, so no permalink anchor.)
- Fenced code block: `"```python\ncode = 1\n```"` → output contains `<pre>` and `<code>`.
- Table syntax (two-line GitHub table) → output contains `<table>`.
- Single newline in content → output contains `<br />` (the `nl2br` extension is enabled).

**`TestExtractSeriesHeader`** — assert (oracle: source lines 35-61):
- Empty input → `("", "")`.
- Content with no `\n---\n` separator → `("", original_content)`.
- Content where the part before `\n---\n` contains `"About this Article"` → returns `(stripped_header, stripped_remainder)`.
- Content where the first part contains the word `"part"` (case-insensitive) → returns `(stripped_header, stripped_remainder)`.
- Content with `\n---\n` but neither marker phrase → `("", original_content)`.

**`TestHtmlToMarkdown`** — assert:
- Empty string returns `""`.
- `"<h1>Hello</h1>"` round-trips to a string containing `# Hello`.
- `"<strong>bold</strong>"` round-trips to a string containing `*bold*` (strong_em_symbol="*" per source line 83).
- `"<ul><li>a</li><li>b</li></ul>"` round-trips to bullets using `-` (bullets="-" per source line 82).

**`TestStripBioLinks`** — assert (oracle: source lines 87-109):
- `"[Christopher Columbus](/en/notable-figures/colonial-era-figures/christopher-columbus)"` → `"Christopher Columbus"`.
- `"[Balboa](https://panamaincontext.com/es/notable-figures/balboa)"` → `"Balboa"`.
- `"[Regular Link](https://example.com/some/path)"` → unchanged (no `notable-figures` in URL).
- Mixed content with one bio link and one non-bio link → only the bio link is stripped to plain text.
- Empty string → `""`.

### 3. NEW: `backend/tests/test_media_scoring.py`

Module under test: `backend/app/services/media_scoring.py`. Function: `score_candidates(db: Session, batch_size: int = 30, max_batches: int | None = None) -> dict[str, Any]`.

This function (a) queries DB for unscored PENDING `MediaCandidate` rows, (b) calls `anthropic.Anthropic().messages.create(...)` with a scoring prompt, (c) parses the JSON response, (d) writes `relevance_score` and `relevance_notes` back to the candidates, (e) commits and returns stats.

It needs the `test_db` fixture from `conftest.py` AND a mocked anthropic client. Mock pattern (mirror `test_translation.py:11-28`):

```python
from unittest.mock import MagicMock, patch
from app.services.media_scoring import score_candidates

@patch("app.services.media_scoring.anthropic.Anthropic")
def test_scores_pending_candidates(mock_anthropic_class, test_db):
    # Seed candidates via direct MediaCandidate inserts (mirror test_media_library.py:371)
    # Build mock_client with messages.create returning a fake response object whose
    # .content[0].text is a JSON array string like '[{"id": <id>, "score": 0.85, "reason": "..."}]'
    # Call score_candidates(test_db, batch_size=10, max_batches=1)
    # Assert candidate.relevance_score == 0.85 and relevance_notes == "..."
```

**Required test cases** (each is a separate test method; oracle comes from the listed source line):

- **scores PENDING + unscored candidates** (source lines 60-73): seed 2 PENDING candidates with `relevance_score=None`, mock returns scores for both IDs, assert both get scored, `stats["candidates_scored"] == 2`, `stats["batches_processed"] == 1`.
- **skips candidates that are not PENDING** (source line 64): seed one PENDING and one APPROVED candidate, mock returns scores for only the PENDING one's ID (the APPROVED won't be in the LLM prompt), assert APPROVED's `relevance_score` stays None.
- **skips candidates that already have a score** (source line 65): seed one with `relevance_score=0.5`, assert it's not re-scored.
- **clamps scores to [0.0, 1.0] and rounds to 2 decimals** (source line 111-113): mock returns `{"score": 1.5}` → candidate gets `1.0`; mock returns `{"score": -0.3}` → candidate gets `0.0`; mock returns `{"score": 0.123456}` → candidate gets `0.12`.
- **truncates reason to 500 chars** (source line 114): mock returns reason with 600 'a's → stored notes are 500 chars.
- **handles markdown-fenced JSON response** (source lines 98-102): mock returns ```` ```json\n[{...}]\n``` ```` → still parsed correctly.
- **respects `max_batches` parameter** (source lines 55-57): seed 50 candidates, call with `batch_size=10, max_batches=2`, assert `stats["batches_processed"] == 2` and only 20 candidates were scored.
- **stops when no candidates left** (source lines 73-74): seed 0 candidates, call function, assert returns `{"candidates_scored": 0, "batches_processed": 0}` and the anthropic mock is never called.
- **rolls back and stops on exception** (source lines 121-124): mock `messages.create` to raise `Exception("boom")`, seed 5 candidates, assert no candidate gets scored, function returns without raising.
- **silently drops scores for unknown candidate IDs** (source lines 109-110): mock returns a score for an `id` that isn't in the batch → no error, only matching IDs are updated.

Use `from app.models.media_candidate import CandidateStatus, MediaCandidate` and create candidates inline (mirror `TestMediaCandidateModel.test_create_candidate` at `test_media_library.py:371`). Required fields per the model: `source`, `external_id`, `external_url`, `title`. Use `status=CandidateStatus.PENDING.value`.

### 4. MODIFY: `backend/tests/test_media_library.py` — extend with uncovered surface

Add the following new test classes at the end of the file (after `TestMediaLibraryAPI`):

**`TestWikimediaServiceFilesMetadata`** — covers `WikimediaService.get_files_metadata` (currently untested directly):
- `@patch.object(WikimediaService, "_api_request")` returns a fake batch-query response with two pages each containing `imageinfo` — assert two metadata dicts returned, both with `source == "WIKIMEDIA"`.
- Empty `titles` list → returns `[]` without calling `_api_request`.
- Mock returns a page missing `imageinfo` → that page is silently dropped (source lines 199-204).

**`TestWikimediaServiceUpsert`** — covers `WikimediaService._upsert_candidates` (uses `test_db` fixture):
- Inserts new candidates when no existing row matches → `new_count == len(input)`, `skip_count == 0`.
- Skips and merges `source_categories` when row exists (source lines 342-348): seed an existing candidate with `source_categories=["A"]`, upsert with categories `["B"]`, assert existing row's `source_categories == ["A", "B"]` (sorted) and `skip_count == 1`.
- When existing categories already contain the new ones → no rewrite happens (assert `source_categories` is unchanged).

**`TestWikimediaServiceCrawlOrchestrator`** — covers `WikimediaService.crawl_categories` (uses `test_db`):
- Mock `get_subcategories` and `get_files_metadata` to return controlled lists; assert returned `stats` dict has the right counts (`categories_crawled`, `images_found`, `images_new`, `images_skipped`, `errors`).
- Mock `get_subcategories` to raise on one seed → assert `stats["errors"]` contains the error message and the crawl continues.

**`TestLOCServiceUpsert`** — covers `LOCService._upsert_candidates` (uses `test_db`): mirror the Wikimedia upsert tests but with `source="LOC"`. Verify that `tags` and `source_categories` are both merged (source lines 354-364) — Wikimedia only merges `source_categories`, LOC merges both. Important contract difference; assert both.

**`TestLOCServiceCrawlOrchestrator`** — covers `LOCService.crawl_panama` (uses `test_db`):
- `@patch.object(LOCService, "search")` to return a synthetic list of results; `@patch.object(LOCService, "_extract_metadata")` to return controlled metadata; assert stats counts and that one query in `LOC_SEARCH_QUERIES` runs per loop iteration.
- Pass a custom `queries` list of one query → `stats["queries_executed"] == 1`.
- Mock `search` to raise on one query → `stats["errors"]` contains the message; loop continues.

**`TestLOCGetItemDetail`** — covers `LOCService.get_item_detail`:
- `@patch.object(LOCService, "_api_request")` returns a dict → method returns that dict.
- `@patch.object(LOCService, "_api_request")` raises → method returns `None` (does not propagate; source lines 132-135).

**`TestLOCGetBestImageUrl`** — covers `loc.get_best_image_url`:
- Mock `httpx.Client` (via `with patch("app.services.loc.httpx.Client") as mock_client:`) to return a response with a `resources[0].files` structure containing two JPEGs of different sizes (10000 and 500000 bytes) — assert the larger one is returned.
- Mock response includes a 15MB JPEG (over the 10MB cap) — assert it is NOT returned (source line 420).
- Mock response includes only non-JPEG MIME types → returns `None` (after also exhausting URL-variant fallback; pick `image/tiff` and verify None).
- `httpx.Client` raises → returns `None`, no exception (source lines 455-457).

### 5. OPTIONAL NEW: `backend/tests/test_image_storage.py`

Only the pure-bytes helpers are clearly in-scope for this issue's "pure logic" framing. If you have time, add this file with:

**`TestMakeStorageKey`** — covers `make_storage_key(source, external_id, content_type)`:
- `make_storage_key("WIKIMEDIA", "File:Panama_Canal.jpg")` → `"media/wikimedia/Panama_Canal.jpg"` (source line 271).
- `make_storage_key("WIKIMEDIA", "File:Has spaces.jpg")` → `"media/wikimedia/Has_spaces.jpg"` (spaces→underscore).
- `make_storage_key("LOC", "/item/2007660946/")` → `"media/loc/2007660946.jpg"` (extension added from default content_type).
- `make_storage_key("LOC", "/item/2007660946/", content_type="image/png")` → `"media/loc/2007660946.png"`.
- `make_storage_key("LOC", "/item/abc.tif/")` → `"media/loc/abc.tif"` (existing extension preserved).
- `make_storage_key("SMITHSONIAN", "some-id.png")` → `"media/smithsonian/some-id.png"` (PurePosixPath fallback).

**`TestWatermarkInfographic`** — covers `watermark_infographic(image_bytes)`:
- Build a 500×500 white PNG with PIL in-test; pass bytes to function; load the result with PIL; assert the result is a valid PNG with the same dimensions (the watermark is overlaid, doesn't resize).
- Assert the output bytes differ from the input bytes (something was drawn).

**`TestWatermarkSlides`** — covers `watermark_slides(pdf_bytes)`:
- Build a one-page PDF in-test with PyMuPDF (`fitz.open()`, `doc.new_page()`, `doc.save(buf)`); pass bytes to function; reload with PyMuPDF; assert page count is unchanged; assert the bytes differ from input.
- Skip if `fitz` import is heavy — the function imports it lazily (source line 218), so the test must import it directly to construct fixtures.

Do NOT test `ImageStorageService.download_image`, `upload_image`, `delete_image`, `generate_thumbnail`, or `download_and_upload` — they're DO Spaces / httpx integrations and out of scope for this "pure-logic" issue.

## Scope

### IN scope
- `backend/tests/test_slug.py` (new)
- `backend/tests/test_markdown.py` (new)
- `backend/tests/test_media_scoring.py` (new)
- `backend/tests/test_media_library.py` (extend with the classes named in section 4)
- Optional: `backend/tests/test_image_storage.py` (new — pure helpers only, per section 5)

### OUT of scope (do NOT touch)
- Any file under `backend/app/` — this issue is test-only. If you find a bug while writing tests, file it as a comment in the PR description, do NOT fix it. Characterization-fixing a bug under test-coverage cover is the failure mode the oracle rule guards against.
- `backend/app/api/` (issue #194's territory)
- `backend/tests/test_search.py`, `test_public_media.py`, `test_categories.py`, `test_zones.py` (issue #194's territory)
- `backend/tests/conftest.py` — do NOT modify. The existing fixtures (`test_db`, factories) are sufficient. If a test genuinely needs a new fixture, define it locally in the test file.
- Coverage configuration (`pyproject.toml` `[tool.coverage.*]` is already set; do not change it).
- Tests for the non-pure ImageStorageService HTTP/boto3 methods.
- Tests for `LOCService.search`, `WikimediaService._extract_metadata`, `_clean_html`, etc. — already covered in `test_media_library.py`.

## Default rules for likely ambiguities

- **Test discovery / placement**: tests live under `backend/tests/` (per `pyproject.toml:9` `testpaths = ["tests"]`). Class names follow `Test<ThingUnderTest>` style, method names `test_<behavior>` — mirror existing files exactly.
- **Imports**: import from `app.services.X` and `app.models.X` (no `backend.` prefix — `pyproject.toml:8` sets `pythonpath = ["."]` and tests run from `/app` in the container).
- **No async**: every service function here is sync; do NOT use `pytest.mark.asyncio` — `asyncio_mode = "auto"` in `pyproject.toml` would still let you, but these aren't async.
- **Mocking anthropic**: use `@patch("app.services.media_scoring.anthropic.Anthropic")` — patch where it's used, not where it's defined. Construct a `MagicMock()` for the client, a `MagicMock()` for `messages`, with `.create.return_value` having `.content[0].text` as a JSON string.
- **Mocking httpx in loc.py module-level function**: use `with patch("app.services.loc.httpx.Client") as mock_client:` — `get_best_image_url` constructs its own client; you must patch where `httpx` is imported.
- **Mocking the service `_api_request` method**: prefer `@patch.object(LOCService, "_api_request")` style — already established in `test_media_library.py:142`.
- **`test_db` fixture and rollback**: each test gets a fresh transaction that rolls back. For tests that need DB rows (upsert tests, `score_candidates` tests), use `test_db.add(...)` + `test_db.commit()` then run the function. Do NOT use `taxonomy_factory` / `article_factory` — they're unrelated; create `MediaCandidate` rows directly.
- **MediaCandidate required fields**: `source` (str), `external_id` (str), `external_url` (str), `title` (str). Everything else nullable. Use `CandidateStatus.PENDING.value` not the enum directly (the column is `String`).
- **Round numbers in oracle**: when asserting on float scores after clamping/rounding (source line 111), assert exactly the rounded value (`== 0.85`), not approximate equality.
- **`extract_series_header` behavior**: source line 57 says "if 'About this Article' in first_part **or** 'part' in first_part.lower()" — the `'part'` substring match is broad (matches "particle", "depart", etc.). Test the documented case; don't test edge cases that the source treats as a header but probably shouldn't.
- **`generate_slug` test for `"Ñandú"`**: source line 33 replaces `Ñ` with **lowercase** `"n"` (not `"N"`), and then line 36 lowercases the whole string. Expected output: `"nandu"`. If your read of the source disagrees, follow the source.
- **Time/UUID nondeterminism**: none of these functions use time or randomness. If a test ever needs `datetime.now(UTC)`, just construct one — no freezing required.
- **Lint**: run `docker-compose exec backend ruff check /app` and `ruff format /app`. The repo's ruff config (`pyproject.toml:20-42`) enforces `E, F, I, UP`. Tests ignore `F401` (unused imports) per the per-file-ignores. Match existing test imports style.
- **Test count target**: aim for ~10-15 tests per new file (small), ~6-10 per added class in `test_media_library.py`. Don't pad — every test should assert a specific behavior from the brief, not "exercise the path".
- **If a test would require a fixture you can't write trivially** (e.g., a full anthropic API response with all 50 fields): simplify the mock to the minimum that exercises the behavior under test. The oracle is the brief's enumerated behaviors, not exhaustive realism.
- **If something is genuinely ambiguous**: skip it, note it in the PR description, and surface for human review. Do NOT invent expected outputs by reading the implementation — that's the characterization-test trap.

## Failure-mode escape hatch

If the brief's primary path is blocked — the operation is structurally impossible, a required behavior of a service doesn't match what the brief asserts, or pinning down an oracle for a test would require a judgment call about correctness — STOP that specific test and open the PR as a **draft** with a comment describing exactly what's blocked. Partial coverage is better than wrong coverage. If `score_candidates`'s mocking is intractable, ship the slug/markdown tests and flag the others. A draft PR with an honest "covered A, B, C; blocked on D because X" comment is a good outcome; a green PR full of characterization tests is a worse one.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only the IN-scope files were modified (no edits to `backend/app/` files, no edits to `conftest.py`, no edits to `pyproject.toml`).
- [ ] No tests assert behavior that was derived by reading the implementation — every assertion's expected value is grounded in this brief.
- [ ] `docker-compose exec backend ruff check /app` is clean against the main baseline (no NEW issues in the test files).
- [ ] `docker-compose exec backend ruff format /app --check` passes.
- [ ] `docker-compose exec backend pytest backend/tests/test_slug.py backend/tests/test_markdown.py backend/tests/test_media_scoring.py backend/tests/test_media_library.py -v` runs to completion with all new tests passing (existing tests in `test_media_library.py` still green).
- [ ] Mocked external services: anthropic in `test_media_scoring.py`, `httpx.Client` in any `get_best_image_url` test, `WikimediaService._api_request` / `LOCService._api_request` for service-method tests. No test actually hits LOC or Wikimedia.
- [ ] No use of the `test_db` fixture for purely-pure-function tests (`test_slug.py`, `test_markdown.py`, `make_storage_key` tests, watermark tests, parser-helper tests with no DB write).
- [ ] PR description includes the **"Production touch: no — verified by:"** line.
- [ ] PR description names any tests that were planned-but-skipped, with a one-line reason.

## PR shape

- **Branch**: `fix/issue-195-pure-logic-test-coverage`
- **Title**: `test(#195): add coverage for media_scoring, loc/wikimedia parsers, markdown, slug`
- **Body must include**: a one-line summary; **"Production touch: no — verified by: test-only additions, no `app/` changes, mocks for anthropic/httpx/boto3."**; the self-review checklist with each item marked; a test plan listing the test files added/extended; `Closes #195`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise (failure-mode escape hatch).
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (test files + counts), and any flags you surfaced (skipped tests, bugs spotted but not fixed, ambiguity in service behavior that requires human review).

## Begin by

1. Read this issue (`gh issue view 195`) and the source files named above (`backend/app/services/media_scoring.py`, `loc.py`, `wikimedia.py`, `image_storage.py`; `backend/app/utils/markdown.py`, `slug.py`; `backend/tests/test_media_library.py`, `test_translation.py`, `conftest.py`); confirm the verified facts still hold.
2. Make sure backend services are up: `docker-compose up -d backend db`.
3. Create `backend/tests/test_slug.py` and run `docker-compose exec backend pytest backend/tests/test_slug.py -v`. Iterate until green.
4. Repeat for `test_markdown.py`, then `test_media_scoring.py`.
5. Extend `test_media_library.py` with the new classes; run the full file to confirm no regressions.
6. (Optional) Create `test_image_storage.py` for the pure helpers.
7. Run the full test suite once: `docker-compose exec backend pytest`. Iterate on any failures.
8. Run lint/format and fix any new issues.
9. Self-review checklist.
10. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
11. Report back and STOP.
