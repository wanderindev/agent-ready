# Cross-cutting checklist (operational summary)

Operational summary the skill reads when surfacing the checklist at start-of-area and enforcing the closing gate at end-of-area. The authoritative document is the methodology docs' `cross-cutting-checklist.md` (installed by the methodology-install skill, default `docs/methodology/`) — this file is the version the skill loads to drive the prompt's working-style block and the closing-gate behavior. When the two disagree, the methodology doc wins; update this file in lockstep.

## What the checklist is

Six items the pilot audit found *by accident* that future audits should look for *on purpose*:

- **Item 0 — The orchestrator's prior as a check.** Framing item; the disposition the other five sit inside. Not a code pattern; an experimenter discipline (state priors before; compare against findings after). Reports separately from the other five — see "How the closing gate works" below.
- **Item 1 — Partial-correction debt.** A fix-shape applied at some sibling call sites and not others.
- **Item 2 — Swallowed-failure as an umbrella theme.** Error conditions silently dropped; named as instances of an umbrella, not as independent findings.
- **Item 3 — Danger is not where complexity is.** Criticals living in the code that "looked too simple to merit scrutiny."
- **Item 4 — Two-dimensional severity (blast-radius × evidence-of-impact).** Dormant criticals vs. live moderates are not co-ranked.
- **Item 5 — Latent-but-uncrystallized risk.** Severity-relevant prod state that lowered a finding's apparent risk; the bug exists, the data hasn't crystallized it yet.

Each item is a **hypothesis from one codebase**, not a law. Future audits run the checklist partly for the items themselves and partly so the "checked, absent" dispositions land as disconfirmation evidence in the durable record.

## The disposition vocabulary

Three values for items 1-5. Distinct on purpose — do not collapse:

- **Fired** — the pattern was found in this area. Record the issue numbers.
- **Checked, absent** — looked for it; this area doesn't exhibit it. This is **prevalence data** and it is the point.
- **Not applicable** — the item structurally can't apply to this area, with a one-line why. Distinct from "checked, absent": absent is prevalence data (sought, not found); not-applicable is coverage scope (the question didn't make sense here).

Item 0 does not use this vocabulary. See "How the closing gate works" below.

## How the skill surfaces the checklist — start-of-area

Add to Slot 7's working-style block, immediately after the agent-friendly bullet and before the stop-the-line bullet:

```
- **Cross-cutting checklist.** Six patterns to actively look for during
  this audit — surfaced at the start so the agent knows to watch for
  them, not just record them at the end. The list:
    1. Partial-correction debt (sibling call sites diverge on a fix-shape)
    2. Swallowed-failure as an umbrella theme (roll up to {tracking issue
       N if one exists}, don't file independently)
    3. Danger is not where complexity is (read the simple-looking code at
       least once; do not let it slip behind the complex code)
    4. Two-dimensional severity (for any critical: note blast-radius AND
       current evidence the path is exercised in prod)
    5. Latent-but-uncrystallized risk (when prod state lowers a severity,
       say so explicitly — the bug is unchanged, only the impact evidence
       is absent)
    6. Orchestrator priors (the operator's pre-area priors are stated
       above in Slot 3 / Slot 5; treat them as hypotheses the agent's job
       is to test, not to discover)

  Authoritative spec: docs/methodology/cross-cutting-checklist.md. The
  end-of-session report's "Cross-cutting checklist dispositions" sub-
  section is required (see Slot 8) — every item gets a recorded
  disposition, including the absent and N/A ones.
```

When item 2 has no existing tracking issue, drop the `(roll up to ...)` clause.

When Slot 3's blast-radius framing or Slot 5's "what to look for" already contains a stated prior, restate it explicitly in item 6 so the agent has a verbatim hypothesis to test.

## How the closing gate works — end-of-area

**The skill refuses to mark an area complete until every checklist item has a recorded disposition.** This is the structural enforcement — it makes the act of checking non-optional, the same way the per-area fill-gate makes the per-area fills non-optional.

Mechanically:

1. Before the skill emits its closing summary for the area, it walks the report at the configured path looking for the required **Cross-cutting checklist dispositions** sub-section.
2. The sub-section must contain a disposition row for each of items 1-5 (with one of: `fired` / `checked, absent` / `not applicable`).
3. The sub-section must contain a paragraph or short structured note for item 0 (the orchestrator's-prior framing item), with the three parts: priors stated / priors that held / priors that broke. *"No priors stated for this area"* is itself a valid disposition for item 0 — explicit absence beats silence.
4. If the report file is missing the sub-section or any of the seven dispositions (5 pattern dispositions + 3 prior-paragraph parts), the skill refuses to close the area and surfaces what's missing. The operator can override only by explicit re-prompt; the gate does not silently default to "all absent."

The gate's two-part structure (5 fired/absent/N-A dispositions + Item 0's separate note) mirrors the two-part shape of the report block in `references/report-shape.md`. Do not collapse Item 0 into the disposition table — flattening it loses the experimenter-vs-reviewer framing §8 worked to elevate.

## The Slot 8 prompt block the skill writes

The skill weaves the following block into Slot 8 of the assembled prompt, immediately after the override register block (both are required end-of-session report instrumentation; the two together are the falsifiability hooks the methodology owes itself):

```
**REQUIRED: cross-cutting checklist dispositions.** At the end of the
session report, include a section titled "Cross-cutting checklist
dispositions" with two parts.

**Part 1 — Pattern items (5 rows):**

| Item | Disposition | Notes |
|---|---|---|
| 1. Partial-correction debt | fired / checked, absent / N/A | issue numbers if fired; one-line why if N/A |
| 2. Swallowed-failure umbrella | fired / checked, absent / N/A | issue numbers if fired; tracking-issue reference if rolled up |
| 3. Danger isn't where complexity is | fired / checked, absent / N/A | which simple code was read; one-line outcome |
| 4. Two-dimensional severity | fired / checked, absent / N/A | dormant-vs-live ordering note for any criticals filed |
| 5. Latent-but-uncrystallized risk | fired / checked, absent / N/A | "becomes live if X" flag-bit for severity-lowered findings |

**Part 2 — Orchestrator's priors (short paragraph):**

- **Priors stated** — the priors the operator wrote down before this area
  (often in Slot 3 / Slot 5).
- **Priors that held** — evidence the orchestrator's mental model was
  calibrated.
- **Priors that broke** — the surprises; these are the audit's most
  valuable findings.

If no priors were stated, say so explicitly — *"No priors stated for
this area"* is a valid disposition. Silence is not.

The block's purpose: capture prevalence evidence for the §8 hypotheses
so repo 2+'s synthesis can tell pilot-specific patterns apart from
general ones. Even an all-absent area is signal. The block is non-
negotiable — the skill's closing gate refuses to mark the area complete
without it. See docs/methodology/cross-cutting-checklist.md for the
authoritative checklist.
```

## Why the gate is structural

The gate-not-guideline meta-principle in the methodology docs' `conventions.md` applies here: a checklist is the most "I'll fill it in later" artifact type there is. A stated guideline (*"please remember to record dispositions"*) decays under the time pressure that makes the dispositions matter; a structural gate (*"the skill refuses to close the area without them"*) does not. The double enforcement — this skill gate AND the report-shape spec's required sub-section — exists because the runtime gate ensures the dispositions are produced in-session, and the report-shape spec ensures the dispositions land in the durable record for the synthesis.

## Composability with adaptations

- **Forensic-first.** Item 4 (two-dimensional severity) interacts directly with the forensic verdict — the dormant-vs-live ordering implication of the verdict often *is* the disposition for item 4 in a forensic-first area.
- **Model-summary-first.** The intended-vs-actual matrix's "Sound" rows are disconfirmation of priors for item 0 — the orchestrator's-prior note often cites them.
- **Systematic-sweep.** Item 2 (swallowed-failure umbrella) typically fires by construction — the sweep IS the rolling-up. The disposition note points to the catalogue.
- **Call-graph-first.** Item 1 (partial-correction debt) tends to fire — the call graph surfaces the sibling sites; partial-correction shows up at the seams.

None of these composabilities change the gate; they shape the disposition content.
