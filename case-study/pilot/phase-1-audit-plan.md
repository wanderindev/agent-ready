# Phase 1 — Audit Plan

**Date:** 2026-05-18
**Status:** Part A complete (Phase 0 backlog filed as issues #3 – #19). Part B = the structured audit across the codebase; this doc is the plan.

---

## What this plan is for

Phase 1 produces a labeled GitHub backlog of every finding worth capturing. It does **not** fix things, with the two [stop-the-line exceptions](agent-friendly-criteria.md#stop-the-line) — serious security issues and live production bugs affecting the public-facing UI.

Part A was the structured intake of [Phase 0's deferred backlog](phase-0-report.md#phase-1-backlog-deferred-findings) — 17 issues filed against the four templates in `.github/ISSUE_TEMPLATE/`. Part B is the actual codebase audit: walk through each area listed below, file findings as issues, move on. One area per session; some may split.

---

## Audit areas

Six areas, ordered by leverage. **Leverage** = `P(finding bugs) × cost(those bugs in production)`. Where Phase 0 left a specific hint, it's noted under that area.

### 1. Data layer & SQLAlchemy models — **medium**

**Why first:** Every other audit touches the schema. Phase 0 already proved drift exists (9 orphan tables, 7 orphan enums, 7 drifted columns, no baseline migration). Surfacing model / relationship / constraint issues here makes the per-domain audits sharper.

**Scope:** `backend/app/models/`, `backend/alembic/`, relationship definitions, indexes, constraints, enum usage, soft-delete / status-field conventions, default values, nullable columns that shouldn't be.

**Phase 0 hints:**
- Issues #3 (initial migration) and #4 (drop orphans) are inputs to this area, not outputs.
- The Pydantic schema file count drifted between Phase 0 (4) and Phase 1 Part A (2) — worth confirming during this audit that the Phase 0 count wasn't a miscount of something else.

### 2. Payments, bookings, orders & PayPal webhook — **medium**

**Why second:** Money flow. A bug here is a duplicate charge, a lost order, or a webhook idempotency failure — highest dollar cost per defect, and the public-facing UI surface where a regression is most visible.

**Scope:** `backend/app/api/tours.py`, `bookings.py`, `orders.py`, `webhooks.py`, the PayPal SDK integration, order state machine, related schemas, frontend checkout flow.

**Phase 0 hints:**
- Phase 0 fixed a real production bug in `tours.py` (`ticket_child_*` AttributeError when fetching tours with active attractions). That area has demonstrated recent drift between code and schema.
- **PayPal integration may be incomplete or unexercised in prod.** During Phase 0's credential rotation, the PayPal secret in `docker-compose.prod.yml` did not match the secret in the PayPal account console. A live integration with mismatched credentials would have been producing constant Sentry noise — the absence of that noise is strong signal that either the code path never ran in real bookings, or it silently swallowed every failure. Approach the PayPal portion of this audit assuming it may be dead code; verify by inspecting whether any real PayPal-completed orders exist in prod before assuming the integration "works."

### 3. Auth & educator access gate — **small**

**Why third:** Narrow surface but high blast radius (access control + PII). Cheap to audit, expensive to get wrong. The educator access system is newer code (per project memory) — newer = less battle-tested.

**Scope:** `backend/app/api/auth.py`, `admin.py`, `educators.py`, session/token handling, the email-confirmation flow, the 7-day access window logic, the re-verification 6-digit code path.

**Phase 0 hints:** None directly, but the educator access work was the project's "NEXT to implement" item per project memory at the time Phase 0 ran. Confirm during the audit which parts of the spec actually shipped vs. remain to-do.

### 4. Backend services & long-running pipelines — **large** (may split into two sessions)

**Why fourth:** The bulk of business logic lives here, and Phase 0 noted issue #8 (swallowed exceptions sweep) explicitly applies. Edu pipeline, translation, LLM orchestration, media generation, watermarking, Composio Gmail — the highest density of silent failure modes.

**Scope:** `backend/app/services/*` (every module), external integration boundaries (Composio Gmail, DeepL, Anthropic, OpenAI, DO Spaces, NotebookLM CLI if invoked from services).

**Phase 0 hints:**
- Issue #8 (swallowed exceptions) is directly an output of this audit, not an input — expect to file many sub-issues against specific service modules.
- Project memory notes that long research docs (6000+ words) cause LLMs to ignore word-count / section constraints — that's a known workaround in the edu pipeline. Audit whether similar fragility exists elsewhere (translation prompts, study guide generation, etc.).

**Likely split:** Edu-pipeline-specific (study guides, slides, watermarking, media library) vs. cross-cutting services (translation, Composio, generic LLM wrappers). Decide after a first scan; the split should be along service-module boundaries, not along call-graph boundaries.

### 5. Frontend public site — **medium**

**Why fifth:** User-visible defects but lower-cost-per-defect than payment bugs. Pairs naturally with issues already filed.

**Scope:** `frontend/src/` minus admin routes — Home, Blog, Tours listing, Materiales Educativos, Contact, i18n setup, Sentry instrumentation, error handling, public state management, the bilingual fallback paths.

**Phase 0 hints:**
- Issue #7 (no top-level `<Sentry.ErrorBoundary>`).
- Issue #18 (2.6 MB initial bundle, code-splitting needed).
- Frontend has no component test suite — verification is manual, which constrains agent-friendliness for any findings here.

### 6. Frontend admin CMS — **medium**

**Why last:** Internal-facing (only Diego uses it). Bounded user-impact for defects. Worth its own session because TipTap + AG Grid are different concerns from public-site React.

**Scope:** Admin routes, the CMS editor (TipTap), data grids (AG Grid), admin auth UI, any admin-only services on the frontend side.

**Phase 0 hints:** None directly; this area was untouched in Phase 0.

---

## Explicitly skipped

- **CI / build / deploy infra.** Comprehensively inspected and rebuilt in Phase 0 (CI workflows, branch protection, gitleaks, Dockerfiles, docker-compose layout). Anything new here surfaces organically through CI runs against PRs.
- **cert-watcher sidecar.** Built and verified end-to-end in Phase 0. Fresh code; don't audit it again until it has had real production use.
- **Top-level docs** (`CLAUDE.md`, `README.md`). Updated in Phase 0 and verified against reality. Will drift again over time, but auditing them in Phase 1 is premature.

---

## Working style for each audit session

- **One area per session.** Resist the urge to "while I'm in here, also look at X" — that's exactly the scope creep this phase is designed to prevent.
- **File findings, don't fix them.** Stop-the-line still applies but should be rare in a read-only audit.
- **Batch-and-confirm** for issue filing, same pattern as Part A: group findings into batches of 3–5, show proposed titles + labels + agent-friendly classifications, get approval, file.
- **Note "newly observed" items** at the end of each session for anything outside the area's scope that's worth tracking. Don't file them — they belong to a future area's audit.
- **Each session ends with a short report** following the Phase 0 report's shape: what was audited, what was filed, what was deferred, what surprised you.

---

## When Phase 1 ends

When all six areas are audited and their findings filed, Phase 1 produces:

1. **A labeled GitHub backlog** of every finding worth tracking. Each issue has a severity label and an honest agent-friendly classification.
2. **A Phase 1 report** following the Phase 0 report's shape: what was found, what's now known, what's queued for Phase 2+.
3. **A set of agent-friendly issues** that an autonomous agent could plausibly pick up next — the entry point for Phase 2.