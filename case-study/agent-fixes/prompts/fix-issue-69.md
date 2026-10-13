# Fix brief — issue #69: image_storage.download_image enforces 20MB cap AFTER reading full response into memory

## Identification

You are an autonomous agent resolving issue #69 in the Panama In Context codebase (main checkout: /home/javier/vc/panama-in-context). You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend Python change in `backend/app/services/image_storage.py`.

- **Lint/format** (must pass before opening PR), run inside the dev container:
  - `docker-compose exec backend ruff check /app`
  - `docker-compose exec backend ruff format /app`
  - Note: ruff is unpinned in this project (`ruff>=0.1.9`); CI uses the latest. If you cannot reach the dev container from your worktree, install requirements locally and run `ruff check backend/app/services/image_storage.py` natively. Either way, lint must be clean with no NEW issues vs the main baseline.
- **Tests**: this fix is unit-testable without docker-compose. Install backend requirements locally (or use the dev container) and run pytest natively against the single test file. You do NOT need the database container or live API access for this change.
  - In-container: `docker-compose exec backend pytest tests/test_image_storage.py`
  - Native alternative: `pytest backend/tests/test_image_storage.py`
- **External HTTP MUST be mocked.** Never make a real network call to LOC, Wikimedia, or any host in a test. Use a mocked/stubbed `httpx` streaming response (e.g. patch `httpx.Client` / `client.stream`, or use a fake response object whose `iter_bytes()` yields controlled chunks). The existing test file already avoids network-touching helpers; preserve that discipline.
- **Production touch: none.** This is pure in-memory download hardening — no prod DB, no `.env`, no auth/payment/PII, no deploy. The `code-quality:critical` label is about worker-OOM stability, not a data path. Do not touch any production resource.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

In `backend/app/services/image_storage.py`:
- Line 18: `MAX_DOWNLOAD_SIZE = 20 * 1024 * 1024` (the 20 MB cap constant — reuse it, do NOT redefine or change the value).
- Lines 38-59: `download_image(self, url: str) -> tuple[bytes, str]`. Current (broken) body:
  ```python
  with httpx.Client(timeout=60, follow_redirects=True) as client:
      response = client.get(
          url,
          headers={"User-Agent": "PanamaInContext/1.0 (diego@panamaincontext.com)"},
      )
      response.raise_for_status()

      if len(response.content) > MAX_DOWNLOAD_SIZE:                       # <-- too late
          raise ValueError(f"Image too large: {len(response.content)} bytes")

      content_type = response.headers.get("content-type", "image/jpeg")
      content_type = content_type.split(";")[0].strip()

      return response.content, content_type
  ```
  The bug: `response.content` has already loaded the entire body into memory before the cap is checked. A multi-hundred-MB response OOMs the worker regardless of the cap.

**The fix** — stream the response with `httpx`'s `client.stream(...)` context manager, accumulate chunks via `iter_bytes()`, and raise as soon as the cap is exceeded (aborting mid-stream so the full body is never buffered):

```python
with httpx.Client(timeout=60, follow_redirects=True) as client:
    with client.stream(
        "GET",
        url,
        headers={"User-Agent": "PanamaInContext/1.0 (diego@panamaincontext.com)"},
    ) as response:
        response.raise_for_status()

        # Cheap pre-flight: trust an honest Content-Length if present.
        content_length = response.headers.get("content-length")
        if content_length is not None:
            try:
                if int(content_length) > MAX_DOWNLOAD_SIZE:
                    raise ValueError(f"Image too large: {content_length} bytes")
            except ValueError as exc:
                # Re-raise our own size error; ignore an unparseable header.
                if "Image too large" in str(exc):
                    raise

        chunks = bytearray()
        for chunk in response.iter_bytes():
            chunks.extend(chunk)
            if len(chunks) > MAX_DOWNLOAD_SIZE:
                raise ValueError(f"Image too large: at least {len(chunks)} bytes")

        content_type = response.headers.get("content-type", "image/jpeg")
        content_type = content_type.split(";")[0].strip()

        return bytes(chunks), content_type
```

Notes on the fix:
- Keep the `User-Agent` header string byte-for-byte identical.
- Keep `timeout=60, follow_redirects=True` unchanged.
- The streaming guard (the `for chunk in response.iter_bytes()` loop) is the load-bearing enforcement — it must stay even if you keep the Content-Length pre-check, because Content-Length can be absent or lie. Do NOT rely on the pre-check alone.
- **Return contract is preserved and load-bearing:** the function must still return `tuple[bytes, str]`. Return `bytes(chunks)` (convert the `bytearray` to `bytes`) — NOT a `bytearray`. The only caller, `download_and_upload` (line 152, same class), unpacks `image_bytes, content_type = self.download_image(source_url)` and later calls `len(image_bytes)` and passes the bytes to `upload_image` / `generate_thumbnail`; a `bytes` value satisfies all of those.
- Error type on overflow stays `ValueError` (matches the existing error contract; the docstring says "Raises ValueError if the download fails or exceeds size limit"). The message format `f"Image too large: ... bytes"` is preserved in spirit; use `at least {len(chunks)} bytes` for the streaming case since the true size is unknown once aborted.
- Leave the docstring (lines 39-44) as-is; it remains accurate.

If you judge the Content-Length pre-check adds more complexity than value, you MAY omit it and ship only the streaming guard — that alone fully fixes the issue. If you keep it, keep it simple and never let it replace the streaming guard. State which you chose in the PR description.

**Issue-body-vs-source drift: none.** Every line number, the constant value (20 MB), the cap-check location (line 52, post-`response.content`), and the HTTP client (`httpx`) were verified against current source and match the issue body exactly.

## Scope

### IN scope
- `backend/app/services/image_storage.py` — function `download_image` (lines 38-59) ONLY.
- `backend/tests/test_image_storage.py` — ADD a unit test for the new size guard (see Default rules). This is the only sanctioned edit to the test file.

### OUT of scope (do NOT touch)
- `MAX_DOWNLOAD_SIZE` value (line 18) — do not change it.
- `upload_image`, `generate_thumbnail`, `download_and_upload`, `make_storage_key`, `watermark_infographic`, `watermark_slides`, or any other function in `image_storage.py`.
- `backend/app/services/loc.py` and any Wikimedia/LOC fetching code — the issue mentions LOC's 10 MB metadata check as *context*, not as a fix target.
- The function signature `download_image(self, url: str) -> tuple[bytes, str]` and the docstring — preserve both.
- The existing tests in `test_image_storage.py` (TestMakeStorageKey and watermark tests) and the file's top-of-file "DO NOT test download_image..." docstring note — you MAY add a focused size-guard test, but do not delete or rewrite existing tests, and do not refactor the existing helpers.

## Default rules for likely ambiguities

- **Cap constant**: reuse the module-level `MAX_DOWNLOAD_SIZE`; do not inline `20 * 1024 * 1024`.
- **Error on overflow**: raise `ValueError` (same type the function already documents/raises). Message: `f"Image too large: at least {len(chunks)} bytes"` for the streamed case.
- **Return value**: `bytes(chunks)` — a `bytes` object, never a `bytearray`.
- **httpx API**: use `client.stream("GET", url, headers=...)` as a context manager (`with ... as response:`), then iterate `response.iter_bytes()`. Call `response.raise_for_status()` inside the `stream` context before iterating. (This is the correct httpx streaming idiom; the project pins `httpx` already imported at line 9.)
- **Header preservation**: User-Agent header value stays `"PanamaInContext/1.0 (diego@panamaincontext.com)"`.
- **Content-Length pre-check**: optional (see The task). If kept, must not be the sole guard.
- **New test shape**: add a test (e.g. `class TestDownloadImageSizeGuard`) that patches/mocks `httpx.Client` so `client.stream(...)` yields a fake response whose `iter_bytes()` returns chunks summing to more than `MAX_DOWNLOAD_SIZE`, and asserts `download_image` raises `ValueError`. Optionally a happy-path test with a small payload returning `(bytes, content_type)`. MUST mock — zero real network. Keep the test small; do not introduce new heavy test dependencies (no `respx`/`responses` unless already in `requirements`; a plain `unittest.mock` / monkeypatch fake is preferred). If mocking httpx streaming proves awkward and you cannot produce a clean mocked test within scope, it is acceptable to ship the source fix without the test and note in the PR that the function was previously excluded from tests by design (see the test file's top docstring) — but prefer to add the test.

## Failure-mode escape hatch

If the primary path is blocked — e.g. the httpx version in `requirements.txt` lacks `client.stream`/`iter_bytes` (it won't; this is standard httpx), or mocking the stream is structurally infeasible — STOP and open the PR as a **draft** with a comment describing exactly what's blocked and what you did instead. A draft PR with an honest "blocked on X; shipped source fix without test" comment is a good outcome.

## Self-review checklist (before opening the PR)

- [ ] Only `download_image` in `image_storage.py` (and, if added, a new test in `test_image_storage.py`) was modified — no other functions touched.
- [ ] `MAX_DOWNLOAD_SIZE` value unchanged; constant reused (not inlined).
- [ ] The streaming guard aborts mid-stream once the cap is exceeded (verified by reading the final code).
- [ ] Return type is still `tuple[bytes, str]` and the value is `bytes`, not `bytearray`.
- [ ] Function signature and docstring unchanged.
- [ ] `User-Agent` header, `timeout=60`, `follow_redirects=True` preserved.
- [ ] Any new test mocks httpx — zero real network calls.
- [ ] `ruff check` clean (no new issues vs main baseline); `ruff format` applied.
- [ ] Tests pass (`pytest tests/test_image_storage.py`).
- [ ] PR description complete, including the production-touch line.
- [ ] Production touch: no.

If any item fails, open the PR as a **draft** with a comment naming the failed item.

## PR shape

- **Branch**: `fix/issue-69-stream-download-size-cap`
- **Title**: `fix(#69): enforce 20MB download cap by streaming instead of buffering`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (e.g. "no prod DB / auth / payment / PII / deploy touched; pure in-memory download hardening"); the self-review checklist with each item marked; a test plan (note that external HTTP is mocked); whether you kept the Content-Length pre-check; `Closes #69`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, whether the Content-Length pre-check was included, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 69`) and `backend/app/services/image_storage.py` lines 1-60 and 140-163; confirm the verified facts still hold (constant at line 18, cap check at line 52, single caller at line 152).
2. Rewrite `download_image` (lines 38-59) per "The task", staying strictly within IN scope.
3. Add the mocked size-guard test to `backend/tests/test_image_storage.py` (or note its omission per the escape hatch).
4. Run `ruff check` / `ruff format` and `pytest tests/test_image_storage.py`; iterate until clean.
5. Run the self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
