# Structured swallowed-exceptions catalogue

## Purpose

A categorized catalogue of every instance of a cross-cutting pattern, posted as a single comprehensive comment on a single tracking issue, with a rationale column that lets the catalogue compress to a handful of follow-up issues rather than dozens. The original pilot instance was the swallowed-exceptions sweep across the services layer (issue #8), which produced one structured comment with ~40 catalogued sites plus 3 standalone filings — instead of the ~30+ scattered issues that per-site filing would have produced.

The spec's name is "swallowed-exceptions catalogue" because that was the worked example, but the document type is general — any cross-cutting concern that produces many similar instances qualifies. Possible future applications: dependency drift across a multi-package monorepo; deprecated API usage across a large frontend codebase; rate-limit-handling inconsistencies across many vendor wrappers.

The catalogue's deeper value is **rationale capture**. Per-site issue filings record the *what* of each instance; the catalogue's rationale column records the *why* — "this swallow is wrapper-induced, will resolve when #67 lands"; "this swallow is intentional, the transient-error fallback is correct here"; "this swallow is novel and needs its own analysis." Rationale is what makes a backlog actionable; row counts alone are not.

## When it's produced

When the **systematic-sweep** adaptation is active — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md).

Triggers:
- A pre-existing cross-cutting tracking issue ("sweep services for X") exists.
- The instances of the pattern are mostly resolvable by fixing one or two *root* causes (e.g. one wrapper contract bug produces many caller-side swallow sites; fixing the wrapper compresses the catalogue).
- Per-site filings would produce 20+ near-identical issues whose value is in the aggregate, not the individual.

## Template

The catalogue lives as a **single comment on a single tracking issue**, not as a series of issues. Its structure:

### Section 1 — Wrapper-induced sites

Sites where the swallow is downstream of a wrapper-contract bug. These resolve when the wrapper is fixed; the catalogue entry exists for traceability but does NOT warrant a standalone issue.

| File:line | Pattern | Wrapper-contract root cause | Will resolve when |
|---|---|---|---|

### Section 2 — Independent active-masking

Sites where the swallow is a local decision (not wrapper-induced) and is actively masking a real production failure mode. These warrant standalone issues.

| File:line | What's swallowed | What it masks | Standalone issue # |
|---|---|---|---|

### Section 3 — Independent intentional fallback

Sites where the swallow is a local decision and is defensible — transient-error fallback that's actually correct, a guarded recovery path, etc. Rationale recorded but no issue filed.

| File:line | What's swallowed | Rationale (why intentional) |
|---|---|---|

### Section 4 — Pattern variants observed (aggregate counts by shape)

A summary of the *shapes* the pattern takes. For swallowed exceptions, the shapes were `except Exception: pass`, `except Exception: return None`, `except Exception: break`, `except (SpecificError,): log.error(...)`, etc. The aggregate counts surface the architectural finding: which shape dominates, which is rare, which is worth standardizing.

### Section 5 — Inverse pattern: uncaught propagation

A separate section for the *inverse* failure mode — where the catalogue's primary concern is swallow, but the audit also surfaces sites where the opposite problem (uncaught propagation when a swallow-or-handle would have been correct) is the actual bug. The pilot's catalogue surfaced ~18 uncaught Anthropic calls here.

After the catalogue, the session report has a short companion section (see "What's filed separately and why" in the worked example below).

## Standalone-filing decision rules

The catalogue is the primary deliverable. Standalone filings are reserved for:

1. **Active bug-masking swallows.** A swallow that hides a real failure mode affecting production today. Filed because the catalogue cannot capture an actionable single-site fix.
2. **Structurally novel patterns.** Patterns that don't fit any of the categories above and need their own analysis. Probably rare.
3. **Already-named items from prior areas** that need a proper issue, not just a catalogue entry.

Everything else lives in the catalogue. The intent is to make the tracking issue itself the primary deliverable — a single comprehensive reference — rather than a scattering of 30+ tiny issues.

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from a swallowed-exceptions sweep area report (full instance in the case study, `case-study/pilot/phase-1-area-4c-report.md`):

```
### Catalogue location reference

The full catalogue is posted as a single structured comment on the
tracking issue (#8).

Sections in the comment:
- §1 — Wrapper-induced sites (20 entries; resolve via #67/#70/#74)
- §2 — Independent active-masking (3 entries; all filed)
- §3 — Independent intentional fallback (17 entries; rationale recorded)
- §4 — Pattern variants observed (aggregate counts by shape)
- §5 — Inverse pattern: uncaught propagation in LLM modules

### What's filed separately and why

| # | Title | Why standalone | Severity | Agent-friendly |
|---|---|---|---|---|
| #83 | image_storage.generate_thumbnail silently swallows Pillow failures | Caller has no error trail; UI shows broken thumb with no actionable signal | moderate | yes |
| #84 | orders.py:495-498 except Exception: pass masking PayPal cancel failures | Textbook bad pattern; produces uncorrelated PayPal payments if the assumed-cancel actually failed | moderate | yes |
| #85 | media_scoring broad except Exception aborts entire scoring run | Transient API errors should skip the batch, not terminate; broadest catch in LLM modules | moderate | yes |

On #84 (the scope edge): the swallow lives in a router, not a service.
Area 2 explicitly handed it to 4c via its "Newly observed" section.
Filing here during 4c with a scope note rather than punting back to
Area 2's backlog — the catalogue is the right home for this pattern
even when the line is in api/.

Everything else — 16 wrapper-induced sites, 17 intentional fallbacks,
18 uncaught LLM calls — lives in the #8 catalogue. Per-site filings
would have been ~30+ issues, most of which would be obsolete after
#67/#70/#74/#76 land.
```

The catalogue's compounding effect from prior cross-session investment is also worth surfacing:

```
What was easier than expected:
- The 4a "newly observed for 4c" section was load-bearing. Roughly 70%
  of the wrapper-induced sites I catalogued were already named at the
  line level in the 4a report. The sweep mostly verified rather than
  discovered. Without the 4a groundwork this would have been a 3-4
  hour audit, not 1.5 hours.
```

This is the cleanest evidence in the corpus that cross-session investment compounds.

## Pitfalls

- **Filing per-site instead of cataloguing.** If a sweep produces 30 nearly-identical issues, the sweep's framing was wrong. Reframe as a catalogue with a tracking issue, file at most 3-5 standalone issues for the genuinely-independent cases.
- **Cataloguing without rationale.** A catalogue without the rationale column is a list. The rationale column is what makes the catalogue actionable — without it, future maintainers cannot tell which entries are intentional vs. masked-bug vs. wrapper-resolvable.
- **Mixing the §2 (active-masking, file standalone) and §3 (intentional fallback, rationale only) decisions inside the same row.** Each row belongs to one section. The classification IS the judgment call the catalogue exists to make.
- **Letting batch-and-confirm stay enabled.** The catalogue is mechanical transcription against a structure; batch-and-confirm adds friction without value. The systematic-sweep adaptation explicitly drops batch-and-confirm for catalogue work — and re-enables it for the standalone-filing synthesis at the end.
- **Missing the §5 inverse-pattern section.** A swallow sweep that doesn't surface the uncaught-propagation cases is incomplete — the two failure modes are mirror images and the audit is in position to see both.

## Cross-references

The catalogue is the deliverable a **systematic-sweep** adaptation produces — see [the adaptations reference](../../../skills/area-audit/references/adaptations.md). The adaptation explicitly drops batch-and-confirm for catalogue work and re-enables it for the standalone-filing synthesis at the end.
