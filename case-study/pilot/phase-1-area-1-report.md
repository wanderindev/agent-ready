# Phase 1 — Area 1 Report: Data layer & SQLAlchemy models

**Date:** 2026-05-18
**Duration:** ~1.5 hours
**Scope:** `backend/app/models/` (23 model files), `backend/alembic/` (env.py + 21 migrations), model-vs-prod drift signals from Phase 0.

---

## Executive summary

The data layer is structurally sound — linear migration history, no edited-after-applied evidence, no soft-delete bugs leaking deleted rows. What it lacks is **convention discipline**. Three competing status-column patterns, mixed timezone-aware vs. naive datetimes, plain-int columns that should be foreign keys, FK columns without indexes, and a documented drift between models and production. None of these are stop-the-line; collectively they're the reason every audit going forward needs to start by asking "which version of this column is the real one?"

One genuine footgun was found on the way through: **`backend/alembic/env.py` imports only 17 of the 23 registered model classes.** Running `alembic revision --autogenerate` today would propose dropping six existing prod tables. This is filed as critical and agent-friendly (#21), and called out as a prerequisite on #3 (initial migration).

Nine issues filed, plus comments on #3 and #4. No stop-the-line incidents.

---

## By the numbers

| Metric | Count |
|---|---|
| Model files audited | 23 |
| Migration files audited | 21 |
| Issues filed | 9 |
| — `code-quality:critical` | 1 |
| — `code-quality:moderate` | 5 |
| — `code-quality:nice-to-have` | 3 |
| — `agent-friendly` (orthogonal) | 2 |
| Comments added to existing issues | 2 (#3, #4) |
| Stop-the-line incidents | 0 |

---

## What was audited

### Models (`backend/app/models/`)

All 23 model files read in full: `article`, `article_suggestion`, `attraction`, `booking`, `category`, `contact_submission`, `edu_material`, `edu_research`, `edu_suggestion`, `educator`, `hotel`, `magic_link`, `media`, `media_candidate`, `order`, `pricing_config`, `research`, `tag`, `tour`, `user`, `zone`, `zone_attraction_rate`, `zone_transport_rate`.

Looked for: nullable/NOT NULL hygiene, missing/inconsistent indexes on FKs and frequently-filtered columns, FK constraints and ondelete behavior, audit timestamps, soft-delete patterns, enum conventions, default values, relationship correctness (backref vs back_populates, lazy strategies, orphan rels), naming/type-width consistency.

### Alembic (`backend/alembic/`)

`env.py` and `alembic.ini` read in full. All 21 migrations in `versions/` skimmed for: chain integrity (no branches found), columns referenced by migrations that no longer exist (none found — every column referenced is either still in the schema or was removed by a later migration in the same chain), edited-after-applied evidence (none in commit timestamps), and FK / index hygiene at create-table time.

### Drift signals from Phase 0

The Phase 0 report's data-layer findings (9 orphan tables, 7 orphan enums, 7 columns of drift in 3 surviving tables) were treated as inputs, not findings to re-derive. The `backend/scripts/seed_local_db.py` script was read to confirm the drift direction: prod has columns the models don't define. A direct prod schema pull (`psql` / `pg_dump`) was attempted but denied by the auto mode classifier — exact per-column lists for the drift will need to come from the work on #23 once #21 unblocks autogenerate.

---

## Item-by-item findings

### Issues filed in this session

| # | Title | Severity | Agent-friendly |
|---|---|---|---|
| #21 | Add missing model imports to `alembic/env.py` | critical | yes |
| #22 | Add `ForeignKey` constraints to `Article.research_id`, `Article.approved_by_id`, `MediaCandidate.media_id` | moderate | no (schema) |
| #23 | Models missing prod columns: timestamps on `Taxonomy`/`Category`, reconcile media drift | moderate | no (schema + decisions) |
| #24 | Unify status-column implementation across models (3 competing patterns) | moderate | no (cross-cutting + decisions) |
| #25 | Add indexes on foreign-key columns (Postgres does not auto-index FKs) | moderate | no (schema) |
| #26 | DateTime columns inconsistently use `timezone=True` — pick one convention | moderate | no (schema, cross-cutting) |
| #27 | String column length convention drift (`name_es`, `email`, `Tag.name`) | nice-to-have | no (schema) |
| #28 | Fix walrus-operator typo in `zone_attraction_rate.py` + `backref→back_populates` on `Media.tags` | nice-to-have | yes |
| #29 | Defined Python enums unused as DB constraints; `Educator.email` has redundant index | nice-to-have | no (schema) |

### Comments added

- **#3 (Generate initial alembic migration):** flagged #21 as a hard prerequisite (autogenerate produces wrong output today) and #23 as a sequencing dependency (need to decide each drifted column's fate before stamping a clean baseline).
- **#4 (Drop orphan tables/enums):** suggested splitting the 7-column drift off into #23, since the orphan tables and the drifted columns have different fix paths (drop vs. extend the model), and re-stated the #21 dependency.

### The Pydantic mystery (count drift)

The Phase 0 report's "4 schema files with `class Config` deprecation warnings" was compared against Part A's grep finding of 2 files. Resolution: Phase 0 was counting **occurrences** (4: `category.py` has 2, `article.py` has 1, `core/config.py` has 1), not distinct files. Issue #12's 2-file count for schemas is correct; `core/config.py` is Pydantic **Settings** and migrates via `SettingsConfigDict`, not `ConfigDict` — it's correctly scope-excluded from #12 and should be tracked separately if not already. A clarifying comment was added to #12.

---

## What's filed vs. what's deferred

### Filed (this session)
Nine issues, listed above.

### Deferred / not filed

- **Per-column enumeration of the Phase 0 7-column drift.** The exact column names in prod that the models don't define need a `pg_dump --schema-only` against prod. Captured as part of #23's scope rather than filed separately.
- **Cascade semantics review.** Most FKs default to `NO ACTION` (effectively RESTRICT) and a few (`article_tags`, `media_tags`) explicitly use `CASCADE`. Whether each FK should keep that default or move to `CASCADE` / `SET NULL` is a per-relationship decision. Listed implicitly under #22's scope but not pulled out as its own issue — would have been the 10th finding and is closer to "convention decision" than to "actionable code change." If the unification work in #22/#24/#26 turns out to expose specific cascade bugs, a separate issue can spin out then.
- **TYPE_CHECKING import patterns.** Several models use `from typing import TYPE_CHECKING` and import sibling models inside the guard for relationship type hints. This is correct usage. The `zone_attraction_rate.py` walrus typo (#28) was the only broken instance.

---

## Newly observed — for other audit areas

Items I noticed during this audit that don't belong in Area 1, in the order I expect they'll surface again:

- **Area 2 (Payments/bookings/PayPal):**
  - `Order.subtotal` and `Order.grand_total` are stored separately, but no `discount_total` column exists at the order level — the senior discount lives only on `Booking`. If multiple bookings in an order have different discount totals, reconciliation might be ambiguous.
  - `BookingStatusLog.changed_by` is `String(100)` and stores "admin email or 'system'" — Area 3 (auth/PII) territory. May be relevant when auditing how admin actions are attributed.
  - `Order.payment_method` is plain `String(20)` (also covered by #24) but it sits squarely in the payments flow, so worth double-checking that the service-layer code doesn't insert unexpected values.
  - The `EduMaterial` model has **two** optional FKs — `research_id` to `edu_research`, `blog_research_id` to `research` — modelling a discriminated union without a discriminator column. The `suggestion_title` property has a fallback chain that could mask a row with neither relationship populated. Closer to Area 4 (services / edu pipeline) than to a data-layer finding.

- **Area 3 (Auth/educator gate):**
  - `MagicLink` rows have no soft delete or rotation — once a magic link is created it persists indefinitely. There's a `used_at` and an `expires_at`, but no cleanup job is implied by the model. Worth checking whether expired/used links are pruned anywhere in services.
  - `Educator.confirm_token` and `Educator.verify_code` are stored in plaintext in the DB. Defensible (they're short-lived single-use tokens) but worth a security-review pass in Area 3.

- **Area 4 (Services / pipelines):**
  - The fact that `outline_status` is a plain string (#24) suggests the article-outline state machine is enforced in service-layer code, not at the DB. If that enforcement has gaps, the column could hold stale values.
  - `EduMaterial.material_type` is a plain `String(20)` with no enum — there's likely an implicit set of expected values in the edu-pipeline services. Worth checking that area finds the canonical list and documents it.

- **Area 5 (Frontend public):**
  - The `is_active` flag on `Tour`, `Zone`, `Hotel`, `Attraction`, `AdminEmail` is consistently applied at the DB level. Public-API endpoints should be filtering on this; worth confirming during Area 5.

- **Area 6 (Frontend admin):**
  - Admin grids (per project memory: AG Grid) likely display `created_at` / `updated_at` columns. The lack of these on `Taxonomy` and `Category` (#23) probably means the admin UI either fakes them or hides the column for those tables. Worth a quick check.

---

## What surprised me

1. **The migration chain is genuinely linear.** I expected at least one branch (the project is solo-developed and has gone through multiple feature pivots). No branches, no divergent heads. Whoever's managing alembic has been careful.
2. **No soft-delete pattern anywhere.** `is_active` is used for "publishable/visible" but never for tombstoned records. Either the admin CMS hard-deletes everything (likely — there's no `deleted_at` and no UI mention of restore), or the model genuinely doesn't need it yet. Worth a note for Area 6.
3. **The 7-column drift is concentrated.** Phase 0's count of 7 sounded large; in practice it's three tables (taxonomies, categories, media) at roughly two columns each. The pattern (timestamps on entity tables, Instagram residue on media) is consistent and the fix path is clean once the prod schema is pulled.
4. **`if TYPE_CHECKING := False:`** is a real bug that's been sitting in the repo. It "works" only because string-based relationship targets sidestep the import, and ruff doesn't flag the walrus-as-conditional pattern. The kind of thing that would be caught by mypy if mypy were configured — currently it isn't.
5. **The Pydantic count drift was occurrence vs. file confusion**, not an actual schema-file cleanup between Phase 0 and Part A. The earlier audit was right (2 schema files); Phase 0 was counting deprecation warnings, not distinct files. Useful calibration for future "did N files drift to M?" questions: confirm whether the count was files, occurrences, or warnings before assuming intermediate work happened.

---

## Process notes for the next area

- **Batch sizes of 4 worked.** Two batches of 4 (#21–#24, #25–#28) plus one bundled-then-split issue (#29) was the right cognitive grain for getting approval and filing.
- **Prod schema queries are gated** by the auto mode classifier. The `.env.prod-readonly` source pattern works in principle, but `psql` against the DO managed cluster was denied. Area 2 (payments) may need a different approach — either explicit user approval up front, or using the `database-ops` skill which is presumably whitelisted for this purpose.
- **Reading all 23 model files in one pass was the right call.** Several findings (the three status-pattern groups, the `name_es` width drift, the timezone inconsistency) only become visible by comparing across files. Reading domain-by-domain would have missed them.
- **The Phase 0 report is a load-bearing reference.** Pulling its specific hints (the 7-column drift count, the orphan-table list, the seed script existence) made this audit faster than re-deriving the same information from scratch. Next areas should do the same.
