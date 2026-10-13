# Phase 2 — Session 03: Full #99 fix — refuse-on-rerun policy + raw-SQL → ORM refactor

## Identification

You are running **Phase 2 Session 03** of the Panama In Context (PIC) audit-and-fix pilot. Phase 0 (baseline + safety nets) is done; Phase 1 (the area-by-area audit) is done; Phase 2 (the fix-execution phase) is in progress. Session 01 was planning-only. Session 02 shipped the *partial* #99 remediation — articles 39/40 production data cleanup + a safety-net idempotency refusal in `SeriesSectionGenerator.generate_sections_for_series`. This session ships the **full #99 code fix**.

You are running in a **fresh Claude Code instance**, separate from the orchestrator's main session. That separation is deliberate — the orchestrator is preserving their context window so they can review your work and brief subsequent sessions. **Do not assume any conversational context.** Everything you need is in the files this prompt points at; the repo is the source of truth.

## Operator decisions already made (do not re-debate)

These were decided in the orchestrator's session and are binding for session 03:

1. **Policy: refuse-on-rerun** (not strip-and-replace). The endpoint should refuse cleanly when regeneration is attempted on an already-processed series, matching the four other regeneration-guarded flows in the article pipeline (`outline gen`, `write_article`, `translate_article` — they all refuse on "already has X"). Strip-and-replace was considered and rejected on grounds of (a) no current evidence admins need to re-run after metadata edits, (b) higher risk of re-corrupting prod given the byte-drift hazard session 02 discovered, (c) refuse is a clean future-upgrade path if strip-and-replace becomes needed.
2. **Single PR** containing the policy implementation, the raw-SQL → ORM refactor, and the frontend `has_series_sections` UI-gate review. The refactor only matters because of the policy; they're conceptually one fix.
3. **No further production data cleanup is needed.** Articles 39 and 40 were cleaned in session 02 (PR #134). Verified post-merge via the public API: art 39 = 1/1/1/1 markers, art 40 = 1/1/0/0. Don't re-touch prod data.

## Read these first, in order

Read each one fully before proposing a plan. Don't skim.

1. **`docs/phase-2/02-articles-39-40-cleanup-report.md`** — the previous session's report. Pay attention to: the stop-the-line moment (the continue-section canonical drifted from stored by one leading newline; cleanup script needed a single-fallback widening); the auto-approve fence's two correct fires; the test-infrastructure note (`docker.sock` not mounted in dev compose — you will hit this too); cross-cutting checklist dispositions.
2. **Issue #99** — run `gh issue view 99` and **read the comment thread** (`gh issue view 99 --comments`). The session-02 comment names what shipped (cleanup + safety-net refusal) and what remains (policy + raw-SQL→ORM + UI gate). Pay attention to the issue body's "Desired state" section and the line "Either refuse (mirror the other flows' `400 \"already has ...\"`) or strip the existing block and replace cleanly." Refuse is the chosen policy; the 400 shape is one of your Phase-1 verifications (see Scope).
3. **`backend/app/services/series_sections.py`** (full file) — the service you're refactoring. Current state has the safety-net refusal in place (`ABOUT_MARKER_EN` / `ABOUT_MARKER_ES` module constants; refusal inserted between `can_generate_sections` and the per-article update loop). Note the **three** `text()` queries you will convert to ORM: suggestion-lookup (lines ~63-71), articles-in-series-lookup (lines ~88-97), and the **`UPDATE` concatenation** (lines ~286-297). The `UPDATE` is the structural cause of #99 — once it's ORM, the double-append failure mode disappears regardless of the policy.
4. **`backend/app/api/dashboard.py`** lines ~1172-1224 — the `POST /admin/dashboard/articles/{article_id}/series-sections` endpoint. Note how it currently surfaces `(success, message, articles_updated)` as `SeriesSectionsResponse` with HTTP 200 (not 400). Compare with how `outline gen`, `write_article`, and `translate_article` surface their "already has" refusals — that's part of your Phase-1 verification.
5. **`backend/app/models/article.py`** — the `Article` model. You'll be loading rows via ORM in the refactor (`db.query(Article).filter(...)`) and writing `article.content = ...; db.add(article); db.commit()` — note the `updated_at` `onupdate` trigger (line ~58); the current raw-SQL `UPDATE` bypasses it, the ORM path will start firing it again.
6. **`backend/tests/test_series_sections.py`** — the 3 existing tests (EN-refusal, ES-refusal, happy-path). You will extend this file; the existing tests should continue to pass after the refactor.
7. **`backend/tests/conftest.py`** — note `article_factory`, `suggestion_factory`, `research_factory`. The fixture pattern uses real Postgres via `testcontainers`. See the test-infra note in §"Test infrastructure" below.
8. **Frontend `has_series_sections` consumers** — grep for `has_series_sections` across `frontend/src/`. The predicate is also defined backend-side in `dashboard.py:list_articles` as `"**About this Article**" in a.content`. Confirm both sides agree on the marker string and align to `ABOUT_MARKER_EN` if there's drift. Most likely outcome: read-only verification, no change.
9. **`CLAUDE.md`** — project conventions. Especially the "Use SQLAlchemy ORM, not raw SQL" rule (the refactor is literally satisfying this) and the Docker-based dev workflow.
10. **`.claude/settings.json`** — the auto-approve fence. **No production touch is expected in this session.** No prod DB writes, no `gh pr merge`, no force-pushes. If the fence fires on something, you've drifted out of scope — stop and surface.
11. **`docs/phase-2/agent-friendly-outcomes.md`** — append one row when the PR opens. Use `Issue # = 99 (full)`, `Filed agent-friendly? = no` (per the issue body), `Filed severity = critical`, `Track = article`, `Agent attempted? = pair`, `Outcome = not-yet-attempted` until merge.

## Why this session matters

The session-02 PR shipped a safety-net refusal and cleaned the manifested corruption. The **structural cause** of #99 — the raw-SQL `UPDATE articles SET content = :about_en || content || :continue_en` — is still in the codebase. The safety-net catches re-runs *if* a prior run left the about-marker; it does not protect against any future variant of the same string-concatenation failure mode (e.g. a future edit that introduces another raw-SQL UPDATE). Converting all three `text()` queries to ORM removes the failure mode structurally and brings `series_sections.py` into line with the project convention.

The 400-vs-200 surface question is small but real. The other regeneration-guarded flows in the article pipeline use **one** convention for refusals; the series-sections refusal should match it. Currently the safety-net returns `(False, msg, 0)` which the endpoint serves as HTTP 200 with `success=False`. Whether that matches the other flows is a Phase-1 verification.

## Scope

### IN scope

- **Raw-SQL → ORM refactor** of all three `text()` queries in `series_sections.py`:
  1. `get_series_info`'s suggestion-via-research lookup → `db.query(ArticleSuggestion).join(Research, Research.suggestion_id == ArticleSuggestion.id).filter(Research.id == parent.research_id).first()` (or equivalent).
  2. `get_series_info`'s articles-in-series lookup → `db.query(Article).filter(or_(Article.id == parent_id, Article.series_parent_id == parent_id)).order_by(func.coalesce(Article.series_order, 1)).all()`. Keep `has_content_es` logic (currently `content_es IS NOT NULL`) via the loaded row's `content_es is not None`.
  3. `generate_sections_for_series`'s `UPDATE` → load each `Article` row via ORM, set `article.content = about_en + (article.content or "") + continue_en` and the `content_es` equivalent, `db.add(article)`. Commit once at the end (current behavior — keep it; the safety-net already prevents recurrence-on-rerun).
- **Policy implementation: refuse-on-rerun.** Promote the safety-net from a per-session safety net to the documented behavior. The refusal is already in place; what may change is the *endpoint surface*:
  - **Phase-1 verification (sub-decision):** check whether `outline gen`, `write_article`, and `translate_article` surface their "already has" refusals as HTTP 400 (raised `HTTPException`) or as HTTP 200 with a `success=False` body. Whatever the majority convention is, the series-sections refusal should match. Surface the verification result in your Phase-1 plan before changing anything.
  - If majority is 400 with `HTTPException`: change `dashboard.py:1216-1224` (or have the service raise) so the idempotency refusal surfaces as `HTTPException(400, detail=...)`. Distinguish the idempotency refusal from existing `(False, ...)` returns (e.g. "Series not found", "X articles not translated") — those may stay as 200/success=False if they were 200/success=False before.
  - If majority is 200 with success=False: leave the current shape; the issue body's "400" wording was aspirational, and the comment-on-issue should note we picked the established convention.
- **Frontend `has_series_sections` UI-gate review.** Read the consumers. Confirm the predicate matches `ABOUT_MARKER_EN`. Most likely outcome: no change needed. If there's drift, fix.
- **Tests.** Extend `backend/tests/test_series_sections.py`:
  - The 3 existing tests should remain green post-refactor. If any go red, the refactor changed observable behavior and you need to understand why.
  - Add a test asserting `generate_sections_for_series` produces the correct content shape end-to-end via ORM (about + body + continue, with markers in the right positions).
  - If the endpoint surface changes to 400, add an API-level test using `test_client` + `admin_token` fixtures (see `conftest.py`) that hits the endpoint twice and asserts the second call returns 400.
- **Session report** at `docs/phase-2/03-issue-99-full-fix-report.md`. Follow the shape of session 02's report. Include the cross-cutting checklist dispositions sub-section.
- **One row appended** to `docs/phase-2/agent-friendly-outcomes.md` when the PR opens.
- **Comment on issue #99** linking the PR. If this PR closes #99 entirely, use `Closes #99` in the PR description and confirm with the operator that nothing further is expected.
- **INDEX update.** Add an entry for session 03 in `docs/phase-2/prompts/INDEX.md`.

### OUT of scope

- **Strip-and-replace.** Decided against. If you find yourself tempted to implement it because "it's only a little more code," stop and surface as a process note instead.
- **Any production data touch.** Articles 39/40 were cleaned in session 02. Do not re-read them from prod, do not re-clean them, do not run the cleanup script in any mode against prod.
- **Other refactors in `series_sections.py`** — e.g. dataclass changes, slug-generation tweaks, prompt-template extraction. The session is bounded to the three `text()` queries, the policy surface, the UI-gate review, and tests.
- **Other `text()` queries elsewhere in the codebase.** Stay in `series_sections.py`.
- **The test-infrastructure `docker.sock` issue.** Acknowledged; not this session's work. Run tests from the host as session 02 did.
- **The `_generate_references_section` duplication (#103)** and other Area-4b-2-adjacent issues.
- **Composio Gmail integration.** Unrelated to #99; covered in CLAUDE.md as "planned for replacement" with no current ETA.

## Plan — four phases, gated step-by-step

### Phase 1 — Local prep + plan (no code writes until approved)

1. Read the inputs above.
2. Run `gh issue view 99 --comments` and confirm what's already shipped per the session-02 comment.
3. **Verify the endpoint-surface convention** for refusals across the four regeneration-guarded flows:
   - `POST /admin/dashboard/articles/generate-outlines` (the "Articles already exist" refusal)
   - `POST /admin/dashboard/articles/{article_id}/write` (the "Article already has content" refusal)
   - `POST /admin/dashboard/articles/{article_id}/translate` (the "Article already has Spanish content" refusal)
   - Compare against the current series-sections surface.
   - Decide: majority-400 or majority-200/success=False. Make this a load-bearing fact in your Phase-1 plan.
4. **Verify the frontend `has_series_sections` predicate** matches `ABOUT_MARKER_EN`. Grep for `has_series_sections` and `About this Article` across `frontend/src/`.
5. Produce a **plan** that specifies:
   - The ORM-equivalent of each of the three `text()` queries (one-line sketches; not full code).
   - The endpoint-surface decision and how it will be implemented (e.g. `HTTPException` raised in the service, or in the endpoint).
   - The test list — which new tests, which existing tests need updating.
   - Any frontend changes (most likely: none).
   - Whether the PR closes #99 (i.e. nothing further remains after this PR).
6. **Surface the plan and WAIT for operator approval before any code write.**

### Phase 2 — Implementation

Once Phase 1 is approved:

1. Create the feature branch: `fix/issue-99-full-fix` (or operator-suggested alternative).
2. Implement the three ORM conversions one at a time. After each, run the 3 existing tests; they must stay green. Convert in this order: suggestion-lookup → articles-lookup → UPDATE-concatenation (the safest order — the UPDATE is the load-bearing one and is converted last so the read paths are already verified).
3. Implement the policy surface change (if any) per Phase-1 decision.
4. Add the new test(s).
5. Run the full `backend/tests/test_series_sections.py` clean from the host (see Test infrastructure §).
6. `ruff check` clean on changed files.
7. Surface results for operator review before opening the PR.

### Phase 3 — PR + housekeeping

1. Commit in logical chunks. Suggested:
   - `refactor(series-sections): convert get_series_info raw-SQL queries to ORM (#99)` — both reads.
   - `refactor(series-sections): convert generate_sections_for_series UPDATE to ORM (#99)` — the load-bearing one.
   - `fix(series-sections): make idempotency refusal return HTTP 400 (#99)` — only if Phase-1 chose 400.
   - `test(series-sections): extend coverage for ORM-based generation and policy surface (#99)`.
   - `docs(phase-2): session 03 — full #99 fix report + outcomes-log row` — final.
2. Push the branch. Open a PR. **Do not merge.** Operator merges.
3. PR description must include a **"Production touch: no — verified by:"** line per Phase 2 working-model L3 (no prod touch expected this session).
4. Append a row to `docs/phase-2/agent-friendly-outcomes.md` when the PR opens.
5. Comment on issue #99. If this PR closes the issue, say so explicitly in both the PR (`Closes #99`) and the issue comment.
6. Write the session report at `docs/phase-2/03-issue-99-full-fix-report.md`.
7. Update `docs/phase-2/prompts/INDEX.md` with an entry for session 03 pointing at this prompt and the produced report.

## Test infrastructure

The dev backend container does not mount `/var/run/docker.sock`, so the `testcontainers`-backed `conftest.py` fixtures cannot spawn a Postgres container inside `docker-compose exec backend pytest`. Session 02 documented this; session 03 will hit it again.

**Workaround used by session 02:** run tests from the host with `/home/javier/anaconda3/bin/pytest` from `backend/`. Host has the required deps (`testcontainers`, `sqlalchemy`, `fastapi`, etc.) and the host's `/var/run/docker.sock` is available. This is the practical fix for now.

**Do not fix the docker.sock issue this session.** It's out of scope.

## Working style

- **Gate-at-each-phase.** Phase 1 → Phase 2 → Phase 3, each separated by an explicit operator approval surface. No "I'll just do the refactor and the test and surface everything at the end" pass.
- **Don't expand scope.** If you notice the strip-and-replace policy "would only take a bit more time," do NOT expand. The whole point of refuse-on-rerun is to keep this PR small and reviewable. Surface temptations as process notes in the session report; let the operator decide whether to follow up.
- **ORM, not raw SQL.** The whole session is about satisfying this; if you find yourself reaching for `text()` for any reason, stop.
- **Tests pass locally before push.** `pytest backend/tests/test_series_sections.py` from the host (3 existing + your new tests) and `ruff check` clean on changed files.
- **PR opened, not merged.** Operator merges. The `gh pr merge*` deny rule in the fence will block you anyway.
- **One row in the outcomes log when the PR opens, not at merge.**
- **No production touch.** Phase 2 should not require prod credentials. If you find yourself sourcing `.env.prod-readonly` for any reason, you've drifted.

## Stop-the-line triggers

Concrete, not abstract. If any of these fire during the session, STOP and surface immediately:

- An existing test goes red after the refactor. Stop. The refactor changed observable behavior; understand the byte-level difference before proceeding.
- The endpoint-surface verification (Phase 1 step 3) returns ambiguous results — e.g. two flows return 400 and one returns 200. Stop and surface for operator decision on which convention to follow.
- The frontend has a `has_series_sections` consumer that uses a different marker string than `ABOUT_MARKER_EN`. Stop. This is a cross-stack consistency question that needs operator input before any fix.
- The ORM-generated content for the happy path differs byte-for-byte from the raw-SQL-generated content (other than `updated_at` firing). Stop. Investigate the difference before committing.
- A prod-touching command surfaces. Stop. This session is local-only.

## Scope estimate

~1 session, 1 PR. ~4-5 commits in the PR. This PR likely **closes #99** entirely (refuse-on-rerun policy, raw-SQL→ORM done, UI gate verified). If Phase-1 verification reveals additional scope (e.g. the UI gate has drift requiring a frontend change), surface for re-scoping.

If the session is approaching its third hour without Phase 2 having started, something is wrong — surface for re-scoping.

## Begin by

1. Read the inputs in the order listed in "Read these first." Don't skim. Don't start writing code.
2. Run `gh issue view 99 --comments` and read the session-02 comment.
3. Verify the endpoint-surface convention by reading the three other refusal sites in `dashboard.py`.
4. Grep for `has_series_sections` in the frontend; read the consumer.
5. Produce a Phase-1 plan with: the three ORM query sketches; the endpoint-surface decision (400 vs 200/success=False) and how to implement it; the test list; any frontend findings; whether this PR will close #99.
6. **Wait for operator approval on the Phase-1 plan before any code write.** The plan goes to the operator; the operator approves or pushes back; then Phase 2 begins.
