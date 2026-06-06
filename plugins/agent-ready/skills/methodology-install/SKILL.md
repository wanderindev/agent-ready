---
name: methodology-install
description: "Install the audit-to-autonomy methodology docs into a target repository's own tree — copy the portable methodology directory in, rewrite the cross-links that would otherwise dangle (skill paths, case-study pointers), create the prompts directory and INDEX, confirm the cross-session register ships empty, and orient the operator on the pilot worked examples. Run after repo-bootstrap, before the first area audit. Use when the operator says any of \"install the methodology\", \"add the methodology docs\", \"set up docs/methodology\", \"onboard this repo to the audit methodology\", or is preparing a project for its first area audit."
---

# methodology-install

Copies the **portable methodology docs** into a target repo's own documentation
tree (so the project owns them, checked in) and makes them coherent standalone —
the cross-links that point at the plugin or the case study get rewritten so a
reader in the target repo isn't chasing dead paths.

Plugins are read-only once installed and can't write into a project on their
own, so this skill does it explicitly with the bundled `install.sh` plus
contextual edits.

## What this does — and what it doesn't

It installs **docs and scaffolding**. It does not run an audit, and it does not
try to replace the pilot worked examples with your codebase's equivalents —
that's impossible before you've audited anything. The worked examples ship as
clearly-labeled *pilot illustration*; you supersede them organically as you run
audits (the `area-audit` skill's fill-gate makes you produce real per-area
examples every session anyway).

## Prerequisites

- Run from the **target repo's root** (a git repo). `repo-bootstrap` should
  already have run (labels + CI + protection), though it's not strictly required.
- The `agent-ready` plugin is installed (so `${CLAUDE_PLUGIN_ROOT}` resolves).

## Workflow

### Step 1 — Choose the docs home and copy
Default is `docs/methodology/` (the issue templates `repo-bootstrap` installs
point at `docs/methodology/agent-friendly-criteria.md`, so prefer the default
unless the operator has a reason). Run:
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/methodology-install/scripts/install.sh" \
     "${CLAUDE_PLUGIN_ROOT}/assets/methodology" docs/methodology
```
The script copies the tree and prints four reports: worked-example blocks,
skill-path references, case-study references, and the register row count. Use
those reports to drive the next steps.

### Step 2 — Rewrite dangling cross-links (must-fix)
The copied docs were written to live *inside the Agent Ready repo*; in a target
they need two contextual rewrites (do them as real edits, preserving good
markdown — don't blunt-sed):
- **Skill-path references** (`../../skills/area-audit/...`, `../../../skills/...`)
  → the plugin-invocation form: "the `area-audit` skill (`/agent-ready:area-audit`)".
  The skill is a plugin, not a file in the target tree.
- **case-study references** (`case-study/...`) → a stable pointer to the Agent
  Ready case study: `https://github.com/wanderindev/agent-ready/tree/main/case-study`
  (and the specific file under it where the report named one).
Use the script's line-numbered output as the worklist; fix every listed line.

### Step 3 — Confirm the register ships empty
`cross-session-register.md` should contain its explanatory sections plus an
empty table (header + separator only). The script reports the row count; if it
shows stray data rows, strip them so the target starts with a clean register.

### Step 4 — Create the prompts directory + INDEX (the preservation convention)
Ask the operator for the phase name they'll use (e.g. `audit`, `phase-1`).
Create `docs/<phase>/prompts/` and an `INDEX.md` with the mapping header (prompt
file → session report). This is the prompt-preservation convention from
`conventions.md`; setting it up now means the first session has somewhere to
land its verbatim prompt.

### Step 5 — Orient on the worked examples (no forced swap)
Tell the operator: the `PIC-WORKED-EXAMPLE` blocks the script listed are
labeled pilot illustration. They don't need replacing now — they teach what each
doc-type and severity rung looks like. They'll be superseded organically as the
operator runs audits. **Offer an optional walk**: for any block where the
operator *already* has a confident domain equivalent, replace it now and drop the
tag; otherwise leave it as illustration. Never substitute a generic placeholder
for a real example — an empty example is worse than the pilot's.

### Step 6 — Report and hand off
Summarize: docs home, cross-links rewritten (count), register state, prompts dir
created, worked-example blocks (left-as-illustration vs swapped). Point the
operator at the next step: scaffold the first audit with
`/agent-ready:area-audit`.

## Closing gate

The install is **not complete** while either holds:
- a **skill-path** or **case-study** cross-reference from the script's report is
  still unrewritten (these dangle in a standalone target — they are the must-fix
  set), or
- the **prompts directory + INDEX** haven't been created.

If either is outstanding, name what's left and tell the operator the install is
not finished. (Worked-example blocks left as labeled pilot illustration do NOT
block completion — that's by design; forcing a swap before the audit would
manufacture fake examples.)

## Files this skill uses

- `${CLAUDE_PLUGIN_ROOT}/assets/methodology/` — the portable docs being copied.
- `scripts/install.sh` — the copy-and-report helper.
