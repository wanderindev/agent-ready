# Fix brief — issue #79: [Quality] translation.py: hardcoded formality='default' + regex code-block protection fragile

## Identification

You are an autonomous agent resolving issue #79 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend, service-layer change. There are TWO independent fixes in one file, plus their tests. DeepL is an external service and is ALWAYS mocked in tests (see the existing `patch("app.services.translation.deepl.Translator")` pattern in `backend/tests/test_translation.py`) — never make a real DeepL call.

This is a test-only-runnable change (the translation unit tests use mocks, no DB, no testcontainer). Simplest path: run the tests natively or in the existing backend container. The canonical invocations:
- Lint: `docker-compose exec backend ruff check /app` (note: ruff is unpinned in this repo — CI uses latest; if you lint locally with a different ruff version, re-verify against a clean baseline so you don't introduce a NEW finding).
- Tests: `docker-compose exec backend pytest tests/test_translation.py`
- If the operator's dev stack is not already up and you need the container: use a dedicated compose project name (`docker-compose -p agent-issue-79 ...`) to avoid colliding with the operator's running stack on ports 5432/8000. But since these tests need neither DB nor live API, installing requirements locally and running `pytest tests/test_translation.py` natively is the lighter path — pick whichever is available and spell out what you did in the PR.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a mismatch.

## The task (verified facts)

File: `backend/app/services/translation.py` (158 lines). Note: the issue body's line numbers are off by ~1 from current source — use the line numbers below, which were verified this session.

### Fix 1 — expose `formality` as a typed parameter (currently hardcoded `"default"`)

Two hardcoded literals exist:
- Line 73: inside `_sync_translate_text` (def starts line 65), `formality="default",`
- Line 93: inside `_sync_translate_markdown` (def starts line 77), `formality="default",`

The public async methods are `translate_text` (line 29) and `translate_markdown` (line 42), which delegate to the `_sync_*` methods via `loop.run_in_executor(None, self._sync_translate_text, text)` (lines 39, 62).

Required change:
1. Add a module-level type alias near the top of the file (after the imports, before the class). `from typing import Literal` is the established idiom in this repo (e.g. `backend/app/schemas/subscribe.py:8`). Add:
   ```python
   Formality = Literal["default", "more", "less", "prefer_more", "prefer_less"]
   ```
2. Thread `formality: Formality = "default"` as a parameter through BOTH public methods (`translate_text`, `translate_markdown`) AND both private methods (`_sync_translate_text`, `_sync_translate_markdown`), passing it to the `deepl` `translate_text` call in place of the hardcoded `"default"`. Preserve `run_in_executor` — pass `formality` as an extra positional/keyword arg (use `functools.partial` or a lambda, OR add it as a positional after `text`/`markdown_content` in the `run_in_executor` call). Keep the signature backward compatible: default MUST remain `"default"` so all existing callers in `admin.py` and `dashboard.py` keep working unchanged.

### Fix 2 — make `_protect_code_blocks` regex tolerate attributes

`_protect_code_blocks` (def line 113, body lines 119-130) currently only matches bare `&lt;code&gt;` / `&lt;pre&gt;`:
```python
html = re.sub(r"&lt;code&gt;", '&lt;code class="notranslate"&gt;', html)
html = re.sub(r"&lt;pre&gt;", '&lt;pre class="notranslate"&gt;', html)
```
This misses `&lt;code class="language-python"&gt;` / `&lt;pre&gt;&lt;code class="hljs"&gt;` if the renderer ever emits attributes. Today the parser (`MarkdownIt("commonmark", {"html": True})`, line 27) emits bare tags so it works — this is a latent bug, not an active one.

Make both regexes match the tag with-or-without existing attributes and inject `class="notranslate"` while preserving any existing attributes. IMPORTANT — the issue body's proposed snippet has an ordering quirk: it injects the class BEFORE the existing attributes (`&lt;code class="notranslate"{attrs}&gt;`), which would put `class="notranslate"` next to a possibly-already-present `class="language-python"` producing a duplicate `class` attribute. Prefer injecting `class="notranslate"` AFTER the captured attributes (or de-duplicate). A correct, robust form:
```python
html = re.sub(
    r"&lt;code(\s[^&gt;]*)?&gt;",
    lambda m: f'&lt;code{m.group(1) or ""} class="notranslate"&gt;',
    html,
)
html = re.sub(
    r"&lt;pre(\s[^&gt;]*)?&gt;",
    lambda m: f'&lt;pre{m.group(1) or ""} class="notranslate"&gt;',
    html,
)
```
`_unprotect_code_blocks` (line 133) strips `' class="notranslate"'` via `.replace(...)`; placing ` class="notranslate"` as a discrete space-prefixed token keeps that cleanup working. Verify the unprotect still removes the injected token cleanly given your chosen form — adjust `_unprotect_code_blocks` only if your injection format changes the exact substring it removes (and if you change it, that is in-scope).

### Tests (must update + add)

`backend/tests/test_translation.py` already exists and is the test home. The existing test `test_translate_text_calls_deepl_with_correct_params` (line 11) asserts the EXACT DeepL call kwargs including `formality="default"` — your default-preserving change keeps it green; do NOT loosen it. Add:
- A test that passing `formality="less"` (or `"more"`) to `_sync_translate_text` / `_sync_translate_markdown` forwards it to the mocked DeepL `translate_text` call.
- A test that `_protect_code_blocks` adds `class="notranslate"` to a `&lt;code class="language-python"&gt;` / attributed `&lt;pre&gt;` tag WITHOUT producing a duplicate `class` attribute, and that `_unprotect_code_blocks` round-trips it back.
Mock DeepL exactly as the existing tests do.

## Scope

### IN scope
- `backend/app/services/translation.py` — the `Formality` alias, the 4 method signatures, the 2 DeepL `formality` args, the 2 regexes in `_protect_code_blocks`, and `_unprotect_code_blocks` only if your injection format requires it.
- `backend/tests/test_translation.py` — update the existing assertion expectations only where the new param requires, and add the new tests above.

### OUT of scope (do NOT touch)
- `backend/app/api/admin.py` and `backend/app/api/dashboard.py` — callers must NOT change. The whole point of the `"default"` default is that they keep working untouched. If you find yourself editing a caller, you have broken backward compatibility — stop and reconsider.
- The `MarkdownIt` parser config (line 27) — do NOT add syntax highlighting or change the renderer. Fix 2 is about making the regex robust, not changing what the renderer emits.
- `get_translation_service` / `lru_cache` (lines 147-157), `_clean_markdown`, and the round-trip flow structure — leave untouched.
- Do NOT switch to BeautifulSoup. The issue mentions it as an alternative; the regex approach is sufficient and lower-risk. Stay with regex.

## Default rules for likely ambiguities

- **Alias name:** `Formality`. **Allowed values:** `Literal["default", "more", "less", "prefer_more", "prefer_less"]` exactly (DeepL's supported set). **Default value everywhere:** `"default"`.
- **Param name:** `formality` (matches the existing DeepL kwarg name).
- **Param position:** add `formality: Formality = "default"` as the last parameter of each method, after the existing `text` / `markdown_content`.
- **run_in_executor threading:** `run_in_executor` takes the function then positional args. Pass `formality` either via `functools.partial(self._sync_translate_text, text, formality)` or by appending it as a positional arg: `run_in_executor(None, self._sync_translate_text, text, formality)`. Either is fine; prefer the positional-arg form (no new import) if `functools` isn't already imported. (`functools` IS already imported — line 11, `from functools import lru_cache` — so `partial` would need adding to that import; the bare positional form avoids it.)
- **Regex class-injection ordering:** inject `class="notranslate"` AFTER existing attributes to avoid duplicate `class` attributes (see Fix 2). Do not merge into an existing `class` value — a separate `class="notranslate"` attribute is what DeepL's notranslate behavior keys on and what `_unprotect_code_blocks` removes.
- **Don't over-engineer the regex:** matching `&lt;code(\s[^&gt;]*)?&gt;` is enough; you do not need to handle self-closing or uppercase tags (markdown-it emits lowercase).

## Failure-mode escape hatch

If the primary path is blocked (e.g., `run_in_executor` threading can't cleanly carry the param, or the regex change breaks the existing `test_code_blocks_protected_from_translation` test in a way you can't resolve in-scope), STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X" comment is a good outcome.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/services/translation.py` and `backend/tests/test_translation.py` modified — no caller files touched.
- [ ] `admin.py` / `dashboard.py` call sites still type-check and work unchanged (default `"default"` preserved).
- [ ] `Formality` alias added using `Literal`; both public + both private methods carry the param.
- [ ] Regex injects `class="notranslate"` without producing a duplicate `class` attribute; `_unprotect_code_blocks` round-trips cleanly.
- [ ] New tests added for formality forwarding and attributed-tag protection; existing `test_translate_text_calls_deepl_with_correct_params` still passes (or is updated only as the param strictly requires).
- [ ] DeepL is mocked in every test (no live calls).
- [ ] `docker-compose exec backend ruff check /app` clean vs main baseline (no NEW findings).
- [ ] `pytest tests/test_translation.py` green.
- [ ] PR description complete; production-touch line present.

## PR shape

- **Branch**: `fix/issue-79-translation-formality-and-codeblock-regex`
- **Title**: `fix(#79): expose DeepL formality param and make code-block protection regex attribute-tolerant`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: service-layer only, DeepL mocked, no DB/.env/deploy/auth/payment/PII"** line; the self-review checklist with each item marked; a test plan; `Closes #79`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 79`) and `backend/app/services/translation.py` + `backend/tests/test_translation.py`; confirm the verified facts (line 73 & 93 formality literals; `_protect_code_blocks` body at lines 119-130; `Literal` available via `typing`) still hold.
2. Make Fix 1 (formality param) and Fix 2 (regex), staying strictly within IN scope.
3. Update/add tests in `test_translation.py`.
4. Run `ruff check /app` and `pytest tests/test_translation.py`; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
