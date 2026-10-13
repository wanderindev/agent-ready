# Phase 2 — Session 02: Articles 39/40 production content cleanup + safety-net refusal

## Identification

You are running **Phase 2 Session 02** of the Panama In Context (PIC) audit-and-fix pilot. Phase 0 (baseline + safety nets) is done. Phase 1 (the area-by-area audit) is done and produced a labelled backlog of 108 open issues. Phase 2 is the **fix-execution** phase — it produces code changes through PRs, exercises the auto-approve fence operationalized in session 01, and runs the four-track Wave 1 the synthesis identified.

This is the **first Phase 2 fix-work session** (session 01 was planning-only). The Phase 2 working model — prompt-preservation under `docs/phase-2/prompts/`, session reports at `docs/phase-2/NN-*-report.md`, the agent-friendly-outcome log, the cross-session register, the auto-approve fence — is already in place. Read session 01's report to understand the model you're operating inside.

You are running in a **fresh Claude Code instance**, separate from the orchestrator's main session. That separation is deliberate — the orchestrator is preserving their context window so they can review your work and brief subsequent sessions. **Do not assume any conversational context.** Everything you need is in the files this prompt points at; the repo is the source of truth.

## Read these first, in order

Read each one fully before proposing a plan. Don't skim.

1. **`docs/phase-2/01-kickoff-report.md`** — session 01's planning report. Pay attention to §"Part B — Front-loaded plans / B.1 — Articles 39/40 production content cleanup plan" (the four-phase plan you'll execute), and the two operator decisions: **bundle** the safety-net idempotency refusal into the same PR, and use a **script** rather than manual admin-UI editing.
2. **Issue #99** — run `gh issue view 99`. Read the full body. Pay attention to: the corruption shape (`UPDATE articles SET content = :about_en || content || :continue_en`); the "This has already happened in production" section (articles 39 + 40, doubled markers in EN and ES); the "Desired state" section (idempotency guard, raw-SQL→ORM cleanup, one-time content cleanup); the "Is this agent-friendly? No" note (this is operator-driven, not autonomous-agent work).
3. **`docs/pilot/phase-1-area-4b-2-report.md`** — the audit that surfaced #99. Gives the flow-traffic context (series-sections ran on all 51 published articles; only articles 39+40 doubled), and the synthesis §8 "danger is not where complexity is" framing.
4. **`backend/app/services/series_sections.py`** (full file) — the service you'll add the refusal to. Note especially `SeriesSectionGenerator.generate_about_section` (lines ~146-184), `.generate_continue_reading_section` (lines ~186-219), `.generate_sections_for_series` (lines ~221-277, the method with the unguarded raw-SQL UPDATE), and `.can_generate_sections` (lines ~107-144, the existing precondition-check method).
5. **`backend/app/models/article.py`** — the `Article` model. Note `content` and `content_es` as `Text`, `series_parent_id` / `series_order` for series traversal.
6. **`docs/phase-2/agent-friendly-outcomes.md`** — the outcomes log format. You'll append one row when the PR opens.
7. **`docs/methodology/cross-session-register.md`** — only relevant if you make a cross-session decision during this session (e.g., re-scope, stop-the-line, methodology insight worth recording). Most fix sessions don't generate register entries; don't force one.
8. **`CLAUDE.md`** (project root) — project conventions. Especially the "Use SQLAlchemy ORM, not raw SQL" rule (the refusal logic must follow this), the Docker-based dev workflow, and the testing requirement ("New endpoints MUST have corresponding tests").
9. **`.claude/settings.json`** — the auto-approve fence's deny rules. Note that prod DB access (anything matching `*ondigitalocean.com*`, `*:25060*`, or the `AVNS_*` credential prefix) is denied at the Bash level, as are `gh pr merge*`, force-pushes, pushes to main/master, bare `alembic upgrade*`, prod registry pushes, mass deletion, and `.env*` writes. **These will fire and require explicit operator approval if you try to run a denied command.** That's the fence working as designed — surface for approval, don't fight it.

## Why this session matters

Issue #99 is the **only Phase 1 critical with confirmed live production impact** — synthesis §8's two-dimensional severity check fired in the direction of "this one is real, not latent." Articles 39 and 40 currently render doubled "About this Article" / "Continue Reading" navigation blocks (and their Spanish equivalents) on the public site. The bug also recurs on any re-trigger of the `series-sections` endpoint.

This session ships the two-part remediation:

1. **The safety-net refusal** — `series_sections.py` should refuse to (re-)generate sections if any article in the series already carries the about-marker. Prevents recurrence between this PR and the eventual full #99 code fix.
2. **The one-off cleanup script** — removes the duplicate blocks from articles 39 and 40 in production via an idempotent, dry-run-defaulting, ORM-based script.

Bundled into one PR per the operator's session 01 decision.

This session is **not the full #99 fix.** That fix involves a policy decision (refuse-on-rerun vs. strip-and-replace) and the raw-SQL→ORM refactor of `generate_sections_for_series`. Both are deliberately scoped *out* of this session — they need a longer design conversation. The safety-net is a holding pattern, not the proper fix.

## Scope

### IN scope

- Add an idempotency guard to `SeriesSectionGenerator.generate_sections_for_series` (and/or `can_generate_sections` — choose the cleaner shape) that detects if any article in the series already carries either the EN about-marker (`**About this Article**`) or the ES about-marker (`**Acerca de este artículo**`) in its `content` or `content_es`, and refuses cleanly. Follow the existing `tuple[bool, str, int]` return convention (return `(False, "<descriptive>", 0)` rather than raising) so the existing endpoint surface continues to render 400-shaped error responses without further changes.
- Unit tests for the refusal. At minimum: one test for the EN-marker-present case, one for the ES-marker-present case, one for the happy-path (no markers, generation proceeds). Mock the DB session per project conventions (see existing tests in `backend/tests/`).
- One-off cleanup script: `scripts/one_off/cleanup_articles_39_40.py`. Spec below.
- A `scratch/` directory at repo root + a `scratch/` entry in `.gitignore`. The cleanup script writes its timestamped pre-update backup of the four affected columns to `scratch/`. This becomes a project convention going forward; don't commit anything inside `scratch/`.
- One row appended to `docs/phase-2/agent-friendly-outcomes.md` **when the PR opens** (not at merge — the convention is PR-open so closed-without-merge issues still appear). Mark `Agent attempted?` as `pair` (this is operator-with-Claude, not autonomous), `Filed agent-friendly?` as `no` (per #99's own body).
- Session report at `docs/phase-2/02-articles-39-40-cleanup-report.md` at end of session. Follow the shape of `docs/phase-2/01-kickoff-report.md` (executive summary, by-the-numbers, what was done, what's next, process notes, what surprised me, cross-cutting checklist dispositions).

### OUT of scope (do NOT touch)

- The full #99 code fix — the refuse-vs-strip-and-replace policy decision, the raw-SQL→ORM refactor of `generate_sections_for_series`. Future PR.
- Any other Phase 1 backlog issue. If you notice another bug during this work, surface it; do not file or fix it.
- `dashboard.py` (the endpoint) — unless the refusal's `(False, msg, 0)` return shape isn't already being handled correctly by the endpoint. Verify before changing; existing similar refusals (e.g., "Series not found...") should already be wired.
- The frontend `has_series_sections` UI gate. That's part of the full #99 fix.
- The `_generate_references_section` duplication (#103) and other Area-4b-2-adjacent issues.
- Any change to `backend/app/services/research.py` or `edu_research.py`.

## Plan — four phases, gated step-by-step

### Phase 1 — Local prep (no prod touch, no code writes until approved)

1. Read the inputs above.
2. Confirm the corruption shape: review `generate_sections_for_series` and verify the duplication is `about_v1 + about_v2 + REAL + continue_v1 + continue_v2` per the issue body.
3. Produce a **plan** that specifies:
   - The refusal's API shape — where in `series_sections.py` it goes, what it returns, what markers it checks, what it does about `content_es` being optional (some articles may not have Spanish content yet).
   - The cleanup script's structure — CLI flags, the DB-URL source (env var), the dry-run default, the assertion guards, the backup format, the ORM update pattern.
   - The unit test list — which cases, what mocks.
   - The local dry-run procedure (database-ops skill use, restore-to-local, run script, verify markers).
4. **Surface the plan and WAIT for operator approval before any code write.**

### Phase 2 — Local implementation + dry-run (no prod touch)

Once Phase 1 is approved:

1. Create the feature branch: `fix/issue-99-articles-39-40-prod-cleanup`.
2. Implement the safety-net refusal in `series_sections.py`. Add unit tests. Run them locally: `docker-compose exec backend pytest backend/tests/...` Until they pass.
3. Implement the cleanup script. Skeleton requirements:
   - Argparse CLI with `--dry-run` (default `True`), `--no-dry-run`, `--confirm-prod` (required when `--no-dry-run` is set AND `DATABASE_URL` points at a non-local host — a defensive sanity check).
   - Reads `DATABASE_URL` from env. Refuses to run if env is empty.
   - Logs the target host (parsed from the URL) at the top so the operator can confirm. Never logs the password.
   - Connects via SQLAlchemy session (the project's existing `get_db` pattern or a session-maker — match the codebase).
   - For each `(article_id ∈ {39, 40}, lang ∈ {"en", "es"})`:
     - Loads the article + series state.
     - Uses `SeriesSectionGenerator` to regenerate the canonical `about_section` for that (article, lang).
     - Uses `SeriesSectionGenerator` to regenerate the canonical `continue_section` for that (article, lang) — `None` for article 40 (last in series, no next).
     - Reads current `content` (or `content_es`).
     - **Asserts** that the canonical `about_section` appears exactly 2 times in the column.
     - **Asserts** that the canonical `continue_section` appears exactly 2 times (article 39) or 0 times (article 40 — last in series).
     - Computes the cleaned string: `cleaned = content.replace(about_section, "", 1)` (removes first occurrence); for the trailing continue, `if cleaned.endswith(continue_section + continue_section): cleaned = cleaned[:-len(continue_section)]`.
     - **Re-asserts** the marker count reduced to exactly 1 (about) and 1/0 (continue).
     - In dry-run mode: prints a diff (or first 300 + last 300 chars before/after); does NOT write.
     - In write mode: writes a timestamped JSON backup to `scratch/cleanup_articles_39_40_<timestamp>.json` BEFORE the UPDATE; uses ORM (`db.add(article)`, `db.commit()`) — not raw SQL.
4. Use the `database-ops` skill to pull a fresh prod DB backup and restore it to local. (The skill manages the prod-read as a gated operation; the deny rules in `.claude/settings.json` will let it through because it's the skill mediating.)
5. Run the script with `--dry-run` against the local restored DB. Inspect the printed diffs against expected shape (one about-block removed at the start; for article 39 only, one continue-block removed at the end). Surface the diff output for operator review.
6. Run the script with `--no-dry-run` against the local restored DB. Verify the asserts pass and the post-cleanup column has marker count 1.
7. Surface dry-run + local-write results to the operator and **request approval for prod execution.**

### Phase 3 — Production execution (gated, explicit approval required)

Once Phase 2's results are approved:

1. **Re-verify the script's safety**: the `--confirm-prod` flag is set; the target host is logged; the backup file path is shown before any UPDATE.
2. Run the script against prod. **The auto-approve fence's deny rules will fire** (any command containing the prod host or AVNS_ credential is denied) — surface the command for explicit per-invocation approval. The operator types yes.
3. After the script reports success, run a marker-count verification query (via database-ops skill) against the four affected columns. Confirm each marker appears exactly once (or zero for article 40's continue blocks).
4. Spot-check the rendered pages by fetching them: `/en/articles/{slug-of-39}`, `/es/articulos/{slug-es-of-39}`, same for article 40. Either curl or open in a browser; eyeball the rendered HTML for clean nav blocks.

### Phase 4 — PR + housekeeping

1. Commit the implementation in logical chunks (suggested: one commit for the refusal + tests, one for the script + .gitignore update). Use the same commit-message style as session 01's PR #133 (subject in conventional-commit form; body explains the why; `Co-Authored-By: Claude` trailer).
2. Push the branch. Open a PR. **Do not merge.** Operator merges.
3. The PR description must include a **"Production touch: yes — gated by:"** line per Phase 2 working-model L3 (synthesis §5 fence layer 3). Specify what gated it (the database-ops skill, the deny-rule prompts, etc.).
4. **Append a row** to `docs/phase-2/agent-friendly-outcomes.md` when the PR opens. Use:
   - Issue #: 99
   - Filed agent-friendly?: `no`
   - Filed severity: `critical`
   - Track: `article`
   - Agent attempted?: `pair`
   - PR #: (the newly opened PR number)
   - Outcome: `not-yet-attempted` (the operator hasn't merged yet — update this column when the PR moves)
   - Reviewer interventions: leave as `—` until operator review concludes
   - Notes: one-line summary of what was easier/harder than expected
5. **Comment on issue #99** linking the PR. Note that the PR is *partial* — content cleanup + safety-net refusal — and the full code fix (refuse-vs-replace policy + raw-SQL→ORM) is still outstanding.
6. Write the session report at `docs/phase-2/02-articles-39-40-cleanup-report.md`. Use session 01's report as a shape template. Include a Cross-cutting checklist dispositions sub-section (most items will be N/A or "checked, absent" — that's fine; the discipline is in checking).
7. If the session generated any cross-session decision worth recording (e.g., methodology insight, re-scope, stop-the-line), append a row to `docs/methodology/cross-session-register.md`. If not, don't force one.
8. Save THIS prompt verbatim — it's already at `docs/phase-2/prompts/02-articles-39-40-cleanup.md` (the orchestrator wrote it). Confirm it's present and update `docs/phase-2/prompts/INDEX.md` to add an entry for session 02 pointing at this prompt and the produced report.

## Production data access policy

Every prod-touching step (read OR write) is gated:

- **Reads of prod data**: route through the `database-ops` skill. Direct `psql` / `pg_dump` against the prod host is denied by `.claude/settings.json` — that's by design. The skill is the in-the-loop gate.
- **Writes to prod**: the cleanup script's `--no-dry-run` invocation against the prod DB is the only production WRITE in this session. It will trip the deny rules; surface for explicit per-invocation approval from the operator. Do not retry the command in a loop; one approval per invocation.
- **No row-level PII pulled into context**: the affected columns are `articles.content` and `articles.content_es`. These are published blog content — public, not PII. Still, do not paste full column dumps into chat; reference them by row+column and use diffs / first-N + last-N chars when you need to surface something.
- **Backup before write**: the timestamped JSON to `scratch/` is mandatory, not optional.

## Working style

- **Gate-at-each-prod-step.** Phase 1 → Phase 2 → Phase 3 → Phase 4, each separated by an explicit operator approval surface. Don't roll multiple phases into a single "I'll just do it all and report at the end" pass — that defeats the fence.
- **Don't expand scope.** If you notice the full #99 fix would only take "a bit more time", do NOT expand. The whole point of bundling only the safety-net is to keep this PR small and reviewable. Surface the temptation as a process note in the session report; let the operator decide whether to follow up.
- **ORM, not raw SQL.** The refusal logic and the cleanup script's UPDATE both go through the ORM. This is doctrinal (CLAUDE.md says so) and also load-bearing for this fix specifically (raw-SQL string concatenation is what *caused* #99).
- **Pre-condition asserts are loud.** If the script's marker-count asserts fail (e.g., the script expects 2 of a marker and finds 1 or 3), STOP. Surface the unexpected state. Do not "fix" it heuristically. The asserts existing is what makes the script safe.
- **Tests pass locally before push.** `docker-compose exec backend pytest` and `docker-compose exec backend ruff check /app` both clean before pushing the branch.
- **PR opened, not merged.** Operator merges. The `gh pr merge*` deny rule in the fence will block you anyway; don't fight it.
- **One row in the outcomes log when the PR opens.** Not at merge. This is the synthesis §10 falsifiability instrumentation — the data is only useful if it captures the closed-without-merge case too.

## Stop-the-line triggers

Concrete, not abstract. If any of these fire during the session, STOP and surface immediately:

- The script's pre-condition asserts fail (marker count is not exactly 2 in any of the four affected columns). Stop. Don't run the cleanup. The corruption shape isn't what the issue body and the audit described; we need to understand why before any UPDATE.
- The local dry-run output doesn't visibly remove the duplicates. Stop. The cleanup logic isn't right.
- A prod-touching command is approved by the operator and produces an error you don't understand. Stop. Surface the full error.
- The `series-sections` endpoint is hit during the session by anyone (you, the operator, a stale browser tab). The deny rules don't catch endpoint calls — this is a discipline-not-gate area. If it happens, halt and re-check articles 39+40's state.

## Scope estimate

~1 session, 1 PR. ~3-5 commits in the PR. No follow-up issues expected — the full #99 code fix remains open as a separate future-PR item, and this session's PR does NOT close #99 (it closes only the content corruption + adds a safety net). Comment on #99 noting what shipped vs what remains.

If the session is approaching its third hour without prod execution having happened, something is wrong — surface for re-scoping.

## Begin by

1. Read the inputs in the order listed in "Read these first." Don't skim. Don't start writing code.
2. Confirm against the actual `series_sections.py` that the marker strings and the duplication mechanism match what the issue body and Area 4b-2 report describe.
3. Produce a Phase-1 plan with: the refusal's exact API shape (method signature, return shape, marker checks); the cleanup script's CLI shape and flow; the unit-test list; the local dry-run procedure.
4. **Wait for operator approval on the Phase-1 plan before any code write.** The plan goes to the operator; the operator approves or pushes back; then Phase 2 begins.
