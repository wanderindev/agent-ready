# Fix brief — issue #85: [Quality] media_scoring broad except Exception aborts entire scoring run on transient errors

## Identification

You are an autonomous agent resolving issue #85 in the Panama In Context codebase (main checkout: `/home/javier/vc/panama-in-context`). You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- Backend Python. Lint and tests run inside Docker per CLAUDE.md: `docker-compose exec backend ruff check /app` and `docker-compose exec backend pytest tests/test_media_scoring.py`. The operator's main checkout likely has the dev stack running, so a naïve `docker-compose up -d` from your worktree will hit 5432/8000 port conflicts and/or attach to the operator's containers (whose code volume is the main checkout, NOT your worktree). This issue is **test-only + service-only with no live API access needed** — every external call is mocked. Simplest correct path: install backend requirements locally (`pip install -r backend/requirements.txt`) and run `pytest backend/tests/test_media_scoring.py` natively against the testcontainer (conftest spins up its own PostgreSQL testcontainer; you need a reachable Docker socket but no docker-compose stack). Run `ruff check backend/app/services/media_scoring.py backend/tests/test_media_scoring.py` locally too. If local install is impractical, use a dedicated compose project name (`-p agent-issue-85`) with an alternate-port override file you do NOT commit. Pick one and proceed.
- **All LLM / external scoring calls MUST be mocked in tests** — never hit the real Anthropic API. The existing test file already mocks via `@patch("app.services.media_scoring.anthropic.Anthropic")` and a `_build_mock_anthropic` helper. Reuse that machinery; drive failure modes with `mock_client.messages.create.side_effect = <ExceptionInstance>`.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

**Target:** `score_candidates` in `backend/app/services/media_scoring.py` (lines 39-126). The `while True` loop (line 55) fetches a batch of unscored PENDING candidates (lines 60-71), builds a prompt, calls Anthropic, parses JSON, applies scores, and commits — all inside one `try` (line 84) whose `except Exception as e:` (lines **121-124**, NOT 117-120 as the issue body states — issue line numbers are stale by ~4) logs, rolls back, and **`break`s out of the entire loop**. One transient failure on one batch aborts the whole run.

**Issue-body drift you MUST know about:**
1. The broad except is at `media_scoring.py:121-124`, not 117-120.
2. The issue body cites `research.py:164-168` and `edu_research.py:166-169` as the canonical narrow-catch (`except (json.JSONDecodeError, IndexError)`) pattern to be consistent with. **This is FALSE.** `research.py` is only 88 lines and `edu_research.py` only 91; neither does any JSON parsing or has any `except` clause. There is **no LLM-JSON narrow-catch sibling to mirror.** Do not go looking for it. Construct the narrow catch from the issue's desired-state snippet + the real Sentry pattern named below. Note this correction in your PR description.

**The fix:** Replace the single `break`-ing `except Exception` (lines 121-124) with the split, narrowed handlers from the issue's "Desired state" section, with the loop-progression correction below. The loop must CONTINUE past transient/malformed-batch failures and only stop on terminal API errors; truly unexpected exceptions propagate uncaught.

**CRITICAL loop-progression hazard (the issue's snippet does not handle this):** The batch query (lines 60-71) selects rows where `relevance_score IS NULL` with a `LIMIT`, with **no offset/cursor**. The current code only advances because a successful batch `commit()`s scores (so those rows stop matching `IS NULL`). If you `continue` after `db.rollback()` on a transient error, the **exact same unscored rows are re-selected next iteration → infinite loop**. You MUST prevent this. The clean, minimal resolution that preserves the issue's intent ("transient errors skip the current batch and the run continues with the NEXT batch") AND avoids the infinite loop: maintain a running `skipped_batches` counter and apply `.offset(skipped_batches * batch_size)` to the batch query so a skipped batch is not re-fetched. Implement the `.offset(skipped_batches * batch_size)` approach: it is the smallest change that makes `continue` terminate.

**Exception classification (from issue, authoritative):**
- Transient → log `logger.warning`, `db.rollback()`, increment skip tracking, `continue`: `anthropic.RateLimitError`, `anthropic.APIConnectionError`, `anthropic.APITimeoutError`.
- Malformed LLM response → log `logger.error`, `sentry_sdk.capture_exception(e)`, `db.rollback()`, increment skip tracking, `continue`: `json.JSONDecodeError`, `KeyError`, `ValueError` (note: `json.JSONDecodeError` subclasses `ValueError`, so list it first or rely on the `ValueError` catch — keep both names for readability, harmless).
- Terminal → log `logger.error`, `sentry_sdk.capture_exception(e)`, `db.rollback()`, `break`: `anthropic.APIError` (parent of auth/permission errors; catch AFTER the transient anthropic subclasses so transient ones match first).
- Anything else: do NOT catch — let it propagate (it reaches Sentry as a real bug via the app's global handler).

**Do NOT add active retry** (no sleeping + re-calling). Just `continue`. (Per issue caveat: active retry is the job of the unified wrapper in #76.)

**Imports:** add `import sentry_sdk` at the top of `media_scoring.py` (it is not currently imported). `anthropic` and `json` are already imported.

**Stats / return contract:** `score_candidates` returns `dict[str, Any]` currently `{"candidates_scored": int, "batches_processed": int}`, consumed by the admin endpoint `media_library.py:84` as `ScoreResponse(**stats)`. `ScoreResponse` (`backend/app/schemas/media_candidate.py:98-102`) has EXACTLY those two fields. To surface the skip count cleanly, add `batches_skipped: int = 0` to BOTH `stats` (initialized alongside the others, ~line 52) and `ScoreResponse`. This surfaces the observability the issue asks for ("failures invisible to caller") with no breakage. Keep `batches_processed` meaning "successfully committed batches."

**Canonical pattern to mirror for the log+Sentry shape:** `backend/app/services/email_sender.py:55-58`:
```python
except (smtplib.SMTPException, OSError, TimeoutError) as e:
    logger.error("Failed to send email to %s: %s", to, e)
    sentry_sdk.capture_exception(e)
    raise EmailDeliveryError(...) from e
```
Mirror the narrow-tuple-except + `logger` + `sentry_sdk.capture_exception(e)` idiom (you `continue`/`break` instead of `raise`).

## Scope

### IN scope
- `backend/app/services/media_scoring.py` — narrow + split the except (lines 121-124), add `import sentry_sdk`, add `skipped_batches` tracking + `.offset(...)` on the batch query, add `batches_skipped` to `stats`.
- `backend/app/schemas/media_candidate.py` — add `batches_skipped: int = 0` to `ScoreResponse` (lines 98-102).
- `backend/tests/test_media_scoring.py` — add tests for the new classification behavior AND update the now-obsolete test (see Default rules).

### OUT of scope (do NOT touch)
- The `SCORING_PROMPT` string, the score-clamping/rounding/truncation logic (lines 104-117), the prompt-building, the markdown-fence stripping — all working and unrelated.
- `research.py`, `edu_research.py` — do NOT "fix" them to match; they have no JSON parsing. The issue's reference to them is wrong (see drift).
- The admin endpoint `media_library.py:trigger_scoring` (line 76-89) — no change needed beyond the schema field flowing through automatically.
- Issue #76 (unified Anthropic wrapper) — do NOT attempt it. Do NOT add active retry/backoff.
- Any other service module, the LOC crawl, the public-media API.

## Default rules for likely ambiguities

1. **Infinite-loop prevention (most important):** apply `.offset(skipped_batches * batch_size)` to the batch `select` (lines 60-71), where `skipped_batches` starts at 0 and increments on every `continue`-path. This steps over batches that failed-and-were-skipped so they aren't re-selected. Without this, `continue` after `rollback` re-fetches the same NULL-score rows forever.
2. **Variable name:** use `skipped_batches` (int, init 0 at line ~53 next to the other counters). Stats key: `batches_skipped`. Schema field: `batches_skipped: int = 0`.
3. **Exception ordering inside the try:** put the transient-anthropic tuple FIRST, then the malformed-response tuple, then `anthropic.APIError` (terminal), then no bare `except` — unmatched exceptions propagate. `anthropic.RateLimitError`/`APIConnectionError`/`APITimeoutError` are subclasses of `anthropic.APIError`, so the narrow tuple MUST precede the `anthropic.APIError` catch.
4. **Existing test that asserts OLD behavior — `test_rolls_back_and_stops_on_exception` (lines 261-284):** it raises a bare `Exception("boom")` and asserts the loop breaks with `candidates_scored == 0`. Under the new design a bare `Exception` is NOT caught (it propagates). UPDATE this test: rename/repurpose it to assert a bare/unexpected `Exception` now **propagates** (use `pytest.raises(Exception)` around the call), since the new contract is "unexpected exceptions propagate as real bugs." Keep the rollback observation note if still accurate.
5. **New tests to add** (mock via `side_effect = <ExceptionInstance>`):
   - `anthropic.RateLimitError` on batch 1 → run does not raise, `batches_skipped >= 1`, loop terminated (no infinite loop — assert `messages.create` called a bounded number of times). Construct anthropic error instances carefully: they often require constructor args (`message`, `response`, `body`). If instantiating real `anthropic.*Error` objects is awkward, build a lightweight subclass instance or use `MagicMock(spec=anthropic.RateLimitError)` as the side_effect — whatever the installed `anthropic` version allows. Verify the constructor signature against the installed package before writing the test.
   - `json.JSONDecodeError` (malformed response) on a batch → no raise, `sentry_sdk.capture_exception` called (patch `app.services.media_scoring.sentry_sdk`), batch skipped, run continues/terminates cleanly.
   - `anthropic.APIError` (terminal) → no raise, `break`, `sentry_sdk.capture_exception` called.
   - A bare `Exception` → propagates (`pytest.raises`).
6. **Sentry in transient handler:** the issue's snippet does NOT call `capture_exception` for the transient (rate-limit/connection/timeout) case — only `logger.warning`. Follow the issue: transient = warning only, no Sentry capture. Malformed + terminal = `logger.error` + `sentry_sdk.capture_exception`.
7. **Test for `sentry_sdk`:** patch it with `@patch("app.services.media_scoring.sentry_sdk")` so you assert `capture_exception` calls without sending events.
8. If instantiating `anthropic` exception classes proves genuinely impossible in tests, it is acceptable to test the malformed-response (`json.JSONDecodeError` / `ValueError`) and terminal/`break` paths thoroughly and note the anthropic-transient class instantiation limitation in the PR — but try `MagicMock(spec=...)` first.

## Failure-mode escape hatch

If the primary path is blocked — e.g., the `.offset` approach turns out infeasible against the model, or the anthropic exception classes cannot be instantiated/mocked at all — STOP and open the PR as a **draft** with a comment describing exactly what's blocked and what partial state you reached. A draft PR with an honest "blocked on X; did Y instead" comment is a good outcome; a non-draft PR that silently worked around the block is worse.

## Self-review checklist (before opening the PR)

- [ ] Only IN-scope files modified (`media_scoring.py`, `media_candidate.py` schema, `test_media_scoring.py`).
- [ ] `import sentry_sdk` added to `media_scoring.py`.
- [ ] The broad `except Exception` (old lines 121-124) is gone; replaced by transient/malformed/terminal handlers in the correct order; unexpected exceptions propagate.
- [ ] `continue` paths cannot infinite-loop (verified the `.offset(skipped_batches * batch_size)` steps over skipped batches; a test asserts a bounded `messages.create` call count).
- [ ] `batches_skipped` added to both `stats` and `ScoreResponse`; `ScoreResponse(**stats)` still validates.
- [ ] Obsolete `test_rolls_back_and_stops_on_exception` updated to the new propagate-on-unexpected contract.
- [ ] New tests cover transient-skip, malformed-skip (+Sentry), terminal-break (+Sentry), and bare-Exception-propagates. All external/LLM calls mocked.
- [ ] `ruff check` clean vs main baseline (no new issues) on the changed files.
- [ ] `pytest tests/test_media_scoring.py` passes (all old + new tests).
- [ ] PR description complete, includes the issue-body drift corrections (line 121-124 not 117-120; research.py/edu_research.py have no such pattern).
- [ ] Production-touch line present (none).

## PR shape

- **Branch**: `fix/issue-85-media-scoring-per-batch-except`
- **Title**: `fix(#85): narrow media_scoring catch so one batch failure doesn't abort the run`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: content-scoring service + admin-gated endpoint, no prod DB/.env/deploy/auth/payment/PII"** line; the self-review checklist with each item marked; a test plan; the issue-body-vs-source drift notes; `Closes #85`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced (especially the drift corrections and the loop-progression resolution you chose). Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 85`) and `backend/app/services/media_scoring.py`, `backend/app/schemas/media_candidate.py` (lines 91-103), and `backend/tests/test_media_scoring.py`; confirm the verified facts (especially: except at 121-124; research.py/edu_research.py have NO json/except; batch query has no offset).
2. Make the change, staying strictly within IN scope.
3. Run `ruff check` and `pytest tests/test_media_scoring.py`; iterate until clean.
4. Self-review checklist.
5. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
6. Append the outcomes-log row.
7. Report back and STOP.
