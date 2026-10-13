We're starting Phase 1 Part B Area 4a: Cross-cutting services audit.

The audit plan at docs/pilot/phase-1-audit-plan.md originally framed Area 4
as one session that might split. With 20 modules in backend/app/services/,
we're splitting it into three: 4a (cross-cutting wrappers, this session),
4c (systematic swallowed-exceptions sweep across all services), then 4b
(domain pipelines). Order: 4a → 4c → 4b. The 4a findings shape what 4c
looks for; both shape what 4b finds.

Read these first for context:
- The audit plan
- The Area 1, 2, and 3 reports for newly-observed items targeted at Area 4
- Issue #8 (swallowed exceptions sweep) — explicitly NOT for this session,
  but the "newly observed" items in Area 2's report flag specific
  composio_client and paypal_service swallow patterns. Note them when
  encountered but file them in 4c, not 4a.

## Why this area matters

Cross-cutting services are the lower-level wrappers that domain pipelines
call into: LLM clients, translation, email, storage, generic schedulers.
Their failure modes propagate upward — a Composio Gmail wrapper that
swallows errors invisibly creates the customer-stranding risk Area 2
identified (issue #37). The same pattern likely repeats for LLM and
DeepL wrappers. Auditing the wrappers first means the domain pipeline
audit (4b) can assume a clear picture of how the underlying services
behave.

This area is also where the project's external-vendor coupling lives:
Anthropic, OpenAI, DeepL, Composio Gmail, DO Spaces. The audit should
produce a clear picture of what depends on what, what fails how, and
what would happen if each vendor had an outage.

## Scope

In-scope files: the cross-cutting wrappers in `backend/app/services/`.
Specifically the modules that wrap external services or provide generic
infrastructure used by other services. Likely candidates (verify by
reading, not by guessing):
- LLM clients: Anthropic wrapper, OpenAI wrapper, any base/abstract LLM
  client
- Translation: DeepL client
- Email: Composio Gmail wrapper
- Storage: DO Spaces client
- Any scheduler / background-task / queue plumbing
- Any retry / rate-limiting / circuit-breaker utilities
- Any generic HTTP client base class

Out of scope for this session:
- Domain pipelines (edu, articles, media generation, watermarking,
  NotebookLM CLI) — those are 4b
- Swallowed-exceptions analysis — that's 4c (note instances but don't
  file them here)
- API routers (audited in previous areas)
- Models, schemas, frontend (audited or scheduled for later areas)

If you find a module that's hard to classify as "cross-cutting wrapper"
vs "domain pipeline," tell me and we'll decide together rather than
have you choose unilaterally.

## Map the surface first

Before auditing, produce a service-module inventory:
1. List every module in `backend/app/services/` with one-line description
2. Classify each as cross-cutting (4a scope), domain pipeline (4b scope),
   or ambiguous (decision needed)
3. For the cross-cutting modules, sketch the dependency graph: which
   services call which others, and which external vendors each touches
4. Flag any module that's imported by 4+ other services — those are the
   highest-leverage audit targets because their bugs propagate widely

Show me the inventory and dependency sketch before starting the audit
itself. The classification matters — getting it wrong shifts work between
4a and 4b. We'll lock the split together before any in-depth reading.

## What to look for in cross-cutting wrappers

**Vendor coupling and failure modes**
- What does each wrapper do when the vendor returns an error? 4xx vs
  5xx vs timeout vs connection refused — handled differently or
  uniformly?
- Are retries implemented? On what (idempotent ops only?) and with
  what backoff? Bounded?
- Is there a circuit-breaker pattern, or does a vendor outage produce
  unbounded retries per request?
- Are timeouts set on every external call? Default timeouts (often
  none or absurdly long) versus explicit ones?
- Are vendor responses validated before being returned to the caller,
  or trusted? Especially relevant for LLM clients — what happens if
  the model returns malformed JSON, empty output, or a refusal?

**Configuration and secrets**
- How is each vendor's API key / credential loaded? Env vars only?
  Hardcoded fallbacks? (Phase 0 found a lot of these — verify none
  remain in services.)
- Are credentials passed correctly into the SDK or HTTP client? Any
  paths where the key is logged in plaintext (request logging,
  Sentry breadcrumbs, application logs)?
- Is there configuration drift between dev/test/prod (e.g. test
  hitting a real vendor by accident)?

**Cost and rate-limit awareness**
- Do LLM wrappers track token usage? Anywhere?
- Are rate limits respected, or is throttling deferred to the vendor
  to enforce by 429-ing?
- Is there any usage-cap or budget-cap logic, or could a runaway loop
  burn unbounded API spend?
- Specifically for the Anthropic wrapper: which model is hardcoded?
  Is it pinned to a specific version, or "latest"? (Pinning matters
  for reproducibility; "latest" makes test results drift.)

**Concurrency**
- Async vs sync — consistent within each wrapper? Mixed in awkward
  ways?
- Any module creating its own event loop (the pattern Area 2 flagged
  in the PayPal webhook)?
- Any blocking calls inside async functions that would defeat
  concurrency?
- Connection pooling for HTTP clients — set up correctly, or one
  client per call?

**Observability**
- Are external calls logged anywhere? Sentry breadcrumbs, structured
  logs, application logs?
- Are failures surfaced to Sentry as exceptions, as captured-handled
  exceptions, or invisibly?
- Is there latency tracking? Any way to answer "is DeepL slow today"
  from a dashboard?

**Inter-service consistency**
- Do all wrappers expose a similar API shape (e.g. raise on error vs
  return result objects)? Or does each wrapper do its own thing?
- Are exceptions normalized to project-specific exception types, or
  do vendor SDK exceptions leak through to callers?
- Same question for retry/timeout behavior — consistent across
  wrappers or per-wrapper improvisation?

**Things that came up in earlier areas**
- Composio Gmail wrapper: Area 2's #37 (swallowed notification
  failures) traces here. Area 2's "newly observed" said
  composio_client.send_email is the boundary that may swallow Gmail
  API errors. Verify what it actually does. The swallowed-exceptions
  *instance* is a 4c finding, but the *behavior* of the wrapper — does
  it raise on failure, return a boolean, return None? — is a 4a
  finding because it shapes how every caller should integrate with it.
- Project memory notes that long research docs (6000+ words) cause LLMs
  to ignore constraints. That's a domain-pipeline workaround (4b
  territory), but if it surfaces a missing capability in the LLM
  wrapper (e.g. no chunking utility) that's a 4a finding.

## Working style

- **Batch-and-confirm** as in previous sessions.
- **Severity calibration:** A wrapper that silently swallows vendor
  errors is critical (it creates the invisible-failure class Area 2
  identified). A wrapper without timeouts is critical (it creates
  unbounded-blocking risk). A wrapper hardcoding a model version that's
  about to be deprecated is moderate. Inconsistent exception types
  across wrappers is moderate. Variable-naming or formatting issues
  are nice-to-have.
- **Agent-friendly calibration:** Wrappers handle external boundaries
  and error behavior. Most changes here require judgment about
  contracts and failure modes — NOT agent-friendly. Cosmetic refactors,
  type annotations, doc updates: probably agent-friendly. A
  contained, well-specified migration like "swap deprecated SDK call
  X for replacement Y" might qualify, but the assessment must pass the
  six-checkbox gate honestly.
- **Stop-the-line:** If you find a wrapper that's logging vendor
  credentials in plaintext, or has a code path that could exfiltrate
  user data to the wrong vendor, or has a hardcoded test credential
  reaching prod, surface immediately. We fix inline.
- **Token usage:** This session has access to the $100 promotional
  credit pool. If you hit subscription cap during this session,
  continue rather than stop — the overflow lands on extra-usage credit
  and we want to be thorough on the wrapper audit because it shapes
  4b's scope. But "be thorough" is not "expand scope" — stay in
  cross-cutting services.

## End-of-session report

Save as `docs/pilot/phase-1-area-4a-report.md`. Same shape as previous
reports.

Add two area-specific sections:

**"Service surface map."** The inventory and dependency sketch from
the start, refined by what the audit found. This becomes the reference
for 4b and 4c. Specifically: every cross-cutting module, its external
dependencies, and which downstream services depend on it. A diagram
or table, not prose.

**"Vendor failure-mode summary."** For each external vendor, a clear
statement of: what the wrapper does on vendor success, what it does
on vendor error, what it does on vendor timeout, whether the failure
is visible upstream (raises) or invisible (swallowed/None/False), and
what would happen system-wide if the vendor were down for an hour.
This becomes a load-bearing reference for any future incident or
reliability conversation.

## Scope estimate

This is the first of three sessions for Area 4. Expect 1.5-2 hours of
focused work and 8-12 issues filed for 4a specifically. The 4c session
will likely add 10-20 more issues (swallowed exceptions are pervasive
per Area 2's signal). 4b is the largest with 15-25 expected.

If you're approaching 20+ findings in 4a alone, either the wrappers
are in worse shape than expected (surface and we'll regroup) or you've
drifted into domain-pipeline territory (re-scope).

Begin with the service-module inventory and dependency sketch. Wait
for my approval on the cross-cutting vs domain classification before
starting the in-depth audit.
