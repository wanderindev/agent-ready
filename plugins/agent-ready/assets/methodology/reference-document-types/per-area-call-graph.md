# Per-area call graph

## Purpose

A diagram of the flows inside a pipeline-shaped area, showing which modules call which others, in what order, with what data flowing through and what side effects at each step. Produced when an area is structurally a set of flows that share infrastructure but not control flow. Findings in pipeline-shaped areas live "in the seams between flows" — the call graph is what surfaces the seams.

The graph's deeper value is that it changes how the audit walks the area. Instead of walking files alphabetically, the audit walks flows. The same files get read, but in an order that surfaces the cross-flow patterns: where two flows share a wrapper but use it differently, where one flow has a guard the others don't (the partial-correction pattern), where state from flow A leaks into flow B.

## When it's produced

In areas that match these shapes:
- **Multi-stage domain pipelines** (research → content → output; suggestion → research → article → translation → publication).
- **Routing-heavy areas** where many endpoints converge on a shared service layer.
- **Background-job systems** where multiple producers feed a shared queue.

In the pilot: Areas 4b-1 (edu pipeline) and 4b-2 (article pipeline) both produced call graphs. The graph in 4b-1 surfaced the five-flow structure that became the "load-bearing structural fact" of the area.

## What triggers it

- The area has 4+ entry points (router endpoints, public functions, queue consumers) that share infrastructure (the same wrapper, the same model, the same DB table).
- Reading individual files in isolation will miss the cross-flow patterns.
- The call-graph-first adaptation is active (see [the adaptations reference](../../../skills/area-audit/references/adaptations.md)).

## Template

The graph is usually ASCII (mermaid is acceptable but ASCII renders in any markdown viewer). It has these elements:

- **One block per flow**, labeled clearly (`FLOW A`, `FLOW B`, etc., or by their domain purpose).
- **Entry point at the top** of each block (the router endpoint, the public function, the queue consumer).
- **The call chain** inside the block, indented to show nesting. Annotate calls with concrete details:
  - For LLM calls: model + `max_tokens` + whether date-pinned
  - For DB writes: which model + which transaction boundary (db.flush vs db.commit, and *where* the commit lives — service vs router)
  - For external API calls: which vendor + which endpoint
- **Side effects per step**: DB writes, queue puts, file system writes, external API calls.
- **Inline citations of filed issues**: `[#NN — short description]` next to the line where the issue's finding lives. This makes the graph a navigation aid into the backlog.

Below the graph, two short tables are usually worth including:

### Production state (read-only aggregates)

Aggregate prod queries that ground the graph in real data. Counts of rows by status, by FK population, by enum value. The production state often reshapes the audit's severity calibration mid-session.

### Cost per pipeline run (from code, not from prod)

If the pipeline is LLM-heavy or otherwise cost-sensitive, a per-run cost estimate derived from the code. This is what makes the unbounded-cost findings concrete.

### Audited and clean — no finding

A short list of things the audit verified are *correct*. Like the Sound rows in an intended-vs-actual matrix, these disconfirm priors and are part of the value.

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from an edu-pipeline area report (full instance in the case study, `case-study/pilot/phase-1-area-4b-1-report.md`):

```
### The edu pipeline call graph

The pipeline is five flows, not one. This is the load-bearing
structural fact.

FLOW A — Research prompt generation         (no DB write)
  POST /admin/dashboard/edu/research/generate-prompt
    edu_research.generate_edu_research_prompt(suggestion)
      → Anthropic Sonnet ×1  (max_tokens=10000, "claude-sonnet-4-6" — not date-pinned, #76)
    returns prompt text; admin pastes into Claude deep-research UI externally

FLOW B — Research upload + validation
  POST /admin/dashboard/edu/research/upload   (markdown file)
    extract_suggestion_title(content)                  [regex]
    substring-match loop over ALL EduSuggestions       [#87 — wrong-suggestion risk]
    validate_edu_research_document(content, suggestion)
      → word-count + references checks                 [regex]
      → sub-topic coverage    → Anthropic Haiku ×1 (max_tokens=256)
      → if no refs: _generate_references_section → Anthropic Haiku ×1 (max_tokens=4000)
    DB write: EduResearch (insert OR silent overwrite — #88)

FLOW C — Study guide generation              ← the heavy flow
  POST /admin/dashboard/edu/materials/generate
    generate_edu_materials(research, suggestion, db)
      FOR EACH grade_band in suggestion.grade_bands:   [#92 — no length cap]
        → _condense_research()   → Anthropic Haiku ×1  (max_tokens=4096, if >2500 words)
        → build_edu_outline_prompt → Sonnet ×1         (max_tokens=4096 — #93 truncation)
        → _parse_outline_response()                    [defensive, no LLM]
        → build_edu_content_prompt → Sonnet ×1         (max_tokens=8000)
        → EduMaterial upsert (material_type="guide"), db.flush()   [#91, #97]
    db.commit()  ← in the ROUTER, after the whole loop  [#90 — no partial progress]

FLOW D — Slide generation
  POST /admin/dashboard/edu/materials/generate-slides
    generate_edu_slides(guide, db)
      → build_edu_slides_prompt → Sonnet ×1 (max_tokens=8000)
      → EduMaterial upsert (material_type="slides"), db.flush()    [#91, #97]
    db.commit()  ← in the ROUTER

FLOW E — Material file upload + watermarking  ← links blog_research_id, NOT research_id
  POST /admin/dashboard/edu/materials/upload  (binary: PDF / PNG / m4a)
    watermark_infographic | watermark_slides  (image_storage.py)  [#94 — silent fallback]
    ImageStorageService.upload_image → DO Spaces
    _generate_material_thumbnail (Pillow / PyMuPDF)               [#83 swallow]
    DB write: EduMaterial (blog_research_id set, file_url set, content NULL)
```

Then the production-state table:

```
### Production state (read-only aggregates)

| Query | Result |
|---|---|
| edu_materials by (material_type, status) | guide: 2 PENDING + 2 APPROVED; slides: 3 PENDING; infographic: 1 PENDING; podcast: 1 PENDING |
| edu_materials by FK population | 6 research_id only, 3 blog_research_id only, 0 both, 0 neither |
| Orphan edu_research (no material) | 1 (expected intermediate state) |
| Distinct material_type | guide, slides, infographic, podcast |
| Distinct grade_band | 3rd-6th, 7th-8th, 9th-12th, NULL (NULL = Flow E rows) |
| edu_material_files row count | 0 (confirms #96 dead table) |
```

Then the cost section:

```
### Cost per generation run (from code)

A typical 3-band suggestion with a properly-sized (5000-8000-word)
research doc — condensation always fires:

- Flow C: 3 × condense (Haiku) + 3 × outline (Sonnet) + 3 × content (Sonnet) = 9 calls, 6 Sonnet
- Flow D: 1 × slides (Sonnet) per band = 3 Sonnet calls
- Flow B (one-time per research): 1-2 Haiku calls
- Flow A (one-time per suggestion): 1 Sonnet call

The edu pipeline is the most LLM-spend-heavy flow in the codebase, and
the per-run cost scales linearly with grade_bands length, which has no
cap (#92).
```

Notice how the graph + the prod state + the cost section together make the audit's severity calibration legible: the unbounded-cost finding (#92) is anchored in the prod-state observation (no cap on `grade_bands`) and the from-code cost calculation. The graph alone would have been less convincing.

## Pitfalls

- **Drawing the graph without inline issue citations.** A graph without citations is decoration; a graph with citations is a backlog navigation aid.
- **Skipping the prod-state table.** The graph derived from code says what the pipeline *can* do; the prod state says what it *has been doing*. The combination shapes severity calibration.
- **Treating "five flows" as a structural insight when there are really three.** The flow boundary is where control flow diverges, not where you wish it would. Read the entry points, then draw the graph.
- **No "audited and clean" section.** Disconfirmation of priors is part of the audit's value. If the pipeline has a defensive-parsing helper that turned out to work correctly, say so — it's part of what shapes the fix-ordering and the cross-area inheritance.
- **Letting the graph drift past 30-40 lines.** If the graph wants to be longer, the area should probably be split. The pilot split Area 4 into 4a/4b-1/4b-2/4c partly because the call graphs were going to be too dense to be legible.

## Cross-references

The call graph is the deliverable a **call-graph-first** adaptation produces — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md). Slot 10 of a call-graph-first prompt has the operator approve the call graph before the per-stage audit begins. The approval gate exists because a wrong call graph misroutes everything downstream.
