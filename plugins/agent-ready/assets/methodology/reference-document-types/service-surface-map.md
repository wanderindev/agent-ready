# Service surface map

## Purpose

When an audit area contains a large set of modules that need to be sliced before the deep read, the service surface map is the inventory-classify-defer-with-rationale document that locks the split. Its primary value is making the area's boundary visible and decidable: every module either belongs in this area's deep read, gets deferred to a later area with a rationale, or is out of scope entirely. The map becomes the reference subsequent areas use to verify they're not re-auditing modules already covered and to confirm modules they expect to be in scope actually are.

The map is also a **dependency sketch**: which modules call which others, which depend on which external vendors, which modules are imported by many downstream callers (the high-leverage audit targets). The dependency sketch is half the value — it tells the audit which modules to read first, because a module imported by four others has bugs that propagate widely.

## When it's produced

In Area-4a-class areas — areas that own a large module set whose members need to be classified before the deep read. The original pilot instance was the services-layer audit (20 modules); the same shape applies any time the audit faces a similar inventory problem (e.g. a large router set, a large schema directory, a frontend-component sprawl).

## What triggers it

- The area's directory contains more files than the session can deeply read end-to-end (>10-15 modules of substance).
- The modules split naturally into cross-cutting (read in this area) vs. domain-specific (defer to a later area).
- Subsequent areas' scope depends on knowing which modules this area covered.

## Template

The map has three sub-sections. All three are required when the surface map is produced.

### Sub-section 1: Inventory

A row-per-module table with these columns:

| Module | LOC | Role (one line) | External vendor | Internal callers | Phase 1 scope |
|---|---|---|---|---|---|

- **LOC** anchors the reader's mental model of size.
- **Role** in ≤ 10 words — what the module *does*, not what it *is*.
- **External vendor** — the integration the module wraps, if any. Empty for pure domain logic.
- **Internal callers** — what else in the codebase imports this module. The count is half the leverage signal.
- **Phase 1 scope** — explicit decision: "4a (filed)" / "4b" / "Audited Area 2" / "out of scope" / "ambiguous — propose split". This column makes the area boundary auditable.

### Sub-section 2: Dependency graph

An ASCII or mermaid sketch showing which modules call which, with external vendors as edge labels and the high-import-count modules visually prominent. This is the navigation aid, not the inventory.

### Sub-section 3: High-leverage targets

A row-per-high-leverage-module table:

| Module | Imported by | Status |
|---|---|---|

Surface the modules imported by 4+ others. These are the highest-leverage audit targets because their bugs propagate widely. The map's most actionable conclusion is "module X is the root of the leverage graph; audit it first."

## Worked example (from the pilot)

`PIC-WORKED-EXAMPLE`. A real instance of this spec, from a services-layer area report (full instance in the case study, `case-study/pilot/phase-1-area-4a-report.md`), abridged:

```
### Inventory: all 20 service modules

| Module | LOC | Role | External vendor | Internal callers | Phase 1 scope |
|---|---|---|---|---|---|
| composio_client.py | 52 | Composio singleton + send_email helper | Composio (Gmail) | notifications, mailing_list, educator_service, contact.py | 4a (filed) |
| translation.py | 158 | DeepL wrapper (text + MD round-trip) | DeepL | admin.py | 4a (filed) |
| image_storage.py | 292 | DO Spaces upload/download + Pillow watermarking | DO Spaces, source-URL httpx | media_library.py | 4a (filed) |
| paypal.py | 253 | PayPal Invoicing API v2 | PayPal | booking_admin, webhooks | Audited Area 2 |
| article_generation.py | 233 | Anthropic prompt → article body + outline gen | Anthropic | dashboard.py | 4b |
| ... | ... | ... | ... | ... | ... |

### Dependency graph (cross-cutting + adjacent)

            ┌─────────────────┐
contact ───▶│                 │
notifications ─▶ composio_client ─▶ Composio Gmail
mailing_list ─▶│                 │
educator_service ─▶              │
            └─────────────────┘
              ▲ (4 callers — highest leverage in 4a)

### High-leverage targets

| Module | Imported by | Status |
|---|---|---|
| composio_client | 4 services + contact.py | Critical — root of #67 |
| notifications | 5 routers | Partly audited Area 2; Composio boundary covered here |
| availability | 4 routers | Audited Area 2 |
```

The map's punchline: composio_client is the single highest-leverage module — 4 downstream services depend on it, and its wrapper-contract bug propagates to every customer-facing email path. That conclusion shaped the rest of the area's audit and the cross-area fix-ordering.

## Pitfalls

- **Treating the inventory as the deliverable.** The inventory without the dependency graph and the high-leverage targets is a list, not a map. The leverage signal is what makes the map decision-shaped.
- **Letting LOC dominate.** A 50-line module with 4 importers is more consequential than a 500-line module with 1 importer. Sort the high-leverage view by import count, not by size.
- **Ambiguous Phase-1-scope entries with no rationale.** "Ambiguous" is a valid value but it must come with a one-line proposal for the operator to react to. Silent ambiguity drops modules between sessions.
- **No approval gate.** The inventory and the cross-cutting vs. domain split MUST be reviewed by the operator before the deep read begins. The audit-plan-split decision is exactly the kind of thing the synthesis identifies as cross-session judgment.
