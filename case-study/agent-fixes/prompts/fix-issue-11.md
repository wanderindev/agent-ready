# Fix brief — issue #11: Fix auto-fixable ruff errors in backend/app/ and flip CI ruff step to blocking

## Identification

You are an autonomous agent resolving issue #11 in the Panama In Context (PIC) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against current source at brief-writing time (2026-05-28). If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

Backend tooling runs inside Docker on the operator's machine, but **your worktree is a plain git checkout — you do not have the docker-compose stack.** Run ruff directly from `backend/`:

- The repo pins ruff via `backend/requirements.txt`. If `ruff` is not already on PATH, install it: `pip install ruff` (match the version in `backend/requirements.txt` if you can; any recent 0.x ruff produces the same fixes for this issue).
- All ruff commands run from the `backend/` directory and target `app` (mirrors CI, which sets `working-directory: backend` and runs `ruff check app`).
- The ruff config lives in `backend/pyproject.toml` (`[tool.ruff]`, `line-length = 100`, `select = ["E","F","I","UP"]`, `ignore = ["E501"]`). **Do not change the ruff config** (see OUT of scope).
- You likely cannot run the pytest suite (it needs testcontainers + the docker stack). That's expected. Do NOT block on running pytest. The change is mechanical lint/format + a CI YAML edit; rely on the self-review checklist and CI to validate. State clearly in the PR description that you did not run the test suite locally and that CI must confirm it.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

The issue body's numbers have drifted — intervening cleanup shrank the error set. **The verified current state (run yourself to confirm):**

- `ruff check app` reports **73 errors** total (issue said 83).
- `ruff check app --fix` (the safe-fix subset; NO `--unsafe-fixes`) resolves **71** of them, leaving exactly **2**:
  1. `F841` — local variable `magic_link` assigned but never used, at `app/api/dashboard.py:1591` (`magic_link = validate_admin_token(token, db)` — the call is for its validation side effect; the return is unused).
  2. `E402` — module-level import not at top of file, at `app/schemas/category.py:39` (`from app.schemas.article import ArticleBase`). This is an **intentional** late import to avoid a circular import — see the comment on `category.py:38`.
- The issue's "~10 non-auto-fixable" is stale; the real count is **2**. State the corrected count in your PR.

### Steps (do them in this order)

1. From `backend/`: `ruff check app --fix` — applies the 71 safe fixes (UP045 pep604 annotations, I001 import sorting, F401 unused imports, UP042 str-enum).
2. From `backend/`: `ruff format app` — applies formatting. This reformats a large number of files (~66); that is expected and correct (the codebase was never `ruff format`ted). The large diff is fine.
3. Suppress the 2 remaining errors with surgical line-level `# noqa` (this DEFERS them for human review — it is NOT a hand-fix of the underlying code, which the issue forbids):
   - `app/schemas/category.py:39` → append `  # noqa: E402` to the import line. (Intentional late import; this is the standard, defensible annotation.)
   - `app/api/dashboard.py:1591` → append `  # noqa: F841` to the assignment line. (Deferred: whether the `validate_admin_token` return should be used is a judgment call left for the follow-up issue.)
   - Use line-level `# noqa`, NOT `per-file-ignores` in `pyproject.toml` — a file-level `F841` ignore on the 1600-line `dashboard.py` would hide future real unused-variable bugs.
4. From `backend/`: re-run `ruff check app` — it MUST now exit 0 (the 2 noqa'd errors are suppressed). Also run `ruff format --check app` — it MUST report no changes (if it wants to reformat the noqa lines, run `ruff format app` again and re-verify). Iterate until both are clean.
5. Edit `.github/workflows/ci.yml` to make the ruff step blocking. Current lines 54-58:
   ```yaml
         # Non-blocking until the existing 83 ruff errors are cleaned up in Phase 1.
         # Flip `continue-on-error` to `false` once `ruff check app` is green.
         - name: Ruff (informational)
           continue-on-error: true
           run: ruff check app
   ```
   Replace with:
   ```yaml
         - name: Ruff
           run: ruff check app
   ```
   (Remove the two now-stale comment lines, drop "(informational)" from the step name, and remove the `continue-on-error: true` line entirely — the default is blocking.)

## Scope

### IN scope
- `backend/app/**` — the files changed by `ruff check app --fix` (~71 fixes across the tree) and `ruff format app` (~66 files reformatted).
- `backend/app/schemas/category.py:39` — add `# noqa: E402`.
- `backend/app/api/dashboard.py:1591` — add `# noqa: F841`.
- `.github/workflows/ci.yml` — remove `continue-on-error: true` and the stale comment on the ruff step (lines 54-58).

### OUT of scope (do NOT touch)
- **`backend/pyproject.toml`** — do NOT change the ruff `select`/`ignore`/`per-file-ignores` or any other config. The deferral is via line-level `# noqa`, not config.
- **Do NOT hand-fix the 2 deferred errors.** Do not remove the `magic_link =` assignment; do not move the `ArticleBase` import. Suppress with `# noqa` only.
- **Do NOT use `--unsafe-fixes`.** Only the safe `--fix` subset.
- **Do NOT add a `ruff format --check` step to CI.** The issue only asks to flip the existing `ruff check` step to blocking. Adding format enforcement is a separate decision.
- `backend/tests/**`, `backend/alembic/**` — not checked by CI's `ruff check app`; leave untouched.
- `frontend/`, `docker/`, `scripts/`, `docs/` — untouched.
- **`docs/agent-fixes/**`** — do NOT create or edit any file here (no INDEX, no outcomes log, no brief file). The orchestrator owns those on `main`; you are on a fix branch.
- **Do NOT create a GitHub issue** for the deferred errors. Instead, put a ready-to-file writeup in your PR description (see below); the operator files it.

## Default rules for likely ambiguities

- **If `ruff check app --fix` leaves more or fewer than 2 errors**, or leaves errors other than the `F841`/`E402` named above: this brief's count is wrong (shape #2). Apply `# noqa` to whatever non-auto-fixable errors actually remain (one per line, with the correct rule code), list each in the PR, and flag the drift. Do NOT hand-fix any of them and do NOT use `--unsafe-fixes`.
- **If a noqa line exceeds 100 chars**: `E501` is in the `ignore` list, so it won't fail `ruff check`. Both target lines are well under 100 even with the noqa, so this should not arise.
- **ruff version**: any recent ruff 0.x reproduces these fixes. If your installed ruff produces a materially different fix set, note the version in the PR and proceed with whatever its safe `--fix` produces, applying `# noqa` to the residue.
- **Branch is clean**: you are branched from `main`; the working tree should have no other changes. Stage only the in-scope files.

## Failure-mode escape hatch

If the primary path is blocked — e.g. `ruff check app` will not exit 0 after the `--fix` + `# noqa` even though you've suppressed every residual error, or the `ci.yml` edit can't be made cleanly — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X" comment is a good outcome; a non-draft PR that silently worked around the block is worse.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] `ruff check app` (from `backend/`) exits 0.
- [ ] `ruff format --check app` (from `backend/`) reports no changes.
- [ ] Exactly the 2 expected residual errors were suppressed via line-level `# noqa` (`E402` on `category.py:39`, `F841` on `dashboard.py:1591`), with the correct rule code on each. (If the residual set differed, the drift is documented in the PR.)
- [ ] `backend/pyproject.toml` is **unchanged**.
- [ ] The 2 deferred errors' underlying code was NOT hand-fixed (assignment and import still present, only annotated).
- [ ] `.github/workflows/ci.yml`: the ruff step no longer has `continue-on-error`, the stale "83 errors / Phase 1" comment is gone, and the step still runs `ruff check app`.
- [ ] No CI `ruff format --check` step was added.
- [ ] Only in-scope files are modified (`backend/app/**` + `.github/workflows/ci.yml`); nothing under `docs/`, `frontend/`, `tests/`, `alembic/`, or `pyproject.toml`.
- [ ] PR description includes the production-touch line, the corrected error counts, the test-suite-not-run-locally note, and the deferred-errors follow-up writeup.

## PR shape

- **Branch**: `fix/issue-11-ruff-autofix-blocking-gate`
- **Title**: `fix(#11): apply auto-fixable ruff + format, flip CI ruff step to blocking`
- **Body must include**:
  - One-line summary.
  - **"Production touch: no — verified by:"** line (this is a lint/format + CI-YAML change; no prod DB, no deploy, no auth/payment/PII code path altered — the `dashboard.py` and `category.py` edits are comment-only `# noqa` annotations).
  - Corrected counts: "Issue said 83 errors / 73 auto-fixable / ~10 remaining; current source had 73 / 71 fixed by safe `--fix` / 2 remaining."
  - A note that the pytest suite was not run locally (no docker stack in the worktree) and CI must confirm it (171 tests expected green).
  - The self-review checklist with each item marked.
  - A **"Deferred for follow-up issue"** section, copy-paste ready, listing the 2 errors for the operator to file:
    - `F841` — `app/api/dashboard.py:1591`: `magic_link = validate_admin_token(token, db)` assigns an unused return. Needs human review: should the return value be used (latent bug), or should the assignment be dropped? Suppressed with `# noqa: F841` for now.
    - `E402` — `app/schemas/category.py:39`: intentional late import to break a circular import. Likely "wontfix / keep the noqa", but a human should confirm. Suppressed with `# noqa: E402`.
  - A test plan.
  - `Closes #11`.
  - The `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped (counts of files reformatted / fixed), and any flags you surfaced (especially any brief-vs-source drift in the residual error set). Do NOT edit `docs/agent-fixes/**` — the orchestrator logs the outcome row on `main` after you report.

## Begin by

1. Ensure `ruff` is available (`ruff --version`; `pip install ruff` if missing).
2. Read the issue (`gh issue view 11`) and the two named sites (`app/api/dashboard.py:1591`, `app/schemas/category.py:39`); confirm the verified facts still hold and that `ruff check app --fix` leaves exactly the 2 expected errors.
3. Make the change, staying strictly within IN scope (fix → format → noqa → ci.yml edit).
4. Run `ruff check app` (must exit 0) and `ruff format --check app` (must be clean); iterate.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Report back and STOP.
