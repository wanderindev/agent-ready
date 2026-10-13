We're starting Phase 1 Part B Area 4c: Swallowed-exceptions sweep across
backend/app/services/.

This is the second of three Area 4 sessions. 4a audited cross-cutting
wrappers and produced the service surface map. 4c does a focused
systematic pattern walk for exception-swallowing across all 20 service
modules. 4b (domain pipelines) follows.

Read these first:
- docs/pilot/phase-1-area-4a-report.md, especially the "Service surface
  map" and "Process notes for the next area (4c)" sections — both are
  load-bearing for this session
- Issue #8 (the cross-cutting swallowed-exceptions sweep originally
  filed in Phase 0)
- Issues #67, #70, #74, #77 — the wrapper-contract findings from 4a
  that explain the most consequential swallow patterns
- The "newly observed for 4c" subsections of every prior area report
  (1, 2, 3, 4a) — these contain specific line-level pointers

## Why this session is different

This is a systematic sweep, not an audit. The output is a single
comprehensive comment on issue #8, structured as a catalogue, with
line-level references to every exception-swallow site in the services
layer. Plus targeted issues for swallows that warrant standalone
attention (judgment call: if it's structurally novel or particularly
severe, file separately and reference #8 from it).

The 4a report explicitly framed how to structure the output: don't
enumerate `except Exception: pass` as if instances are independent.
Distinguish:

(a) Wrapper-induced swallows — sites where a caller ignores a return
    value or exception because the wrapper's contract is broken or
    unclear. These will be largely resolved when #67 (composio
    contract) and #74 (mailing_list callers) are fixed. Catalogue
    them, reference the parent issue, do NOT file individual issues
    for each.

(b) Genuinely independent swallows — sites where the swallow is a
    local decision, unrelated to wrapper contracts. These deserve
    individual analysis: is the swallow intentional (retry-friendly
    transient error, fallback that's actually correct)? Is it
    actively masking a bug? File issues for the active-masking ones;
    catalogue the rest with rationale.

(c) Pattern variants — the LOC/Wikimedia `except Exception: break`
    crawler pattern is different from the `except Exception: pass`
    silent swallow, which is different from the `except Exception:
    return None` fallback pattern, which is different from the
    `except (SpecificError,): log.error(...)` narrow swallow. The
    catalogue should distinguish these.

## Scope

In-scope: every file in `backend/app/services/` (all 20 modules).
Specifically:
- Every `try:` block with an `except:` clause
- Every place a function returns None, False, or a sentinel when
  upstream behavior failed
- Every place a vendor-SDK exception type is caught and converted to
  a non-exception return
- The five separate `anthropic.Anthropic()` instantiation sites
  (per the 4a findings) — each is a swallow surface in the sense
  that no centralized error handling exists

Out of scope:
- Router files (`backend/app/api/`) — Areas 2 and 3 covered the
  router-side swallow patterns; don't re-audit
- Models, schemas, frontend — not this area's concern
- Re-auditing wrapper contracts — 4a already produced the wrapper
  analysis; this session uses those findings as inputs

If you find a swallow in a non-services file while tracing a service
call upward, note it but don't file. Cross-area reach is what the
"newly observed" sections are for.

## How to walk the surface

The 4a report recommended this order, which I'm endorsing:

1. **The 7 cross-cutting modules first** (composio_client,
   notifications, translation, image_storage, loc, wikimedia,
   mailing_list). These are small, bounded, and the 4a audit already
   identified most of the swallow sites. The catalogue work is
   mostly transcribing the 4a observations into structured form,
   plus any line-level sites 4a noted in passing but didn't filed.

2. **The 7 Anthropic-using modules next** (article_generation,
   edu_material_generation, edu_research, research, research_summary,
   suggestion_generation, image_prompt, media_scoring,
   series_sections — that's actually 9 modules; verify). These
   have the most uncaught `messages.create` calls per 4a's finding.
   Most "swallows" here are likely the inverse pattern — exceptions
   propagating uncaught, which is a different problem from
   swallowing but worth catalogueing alongside for the same #8 ticket.

3. **The remaining domain services** (paypal, availability, pricing,
   educator_service, plus whatever else exists). Lighter pass —
   Areas 2 and 3 already touched some of these.

Suggest a session-internal structure: do step 1 in one batch (file
nothing yet, just catalogue), then step 2, then step 3, then synthesize
the catalogue at the end. The synthesis at the end is where the issue
filing happens — looking at the full pattern lets you decide which
warrant standalone issues vs which roll up to #8.

## The catalogue structure

The output that lands on issue #8 as a comment should be structured.
Suggested shape:

The tables are illustrative; adjust as makes sense. The principle is
that the structure makes it scannable. A future reader (you, an agent,
me) should be able to find "all the swallows in image_storage" or
"all the wrapper-induced swallows" without re-reading the catalogue.

## What to file as separate issues

Restrict separate filings to:

1. **Active bug-masking swallows.** A swallow that hides a real
   failure mode that's affecting production today. (The
   `image_storage.generate_thumbnail` returning None on Pillow
   failure, where the caller ignores it and the UI shows a missing
   thumbnail with no error trail — that's the kind of thing that
   might warrant filing.)

2. **Structurally novel patterns** that don't fit any of the
   categories above and need their own analysis. Probably rare.

3. **Already-named items from prior areas** that need a proper
   issue, not just a catalogue entry. Specifically: the
   `paypal_service.cancel_invoice` swallow at orders.py:495-498
   that Area 2 flagged. It's in a router not a service, so it's
   actually out of strict scope for 4c, but Area 2's newly-observed
   list explicitly handed it to 4c. Decide whether to file (with a
   note about the scope edge) or punt back to Area 2's backlog.

Everything else lives in the catalogue. The intent is to make #8
itself the primary deliverable — a single comprehensive reference —
rather than a scattering of 30+ tiny issues.

## Working style

- **No batch-and-confirm for catalogue work.** This is mechanical
  transcription against a clear structure. Just produce the
  catalogue.

- **DO batch-and-confirm for separate issue filings.** When you've
  finished the synthesis and identified candidates for standalone
  issues, propose them as a single batch with titles, severities,
  and rationales. Wait for approval before filing.

- **Severity calibration:** A swallow that masks a live production
  failure mode is moderate to critical depending on what's being
  masked. A swallow that's an intentional fallback for a transient
  error is nice-to-have or not filed at all. A pattern variant
  observation is a catalogue entry, not an issue.

- **Agent-friendly calibration:** Mechanical "replace `except
  Exception: pass` with `except Exception: log.exception(...);
  raise`" changes might qualify if the scope is single-site and the
  semantic change is clearly correct. Cross-cutting normalizations
  (introducing project-specific exception types, say) are not
  agent-friendly. Use the 6-criteria gate honestly.

- **Stop-the-line:** Unlikely in a sweep, but if you find a swallow
  that's hiding active data loss or active security exposure (e.g.
  a swallow around a credential rotation that means rotations are
  silently failing), surface immediately.

- **Token usage:** Same as 4a — the $100 promotional credit covers
  overflow. Be thorough; the catalogue is most valuable when it's
  complete. But "thorough" means "every swallow site in services/,"
  not "expand to routers/models/frontend."

## End-of-session report

Save as `docs/pilot/phase-1-area-4c-report.md`. Shorter than the
previous reports because most of the substance is in the issue #8
catalogue comment.

Required sections:
- Executive summary (the catalogue's headline numbers)
- By-the-numbers (counts: total swallow sites found, by category,
  separately-filed issues)
- Catalogue location reference (link to the #8 comment)
- What's filed separately and why
- Methodological notes — specifically: which patterns turned out to
  be more or less common than expected, calibration data for the
  4b prompt
- Newly observed for 4b
- What surprised you

You don't need a "vendor failure-mode summary" or "service surface
map" — those are 4a's contributions and don't change here.

## Scope estimate

Per 4a's estimate, expect 10-20 swallow sites total catalogued and
2-5 standalone issues filed. Time: 1.5-2 hours. The catalogue itself
is the bulk of the work, not the issue filing.

If you're approaching 30+ catalogue entries, the services layer is
in worse shape than expected — surface and we'll regroup. If you're
approaching 10+ separate issues, you're filing too granularly — most
should be rolling up to #8.

Begin by:
1. Re-reading the 4a report's process notes section for 4c
2. Confirming the order of the sweep (cross-cutting first, then LLM,
   then remaining)
3. Proposing the catalogue table structure (refinement of the
   sketch above)
4. Then proceeding through the sweep

Wait for my approval on the catalogue structure before starting the
sweep itself. Once approved, no further check-ins until synthesis —
this should be a focused pass.
