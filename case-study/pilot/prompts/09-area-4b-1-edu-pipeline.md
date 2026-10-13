We're starting Phase 1 Part B Area 4b-1: Edu pipeline audit.

This is the last of three Area 4 sessions, split into two:
- 4b-1 (this session): edu pipeline — research → study guides → slides
  → watermarking → media library
- 4b-2 (next session): article pipeline — suggestions → research →
  article writing → translation → publication

4a produced the service surface map and vendor failure-mode summary.
4c produced the swallowed-exceptions catalogue and the wrapper-contract
analysis. Both are inputs to this session, not work to redo.

Read these first:
- docs/pilot/phase-1-area-4a-report.md, especially the service surface
  map (the 4a/4b split is locked there) and vendor failure-mode summary
- docs/pilot/phase-1-area-4c-report.md, especially the methodological
  notes on what 4b should pick up
- Issues #67, #70, #74, #76, #77, #83, #84, #85 — the wrapper-contract
  and pattern-standardization cluster from 4a and 4c
- The "newly observed for 4b" subsections of every prior area report

## Why this area matters

The edu pipeline is the project's most ambitious feature: it takes a
suggested edu material, runs deep research, drafts study guides and
slides, watermarks them, and pushes them through the media library.
It's also where the LLM orchestration gets most complex — multiple
sequential prompts, large outputs, the long-research-doc workaround
mentioned in project memory, and the most LLM-call-dense module in
the codebase (`edu_material_generation` with 4 separate
`messages.create` calls).

If the wrapper-contract work in 4a/4c is the structural diagnosis,
this audit is the domain diagnosis: where does the edu pipeline's
specific orchestration fall down, what's its actual failure shape,
and how would a fully autonomous "produce N edu materials per week"
flow break in practice.

## Scope

In-scope modules (the edu cluster):
- `backend/app/services/edu_research.py`
- `backend/app/services/edu_material_generation.py`
- The watermarking helpers (`watermark_infographic`,
  `watermark_slides`) — locate them; they may be in `image_storage.py`
  or in a separate watermarking module
- `backend/app/services/media_scoring.py` (used by media library;
  it's used by the edu pipeline downstream)
- The edu router (`backend/app/api/edu.py`) — the orchestration
  entry points
- Any edu-specific Pydantic schemas
- Cross-references into models touched by the pipeline (EduMaterial,
  EduResearch, EduSuggestion, MediaCandidate)

Explicitly NOT in scope this session (4b-2 territory):
- `article_generation.py`
- `research.py` (blog research, distinct from `edu_research.py`)
- `research_summary.py`
- `suggestion_generation.py`
- `image_prompt.py`
- `series_sections.py`
- `translation.py` (already audited 4a)

If you find a module that's hard to classify as edu vs article (e.g.
`media_scoring.py` is used by both), audit it here and note that 4b-2
should reference rather than re-audit it.

## What to look for

**LLM orchestration**
- Multi-step prompt chains: what fails between steps? If step 2
  fails after step 1 succeeded, is step 1's output recoverable
  or lost?
- Token-budget choices: `max_tokens` per call, thinking budget
  if set, whether they're consistent within the pipeline
- Prompt construction: where does user input enter the prompt?
  Is there any injection risk into the LLM prompts themselves
  (a different problem from HTML injection — LLM prompt injection
  via attacker-controlled fields)?
- The long-research-doc workaround mentioned in project memory:
  what is it, where does it live, and is it documented anywhere
  beyond the implementation?
- Defensive parsing: per 4c's findings, `edu_material_generation.
  _parse_outline_response` is the template. Compare the rest of
  the pipeline against it.

**Pipeline state and recovery**
- If the pipeline runs for 5 minutes and fails at minute 4, what's
  the state? Half-finished EduResearch row? Orphan MediaCandidate
  rows? A study guide draft with no slides?
- Is there a "resume from step N" path, or does failure require
  starting over?
- The `stats["errors"].append` pattern from 4c — does the edu
  pipeline use it, or does it fail-fast on first error?
- Concurrency: can two edu material generations run in parallel?
  If yes, do they share any state that could conflict?

**Watermarking**
- Watermarking lives between LLM-produced artifacts and the media
  library. What happens if watermarking fails? Is the unwatermarked
  artifact discarded, kept, or stored unwatermarked?
- PyMuPDF / Pillow failure modes: per 4a, the `MAX_IMAGE_PIXELS`
  is relaxed (filed as #81). What other ways can watermarking
  break, and does the pipeline handle them?
- Is the watermarking step idempotent? Re-running on an already-
  watermarked artifact — does it double-watermark, no-op, or
  silently corrupt?

**Media library integration**
- MediaCandidate creation: when does it happen in the pipeline?
  What if the candidate is created but never approved?
- The `media_scoring.py:117` broad catch (now filed as #85) —
  what's the blast radius when scoring aborts mid-run?
- LOC + Wikimedia crawlers (filed under #73): does the edu
  pipeline call them synchronously, async, or queue them?

**Outputs and side effects**
- DB writes: which model fields get updated when, and in what
  transaction scope?
- File outputs: where do study guides and slides land
  (DO Spaces? local disk? attached to DB rows)?
- Notifications: does the edu pipeline notify anyone on completion
  or failure? (Likely no, given 4a found `request_followup_email`
  uncalled — there may be a parallel gap.)

**Cost awareness**
- The edu pipeline is the most LLM-spending-heavy flow in the
  codebase. A full edu material generation run: how many calls,
  to which models, with what token budgets? Estimate the cost per
  run from the code (not from prod data — this is code-reading).
- Are there guards against runaway loops or accidental
  re-triggering?

**Things from earlier areas to verify**
- 4a flagged that `edu_material_generation` has the most LLM
  calls of any module. Verify the call count, and document the
  call graph.
- 4a flagged `EduMaterial.material_type` is plain `String(20)`
  with no enum. Confirm the canonical set of expected values
  during this audit.
- 4a's "newly observed" flagged `EduMaterial`'s two optional FKs
  (research_id to edu_research, blog_research_id to research) as
  modeling a discriminated union without a discriminator column.
  Confirm whether the service-layer code can produce a row with
  neither populated.

## Working style

- **Batch-and-confirm** as in all previous audit sessions.
- **Severity calibration:** A pipeline-state-corruption bug
  (half-completed run leaves DB in inconsistent state) is critical.
  An unbounded-cost runaway risk is critical. A missing recovery
  path that forces start-over on transient failures is moderate.
  Inconsistent token budgets that produce minor quality drift are
  nice-to-have.
- **Agent-friendly calibration:** Domain-pipeline changes are
  rarely agent-friendly because they typically require understanding
  the pipeline's intent. Cosmetic refactors and single-file
  prompt-cleanup tasks might qualify. Apply the six-checkbox gate
  honestly.
- **Stop-the-line:** If you find a pipeline bug that's actively
  corrupting data in production (e.g. EduResearch rows are getting
  silently overwritten), or a path where attacker-controlled input
  reaches LLM prompts in a way that could exfiltrate prompt
  context, surface immediately.
- **Don't re-audit wrapper concerns.** Exception handling,
  swallow patterns, and wrapper contracts are 4a/4c territory.
  This session is for orchestration, state, and domain logic.

## Production data access

Following the pattern from previous areas: surface for explicit
approval before any prod query. Aggregates only — no PII or
content from `edu_research`, `edu_material` body fields. Useful
aggregate queries might include: count of edu_material rows by
status, count of orphan EduResearch rows (research without
material), distribution of EduMaterial.material_type values
(to confirm the canonical set), count of edu materials with
blog_research_id vs research_id vs both vs neither.

## NEW for this session: fix-ordering analysis

This is a new section relative to previous reports. We now have
~76 open issues across Phase 1 and a real question of what to
fix first. The 4b-1 audit is the right place to introduce
fix-ordering output, because the edu pipeline has clear
dependencies (LLM wrapper before pipeline cleanup before
watermarking improvements) that exemplify the kind of structure
the rest of the backlog likely has.

In the end-of-session report, add a section called **"Fix
ordering for edu pipeline."** It should:

1. List every open issue currently filed that touches the edu
   pipeline directly (audit-related or otherwise — pull from
   the full GitHub issues list)
2. Group them by what they unblock and what unblocks them
3. Propose a sequence: which to fix first, which can run in
   parallel, which are blocked on others
4. Highlight any issue where fixing it changes the scope of
   another issue (the 4c-flagged "#76 first means #85's fix
   shrinks" pattern is the template)
5. Flag dependencies that cross domains — e.g. the edu
   pipeline depends on Anthropic wrapper work (#76) which is
   shared with the article pipeline; whoever fixes #76 affects
   both 4b-1 and 4b-2 cleanup

This section is the proof-of-concept for the Phase 1 final
report's fix-sequence framework. If it lands well, 4b-2 and the
final report will inherit the format.

## End-of-session report

Save as `docs/pilot/phase-1-area-4b-1-report.md`. Same shape as
previous reports.

Required sections:
- Executive summary
- By-the-numbers
- What was audited
- Item-by-item findings
- Stop-the-line discussion
- What's filed vs deferred
- Newly observed (for 4b-2, and any other areas)
- What surprised me
- Process notes for the next session
- **NEW: Fix ordering for edu pipeline** (per above)

The fix-ordering section is the most novel deliverable from this
session. Don't shortcut it.

## Scope estimate

The edu pipeline is the more complex of the two domain clusters.
Expect 2-2.5 hours of focused work and 8-12 issues filed. The
upper end of that range is more likely than the lower, given the
pipeline's complexity. If you're approaching 20+ findings, you've
probably drifted into article-pipeline or wrapper-redo territory
— stop and re-scope.

Begin by:
1. Reading the 4a and 4c reports' relevant sections
2. Producing the edu-pipeline call graph (which modules call
   which, in what order, with what data flowing through)
3. Confirming the in-scope module list against the actual
   directory (the watermarking helpers' location especially)
4. Proposing a session structure (probably: call-graph first,
   then per-stage audit walking the pipeline from research →
   slides, then state/recovery analysis, then fix-ordering)

Wait for my approval on the call-graph and structure before
starting the per-stage audit.
