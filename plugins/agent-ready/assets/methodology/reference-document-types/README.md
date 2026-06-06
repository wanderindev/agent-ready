# Reference document types

The audit produced **document types**, not just documents. Each spec below is a candidate template for future audits. Together they form the menu the area-audit skill and the prompt template pull from when filling Slot 8's area-specific required additions.

The shared property across all of these is that they are **outputs the audit produces alongside the issue backlog**, not byproducts of it. The issue backlog is one deliverable; the reference documents are co-equal — and in several cases they outlast individual issues by years because they encode invariants and structural shapes rather than discrete bugs.

## The eight types

| Spec | Purpose, in one line | When it's produced |
|---|---|---|
| [Service surface map](service-surface-map.md) | Inventory + classification + dependency sketch of a large module set | Areas with many modules to slice (Area-4a class) |
| [Vendor failure-mode summary](vendor-failure-mode-summary.md) | Per-vendor matrix of behavior on success / error / timeout / outage | Areas that own external integration boundaries |
| [Intended-vs-actual matrix](intended-vs-actual-matrix.md) | The general device for surfacing deviations from an invariant; three surface variations (auth model, public-error model, admin route + auth) live as instances within this spec | Areas whose findings are mostly deviations from an invariant (auth, error handling, transactions, money flow) |
| [Per-area call graph](per-area-call-graph.md) | Diagram of the flows inside a pipeline-shaped area | When findings live "in the seams between flows" |
| [Structured swallowed-exceptions catalogue](swallowed-exceptions-catalogue.md) | Categorized catalogue compressed under a single tracking issue, with rationale per row | Cross-cutting concerns where rationale matters more than row count |
| [Fix-ordering analysis](fix-ordering-analysis.md) | Per-area waves with a dependency diagram; a column for "where fixing one issue changes another's scope" | Areas whose backlog is large enough that order matters |
| [Global-ordering bridge section](global-ordering-bridge.md) | Half-page sketch composing the current area's ordering with prior areas' | From the 2nd-onward fix-ordering session, accumulating toward synthesis |
| [Forensic verdict](forensic-verdict.md) | Evidence-backed determination of whether a feature is live, dormant, or dead | When forensic-first adaptation is active |

## Spec format

Each spec is structured uniformly:

1. **Purpose** — one paragraph; what kind of clarity it produces.
2. **When it's produced** — area class / phase of the area.
3. **What triggers it** — the condition that surfaces the need.
4. **Template** — structural skeleton (column headings, section list, the matrix shape).
5. **Worked example (from the pilot)** — a real instance lifted from a Phase 1 area report. Tagged `PIC-WORKED-EXAMPLE` so the methodology-install pass can find and swap them.
6. **Pitfalls** — common bad fills, surfaced from where the corpus shows the pattern wobbling.

## A reading note

The specs are written so the **template** (the structural skeleton) transfers across repos, while the **worked example** is illustrative and will be replaced when this directory is installed into a new repo. The pilot examples carry signal that the templates alone cannot — they show what good calibration depth looks like. A spec with a real example beside it is worth far more than an abstract template.

When installing this directory into a new repo, replace the `PIC-WORKED-EXAMPLE` blocks with that repo's equivalents. Leave the structure of each spec intact.

## Cross-references

- The area-audit skill pulls from this menu when filling Slot 8.
- The prompt template lists the menu in its Slot 8 block.
- The [conventions doc](../conventions.md) names "preserve verbatim prompts" and "keep the cross-session register current" as the two practices the methodology depends on. The reference-document types are the corollary practice: produce these documents alongside the issue backlog, not as afterthoughts.
