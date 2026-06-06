# Phase 2 — Session 03 Report: Full #99 fix — refuse-on-rerun policy + raw-SQL → ORM refactor

**Date:** 2026-05-25
**Duration:** ~1 session (single sitting; Phase 1 plan → Phase 2 implement → Phase 3 PR)
**Prompt:** `docs/phase-2/prompts/03-issue-99-full-fix.md`
**PR:** [#137](https://github.com/wanderindev/panama-in-context/pull/137)

---

## Executive summary

Second Phase 2 fix-work session and the **closing half of #99**. Five-commit PR that:

1. Converts all three `text()` queries in `series_sections.py` to SQLAlchemy ORM — including the load-bearing `UPDATE articles SET content = :about_en || content || :continue_en …`, the structural cause of the double-append. Also restores the `updated_at` `onupdate` trigger that the raw-SQL UPDATE was bypassing.
2. Promotes the session-02 safety-net refusal to a first-class **refuse-on-rerun** policy, raised as `HTTPException(400, …)` to match the convention of the three sibling regeneration-guarded flows (`generate-outlines`, `write_article`, `translate_article` — all 400 with `HTTPException`).
3. Routes the two literal `"**About this Article**"` string checks in `dashboard.py` (the `has_series_sections` derivation and the publish-gate) through the `ABOUT_MARKER_EN` constant. Cross-module marker definition in one place. Verified no drift — both literals were already byte-identical.
4. Extends the test file: 2 existing refusal tests updated to assert `HTTPException(400)`; 2 new tests added (ORM content shape; endpoint-level 400-on-rerun).

The PR description says `Closes #99`. The three "Desired state" bullets in the issue body are all addressed: (1) idempotency guard with the 400 surface the body suggested, (2) ORM-based content building, (3) corrupted articles 39/40 fixed in PR #134.

The session was deliberately uneventful — no stop-the-line incidents, no fence fires, no prod touch. The only sub-decision worth surfacing was Phase 1's endpoint-surface verification: read the three sibling refusals (`dashboard.py:838-842`, `:896-897`, `:1147-1148`), confirmed unanimous 400 with `HTTPException`, and locked the series-sections refusal to match. The verification was a 5-minute read; the alternative (silently pick 200 to match the existing safety-net's shape) would have left the article pipeline with inconsistent refusal surfaces.

One planned test (`test_orm_path_fires_updated_at_trigger`) was dropped during Phase 2 implementation. The fixture's transaction-rollback design wraps each test in a single Postgres transaction; `func.now()` is fixed at transaction start, so the trigger fires but `updated_at` can't differ from `server_default` within the same transaction. The contract is structurally enforced by the ORM-vs-raw-SQL choice; just not observably testable here. Surfaced as a process note in the commit message and below.

---

## By the numbers

| Metric | Count |
|---|---|
| Commits in branch | 5 (4 code + 1 tests, plus this docs commit) |
| Files added | 1 (this report) |
| Files modified | 3 (`backend/app/services/series_sections.py`, `backend/app/api/dashboard.py`, `backend/tests/test_series_sections.py`) |
| Files modified (docs) | 2 (`docs/phase-2/agent-friendly-outcomes.md`, `docs/phase-2/prompts/INDEX.md`) |
| `text()` queries removed from `series_sections.py` | 3 (all of them) |
| Unit tests updated | 2 (EN/ES refusal — tuple-return → `pytest.raises(HTTPException)`) |
| Unit tests added | 2 (`test_generated_content_has_correct_shape`, `test_endpoint_returns_400_on_rerun`) |
| Unit tests dropped (with note) | 1 (`test_orm_path_fires_updated_at_trigger` — not observably testable with current fixture) |
| Unit tests passing on changed code | 5/5 |
| Ruff status on changed files | clean (pre-existing `F841` in `dashboard.py:1591` unrelated to this PR's lines, carried forward per session-02 precedent) |
| Auto-approve-fence fires | 0 |
| Stop-the-line incidents | 0 |
| Production touch | none |
| Outstanding decisions awaiting operator at session end | 0 (PR open for review; merge is operator-driven) |

---

## What was done

### Phase 1 — Local prep + plan

Read all inputs in order per the brief. Pulled the session-02 report, the issue body and the session-02 comment thread on #99, the full `series_sections.py`, the `dashboard.py` endpoint region (with the three sibling refusal sites), the `Article` model, the existing `test_series_sections.py`, the `conftest.py` fixtures, the frontend `has_series_sections` consumers, `CLAUDE.md`, and the outcomes-log format.

Two load-bearing verifications:

**Endpoint-surface convention.** Read the three other regeneration-guarded refusal sites:

| Endpoint | File:Line | Refusal |
|---|---|---|
| `POST /generate-outlines` | `dashboard.py:838-842` | `HTTPException(400, "Articles already exist for this research")` |
| `POST /articles/{id}/write` | `dashboard.py:896-897` | `HTTPException(400, "Article already has content")` |
| `POST /articles/{id}/translate` | `dashboard.py:1147-1148` | `HTTPException(400, "Article already has Spanish content")` |

All three: 400 raised as `HTTPException` at the endpoint layer. **Unanimous.** Decision: switch the series-sections idempotency refusal to `HTTPException(400, …)`. The two pre-existing tuple-returns (`"Series not found"`, `"X articles not translated"`) stay as 200/`success=false` — they weren't 400 before and the brief explicitly scopes them out.

**Frontend `has_series_sections` consumers.** Three consumer sites in `frontend/src/`, all reading the boolean from the API (none re-derive the marker):

- `AdminArticles.jsx:32` — UI-gate `showSeries = … && !data.has_series_sections`
- `AdminArticles.jsx:35` — publish-gate `(!data.is_series || data.has_series_sections)`
- `AdminArticles.jsx:593` — optimistic post-success update

Backend `has_series_sections` predicate at `dashboard.py:1015` is `bool(a.content and "**About this Article**" in a.content)`; publish-gate at `dashboard.py:1256` uses the same literal. Both byte-identical to `ABOUT_MARKER_EN = "**About this Article**"`. **No drift.** Frontend works without changes — the admin service at `admin.js:341-351` already extracts `err.detail` from non-2xx responses and the handler's `catch` block routes the detail into `setErrorDialog`.

Surfaced a single Phase-1 plan with the ORM sketches, the 400 decision, the test list (existing tests to update + 3 new tests planned, one of which I later dropped), and the assertion that this PR closes #99. Operator approved.

### Phase 2 — Implementation

Branch `fix/issue-99-full-fix`. Five code commits, each keeping the test tree green:

**Commit 1 — `refactor(series-sections): convert get_series_info raw-SQL queries to ORM (#99)`.** Both reads converted: suggestion-via-research lookup → `db.query(ArticleSuggestion).join(Research, Research.suggestion_id == ArticleSuggestion.id).filter(Research.id == parent.research_id).first()`; articles-in-series lookup → `db.query(Article).filter(or_(Article.id == parent_id, Article.series_parent_id == parent_id)).order_by(func.coalesce(Article.series_order, 1)).all()`. The dataclass return shape is preserved; `has_content_es` derived in Python from `row.content_es is not None`. No behavior change. 3 existing tests stay green.

**Commit 2 — `refactor(series-sections): convert generate_sections_for_series UPDATE to ORM (#99)`.** The load-bearing one. Folded the safety-net loop and the UPDATE loop into a single bulk pre-load: one `db.query(Article).filter(or_(…)).all()` builds a `dict[int, Article]` keyed by ID; both passes iterate over that dict. Marker check still uses the same tuple-return convention as before. Mutation is `row.content = about_en + (row.content or "") + continue_en` followed by `db.add(row)`; single `db.commit()` at the end (preserves the current transaction shape). The ORM path restores the `updated_at` `onupdate` trigger that the raw-SQL UPDATE was bypassing. 3 existing tests stay green.

**Commit 3 — `fix(series-sections): make idempotency refusal return HTTP 400 (#99)`.** Surface change. The safety-net's tuple-returns are replaced with `raise HTTPException(status_code=400, detail=…)`. The two existing refusal tests are updated in the same commit to `pytest.raises(HTTPException)` and assert `status_code == 400` plus the detail substrings. The happy-path test is unchanged. The two pre-existing non-idempotency tuple-returns (Series-not-found, X-articles-not-translated) are deliberately untouched — they were 200/false before and remain 200/false.

**Commit 4 — `refactor(dashboard): route About-marker checks through ABOUT_MARKER_EN (#99)`.** Import `ABOUT_MARKER_EN` from `app.services.series_sections`; replace the two literal `"**About this Article**"` strings at `dashboard.py:1015` (list_articles) and `:1256` (publish_article). No behavior change — literals were already byte-identical. Pre-existing `F841` ruff error at `dashboard.py:1591` (unrelated line) flagged in the commit message and carried forward per session-02 precedent.

**Commit 5 — `test(series-sections): add ORM content-shape and endpoint-400 coverage (#99)`.** Two new test classes:

- `TestSeriesSectionsOrmGeneration::test_generated_content_has_correct_shape` — asserts about-marker at the start, original body preserved verbatim in the middle, continue-section appended for non-last articles (and absent for the last). Both EN and ES.
- `TestSeriesSectionsEndpoint::test_endpoint_returns_400_on_rerun` — API-level via `test_client` + `admin_token`. First POST returns 200 with `success=true` and `articles_updated=2`; second POST returns 400 with detail containing `"already has series sections"` and `"#99"`. Exercises the full HTTP → router → service → ORM path.

The planned third test (`test_orm_path_fires_updated_at_trigger`) was dropped: the `test_db` fixture wraps each test in a single Postgres transaction where `func.now()` is fixed at transaction start, so even though the `updated_at` `onupdate` trigger fires, the observed value equals the `server_default` set on insert within the same transaction. Captured the failing assertion (`datetime.datetime(2026, 5, 25, …) > datetime.datetime(2026, 5, 25, …)` — same instant), recognized the root cause in the fixture design rather than the production code, and surfaced as a process note (here and in the commit message) rather than building infrastructure to test it.

All 5 tests pass:

```
tests/test_series_sections.py::TestSeriesSectionsIdempotencyRefusal::test_refusal_when_en_marker_present_in_content PASSED
tests/test_series_sections.py::TestSeriesSectionsIdempotencyRefusal::test_refusal_when_es_marker_present_in_content_es PASSED
tests/test_series_sections.py::TestSeriesSectionsIdempotencyRefusal::test_happy_path_generates_when_no_markers_present PASSED
tests/test_series_sections.py::TestSeriesSectionsOrmGeneration::test_generated_content_has_correct_shape PASSED
tests/test_series_sections.py::TestSeriesSectionsEndpoint::test_endpoint_returns_400_on_rerun PASSED
```

Ran from the host with `/home/javier/anaconda3/bin/pytest` (the dev backend container still doesn't mount `/var/run/docker.sock`, so `testcontainers` fixtures can't spin up Postgres from inside `docker-compose exec backend pytest` — same workaround as session 02; out of scope to fix this session).

### Phase 3 — PR + housekeeping

PR #137 opened. Description includes `Closes #99` and a `Production touch: no — verified by:` block. Outcomes-log row appended (`Outcome = not-yet-attempted` until merge). This report written. `INDEX.md` entry for session 03 updated (the orchestrator had pre-written it with a non-link path; updated to a real markdown link now that the report file exists). Comment on issue #99 follows.

---

## What's next

1. **Operator merges PR #137.** The `gh pr merge*` deny rule blocks me from merging; correctly. Once merged, update the `Outcome` column in `docs/phase-2/agent-friendly-outcomes.md` from `not-yet-attempted` to the actual outcome (`clean-merge` or `needs-revision` per the schema).
2. **Issue #99 closes on merge.** PR description has `Closes #99`. Nothing further on #99 after the merge.
3. **Follow-ups worth filing as their own issues** (not done this session — surfacing as the brief instructed):
   - **Test-infrastructure: `docker.sock` not mounted in dev compose.** Same pre-existing issue session 02 surfaced. The `testcontainers`-backed suite is un-runnable in `docker-compose exec backend pytest`. Two viable paths: mount the socket in dev compose; or migrate `conftest.py` to use the already-running `db` service. Carried forward as a deferred candidate, still uncrystallized as a filed issue.
   - **Ruff debt on the wider backend.** Session 02 reported 118 errors across the codebase (109 auto-fixable). I confirmed at least one (`F841` in `dashboard.py:1591`) is still present and untouched. The four files I touched are clean.
   - **Transaction-rollback test fixture limits `updated_at`-trigger observability.** Noted in commit 5's message and above. A future infra change (per-test commit/separate-transaction fixture, or testing strategy that exercises the trigger via a separate connection) would unlock this kind of trigger-firing assertion. Not blocking the #99 close.

---

## Process notes

- **The brief's gating-at-each-phase discipline was load-bearing.** Phase 1 surfaced the unanimous-400 verification before any code wrote; the alternative path (silently pick 200 to match the existing safety-net's shape) was visibly available and would have left the pipeline with one of four refusal sites disagreeing on convention. Catching it in plan-time made the implementation a 5-commit straight line instead of a "wait should this be 200 actually?" round-trip mid-implementation. Disposition: **gate fired clean.**
- **Splitting commit 2 (UPDATE→ORM) and commit 3 (policy 400) was worth the small extra effort.** They could have been one commit — the safety-net loop and the UPDATE loop were intertwined enough that folding them is naturally one change. But: commit 2 is a pure refactor (no behavior change), commit 3 is a pure surface change (no algorithmic change). A reviewer reading commit 2 in isolation can verify "this preserves behavior" without holding the 400 semantics in their head; a reviewer reading commit 3 can verify "this changes the surface from 200/false to 400" without re-grokking the loop-folding. Cost was about 90 seconds of extra editing.
- **The dropped `updated_at` test was the only Phase-2 surprise.** I'd written the test assuming the fixture would let me observe a wall-clock advance between insert and update. Wrong assumption: the fixture's design (transaction-rollback for isolation) and Postgres's `now()` semantics (fixed at transaction start) are both load-bearing for unrelated reasons, and they combine to make the trigger fire invisibly. The right response was to drop the test, not to fight the fixture. Surfaced this honestly in the commit message and the PR body rather than quietly omitting it. Disposition: **mid-implementation stop-the-line, resolved without escalation.**
- **Pre-existing ruff debt: leave it.** Same call session 02 made (and surfaced as a follow-up). Touched `dashboard.py` for the constant-routing; the `F841` at line 1591 was already there. Fixing it would be trivial but expands scope and conflates two unrelated changes in the same PR. Noted in the commit message.
- **No process-note about prod safety this session, because there was nothing to prod-touch.** The brief was explicit ("No production touch is expected"); session 02 already cleaned articles 39/40; the fix is pure code. The auto-approve fence was the silent dog that didn't bark — zero fires, because nothing fired-able happened.

---

## What surprised me

- **The 400-vs-200 sub-decision was less interesting than the brief implied.** The brief framed it as a potentially-load-bearing Phase-1 verification that might "return ambiguous results — e.g. two flows return 400 and one returns 200." Reality: all three flows agree, the convention is one line of `HTTPException(400, …)` each, and the question resolved in under five minutes. Worth knowing for future fix-execution sessions: the "verify the convention" step often is the kind of one-grep verification the brief asks for, not the kind of surprise-uncovering deep dive the framing suggests. Both shapes happen; planning for both is right.
- **The transaction-fixture / `updated_at`-trigger conflict was the only real friction.** I'd internalized the "ORM-restores-the-trigger" point hard enough that I assumed the test would just work. Writing the test that should pass and watching it fail with `datetime.X > datetime.X` was a clean reminder that "the trigger fires" and "I can observe it fire" are different claims, and the test infrastructure can have its own opinions about which.
- **The frontend was a non-event.** I'd half-expected to find some consumer that re-derives the marker (a Markdown post-processor, a stylesheet selector, an i18n key with the marker baked in) and would have caused a stop-the-line if it disagreed with `ABOUT_MARKER_EN`. The actual consumers all read a backend-computed boolean; the only place the marker string is materialized in the FE is the CSS comment at `index.css:103` and a JSX comment at `ArticleContent.jsx:16`, neither of which is functionally load-bearing. The CSS styling targets `<strong>About this Article</strong>` rendered HTML, not the marker string in the source markdown — different layer. A read-only verification, exactly as Phase 1 predicted.
- **The session was uneventful, and that's the point.** Session 02 had a stop-the-line incident, a prod touch with two explicit-approval moments, and a fence fire on the wrong-shape `pg_dump`. Session 03 had none of those — and that's because the prod data was already clean from session 02, the policy decision was already made (refuse-on-rerun, single PR), and the code change is a refactor with a small surface tweak. The cumulative effect of session 02 doing the messy half is that session 03 was a straight line. Worth noting for future cleanups-then-refactors: paying off the manifested corruption first, even if it duplicates some safety-net code temporarily, makes the structural fix dramatically simpler to reason about.

---

## Cross-cutting checklist dispositions

This is a fix-execution session, not an area audit, so most checklist items are N/A or "checked, absent." Recording the ones that *did* fire or were materially checked:

- **Two-dimensional severity: blast-radius × evidence-of-impact (synthesis §8).** The 400-vs-200 sub-decision in Phase 1 was a tiny-blast-radius / clear-evidence question. Evidence was three lines of code at three different file:line locations, all agreeing. Blast-radius of getting it wrong was small (FE handles both shapes), but the consistency win is real and the cost of verification was negligible. Disposition: **fired clean; trivially.**
- **Danger is not where complexity is (synthesis §8).** Most of the complexity in this session was in the loop-folding in commit 2 (the safety-net dict pre-load + dual-pass iteration). None of it was load-bearing for correctness — the ORM mutation is structurally indistinguishable from the raw-SQL UPDATE in terms of outcome (same bytes, same column writes, different SQL plan, plus the trigger fires). The risky part — the surface change in commit 3 — was a 30-line diff with a clear before/after invariant. Disposition: **complexity and danger lived in different commits; risk was correctly localized to commit 3 and tests covered it.**
- **Partial-correction debt umbrella.** Session 02 was a partial correction; this session is its completion. The umbrella closes with #99. The session-02 outcomes-log row stays as `clean-merge`; this session adds the `99 (full)` row. The umbrella's risk (deferred work staying deferred indefinitely) was managed by the cross-session register and the agent-friendly-outcomes log carrying the breadcrumb. Disposition: **closed clean; umbrella discharged.**
- **Latent-but-uncrystallized risk.** Two from session 02 remain uncrystallized: the `docker.sock` test-infra issue and the wider-backend ruff debt. Both noted in "What's next §3" above. A third joins them this session: the transaction-fixture `updated_at`-observability issue. None blocking; all worth a follow-up file. Disposition: **three surfaced; deferred to follow-up filings.**
- **Swallowed-failure umbrella.** N/A this session — the policy change is the opposite of swallowing: a previously-200/false tuple becomes a raised 400 exception. More fail-loud, not less. The dropped `updated_at` test was *removed* with a written note, not silently `xfail`ed.
- **Agent-friendly grading prior (synthesis §10).** Filed `agent-friendly: no` for #99, citing the policy decision and the non-trivial refactor. The actual outcome this session: planning was 5 minutes (the policy was pre-decided by the operator), implementation was a 5-commit straight line, no escalations, one minor dropped test. If the operator hadn't pre-decided the policy in the prompt, this would have been an agent-friendly:no for sure. With the policy pre-decided, the *code* portion was agent-friendly in retrospect — the kind of pattern-matching refactor a clear brief can scope tightly. The grading prior held up for the issue as filed; the in-session work was an "agent-friendly if you've already done the planning for it" specimen. Disposition: **filed-grade was correct for the issue; in-session execution was easier than the file-time grading suggested, because session 02 + the prompt did all the heavy planning.**

---

## Cross-references

- Phase 1 synthesis: `docs/pilot/phase-1-synthesis.md` (especially §8 two-dimensional severity, §10 falsifiability hook)
- Phase 1 Area 4b-2 report (the audit that surfaced #99): `docs/pilot/phase-1-area-4b-2-report.md`
- Session 01 report (planning): `docs/phase-2/01-kickoff-report.md`
- Session 02 report (partial fix): `docs/phase-2/02-articles-39-40-cleanup-report.md`
- Session 03 prompt: `docs/phase-2/prompts/03-issue-99-full-fix.md`
- Outcomes log: `docs/phase-2/agent-friendly-outcomes.md`
- Cross-session register: `docs/methodology/cross-session-register.md`
- GitHub: issue #99; PR [#137](https://github.com/wanderindev/panama-in-context/pull/137); previous PR [#134](https://github.com/wanderindev/panama-in-context/pull/134)
