# Fix brief — issue #77: [Quality] LLM response parsing is inconsistently defensive across services

## Identification

You are an autonomous agent resolving issue #77 in the panama-in-context codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- Backend Python (FastAPI + SQLAlchemy). All commands run in Docker per CLAUDE.md.
- The operator's main checkout at `/home/javier/vc/panama-in-context` likely has the dev stack running (ports 5432/8000). This issue is TEST-ONLY for verification — there is no live API access needed and no migration. Do NOT run `docker-compose up` from your worktree (port conflicts + it would mount the main checkout's code, not yours).
- Run lint and tests with a dedicated compose project name so you never attach to the operator's containers. From your worktree root:
  - Lint: `docker-compose -p agent-issue-77 run --rm --no-deps backend ruff check /app && docker-compose -p agent-issue-77 run --rm --no-deps backend ruff format --check /app`
  - Tests: `docker-compose -p agent-issue-77 run --rm backend pytest tests/test_article_generation.py tests/test_suggestion_generation.py tests/test_research_common.py tests/test_media_scoring.py`
  - If `run --rm backend pytest` cannot reach the testcontainer/docker socket, add `--user 0:0`. If compose is still unworkable, fall back to installing `backend/requirements.txt` natively and running `pytest` against a testcontainer — pick whichever works and note it in the PR.
- **LLM providers MUST be mocked in tests.** Never make a real Anthropic call. The existing tests already mock `_get_client`; follow their pattern exactly (see Default rules).
- `ruff` is unpinned in this repo (CI uses latest); make sure your changes are clean under the container's ruff, which is the binding check.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

The issue is that LLM JSON parsing is defensive at some service sites and not others. You will make the inconsistent sites consistent by introducing ONE shared helper and migrating exactly 3 unguarded sites to use it.

### Issue-body-vs-source drift (the source wins — corrected here)

- The issue body claims guarded `json.loads` exists at `research.py:164-168` and `edu_research.py:166-170`. **This is false.** Neither `research.py` nor `edu_research.py` calls `json.loads` — they only `return message.content[0].text`. The real guarded JSON-parse exemplar is `backend/app/services/research_common.py:84-93`.
- The issue body's "Desired state" proposes wrapping `messages.create(...)` in `try/except anthropic.APIError` and putting a helper in a new `llm.py` "per #76". **The `llm.py` wrapper does not exist and #76 is a separate issue. Do NOT wrap the `messages.create` call, do NOT add retry logic, and do NOT create `llm.py`.** That is OUT of scope. This issue is ONLY about defensive *response parsing*.

### Canonical pattern to mirror

- Defensive JSON parse exemplar: `backend/app/services/research_common.py:84-93` — fence-strip, then `try: result = json.loads(raw) except (json.JSONDecodeError, IndexError): result = {}`.
- Fence-stripping helper already in repo: `_strip_json_fences` at `backend/app/services/article_generation.py:33-39`.

### The change — add a shared helper, migrate 3 sites

**Step 1 — add a shared helper to `backend/app/services/research_common.py`** (it already imports `json` and `re` and is the shared module both blog and edu pipelines import from). Add:

```python
def parse_llm_json(message, *, required_key: str | None = None) -> dict | list:
    """Defensively parse JSON from an Anthropic message.

    Extracts the first text block, strips markdown fences, and parses JSON.
    Raises ValueError (not IndexError/JSONDecodeError/KeyError/StopIteration)
    on any failure so callers get one predictable, retry-friendly exception.
    """
    content = getattr(message, "content", None) or []
    if not content:
        raise ValueError("LLM returned no content blocks")
    text_blocks = [b for b in content if getattr(b, "type", "text") == "text"]
    block = text_blocks[0] if text_blocks else content[0]
    raw = block.text
    raw = raw.strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```\w*\n?", "", raw)
        raw = re.sub(r"\n?```$", "", raw).strip()
    try:
        result = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"LLM returned malformed JSON: {e}") from e
    if required_key is not None and (
        not isinstance(result, dict) or required_key not in result
    ):
        raise ValueError(f"LLM response missing required key {required_key!r}")
    return result
```

Notes on the design (these are deliberate — see Default rules for the reasoning):
- It uses the `getattr(b, "type", "text") == "text"` filter with a `content[0]` fallback, **not** a strict `b.type == "text"` filter, to stay compatible with the existing `article_generation` test mocks (which create `MagicMock(text=...)` with no `.type`) AND to skip real `thinking` blocks in `suggestion_generation` (which have `.type == "thinking"`). The fence-strip is inlined (duplicating `_strip_json_fences`) so the helper is self-contained in `research_common.py`; do NOT import `_strip_json_fences` from `article_generation.py` (that would create a back-import — `suggestion_generation.py` already imports from `article_generation`, keep dependency direction clean).

**Step 2 — migrate `backend/app/services/article_generation.py:69-71`** (`generate_outlines`). Replace:
```python
    raw = _strip_json_fences(message.content[0].text)
    result = json.loads(raw)
    return result["articles"]
```
with:
```python
    result = parse_llm_json(message, required_key="articles")
    return result["articles"]
```
Add `from app.services.research_common import parse_llm_json` to the imports.

**Step 3 — migrate `backend/app/services/article_generation.py:200-201`** (`generate_tags` / tagging). Replace:
```python
    raw = _strip_json_fences(message.content[0].text)
    result = json.loads(raw)
```
with:
```python
    result = parse_llm_json(message)
```
(No `required_key` here — downstream uses `result.get("assign", [])` / `result.get(...)`, so missing keys are already tolerated. Keep the `result.get(...)` calls as-is.)

**Step 4 — migrate `backend/app/services/suggestion_generation.py:54-56`**. Replace:
```python
    text_block = next(b for b in message.content if b.type == "text")
    raw = _strip_json_fences(text_block.text)
    result = json.loads(raw)
```
with:
```python
    result = parse_llm_json(message, required_key="suggestions")
```
**Important sub-case:** this site currently filters for the text block because the response contains a `thinking` block BEFORE the text block (extended thinking is enabled here — verify `thinking={"type": "enabled", ...}` is set at the `messages.create` call before relying on this). The helper's `getattr(b, "type", "text") == "text"` filter (Step 1) handles exactly this — it skips the `thinking` block and picks the text block, while still treating a type-less mock as text. Verify against source that thinking is enabled; if it is NOT, flag in the PR.

After this change `suggestion_generation.py` no longer uses `_strip_json_fences`; remove it from the `from app.services.article_generation import _get_client, _strip_json_fences` import (leave `_get_client`). Add `from app.services.research_common import parse_llm_json`.

### Tests to update/add

- `backend/tests/test_suggestion_generation.py` already builds mocks with `block.type = "text"` and a `thinking` block — these stay green with the new helper. Add a test that a malformed-JSON response (e.g. mock returns `"not json"`) raises `ValueError` (not `JSONDecodeError`), and one that a missing `"suggestions"` key raises `ValueError`.
- `backend/tests/test_article_generation.py` uses `MagicMock(text=...)` with NO `.type` — the helper's `getattr(b, "type", "text")` default keeps these green. Do NOT change the existing mock helper. Add a test for `generate_outlines` that a missing `"articles"` key raises `ValueError`, and one that malformed JSON raises `ValueError`.
- Add at least one direct unit test of `parse_llm_json` in `backend/tests/test_research_common.py` covering: empty content → ValueError; fenced JSON parsed correctly; malformed JSON → ValueError; `required_key` missing → ValueError.

## Scope

### IN scope
- `backend/app/services/research_common.py` — add `parse_llm_json` helper.
- `backend/app/services/article_generation.py` — migrate 2 sites (lines ~69-71 and ~200-201); add import.
- `backend/app/services/suggestion_generation.py` — migrate 1 site (lines ~54-56); fix imports.
- `backend/tests/test_research_common.py`, `backend/tests/test_article_generation.py`, `backend/tests/test_suggestion_generation.py` — add the tests named above.

### OUT of scope (do NOT touch)
- `backend/app/services/research_common.py:84-93` — already-conformant exemplar; leave the inline parse as-is (do NOT refactor it to call the new helper; its failure semantics return `{}`, which is intentional for that callsite).
- `backend/app/services/media_scoring.py` — already wrapped in a broad `try/except Exception` (lines 84-122); leave entirely alone.
- `backend/app/services/edu_material_generation.py` — its outline parse (`_parse_outline_response`, line 137) is a plain-text TITLE:/--- parser, NOT JSON; its other `messages.create` sites return `.text` only. Do NOT touch.
- `backend/app/services/research.py`, `edu_research.py`, `image_prompt.py`, `research_summary.py` — these only return `message.content[0].text` (no JSON parse to make defensive). Do NOT touch.
- The `messages.create(...)` API calls themselves — do NOT wrap them in try/except, do NOT add retries, do NOT create `llm.py`. That is issue #76's territory.
- Do NOT change `_strip_json_fences` in `article_generation.py` or remove it (it may still be referenced; verify before any removal — it is used by `generate_outlines`/`generate_tags` only via the lines you are replacing, but leave the function defined since it's a small public-ish helper and out of scope to delete).

## Default rules for likely ambiguities

- **Helper location**: `research_common.py`, not a new file. It is the shared module both pipelines already import.
- **Helper return**: parsed value (`dict | list`); raise `ValueError` on every failure mode. Do NOT return `{}` (the `research_common.py:84` exemplar returns `{}` because its caller uses `.get()` with defaults; the 3 migration sites instead require keys / use the value directly, so a raised `ValueError` is the right normalization).
- **Exception type to raise**: `ValueError` only. Catch `json.JSONDecodeError`; convert empty-content and missing-key into `ValueError`. Do NOT let `IndexError`, `KeyError`, or `StopIteration` escape the helper.
- **`.type` filtering vs `content[0]`**: use the `getattr(b, "type", "text") == "text"` filter with `content[0]` fallback (shown in Step 1). This is the single design that satisfies BOTH the type-less `article_generation` mocks AND the thinking-block `suggestion_generation` case.
- **Logging**: do NOT add a module logger or log statements in the helper — raising `ValueError` with a descriptive message is sufficient and matches the issue's "retry-friendly normalization" intent. (The exception propagates to the request handler and Sentry, which is the existing behavior.) If you feel logging is warranted, keep it to a single `logger.warning` only at a callsite you already touch, and flag it in the PR.
- **`required_key`**: pass `"articles"` for outlines, `"suggestions"` for suggestions, and none for tagging (tagging uses `.get()`).
- **Test mocks**: mirror the existing `_mock_anthropic_response` helpers in each test file. For malformed-JSON tests, pass a non-JSON string as the mock `.text`. Use `pytest.raises(ValueError)`.

## Failure-mode escape hatch

If the primary path is blocked — e.g. the `suggestion_generation` thinking-block assumption doesn't hold against source, or tests reveal the helper signature can't satisfy a callsite — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Implementing a partial-but-correct subset (e.g. migrating the 2 article_generation sites and documenting why suggestion_generation was deferred) is an acceptable draft outcome; a non-draft PR that silently broke a callsite is not.

## Self-review checklist (before opening the PR)

- [ ] Only the 6 in-scope files modified (3 services + 3 tests); no OUT-of-scope file touched.
- [ ] `parse_llm_json` added to `research_common.py`; raises `ValueError` on empty content, malformed JSON, and missing `required_key`.
- [ ] All 3 migration sites use the helper; `suggestion_generation.py` no longer imports `_strip_json_fences`.
- [ ] No `messages.create` call was wrapped; no `llm.py` created; no retry logic added.
- [ ] New tests added in all 3 test files; LLM client mocked (no real Anthropic call).
- [ ] `docker-compose -p agent-issue-77 run --rm --no-deps backend ruff check /app` clean (no NEW issues vs main); `ruff format --check` clean.
- [ ] Target test files pass: `test_article_generation.py test_suggestion_generation.py test_research_common.py test_media_scoring.py`.
- [ ] PR description complete with the production-touch line.
- [ ] Production touch: no.

## PR shape

- **Branch**: `fix/issue-77-defensive-llm-json-parse`
- **Title**: `fix(#77): add shared parse_llm_json helper and make LLM parsing defensive`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (admin-only content-gen services, no prod DB/auth/payment/PII/deploy; LLM mocked in tests); the self-review checklist with each item marked; a test plan; the issue-body-vs-source drift note (the false `research.py`/`edu_research.py` line refs and the deferred `messages.create`-wrapping / `llm.py` to #76); `Closes #77`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 77`) and the files named in "The task"; confirm the verified facts still hold — especially that `suggestion_generation.py` enables `thinking` and that `article_generation` test mocks lack a `.type` attribute (these drive the helper design).
2. Add `parse_llm_json` to `research_common.py`.
3. Migrate the 3 sites, staying strictly within IN scope; fix imports.
4. Add the tests.
5. Run ruff + the 4 target test files per Operational notes; iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
