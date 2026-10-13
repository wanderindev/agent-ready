# Fix brief — issue #12: [Quality] Migrate Pydantic v1 class Config to ConfigDict in schemas (eliminate deprecation warnings)

## Identification

You are an autonomous agent resolving issue #12 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a backend Python change. The fix itself is a pure source edit (no runtime). You only need lint + tests to verify.

**Lint** (no container needed if ruff is on PATH; otherwise via docker-compose):
- `docker-compose exec backend ruff check /app/schemas/article.py /app/schemas/category.py`

**Tests** use `testcontainers` (spins up a real `postgres:17-alpine` container — needs the docker socket; see `backend/tests/conftest.py`). Two ways to run:

- **Preferred (native, simplest):** the suite needs only a testcontainer + Python deps, no live API. From the worktree's `backend/` dir, install requirements into a venv and run `pytest` natively against the testcontainer — no docker-compose needed.
- **If you use docker-compose instead:** the operator's main checkout likely has the dev stack running. A naïve `docker-compose up -d` from this worktree will hit port conflicts (5432/8000) and/or attach to the operator's containers (whose code volume is the main checkout, NOT your worktree, so your edits won't be tested). If you go this route: pass `-p agent-issue-12` on every docker-compose call, write a temp `docker-compose.agent.yml` with alternate host ports and `user: "0:0"` on the backend service, reference both files via `-f docker-compose.yml -f docker-compose.agent.yml`, and `rm` the override file before opening the PR (do NOT commit it).

Acceptance commands (from the issue):
- `pytest -W error::DeprecationWarning -k "article or category"` passes (no Pydantic deprecation warnings from the touched files).
- Full `pytest` exits 0.
- `ruff check` on the two files exits 0.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Migrate the deprecated Pydantic v1 `class Config:` blocks to the v2 `model_config = ConfigDict(...)` form in two schema files. **The issue body overstates the work — the source has already been partially migrated. Here is exactly what is and isn't present (verified this session):**

- There is **NO `orm_mode`** anywhere in either file. Both `class Config` blocks already use `from_attributes = True`. So the only transformation is the *block form* (`class Config:` → `model_config = ConfigDict(...)`), NOT the attribute rename.
- There is **NO `@validator`** in either file. Do not add `field_validator`. (`category.py` has a `@property def slug` at lines 22-24 — that is a plain Python property, not a Pydantic validator. Leave it exactly as-is.)
- There is **NO `allow_population_by_field_name`** anywhere. Moot.

**Canonical pattern to mirror:** `backend/app/schemas/article.py:12` already does it correctly:
```python
model_config = ConfigDict(from_attributes=True)
```
(Same form appears in `order.py:52`, `tour.py:29`, `zone.py:15`, `edu.py:20`, etc.)

**The exact 3 sites to change:**

1. `backend/app/schemas/article.py`, `ArticleBase` (lines 22-23):
   - Replace
     ```python
         class Config:
             from_attributes = True
     ```
     with
     ```python
         model_config = ConfigDict(from_attributes=True)
     ```
   - Import is already present (`from pydantic import BaseModel, ConfigDict` at line 3) — no import change needed in this file.

2. `backend/app/schemas/category.py`, `TaxonomyBase` (lines 11-12) and `CategoryBase` (lines 26-27): replace each
   ```python
       class Config:
           from_attributes = True
   ```
   with
   ```python
       model_config = ConfigDict(from_attributes=True)
   ```
   - Update the import at line 1 from `from pydantic import BaseModel` to `from pydantic import BaseModel, ConfigDict`.

After the change there must be ZERO `class Config` blocks remaining in either file.

## Scope

### IN scope
- `backend/app/schemas/article.py` — 1 `Config` block (`ArticleBase`, line 22).
- `backend/app/schemas/category.py` — 2 `Config` blocks (`TaxonomyBase` line 11, `CategoryBase` line 26) + add `ConfigDict` to the line-1 import.

### OUT of scope (do NOT touch)
- `backend/app/core/config.py:59` — this `class Config` lives on a `pydantic_settings.BaseSettings` subclass and carries `env_file` / `env_file_encoding`. Its v2 equivalent is `SettingsConfig`/`model_config = SettingsConfigDict(...)`, which has different semantics from `ConfigDict`. The issue explicitly excludes it. Do NOT migrate it.
- The `@property def slug` in `category.py` (lines 22-24) — leave verbatim.
- The `model_rebuild()` calls, the circular-import `noqa: E402` import in `category.py` (line 38), and the `ArticleSeriesInfo.model_rebuild()` in `article.py` — leave verbatim.
- Every other schema file in `backend/app/schemas/` — already on `model_config`. Do not touch.
- No model/DB/migration/auth/payment changes of any kind.

## Default rules for likely ambiguities

- **Import line for ConfigDict:** in `category.py`, change line 1 to exactly `from pydantic import BaseModel, ConfigDict` (alphabetical order, matching the project's existing style e.g. `tour.py:6`). In `article.py` the import already exists — do not duplicate it.
- **Form of model_config:** always `model_config = ConfigDict(from_attributes=True)` (call form), matching `article.py:12`. Do NOT use the bare-dict form `model_config = {"from_attributes": True}` even though it appears in `media_candidate.py`/`public_media.py` — the call form is the dominant canonical pattern and what `TagItem` in the same file already uses.
- **Placement within each class:** put `model_config` where the `class Config` block was (preserving the surrounding blank lines / field order already present). For `CategoryBase`, the `class Config` is below the `@property slug` — keep it in that position.
- **No `@validator` / `field_validator` work** — none exists; do not invent any.
- **`config.py`** — confirmed out; do not migrate.

## Failure-mode escape hatch

If the primary path is blocked (e.g. tests can't run because the docker socket is unreachable from the worktree), STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Note that the source edit itself is trivial and low-risk; the most likely blocker is the test-environment plumbing, not the change.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only `backend/app/schemas/article.py` and `backend/app/schemas/category.py` are modified (`git diff --name-only` shows exactly these two).
- [ ] `grep -rn "class Config" backend/app/schemas/` returns ZERO results.
- [ ] `config.py` (`backend/app/core/config.py`) is NOT in the diff.
- [ ] `category.py` line 1 import now includes `ConfigDict`; the `@property def slug` is unchanged.
- [ ] `ruff check` on both files exits 0 (no new issues vs main baseline).
- [ ] `pytest -W error::DeprecationWarning -k "article or category"` passes.
- [ ] Full `pytest` exits 0.
- [ ] PR description complete, including the production-touch line.

## PR shape

- **Branch**: `fix/issue-12-pydantic-configdict`
- **Title**: `fix(#12): migrate Pydantic class Config to ConfigDict in article/category schemas`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: source-only edit to two Pydantic schema files; no DB/auth/payment/env/deploy paths touched"** line; the self-review checklist with each item marked; a test plan; `Closes #12`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- In the body, note the issue-body-vs-source drift you encountered: no `orm_mode`, no `@validator`, no `allow_population_by_field_name` existed — only the `class Config` → `model_config` block form remained (3 blocks across 2 files).
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Read the issue (`gh issue view 12`) and open `backend/app/schemas/article.py` and `backend/app/schemas/category.py`; confirm the 3 `class Config` blocks (article.py:22, category.py:11, category.py:26) and that none use `orm_mode`/`@validator`.
2. Make the change, staying strictly within IN scope.
3. Run ruff + pytest as named in operational notes; iterate until clean.
4. Self-review checklist.
5. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
6. Append the outcomes-log row.
7. Report back and STOP.
