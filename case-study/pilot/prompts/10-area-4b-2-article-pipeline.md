We're starting Phase 1 Part B Area 4b-2: Article pipeline audit.

This is the final Area 4 session. 4a produced the service surface map
and vendor failure-mode summary. 4c produced the swallowed-exceptions
catalogue. 4b-1 audited the edu pipeline and produced the first
fix-ordering analysis. All three are inputs to this session.

Read these first:
- docs/pilot/phase-1-area-4a-report.md (service surface map)
- docs/pilot/phase-1-area-4c-report.md (swallow catalogue)
- docs/pilot/phase-1-area-4b-1-report.md, especially:
  - The "Newly observed for 4b-2" subsection (specific items to verify)
  - The fix-ordering format (this session inherits it)
- Issues #76, #77, #78, #68, #8 (shared foundations with edu pipeline)
- Issues #87, #88 from 4b-1 (the parallel findings to verify in article
  pipeline)

## Scope

In-scope modules (the article cluster):
- `backend/app/services/article_generation.py`
- `backend/app/services/research.py` (blog research; distinct from
  `edu_research.py` per 4b-1)
- `backend/app/services/research_summary.py`
- `backend/app/services/suggestion_generation.py`
- `backend/app/services/image_prompt.py`
- `backend/app/services/series_sections.py`
- The article router(s) — locate via 4a's surface map, likely in
  `dashboard.py` per 4a's listing
- Article-related Pydantic schemas
- Cross-references into models touched by the pipeline (Article,
  ArticleSuggestion, Research, Tag, Category)

Explicitly NOT in scope:
- Edu pipeline modules (4b-1 done)
- `media_scoring.py` (4a/4c done; confirmed not in edu use; verify
  whether article pipeline uses it)
- `translation.py` (4a done) — but verify how the article pipeline
  *calls* translation, since blog articles get translated and that
  integration point is article-pipeline territory
- Wrapper/exception concerns (4a/4c territory)

## What 4b-1 told us to verify

4b-1's "newly observed for 4b-2" was specific. Pre-load these as the
investigation backbone:

1. **Title-matching bug in blog research upload.** `edu_research.py`
   `upload_edu_research` uses a substring title-match over all
   suggestions and ignores the `REF:` line that the prompt generator
   emits. Filed as #87. Does `research.py`'s upload endpoint have the
   same shape? Same `REF:` mechanism designed-but-unused?

2. **Silent overwrite in blog research upload.** `upload_edu_research`
   silently overwrites existing research content and never resets
   `status` from `APPROVED`. Filed as #88. Same question for the blog
   research upload path.

3. **`_generate_references_section` duplication.** The function is
   duplicated verbatim between `edu_research.py` and `research.py`.
   4b-1 said: 4b-2 should consider filing this as a DRY finding.
   Confirm the duplication and decide.

4. **Regeneration overwrite parallel.** 4b-1's headline finding was
   #91: edu material generation has no regeneration guard. Does
   article generation have the same shape? `generate_article` /
   regenerate paths — what happens to an APPROVED, published article
   if regeneration is triggered?

5. **`suggestion_generation.py` `StopIteration` risk.** 4c catalogued
   `next(b for b in message.content if b.type == "text")` as a
   `StopIteration` risk in this module. 4b-2 folds it into the #77
   work — confirm it exists, reference #77, don't file separately.

6. **`image_prompt.py` orphan check.** 4a noted this module has no
   detected callers in services/ or api/. 4b-2 should verify
   whether it's invoked from a script outside `backend/app/`, or
   it's dead code. If dead, file as a #96-style cleanup finding.

## What else to look for (article-pipeline-specific)

**Article lifecycle**
- Suggestion → research → article generation → translation →
  publication. Where are the transition gates? Status field on
  Article — what are the valid states and transitions?
- Translation integration: when does an article get translated?
  Is it triggered manually or as part of the generation flow? What
  fails if DeepL is unavailable mid-flow?
- Publication: does generation set a `published` state, or does that
  require explicit approval? Same `status` confusion as #24?

**LLM orchestration (specific to article generation)**
- Article generation is the heaviest non-edu LLM flow. Walk the
  call chain: suggestion → research → outline → article → summary?
- Token budgets across the chain — consistent? Sized appropriately
  for blog-length content (probably longer than edu-grade-band
  guides)?
- The "long research docs cause LLMs to ignore constraints" workaround
  from project memory: where does it live? Is it the same workaround
  4b-1 hinted at, or different?

**Series and sections**
- `series_sections.py` is unique to article pipeline. What does it
  do? Multi-part articles? Sectioning logic that splits long content?
- Are series internally consistent (does part 2 know about part 1's
  context)?

**Image prompts**
- If `image_prompt.py` is alive: how does its output get used? Is
  it fed into Gemini Image Generation Pro per project memory?
- If dead: file the cleanup.

**Article ↔ research linkage**
- Article model has a `research_id`. Same XOR question as edu? Can
  an article exist without research? Without an approved research?
- 4b-1 found `EduMaterial`'s discriminated union (#95). Does Article
  have an analogous undisciplined polymorphism?

**Prompt injection check**
- 4b-1 found the edu pipeline fully admin-gated, no injection
  surface. Verify the article pipeline is the same shape. If any
  article endpoint takes public/educator input that reaches an LLM
  prompt, that's a different risk category.

**Things from earlier areas to verify**
- The five separate `anthropic.Anthropic()` instances 4a flagged —
  most of them live in article-pipeline modules. Confirm and reference
  #76; don't re-file.
- The `_get_client` import-from-private-module pattern that
  `suggestion_generation` and `edu_material_generation` both use.
  Edu side documented in 4a; verify suggestion_generation's usage.

## Working style

- **Batch-and-confirm** as always.
- **Severity calibration:** Same standards as 4b-1. A live overwrite
  of published content is critical. Lifecycle bugs that corrupt
  state are critical. Missing recovery is moderate. Inconsistent
  patterns are nice-to-have.
- **Agent-friendly:** Same standards. Domain-pipeline changes
  rarely qualify unless they're cosmetic or single-file scope.
- **Stop-the-line:** Same triggers as 4b-1.
- **Don't re-audit wrapper concerns.** 4a/4c covered them.
- **Don't re-file edu pipeline findings.** Reference them when
  patterns parallel; don't duplicate.

## Production data access

Same pattern. Surface for explicit approval before any prod query.
Aggregates only — no article content, no PII.

Useful queries likely include: count of articles by status, count
of articles with research_id null/populated, count of orphan
Research rows (research without article), distribution of
Article.translated state if such a field exists, count of articles
per series if series have a table or FK structure.

Run them early — 4b-1's experience was that prod aggregates
recalibrated three severities.

## Fix-ordering analysis (continued from 4b-1)

This session produces the **second** fix-ordering analysis. The
format is established in 4b-1's report. Apply it to:

1. Issues filed this session that touch the article pipeline
2. Pre-existing issues that touch the article pipeline (per the
   inputs list above plus anything else relevant)
3. The shared foundations (#76, #77, #78, #68) — note these the
   same way 4b-1 did, as cross-domain, scheduled once

End the report with a brief section called **"Toward a global fix
ordering"** — a half-page sketch of how this session's ordering
and 4b-1's ordering compose into a single backlog sequence for
the eventual Phase 1 final report. Don't try to produce the
complete global sequence yet — just identify where the two
pipeline orderings interact, where they're independent, and where
the shared foundations slot in.

The intent: the Phase 1 final report will produce the full global
ordering, but it'll have a working composition pattern to inherit
from this session.

## End-of-session report

Save as `docs/pilot/phase-1-area-4b-2-report.md`. Same shape as
4b-1's report. Required sections:

- Executive summary
- By-the-numbers
- What was audited (with article pipeline call graph)
- Item-by-item findings
- Stop-the-line discussion
- What's filed vs deferred
- Newly observed (for whichever areas remain, plus Phase 1 final)
- What surprised me
- Process notes for the Phase 1 final report
- Fix ordering for article pipeline
- Toward a global fix ordering (the new bridge section)

## Scope estimate

Smaller than 4b-1, because much of the foundational work is done.
Expect 1.5-2 hours and 6-10 issues filed. Some of the article
pipeline's findings will mirror 4b-1's — reference them via the
4b-1 issue numbers rather than re-filing. If the article pipeline
mirrors edu more closely than expected, the count drops further.
If it has its own surprises (series logic, translation integration),
the count rises.

Begin by:
1. Reading the inputs above
2. Producing the article-pipeline call graph (same approach as
   4b-1's five-flow map)
3. Verifying the six items from 4b-1's "newly observed for 4b-2"
   list — quick spot-checks, not deep audits
4. Proposing a session structure

Wait for my approval on the call graph and the spot-check results
before starting the per-stage audit.
