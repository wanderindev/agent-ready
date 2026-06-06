# Fix brief — issue #103: research.py and edu_research.py duplicate _generate_references_section and validate_*_document

## Identification

You are an autonomous agent resolving issue #103 in the Panama In Context (PIC) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

This is a **pure mechanical refactor**: extract duplicated logic into a new shared module with **zero behavior change**. The output of every code path must be byte-for-byte equivalent to today's.

## Operational notes

- **Backend Python change. Lint runs on the host — no docker needed.** `ruff` is on PATH (`ruff 0.11.2`). The config is `backend/pyproject.toml` (line-length 100, target py311, rules E/F/I/UP, E501 ignored). Run from the worktree root:
  - `ruff check backend/`
  - `ruff format --check backend/`
- **Syntax/compile check (host):** `python3 -m py_compile backend/app/services/research.py backend/app/services/edu_research.py backend/app/services/research_common.py`
- **Do NOT rely on docker or pytest.** The docker backend container mounts the *main* checkout, not your worktree, so it will not see your changes. There are no tests covering these functions (verified). The lint + compile + the explicit grep checks below are your gates.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Two backend service modules contain duplicated research-document-validation logic:

- `backend/app/services/research.py` (blog): `validate_research_document` (lines 84-198) and `_generate_references_section` (lines 201-232).
- `backend/app/services/edu_research.py` (edu): `validate_edu_research_document` (lines 94-197) and `_generate_references_section` (lines 200-231).

Verified at brief time:
- The two `_generate_references_section` definitions are **byte-identical** (confirmed with `diff` — empty output).
- The two validate functions are near-identical. The **only** meaningful difference is the parameter: `research` takes `suggestion: ArticleSuggestion`, `edu` takes `suggestion: EduSuggestion`. In both, the *only* attribute accessed on `suggestion` is `.sub_topics`. The references regex, the word-count gate (`< 4000`), the Haiku sub-topic-coverage call, the `except (json.JSONDecodeError, IndexError)` guard, the markdown-fence stripping, the `subtopic_ok = subtopics_found >= 2` threshold, the auto-fix call, and the returned dict shape are all identical. Docstring/comment wording differs trivially (ignore — write one clean docstring).
- `extract_suggestion_title` and `HAIKU_MODEL` are already shared: `edu_research.py:10` does `from app.services.research import HAIKU_MODEL, extract_suggestion_title`.

**Desired end state (the extraction):**

Create a new leaf module `backend/app/services/research_common.py` containing:
- `HAIKU_MODEL = "claude-haiku-4-5-20251001"` (the constant moves here; see default rule R1).
- A `_get_client()` helper (same body as the existing ones — see R2).
- `_generate_references_section(client, content) -> str | None` (move verbatim; it becomes internal to this module).
- `validate_research_document(content: str, sub_topics: list[str] | None) -> dict` — the **parameterized** core. Identical body to today's, except it takes `sub_topics` directly instead of a typed suggestion. The first line of its body normalizes: `sub_topics = sub_topics or []`.

Then rewire the two service modules to **thin wrappers** that preserve their existing public signatures (so the two caller files stay untouched — see Scope):

- `backend/app/services/research.py`:
  ```python
  from app.services import research_common

  def validate_research_document(content: str, suggestion: ArticleSuggestion) -> dict:
      return research_common.validate_research_document(content, suggestion.sub_topics or [])
  ```
  Delete the old `validate_research_document` body, the `_generate_references_section` definition, and the `HAIKU_MODEL` constant (now unused here — see R1). Keep `generate_research_prompt`, `extract_suggestion_title`, and `_get_client` (still used by `generate_research_prompt`). Remove now-unused imports (e.g. `json`; `re` is still used by `extract_suggestion_title`, keep it).

- `backend/app/services/edu_research.py`:
  ```python
  from app.services import research_common

  def validate_edu_research_document(content: str, suggestion: EduSuggestion) -> dict:
      return research_common.validate_research_document(content, suggestion.sub_topics or [])
  ```
  Delete the old `validate_edu_research_document` body and the `_generate_references_section` definition. Update line 10: drop `HAIKU_MODEL` from the import (no longer used here), keep `extract_suggestion_title` (it is re-exported in `__all__` and imported by `edu.py`). Keep `generate_edu_research_prompt`, the `__all__` list, and `_get_client` (still used by `generate_edu_research_prompt`). Remove now-unused imports (`json` and `re` both become unused here — verify with ruff and remove).

**Dependency direction (no cycle — verified):** `research_common` imports only `app.core.config` + stdlib + `anthropic` (no `research`, no `edu_research`). `research` imports `research_common`. `edu_research` imports both `research_common` and `research` (the latter only for `extract_suggestion_title`). This is acyclic.

## Scope

### IN scope
- **Create** `backend/app/services/research_common.py`.
- **Edit** `backend/app/services/research.py` (remove dup'd logic, add wrapper + import, drop `HAIKU_MODEL` + unused imports).
- **Edit** `backend/app/services/edu_research.py` (remove dup'd logic, add wrapper + import, fix line-10 import, drop unused imports).

### OUT of scope (do NOT touch)
- `backend/app/api/dashboard.py` — caller at line 340 stays as-is (it imports the wrapper from `research.py`, whose signature is unchanged).
- `backend/app/api/edu.py` — caller at line 371 stays as-is (imports the wrapper from `edu_research.py`, signature unchanged).
- `generate_research_prompt` / `generate_edu_research_prompt` — leave untouched.
- The `HAIKU_MODEL` constants in `article_generation.py` and `research_summary.py`, and the `_get_client` copies elsewhere — **do NOT** attempt a project-wide dedup of these. That is issue #76's territory, explicitly out of scope here.
- Any change to behavior, thresholds, prompt strings, or the returned dict shape.

## Default rules for likely ambiguities

- **R1 — Where `HAIKU_MODEL` lives:** Define it in `research_common.py`. Remove the definition from `research.py` (after the move, `research.py` no longer references it — `generate_research_prompt` uses the hardcoded `"claude-sonnet-4-6"`). Verified: the only external importer of `research.HAIKU_MODEL` was `edu_research.py:10`, which you are editing. Do NOT re-export it from `research.py` for backward compat — just delete it and fix the one import.
- **R2 — `_get_client` in the new module:** Give `research_common.py` its own `_get_client()` with the same 2-line body as the existing ones. Do NOT try to share/dedup `_get_client` across modules (out of scope, R per OUT list). `research.py` and `edu_research.py` keep their own `_get_client` (still used by their `generate_*_prompt` functions).
- **R3 — Calling convention from the wrappers:** Use `from app.services import research_common` and call `research_common.validate_research_document(...)` (qualified). Do NOT use `from app.services.research_common import validate_research_document` — that would shadow the same-named wrapper in `research.py`'s namespace. Qualified access avoids the name clash cleanly.
- **R4 — Pass `suggestion.sub_topics or []`** from each wrapper. (The common function also normalizes `sub_topics = sub_topics or []` defensively; both is fine and matches the original's internal `suggestion.sub_topics or []`.)
- **R5 — Docstring:** Write one clean docstring for the common `validate_research_document`. Keep it short. The wrappers need no docstring (one-liners).
- **R6 — Whitespace:** The original `research.py` validate body has scattered blank lines (e.g. double-blanks at 95-96, 116). Don't reproduce those; let `ruff format` normalize. Match the formatter, not the original spacing.

## Failure-mode escape hatch

If the primary path is blocked — e.g. a circular-import error you can't resolve within scope, or a caller you didn't expect breaks — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. A draft PR with an honest "blocked on X" comment is a good outcome; a non-draft PR that silently worked around a block is a worse one. (Based on verification, no block is expected.)

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only the three in-scope files are modified (new `research_common.py` + edited `research.py` + edited `edu_research.py`). `git diff --stat` shows nothing else.
- [ ] `dashboard.py` and `edu.py` are unmodified (`git status` confirms).
- [ ] `ruff check backend/` is clean (no new issues vs main — in particular no F401 unused-import, no F811/F821).
- [ ] `ruff format --check backend/` passes for the touched files.
- [ ] `python3 -m py_compile` succeeds for all three files.
- [ ] **No dangling references to moved symbols:** `grep -rn "_generate_references_section" backend/app/services/research.py backend/app/services/edu_research.py` returns nothing (it now lives only in `research_common.py`). `grep -rn "HAIKU_MODEL" backend/app/services/research.py` returns nothing.
- [ ] The common `validate_research_document` body is logically identical to the originals: word-count gate `< 4000`, the same references regex, the same Haiku call (model, max_tokens=256, prompt text), the same fence-stripping, the same `except (json.JSONDecodeError, IndexError)`, `subtopics_found >= 2`, the same auto-fix branch, and the same returned dict shape (including the nested `subtopic_coverage` dict).
- [ ] No behavior, threshold, or prompt-string changes anywhere.
- [ ] Production touch: none.

## PR shape

- **Branch**: `fix/issue-103-extract-research-common`
- **Title**: `fix(#103): extract shared research-validation logic into research_common`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: isolated backend service-layer refactor, no prod DB/deploy/auth/PII, no behavior change"** line; the self-review checklist with each item marked; a test plan (note: no test coverage exists for these functions — the guarantee is lint-clean + compile + byte-equivalent logic; mention you eyeballed the moved body against the originals); `Closes #103`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` (under "## The log") with: Issue # = 103, Filed agent-friendly? = yes, Filed severity = nice-to-have, Track = backend, Brief reviewed? = yes, PR # = <your PR>, Outcome = not-yet-attempted, Reviewer interventions = (blank), Notes = one line on what was easier/harder than expected and any disagreement shape that fired.

## Begin by

1. Read the issue (`gh issue view 103`) and the three files named above; confirm the verified facts still hold (especially that the two `_generate_references_section` bodies are still identical and the validate bodies still differ only by the typed param).
2. Create `research_common.py`; move `_generate_references_section`, add the parameterized `validate_research_document`, `HAIKU_MODEL`, and `_get_client`.
3. Rewire `research.py` and `edu_research.py` to thin wrappers per R1-R6; remove dead code and now-unused imports.
4. Run `ruff check backend/`, `ruff format` (or `--check`), and `python3 -m py_compile` on the three files; iterate until clean.
5. Run the grep checks in the self-review list.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Report back and STOP.
