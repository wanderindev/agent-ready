# Global-ordering bridge section

## Purpose

A half-page sketch composing the current area's [fix-ordering analysis](fix-ordering-analysis.md) with the prior areas'. Produced from the second-onward fix-ordering session, accumulating across sessions until the synthesis. The bridge does not produce the complete global sequence — that's the synthesis's job. The bridge identifies **where the current area's ordering interacts with prior areas', where it's independent, and where shared foundations slot in.**

The bridge's value is incremental: each session adds one more area's interactions; the synthesis composes them into the full global ordering. Without the bridge, the synthesis would have to derive all cross-area interactions from scratch by reading the per-area orderings cold; with the bridge, the synthesis inherits the composition work distributed across sessions.

The bridge is also a **methodology evolution case**. It started in the pilot as a small required deliverable in Area 4b-1 (proof-of-concept), grew into a cross-area composition format in 4b-2 and 5, and became the four-track Wave 1 in the backlog snapshot. Mid-audit deliverable evolution is itself a methodology — the audit plan does not have to be finished before the audit starts.

## When it's produced

In every fix-ordering session **after the first**. The first area's fix-ordering does not have a bridge (nothing prior to bridge to); the second-onward sessions do.

## What triggers it

- This is the 2nd-or-later area producing a fix-ordering analysis.
- The current area's backlog has dependencies that cross into prior areas' backlogs (shared foundations like a unified wrapper, a central budget cap, a model migration).

## Template

The bridge has three sub-sections plus, in the final per-area bridge, a "carry-forward" observation.

### Sub-section 1 — Where the area is independent

Name the parts of the current area's backlog that have no cross-area dependencies. The "they can run fully in parallel with [other areas]" observation. The pilot's 4b-2 bridge framed this as: *"The two critical paths touch disjoint code... they can run fully in parallel. A team could assign edu-critical and article-critical to two people on day one and they would not collide."*

### Sub-section 2 — Where the area interacts with prior orderings

List 2-4 interaction points, in decreasing order of how tightly they couple. For each:

1. **Name the interaction** (e.g. "Research-upload hardening — a genuine code merge").
2. **State the cross-area consequence** (e.g. "Edu's #87/#88/#89 and article's #100 are the same three bugs in different modules. The global ordering should carry one 'research upload hardening' work item that fixes both in one PR.").
3. **Name the failure mode if the interaction is missed** (e.g. "Fixing one pipeline's upload and not the other's leaves the system with two research-upload endpoints that disagree on correlation mechanism, overwrite policy, and input limits.").

The interaction points typically fall into three classes:

- **Code merges** — issues in different areas that touch the same code or implement the same fix. Should be one PR.
- **Foundation sharing** — a foundation (wrapper / budget cap / migration) that multiple areas depend on. Should be scheduled once.
- **Loose pairings** — issues that don't *need* to be merged but are cheaper to do as a batch (e.g. several small schema migrations together).

### Sub-section 3 — Where shared foundations slot in

A short statement of where the shared foundations sit in the eventual global ordering. The pilot's pattern: the shared foundations belong in **global Wave 1 alongside, not before, the area-specific critical paths**, because the critical paths don't depend on the foundation and the foundation doesn't depend on them.

### Sub-section 4 (final per-area bridge) — Carry-forward observation

In the *last* area's bridge, the one immediately preceding the synthesis, an observation worth surfacing for the synthesis to inherit. The pilot's 4b-2 bridge surfaced "the one asymmetry worth carrying forward" — that the article-pipeline critical path was un-gated (#99 is immediately startable) while the edu-pipeline critical path was gated (#91 trails its prerequisite #97). That kind of asymmetry is what the synthesis builds the global Wave 1 around.

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from an article-pipeline area report (full instance in the case study, `case-study/pilot/phase-1-area-4b-2-report.md`), abridged:

```
## Toward a global fix ordering

The Phase 1 final report will produce the full global backlog sequence.
This section is the bridge: how 4b-1's edu ordering and 4b-2's article
ordering compose. It identifies where the two interact, where they're
independent, and where the shared foundations slot in — it does not
attempt the complete sequence.

### Where the two pipeline orderings are independent

The two critical paths touch disjoint code. Edu's critical path is
#97 → #91 → #90 — the edu_materials table, its unique constraint, and
the generate_edu_materials / generate_edu_slides generators. Article's
critical path is #99 — series_sections.py and the series-sections
endpoint in dashboard.py. No shared files, no shared tables, no
ordering constraint between them. They can run fully in parallel. A
team could assign edu-critical and article-critical to two people on
day one and they would not collide.

### Where the two orderings interact

Three interaction points, in decreasing order of how tightly they couple:

1. Research-upload hardening — a genuine code merge. Edu's #87/#88/#89
   and article's #100 are the same three bugs in edu.py and dashboard.py.
   The global ordering should carry one "research upload hardening" work
   item that fixes both modules in one coordinated PR. Fixing one
   pipeline's upload and not the other's leaves the system with two
   research-upload endpoints that disagree on correlation mechanism,
   overwrite policy, and input limits. This is the single place where
   the two pipeline backlogs must be physically merged rather than
   merely sequenced.

2. The LLM foundation — #76 and its downstream cluster. #76 is the
   linchpin of both orderings. It reshapes edu's #93, #92, #77 and
   article's #101, #102, #103, #77. The global ordering schedules #76
   once, early, as cross-domain Wave-1 work. Whoever picks up #76 must
   be briefed that it has consumers in both pipelines.

3. Model hygiene — a loose pairing. Edu's #95/#96 and article's #22/#24
   are all schema-shape findings with no runtime dependency between
   them. Doing them as one models/schema mini-batch is cheaper than
   scattering six small migrations across the backlog.

### Where the shared foundations slot in

The shared foundations (#76, #77, #78, #68) belong in global Wave 1,
alongside — not before, not after — the two critical paths. The
critical paths (#91-after-#97, #99) do not depend on the LLM foundation,
and the LLM foundation does not depend on them. So global Wave 1 runs
three things concurrently:
- edu critical: #97 → #91 → #90
- article critical: #99 (+ the articles 39/40 prod cleanup)
- LLM foundation: #76 (+ #68, and #77/#78 beginning to fold in)

Global Wave 2 is the cross-pipeline research-upload hardening
(#87/#88/#89/#100) plus the LLM-quality cleanup that #76 unlocks
(edu #92/#93, article #101/#102/#103).

### The one asymmetry worth carrying forward

The two critical paths differ in startability. Edu's #91 is gated —
#97 (a moderate schema change) must land first. Article's #99 is
ungated — it is both the most urgent article fix and immediately
startable. When the Phase 1 final report sequences the global backlog,
#99 and the articles 39/40 cleanup are the earliest-completable
critical work in the entire phase.
```

## Pitfalls

- **Trying to produce the full global ordering in the bridge.** The bridge is half-a-page; the synthesis is what does the full composition. Resist the urge to finish what the bridge starts.
- **Listing every interaction.** The bridge surfaces the 2-4 most consequential interactions, in priority order. A comprehensive list dilutes the signal.
- **No carry-forward observation in the final bridge.** The final pre-synthesis bridge is the one the synthesis reads most closely. The carry-forward observation — the one structural asymmetry the synthesis should anchor its global Wave 1 on — is the bridge's most consequential single line.
- **Treating cross-area scope-reshapes as just "schedule alongside."** A scope reshape (one area's fix shrinks another's) is different from a schedule dependency (one area's fix unblocks another's). The bridge distinguishes both kinds.
- **Inventing the bridge as a one-off.** The bridge format was added at the pilot's 4b-1 because the cumulative backlog was large enough to need it. If the audit's first 2-3 areas produce small backlogs with no cross-area dependencies, the bridge is over-engineered. Add it when it earns its place.

## Cross-references

- [fix-ordering-analysis.md](fix-ordering-analysis.md) — the per-area analysis the bridge composes.
- The synthesis consumes the cumulative bridges into the global ordering — in the pilot's case, the four-track Wave 1 in §6 of `case-study/pilot/phase-1-synthesis.md`.
