# Methodology conventions

Two practices the synthesis identifies as load-bearing for the next five project-phases. Both are small in mechanics, large in compounding value, and both are easy to skip on any individual session — which is why they need to be conventions, not memory.

---

## 1. Preserve every session's verbatim prompt

After each session, save the prompt the operator sent to the agent as a file under `{phase-name}/prompts/` (or whatever the project's equivalent directory is). Use a numbered filename matching the session's chronological order (e.g. `04-area-1-data-layer.md`). Maintain an `INDEX.md` in the prompts directory mapping each prompt file to the session report it produced.

### Why this practice matters

The synthesis was possible because the pilot preserved all 14 prompts verbatim. Future skill-tweaking, methodology revisions, and meta-analysis all depend on reading the actual prompts that worked (or didn't) — not the reconstructed versions an operator would produce from memory.

The synthesis's own warning: *"this synthesis was possible because the area reports captured 'what surprised me' and 'process notes' sections, but the live cross-session conversation — the messages between sessions, the decisions to split Area 4, the stop-the-line judgment calls — survives only in this orchestrator's memory."* The prompts are the closest available proxy for the live cross-session conversation; preserving them keeps the methodology auditable.

Specifically: when building or revising the area-audit skill, the prompts are the ground truth for what the skill is encoding. Without them, future skill-tweaking confabulates the methodology from incomplete context. With them, every claim in the methodology can be cross-checked against the actual session brief that produced the result.

### The mechanic

- Create the prompts directory at the start of the phase: `{phase-name}/prompts/`.
- After each session: copy the prompt verbatim (no edits, no cleanup, no formatting changes) into a numbered file.
- Update the `INDEX.md` with the one-line description and a pointer to the produced report.
- If the prompt was sent in multiple parts (rare), preserve them all in the same file with clear separators.

**Example (from the pilot):** the pilot's prompt corpus contains 13 prompt files (`01-phase-0-baseline.md` through `13-phase-1-backlog-snapshot.md`) plus `INDEX.md`. The corpus was the primary source for the synthesis and for the area-audit skill. (Full instance in the case study, `case-study/pilot/prompts.txt`.)

---

## 2. Keep the cross-session register current

Append to [cross-session-register.md](./cross-session-register.md) after every session, before moving to the next. The register records the cross-session decisions — area ordering, area splits, stop-the-line detour scope, mid-audit deliverable introduction, re-scope events. It does not record per-session findings (those go in issues) or self-corrections inside a session (those don't count as overrides).

### Why this practice matters

The synthesis §4 identifies cross-session work as the methodology's load-bearing human labor — and as the eventual target for Artifact 5 (the orchestration artifact, deferred until after a second codebase). Building Artifact 5 requires data about cross-session decisions. The pilot has no such data; its cross-session decisions survive only in the synthesis's compressed retelling. The next codebase onward needs the register.

The register's compounding value: one data point (the pilot) is insufficient to build an orchestration artifact; two data points (the pilot + a second codebase) is the minimum baseline; three or four data points let real patterns crystallize. Without the register, the next codebase's cross-session work decays into recollection the same way the pilot's did, and Artifact 5 stays unbuildable.

The synthesis's own warning, §10: *"retroactive recollection across multi-week audits is not reliable enough to falsify anything. If the next codebase ends without that data captured, the v2 synthesis will have the same problem this one does."*

### The mechanic

- Open [cross-session-register.md](./cross-session-register.md) after each session.
- Append rows for any cross-session decisions made during or after that session.
- Convert relative dates to absolute (YYYY-MM-DD) at the point of writing.
- Don't batch — append immediately, while context is fresh.
- The register is small by design; rows are short. The bar for inclusion is "this decision shapes how subsequent areas are run" — not "this happened during the session."

See [cross-session-register.md](./cross-session-register.md) for the format and column conventions.

---

## Why these two and not others

The synthesis names many practices worth carrying forward (batch-and-confirm, the override register, the "newly observed" mechanism, etc.). Those are encoded in the area-audit skill and the prompt template — they're *per-session* practices that the skill and the template already enforce.

The two practices in this document are different: they are **cross-session and cumulative**. They aren't enforced by any individual session's prompt because they happen *between* sessions, in the moments where a single session has just ended and the next has not yet begun. They need to be conventions because they aren't naturally caught by any of the methodology's per-session mechanics.

Both are also low-overhead: the prompt-saving is a copy-paste plus an INDEX line; the register update is a row in a table. The cost is sub-minute per session; the value compounds for years.

If a single session report ever omits the override register (the per-session falsifiability hook the methodology owes itself), or a session is run without the prompt being preserved, surface it the next session as a process-note correction — and update the register to record the slip. The methodology survives slippage; the methodology does not survive systematic decay of its own instrumentation.

---

## A meta-principle: prefer gates to guidelines

Where the methodology depends on a discipline, prefer a **structural gate** over a stated **guideline**. Guidelines decay under exactly the time pressure that makes them matter; gates don't.

### The two instances so far

- **Artifact 1's fill-gate.** The area-audit skill refuses to emit a complete prompt until per-area fills are supplied (severity examples grounded in the area; stop-the-line triggers stated as concrete vulnerabilities; agent-friendly examples; scope; prior-area pointers; blast-radius framing). This was discovered during the Artifacts 1-3 session: the fill discipline was the methodology's most-likely-to-be-skipped step, and a stated principle (*"please supply per-area fills"*) would not have held under operator time pressure. A structural gate does. See `../../skills/area-audit/SKILL.md` — the **Per-Area Fill Checklist** and the **Closing gate** section.

- **Artifact 4's checklist double-enforcement.** The same skill's closing gate refuses to mark an area complete until the report contains the **Cross-cutting checklist dispositions** sub-section, with all seven dispositions present. The report-shape spec independently requires the same sub-section in the durable record. Two structural gates instead of one because a checklist is the most "I'll fill it in later" artifact type there is — the runtime gate catches the slip in-session; the persistence gate catches it in the written output. See `../../skills/area-audit/references/cross-cutting-checklist.md` and `../../skills/area-audit/references/report-shape.md`.

### The cost asymmetry that favors gates

Stated guidelines cost a sentence in a doc nobody re-reads under pressure. Structural gates cost a one-time wiring edit and then enforce themselves indefinitely. The cost ratio favors gates wherever a gate is buildable — and most disciplines that live inside a per-session skill are gateable, because the skill is in the loop at exactly the moment the discipline applies.

### When a gate isn't possible

Not every discipline can be gated. The two conventions in this document (**preserve every session's verbatim prompt**; **keep the cross-session register current**) are guidelines because they live *between* sessions, in the moments where a single session has just ended and the next has not yet begun. No skill runs in those moments, so no gate can fire. That's why they sit in `conventions.md` as practices rather than in a skill as enforcement. Knowing when to gate and when to convention is itself a methodology call — the test is *"is a skill in the loop when this discipline needs to apply?"*

If the answer is yes, build a gate. The two existing gates have already demonstrated their value during their own construction sessions; future audits should treat a missing gate where one is buildable as a methodology-quality issue worth raising.

---

## Cross-references

- [prompt-template.md](./prompt-template.md) and `../../skills/area-audit/SKILL.md` — the per-session entry points the conventions sit alongside.
- [cross-session-register.md](./cross-session-register.md) — the register itself.
- `../../skills/report/` — the resolve phase's *automatic* self-measurement (a local event log the loop emits + a scorecard that also derives from `gh`/`git`). It is the machine counterpart to this section's manual practices: where the register captures cross-session audit decisions by hand, the report captures resolve-loop effectiveness as a byproduct of running — the direct answer to §10's warning that retroactive recollection isn't reliable enough to measure the methodology.
- [cross-cutting-checklist.md](./cross-cutting-checklist.md) — the second instance of the gate-not-guideline meta-principle; the checklist whose dispositions are double-enforced.
- The case study's synthesis §9 (Artifact 5 deferred until a second codebase) and §10 (falsifiability) — the conceptual basis for both conventions.
