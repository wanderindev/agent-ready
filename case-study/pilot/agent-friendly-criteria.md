# Agent-Friendly Criteria

This document is the authoritative answer to **"should this issue be marked `agent-friendly`?"**

An `agent-friendly` issue is one we'd trust an autonomous agent to pick up and finish without a human pairing on it. The label is orthogonal to severity: a `code-quality:critical` issue can be agent-friendly, and a `code-quality:nice-to-have` issue might not be.

If you're unsure, lean toward **not** applying the label. Human-pair the work first; the next similar issue will be easier to classify.

---

## The criteria

All six must hold. If any one fails, it is not agent-friendly.

### 1. Single-file or tightly-scoped multi-file change

The change touches one file, or a small handful of closely-related files (e.g. a service and its test). "Touches every router," "renames a column used across the app," and "introduces a new abstraction" all fail this. The agent should be able to hold the entire change in working memory.

### 2. No business logic decisions required

The "what" is settled. The agent decides "how" within obvious bounds, but doesn't pick between user-visible behaviors, naming conventions for new public APIs, or trade-offs the team hasn't already made. If the issue contains the phrase "decide whether," it fails this.

### 3. No schema migrations

No `alembic revision`, no `CREATE TABLE`, no column adds/drops/renames, no enum changes. Schema work is irreversible in prod and requires coordinated rollout — keep a human in the loop. Backfills, data migrations, and `INSERT`s against existing tables also fail this.

### 4. No changes to auth, payment, or PII handling

Anything in `backend/app/api/auth.py`, the PayPal flow, the educators table/access gate, or the contact-form pipeline. These are high-blast-radius areas where a regression isn't just a bug — it's a security or compliance event. Agents can read this code; they should not modify it without a human review pass beyond standard PR approval.

### 5. Tests exist for the affected area, or can be added trivially

There's an existing test file for the module, OR adding a fresh `test_<thing>.py` is straightforward (no fixture archaeology, no test-container plumbing). "Tests will need a new fixture for `ApprovedEducator` against a seeded `Booking`" probably fails this; "add an assertion to the existing `test_articles.py`" passes.

### 6. Clear acceptance criteria

The issue says exactly what "done" looks like, in checkable terms. "Improve the markdown renderer" fails; "Render `<h1>` without the auto-generated `id` attribute on the public article endpoint, update the affected assertion in `test_articles.py`" passes. The agent must be able to read the issue and know when to stop.

---

## Worked examples

### Clearly qualifies

> **Bump local Postgres testcontainer from `15-alpine` to `17-alpine` in `backend/tests/conftest.py` so it matches prod.**
>
> - Single file. ✓
> - No business logic. ✓
> - No schema migration (testcontainer image bump). ✓
> - Not auth/payment/PII. ✓
> - Tests are the affected area; running them is the verification. ✓
> - Acceptance: image string changed, `pytest` passes locally and in CI. ✓

Apply `agent-friendly`. This is the platonic case.

### Clearly doesn't qualify

> **Replace Composio Gmail with a self-hosted SMTP integration for educator confirmation emails.**
>
> - Multi-file: service, config, env, tests, possibly the contact form too. ✗
> - Business logic decisions: which SMTP provider, retry semantics, bounce handling. ✗
> - Touches PII pipeline (educator emails). ✗
> - Tests will need a new mock layer for SMTP. ✗ (borderline)
>
> Even the first three failures are enough. Do not apply `agent-friendly` — this needs a human at the wheel.

### Borderline

> **Fix 73 auto-fixable `ruff` errors in `backend/app/` and flip the CI ruff step from `continue-on-error: true` to blocking.**
>
> - Touches many files (~30+). ✗ on a strict reading of "tightly-scoped multi-file."
> - But: zero business logic, no schema, not auth/payment/PII, tests already exist (and protect against regressions), acceptance is mechanical (`ruff check` exits 0).
>
> **Verdict: agent-friendly.** The "tightly-scoped multi-file" criterion is about *cognitive scope*, not file count. A mechanical, tool-driven sweep where every change is the same kind of edit is fine even at 30 files. The 10 non-auto-fixable errors might need a separate, more careful pass — flag those for human review and split the issue if so.

---

## Test-writing tasks: the oracle rule

Writing tests is a special case. Claude writes strong Python tests, and adding coverage for a single area is well within an agent's reach — so test-writing is *often* `agent-friendly`. But it carries a failure mode that bug-fixing does not, and that failure mode decides the label.

**The oracle problem.** When an agent *fixes* code, the existing suite is the oracle: a green run means the known-good behavior still holds. When an agent *writes* tests, there is no oracle — a passing test only proves "the code does what I asserted." If the agent derived that assertion by reading the implementation, it is circular: the result is a **characterization test that enshrines current behavior, bugs included**, and reports green. A plausible-but-wrong assertion is *worse* than no test, because it manufactures false confidence in exactly the path we wanted to protect.

So a test-writing task is `agent-friendly` only when **both** of these hold, on top of the six criteria:

- **(a) The area is spec'd or pure-logic, and not excluded by criterion #4.** Pure transforms, parsers, scoring/pricing math, read endpoints with schema contracts, admin CRUD with clear semantics — fine. Payment/webhook idempotency, auth, and the educator access gate stay human-led: a wrong assertion about money or access is the most expensive false-green, and their "what should happen" is often defined only by the code itself.
- **(b) The brief supplies the oracle.** A test-writing brief must **enumerate the specific behaviors and their expected outcomes to assert**, derived from the spec / API contract / issue — *not* "go cover `file_x.py`." This is the brief-writer pre-resolving the one ambiguity that matters for tests: what *correct* looks like, independent of the current implementation. A brief that only names a coverage target is a loose brief and will produce characterization tests.

When (a) or (b) can't be met, keep a human in the loop — write the tests in pair-mode, or have the human review the **assertions** (not merely that the suite is green) before merge. Either way, scope each test-writing issue to **one area per session** (criterion #1); "raise coverage across the backend" is not one task.

---

## Stop the line

During any agent or audit session (Phase 1 included), most findings get filed as issues and deferred. **Two exceptions** get fixed inline:

1. **Serious security issues.** Exposed credentials in tracked files, an auth bypass, an unauthenticated endpoint leaking PII, an obvious injection vector. If exploiting it could harm users or the business *today*, fix it now. File the regression test alongside the fix.
2. **Actual production bugs affecting the public-facing UI.** Not "this could break under unusual load" — an actively-broken user flow on the live site. The kind of thing Sentry should have caught but didn't.

Everything else — code smells, missing tests, drift between code and docs, hardcoded values that *could* leak but haven't, ruff errors, deprecation warnings, performance concerns — gets an issue and waits.

The bar for "stop the line" is deliberately high. Most things that feel urgent in the moment aren't. When in doubt: file the issue, keep moving, surface it in the session summary.
