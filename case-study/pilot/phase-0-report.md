# Phase 0 Report — Baseline & Safety Nets

**Date:** 2026-05-17
**Duration:** ~5 hours
**Goal:** Bring the project to a known-good state before any agent does autonomous work — audit, verify, and install safety nets. No feature work; no refactoring beyond what was needed to unblock the goal.

---

## Executive summary

The project came into Phase 0 with broken tests no one had noticed, dev config silently pointed at the production database, no CI, no branch protection, and a backlog of accumulated drift between code and reality. Within this session we landed **9 commits to `main`**, fixed **19 failing tests** (including a production bug they exposed), built a safe local-dev database with real content, stood up **CI with secret-scanning**, configured **branch protection**, and rotated **every production credential** after discovering they had been committed to git history five months prior. The codebase is now in a known state with active enforcement against the most common ways agentic work could go sideways.

---

## By the numbers

| Metric | Before | After |
|---|---|---|
| Passing tests | 80 of 99 | **99 of 99** |
| Failing / erroring tests | 19 | **0** |
| CI workflows | 0 | 3 jobs (backend, frontend, secret-scan) |
| Branch protection on `main` | None | PR required + 1 review + 3 status checks + admin enforced |
| Dev `.env` DATABASE_URL | Production DB | Local container |
| Production credentials in git | Live, exposed | All rotated; sources sanitized |
| Sentry test pollution | Every pytest run | Gated by `ENVIRONMENT=test` |

---

## What we did, item by item

### Item 1 — Tool Search verification

Catalogued the 10 MCP servers loaded into Claude Code sessions for this project. Confirmed Tool Search is active (deferred MCP tool definitions consume near-zero context until invoked). Disconnected two unused servers (`rube`, deprecated; `make`, account cancelled). Installed and authenticated `gh` CLI (`v2.92.0`, account `wanderindev`, `repo` scope) — the foundation for items 5 and 6.

### Item 2 — CLAUDE.md audit

`CLAUDE.md` had drifted significantly from the running system. Specific corrections:

- **Wrong database host** documented — fixed to the actual prod cluster (`nyc1-69505`, not `nyc3-18aborw5xh`).
- **PostgreSQL 16 documented** while prod runs 17.9 — bumped local dev image to `postgres:17-alpine` to match. Also updated `backend/tests/conftest.py` testcontainer to 17.
- **API endpoint table listed 6 endpoints**; the app registers **19 routers**. Replaced with a router-by-domain grouping.
- **Sentry never mentioned** despite being load-bearing in both backend and frontend — added a dedicated Observability section.
- **Missing integrations** in the tech stack: PayPal, DO Spaces, OpenAI, Anthropic, DeepL, Composio. Added with version markers and a "**planned for replacement**" tag on Composio.
- **No Frontend Tech Stack section** despite React 19, Tailwind v4 (different directive syntax from v3), TipTap, AG Grid being non-obvious. Added.
- Removed stale `Make.com webhook` reference from "mock external services" in the test guidelines.

### Item 3 — Build & test verification

Three sub-tasks executed in order: `(a)` dev DB safety net, `(c)` fix broken tests, `(b)` CI workflow. (Order reasoning: green tests locally before locking CI to enforce them; safe dev DB before debugging in it.)

#### 3 (a) — Dev DB safety net

`.env` files defaulted `DATABASE_URL` to **production** — a real safety hazard. Reshaped the layout:

- `.env` (root) → local container DB
- `backend/.env` → local container DB
- `.env.prod-readonly` (new, chmod 600, gitignored) → only place prod creds live; operator sources explicitly when needed

Brought up the local Postgres container, attempted `alembic upgrade head`, and discovered **alembic has no initial-schema migration** — prod was bootstrapped via `Base.metadata.create_all()` and alembic only tracks deltas. Used the same pragmatic path: `create_all()` + `alembic stamp head`, deferring the proper initial-migration as Phase 1 work.

Pulled prod schema for comparison and found significant drift:

- **9 orphan tables in prod** (`agents`, `ai_models`, `api_usage`, `approved_languages`, `hashtag_groups`, `social_media_*` x3, `translations`) — schema remnants of an AI-agent pipeline and Instagram scheduler that were de-scoped without dropping their tables.
- **7 orphan enum types** in the same neighbourhood.
- **7 columns of drift** in 3 surviving tables (`taxonomies`, `categories`, `media`) — timestamp columns and Instagram-pipeline residue.

Built `backend/scripts/seed_local_db.py`: a column-drift-aware seeder that pulls content tables from prod (using the explicit `.env.prod-readonly` source pattern), drops prod-only columns silently, and skips PII tables (`bookings`, `contact_submissions`, `educators`, etc.). Seeded **44,456 rows across 22 content tables** into local. Smoke-tested by booting `pic-backend` against the local DB and hitting the public API.

#### 3 (c) — Fix the 19 broken tests

The 5 failures and 14 errors collapsed into 5 distinct root causes:

| # | Root cause | Fix |
|---|---|---|
| 1 | `article_factory` didn't set `published_at`, but the list endpoint filters `published_at <= now()`. Postgres `now()` is fixed at transaction start, so even `datetime.utcnow()` ran microseconds *later* and was excluded. | Default to `utcnow() - 1 second` with a sentinel for opt-out. |
| 2 | Markdown renderer added `<h1 id="anchor">` (TOC extension); tests asserted exact `<h1>`. | Substring match on `<h1` instead. |
| 3 | `Attraction` model split `ticket_child_*` into `_5_10_*` and `_10_17_*`; fixtures still used the old column names. | Updated fixtures and the `ParticipantBreakdown` participant kwarg (`child_5_17` → `child_10_17`). |
| 4 | Price string formatting drifted from `"58.00"` to `"58.0000"`. | Compare via `Decimal(...)` instead of string equality. |
| 5 | testcontainer was on `postgres:16-alpine`. | Bumped to `17-alpine`. |

**Production bug surfaced in passing:** `app/api/tours.py` and `app/schemas/tour.py` referenced `ticket_child_tourist` / `ticket_child_resident` — attributes the model no longer has. Hitting `GET /api/v1/tours/{slug}` for any tour with active attractions would have thrown `AttributeError` and 500'd. Updated both files to use the bracketed columns. The frontend doesn't consume those fields, so the schema change was invisible to the API contract. This is exactly the class of bug that "broken tests, no one notices" silently accumulates.

Final result: **99 passed / 0 failed / 0 errors** in 8 seconds.

#### 3 (b) — CI workflow

Added `.github/workflows/ci.yml` with two parallel jobs (backend pytest + ruff, frontend `npm ci` + vite build), pip and npm caching, concurrency cancellation, and ruff in informational mode (non-blocking until Phase 1 cleans the existing 83 ruff errors). First run on first push passed in **<1 minute** total wall-clock.

### Item 4 — Sentry connection check

Verified all three Sentry integration surfaces by code review (no test errors triggered):

- **Backend**: `sentry_sdk.init()` runs at import; relies on `sentry-sdk[fastapi]` auto-instrumentation for transactions and uncaught exceptions; no explicit `capture_exception` calls anywhere.
- **Frontend**: separate Sentry project; `Sentry.withErrorBoundary` on three critical pages (Checkout, OrderConfirmation, Contact); browser SDK auto-instruments `window.onerror` and `unhandledrejection`. **No top-level `<ErrorBoundary>` on `<App>`** — flagged for Phase 1.
- **cert-watcher** (built earlier this session): the only one of the three that reads DSN from env; daily cron-monitor check-ins; already verified end-to-end.

Applied one small fix: gated the backend `sentry_sdk.init()` behind `ENVIRONMENT != "test"` so pytest and CI runs stop emitting startup transactions to the production Sentry project. Full DSN-from-env refactor deferred to Phase 1.

### Item 5 — GitHub repo hygiene

This was the largest item by impact. Findings:

- **Branch protection unavailable** on the private/free GitHub plan (HTTP 403). Later in the session, after the user upgraded to GitHub Pro, we enabled full protection: 1 approval required, 3 status checks (Backend, Frontend, Secrets scan), strict-up-to-date, dismiss-stale-reviews, conversation resolution required, force-pushes and deletions blocked, **admin enforcement on** (the user goes through the same flow as agents).

- **No open PRs, no stale branches.** Clean.

- **`.gitignore` had a load-bearing loophole**: `docker-compose.prod.yml` was listed but **still tracked**, because gitignore doesn't untrack already-committed files. Every secret rotation since the file was first committed had landed in git history through that hole.

- **🚨 Production credentials committed to git history** since `2025-12-22` (~5 months exposure). Found in 4 files in current `HEAD`:
  - `docker-compose.prod.yml` — DB password, OpenAI, Anthropic, PayPal, DeepL, Composio, DO Spaces keys
  - `.claude/skills/database-ops/SKILL.md` — DB password in three example commands
  - `backend/scripts/translate_taxonomy_category.py` — hardcoded DATABASE_URL with password as fallback
  - `docs/database-exploration.md` — connection string in plain markdown

  Plus a stale Make webhook URL + key in `frontend/HOME_PAGE_PLAN.md` (dead account, but still bad form).

  Remediation:
  1. **User rotated every credential** in vendor consoles (DO Managed Postgres, DO Spaces, Anthropic, OpenAI, PayPal, DeepL, Composio) and revoked the old values.
  2. **Coordinated DB rotation** via SSH on the droplet to minimize downtime — under 30 seconds. Required one debug round on URL-encoding when DO's "Connection Details" page showed a stale password.
  3. **Discovered the user rotation also affected TRD** (different DB, same `doadmin` user, same cluster) — fixed in parallel.
  4. **Untracked `docker-compose.prod.yml`** (`git rm --cached`) so future edits stay out of git.
  5. **Sanitized the four files** still in HEAD: replaced hardcoded values with the explicit `source .env.prod-readonly; psql "$DATABASE_URL"` pattern.
  6. **Sanitized `HOME_PAGE_PLAN.md`** Make webhook section with `<REDACTED>` markers and a historical note.
  7. **Added gitleaks to CI** as a third job, scanning the working tree on every push/PR (`--no-git` mode — pre-Phase-0 commits still contain the rotated-but-dead values; scanning the tree validates every push against its post-merge state). Configured `.gitleaks.toml` with path and regex allowlists for known false positives (gitignored files, PricingConfig row names).

### Item 6 — Backlog readiness

Read-only audit of GitHub labels and issue templates. Of the six labels needed for Phase 1+ work:

| Label | Status |
|---|---|
| `bug` | Exists (default) |
| `enhancement` | Exists (default) |
| `code-quality:critical` | Missing |
| `code-quality:moderate` | Missing |
| `code-quality:nice-to-have` | Missing |
| `agent-friendly` | Missing |

**No issue templates configured.** Recommended creating four (`bug_report`, `feature_request`, `code_quality`, `agent_task`) early in Phase 1, since issue templates are committed files and will need to land via PR now that branch protection is on.

---

## Phase 1 backlog (deferred findings)

Things we identified during Phase 0 but consciously did not fix, sorted roughly by importance:

### High value
- **Generate an initial alembic migration** so `alembic upgrade head` can reproduce prod schema from scratch.
- **Drop the 9 orphan tables + 7 enums in prod** after confirming nothing still writes to them. Mostly the abandoned AI-agent pipeline and Instagram scheduler.
- **De-hardcode the Sentry DSN** in `backend/app/main.py` and `frontend/src/main.jsx`; read from env. (Test pollution is gated already; this is the broader fix.)
- **Create the 4 missing labels + 4 issue templates** so Phase 1 work has structure.
- **Move PIC to TRD's `env_file:` pattern** so `docker-compose.prod.yml` becomes safe to commit (TRD already does this cleanly).

### Medium value
- **83 ruff errors** in `backend/app/`, 73 auto-fixable. Then flip CI's ruff step from `continue-on-error: true` to blocking.
- **11 npm vulnerabilities** (5 moderate, 6 high) per `npm audit`.
- **Add `pytest-cov`** and start tracking coverage.
- **Pydantic v1 deprecation warnings** in 4 schema files (`class Config` → `ConfigDict`).
- **Add a top-level frontend `<Sentry.ErrorBoundary>`** so uncaught errors outside Checkout / Contact / OrderConfirmation still show a recovery UI.
- **Sweep `backend/app/services/` for swallowed exceptions** that should `capture_exception` to Sentry.
- **`send_default_pii=True`** review against your privacy policy / GDPR posture.
- **Tighten `.env*` permissions** to 600 on the droplet (currently 664 on TRD's `.env`).

### Lower value / cosmetic
- **2.6 MB frontend JS bundle** — exceeds Vite's 500kB warning; introduce code-splitting.
- **Stale planning docs** (`frontend/HOME_PAGE_PLAN.md`, `IMPLEMENTATION_PLAN.md`, `PROJECT_CONTEXT.md`) — likely candidates for deletion after a content audit.
- **Node 20 deprecation** in GitHub Actions (hard cutoff June 2026).
- **History rewrite with `git filter-repo`** to strip the rotated-but-shaped credentials from past commits. Purely cosmetic now that everything is rotated.
- **Pre-commit gitleaks hook** as a local belt-and-suspenders alongside the CI scan.
- **Split cert-watcher into its own Sentry project** rather than reusing backend's.

---

## What's now in place going forward

1. **Local dev environment is safe.** No accidental prod hits from a `python manage.py shell` or a wayward test. Prod URL only enters scope when the operator explicitly `source`s `.env.prod-readonly`.
2. **The test suite is green** and exists primarily because there's CI to enforce it. A test that breaks now will be visible immediately, not five months later.
3. **CI runs three jobs on every push and PR**: backend tests, frontend build, secret scan. All three gate merges.
4. **`main` is protected**: PR required, 1 review, 3 status checks must pass, admins enforced.
5. **Production credentials are unique, rotated, and the only copy lives on the droplet** in `docker-compose.prod.yml` (untracked) and `/home/wanderindev/trd/.env`.
6. **Documentation matches reality.** `CLAUDE.md` describes the actual stack, the actual database, the actual API surface.

The next agent that joins this codebase — or the next time we revisit it — won't have to learn what was true vs. what was documented before being able to make a change safely.