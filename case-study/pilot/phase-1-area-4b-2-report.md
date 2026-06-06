# Phase 1 — Area 4b-2 Report: Article pipeline audit

**Date:** 2026-05-19
**Duration:** ~1.5 hours (call-graph mapping + spot-checks + prod queries + per-stage walk + filing + report)
**Scope:** The blog article content pipeline — `article_generation.py`, `research.py` (blog research), `research_summary.py`, `suggestion_generation.py`, `image_prompt.py`, `series_sections.py`, the article router (all in `dashboard.py`), article-related Pydantic schemas (`schemas/dashboard.py`), and the `Article` / `ArticleSuggestion` / `Research` models. `edu_research.py` read light-touch for the DRY comparison; `media_scoring.py` confirmed decoupled from the article pipeline.

This is the final Area 4 session. 4a produced the service surface map; 4c produced the swallow catalogue; 4b-1 audited the edu pipeline and produced the first fix-ordering analysis. All three are inputs.

---

## Executive summary

The article pipeline is **ten flows** (vs. the edu pipeline's five), all admin-gated, all routed through `dashboard.py`. Mapping the flows first — as 4b-1 recommended — again paid for itself: the headline finding lives in the one flow nobody would have guessed.

The headline finding is **#99 (critical)**: the `series-sections` endpoint has no regeneration guard, and `SeriesSectionGenerator.generate_sections_for_series` builds navigation by raw-SQL string concatenation — `content = :about || content || :continue`. A second run double-appends the "About this Article" and "Continue Reading" blocks to every article in the series. Unlike edu's #91 (filed critical *while still latent* — "production data is clean"), **this one is not latent**: a read-only prod query found articles **39 and 40** — a complete 2-part published series — already carrying doubled nav blocks in both `content` and `content_es`. The corruption is live on the public site. It is the article-pipeline analog of #91, but where #91 is a landmine, #99 has already gone off.

The surprising structural fact: the article pipeline guards regeneration **correctly in four of five mutating flows** — outline generation, article writing, and translation all refuse to overwrite (`"Articles already exist"`, `"Article already has content"`, `"Article already has Spanish content"`). The pipeline learned the #91 lesson everywhere except `series-sections` — and `series-sections` is the *most-exercised* flow (all 51 published articles went through it). The danger was not where the LLM complexity was; it was in the one flow that's just string concatenation.

The article pipeline otherwise **mirrors the edu pipeline closely**: the blog research upload (`upload_research`) reproduces the exact #87 / #88 / #89 bugs (title-substring matching that ignores the `REF:` line, silent overwrite without status reset, no upload size cap) — filed once as **#100**, to be fixed as a coordinated set with the edu trio. `_generate_references_section` is byte-identical between `research.py` and `edu_research.py` (**#103**, DRY).

6 issues filed: 1 critical, 2 moderate, 3 nice-to-have. 2 agent-friendly. 0 stop-the-line — but #99 was the closest call of the Area-4 sub-sessions (discussed below). This session produces the **second fix-ordering analysis** and the new **"Toward a global fix ordering"** bridge section for the Phase 1 final report.

---

## By the numbers

| Metric | Count |
|---|---|
| Modules audited (full read) | 11 (`article_generation`, `research`, `research_summary`, `suggestion_generation`, `image_prompt`, `series_sections`, article router in `dashboard.py`, `schemas/dashboard.py`, `Article` / `ArticleSuggestion` / `Research` models, `prompts/article_generation`) |
| Modules audited (light pass) | 2 (`edu_research` — DRY comparison; `media_scoring` — confirmed decoupled) |
| Distinct pipeline flows mapped | 10 |
| LLM call sites in the article pipeline | ~11 distinct `messages.create` sites across 5 modules |
| Findings | 6 filed + 5 noted-not-filed |
| Issues filed | 6 |
| — `code-quality:critical` | 1 (#99) |
| — `code-quality:moderate` | 2 (#100, #101) |
| — `code-quality:nice-to-have` | 3 (#102, #103, #104) |
| — `agent-friendly` | 2 (#103, #104) |
| Prod aggregate queries run | 3 (counts only, no content/PII) |
| Stop-the-line incidents | 0 (one close call — #99) |

---

## What was audited

### The article pipeline call graph

Ten flows, sharing the `articles` / `research` / `article_suggestions` tables. Every endpoint is in `dashboard.py` and admin-gated (`validate_admin_token`).

```
FLOW A — Suggestion generation                         (DB write; commit IN SERVICE)
  POST /admin/dashboard/suggestions/generate
    generate_historical_suggestions(category, taxonomy, num, db)
      → Sonnet ×1  max_tokens=16000, thinking budget=10000  ("claude-sonnet-4-6", not pinned)
      → next(b ... type=="text")  [StopIteration risk] → _strip_json_fences → json.loads  [unguarded]
      → ArticleSuggestion rows, db.commit()              ArticleSuggestion.status = PENDING

FLOW B — Research prompt generation                    (no DB write)
  POST /admin/dashboard/research/generate-prompt
    guard: suggestion APPROVED + no existing research   [refuses if research exists]
    generate_research_prompt → Sonnet ×1  max_tokens=10000, inline "claude-sonnet-4-6"
    emits "REF: suggestion_{id}"; admin pastes into Claude deep-research UI

FLOW C — Research upload + validation                  (DB write)             ← #100
  POST /admin/dashboard/research/upload  (markdown file)
    (await file.read()).decode("utf-8")                 [no size cap; decode can raise]
    extract_suggestion_title  [regex H1]
    substring-match loop over ALL ArticleSuggestions    [wrong-suggestion risk; REF line ignored]
    validate_research_document
      → word-count + references regex
      → sub-topic coverage → Haiku ×1 (256)  json.loads GUARDED
      → if no refs: _generate_references_section → Haiku ×1 (4000)  [verbatim dup of edu_research]
    Research insert OR silent overwrite, status never reset   Research.status = PENDING

FLOW D — Outline generation (Phase 1)                  (DB write; commit in router)
  POST /admin/dashboard/articles/generate-outlines
    guard: research APPROVED;  guard: no existing articles   [regen guard PRESENT — good]
    generate_outlines → Sonnet ×1  max_tokens=16000
      → message.content[0].text → json.loads → result["articles"]  [3 unguarded exc classes]
    create_article_records_from_outlines → Article rows + series parent/child wiring
                                            Article.status=PENDING, outline_status=PENDING

FLOW E — Article writing (Phase 2)                     (DB write; commit in router)   ← #104
  POST /admin/dashboard/articles/{id}/write
    guard: has outline;  guard: no existing content      [regen guard PRESENT — good]
    NOTE: does NOT enforce outline_status==APPROVED (UI-only gate)
    generate_article_content → Sonnet ×1 (8000); embeds FULL research  [no condensation — #102]
      series_context: Part N is told Part 1's TITLE only, not its content
    generate_excerpt_and_summary → Haiku ×2 (256, 512)
    [3 LLM calls, single commit — a call-2/3 failure discards the Sonnet output]

FLOW F — Tagging (Phase 3)                             (DB write; commit in router)
  POST /admin/dashboard/articles/{id}/generate-tags
    generate_tags → Haiku ×1 (512), json.loads [unguarded]; additive (no regen harm)

FLOW G — Translation                                   (DB write; commit in router)
  POST /admin/dashboard/articles/{id}/translate
    guard: has content; guard: no existing content_es
    DeepL ×3 (title, excerpt, content)  [no error handling — #71]; single atomic commit

FLOW H — Series sections                               (DB write; commit in router)   ← #99
  POST /admin/dashboard/articles/{id}/series-sections
    guard: is part of series; can_generate (all translated)
    NO regeneration guard → re-run DOUBLE-APPENDS nav into content + content_es
    SeriesSectionGenerator — raw SQL text() ×3, UPDATE-concatenation

FLOW I — Image prompt                                  (no DB write)
  POST /admin/dashboard/articles/{id}/image-prompt
    generate_image_prompt → Sonnet ×1 (1024), inline "claude-sonnet-4-6"
    returns text; admin → Gemini (external) → upload-image endpoint

FLOW J — Research summary / infographic  (side branch) (DB write; commit in router)
  POST /admin/dashboard/research/{id}/generate-summary
    guard: research APPROVED + has content
    generate_research_summary → Haiku ×1 (2000)  [wrapped in try/except → 502 — the ONE
                                                   defensively-called LLM site in the pipeline]

LIFECYCLE: publish_article / unpublish_article / update_outline_status /
           update_entity_status (shared PENDING↔APPROVED↔REJECTED machine, VALID_TRANSITIONS)
```

### Production state (read-only aggregates)

| Query | Result |
|---|---|
| `articles` by `status` | 51 APPROVED, 2 PENDING (53 total) |
| `articles` by `outline_status` | 2 APPROVED, **51 NULL** |
| `articles` published | 51 published, 2 unpublished |
| Series | 12 series parents; all 53 articles belong to one series |
| Published series members | 51 |
| `articles` with orphan `research_id` (no matching `research` row) | **0** |
| `research` by `status` | 19 APPROVED, 23 PENDING (42 total) |
| Orphan `research` (no article) | 30 |
| `articles` with **doubled** `**About this Article**` | **2** (IDs 39, 40) |

Two facts drove the session's calibration:

1. **Only 2 articles were created by the current generation pipeline.** `create_article_records_from_outlines` sets `outline_status="PENDING"`; 51 of 53 articles have `outline_status = NULL` — they predate this code (imported / migrated / older pipeline). The two `outline_status`-bearing articles are exactly the two `PENDING`/unpublished ones. **The heavy LLM article-generation flows (D, E, F) have produced 2 articles.** The findings in those flows are real but currently low-traffic.

2. **The series-sections double-append has already fired in production.** A verification query confirmed articles 39 (series parent) and 40 (its child) each carry two `**About this Article**` / `**Acerca de este artículo**` blocks in both `content` and `content_es`; article 39 also has two `**Continue Reading**` blocks. The counts are internally consistent with `generate_sections_for_series` running twice on that one 2-part series. This recalibrated #99 from moderate (latent) to **critical (manifested)**.

### Audited and clean — no finding

- **Prompt injection.** Every article endpoint is admin-gated. Research is admin-uploaded; suggestions are LLM-generated then admin-reviewed; article content is admin-reviewed. No public or educator input reaches an LLM prompt. Same shape as the edu pipeline (4b-1) — no injection surface.
- **Regeneration guards in Flows D, E, G.** Outline generation refuses if articles exist; `write_article` refuses if content exists; `translate_article` refuses if `content_es` exists. These are the guards #91 wanted and the edu pipeline lacked. They are correct.
- **`media_scoring.py`** — confirmed decoupled. The article pipeline never imports it (verified across `dashboard.py` and `article_generation.py`). The scope brief's "verify whether the article pipeline uses it" resolves negative.
- **`image_prompt.py` is alive.** 4a reported "no detected callers." It *is* called — `dashboard.py:1438` imports `generate_image_prompt` and `:1440` invokes it, via a **function-local import** inside the `image-prompt` endpoint. 4a's caller-grep missed function-local imports. No dead-code cleanup to file; 4a's inventory entry is corrected here.
- **Translation integration.** `translate_article` does three DeepL calls then a single commit — atomic; a mid-flow DeepL failure rolls back cleanly with no partial state. The DeepL failure mode itself is #71 (already filed). Flow ordering is enforced: translation requires content, refuses re-translation; `series-sections` requires all articles translated; `publish` requires `content_es`. Coherent.

---

## Item-by-item findings

### Issues filed

| # | Finding | Severity | Agent-friendly |
|---|---|---|---|
| #99 | `series-sections` has no regeneration guard; raw-SQL `UPDATE` concatenation double-appends nav blocks. **Manifested in prod (articles 39, 40).** | **critical** | no |
| #100 | Blog `upload_research` mirrors #87 + #88 + #89: title-substring match ignoring `REF:`, silent overwrite without status reset, no size cap / decode handling | moderate | no |
| #101 | `suggestion_generation` `max_tokens=16000` − `thinking budget=10000` ≈ 6000 effective output; truncates → uncaught `json.loads` 500 at high `num_suggestions` | moderate | borderline |
| #102 | Article generation feeds the full 5000-8000-word research into outline/content prompts — lacks the `_condense_research` step the edu pipeline has | nice-to-have | no |
| #103 | `research.py` and `edu_research.py` duplicate `_generate_references_section` (verbatim) and `validate_*_document` (near-identical) | nice-to-have | yes |
| #104 | `write_article` doesn't enforce `outline_status == APPROVED` server-side; UI-only gate, inconsistent with outline gen's server-side research-status check | nice-to-have | yes |

### Stop-the-line discussion

**No stop-the-line halt — but #99 was the closest call of the four Area-4 sub-sessions.**

The inherited stop-the-line trigger is "actively corrupting data in production." #99 has corrupted production data — articles 39 and 40 carry doubled navigation. The judgment call: is it *actively* (continuously) corrupting? No. The corruption fired on a manual re-trigger of an admin endpoint; it is not spreading on a timer, and it does not recur without another deliberate re-run. The damage is bounded (2 articles), recoverable (an admin edits out the duplicates), and cosmetic in impact (the articles still render — the nav is just duplicated). That is materially different from "a process is destroying data right now," which is what a stop-the-line halt is for.

So: not a halt, but **surfaced immediately** rather than held for this report — articles 39 and 40 are visibly broken on the live site and warrant a manual content fix independent of the code fix. The distinction from 4b-1's #91: #91 was filed critical while latent; #99 is filed critical *because* it manifested. Same severity label, opposite evidentiary basis.

No attacker-controlled-input-to-LLM path exists — the pipeline is fully admin-gated.

### Noted, not filed

- **`write_article`'s three-call partial-loss.** Flow E does `generate_article_content` (Sonnet) then `generate_excerpt_and_summary` (2× Haiku) then a single commit. A failure in the excerpt/summary calls discards the already-generated Sonnet article (nothing committed). This is the #90 shape (no partial progress) but much milder — 3 calls not N grade-bands, and Haiku rarely fails. Referenced against #90, not filed.
- **`publish_article:1260-1261` dead branch.** `if article.status != "APPROVED": article.status = "APPROVED"` is unreachable — line 1248 already raised if status ≠ APPROVED. Cosmetic; a 2-line cleanup. Not filed.
- **Series content-coherence.** When writing Part N, `generate_article_content` passes the LLM the shared research doc + Part N's outline + "Part 1 is titled X" — Part N never sees Part 1's *generated content*. Cross-article repetition is mitigated by the shared research and the jointly-generated outlines, so this is a design limitation, not a bug. A quality-area observation.
- **`Article.research_id` has no FK** and no ORM relationship (`Mapped[int]`, plain column; every consumer does a manual `db.query(Research)`). Already named explicitly in **#22**. Prod shows 0 orphans — latent. Referenced, not re-filed.
- **`Article.outline_status` is `String(20)` with no enum**, unlike `Article.status` (`SAEnum`). The article-pipeline instance of **#24** (status-column unification). Referenced, not re-filed.

### Cross-references added on filed issues

- **#99 ↔ #91** — parallel regeneration-overwrite bugs; #91 latent, #99 manifested.
- **#100 ↔ #87 / #88 / #89** — same three bugs in the blog research-upload path; fix as a coordinated set.
- **#101 ↔ #93 / #77 / #76** — #93 is the parallel edu truncation; #77 would make the failure clean; #76 would own token-budget policy.
- **#102 ↔ #76** — the condensation helper belongs in the unified-LLM-wrapper layer.
- **#103 ↔ #76** — the duplicated Haiku calls inside `validate_*_document` are what the wrapper absorbs.
- **#104 ↔ #24** — `outline_status` is the model-hygiene instance.

---

## What's filed vs. deferred

### Filed (this session)
6 issues, #99-#104, listed above.

### Deferred / not filed

- **The five noted-not-filed items above** — `write_article` partial-loss, the dead branch, series content-coherence, the `research_id` FK gap (→ #22), the `outline_status` enum gap (→ #24).
- **`StopIteration` at `suggestion_generation.py:54`** — `next(b for b in message.content if b.type == "text")`. Per the scope brief, folded into the #77 work (defensive parsing), not filed separately. Confirmed present.
- **The five scattered `anthropic.Anthropic()` instances and scattered model strings** — article-pipeline modules hold most of them (`article_generation._get_client`, `research._get_client`, `research_summary` inline, `image_prompt` inline; `suggestion_generation` imports `_get_client` + `_strip_json_fences` from the private `article_generation` module). All captured by **#76**; not re-filed.
- **Unguarded LLM-response parsing** at `generate_outlines`, `generate_tags`, `suggestion_generation` (the `result["articles"]` / `json.loads` / `message.content[0]` shapes). Captured by **#77**; the article-pipeline sites are now enumerated in #77's existing body. Not re-filed.
- **No SDK timeouts** on any article-pipeline `messages.create` — **#68**.
- **30 orphan `research` rows** (research with no article) — the expected intermediate backlog state (research uploaded/approved, articles not yet generated), exactly as 4b-1 deferred its 1 orphan `edu_research`. Not a bug.

---

## Newly observed — for the Phase 1 final report

Area 4 is complete (4a, 4b-1, 4b-2, 4c). These items are for the Phase 1 final report and for any models/schema pass that follows it.

### Cross-pipeline work items

- **Research-upload hardening is one work item, not four.** Edu's #87 / #88 / #89 and article's #100 are the *same three bugs* in two modules (`edu.py` and `dashboard.py`). The final report should merge them into a single "research upload hardening" item — fix both or the two pipelines diverge in behavior. This is the single clearest cross-pipeline merge in Area 4.
- **`#76` / `#77` / `#78` / `#68` are shared foundations**, scheduled once. #76 (unified Anthropic wrapper) reshapes 4b-1's cleanup (#93, #92, #77) *and* 4b-2's (#101, #102, #103, #77). See the bridge section below.

### For a models / schema pass

- **#22** explicitly names `Article.research_id` (no FK). Confirmed: plain `Mapped[int]`, no `ForeignKey`, no relationship. Prod has 0 orphans — latent.
- **#24** (status-column unification): `Article.outline_status` (`String(20)`, no enum) is the article-pipeline instance. `Article.status` and the other content models use `SAEnum`.
- These pair with edu's **#95** (EduMaterial XOR) and **#96** (dead `EduMaterialFile`). 4b-1 already proposed sequencing #95/#96 with #22/#24/#29/#4 — #24's `outline_status` instance joins that batch.

### For the Phase 1 final's accuracy

- **Weight findings by flow traffic.** Production now gives the data: the LLM article-generation flows (D/E/F) have produced 2 articles; `series-sections` (Flow H) ran on all 51 published articles. A bug's severity should account for how exercised its flow is — #99 is critical partly *because* its flow is the most-used.
- **4a's module inventory has a function-local-import blind spot.** `image_prompt.py` was reported callerless; it is called via a function-local import. `dashboard.py` also imports `research_summary`, `series_sections`, and `translation` function-locally. The final report's inventory should re-derive callers including function-local imports.

---

## What surprised me

1. **The article pipeline guards regeneration everywhere except the one flow that's just string concatenation.** Going in, after 4b-1's #91, I expected the article pipeline's *LLM-generation* flows to be the regeneration risk. They're not — outline gen, writing, and translation all guard correctly. The unguarded flow is `series-sections`, which makes no LLM call at all; it's a raw-SQL `UPDATE` that concatenates strings. The danger was not where the complexity was. The pipeline learned the #91 lesson four times out of five and missed it in the flow that looked too simple to get wrong.

2. **The prod query raised a severity instead of lowering one.** 4b-1's headline process lesson was "run prod aggregates early — they recalibrated three severities" — all *downward* (latent, clean data). 4b-2's prod query did the opposite: it found #99 had already corrupted articles 39 and 40, moving it from moderate to critical. Same tool, same discipline, opposite direction. Aggregates don't just de-escalate — they tell you the truth in whichever direction it runs.

3. **The heavy LLM pipeline is barely used; the simple flow is the one that broke.** Two articles have gone through the multi-call Sonnet generation chain. Fifty-one went through `series-sections`. The flow with five LLM calls and the scariest token budgets has a near-zero production footprint; the flow that's one SQL statement is the most-exercised and the one with the critical bug.

4. **Ten flows, fewer findings than edu's five.** The article pipeline has twice the flow count of the edu pipeline but produced 6 issues to 4b-1's 11. It mirrors edu where edu was already audited (research upload) and is genuinely *better* than edu where it counts (regeneration guards). "Smaller than 4b-1" — the scope estimate — held, and the reason is that a well-guarded pipeline with more surface beats a poorly-guarded one with less.

5. **`_generate_references_section` is byte-identical between the two modules — and they already cross-import.** `edu_research.py` imports `extract_suggestion_title` *and* `HAIKU_MODEL` from `research.py`. So the two modules already depend on each other; someone extracted *part* of the shared surface and stopped, leaving a 32-line function copy-pasted verbatim. This is the third Area-4 instance of the exact "noticed the problem, fixed half of it" shape — 4c saw it in `educator_service`, 4b-1 saw it in the `REF:` line, 4b-2 sees it here.

6. **The one LLM call site with error handling is on the least-critical path.** Exactly one of the ~11 `messages.create` sites in the article pipeline is wrapped in `try/except` — `generate_research_summary`, called by the infographic side-branch (Flow J). The main article-generation chain (Flows A, D, E, F) wraps nothing. The defensive instinct was applied to the optional flow and skipped on the load-bearing one.

---

## Process notes for the Phase 1 final report

- **The fix-ordering composition pattern works** — see "Toward a global fix ordering" below. The final report inherits a working two-pipeline composition, not a blank slate.
- **Merge the research-upload findings.** #87 / #88 / #89 / #100 are one work item across two modules. Don't list them as four backlog lines.
- **Prod aggregates earned their place a third time** — 4b-1 (down), 4b-2 (up). The final report should treat "run prod aggregates before finalizing severity" as a confirmed Phase-1 practice, not a per-session option.
- **Re-derive the module inventory including function-local imports** — 4a's caller-grep missed `image_prompt`'s caller.
- **The bug-impact-by-traffic point generalizes.** Wherever the final report ranks findings, flow traffic is now measurable (article-generation: 2; series-sections: 51). Severity should reflect it.

---

## Fix ordering for article pipeline

The second fix-ordering analysis. Same format as 4b-1: of the issues touching the article pipeline, what gets fixed first, what runs in parallel, and where one fix changes another's scope.

### Issues in scope

**Filed this session (4b-2):** #99, #100, #101, #102, #103, #104.

**Pre-existing issues that touch the article pipeline:**
- **#76** — unified Anthropic wrapper (the ~11 article-pipeline LLM call sites; cross-domain, shared with edu)
- **#77** — defensive LLM-response parsing (`article_generation`, `suggestion_generation`, `research`)
- **#78** — Anthropic budget cap / observability
- **#68** — no SDK timeouts
- **#22** — FK constraints (names `Article.research_id` explicitly)
- **#24** — status-column unification (`Article.outline_status`)
- **#8** — swallowed-exceptions catalogue (the article modules' uncaught LLM calls are in §5)
- **#93** — edu outline truncation (parallel to #101; cross-referenced, not shared code)
- **#71** — DeepL error handling (Flow G's translation failure mode)

**Cross-pipeline set:** **#100** must be fixed with **#87 / #88 / #89** (edu) — same bug, two modules.

### Dependency structure

```
  FOUNDATION (parallel, do early)
    #76 Anthropic wrapper  ──reshapes──▶  #77, #78, #101, #102, #103
    (cross-domain — shared with 4b-1 edu pipeline)

  CRITICAL PATH (start immediately — NO prerequisite)
    #99 series-sections guard + raw-SQL→ORM      ──┐
    + one-time prod cleanup of articles 39, 40      │  fully standalone
                                                    │  (contrast: edu's #91 was
                                                    ▼   gated behind #97)
  CROSS-PIPELINE SET (one coordinated PR)
    #100 (blog) + #87 + #88 + #89 (edu)  ── research-upload hardening

  LLM-QUALITY CLEANUP (after #76)
    #77 defensive parsing  ──▶  folds into the wrapper
    #101 token budget      ──▶  becomes "set the wrapper's budget param"
    #102 condensation      ──▶  becomes "call the shared condenser"
    #78 budget cap / observability

  PARALLEL TRACK (independent, no blockers, fix anytime)
    #104 outline-status guard   #103 research_common extraction
    #68 timeouts                #22 FK on research_id
    #24 outline_status enum     #71 DeepL error handling
```

### Proposed sequence

**Wave 1 — start immediately (the two are independent of each other).**

1. **#99 — series-sections regeneration guard (CRITICAL).** Has no prerequisite — unlike edu's #91, it is not gated behind a schema change. Two parts: the code fix (idempotency guard + raw-SQL→ORM), and a **one-time production content cleanup of articles 39 and 40** which can and should happen *now*, ahead of the code fix.
2. **#76 — unified Anthropic wrapper.** Cross-domain foundation; coordinate with 4b-1's ordering (it is the same single item). Reshapes #77, #78, #101, #102, #103.

**Wave 2 — research-upload hardening (cross-pipeline).**

3. **#100 + #87 + #88 + #89** — one coordinated PR spanning `dashboard.py` and `edu.py`: explicit `suggestion_id`, a single consistent overwrite policy (reject, or re-review + reset status + flag stale dependents), size caps + UTF-8 decode handling. Fixing only one side leaves the two pipelines divergent.

**Wave 3 — LLM-quality cleanup (after #76).**

4. **#77** — defensive parsing folds into the wrapper (also resolves the `suggestion_generation` `StopIteration`).
5. **#101** — token budget: if #76 landed first, this is "set the budget on the wrapper call"; if not, a standalone `MAX_TOKENS` bump + a `num_suggestions`-derived size.
6. **#102** — condensation: if #76 landed first, "call the shared condenser"; if not, port `_condense_research` from the edu pipeline.
7. **#78** — budget cap / observability.

**Parallel track — independent, fix anytime.**

- **#104** (outline-status guard) — one guard clause; the most agent-friendly issue this session.
- **#103** (research_common extraction) — agent-friendly; cleaner after #76 but not blocked by it.
- **#68** (timeouts), **#22** (FK on `research_id`), **#24** (`outline_status` enum), **#71** (DeepL error handling) — small cross-cutting fixes.

### Where fixing one issue changes another's scope

1. **#76 → #101.** The unified wrapper owns token-budget policy. #76-first: #101 shrinks to setting a parameter. #76-delayed: #101 is a standalone constant bump. (Same pattern 4c/4b-1 flagged for #85/#93 vs. #76.)
2. **#76 → #102.** With the wrapper in place, condensation is a shared helper both pipelines call. #102-standalone means porting `_condense_research`; #76-first means #102 is "wire in the shared condenser."
3. **#76 → #103.** The DRY extraction (`research_common.py`) and the wrapper interact — the duplicated Haiku calls inside `validate_*_document` are exactly what #76 absorbs. Not a hard dependency, but doing #76 first makes #103's extraction cleaner (the extracted module calls the wrapper, not a raw client).
4. **#76 → #77.** As in 4b-1: #77 substantially *becomes* #76 — the wrapper centralizes the defensive parse.
5. **#99 depends on nothing.** This is the structural contrast with 4b-1: edu's critical (#91) was gated behind a moderate (#97 unique constraint) — the most urgent fix could not start first. The article-pipeline critical (#99) has no prerequisite. It is both the most urgent fix *and* immediately startable. The fix-ordering analysis exists to surface inversions like edu's; here it surfaces the absence of one.
6. **#100 ↔ #87/#88/#89 — a scheduling unit, not a scope change.** They are not dependencies; they are the same fix that must ship together to keep the two upload paths consistent.

---

## Toward a global fix ordering

The Phase 1 final report will produce the full global backlog sequence. This section is the bridge: how 4b-1's edu ordering and 4b-2's article ordering compose. It identifies where the two interact, where they're independent, and where the shared foundations slot in — it does **not** attempt the complete sequence.

### Where the two pipeline orderings are independent

The two **critical paths touch disjoint code**. Edu's critical path is `#97 → #91 → #90` — the `edu_materials` table, its unique constraint, and the `generate_edu_materials` / `generate_edu_slides` generators. Article's critical path is `#99` — `series_sections.py` and the `series-sections` endpoint in `dashboard.py`. No shared files, no shared tables, no ordering constraint between them. **They can run fully in parallel.** A team could assign edu-critical and article-critical to two people on day one and they would not collide.

### Where the two orderings interact

Three interaction points, in decreasing order of how tightly they couple:

1. **Research-upload hardening — a genuine code merge.** Edu's #87/#88/#89 and article's #100 are the same three bugs in `edu.py` and `dashboard.py`. The global ordering should carry **one** "research upload hardening" work item that fixes both modules in one coordinated PR. Fixing one pipeline's upload and not the other's leaves the system with two research-upload endpoints that disagree on correlation mechanism, overwrite policy, and input limits. This is the single place where the two pipeline backlogs must be physically merged rather than merely sequenced.

2. **The LLM foundation — #76 and its downstream cluster.** #76 is the linchpin of both orderings. It reshapes edu's #93, #92, #77 *and* article's #101, #102, #103, #77. The global ordering schedules #76 **once**, early, as cross-domain Wave-1 work — and then both pipelines' "LLM-quality cleanup" waves (edu Wave 3, article Wave 3) shrink to wrapper-configuration tasks. #77, #78, #68 ride along with #76 as the same shared foundation. Whoever picks up #76 must be briefed that it has consumers in both pipelines and that the condensation helper (#102) and the `research_common` extraction (#103) are expected to live alongside it.

3. **Model hygiene — a loose pairing.** Edu's #95/#96 and article's #22/#24 are all schema-shape findings with no runtime dependency between them. They don't *need* to be merged, but doing them as one models/schema mini-batch (4b-1 already proposed sequencing #95/#96 with #22/#24/#29/#4) is cheaper than scattering six small migrations across the backlog.

### Where the shared foundations slot in

The shared foundations (#76, #77, #78, #68) belong in **global Wave 1**, alongside — not before, not after — the two critical paths. The critical paths (#91-after-#97, #99) do not depend on the LLM foundation, and the LLM foundation does not depend on them. So global Wave 1 runs three things concurrently:

- **edu critical:** #97 → #91 → #90
- **article critical:** #99 (+ the articles 39/40 prod cleanup)
- **LLM foundation:** #76 (+ #68, and #77/#78 beginning to fold in)

Global Wave 2 is the cross-pipeline **research-upload hardening** (#87/#88/#89/#100) plus the LLM-quality cleanup that #76 unlocks (edu #92/#93, article #101/#102/#103). Global Wave 3 / parallel track absorbs the model-hygiene batch and the small independent fixes (#104, #22, #24, #71, #95, #96).

### The one asymmetry worth carrying forward

The two critical paths differ in *startability*. Edu's #91 is gated — #97 (a moderate schema change) must land first, so the most urgent edu fix cannot be the first edu commit. Article's #99 is ungated — it is both the most urgent article fix and immediately startable. When the Phase 1 final report sequences the global backlog, **#99 and the articles 39/40 cleanup are the earliest-completable critical work in the entire phase**; #91 trails its prerequisite. That is the kind of cross-pipeline scheduling fact the global ordering exists to make visible, and it is the recommended starting point for the final report's Wave 1.
