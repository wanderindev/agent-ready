# Area-audit prompt template

This is the **fill-in form** an operator works from when scaffolding an area-audit session by hand. It is the surface form of the same template the `area-audit` skill assembles interactively (`../../skills/area-audit/SKILL.md`). Use whichever surface you prefer: the skill is a guided walkthrough; the template is a copy-and-edit document.

The template is structured as the **10 slots** that emerged across the 14-session pilot audit, plus the **four named adaptations** as switchable headers, plus a **snippet library** for the reusable cross-session investments. Every slot exists to pre-empt a specific failure mode; the failure mode and the verbatim prompt phrasings the corpus produced are documented inline.

---

## How to use this template

1. Copy this file into your working area for the session.
2. Walk the 10 slots top-to-bottom, filling each. The slots in bold (3, 4, 5, 7-severity, 7-stop-the-line, 8-additions, 9, 10) require area-specific fills the operator must produce — generic substitutes degrade the audit.
3. If the area's nature matches one or more of the four adaptations, weave in the corresponding adaptation snippets (below).
4. Drop in any cross-session snippets that apply (batch-and-confirm, "newly observed", "what this is NOT", $100-credit framing).
5. Confirm the report-shape block in Slot 8 includes the **override register** (required from the second codebase onward — see synthesis §10).
6. Sanity-check the failure-mode-pre-emption catalogue at the end of this doc; weave in any pre-emption lines that apply to the session's risk shape.

A complete session prompt is usually 150-250 lines of markdown. Shorter than that usually means a slot has been skimped; longer than that usually means scope has crept.

---

## The 10 slots

### Slot 1 — Identification + audit-plan pointer

```
We're starting Phase {N} Part {X} Area {Y}: {short descriptive name}.

The audit plan at {path-to-audit-plan} remains the authoritative scope
document. Read it again if context has rolled.
```

**Purpose:** Robust against fresh-session context, anchor what "Area Y" means.
**Pre-empts:** the failure mode where a fresh session has no shared frame for what area means or how it relates to other areas.

---

### Slot 2 — Read-this-first inputs

```
Read these first for context:
- {path-to-audit-plan}
- {prior-area reports — list each}, especially the "Newly observed for Area {Y}"
  subsections in each. Treat those as known inputs to verify, not as
  findings to rediscover.
- {relevant filed issues that bear on this area, by number}
```

**Purpose:** Treat prior-session findings as inputs, not findings to rediscover.
**Pre-empts:** the failure mode where the agent rediscovers what was already filed in a previous area; wastes hours and produces duplicate issues.

---

### Slot 3 — Why this area matters **(FILL REQUIRED)**

```
## Why this area matters

{One paragraph stating concrete blast radius. Examples of good calibration:
- "highest-financial-blast-radius area in the codebase"
- "narrow surface, high blast radius"
- "user-visible, not data-corruption-shaped"

Name what makes this area hard AND what makes it lower-stakes than other
areas if applicable. Both directions matter.}
```

**Purpose:** Inject the orchestrator's prior; set the severity calibration anchor for the whole session.
**Pre-empts:** the failure mode where every finding is treated as equally consequential.
**Good fills:** see `../../skills/area-audit/references/worked-examples.md` Slot 3 section.

---

### Slot 4 — Scope **(FILL REQUIRED)**

```
## Scope

In-scope files (read all in full):
- {list every file the audit must read end-to-end}
- {service-layer modules, routers, schemas — be specific}

Out of scope (note in "newly observed" if interesting):
- {areas covered by previous sessions — name them and route findings}
- {areas reserved for future sessions — name them and route findings}
- {anything explicitly punted with rationale}

If you find a module that's hard to classify, tell me and we'll decide
together rather than have you choose unilaterally.
```

**Purpose:** Make in-scope and out-of-scope both explicit; name where misplaced findings go.
**Pre-empts:** scope drift; re-audit of areas already covered; silent absorption of out-of-scope work.

---

### Slot 5 — What to look for **(FILL REQUIRED)**

```
## What to look for

**{Concern 1 — e.g. "Order state machine"}**
- {pointed question grounded in the codebase, not generic}
- {pointed question}
- {pointed question that names a specific file or function}

**{Concern 2 — e.g. "Webhook handling"}**
- {pointed question}
- ...

{Continue with 4-8 concern headings. Each heading names the things the
orchestrator wants the agent to *think about*, not the files to *read*.
Bullets carry the orchestrator's priors — what is *expected* to be wrong.}

**Things that came up in earlier areas**
- {pointer to a specific newly-observed item from a prior report}
```

**Purpose:** Channel the audit's attention along the dimensions the orchestrator cares about; surface priors so the agent can verify-or-refute rather than discover-or-miss.
**Pre-empts:** the file-walk-as-audit failure mode where the agent reads files in order without ever raising its head to see patterns.
**Good fills:** see the worked-examples reference, Slot 5 section.

---

### Slot 6 — Production data access policy (conditional)

Include when prod queries are likely useful. Omit for frontend audits, catalogue sweeps, or any area where prod inspection won't materially shape findings.

```
## Production data access

Surface for explicit approval at the top of the session. Before running
any prod query, propose the exact command you want to run, what data
it will return, and why you need it. I'll approve or reject each one.

Use the `.env.prod-readonly` source pattern — that file is gitignored
and chmod 600 on my host; sourcing it into the session gives you
DATABASE_URL but no write credentials. If a query needs more than read
access, stop and tell me — we don't have a path for that.

**Specifically do not:**
- Query PII tables for actual row data. Aggregates are fine — `SELECT
  COUNT(*), MIN(created_at), MAX(created_at) FROM {table}` is fine.
  `SELECT * FROM {table} LIMIT 5` is not.
- Pull individual-row-level amounts/values from sensitive fields. Sums
  and counts only.
- Touch any vendor API, even sandbox. We're auditing code, not making
  test calls.

Specifically useful prod queries you might propose:
- {area-specific aggregates the orchestrator expects}
```

**Purpose:** Gate prod access with explicit approval; bound the read shape; pre-empt PII exfiltration into agent context.
**Pre-empts:** two failure modes — careless reads and PII leaking into agent context (from which it cannot be reliably scrubbed).

---

### Slot 7 — Working style **(FILL REQUIRED for severity, agent-friendly, stop-the-line)**

```
## Working style

- **Batch-and-confirm**, same as previous sessions. Group findings into
  batches of 3-5, propose titles + labels + agent-friendly classification,
  get approval, file.

- **Severity calibration is {strict/standard/lenient} here.**
  {Examples of critical / moderate / nice-to-have grounded in this area.
  Each rung names a concrete behavior, not a property.
  Critical: "{concrete behavior}"
  Moderate: "{concrete behavior}"
  Nice-to-have: "{concrete behavior}"}

- **Agent-friendly is {rare/moderate/available} here.**
  {What would qualify AND what wouldn't, in the area's domain vocabulary.
  Borderline cases default to NO.}

- **Stop-the-line:** If you find {list 3-5 concrete vulnerabilities — never
  abstract. "Unsigned webhook endpoint accepting writes" not "security issues."}
  ...surface immediately. We fix inline before continuing the audit.

- **Don't re-audit prior-area concerns.** {Name the prior areas and what
  they covered.} Reference; don't re-file.
```

**Purpose:** Give the agent calibrated anchors for the three judgments it will make hundreds of times this session.
**Pre-empts:** generic-rubric drift on severity; agent-friendly inflation; missed stop-the-line; re-audit churn.
**Good fills:** see the worked-examples reference, Slot 7 sections.

---

### Slot 8 — End-of-session report **(FILL REQUIRED for area-specific additions)**

```
## End-of-session report

Save as {report path, e.g. {phase-name}/phase-{N}-area-{Y}-report.md}.
Same shape as previous reports: executive summary, by-the-numbers, what
was audited, item-by-item findings, what's filed vs deferred, newly
observed, what surprised me, process notes.

{Area-specific required additions — pick from the menu in
./reference-document-types/README.md:
- "Service surface map" (if Area 4a-class — large module set to slice)
- "Vendor failure-mode summary" (if Area 4a-class — owns vendor boundaries)
- "Intended-vs-actual matrix" (if Area 3-class — defined by an invariant)
- "Per-area call graph" (if pipeline-shaped area — flows in seams)
- "Structured catalogue" (if systematic-sweep adaptation is active)
- "Fix-ordering analysis" (if backlog is large enough that order matters)
- "Global-ordering bridge" (if 2nd-onward area producing fix-ordering)
- "Forensic verdict" (if forensic-first adaptation is active)
- Other area-specific framing}

**REQUIRED: override register.** At the end of the session report,
include a section titled "Override register" with two parts:

1. **Counts.** A simple table:

   | Override type | Count |
   |---|---|
   | Severity (proposed → adjusted by operator) | 0 |
   | Agent-friendly (proposed → adjusted by operator) | 0 |
   | Scope (in-area vs newly-observed call, adjusted by operator) | 0 |
   | Area-split or area-ordering (adjusted by operator) | 0 |

2. **One-liners.** For each override, one line: what was proposed,
   what it became, why. If there were zero overrides in a category,
   write "none."

The register's purpose is to test whether the methodology's autonomy
claim survives this codebase. Record every override, including small
ones. If you reflexively self-correct before sending for approval,
that is *not* an override (the agent corrected itself); only operator-
driven adjustments count.
```

**Purpose:** Standardize the report's shape; surface area-specific reference outputs; install the falsifiability hook.
**Pre-empts:** drift in report shape across sessions; the §4 autonomy claim becoming uncheckable for lack of data.

---

### Slot 9 — Scope estimate **(FILL REQUIRED)**

```
## Scope estimate

Expect {N-M} hours of focused work and {a-b} issues filed.

If you're approaching {upper-bound, e.g. 25+ findings}, something is
wrong — either the codebase has more rot in this area than expected
(surface and we'll regroup) or you've drifted into {Area N+k or N-k}
territory.
```

**Purpose:** Bound the audit; install a re-scope trigger.
**Pre-empts:** unbounded fan-out; silent scope creep.
**Good fills:** see the worked-examples reference, Slot 9 section.

---

### Slot 10 — Begin by **(FILL REQUIRED — must end at an approval gate)**

```
Begin by:
1. Reading {inputs above, especially newly-observed subsections}.
2. Mapping {the surface — call graph, route map, model inventory}.
3. Proposing {a session structure / a forensic plan / a catalogue
   structure} to me.
4. {Optional fourth step — e.g. "Verifying the six items from prior
   report's newly-observed list — quick spot-checks, not deep audits"}.

Wait for my approval on {the structure / the call graph / the route map /
the forensic plan} before starting {the per-stage audit / any prod
queries / the sweep itself}.
```

**Purpose:** Channel the session's first 30-45 minutes into producing an artifact the operator approves before deep work begins. The approval gate sits at a decision boundary where a wrong turn would waste hours.
**Pre-empts:** the failure mode where the agent burns half a session pursuing the wrong angle and surfaces only when the report is being drafted.

---

## Adaptation switches

The four named adaptations reshape the standard slots. They are **composable** — an area can be both forensic-first and call-graph-first. Full detail at `../../skills/area-audit/references/adaptations.md`.

### If this is a forensic-first area

Add into Slot 3:

```
**Approach the {X} portion of this audit assuming the integration may be
dead code.** Verify before assuming anything works.
```

Add a new section between Slot 5 and Slot 6:

```
## Forensic question: is {X} alive?

This is the single most important question this audit answers, and it
needs to be answered before any of the other findings can be properly
prioritized. If {X} is dead, half the issues filed for the {X} code
path are moot; if it's live, {recent near-miss} was a near-miss.

To answer it, you need to inspect production. Read the next section on
prod access before attempting anything.

The investigation:
1. Read the {X} integration code first. Map every code path that should
   touch a real {X} API.
2. Check for any logging, error-tracking breadcrumbs, or audit-log writes
   that would leave evidence in prod if the path executed.
3. Query prod (via the gated method below) for: {forensic fingerprints —
   typically `WHERE column IS NOT NULL` counts on integration-specific
   fields, plus audit-log row counts attributed to the integration}.
4. Cross-reference {time-bounded discovery — e.g. credential drift dates}.
5. Report a clear conclusion: "{X} appears live, with evidence A, B, C"
   or "{X} appears dead/never-used, with evidence A, B, C" or
   "Inconclusive — here's what we'd need to determine it."

The conclusion goes into the {area} report and shapes the agent-friendly
classification of every {X}-related issue you file. If it's dead code,
most findings drop to nice-to-have. If it's live, {recent near-miss}
itself becomes a critical retroactive finding.
```

In Slot 8, add the **forensic verdict** as a required area-specific section. In Slot 10, ensure the approval gate is on the forensic plan.

### If this is a model-summary-first area

In Slot 8, add the **{model} summary** as a required area-specific section. Spec: [./reference-document-types/intended-vs-actual-matrix.md](./reference-document-types/intended-vs-actual-matrix.md).

In Slot 10, reshape the lead-in:

```
Begin by:
1. Reading the audit plan, the prior reports' newly-observed sections,
   and any relevant phase-0 findings.
2. Mapping the {area} surface: list every route, every middleware, every
   dependency, every state transition. The map itself is half the audit
   — many {area} bugs are about gaps in the map.
3. Proposing a session structure. My suggestion: **build the {area} model
   summary first** (read everything, produce the section that goes into
   the report), then audit against it. The summary doubles as the mental
   model the audit uses.

Wait for my approval on the structure before starting any prod queries.
```

### If this is a systematic-sweep area

Reshape Slot 1's framing:

```
This is a systematic sweep, not an audit. The output is a single
comprehensive comment on issue #{N}, structured as a catalogue, with
line-level references to every {pattern instance} site in the
{scope}. Plus targeted issues for {pattern instances} that warrant
standalone attention (judgment call: if it's structurally novel or
particularly severe, file separately and reference #{N} from it).
```

In Slot 5, replace the concern-checklist with a **catalogue structure proposal** — what categories the catalogue will distinguish (wrapper-induced / genuinely independent / pattern variants / inverse patterns), what columns it will carry, what the "structurally novel" bar is for separate filing.

In Slot 7, replace batch-and-confirm:

```
- **No batch-and-confirm for catalogue work.** This is mechanical
  transcription against a clear structure. Just produce the catalogue.

- **DO batch-and-confirm for separate issue filings.** When you've
  finished the synthesis and identified candidates for standalone issues,
  propose them as a single batch with titles, severities, and rationales.
  Wait for approval before filing.
```

In Slot 9, change the upper-bound trigger:

```
If you're approaching 30+ catalogue entries, the {scope} is in worse
shape than expected — surface and we'll regroup. If you're approaching
10+ separate issues, you're filing too granularly — most should be
rolling up to #{N}.
```

### If this is a call-graph-first area

In Slot 8, add the **per-area call graph** as a required area-specific section. Spec: [./reference-document-types/per-area-call-graph.md](./reference-document-types/per-area-call-graph.md).

Reshape Slot 10:

```
Begin by:
1. Reading the inputs above.
2. Producing the {area}-pipeline call graph (which modules call which,
   in what order, with what data flowing through).
3. Verifying the in-scope module list against the actual directory.
4. Proposing a session structure (probably: call-graph first, then
   per-stage audit walking the pipeline, then state/recovery analysis,
   then {area-specific deliverable}).

Wait for my approval on the call graph and structure before starting
the per-stage audit.
```

---

## Snippet library — cross-session investments

These are copy-paste blocks the operator weaves into any session that needs them.

### Batch-and-confirm (verbatim from corpus)

```
**Batch and confirm.** Don't open issues one at a time and wait for me
on each. Group them in batches of 3-5 logically related items, show me
the proposed titles + labels + agent-friendly classification for the
batch, wait for approval, then open them.
```

### "Newly observed but don't file"

```
**Don't expand scope.** If you notice issues during this session that
weren't in scope, note them at the end in a "newly observed" section.
Don't file them — they'll be picked up in {next area}'s proper audit.
```

### "What this is NOT" device — for sessions at risk of scope drift

```
## What this is NOT

- Not {an analysis} (that's {follow-up session}'s job)
- Not {an interpretation or recommendation}
- Not {a re-audit of X}
- Not {opening or closing issues, editing them, or commenting on them}
- Not {a fix proposal}

This is just {what the session IS — one specific output, well-bounded}.
```

### The $100 promo-credit framing (depth-without-scope-creep)

```
**Token usage:** This session has access to the $100 promotional
credit pool. If you hit subscription cap during this session, continue
rather than stop — the overflow lands on extra-usage credit and we
want to be thorough on {this area's reason for depth} because it
shapes {next area's scope}. But "be thorough" is not "expand scope" —
stay in {this area}.
```

### Pre-figured finding (orchestrator's prior as a verify-or-refute target)

```
{In Slot 3 or Slot 5, where applicable:}

**Approach assuming {specific prior}.** Verify before assuming anything
works.
```

**Example (from the pilot):** phrasings such as "approach the PayPal portion of this audit assuming the integration may be dead code"; "a few thousand requests per second cracks it in minutes" (pre-figuring rate-limit finding); "what happens to an APPROVED, published article if regeneration is triggered?" (pre-figuring the regen-overwrite finding). (Full instances in the case study.)

### Stop-the-line discussion in the working-style block

```
**Stop-the-line:** If you find {area-specific concrete vulnerabilities —
list 3-5}, surface immediately. We fix inline before continuing the
audit.

{Optionally, frame the asymmetry: "less likely on the public side
than in services" / "most likely here of any area"}
```

### Don't-re-audit-prior-area pointer

```
**Don't re-audit {area X} concerns.** Exception handling, swallow
patterns, and wrapper contracts are {Area X} territory. This session
is for {this area's actual concerns}.
```

---

## Failure-mode pre-emption catalogue

Most lines in a well-constructed area-audit prompt exist to head off a specific known failure mode. The table below maps the most consequential pre-emption lines from the corpus to the failure each heads off. Weave them into the appropriate slot when the failure shape applies.

| Pre-emption line | Failure mode it heads off |
|---|---|
| *"If you're approaching 25+ findings, something is wrong"* | unbounded fan-out; the agent files every possible issue rather than maintaining severity discipline |
| *"Borderline cases default to NO"* (for agent-friendly) | agent-friendly inflation; over-promising what a fresh agent can land |
| *"Wait for my approval on the structure before starting any prod queries"* | hours wasted on the wrong angle before approval-gate friction can correct |
| *"Aggregates only — no row-level PII queries"* | PII exfiltration into the agent's context window |
| *"`SELECT * FROM bookings LIMIT 5` is not [allowed]"* | the same failure mode the aggregates-only line catches; the explicit counter-example pre-empts a known workaround |
| *"approach assuming the integration may be dead code"* | the agent treating non-functioning code as functioning, mis-calibrating severities |
| *"the map itself is half the audit"* | the agent skipping the map step and producing a thinner audit |
| *"Don't be permissive. Borderline cases default to NO"* | drift toward over-classifying as agent-friendly |
| *"Treat those as known inputs to verify, not findings to rediscover"* | rediscovery of prior findings; duplicate filings |
| *"the deliverable was a compressed taxonomy, not a sequence of judgment calls"* | applying batch-and-confirm to catalogue work, where it adds friction without value |
| *"If you notice problems that aren't part of {scope}, note them in a 'newly observed' list"* | silent scope expansion |
| *"If you find a module that's hard to classify, tell me and we'll decide together"* | unilateral classification decisions that shift work between areas |
| *"Wait for approval on the call graph and structure before starting the per-stage audit"* | the call graph being treated as a sketch rather than as an approval-gate artifact |
| *"if the counts are significantly different, flag that immediately — it means something closed that I don't remember closing"* | drift between orchestrator's mental model and actual state |

---

## Approval gates at decision boundaries

Approval gates sit where wrong turns waste hours, NOT at fixed progress checkpoints. Don't gate every file read; don't ungate the high-stakes branch points.

Where to gate, with examples from the corpus:

| Decision boundary | Why gate here |
|---|---|
| Before the per-stage audit — on the call graph / route map / model summary | A wrong call graph misroutes everything downstream |
| Before any prod query — on the forensic plan or query list | Prod data once read is in agent context; bound it explicitly |
| Before filing issues — on each batch of 3-5 with titles + labels + agent-friendly | The classification decisions are where most overrides happen |
| Before scope expansion — on whether to fold a newly-discovered concern into the current session or punt to "newly observed" | Scope expansion mid-session degrades the session's coherence |
| Before stop-the-line inline fix — on the fix's blast radius and PR shape | Whether to fix inline within an area or carve out a separate session is a judgment call (synthesis §2). **Example (from the pilot):** the inline-PR vs. separate-detour decision (full instance in the case study). |

Where NOT to gate:

- Each individual file read (creates friction without judgment content)
- Each individual issue once the batch has been approved
- Routine catalogue entries (drop batch-and-confirm explicitly)

---

## Voice notes

- **First-person plural** for collaborative work — "we'll regroup", "we fix inline before continuing", "we don't have a path for that".
- **Second-person singular** for guardrails — "don't expand scope", "wait for my approval", "stop and tell me".
- The voice difference matters: the collaborative work invites the agent into the decision; the guardrails are the operator's bright lines.
- **Imperative for the working style block** — "batch and confirm", "surface immediately", "use the .env.prod-readonly pattern". Imperative bullets are scannable and pin the discipline.

---

## A note on what changes vs. what stays the same across sessions

The **skeleton** of this template is stable across sessions and across repos: the 10 slots, the four adaptations, the working-style discipline, the snippet library, the failure-mode pre-emption pattern, the override register.

The **fill** is irreducibly per-session. Severity examples grounded in the area, stop-the-line triggers as concrete vulnerabilities, agent-friendly examples specific to the area's code shape, in-scope and out-of-scope files, the area's blast-radius framing — all of these must be supplied fresh.

The methodology's claim is that the **skeleton + per-area fill** produces an audit run that is high-autonomy within the session (low override rate, sound judgment on severity and scope) while the construction of the prompt itself is the cross-session human work. The two-layer pattern is what makes the methodology scalable: the skeleton transfers; the fills are the irreducible per-area cost.

The override register is what will test whether that claim holds on the next repo.
