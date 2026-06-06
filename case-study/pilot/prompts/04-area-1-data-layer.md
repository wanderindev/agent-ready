We're starting Phase 1 Part B with Area 1: Data layer & SQLAlchemy models.

The audit plan at docs/pilot/phase-1-audit-plan.md is the authoritative scope
document for Part B. Read it first if context has rolled. The areas, their
ordering, and the working style for each session are all defined there.

This session covers Area 1 only. Resist scope drift into other areas — note
findings that belong elsewhere in "newly observed" at the end.

## Scope

Per the audit plan:
- `backend/app/models/` (all model files, relationships, constraints,
  indexes, enums, defaults, nullables)
- `backend/alembic/` (migration history, configuration)
- Patterns in use: soft-delete / status fields, audit timestamps,
  enum conventions, FK behaviors, cascade rules

Out of scope for this session (will be covered in their own areas):
- Pydantic schemas (those are partly Area 2/3/4 territory and partly their
  own thing — flag interesting findings, don't file)
- Service-layer code that uses the models
- Anything outside `backend/app/models/` and `backend/alembic/`

## Context, not work to do

Two existing issues are inputs to this audit, NOT work for this session:
- #3 (generate initial alembic migration)
- #4 (drop 9 orphan tables + 7 orphan enums in prod)

You don't need to act on these. They exist; the audit can assume they'll
get done in Phase 2+. But if you find evidence during the audit that
should be added to those issues as context (e.g. specific FK dependencies
between the orphans, or schema details that affect how the initial
migration should be generated), add a comment to the relevant issue with
your finding. Don't change the issue body — comment only.

## One small mystery to resolve

The Phase 0 report counted 4 Pydantic schema files with v1 `class Config`
deprecation warnings. The Phase 1 Part A issue (#12) was filed against
2 files. Worth a 2-minute check: are there really only 2, or did Part A
miss some? Resolve this and either update issue #12 with the correct
count + file list, or note it as resolved if 2 was right.

This is the only "resolve and update" task in this session — everything
else is read-only auditing.

## What to look for

Standard things in a data-layer audit:

**Schema hygiene**
- Columns that should be NOT NULL but are nullable (or vice versa)
- Missing or misnamed indexes on FK columns, frequently-filtered columns,
  or columns used in ORDER BY
- FK constraints with weak cascade behavior (e.g. ON DELETE SET NULL where
  CASCADE would be safer, or vice versa)
- Inconsistent use of `created_at` / `updated_at` across models
- Soft-delete patterns applied inconsistently
- Enum types defined inline vs. as proper PG enums vs. as string columns
  with check constraints — pick the inconsistencies

**Relationship correctness**
- Backrefs vs back_populates inconsistency
- Lazy-loading strategy mismatches (default N+1 risks)
- Cascade configurations that don't match the FK constraint
- Orphan relationships (model A points to B; B has no awareness of A)

**Drift between model and database**
- Phase 0 found 7 columns of drift across `taxonomies`, `categories`,
  `media`. Check whether the models are now the source of truth (i.e.
  prod schema has extra columns) or the database is (prod is missing
  columns the model expects). The Phase 0 seed script masked some of
  this — read it for hints on which way the drift goes.

**Migration history sanity**
- Are there migrations that were applied but later reverted via direct
  SQL? (Look for migration files referencing columns/tables that no
  longer exist.)
- Are there branches in the alembic history that shouldn't exist?
- Any migrations that have been edited after being applied to prod
  (a real risk on solo projects)?

**Convention drift**
- Mixed naming conventions (singular vs plural table names, camelCase
  vs snake_case column names, _id vs Id suffixes)
- Mixed use of `String(N)` with different N for the same kind of data
  (e.g. emails sometimes 255, sometimes 320)

## Working style

- **Batch-and-confirm** as in Part A. Group findings into batches of
  3-5, propose titles + labels + agent-friendly classification, get
  approval, file.
- **Severity calibration:** A nullable column that allows real data
  corruption is `code-quality:critical`. A missing index that hurts
  query perf on a non-hot path is `code-quality:moderate`. A
  cosmetic naming inconsistency is `code-quality:nice-to-have`.
- **Agent-friendly calibration:** Schema changes are explicitly NOT
  agent-friendly per the criteria doc, even when small. Naming-only
  refactors on internal columns might be; column type changes or
  constraint changes are not.
- **Stop-the-line:** If you find evidence of active data corruption,
  a FK constraint that's silently dropping referential integrity, or
  a soft-delete bug exposing supposedly-deleted records via the public
  API — surface immediately and we'll fix inline before continuing the
  audit.
- **End-of-session report.** Same shape as the Phase 0 report:
  executive summary, by-the-numbers, item-by-item findings, what's
  filed vs what's deferred, "newly observed" items for other audit
  areas. Save it as `docs/pilot/phase-1-area-1-report.md` and open
  a small PR for it (branch protection requires PR even for docs).

## What this session probably looks like

A guess at scope: this is the smallest of the six areas. Reading
through ~20-40 model files and the alembic directory, comparing
against prod schema (which we already have a local mirror of from
Phase 0), should take 1-2 hours of focused work. Findings volume:
my expectation is 5-10 issues filed. If you're approaching 20+
findings, something is wrong — either the codebase has more rot
than expected (in which case stop and surface) or you've drifted
into scope creep (in which case stop and re-scope).

Begin by reading the audit plan, the Phase 0 report's data-layer
sections (Item 3a especially), and issues #3, #4, and #12 for
context. Then propose how you want to approach the audit — by file,
by model domain (content / users / educators / orders / etc.), or
by concern (constraints first, then indexes, then relationships).
Wait for my approval on the approach before starting.
