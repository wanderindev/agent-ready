# Fix brief — issue #83: image_storage.generate_thumbnail silently swallows Pillow failures; caller has no error trail

## Identification

You are an autonomous agent resolving issue #83 in the Panama In Context (wanderindev/panama-in-context) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend Python change in one service file plus one test file. It needs no live API, no DO Spaces, no DB — the test is a pure in-memory bytes test (mirror `TestWatermarkInfographic` in the existing test file, which builds a PNG with Pillow and asserts on the result). You do NOT need docker-compose.

**Test execution (run pytest natively against the testcontainer — the suite uses testcontainers for Postgres; your one new test needs no DB but the suite import chain does):**
- Reuse the existing backend virtualenv / installed deps if present; do NOT reinstall requirements if `pytest` and `app` already import.
- If you must run inside the dev container instead, the operator's stack may already be up — use a dedicated project name to avoid port/volume collisions: `docker-compose -p agent-issue-83 exec -T backend pytest ...`. Prefer the native run if deps are available.

**TEST DISCIPLINE (binding):**
1. ITERATE on the adjacent test file ONLY: `pytest tests/test_image_storage.py -q --tb=short` (NOT `-v`, never the full suite during iteration). Fast feedback, tiny output.
2. ONCE that file passes, run the FULL suite ONCE as the final gate: `pytest -q`. This is UNCONDITIONAL — do not gate it on "did I touch shared code?" A passing full run prints ~one line, so it is nearly free; cost only appears on failure.
3. If the full run FAILS: fix it, but DROP BACK to scoped runs to iterate — do NOT loop on the full suite. Re-run the full suite once more only to confirm green. If you cannot reach green within the runaway bounds, open a DRAFT PR naming the failing tests.

**STALE-STATE DISCIPLINE:** if a command comes back empty or cancelled, re-run that ONE command once; if still unclear, proceed from what you know or bail to a draft. Do NOT fire retry/probe storms.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

**File:** `backend/app/services/image_storage.py`. The `generate_thumbnail` method spans lines **98–141**. The `try` body is **115–138**; the bare catch is at **139–141**:

```python
        except Exception as e:
            logger.warning("Thumbnail generation failed for %s: %s", key, e)
            return None
```

(NOTE: the issue body cites lines 133–135 and caller line 161 — those are STALE. The catch is at 139–141; the caller `download_and_upload` starts at 143 and invokes `generate_thumbnail` at line 167. Lines 133–135 in current source are the unrelated `thumb_key`-building branch. Use the line numbers in THIS brief.)

**The change — narrow the catch, capture to Sentry with structured context, preserve `return None`:**

Replace the three-line `except Exception` block with:

```python
        except (UnidentifiedImageError, Image.DecompressionBombError, OSError) as e:
            logger.warning("Thumbnail generation failed for %s: %s", key, e)
            sentry_sdk.add_breadcrumb(
                category="image_storage",
                message="thumbnail generation failed",
                level="warning",
                data={"storage_key": key, "image_size_bytes": len(image_bytes)},
            )
            sentry_sdk.capture_exception(e)
            return None
```

Any exception class NOT in that tuple now propagates to `download_and_upload` — that is the intended behavior (it signals a real bug, not a content failure). Do not add a bare `except Exception` fallback.

**Imports (module top):**
- Line 11 currently reads `from PIL import Image, ImageDraw, ImageFont`. Change it to `from PIL import Image, ImageDraw, ImageFont, UnidentifiedImageError`.
- Add `import sentry_sdk` to the third-party import group (e.g. after the `import httpx` / before/after `boto3` lines — match ruff's import ordering; `sentry_sdk` is third-party). `sentry_sdk` is used across the backend but is NOT yet imported in this file.

**Why this exact exception tuple (verified):** Pillow resolves to 12.2.0 in the container (`requirements.txt` pins `Pillow>=10.0.0`). `UnidentifiedImageError` (importable from `PIL`) and `Image.DecompressionBombError` both exist and are the names Pillow raises for unreadable/oversized images. `OSError` covers truncated/unreadable BytesIO reads and is the modern alias for `IOError` — do not also list `IOError`.

**Canonical pattern to mirror:**
- Narrowed-catch + capture shape: `backend/app/services/media_scoring.py:145–153` — `except (...) as e:` → `logger` → `sentry_sdk.capture_exception(e)`, with a trailing comment that "any other exception propagates — it signals a real bug." Mirror that comment style.
- Structured-context breadcrumb: `backend/app/services/educator_service.py:158–166` — `sentry_sdk.add_breadcrumb(category=..., message=..., level=..., data={...})`. This is how this codebase attaches structured context; there is NO `push_scope`/`set_extra`/`set_tag`/`set_context` anywhere in the backend.

**IMPORTANT drift correction — do NOT use `extras=`:** the issue body suggests `sentry_sdk.capture_exception(e, extras={...})`. That kwarg is NOT valid in sentry-sdk 2.x (installed: 2.61.0; signature `capture_exception(error, scope=None, **scope_kwargs)`) and appears nowhere in this codebase — every existing `capture_exception` call is bare `capture_exception(e)`. Use the `add_breadcrumb(... data={...})` + bare `capture_exception(e)` pattern shown above instead. If you flag this in the PR, this is disagreement shape #2 (brief/issue corrected against source) — but the brief already resolves it, so just implement as written.

## Scope

### IN scope
- `backend/app/services/image_storage.py` — the two import lines and the `except` block inside `generate_thumbnail` (lines ~11, ~139–141, plus one new `import sentry_sdk`).
- `backend/tests/test_image_storage.py` — ADD a new test class for the narrowed catch (see Default rules).

### OUT of scope (do NOT touch)
- `download_and_upload` (lines 143–169) and its return tuple / API-surface "partial-success message". The issue EXPLICITLY defers the admin-facing "thumbnail generation failed; image uploaded" message as a separate domain-pipeline concern. Leave `download_and_upload` byte-for-byte unchanged. The `return None` contract must stay so the caller is unaffected.
- `watermark_infographic`, `watermark_slides`, `make_storage_key`, `download_image`, `upload_image`, `delete_image` — untouched.
- The `Image.MAX_IMAGE_PIXELS = 300_000_000` line inside the try (line 117) — leave it; relaxing/tightening it is issues #69/#81, not this one.
- Do NOT touch any other test file, conftest, or fixtures.

## Default rules for likely ambiguities

- **Exact exception tuple:** `(UnidentifiedImageError, Image.DecompressionBombError, OSError)` — exactly these three, in this order. No `IOError` (OSError alias), no trailing `Exception`.
- **No retry logic.** The issue explicitly warns against it — this is a fail-fast helper, not a retry-friendly path. Do not add loops, backoff, or re-attempts.
- **Preserve `return None`** at the end of the `except` block — the caller `download_and_upload` depends on it.
- **Sentry call signature:** bare `sentry_sdk.capture_exception(e)` (no kwargs) plus a preceding `sentry_sdk.add_breadcrumb(... data={"storage_key": key, "image_size_bytes": len(image_bytes)})`. Do NOT use `extras=`/`contexts=`/`scope=`.
- **Imports at module top** (extend line 11's `from PIL import ...`; add `import sentry_sdk` to the third-party group) — do NOT use function-local imports. Run `ruff check` / `ruff format` to confirm import ordering.
- **Test class:** add a new class, e.g. `TestGenerateThumbnail`, to `backend/tests/test_image_storage.py`. Instantiate the service the way the existing tests do — `ImageStorageService.__new__(ImageStorageService)` to bypass `__init__` (boto3/settings). To assert the narrowed catch swallows a Pillow failure and returns `None`: pass clearly-non-image bytes (e.g. `b"not an image"`) — `Image.open` raises `UnidentifiedImageError`, which is now caught → assert the method returns `None`. Patch `sentry_sdk.capture_exception` (via `patch("app.services.image_storage.sentry_sdk.capture_exception")`) and assert it was called once with the raised exception. Optionally add a test that an UNexpected error type (e.g. patch `Image.open` to raise `KeyError`) propagates (use `pytest.raises`) — this proves the narrowing. Mirror the existing `TestWatermarkInfographic` style: build inputs in-memory, no DB, no network.

## Failure-mode escape hatch

If the primary path is blocked (a required name doesn't import, the change needs out-of-scope edits), STOP and open the PR as a **draft** with a comment describing exactly what's blocked.

**Runaway-iteration guard (binding).** STOP and open a draft PR if ANY of these hold: ~40+ tool calls on this issue; third attempt at the same fix; you've already pushed and are now rewriting/reverting your own commits; a parallel tool batch got cancelled and you're unsure of your state. A stuck retry loop is the most expensive failure mode — bail to a draft and let the operator look.

## Self-review checklist (before opening the PR)

- [ ] Only `backend/app/services/image_storage.py` and `backend/tests/test_image_storage.py` modified.
- [ ] `except` tuple is exactly `(UnidentifiedImageError, Image.DecompressionBombError, OSError)`; no bare `except Exception` remains in `generate_thumbnail`.
- [ ] `return None` preserved; `download_and_upload` unchanged.
- [ ] `import sentry_sdk` added; `UnidentifiedImageError` added to the PIL import; no function-local imports.
- [ ] `sentry_sdk.capture_exception(e)` is bare (no `extras=`); structured context goes through `add_breadcrumb(... data={...})`.
- [ ] New test class added and passing; `pytest tests/test_image_storage.py -q` green.
- [ ] Full suite `pytest -q` green (run ONCE as final gate).
- [ ] `ruff check backend/app/services/image_storage.py backend/tests/test_image_storage.py` and `ruff format --check` clean vs main baseline (no new issues).
- [ ] PR description complete, including the production-touch line.
- [ ] **Production touch: no** — internal media-pipeline helper; no auth/payment/PII/DB/deploy/.env.

## PR shape

- **Branch**: `fix/issue-83-narrow-thumbnail-catch`
- **Title**: `fix(#83): narrow generate_thumbnail catch and capture to Sentry`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line; the self-review checklist with each item marked; a test plan; `Closes #83`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Begin by

1. Read the issue (`gh issue view 83`) and `backend/app/services/image_storage.py` + `backend/tests/test_image_storage.py`; confirm the verified facts (catch at lines 139–141, caller at 167) still hold.
2. Make the import + catch-block change, staying strictly within IN scope.
3. Add the `TestGenerateThumbnail` test class.
4. Run `ruff check` / `ruff format`, then the scoped pytest, then the full-suite gate per TEST DISCIPLINE; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Report back to the orchestrator with the PR number, draft-vs-ready status, what shipped, and any flags. STOP.
