# Fix-ordering analysis

## Purpose

A per-area dependency analysis that orders the area's open issues into waves, with explicit attention to **where fixing one issue changes another's scope** (not just where it blocks another's start). Produced when an area's backlog is large enough that the order in which issues are addressed materially affects the cost and shape of the work.

The analysis encodes two distinct judgments:

1. **Sequencing** — what must land before what (the dependency dimension).
2. **Scope reshape** — where fixing X *shrinks* Y (the leverage dimension).

The scope-reshape column is the one most absent from a typical backlog ordering. The pilot's worked example: fixing #76 (unified Anthropic wrapper) shrinks #93 from "add a truncation guard + bump max_tokens" to "bump max_tokens 4096 → 8192." That kind of leverage is what the fix-ordering analysis exists to surface.

## When it's produced

In any area whose backlog is large enough that order matters, AND when the team owning the area can choose the order (not when external constraints have already imposed it). The pilot instances:

- **Area 4b-1 (edu pipeline)** — introduced the format mid-audit, as proof-of-concept (synthesis §3 and §9).
- **Area 4b-2 (article pipeline)** — applied the format to the second pipeline, with the "Toward a global fix ordering" bridge section appended.
- **Area 5 (frontend public)** — applied it to the third area; the composition pattern was stable by this point.
- **Area 6 (admin CMS)** — fourth and final per-area fix-ordering, completing the four-track Wave 1 the synthesis describes.

## What triggers it

- The area's backlog is 8+ open issues.
- At least 2 issues in the area have clear prerequisites in the same area.
- The team is choosing the order, not having it imposed.

If the backlog is small (≤6 issues) and dependencies are obvious, the fix-ordering analysis is over-engineered for the situation. Surface dependencies inline in the item-by-item-findings section instead.

## Template

The analysis has these sub-sections, in order:

### Sub-section 1 — Issues in scope

Two lists:
- **Filed this session** — the issue numbers and one-line titles.
- **Pre-existing issues that touch this area** — issues filed in earlier sessions or in Phase 0 that the fix-ordering must integrate.

Plus, when applicable: **Not in scope** — issues the scope brief assumed touched this area but the audit confirmed do not. (The pilot's 4b-1 example: `media_scoring.py` was assumed to touch the edu pipeline but the audit confirmed it doesn't.)

### Sub-section 2 — Dependency structure

An ASCII diagram showing the dependency graph among the in-scope issues. Distinguishing visual elements:

- **Foundations** — issues with no dependencies that everything else builds on.
- **Critical path** — sequential chains where each issue blocks the next.
- **Parallel track** — issues with no blockers, fixable anytime.
- **"Reshapes"** arrows — issues whose landing changes the *scope* of another issue, not just the schedule.

### Sub-section 3 — Proposed sequence

A wave-by-wave proposal:

**Wave 1 — Foundations.** Issues that unblock everything else. Often 2-3 items, ideally independent of each other.

**Wave 2 — Critical path.** Sequential chains that need to be done in order, after Wave 1 lands.

**Wave 3 — Cleanup.** Issues whose scope reshapes after the foundation/critical-path work, so they're cheaper to do here than first.

**Parallel track.** Issues with no blockers, fix anytime.

For each wave, one-paragraph explanation of *why* the issue lands here. Specifically: which prerequisite it needs, OR which downstream issue it unblocks/shrinks.

### Sub-section 4 — Where fixing one issue changes another's scope

This is the section that distinguishes a fix-ordering analysis from a simple dependency diagram. For each pair where fixing X reshapes Y's scope:

1. Name the pair: `#X → #Y`.
2. State the reshape: "If #X lands first, #Y shrinks from {original scope} to {reduced scope}."
3. State the consequence if X is delayed: what #Y looks like if it's done before #X.

### Sub-section 5 — Cross-domain dependency callout

When the area's dependencies extend into other areas' backlogs, name them explicitly. The cross-domain callout is what makes the global ordering composable — see [global-ordering-bridge.md](global-ordering-bridge.md).

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from an edu-pipeline area report (full instance in the case study, `case-study/pilot/phase-1-area-4b-1-report.md`), abridged:

```
### Issues in scope

Filed this session (4b-1): #87, #88, #89, #90, #91, #92, #93, #94, #95, #96, #97.

Pre-existing issues that touch the edu pipeline:
- #76 — unified Anthropic wrapper (shared with article pipeline)
- #77 — defensive LLM-response parsing
- #78 — Anthropic budget cap / observability
- #68 — no SDK timeouts
- #81 — watermark_infographic relaxes Pillow MAX_IMAGE_PIXELS
- #83 — generate_thumbnail swallow
- #8 — swallowed-exceptions catalogue

Not in scope: #85 (media_scoring) — confirmed decoupled from the edu
pipeline despite the scope brief's assumption.

### Dependency structure

                ┌─────────────────────────────────────┐
FOUNDATION      │  #97 unique constraint                │  #76 Anthropic wrapper
(do first,      │  (research_id, material_type,         │  (cross-domain — shared
 parallel)      │   grade_band)                         │   with 4b-2)
                └──────────────┬────────────────────────┘            │
                               │                                     │
CRITICAL PATH                  ▼                          reshapes ──┼──────────┐
(sequential,            ┌────────────────┐                           ▼          ▼
 after #97)             │ #91 regen guard │                        #93        #77
                        │   (CRITICAL)    │                       (shrinks)  (becomes
                        └───────┬─────────┘                                  wrapper work)
                                │                                     │
                                ▼                                     ▼
                        ┌────────────────┐                          #78 budget cap
                        │ #90 per-band    │                           │
                        │   commit        │                           ▼
                        └─────────────────┘                          #92 (becomes
                                                                       belt-and-suspenders)

PARALLEL TRACK (independent — no blockers, fix anytime):
  #87 explicit suggestion_id   #88 overwrite policy   #89 upload size limits
  #94 watermark/type validation   #95 XOR constraint   #96 dead table
  #68 timeouts   #81 MAX_IMAGE_PIXELS   #83 thumbnail swallow

### Proposed sequence

Wave 1 — Foundations:
  1. #97 — unique constraint on (research_id, material_type, grade_band).
     Pure Alembic migration; production data is already clean. First fix
     despite being only moderate, because it unblocks the critical #91
     and the recovery fix #90.
  2. #76 — unified Anthropic wrapper. Cross-domain foundation. Sequence
     it as a shared piece — whoever does it should coordinate with 4b-2.

Wave 2 — Critical path (sequential, after #97):
  3. #91 — regeneration guard (CRITICAL). Needs #97's well-defined key.
  4. #90 — per-band commit. After #91, because per-band commit changes
     what a failed run leaves behind.

Wave 3 — LLM-quality cleanup (after #76):
  5. #77 — defensive parsing folds into the wrapper.
  6. #93 — outline truncation: if #76 lands first, this shrinks to a
     one-line max_tokens bump.
  7. #78 → #92 — #78 (central budget cap) makes #92 (local grade_bands
     cap) a belt-and-suspenders rather than the primary guard.

### Where fixing one issue changes another's scope

1. #97 → #91, #90. Adding the unique constraint is not just a
   prerequisite for scheduling — it changes the implementation of #91
   and #90. With #97 in place, the upsert can become an atomic INSERT
   ... ON CONFLICT DO UPDATE, and #91's guard and #90's per-band commit
   become straightforward and race-free. Fixing #97 first shrinks
   #91 and #90.

2. #76 → #93. If the unified Anthropic wrapper lands first, the generic
   "reject truncated responses" guard lives in the wrapper. #93 then
   shrinks from "add a truncation guard + bump max_tokens" to just
   "bump max_tokens 4096 → 8192."

3. #76 → #77. #77 (defensive parsing) substantially becomes #76 — the
   wrapper centralizes the defensive parse. Doing #77 standalone first
   means writing per-site parsing that #76 then consolidates and
   partially throws away.

4. #78 → #92. #78 (central Anthropic budget cap) is the real fix for
   unbounded edu-pipeline cost. #92 (local grade_bands length cap) is
   a stopgap.

5. #91 → #90 (policy coupling). Not a scope shrink but a scope
   dependency: #90's per-band commit means a failed run leaves
   committed rows from the successful bands. #91's regeneration guard
   is what decides whether the next run skips, refuses, or overwrites
   those rows.

### Cross-domain dependency callout

#76 and #78 are not edu-pipeline-only. They are shared with the
article pipeline (4b-2's domain). Implementing #76 affects 4b-1
cleanup (#93, #77) and 4b-2 cleanup simultaneously. The Phase 1
final report should treat #76 as a single shared foundation
scheduled once.
```

## Pitfalls

- **Treating sequencing as the whole answer.** Sequencing without the scope-reshape analysis misses the leverage. The leverage column is where the highest-value insights are.
- **Letting "everything is critical, do it all at once" be the answer.** Even when several criticals are present, the question is which one *unblocks the others' fix*. Sequence is forcing.
- **No cross-domain callout.** Foundations like a unified wrapper or a budget cap typically span multiple areas. The callout makes the global ordering possible; without it, every area schedules the foundation independently.
- **Diagram without an explanation.** ASCII diagrams that aren't accompanied by per-wave paragraphs are decorative. The proposed-sequence section is where the reasoning lives.
- **Including pure schedule dependencies without saying so.** Not every dependency is a scope-reshape. #91 → #90 is a policy coupling, not a scope shrink — and the analysis says so explicitly, which is what makes it useful.

## Cross-references

- [global-ordering-bridge.md](global-ordering-bridge.md) — the bridge section that composes multiple per-area fix-orderings.
- The synthesis's §6 (Backlog shape and parallelization strategy) consumes per-area fix-orderings into the global Wave-1 four-track structure.
