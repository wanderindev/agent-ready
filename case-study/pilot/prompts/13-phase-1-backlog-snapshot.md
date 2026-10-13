Stock-take session: produce a current snapshot of the project's GitHub
issue backlog as the input for the upcoming Phase 1 synthesis report.

This is a small focused session. ~20-30 minutes. No PR. The output is a
single markdown file with the snapshot, plus a brief synthesis-prep
observation list.

## Goal

Phase 1 produced 99 filed issues across 11 audit sessions plus inline
fixes (#21, #31, #49 PR, etc.). Some are closed; most are open. Before
the synthesis report writes the global fix-ordering, we need an
accurate current picture of what's actually open, by what dimensions,
and how it composes.

## What to produce

A single file: `docs/pilot/phase-1-backlog-snapshot.md`

Required sections:

1. **Headline counts.** Total open issues, total closed, plus the closed
   ones broken out by mechanism (closed-via-PR, closed-as-duplicate,
   closed-as-wont-fix, etc. — use whatever GitHub tells you).

2. **Open issues by severity.** Counts for `code-quality:critical`,
   `code-quality:moderate`, `code-quality:nice-to-have`, plus any
   `bug` or `enhancement` labels that show up. Note any issue without
   a severity label.

3. **Open issues by agent-friendly status.** Count of `agent-friendly`
   issues, broken down by severity within that. The agent-friendly
   moderates and nice-to-haves are the most actionable Phase 2 entry
   points; the agent-friendly criticals (if any) are interesting.

4. **Open issues by audit area / origin.** Trace each open issue back
   to its source: Phase 0 backlog (issues #3-#19), Area 1 (data layer
   — #21-#29), Area 2 (payments — #31-#47), and so on. Use the audit
   reports as the source of truth for which issue numbers belong to
   which area. Include "inline / cross-cutting" for anything that
   doesn't fit a single area.

5. **Closed issues — what got resolved and how.** A short table:
   issue number, title, how it closed, which session or PR. The
   purpose is to make the audit's actual progress visible (some
   issues closed inline during audits, some via dedicated PRs, some
   may have been duplicates).

6. **The "shared foundation" cluster.** Specifically pull out:
   - #76 (unified Anthropic wrapper) and its dependent cluster (#77,
     #78, #68, plus the LLM-quality cleanup issues from edu and
     article pipelines)
   - #67 (Composio contract) and its caller-side cluster (#70, #74,
     plus the 4c catalogue entries)
   - #50 + #52 + #60 (educator access — backend + frontend)
   - Any other multi-issue work that the fix-ordering bridges
     identified
   These are the items whose ordering matters most for Phase 2+ and
   whose framing as "clusters not individuals" is part of what the
   synthesis report will articulate.

7. **The Wave-1 candidates from the four bridge sections.** Per the
   cumulative bridge sections (4b-2, Area 5, Area 6), global Wave 1
   has four concurrent tracks: edu critical (#97 → #91 → #90),
   article critical (#99 + articles 39/40 cleanup), LLM foundation
   (#76 cluster), frontend safety-net (#7, #106, #110). List the
   issue numbers and current open/closed status for each.

8. **Synthesis-prep observations.** A short bulleted list (5-10
   items) of things you notice from compiling this snapshot that
   the synthesis report should account for. Examples of what fits
   here:
   - Severity distribution patterns (e.g. "of 99 issues, only N
     are critical, suggesting most work is moderate or below")
   - Agent-friendly distribution patterns (e.g. "frontend issues
     are ~80% agent-friendly, backend services are ~20%")
   - Issues that have closed and changed the calculus of others
     (e.g. "#21 closed inline, which means #3's prerequisite is now
     met")
   - Any issue that appears stale or worth re-examining (e.g. filed
     critical but the area report says it's latent — does the
     severity still hold?)
   - Any obvious clustering the audit reports didn't name explicitly

   Don't analyze deeply here — just note what you notice. The
   synthesis report will do the heavy interpretation.

## How to get the data

Use `gh issue list` with appropriate filters. Some useful invocations:

- `gh issue list --state open --limit 200 --json number,title,labels,
  state,createdAt,closedAt`
- `gh issue list --state closed --limit 200 --json number,title,labels,
  closedAt,closedBy`
- `gh issue list --label "agent-friendly" --state open --json number,
  title,labels`

The audit reports themselves are the source of truth for which issue
belongs to which area — read them to map issue numbers back to areas.
The mapping isn't always obvious from issue titles.

## What this is NOT

- Not a fix-ordering analysis (that's the synthesis report's job)
- Not an interpretation or recommendation (also synthesis)
- Not a re-audit of any issue
- Not opening or closing issues, not editing them, not commenting
  on them
- Not analysis of which issues are most important

This is just an accurate, well-organized snapshot of the current state.

## Working style

- No batch-and-confirm — this is read-only data aggregation
- No prod queries needed
- If you find issues that lack expected labels (no severity, or
  filed under an area that doesn't have a report), surface them in
  section 8 rather than silently re-classifying
- If two issue numbers look like they refer to the same underlying
  work, note it in section 8 — don't merge or close anything
- Cross-check the audit reports' "closed inline" claims against the
  GitHub state — if a report said something closed but GitHub still
  shows it open, that's a discrepancy worth noting

## Scope estimate

20-30 minutes. The aggregation itself is mechanical. The trickier
part is mapping issue numbers back to audit areas using the reports
as ground truth, and noticing the synthesis-prep observations.

Begin by running the gh queries and confirming the total open vs
closed counts match my mental model (~95 open, ~5 closed, give or
take). If the counts are significantly different (e.g. 80 open, 20
closed), flag that immediately — it means something closed that I
don't remember closing, and we should figure out what before
proceeding.

Save the snapshot to `docs/pilot/phase-1-backlog-snapshot.md`. No
PR — the synthesis session will land the snapshot along with
whatever the synthesis report becomes.
