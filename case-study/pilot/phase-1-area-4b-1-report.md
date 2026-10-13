# Phase 1 — Area 4b-1 Report: Edu pipeline audit

**Date:** 2026-05-19
**Duration:** ~2.5 hours (call-graph mapping + prod queries + 5-stage walk + synthesis + fix-ordering + filing + report)
**Scope:** The educational content pipeline — `edu_research.py`, `edu_material_generation.py`, the watermarking helpers in `image_storage.py`, the edu router (`edu.py`), edu schemas, and the `EduSuggestion` / `EduResearch` / `EduMaterial` / `EduMaterialFile` models. `media_scoring.py` audited light-touch (confirmed decoupled from the edu pipeline).

---

## Executive summary

The edu pipeline is not one linear pipeline — it is **five distinct flows** sharing the `edu_materials` table. Mapping that structure was the highest-value 30 minutes of the session: most of the findings fall out of the seams between flows, not from any single flow's logic.

The headline finding is **#91 (critical)**: the `/materials/generate` and `/materials/generate-slides` endpoints have no guard against regenerating materials that already exist, and the generators unconditionally overwrite content and reset `status` to `PENDING`. A direct re-trigger on an already-`APPROVED`, possibly hand-edited study guide silently destroys it. The UI hides the trigger (the list endpoints filter materialized research out of the dropdowns), but the endpoint itself has no safeguard. Production data is currently clean, so this is not actively corrupting — but it is irreversible when hit.

The structural finding is the **`edu_materials` discriminated union** (#95): LLM-generated markdown rows (`research_id` + `content`) and uploaded-binary rows (`blog_research_id` + `file_url`) share one table with no `CHECK` constraint enforcing the XOR, and `material_type="slides"` is produced by *both* flows with completely different record shapes. Production is clean (6 research-only, 3 blog-only, 0 both/neither), so it is latent — confirmed via read-only aggregate query.

The recovery finding is the **commit-in-router pattern** (#90): `generate_edu_materials` flushes per grade band but the commit is in the router after the whole loop. A band-3-of-4 failure rolls back bands 1-2's LLM work. No corruption (clean rollback), but no partial progress either — transient failures force a full, costly restart.

11 issues filed: 1 critical, 7 moderate, 3 nice-to-have. 0 stop-the-line. The session also produced the first **fix-ordering analysis** (final section) — the proof-of-concept for the Phase 1 final report's fix-sequence framework.

---

## By the numbers

| Metric | Count |
|---|---|
| Modules audited (full read) | 8 (`edu_research`, `edu_material_generation`, `edu.py`, edu prompts, `image_storage` watermark helpers, edu schemas, 3 edu models) |
| Modules audited (light pass) | 1 (`media_scoring` — confirmed decoupled) |
| Distinct pipeline flows mapped | 5 (research-prompt, research-upload, guide-gen, slide-gen, material-upload) |
| LLM call sites in the edu pipeline | 7 distinct `messages.create` sites |
| Findings | 15 |
| Issues filed | 11 |
| — `code-quality:critical` | 1 (#91) |
| — `code-quality:moderate` | 7 (#87, #88, #90, #92, #94, #95, #97) |
| — `code-quality:nice-to-have` | 3 (#89, #93, #96) |
| — `agent-friendly` | 2 (#89, #93) |
| Prod aggregate queries run | 6 (counts only, no content/PII) |
| Stop-the-line incidents | 0 |

---

## What was audited

### The edu pipeline call graph

The pipeline is **five flows**, not one. This is the load-bearing structural fact.

```
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

### Production state (read-only aggregates)

| Query | Result |
|---|---|
| `edu_materials` by `(material_type, status)` | guide: 2 PENDING + 2 APPROVED; slides: 3 PENDING; infographic: 1 PENDING; podcast: 1 PENDING |
| `edu_materials` by FK population | 6 `research_id` only, 3 `blog_research_id` only, **0 both, 0 neither** |
| Orphan `edu_research` (no material) | 1 (expected intermediate state) |
| Distinct `material_type` | `guide`, `slides`, `infographic`, `podcast` |
| Distinct `grade_band` | `3rd-6th`, `7th-8th`, `9th-12th`, NULL (NULL = Flow E rows) |
| `edu_material_files` row count | **0** (confirms #96 dead table) |

`4th-6th` appears in the prompt module's `GRADE_BAND_VOICE` / `GRADE_BAND_WORD_TARGET` dicts but never in production — a harmless dead prompt entry (its voice/target are identical to `3rd-6th`).

### Cost per generation run (from code)

A typical 3-band suggestion with a properly-sized (5000-8000-word) research doc — condensation always fires, since `CONDENSE_THRESHOLD=2500` is below the spec'd research length:

- Flow C: 3 × condense (Haiku) + 3 × outline (Sonnet) + 3 × content (Sonnet) = **9 calls, 6 Sonnet**
- Flow D: 1 × slides (Sonnet) per band = **3 Sonnet calls**
- Flow B (one-time per research): 1-2 Haiku calls
- Flow A (one-time per suggestion): 1 Sonnet call

The edu pipeline is the most LLM-spend-heavy flow in the codebase, and the per-run cost scales linearly with `grade_bands` length, which has no cap (#92).

### Audited and clean — no finding

- **Prompt injection.** Every edu endpoint is admin-gated (`validate_admin_token`). No public / educator input reaches LLM prompts. Suggestion fields and research content are admin-controlled or admin-reviewed. No injection surface.
- **`_parse_outline_response`** — confirmed the defensive-parsing template 4c praised; it never raises. (Its one downside — masking truncated outlines — is #93.)
- **`media_scoring.py`** — light pass confirmed it is media-library-only; the edu pipeline never calls it. The scope brief's "used by the edu pipeline downstream" is not borne out by any code path. The slides prompt emits `[IMAGE: ...]` placeholders but nothing resolves them — they are intentional human-handoff markers for the external Gamma step.

---

## Item-by-item findings

| # | Finding | Severity | Agent-friendly |
|---|---|---|---|
| #87 | `upload_edu_research` guesses the suggestion by title-substring match over all suggestions; ignores the `REF:` line; should take an explicit `suggestion_id` | moderate | no |
| #88 | `upload_edu_research` silently overwrites existing research content and never resets `status` from `APPROVED` | moderate | no |
| #89 | Edu router uploads read the whole file into memory, no size cap; `upload_edu_research` has no UTF-8 decode handling | nice-to-have | yes |
| #90 | `generate_edu_materials`: one band's failure rolls back all bands (commit-in-router); no partial progress, no resume | moderate | no |
| #91 | **Regenerating edu materials silently overwrites APPROVED guides/slides and resets them to PENDING** | **critical** | no |
| #92 | `generate_edu_materials` has no cap on `grade_bands` length — unbounded LLM cost per request | moderate | no |
| #93 | Edu outline call `max_tokens=4096` risks silent truncation that the defensive parser masks | nice-to-have | yes |
| #94 | `upload_material`: watermark failure silently ships the un-watermarked file; no file-type validation | moderate | no |
| #95 | `EduMaterial` is a discriminated union with no XOR constraint; `material_type` overloaded across flows | moderate | no |
| #96 | `EduMaterialFile` table is dead — model + relationship defined, never written, 0 rows | nice-to-have | no |
| #97 | No unique constraint on `edu_materials (research_id, material_type, grade_band)` — upsert is a read-then-write race | moderate | no |

### Stop-the-line discussion

No stop-the-line. #91 is data-destruction-shaped (it irreversibly overwrites human-reviewed APPROVED content), which is why it is filed critical — but it is **not actively corrupting production**: the UI filters materialized research out of the generation dropdowns, so the trigger requires a direct endpoint call, a stale tab, or a scripted retry. Production `edu_materials` data is clean. The brief's stop-the-line bar ("actively corrupting data in production") is not met. It is the first thing to fix, but it is a latent landmine, not a live fire.

No attacker-controlled-input-to-LLM-prompt path exists — the pipeline is fully admin-gated.

---

## What's filed vs. deferred

### Filed (this session)
11 issues, #87-#97, listed above.

### Deferred / not filed

- **1 orphan `edu_research` row.** Research APPROVED with no material — the expected intermediate state between research approval and material generation. Not distinguishable from "a `generate_edu_materials` run that failed and rolled back" via aggregates alone, but neither is a bug. Not filed.
- **`4th-6th` dead prompt entry.** `GRADE_BAND_VOICE` / `GRADE_BAND_WORD_TARGET` carry a `4th-6th` key never used in production; its values duplicate `3rd-6th`. Cosmetic; rolled into the report, not filed.
- **Per-band re-condensation.** `_condense_research` runs once per grade band, so a 4-band suggestion condenses the same research 4 times. `3rd-6th` and `4th-6th` have identical condense targets yet condense separately. A minor cost inefficiency; noted, not filed (the LLM-wrapper / cost work in #76/#78 is the right home).
- **`Content-Disposition` filename construction** in `download_edu_material` / `download_edu_research`. Filenames are built from `unidecode(title).replace(" ", "_")`; `unidecode` does not strip quotes/newlines. The input is single-line admin/LLM-controlled (titles come from a `TITLE:` line, truncated), so header-injection risk is low. Noted, not filed.
- **`media_scoring` issues** — already covered by #85 (4c). Not re-filed.
- **`generate_thumbnail` swallow in Flow E** — `_generate_material_thumbnail` hits the #83 pattern. Cross-referenced in #94, not re-filed.
- **`MAX_IMAGE_PIXELS` relaxation in `watermark_infographic`** — already #81. Cross-referenced in #94, not re-filed.

---

## Newly observed — for other audit areas

### For 4b-2 (article pipeline)

- **`#76` and `#78` are shared foundations.** The unified Anthropic wrapper (#76) and the budget cap (#78) touch both the edu pipeline and the article pipeline. Whoever implements #76 reshapes 4b-1 cleanup (#93, #77) *and* 4b-2 cleanup. 4b-2 should not re-file Anthropic-wrapper findings — reference #76. See the fix-ordering section.
- **`research.py` (blog research) mirrors `edu_research.py` almost exactly.** `validate_research_document` / `validate_edu_research_document`, `_generate_references_section` (duplicated verbatim in both modules), the `REF:` line convention, the narrow `except (json.JSONDecodeError, IndexError)` parse — all parallel. 4b-2 should check whether the blog research upload (`research/upload` equivalent) has the same title-matching bug as #87. The `_generate_references_section` duplication is a DRY finding 4b-2 should consider filing.
- **`EduMaterial.blog_research_id`** links materials to blog `Research`. Flow E (`upload_material`) is the bridge between the article/blog domain and the edu-materials table. 4b-2 owns the blog-research-linkage *semantics*; 4b-1 audited the upload/watermark *mechanics* (#94).
- **`suggestion_generation.py` `next(b for b in message.content if b.type == "text")`** (a `StopIteration` risk noted in 4c §5) is article-pipeline; 4b-2 should fold it into the #77 work.

### For the models / schema area

- **#95 (EduMaterial XOR), #96 (dead `EduMaterialFile`)** pair with the existing model-hygiene cluster: #22 (FK constraints), #24 (status-column unification), #29 (unused enums), #4 (orphan tables). If a dedicated models pass happens, these six should be sequenced together.
- **`EduMaterial.material_type` is `String(20)` with no enum**, and the canonical set is confirmed `{guide, slides, infographic, podcast}`. `Flow E` validates against `ALLOWED_MATERIAL_TYPES = {slides, infographic, podcast}` (no `guide`); `Flow C/D` produce `{guide, slides}`. An enum would make the set authoritative.

### Cross-area

- **The watermark-failure swallow (#94)** is a Phase 1 Area 4c-shaped finding (swallowed exception) filed as a domain finding because it violates pipeline intent (every material watermarked). The 4c catalogue (#8 comment) should be cross-referenced when #94 is worked.

---

## What surprised me

1. **It is five flows, not a pipeline.** Going in, the mental model was research → guide → slides → watermark → library, a linear chain. The reality: Flow C/D (LLM markdown generation) and Flow E (binary file upload + watermarking) are two unrelated subsystems that happen to write the same table. Watermarking — which the brief framed as a pipeline stage "between LLM artifacts and the media library" — **never touches LLM-generated content at all**. It runs only on Flow E uploads, which link to *blog* research. The LLM-generated guides and slides are markdown text in a DB column; they are never watermarked, never uploaded to Spaces. The brief's framing of the pipeline was the framing I had too, and the code does not match it.

2. **`material_type="slides"` means two completely different things.** Flow D writes a `slides` row whose `content` is markdown. Flow E writes a `slides` row whose `file_url` is a PDF in Spaces. Same `material_type` value, disjoint record shapes. The field that looks like the discriminator is itself overloaded. I did not expect the union to be that undisciplined.

3. **The critical bug's prerequisite is a moderate bug.** #91 (critical — regeneration destroys APPROVED content) cannot be fixed cleanly without #97 (moderate — add the unique constraint), because a safe idempotent upsert needs a real key. The most urgent fix is gated behind a less-urgent one. That inversion is exactly what the fix-ordering section exists to surface, and I did not expect the session's own findings to demonstrate it so cleanly.

4. **The defensive parser that 4c praised has a sharp edge.** `_parse_outline_response` never raises — 4c held it up as the template. But "never raises" means a *truncated* outline (from the `max_tokens=4096` cap, #93) sails through looking fine and produces a guide silently missing sections. The same property that makes the parser robust against malformed input makes it blind to truncated input. Good patterns have contexts where they cost you.

5. **The `REF:` line was designed for exactly the job the uploader doesn't use it for.** `generate_edu_research_prompt` emits `REF: edu_suggestion_{id}` and the meta-prompt explicitly instructs the model to keep it. It is a correlation token, purpose-built. Then `upload_edu_research` ignores it entirely and reverse-engineers the suggestion from an H1-title substring match. The right mechanism was built and then not wired up — the same "noticed the problem, fixed half of it" shape 4c saw in `educator_service`.

6. **Production is clean, which lowered three severities.** The discriminated union (#95), the FK-XOR, the upsert race (#97) — all latent, none manifesting in the 9 production rows. Without the prod queries I would likely have rated #95 higher. Aggregate queries earned their place again, as in Area 2.

---

## Process notes for the next session (4b-2)

- **Map the flows before reading the logic.** The 30 minutes spent producing the call graph paid for itself three times over — most findings live in the seams between flows. 4b-2 should produce the article-pipeline call graph first and get it approved before the per-stage walk.
- **`research.py` ↔ `edu_research.py` are near-duplicates.** 4b-2 can move fast by diffing against this session's `edu_research` findings rather than re-deriving. Specifically check: does blog research upload have the #87 title-matching bug? Is there a #88-style silent overwrite?
- **Do not re-file Anthropic-wrapper findings.** #76/#77/#78/#68 are shared. 4b-2 references them.
- **Run the prod aggregates early.** They recalibrated three severities here. 4b-2 should query article/research/suggestion counts and FK-population distributions before finalizing severities.
- **The fix-ordering section (below) is the new deliverable.** 4b-2 should produce one for the article pipeline, and the Phase 1 final report should merge both into a single backlog sequence.

---

## Fix ordering for edu pipeline

This is the new deliverable — the proof-of-concept for the Phase 1 final report's fix-sequence framework. It answers: of the issues touching the edu pipeline, what gets fixed first, what can run in parallel, and where does fixing one issue change the scope of another.

### Issues in scope

**Filed this session (4b-1):** #87, #88, #89, #90, #91, #92, #93, #94, #95, #96, #97.

**Pre-existing issues that touch the edu pipeline:**
- **#76** — unified Anthropic wrapper (the 7 edu LLM call sites; shared with the article pipeline)
- **#77** — defensive LLM-response parsing (`edu_material_generation`, `edu_research`)
- **#78** — Anthropic budget cap / observability (the central fix for #92's cost concern)
- **#68** — no SDK timeouts (amplifies #92's worker-block)
- **#81** — `watermark_infographic` relaxes Pillow `MAX_IMAGE_PIXELS`
- **#83** — `generate_thumbnail` swallow (`_generate_material_thumbnail` in Flow E)
- **#8** — swallowed-exceptions catalogue (catalogues the edu modules' uncaught LLM calls)

**Not in scope:** #85 (`media_scoring`) — confirmed decoupled from the edu pipeline despite the scope brief's assumption.

### Dependency structure

```
                    ┌─────────────────────────────────────┐
  FOUNDATION        │  #97 unique constraint                │  #76 Anthropic wrapper
  (do first,        │  (research_id, material_type,         │  (cross-domain — shared
   parallel)        │   grade_band)                         │   with 4b-2 article pipeline)
                    └──────────────┬────────────────────────┘            │
                                   │                                     │
  CRITICAL PATH                    ▼                          reshapes ──┼──────────┐
  (sequential,            ┌────────────────┐                             ▼          ▼
   after #97)             │ #91 regen guard │                          #93        #77
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
```

### Proposed sequence

**Wave 1 — Foundations (start immediately; the two are independent of each other).**

1. **#97 — unique constraint on `(research_id, material_type, grade_band)`.** Pure Alembic migration; production data is already clean, so no data-cleanup step. This is the *first* fix despite being only moderate, because it unblocks the critical #91 and the recovery fix #90. Agent-assistable (migration-only) once the `NULLS NOT DISTINCT` decision is made.
2. **#76 — unified Anthropic wrapper.** Cross-domain foundation. Sequence it as a shared piece — whoever does it should coordinate with 4b-2. It reshapes #93, #77, and #92 (see scope-change notes below).

**Wave 2 — Critical path (sequential, after #97).**

3. **#91 — regeneration guard (CRITICAL).** Needs #97's well-defined key to implement a safe idempotent upsert. Decide the policy (refuse vs. selective-regenerate vs. force-flag) here.
4. **#90 — per-band commit.** After #91, because per-band commit changes what a failed run leaves behind, and the regeneration guard must handle those committed-partial rows. Doing #90 before #91 means designing the commit boundary without knowing the regeneration policy.

**Wave 3 — LLM-quality cleanup (after #76).**

5. **#77** — defensive parsing folds into the wrapper.
6. **#93** — outline truncation: if #76 lands first, this shrinks to a one-line `max_tokens` bump (the wrapper owns the generic truncation guard). If #76 is delayed, #93 is done standalone with its own `stop_reason` check.
7. **#78 → #92** — #78 (central budget cap) makes #92 (local `grade_bands` cap) a belt-and-suspenders rather than the primary guard. #92 can also ship immediately as a standalone stopgap — it is independent — but #78 is the real fix.

**Parallel track — independent, fix anytime, no blockers.**

- **#87** (explicit `suggestion_id`) — needs a coordinated endpoint + frontend change.
- **#88** (research overwrite policy) — needs a policy decision.
- **#89** (upload size limits) — the most agent-friendly issue in the batch.
- **#94** (watermark / file-type validation) — needs a policy decision.
- **#95** (EduMaterial XOR constraint) — pairs with model-hygiene #24/#29.
- **#96** (dead `EduMaterialFile` table) — pairs with #4; needs a Gamma-roadmap decision.
- **#68 / #81 / #83** — small cross-cutting fixes; #68 ideally lands before or with #92.

### Where fixing one issue changes another's scope

This is the part the fix-ordering analysis exists for — the issues whose *scope* (not just whose schedule) depends on another issue.

1. **#97 → #91, #90.** Adding the unique constraint is not just a prerequisite for scheduling — it changes the *implementation* of #91 and #90. With #97 in place, the upsert can become an atomic `INSERT ... ON CONFLICT DO UPDATE`, and #91's guard and #90's per-band commit become straightforward and race-free. Without #97, both #91 and #90 have to invent an ad-hoc key and remain race-exposed. Fixing #97 first *shrinks* #91 and #90.

2. **#76 → #93.** If the unified Anthropic wrapper lands first, the generic "reject truncated (`stop_reason == "max_tokens"`) responses" guard lives in the wrapper. #93 then shrinks from "add a truncation guard + bump `max_tokens`" to just "bump `max_tokens` 4096 → 8192." If #76 is delayed, #93 carries the full guard itself. (This is the same pattern 4c flagged for #85 vs. #76.)

3. **#76 → #77.** #77 (defensive parsing) substantially *becomes* #76 — the wrapper centralizes the defensive parse. Doing #77 standalone first means writing per-site parsing that #76 then consolidates and partially throws away. #76 first means #77 is absorbed.

4. **#78 → #92.** #78 (central Anthropic budget cap) is the real fix for unbounded edu-pipeline cost. #92 (local `grade_bands` length cap) is a stopgap. If #78 lands, #92 demotes from "the cost guard" to "a cheap input-validation belt-and-suspenders." Both are still worth having, but #78 changes #92 from primary to secondary.

5. **#91 → #90 (policy coupling).** Not a scope *shrink* but a scope *dependency*: #90's per-band commit means a failed run leaves committed rows from the successful bands. #91's regeneration guard is what decides whether the next run skips, refuses, or overwrites those rows. The two fixes must agree on the regeneration policy — doing them in either order without coordinating that policy produces an inconsistent system.

### Cross-domain dependency callout

**#76 and #78 are not edu-pipeline-only.** They are shared with the article pipeline (4b-2's domain). Implementing #76 affects 4b-1 cleanup (#93, #77) *and* 4b-2 cleanup simultaneously. The Phase 1 final report should treat #76 as a single shared foundation scheduled once — not as two separate line items in the edu and article backlogs. Whoever picks up #76 should be briefed that it has consumers in both pipelines.