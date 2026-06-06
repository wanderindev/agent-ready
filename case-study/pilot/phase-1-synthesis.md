# Phase 1 Synthesis — Auditing PIC with an Agent: Methodology, v1

**Date:** 2026-05-23
**Project:** PIC (Panama In Context)
**Subject:** the methodology
**Worked example:** PIC's 14-session Phase 0 + Phase 1 audit (March–May 2026)

> *Session breakdown: Phase 0 (1) + Phase 1 prep (2) + nine area audits (Areas 1, 2, 3, 4a, 4c, 4b-1, 4b-2, 5, 6) + the Phase 1.5 detour for issue #31 (1) + the backlog snapshot (1) = 14. References later in the document to "nine sessions" or "the nine area-audit sessions" mean the area audits specifically; "14 sessions" or "14 prompts" means the full corpus. The Area 3 stop-the-line fix shipped inline within the Area 3 session, not as a separate prompt — see §2.*

---

## 1. Purpose and status

This document is a methodology-extraction design doc. Its primary readers are (a) the operator about to run a similar audit on the next codebase, and (b) the artifact-building session that follows this one, which will turn the principles below into reusable skills and templates.

The voice is prescriptive and methodological — *here is how to run this audit, here is what is mechanical versus judgment-bound* — and PIC findings appear throughout as evidence, not as the subject. The subject is the method.

It is explicitly v1. Every claim is calibrated to one codebase (PIC), one agent (Claude Code on the model versions running during the May 2026 audit window), and one orchestrator (the human operator who briefed each of the 14 sessions). Where a claim might not generalize, it is flagged as a hypothesis the next 3–5 codebases will test rather than a law.

### Explicit non-goals

This document is NOT:

1. **The public LinkedIn / blog series.** That needs multi-repo evidence that does not yet exist.
2. **The MonetizeMore presentation.** That needs organizational and process evidence — not just methodology — that does not yet exist.
3. **A fix-execution plan for PIC.** That is Phase 2, and depends on the labeled backlog this synthesis sits on top of, not the synthesis itself.
4. **The artifacts (skills, prompt templates, reference-document specs) themselves.** Section 9 specifies what those artifacts should be; the next session builds them.
5. **A finished methodology.** It is a v1 articulation, built to be revised as it is tested. Reading it as a checklist would be a misuse — it is a starting position, not a destination.

---

## 2. The methodology in brief

The phase structure that actually ran on PIC is the spine the rest of this document hangs on. Four phases, each gating the next.

**Phase 0 — Baseline and safety nets.** A ~5-hour session that brought the project to a known-good state before any agent did autonomous work. Tools and MCP audit; `CLAUDE.md` reconciled against running reality; the 19 broken tests fixed (one of them hiding a production `AttributeError` in `tours.py`); dev `.env` files reshaped so `DATABASE_URL` no longer defaulted to production; CI workflows stood up with secret scanning; branch protection turned on; every production credential rotated after we discovered they had been committed to git history for five months. The deliverable was not "ready to audit"; it was "safe for an agent to do autonomous work without an orchestrator watching every keystroke."

**Phase 1 prep — Two preparation sessions, not one.** Prompt 02 built the filing cabinet: four GitHub labels, four issue templates, the agent-friendly criteria doc, the Phase 1 README. Nothing else — the prompt's own anti-scope statement: *"Nothing else. No code-quality fixes, no audits, no opening of issues. We're building the filing cabinet, not filling it."* Prompt 03 then did Part A intake (converting Phase 0's deferred backlog into 17 properly-structured issues) and produced the audit plan that scoped the six areas of Part B. Splitting prep into two sessions was a deliberate choice — combining them would have invited the audit to start before the filing cabinet was finalized.

**Phase 1 proper — Area-by-area audit.** Nine sessions covering six audit areas (Area 4 split into 4a / 4b-1 / 4b-2 / 4c during the run, and 4c was scheduled *before* 4b because the swallowed-exceptions catalogue was load-bearing for the pipeline audits). Each session followed the area-audit pattern documented in §3. Each ended with a labeled backlog of findings filed as GitHub issues — no fixes, per the audit plan's *"it does not fix things"* discipline — and a session report following the Phase 0 report's shape.

**Phase 1.5 — Stop-the-line detours.** Two stop-the-line incidents occurred, with deliberately different operational responses. The Area 3 audit surfaced two unauthenticated admin routers (`admin.py` and `media_library.py`) inside the first 30 minutes; the fix shipped inline within the Area 3 session as PR #49 and the audit continued. The Area 2 audit surfaced an HTML-injection vulnerability in customer-controlled fields routed to admin Gmail (issue #31); it was bounded out for a separate Phase 1.5 detour session (prompt 06) that did nothing but the Jinja2 migration. The asymmetry was not accidental: PR #49 was a uniform `validate_admin_token` addition across 20 routes — mechanical, small blast radius once the pattern was set. #31's fix required a wholesale template-system migration and was scoped large enough that an in-area detour would have polluted Area 2's audit voice. Same trigger, different sizes, different responses.

Each phase gated the next because each produced an invariant the next phase relies on. Phase 0 produced a safe local environment, protected `main`, and green tests — the floor below which autonomous agent work has unacceptable downside. Phase 1 prep produced labels, templates, criteria, and an audit plan — the structure within which the audit's outputs are interpretable. Phase 1 produced a labeled backlog — the surface on which Phase 2's fix work and this synthesis both operate. Phase 1.5 was lateral, not vertical: it exists because some discoveries during the audit are too live to defer, but it does not gate anything except its own merge.

A useful asymmetry to record: the cost of *not* running Phase 0 first is invisible until something breaks — a wayward script hits prod; a credential leak crystallizes; a regression no test catches. The cost of running Phase 0 first is finite and bounded. Run Phase 0 first.

---

## 3. The audit-area pattern

The repeatable structure underneath each area audit is a 10-slot prompt template plus a per-area report shape. The prompt template was assembled implicitly across the first few areas and stabilized by Area 4a. The report shape was inherited from the Phase 0 report and elaborated as the audits produced new reference-document types (see §7).

### The 10 slots

Across the nine area-audit prompts (Areas 1, 2, 3, 4a, 4b-1, 4b-2, 4c, 5, 6), the same ten slots appear in roughly stable order:

1. **Identification + audit-plan pointer.** *"We're starting Phase 1 Part B Area N. The audit plan at `docs/pilot/phase-1-audit-plan.md` is the authoritative scope document. Read it first if context has rolled."* Robust against the agent's context having been cleared between sessions.
2. **Read-this-first inputs.** Explicit list of prior reports and relevant issues, including previous areas' "newly observed for Area N" subsections. Treats those as inputs, not findings to rederive.
3. **Why this area matters.** One paragraph stating blast radius. Always concrete: "highest-financial-blast-radius area in the codebase" (Area 2); "narrow surface, high blast radius" (Area 3); "user-visible, not data-corruption-shaped" (Area 5).
4. **Scope.** In-scope files (often "read all in full") and out-of-scope ones with per-area pointers ("Area 3 territory; note in *newly observed*").
5. **What to look for.** A multi-headed checklist organized by concern, never by file. The headings name the things the orchestrator wants the agent to *think about*, not the things they want it to *read*.
6. **Production data access policy.** Present when prod queries are likely useful, absent when they aren't. Always with the gating rule: *"surface for explicit approval before any prod query — aggregates only, no row-level PII."*
7. **Working style.** Five bullets, repeated every time: batch-and-confirm; severity calibration with worked critical / moderate / nice-to-have examples *grounded in that area*; agent-friendly calibration; stop-the-line triggers (area-tuned); don't re-audit prior-area concerns.
8. **End-of-session report.** File path; shared report shape (executive summary, by-the-numbers, item-by-item findings, filed-vs-deferred, newly observed, what surprised me, process notes); area-specific required additions (these produce the reference-document types in §7).
9. **Scope estimate.** Hours and an issue-count band, with an upper bound that triggers re-scope: *"If you're approaching 25+ findings, something is wrong."*
10. **Begin by.** Numbered 1–4 lead-in: re-read inputs; produce a map or call graph or inventory; propose a structure; **wait for approval**.

Two things are worth saying about the template. First, every slot exists to pre-empt a specific failure mode (more on this in §4). Second, the slots that *vary by area* (3, 5, 7's stop-the-line triggers, 8's required additions, 9's scope estimate) are the slots that contain the orchestrator's domain priors. They are also the slots where the prompt-construction work is genuinely irreducible session by session — they cannot be filled from a template alone.

### Four named adaptations

Within the template, four areas adapted the standard shape in ways durable enough to call out.

**Forensic-first (Area 2 / payments).** Prompt 05a introduced a *"Forensic question: is PayPal integration alive?"* section before the standard "what to look for", and an explicit prior: *"approach the PayPal portion of this audit assuming the integration may be dead code. Verify before assuming anything works."* The audit spent its first 45 minutes producing the dead-code verdict — zero `paypal_invoice_id` rows; zero webhook-attributed `BookingStatusLog` entries; five forensic fingerprints, all negative — and that verdict then reshaped every subsequent severity decision in the area. The pattern generalizes to any code area where the *aliveness* of a code path is genuinely uncertain.

**Model-summary-first (Area 3 / auth).** Prompt 05b introduced an *"Auth model summary"* deliverable: *"a clear, concise statement of how auth actually works… if the audit reveals that the intended model differs from the actual model, both should be documented with the gap called out."* The Area 3 report produced a three-systems table (admin magic-link, customer magic-link, educator base64) plus an intended-vs-actual gap matrix. The pattern generalizes to any area defined by an invariant — auth, error handling, transactions, money flow — where most bugs are deviations from a model.

**Systematic-sweep (Area 4c / swallowed exceptions).** Prompt 08 inverted the default: *"this is a systematic sweep, not an audit."* Output was a single structured catalogue comment on issue #8, not a fan-out of per-site issues. Three filed issues instead of ~30. Batch-and-confirm was explicitly dropped (*"no batch-and-confirm for catalogue work"*) because the deliverable was a compressed taxonomy, not a sequence of judgment calls. The Area 4c report's punchline — *"without the 4a groundwork this would have been a 3-4 hour audit, not 1.5 hours"* — is the cleanest evidence in the corpus that cross-session investment compounds.

**Call-graph-first and fix-ordering emergence (Areas 4b-1 onward).** Prompt 09 introduced the *"Fix ordering for edu pipeline"* required report section, framed explicitly as proof-of-concept for the synthesis's fix-sequence framework. The Area 4b-1 report observed that *"the 30 minutes spent producing the call graph paid for itself three times over — most findings live in the seams between flows."* Prompt 10 then added a *"Toward a global fix ordering"* bridge section, and that bridge accumulated across 11 and 12 into the four-track Wave 1 in the backlog snapshot. This adaptation is unusual: it began as a per-area deliverable, became a cross-area composition format, and is on a clear path to a top-level synthesis device. **Mid-audit deliverable evolution is itself a methodology** — the audit plan does not have to be finished before the audit starts.

A fifth, smaller adaptation: **build-the-bundle-not-estimate-it** (Area 5), where the auditor ran `npm run build` and reported the actual byte count (2,649,933) rather than re-estimating Phase 0's "2.6 MB" claim. Same discipline as Area 4b-1's prod-query verification of severity: when the audit can cheaply ground a claim in a measurement, it should.

---

## 4. The automatability map

This section is the centerpiece. The honest claim is in three parts.

**Fully mechanical.** Work that is automatable today, with no judgment beyond the orchestrator's existing approval pattern:

- Catalogue sweeps (the Area 4c swallowed-exceptions taxonomy was three filed issues plus one structured comment — entirely mechanical given the taxonomy).
- Issue filing — once a finding is named, severity-classified, and acceptance-criteria'd, file-then-link is mechanical.
- Aggregate prod queries — dozens were run across Areas 2, 3, 4b-1, 4b-2 with a fixed pattern (aggregate-only, batch-approved, never row-level).
- Per-action approval rounds within a session, when the action is reversible and non-production (file reads, issue filings, test runs, local-DB writes).

These are the parts of the audit where stripping the human out costs nothing — except that today, without selective auto-approve, the human is in the loop on every one. The cost is babysitting, not judgment. §5 returns to this.

**Judgment-assistable, and the assist worked.** Work that requires judgment but where the agent's proposals held across the nine area-audit sessions:

- Severity calibration. Every area prompt gave worked critical / moderate / nice-to-have examples grounded in the area's domain; the agent then applied that calibration to its own findings. Across roughly 110 filed issues, the orchestrator overrode the proposed severity on the order of twice.
- Agent-friendly classification. Same shape: a six-criterion rubric, instructed-with-bias-toward-NO in every prompt, applied by the agent, almost never overridden.
- Most scope calls within a session — whether a finding is "newly observed for Area N+k" or belongs in the current area; whether two related issues should be bundled or split; whether a piece of code is in-scope or out-of-scope.

The surprising claim — surprising because the prior was *"agents need a human in the loop on every judgment call"* — is that the agent's judgment was sound **within a well-constructed prompt**. The override rate across the nine area-audit sessions was extremely low. The artifact-building session should treat this as the load-bearing evidence: per-session execution, given the right brief, is much closer to autonomous than the default mental model predicts. The methodology owes itself an honesty note here, which §10 returns to: this override rate is the orchestrator's recollection, not a logged metric. Future audits need to measure it deliberately.

**Judgment-load-bearing, genuinely human.** Work that lived in the cross-session conversation, not in the terminal:

- Area ordering. The audit plan ordered six areas by leverage; the actual run further split Area 4 into 4a / 4b-1 / 4b-2 / 4c after the first pass revealed its size, and reordered 4c *ahead* of 4b once it became clear the catalogue was load-bearing for the pipelines.
- Stop-the-line detour decisions. The asymmetric handling of PR #49 (inline) vs #31 (separate Phase 1.5 session) was a human call, made by reading each finding and judging fix-size against in-area pollution.
- Mid-audit deliverable introduction. The fix-ordering format was added at prompt 09 because the cumulative backlog after Areas 1–4a was large enough to need composition. The decision to add a new required output mid-audit was a human call.
- Synthesis shape. The document you are reading was scoped by a human-written brief; that brief's existence is what makes the synthesis tractable.

The two-layer pattern that emerges: **per-session execution is highly autonomous when the prompt is well-constructed; constructing the prompts is the cross-session human work.** The agent's judgment held *within a structure built session by session*. Therefore the primary automation target is not audit execution — it is audit *design and orchestration* — which is exactly what the next session's skills should encode.

### What "well-constructed" actually means, in evidence

If the primary automation target is prompt construction, this doc needs to be specific about what is being constructed. From the corpus of 14 prompts:

- **The 10-slot template** (§3). Most sessions inherit the slot structure; the per-area filling is the work.
- **Worked examples for severity calibration, every time.** The part of the prompt that does not carry over across sessions. Abstract rubrics underperform domain-grounded examples; building the examples is the irreducible per-area cost.
- **Failure-mode pre-emption, densely.** Most lines in most prompts exist to head off a specific known failure mode. *"If you're approaching 25+ findings, something is wrong"* (every area prompt) pre-empts unbounded fan-out. *"Don't be permissive. Borderline cases default to NO"* (prompt 03) pre-empts agent-friendly inflation. *"Wait for my approval on the structure before starting any prod queries"* (every prod-touching prompt) pre-empts careless reads. *"Aggregates only — no row-level PII queries"* (same prompts) pre-empts a second failure mode the first instruction doesn't catch.
- **"What this is NOT" devices** (prompts 02 and 13). When the orchestrator wants to bound a session against a default failure mode — interpretation drift in the snapshot, scope expansion in the prep — they do not trust positive specification alone. They enumerate what *not* to do.
- **Approval gates at decision boundaries, not progress checkpoints.** Every area prompt ends with *"wait for my approval on [the structure / the call graph / the route map] before starting [the per-stage audit]."* Approval gates sit at the moments where a wrong turn would waste hours, not at fixed intervals.
- **The $100 promo-credit framing** (prompts 07 and 08). Verbatim from prompt 07: *"If you hit subscription cap during this session, continue rather than stop — the overflow lands on extra-usage credit and we want to be thorough on the wrapper audit because it shapes 4b's scope. But 'be thorough' is not 'expand scope' — stay in cross-cutting services."* A single instruction that buys depth without buying scope creep. Methodologically a small thing; instrumentally critical.
- **Pre-figured findings.** Concretely enough that the agent's job is verify-or-refute, not discover. *"Approach the PayPal portion of this audit assuming the integration may be dead code"* (05a). *"a few thousand requests per second cracks it in minutes"* (05b, pre-figuring the rate-limit finding). *"`generate_article` / regenerate paths — what happens to an APPROVED, published article if regeneration is triggered?"* (10, pre-figuring #99). The orchestrator's priors are visibly injected; the agent's job is to test them. §8 returns to this as a check.

### A caveat the doc owes itself

The above comes from one codebase, one agent, one orchestrator. The override rate is calibrated to PIC's domains — payments, auth, services, frontend — and to this orchestrator's calibration of severity. Whether the prompt-construction logic generalizes to a 10x larger codebase, a more adversarial codebase, or a more security-sensitive domain (medical, financial, defense) is genuinely unknown. The next 3–5 audits will tell. §10 returns to this.

---

## 5. The human-time reality and the auto-approve fence

What actually consumed human time across the 14 sessions was two distinct things, and they have different implications for what to automate next.

The first is the **report-reading and orchestration conversation** — the cross-session work §4 identifies. Reading each area report end-to-end, comparing it against the prior areas' "newly observed" sections, deciding whether the next area's prompt needs a new deliverable, judging stop-the-line detour scope. This time is necessary. It is the load-bearing human work. Automating it is *the* hard problem; the artifact session can encode patterns that *help* with it (cross-session decision checklists; templates for stop-the-line judgment; default report-reading priorities) but it cannot fully substitute for a human who has read the cumulative backlog.

The second is **babysitting 20-minute runs without auto-mode**. Sitting in front of the terminal while the agent files an issue, then approving the next tool call, then approving the next, then approving the read of the next file — for sessions that take an hour or three, this is pure cost with no judgment content. It is the clearest single automation target this synthesis points at.

The fix is selective auto-approve, but **the fence matters more than the existence of the feature**. The naive fence — "auto-approve anything non-destructive" — is wrong, and PIC's own audit produced the close calls that prove it:

- **#99** corrupted production via a routine-looking raw-SQL `UPDATE` (not a `DELETE`, not a `DROP`). The fix-then-rerun pattern on `_generate_references_section` ran twice against articles 39 and 40 and doubled their nav blocks. A "non-destructive" classifier reading the SQL statement type would have waved this through.
- **#69** is an in-memory denial of service — `image_storage.download_image` enforces its size cap *after* reading the whole body. There is no database touch at all. Any fence pegged to DB writes misses this entirely.
- **Phase 0's credential exposure** was discovered through a `git log` (a READ). The same READ, executed without an operator watching, would have surfaced the credentials in the terminal scrollback of a shared environment. Reads are not safe by default.
- **`SELECT * FROM bookings LIMIT 5`** is a single read query against production. It would pull customer PII (names, emails, phone numbers, addresses) into the agent's context window — from which it cannot be reliably scrubbed and to which the agent's logging is not the only audience. This is exactly the kind of thing the audit's "aggregate-only, no row-level PII" rule prevents, and exactly the kind of thing a "reads are safe" fence would allow.

The correct fence, as the audit's own data argues, is **reversible-vs-irreversible × production-vs-non-production**, not destructive-vs-non-destructive. Auto-approve the reversible-and-non-production work: reading local code, filing issues, running local tests, querying the local DB, writing reports. Keep a human gate on anything that touches production at all — reads included, because of PII and context exposure — and anything irreversible: history rewrites, mass deletions, schema migrations against real data, anything that touches `.env*` or credentials storage.

The babysitting cost is the highest-value single automation in this entire methodology. The fence is the highest-stakes single decision in the same automation. Get them in the same conversation.

---

## 6. Backlog shape and parallelization strategy

The labeled backlog Phase 1 produced has a clear structural shape, and that shape — not the issue count — dictates the right Phase 2 parallelization.

The numbers from the snapshot, by area-class:

| Area class | Open | Critical | Moderate | Nice | Agent-friendly |
|---|---:|---:|---:|---:|---:|
| Backend (Phase 0 + Areas 1, 2, 3, 4a, 4c, 4b-1, 4b-2) | 93 | 15 | 53 | 25 | 27 (29%) |
| Frontend (Areas 5, 6) | 17 | **0** | 11 | 6 | **15 (88%)** |
| All open | 110 | 15 | 64 | 31 | 42 (38%) |

Numbers reconcile against the backlog snapshot's per-area §4 table: backend = 17 (Phase 0) + 9 (Area 1) + 16 (Area 2) + 16 (Area 3) + 15 (Area 4a) + 3 (Area 4c) + 11 (Area 4b-1) + 6 (Area 4b-2) = 93; frontend = 11 + 6 = 17; agent-friendly = 27 + 15 = 42.

Two opposed shapes:

**Backend is narrow-and-deep, linchpin-gated.** Fifteen criticals, most of them in services and integrations, with hard prerequisites. Issue #3 (initial alembic migration) cannot start until #21 (`env.py` model imports) is fixed because autogenerate produces wrong output until then. The LLM-foundation cluster (#76 + #68 + #77 + #78) reshapes a dozen downstream issues; sequence it wrong and you do the downstream cleanup twice. The Composio-contract cluster (#67 + #70 + #74 + #59 + #37) collapses 16 caller-side updates into a wrapper-first sequence — but only if #67 lands first. Linchpins everywhere; many small, well-scoped issues are not actually well-scoped because they share a foundation that someone has to fix first. Only two of fifteen critical issues are agent-friendly (#21 and #69).

**Frontend is wide-and-shallow.** Seventeen issues, zero criticals, no linchpins, almost no inter-issue dependencies. 88% of frontend issues are agent-friendly — the cleanest single chunk of the backlog. The Area 6 report's framing crystallizes the contrast: *"the backend backlog is narrow-and-deep with linchpins that gate large clusters and punish wrong sequencing; the entire frontend backlog is wide-and-shallow, ~all agent-friendly, with no linchpins and almost no inter-issue dependencies."* The same report names *"#117 is the single cleanest entry point in the entire backlog"* for autonomous agents — a one-file partial-correction fix with existing tests and clear acceptance.

The operational consequence is direct. **Humans drive the backend narrow-and-deep critical paths interactively**, because the linchpin sequencing is exactly the cross-session judgment §4 identifies as load-bearing. Backend work proceeds in waves, each wave gated by a linchpin landing. **Agents run the frontend wide-and-shallow track in parallel** — there is no path through it that requires a human to be sequencing, and the agent-friendly rate is high enough that the babysitting cost (§5) is the only thing keeping it from running unattended.

The four bridge sections in the area reports (4b-2, Area 5, Area 6, and the backlog snapshot's wave-1 list) compose into a four-track Wave 1 for Phase 2:

1. **edu critical** — #97 → #91 → #90.
2. **article critical** — #99 plus an out-of-band data fix for the already-corrupted articles 39 and 40.
3. **LLM foundation** — #76 with #68, #77, #78.
4. **frontend safety-net** — #7, #106, #110.

The composition method matters more than the specific waves. The bridge sections do not order issues individually — they order *clusters* (the snapshot's §6 lists eleven of them), where the cluster boundary is "if you fix one without the others, you do the others' work badly." **Cluster-not-individual** is the framing future audits should inherit: a backlog of 110 issues is overwhelming; the same backlog seen as a dozen clusters is not.

---

## 7. Reusable reference-document types

The PIC audit produced *document types*, not just documents. Each is a candidate template for future audits. For each: purpose, when in an audit it appears, what makes it reusable.

**Service surface map (Area 4a).** A table of every service module with classification (in-scope-here / deferred to a later area / out-of-scope) plus a one-line description. Produced when an audit area contains a large set of modules that need to be sliced before the deep read. Reusable because the structure (inventory → classify → defer-with-rationale) holds for any large module set.

**Vendor failure-mode summary (Area 4a).** A per-vendor matrix: wrapper / behavior on success / behavior on `successful: False` / behavior on Python exception / behavior on timeout / failure visibility upstream / hypothesized one-hour-outage system-wide impact. Produced once per audit, in the area that owns external integration boundaries. Reusable because the columns are the things you need to know about *any* vendor wrapper.

**Auth model summary (Area 3).** A three-systems table with intended-vs-actual rows showing the gap matrix. Produced when an area's findings are mostly deviations from an invariant; building the invariant first makes the deviations countable. Reusable for any auth, error-handling, transaction, or money-flow audit where a model precedes the deviations.

**Public-site error-handling model (Area 5).** A 10-layer matrix — top-level error boundary, per-page boundary, unknown URLs, async states, HTTP errors, persisted state, gates, stale cache, rendered HTML, analytics — with intended-vs-actual for each layer. Same shape as the auth model, applied to a different invariant.

**Admin route + auth model matrix (Area 6).** Same intended-vs-actual shape, applied to an admin surface (gate / data-before-auth / dev bypass / token transport / logout / service error handling / inline action errors / unsaved-work). Confirms the intended-vs-actual matrix is a general device, not a one-off; the artifact session should treat that shape as a primary artifact and these three (auth, public-error, admin-route) as variations.

**Per-area call graphs (Areas 4b-1, 4b-2).** A diagram of the flows inside a pipeline-shaped area. Produced when an area is structurally a set of flows that share infrastructure but not control flow. Reusable wherever findings live "in the seams between flows" — the Area 4b-1 report's phrase, which itself is reusable.

**Structured swallowed-exceptions catalogue (Area 4c).** A categorized table of every swallow site (wrapper-induced / genuinely independent / pattern variants) posted as a single comment on a single tracking issue, with a rationale column that lets it compress to a handful of follow-up issues rather than dozens. Reusable for any cross-cutting concern where the value is in the rationale, not the row count.

**Fix-ordering analysis (Area 4b-1 onward).** Per-area waves with a dependency diagram, and a column for *"where fixing one issue changes another's scope."* Produced when an area's backlog is large enough that order matters. Reusable for any multi-issue backlog.

**Global-ordering bridge section (Area 4b-2 onward).** Half-page sketch composing the current area's ordering with the prior areas'. Produced from Area 4b-2 onward, accumulating until the synthesis. Reusable because it forces the auditor to surface the cross-area shape of the backlog rather than treating each area as independent.

**Forensic verdict (Area 2).** A short, evidence-backed determination of whether a feature is live, dormant, or dead. The Area 2 PayPal verdict produced five forensic fingerprints (zero `paypal_invoice_id`; zero webhook-attributed log rows; etc.) plus a structured *"what changes if the verdict is wrong"* risk register. Reusable whenever an area's severity calibration depends on a code path's aliveness.

The shared property across all of these is that they are **outputs the audit produces alongside the issue backlog**, not byproducts of it. The issue backlog is one deliverable; the reference documents are co-equal. The artifact session should treat each as a candidate skill output.

---

## 8. Cross-cutting findings as a proactive checklist

The PIC audit found several patterns *by accident* that future audits should look for *on purpose*. The first item below is structurally different from the others — it is a *disposition* the orchestrator brings to each audit, not a pattern to find in the code. The remaining five are stated as hypotheses from one codebase. The next 3–5 repos will tell us which are stop-start-solo-developer signatures specific to PIC's history, which are general structural patterns, and which only exist in agent-touched codebases.

**The orchestrator's prior as a check.** This is the deepest reframe the methodology has to offer, and it sits at the top of the checklist for a reason. Across the 14 prompts, the orchestrator routinely pre-figured findings concretely enough that the agent's job was verify-or-refute, not discover. Prompt 13's *"if the counts are significantly different, flag that immediately — it means something closed that I don't remember closing"* is the cleanest example, but Area 2's *"approach assuming the integration may be dead code,"* Area 3's *"a few thousand requests per second cracks it in minutes,"* and Area 4b-2's *"what happens to an APPROVED, published article if regeneration is triggered?"* are all priors injected to be tested.

The check that follows: **before running an audit, write down the priors. After running it, compare the priors against the findings.** The places where priors held are evidence the orchestrator's mental model of the codebase is calibrated; the places where they didn't are the audit's most valuable discoveries.

What this reframes is the orchestrator's *role*. The default mental model — *"the human reviews the agent's work"* — casts the orchestrator as a quality gate, which is mostly the babysitting work §5 wants to automate away. The audit-as-experiment frame casts the orchestrator instead as the one who states the hypotheses the agent's session is set up to test. The audit becomes the experiment; the report becomes the result set; the surprises become the load-bearing findings. **The orchestrator is an experimenter, not a reviewer.** This is the framing that distinguishes the methodology from *"have an agent read your code"* — and it is the one that makes the cross-session work §4 describes feel like skilled labor rather than supervision.

The five items that follow are pattern-recognition heuristics drawn from PIC. The first item is the disposition the checklist as a whole sits inside.

**Partial-correction debt.** The right pattern half-applied. The PIC audit found it at least five times: `educator_service._send_*_email` helpers log the bool result but the same-file callers discard it (Area 4c); the LLM pipeline guards regeneration in four of five flows and misses the fifth (#99 vs #91, Area 4b-2); `EducatorAuthContext` wraps `JSON.parse` but sibling `CartContext` does not — a whole-site blank-page crash if the localStorage cart is malformed (Area 5); the `_generate_references_section` duplication where the auditor noticed the duplication and fixed only half of it (Area 4b-2). Area 6 crystallized the pattern explicitly: *"every Area 6 finding is the same finding. Six issues, one shape: a good pattern, half-applied."* The check: **when an audit identifies a fix-shaped pattern, sweep across sibling call sites in the same PR before declaring the pattern fixed.** The deeper hypothesis is that partial-correction is the dominant tech-debt shape of a long stop-start project under one developer — but it could equally be the dominant shape of an LLM-edited codebase. The next audits will distinguish.

**Swallowed-failure as an umbrella theme.** Phase 0's issue #8 is literally *"sweep services for swallowed exceptions"*; its concrete instances are scattered as #37, #59, #67, #70, #74, #83, #84, #85 across Areas 2 / 3 / 4a / 4c, and #117 (Area 6) is the same pattern in the admin frontend. Roughly nine issues, one theme. The check: **treat swallowed-failure as a cross-area theme that any single area's audit names as an instance, not a finding.** Distinguish carefully from partial-correction debt — they overlap on the Composio wrapper (#67) and a few others, but they are distinct ideas. Partial-correction is *"the right fix was applied, but only halfway across the relevant call sites"*; swallowed-failure is *"an error condition is silently dropped."* The Composio wrapper has both because it silently drops Gmail failures *and* the helper that wraps it logs the bool but the callers discard it; partial-correction is the meta-pattern, swallowed-failure is one of its concrete instances.

**Danger is not where complexity is.** The Area 4b-2 audit found its only critical (#99) not in the heavy LLM regeneration paths the audit was set up to scrutinize, but in the simple string-concatenation flow nobody was watching. The Area 4b-2 report's framing: *"the pipeline learned the #91 lesson four times out of five and missed it in the flow that looked too simple to get wrong."* The check: **at the end of each area audit, ask explicitly what code in the area looked too simple to merit scrutiny, and read it once.** Complexity attracts attention; simplicity that *also* mutates production data is the systematic blind spot.

**Two-dimensional severity: blast-radius × evidence-of-impact.** PIC has 15 critical issues; three of them (the PayPal webhook trio #32 / #33 / #34) are critical-by-blast-radius but dormant in production because PayPal was never live. #99 is critical *and* has evidence of live production impact (articles 39 and 40 already corrupted). The Area 4b-2 report named the pattern: *"the prod query raised a severity instead of lowering one… aggregates don't just de-escalate — they tell you the truth in whichever direction it runs."* The check: **score critical findings on two dimensions — potential blast radius if the code runs, and current evidence the code is running — and let the second dimension reshape ordering.** A live moderate and a dormant critical are not obviously co-ranked.

**Latent-but-uncrystallized risk: clean prod data masking real bugs.** Several PIC audits found severity-relevant prod state that lowered a finding's apparent risk: zero rows for PayPal fingerprints (Area 2); zero rows for `RENEW_PAYMENT` and `CANCEL_BOOKING` magic links (Area 3); the `material_type="slides"` enum collision that has not yet produced a crash because no row exercises it (Area 4b-1). When the live data is clean, the audit's tendency is to drop severity. The honest reading is that the bug exists; the data has just not crystallized it yet. The check: **when prod state is the reason for a severity-drop, name it explicitly and add a flag-bit for *"becomes live if state X appears"* — that bit should ride with the issue forever.**

Each of these is one-codebase evidence. Future audits should carry the checklist and report back which ones held.

---

## 9. Artifact specifications for the next session

The next session builds the artifacts. This section specifies their purpose, scope, and principles-to-encode — enough for a clear brief, without building them. For each, the relative confidence is marked, so the next session knows where iteration cost is highest.

**Artifact 1: The area-audit skill (well-understood).**
- *Purpose:* Encode the area-by-area audit pattern so an operator can invoke "audit area X of repository Y" and the skill produces a prompt-shaped brief the orchestrator can adapt.
- *Scope:* The 10-slot template from §3; the four named adaptations (forensic-first, model-summary-first, systematic-sweep, call-graph-first); the working-style discipline (batch-and-confirm, stop-the-line triggers, "newly observed but don't file").
- *Principles to encode:* Worked examples for severity calibration must be supplied per-area; the skill should *prompt* the operator to write them, not invent them. Stop-the-line triggers are concrete vulnerabilities, never abstract. The "Begin by" lead-in must end at an approval gate. The agent-friendly default is NO.

**Artifact 2: The prompt-template artifact (well-understood).**
- *Purpose:* Generalize the area-audit prompt shape so a session can be scaffolded in five minutes rather than rebuilt from scratch.
- *Scope:* The 10 slots as a fill-in form; the variants for each of the four adaptations as switchable headers; the cross-session investments (batch-and-confirm, "newly observed", $100-credit-style framings) as snippet libraries.
- *Principles to encode:* Failure-mode pre-emption is densely placed, not afterthoughts. Approval gates sit at decision boundaries, not progress checkpoints. The "What this is NOT" device exists as a snippet for any session at risk of scope drift. Voice is first-person-plural for collaborative work, second-person-singular for guardrails. **The report-shape ask must include an instrumentation hook:** each session report records how many times the orchestrator overrode the agent on severity, agent-friendly, or scope, with a one-line description of each override. The §4 autonomy claim is the methodology's most consequential and most fragile claim; future audits cannot falsify it without measuring it deliberately. PIC's *"on the order of twice"* number is recollection, not data — repo 2 needs to be different.

**Artifact 3: Reference-document-type specs (well-understood).**
- *Purpose:* Each of the document types in §7 becomes a skill output specification, with its own template.
- *Scope:* Service surface map; vendor failure-mode summary; intended-vs-actual matrix (auth / public-error / admin-route as variations); per-area call graph; structured swallowed-exceptions catalogue; fix-ordering analysis; global-ordering bridge section; forensic verdict.
- *Principles to encode:* Each spec must include *when* in an audit it is produced (Area-4a-class, Area-3-class, etc.) and what triggers its production. Several of these are the same intended-vs-actual shape applied to different surfaces — the spec for that shape should be its own primary artifact, with the surface-specific instances as variations.

**Artifact 4: The cross-cutting findings checklist (experimental).**
- *Purpose:* Convert §8's hypotheses into a checklist a future audit runs at the start and end of each area.
- *Scope:* Partial-correction debt; swallowed-failure umbrella; danger-isn't-where-complexity-is; two-dimensional severity with live-vs-dormant; latent-but-uncrystallized risk; orchestrator's prior as a check.
- *Principles to encode:* Each item is a hypothesis from PIC, not a law. The checklist's value is partly its content and partly the discipline of running it — even when most items don't fire, the act of checking captures the negative result. Frame the checklist as *"things to actively look for,"* not *"issues to file unless found."*

**Artifact 5: The meta-process / orchestration artifact (DEFERRED until after repo 2).**
- *Purpose:* Encode the cross-session decision patterns §4 identifies as the *real* automation target. Area ordering; mid-audit deliverable introduction (the prompt-09 call to add fix-ordering); stop-the-line detour scope (the PR-49-inline-vs-#31-detour judgment); when to split an area into sub-areas; when to invest in a new reference-document type.
- *Why deferred:* This is the artifact that matters most for the *"rely less on humans at scale"* goal, because it targets exactly the cross-session work §4 identifies as the bottleneck. It is also the artifact this methodology has the *least* data to specify. PIC is one codebase, one orchestrator, one timeline; the cross-session decisions on PIC are exactly the kind of pattern that crystallizes wrong from a sample size of one. Building Artifact 5 now would lock in PIC-specific habits that repo 2 might immediately need to override.
- *The cleaner sequence:* (1) Run repo 2's audit using the current set of cross-session habits, unencoded. (2) Instrument those decisions deliberately during the run — keep a written register of *"patterns I noticed during this run, and how I responded"* alongside the per-session reports. (3) After repo 2's synthesis, build Artifact 5 with two data points instead of one. This sequencing is itself an instance of §8's *"orchestrator's prior as a check"* discipline applied to the methodology itself: the prior here is *"we don't know enough yet,"* and the honest move is to admit that and collect data rather than crystallize prematurely.
- *What to do in the meantime:* The orchestrator should explicitly keep the cross-session register during repo 2. That register is the *input* to the eventual Artifact 5 — not the artifact itself.

A meta-note: the artifacts above are ordered by how confident this synthesis is that they will look essentially like this after three more audits. Artifacts 1–3 are well-understood and should be built straight in the artifact-building session that follows this one. Artifact 4 will likely shed and gain items as the next codebases test PIC's patterns; build a deliberately-small first version. Artifact 5 is explicitly deferred — the artifact-building session should *not* try to build it. What it should do is set up the data collection (the cross-session register, the §10 instrumentation hooks) that the eventual Artifact 5 will be built from.

---

## 10. Open questions and what the next repos will test

The honest list of what this single-codebase pass cannot answer. Each item is framed as a falsifiable thing to watch for on repos 2–5.

**Does the prompt-construction logic generalize?** §4's core claim — that the agent's judgment held within well-constructed prompts — is calibrated to PIC's domains, to Claude Code on the May 2026 model versions, and to this orchestrator. The test: run the same area-audit shape against a codebase that differs along at least one of (size, language, security sensitivity, agent model). If override rates stay in the same low range, the claim survives. If they jump, the per-domain calibration work is heavier than this synthesis suggests.

**Is partial-correction debt PIC-specific, or a stop-start-solo-developer signature?** PIC is a long-running solo project with episodic agent involvement — exactly the conditions that could produce the half-applied-pattern shape that dominates Area 6 and recurs four other times. The test: run a comparable audit against a codebase with different authorship history (multi-developer continuous; clean-team-rewrite; pure-agent-built). If partial-correction debt continues to be a dominant pattern, it is a general structural signature. If it drops away, it is calibrated to PIC's authorship history.

**Does the auto-approve fence hold on a codebase with different production topology?** §5's reversible-vs-irreversible × production-vs-non-production fence is calibrated to PIC's production surface — a managed Postgres, a CDN bucket, no production cache layer, a small surface of external vendors. The test: run with the same fence on a codebase whose production surface includes a message queue, a workflow engine, multiple writers to the same datastore, or a strongly-typed eventually-consistent storage layer. The categories of "reversible" and "production" both stretch in these environments; the fence may need new sub-rules.

**What is the right gradation for `agent-friendly`?** The backlog snapshot named this as a structural limitation: the flat label cannot distinguish *"platonic single-file mechanical change"* from *"borderline but probably fine."* Two area reports filed issues as *"agent-friendly: borderline"* in the prose, but the label itself is binary. The test: the next audit should either (a) introduce a graded label (`agent-friendly:clear` / `agent-friendly:supervised`) and see whether the gradation reduces orchestrator-overrides at Phase 2 time, or (b) introduce a richer description schema and skip the new label entirely. Either is informative.

**Does prompt-13-style "ground-truth-the-state" before synthesis generalize?** The backlog-snapshot prompt explicitly pre-figured a finding: *"if the counts are significantly different, flag that immediately."* That worked here because the orchestrator had a calibrated prior to inject. On a less-familiar codebase or one with more sessions between the audit and the synthesis, the prior may be wrong by enough margin that the snapshot's role shifts from *"ground-truth the orchestrator's belief"* to *"construct the orchestrator's belief from scratch."* The test: the next synthesis should report whether the snapshot-as-prompt-13 mechanism worked, and whether the orchestrator's pre-snapshot beliefs were close enough to truth to be useful as a check.

**Is the cross-session conversation transcript a worth-preserving artifact?** This synthesis was possible because the area reports captured *"what surprised me"* and *"process notes"* sections, but the live cross-session conversation — the messages between sessions, the decisions to split Area 4, the stop-the-line judgment calls — survives only in this orchestrator's memory. The test: the next audit should keep that conversation in a deliberate log, and the next synthesis should compare what it can learn from the log to what it can learn from the in-report process notes. If the log adds substantial signal, future audits should capture it by default. If the in-report process notes carry most of the signal, the log is overhead.

Each of these is the test plan for repos 2–5. None of them rule the methodology in or out — the v1 articulation survives or fails on them in pieces, not as a whole. That is the right shape for a v1.

### A note on falsifiability

Several of the questions above — the override-rate question especially, but also the partial-correction-debt prevalence and the agent-friendly-gradation ones — are framed as falsifiable hypotheses. **Falsifiable hypotheses need instrumentation defined *before* the test, not after.** PIC's override rate of *"on the order of twice across roughly 110 issues"* is recollection, not a logged metric — useful as a direction, not rigorous enough to detect a 2x or 3x shift on repo 2.

The methodology's next concrete decision is *what to measure*. At minimum, in each session report on repo 2 onward: every orchestrator override (severity, agent-friendly, scope, area-split decision), with one-line descriptions of each. This is the instrumentation hook §9 Artifact 2 specifies as a principle for the prompt-template artifact. The cross-session register §9 Artifact 5 describes is the complementary instrumentation for cross-session decisions. Both need to be in place from repo 2's first session — retroactive recollection across multi-week audits is not reliable enough to falsify anything. If repo 2 ends without that data captured, the v2 synthesis will have the same problem this one does: it will know what it thinks happened, but not what actually did.
