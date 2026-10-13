# Fix brief — issue #193: [Quality] Test coverage for edu/research content-generation services

## Identification

You are an autonomous agent resolving issue #193 in the `panama-in-context` repo. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- **Backend runs in Docker.** Run all pytest/ruff commands inside the backend container:
  - `docker-compose up -d backend db`
  - `docker-compose exec backend pytest tests/test_<new_file>.py -v`
  - `docker-compose exec backend ruff check /app`
  - `docker-compose exec backend ruff format /app`
- The full suite uses a `postgres:17-alpine` testcontainer (see `backend/tests/conftest.py`). Your new tests do not need DB access for the prompt-builder tests, but all tests that exercise a service which queries the DB should use the existing `test_db` fixture and factories (`category_factory`, `suggestion_factory`, `research_factory` — see `conftest.py:101-190`).
- **NEVER call live LLM APIs.** Mock `anthropic.Anthropic` clients per the canonical pattern in `tests/test_article_generation.py:20-26`. Mocking convention in this repo is `unittest.mock` (`MagicMock`, `patch`), not `pytest-mock`.
- This is the **oracle-rule** path from `docs/pilot/agent-friendly-criteria.md`: the brief enumerates the specific behaviors and expected outcomes to assert. Do **not** add tests for behaviors not enumerated below — those would be characterization tests that enshrine current behavior including bugs, which is worse than no test. If you see behavior in the source that you think deserves a test but is not in the enumeration below, flag it in the PR description as a follow-up, do not write the test.

## When this brief and the source disagree — the four shapes

Recognize which shape applies and respond accordingly:

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Add focused unit tests for the under-tested content-generation services and their pure-string prompt builders. **New test files only — do NOT modify any production code under `backend/app/`.**

### Canonical mocking pattern (mirror this verbatim)

From `backend/tests/test_article_generation.py:20-26`:

```python
def _mock_anthropic_response(text: str):
    """Create a mock Anthropic client that returns the given text."""
    mock_msg = MagicMock()
    mock_msg.content = [MagicMock(text=text)]
    mock_client = MagicMock()
    mock_client.messages.create.return_value = mock_msg
    return mock_client
```

For multi-call services (`edu_material_generation.generate_edu_materials` makes 3 calls per grade band: condense, outline, content), use the `side_effect` list pattern from `test_article_generation.py:210-217`:

```python
mock_client.messages.create.side_effect = [
    MagicMock(content=[MagicMock(text=CONDENSED_TEXT)]),
    MagicMock(content=[MagicMock(text=OUTLINE_TEXT)]),
    MagicMock(content=[MagicMock(text=CONTENT_TEXT)]),
]
```

You may copy this helper into a new module-level `_mock_anthropic_response` per test file (duplication is fine — do not create a shared helpers module).

### Patch targets (important — verified)

`_get_client()` is defined in `app.services.article_generation` and re-imported by `suggestion_generation.py` and `edu_material_generation.py`. **Patch the importing module's namespace, not the source module** (standard `unittest.mock` rule). So:

| Service under test | Patch target |
|---|---|
| `app.services.suggestion_generation` | `app.services.suggestion_generation._get_client` |
| `app.services.edu_material_generation` | `app.services.edu_material_generation._get_client` |
| `app.services.research_common` | `app.services.research_common._get_client` (it has its **own** module-local `_get_client` — verified at `research_common.py:13`) |
| `app.services.research_summary` | `app.services.research_summary.anthropic.Anthropic` — it does **not** use `_get_client`; it instantiates `anthropic.Anthropic(api_key=settings.anthropic_api_key)` directly inside the function (verified at `research_summary.py:32`). Patch the class constructor and return a `MagicMock` client. |

### Files to create and the behaviors each must assert

For every test below: the assertion is what the spec/contract dictates, not what the implementation happens to do. If you cannot derive the expected value from the brief alone, treat that as a brief gap — skip the test and flag it in the PR description rather than guessing from the implementation.

---

#### 1. `backend/tests/test_prompts.py` — pure string functions, no DB, no mocks

Cover all three prompt-builder modules. These are deterministic string assemblers — perfect for the oracle rule because the contract is the prompt's structural shape, not the LLM's response.

**`app/prompts/suggestion_generation.py::build_historical_suggestion_prompt`:**
- Returns a string containing the taxonomy name, category name, and `num_suggestions` value.
- When `existing_titles` is empty, the existing-articles section reads `(none yet)`.
- When `existing_titles` has entries, each appears as `- <title>` on its own line.
- When `taxonomy_description` is `None`, the placeholder `N/A` appears in the taxonomy-description line.
- Same for `category_description=None` → `N/A`.

**`app/prompts/image_generation.py::build_image_prompt`:**
- Returns a string containing the `title` verbatim.
- When `content` is ≤ 12000 chars, the full content appears in the output.
- When `content` is > 12000 chars, only the first 12000 chars appear (the cutoff at index 12000 — verify with a 12001-char input that char 12000 is absent and char 11999 is present).
- The string contains the literal phrase `Aspect ratio: 16:9 (landscape)` (a structural style anchor).

**`app/prompts/edu_material_generation.py`** — four builders, all pure strings:
- `_voice_for_band("3rd-6th")` returns the `3rd-6th` voice block.
- `_voice_for_band("unknown-band")` returns the `7th-8th` fallback (verify by string-equality against `GRADE_BAND_VOICE["7th-8th"]`).
- `_word_target_for_band` and `_condensed_target_for_band` behave the same way (known band → its value, unknown band → the `7th-8th` fallback `"1,500-2,500"` and `1200`).
- `build_edu_condense_prompt`:
  - Includes the `suggestion_title` and the target word count from `_condensed_target_for_band(grade_band)`.
  - When `sub_topics` is non-empty, includes a line `Key sub-topics to prioritize: <comma-joined>`.
  - When `sub_topics` is `None` or empty, does **not** include that line.
  - When `excursion_key` is set, includes `Excursion site: <key>`.
  - When `excursion_key` is `None`, does not include the excursion-site line.
- `build_edu_outline_prompt`:
  - Includes the literal `EXACTLY 6 sections` constraint (the prompt's structural anchor).
  - Includes the format anchor `TITLE:` and `---` separator instruction.
  - Includes a `SUB-TOPICS TO COVER:` section when `sub_topics` is non-empty; omits it otherwise.
- `build_edu_content_prompt`:
  - Includes the `title`, `grade_band`, the voice block, and the word target.
  - Includes the constraint string `Do NOT include a title heading`.
- `build_edu_slides_prompt`:
  - Includes the literal `10-15 slides` target.
  - Includes the literal `Separate each slide with` (the format anchor).
  - When `excursion_key` is set, includes `Excursion site: <key>`; omits the line when `None`.

---

#### 2. `backend/tests/test_research_summary.py`

Service is 43 lines, one public function `generate_research_summary(content: str) -> str`. Patch `app.services.research_summary.anthropic.Anthropic` to return a mock client whose `messages.create` returns a mock with `.content[0].text` set to a known string.

Behaviors to assert:
- Returns the text from the mocked LLM response.
- Calls `messages.create` with `model="claude-haiku-4-5-20251001"` (verified at `research_summary.py:7`).
- Calls `messages.create` with `system=SYSTEM_PROMPT` and a `messages` list whose user content includes the input `content`.

Also patch `app.services.research_summary.get_settings` (or feed a settings object) to avoid requiring a real `ANTHROPIC_API_KEY` env var.

---

#### 3. `backend/tests/test_research_common.py`

Service `app.services.research_common.validate_research_document`. The public contract is:

Returns a dict with keys `valid`, `word_count`, `content`, `checks`. `checks` has sub-keys `word_count`, `references`, `subtopic_coverage`.

Patch `app.services.research_common._get_client`. Where the service makes an LLM call (sub-topic coverage and references generation), use `side_effect` or `return_value` on the mock client's `messages.create`.

Behaviors to assert (each must be derived from the spec, not the implementation):

- **Word-count check**: when input has < 4000 words, returns `valid=False`, `checks.word_count=False`, and no LLM call is made (assert `mock_client.messages.create.assert_not_called()`).
- **References regex — present**: when content includes a header like `## References`, `checks.references=True` and `_generate_references_section` is **not** invoked (no auto-fix call).
- **References regex — multiple synonyms**: `## Sources`, `## Bibliography`, `## Works Cited`, `## Citations` all match (case-insensitive). One parametrized test per synonym or a single test cycling through them is fine.
- **References regex — absent + auto-fix succeeds**: when content has no references section, the service makes an additional LLM call that returns text starting with `## References`; the returned `content` ends with `\n\n---\n\n## References ...` and `checks.references=True`.
- **References regex — absent + auto-fix returns non-conforming text**: if the LLM's auto-fix response does NOT start with `## References` or `## Sources`, the original content is returned unchanged and `checks.references=False`.
- **Sub-topic coverage — no sub-topics**: when `sub_topics=None` or `[]`, the sub-topic coverage LLM call is skipped, `subtopic_ok=True`, and `checks.subtopic_coverage.passed=True` with `found=0`, `total=0`.
- **Sub-topic coverage — LLM returns valid JSON**: when LLM returns `{"subtopics_found": 3, "subtopics_total": 5}`, `checks.subtopic_coverage.found=3`, `total=5`, `passed=True` (threshold is `>= 2`, verified at `research_common.py:97`).
- **Sub-topic coverage — LLM returns 1 found**: `passed=False`.
- **Sub-topic coverage — LLM returns code-fenced JSON**: when LLM response is wrapped in ```` ```json ... ``` ````, the fences are stripped and parsing succeeds.
- **Sub-topic coverage — LLM returns malformed JSON**: `result = {}` fallback; `found=0`, `total=0`, `passed=False`.
- **`valid` is the conjunction**: `valid = refs_ok AND subtopic_ok`. Construct a content + sub_topics combo for each of the four boolean combinations and verify the `valid` field.

Use a helper to build content meeting the 4000-word minimum (e.g. `"word " * 4001`). For tests involving sub-topic coverage, the input format `["Title: Description", ...]` matches what `suggestion_generation` produces — use a small list like `["Topic A: description A", "Topic B: description B"]`.

---

#### 4. `backend/tests/test_suggestion_generation.py`

Service `app.services.suggestion_generation.generate_historical_suggestions`. This service exercises Anthropic extended thinking — the response has multiple content blocks (a `thinking` block and a `text` block); the service picks the first `text` block (`suggestion_generation.py:54`).

Use `test_db`, `taxonomy_factory`, `category_factory` fixtures. Patch `app.services.suggestion_generation._get_client`.

Mock-response structure (matches the extended-thinking shape):

```python
text_block = MagicMock()
text_block.type = "text"
text_block.text = json.dumps({"suggestions": [ {...}, ... ]})
thinking_block = MagicMock()
thinking_block.type = "thinking"
mock_msg = MagicMock()
mock_msg.content = [thinking_block, text_block]
```

Behaviors to assert:
- Returns a list of `ArticleSuggestion` rows, one per item in `result["suggestions"]`.
- Each row has `category_id` set to the input category's id.
- `sub_topics` is flattened to the string format `"Title: Description"` (verified at `suggestion_generation.py:63`). Pass `sub_topics: [{"title": "T", "description": "D"}]` in the mock response and assert the saved value is `["T: D"]`.
- The service handles a response with **only** a `text` block (no `thinking` block) — `next(b for b in ... if b.type == "text")` still works.
- The service calls `messages.create` with `thinking={"type": "enabled", "budget_tokens": 10_000}` and `model="claude-sonnet-4-6"` (verified at lines 13-15, 46-49).
- The service includes existing titles in its prompt (read the prompt arg from `mock_client.messages.create.call_args` and assert each pre-existing suggestion title appears).
- The service handles a JSON response wrapped in markdown code fences (mock returns ```` ```json {...} ``` ````, service strips the fences via `_strip_json_fences` and parses successfully).
- When `result["suggestions"]` is empty, returns `[]` and commits cleanly (no DB error).

---

#### 5. `backend/tests/test_edu_material_generation.py`

Two public functions: `generate_edu_materials` and `generate_edu_slides`. Patch `app.services.edu_material_generation._get_client`.

You will need `EduSuggestion`, `EduResearch`, `EduMaterial` records. The `conftest.py` factories do not cover these — use the existing factories' style and create them inline in the test (`test_db.add(...)` + `test_db.flush()`), or add module-level helpers in the new test file. Do **not** modify `conftest.py`.

`EduSuggestion` model fields (verify by reading `backend/app/models/edu_suggestion.py`): at minimum `title`, `description`, `sub_topics`, `grade_bands`, `excursion_key`.
`EduResearch` model fields (verify by reading `backend/app/models/edu_research.py`): at minimum `suggestion_id`, `content`, `status`.
`EduMaterial` fields (verify by reading `backend/app/models/edu_material.py`): `research_id`, `material_type`, `grade_band`, `title`, `content`, `status`.

Behaviors to assert for `generate_edu_materials`:

- **Loop over grade bands**: when `suggestion.grade_bands = ["3rd-6th", "7th-8th"]` and research is long (>2500 words to trigger condensation), the LLM is called **6 times total** (3 calls × 2 bands: condense, outline, content). Use `side_effect` with 6 entries.
- **Skips condensation when research is short**: when research is ≤ 2500 words (`CONDENSE_THRESHOLD`, verified at line 22), only **2 LLM calls per band** are made (outline, content) — no condense call. Assert call count.
- **Outline parsing — well-formed `TITLE: / --- / ...`**: when the outline LLM response is `"TITLE: My Title\n---\nOutline body"`, the saved material has `title="My Title"`.
- **Outline parsing — no TITLE prefix**: when the response has no `TITLE:` line, the saved material has `title=f"{suggestion.title} — {band}"` (fallback at `edu_material_generation.py:139-140`).
- **Outline parsing — TITLE only, no outline body**: returns `("title", "")` (verified at `_parse_outline_response:52-54`). The content phase is still invoked.
- **Upsert — creates when none exists**: returns a list of 1 new `EduMaterial` row per band, with `material_type="guide"`, `status="PENDING"`, `research_id` set.
- **Upsert — updates when existing material on `(research_id, "guide", band)`**: pre-create an `EduMaterial`, run the service, assert the same DB row is reused (same `id`), with `content` overwritten and `status` reset to `"PENDING"`.
- **`grade_bands` is `None` or `[]`**: returns `[]`, no LLM calls (verified at line 112: `grade_bands = suggestion.grade_bands or []`).

Behaviors to assert for `generate_edu_slides`:

- **Single LLM call**: one Sonnet call (no outline phase — comment at line 201 confirms). Assert call count = 1.
- **Title format**: the saved slides material has `title = f"{guide_material.title} — Slides"`.
- **Upsert on `(research_id, "slides", grade_band)`**: same insert/update behavior as `generate_edu_materials`.
- **Raises `ValueError` when `guide_material.research.suggestion is None`** (verified at line 207-208). Construct a guide whose research has no suggestion FK (or whose `research` attribute is `None`) and assert `pytest.raises(ValueError)`.

You can also unit-test `_parse_outline_response` directly (it is module-level and pure) — that's the cleanest way to cover the parsing branches without invoking the full pipeline.

---

#### 6. `backend/tests/test_edu_admin.py`

`app/api/edu.py` is **920 lines** and **admin-side CMS only** (verified — no educator/excursion PII; routes are CRUD on edu suggestions, research, and materials, plus upload/download/thumbnail). The router is admin-gated (uses `validate_admin_token`).

The full router is too large to cover in one PR. **Scope this file to the lowest-risk read/CRUD endpoints**:

- `GET /api/v1/edu/suggestions` (list)
- `GET /api/v1/edu/suggestions/{id}` (detail)
- `PATCH /api/v1/edu/suggestions/{id}/status` (status update)
- `PUT /api/v1/edu/suggestions/{id}` (update)
- `GET /api/v1/edu/research` (list)
- `PATCH /api/v1/edu/research/{id}/status` (status update)
- `GET /api/v1/edu/materials` (list)
- `PATCH /api/v1/edu/materials/{id}/status` (status update)

For each: one happy-path test (returns 200, expected shape) and one error test (404 for missing id; 400 for invalid status if the endpoint validates). Mirror the admin-auth bypass pattern from `test_article_generation.py:29-35`:

```python
@pytest.fixture(autouse=True)
def _bypass_admin_auth():
    with patch("app.api.dashboard.validate_admin_token", return_value=_FAKE_ADMIN):
        yield
```

— but verify the actual patch target for `edu.py` (it may be `app.api.edu.validate_admin_token` if the router imports the function directly). Inspect the top of `app/api/edu.py` to confirm. If the import shape differs, adjust the patch target accordingly and note it in the PR description.

**Explicitly OUT of scope** for this PR (file follow-up issues if you have time):
- `POST /upload-research` (multipart upload — needs file-storage mocking)
- `GET /research/{id}/download` and `GET /materials/{id}/download` (storage download)
- `POST /materials/generate` and `POST /slides/generate` (these wrap the services covered above; integration test would duplicate coverage)
- `_generate_material_thumbnail` (Pillow/PyMuPDF — separate concern)

The contract you assert against each endpoint is: the response shape promised by the `response_model` (e.g. `EduSuggestionListItem`, `EduResearchListItem`). Read the Pydantic schemas in `app/schemas/` to derive the expected field set. Do **not** assert against arbitrary DB-derived field values that aren't in the schema.

---

### Coverage measurement (optional, informational only)

After your tests pass, you may run `docker-compose exec backend pytest --cov=app/services/research_common --cov=app/services/research_summary --cov=app/services/suggestion_generation --cov=app/services/edu_material_generation --cov=app/prompts --cov-report=term-missing tests/test_research_common.py tests/test_research_summary.py tests/test_suggestion_generation.py tests/test_edu_material_generation.py tests/test_prompts.py` to see the new coverage. **Do not chase a coverage percentage target** — chasing coverage produces the characterization-test failure mode the oracle rule warns against. The contract is "the enumerated behaviors are asserted," not "X% covered."

## Scope

### IN scope
- New file: `backend/tests/test_prompts.py`
- New file: `backend/tests/test_research_summary.py`
- New file: `backend/tests/test_research_common.py`
- New file: `backend/tests/test_suggestion_generation.py`
- New file: `backend/tests/test_edu_material_generation.py`
- New file: `backend/tests/test_edu_admin.py`

### OUT of scope (do NOT touch)
- **No production code changes** under `backend/app/`. If a service's structure makes it hard to test (e.g. `research_summary.py` not using `_get_client`), the brief tells you to patch around it — do not refactor the service. File a follow-up issue if you spot a refactor that would improve testability.
- `backend/tests/conftest.py` — do NOT add Edu-related factories there. Define helpers locally in `test_edu_material_generation.py`. (The blog-side factories `category_factory`, `suggestion_factory`, `research_factory` already exist there and are fine to use.)
- Existing tests (`test_articles.py`, `test_article_generation.py`, `test_translation.py`, etc.) — do not modify.
- `app/api/edu.py` paths excluded above (upload, download, generate, thumbnail) — file follow-ups if you want.
- `app/services/article_generation.py` — already has tests; do not duplicate.
- Live LLM calls — under no circumstances. CLAUDE.md mandates mocking.
- Schema migrations, Alembic, env vars, deploy config.
- The educator access gate, contact form, PayPal, auth — none are involved in this issue.

## Default rules for likely ambiguities

1. **Test file naming**: one test file per service module / one per router area; mirror existing names (`test_<module_name>.py`).
2. **Test class organization**: use `class TestX:` to group related tests by behavior cluster (matches `test_article_generation.py:TestGenerateOutlines`, etc.). Not strictly required but consistent.
3. **Fixture choice**: use `test_db`, `category_factory`, `suggestion_factory`, `research_factory` from `conftest.py`. For Edu models, define helpers inline at the top of `test_edu_material_generation.py` and `test_edu_admin.py`.
4. **Mock style**: `unittest.mock.patch` as a decorator on each test method (matches canonical pattern). Do not introduce `pytest-mock` / `mocker` fixture — not used elsewhere.
5. **Patch target**: always patch the symbol in the module that **uses** it, not where it's defined. The verified targets are in the table above.
6. **Settings/env**: where a service calls `get_settings()` to retrieve `anthropic_api_key`, either patch `app.services.<module>.get_settings` to return a settings object with a dummy key, OR (simpler) patch the LLM client class/factory above the `get_settings` call so settings never matters. Prefer the simpler approach.
7. **JSON content in mocks**: when a service expects JSON in the LLM response, build the JSON with `json.dumps({...})` rather than hand-writing string literals (matches `test_article_generation.py:38-47`).
8. **Multi-call services**: use `side_effect=[...]` for sequential calls in a single service invocation (matches `test_article_generation.py:212-216`).
9. **Word count helpers for `research_common`**: `"word " * 4001` is a 4001-word string; use that as the >4000-word baseline. For the references regex tests, append `\n\n## References\n- Source 1\n` after the body.
10. **Empty/None handling**: when the spec says a field can be `None`, test both `None` and `[]` (for list fields) — they may follow different code paths.
11. **Long content for `edu_material_generation`**: to trigger condensation (>2500 words), use `"word " * 2501`. To skip it, use `"word " * 100`.
12. **Adjacent code you might be tempted to test but shouldn't**: anything not in the enumerations above. If you see uncovered branches in the source that the brief did not enumerate, list them in the PR description as follow-ups — do not write tests by reading the implementation. That's the oracle-rule failure mode.
13. **Pydantic schema assertions in `test_edu_admin.py`**: assert against the **schema's field set**, not full DB content. E.g., assert that `response.json()[0]` has keys matching `EduSuggestionListItem.model_fields`, not that a specific row contains a particular value.
14. **If a test reveals a real bug** (e.g. the service returns a result that violates the documented spec): per the disagreement taxonomy above, do NOT fix the bug — file a separate issue, mark the test `@pytest.mark.xfail(reason="bug #<num>", strict=True)`, and surface it in the PR description.
15. **Do not import live `anthropic` / `openai` clients in tests.** The import in the service module is fine because the constructor is patched, but do not add real SDK imports to your test files.

## Failure-mode escape hatch

If you find:
- A service's behavior cannot be derived from the spec/docstring alone (the test would have to read the implementation to know what to assert) — skip that test, list it in the PR description as a brief gap.
- A model field referenced in the brief doesn't exist or has a different type — note the drift and adjust; the brief was verified against the services, not exhaustively against the models.
- Total LLM-mocking complexity exceeds what fits a reasonable session — open the PR as a **draft** with whichever test files are complete and a comment listing what's deferred. A partial-but-correct PR is far better than a complete-but-wrong one.

Open the PR as draft if any of those apply.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only new files under `backend/tests/` were added; no files in `backend/app/` were modified (`git diff --stat main` confirms).
- [ ] All new tests pass: `docker-compose exec backend pytest tests/test_prompts.py tests/test_research_summary.py tests/test_research_common.py tests/test_suggestion_generation.py tests/test_edu_material_generation.py tests/test_edu_admin.py -v` exits 0.
- [ ] Full suite still passes: `docker-compose exec backend pytest` exits 0 (no regression in existing tests).
- [ ] Lint clean against the baseline: `docker-compose exec backend ruff check /app` does not report new issues introduced by your files; `docker-compose exec backend ruff format /app --check` passes on your new files.
- [ ] **No live LLM calls**: every test that exercises a service patches the LLM client / `_get_client` / `anthropic.Anthropic` — `grep -L "patch\|mock" tests/test_research_*.py tests/test_suggestion_generation.py tests/test_edu_material_generation.py` returns nothing.
- [ ] Every test assertion is derived from the brief's enumerated behaviors, not from reading the implementation source.
- [ ] No new fixtures added to `conftest.py`; Edu helpers live inside the test files that use them.
- [ ] PR description complete, including the **"Production touch: no — verified by:"** line, the self-review checklist with each item marked, and an explicit list of any briefs gaps / xfails / follow-ups.

## PR shape

- **Branch**: `fix/issue-193-edu-research-service-tests`
- **Title**: `test(#193): add unit tests for edu/research content-generation services`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: only new files under `backend/tests/`; no `backend/app/` diffs"** line; the self-review checklist with each item marked; a test plan listing the new test files and how to run them; a "deferred / follow-ups" section listing any behaviors you intentionally did not test (per the oracle rule) and any router endpoints in `edu.py` you scoped out; `Closes #193`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise (failure-mode escape hatch).
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (test files created + behaviors covered + any xfail-marked bug-revealers), and any flags you surfaced (brief gaps, deferred behaviors, sub-cases not anticipated). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted (the operator updates the outcome after review).

## Begin by

1. Read this issue (`gh issue view 193`) and the files named in "The task" above; confirm the verified facts still hold. In particular, open `app/services/research_summary.py`, `research_common.py`, `suggestion_generation.py`, `edu_material_generation.py`, and `app/prompts/*.py` and confirm the patch targets and function signatures match what's stated above.
2. Read `backend/tests/test_article_generation.py:1-100` to internalize the canonical mocking pattern.
3. Read `docs/pilot/agent-friendly-criteria.md` § "Test-writing tasks: the oracle rule" to internalize the constraint that you must NOT assert behaviors not enumerated in this brief.
4. Read the Edu model files (`backend/app/models/edu_suggestion.py`, `edu_research.py`, `edu_material.py`) before writing `test_edu_material_generation.py` to confirm field names.
5. Read the top of `app/api/edu.py` to confirm the admin-token patch target before writing `test_edu_admin.py`.
6. Write the new test files in the order: `test_prompts.py` → `test_research_summary.py` → `test_research_common.py` → `test_suggestion_generation.py` → `test_edu_material_generation.py` → `test_edu_admin.py`. The first three have no DB dependency and are the safest warm-up.
7. Run lint/tests as named in the self-review checklist; iterate until clean.
8. Self-review checklist.
9. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
10. Append outcomes-log row.
11. Report back and STOP.
