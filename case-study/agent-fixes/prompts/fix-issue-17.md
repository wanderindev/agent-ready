# Fix brief — issue #17: [Quality] Bump GitHub Actions from Node 20 to Node 22 (deprecation cutoff June 2026)

## Identification

You are an autonomous agent resolving issue #17 in the panama-in-context codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

This is a one-line edit to a GitHub Actions workflow file. You do NOT need to run npm, build the frontend, or symlink node_modules — there is nothing to build or lint locally for this change. The only "test" is that the YAML stays valid and CI runs green on the resulting PR (which happens on GitHub, not in your worktree). Do not start docker-compose or any dev stack.

## When this brief and the source disagree — the four shapes

Recognize which shape applies and respond accordingly:

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

Bump the Node version used by the frontend CI job from 20 to 22.

There is **exactly one** occurrence in **exactly one** workflow file (verified by `grep -rn "node-version" .github/workflows/`):

- `.github/workflows/ci.yml`, line 83:
  ```yaml
        - uses: actions/setup-node@v4
          with:
            node-version: '20'        # ← change to '22'
            cache: npm
            cache-dependency-path: frontend/package-lock.json
  ```

The change: `node-version: '20'` → `node-version: '22'`. That is the entire fix.

**Drift corrections from the issue body (source wins):**
- The issue says "All occurrences" and "any other workflow files … that use Node." There is only ONE workflow file (`ci.yml`) and ONE `node-version` site. Do not search for or invent additional sites; there are none.
- The issue warns the "cache key includes Node version" and must still work. It does NOT. The npm cache here is keyed off the lockfile hash (`cache-dependency-path: frontend/package-lock.json`), not the Node version. There is no Node-version-derived cache key. Leave the `cache:` and `cache-dependency-path:` lines exactly as they are.
- There is no `engines.node` field in `frontend/package.json` and no `.nvmrc`. Nothing else pins Node 20. Do not add one.

## Scope

### IN scope
- `.github/workflows/ci.yml` — change `node-version: '20'` to `node-version: '22'` on line 83 (only this one line).

### OUT of scope (do NOT touch)
- The `actions/setup-node@v4`, `actions/checkout@v4`, `actions/setup-python@v5` pins — do NOT bump action major versions. (The host-runtime Node deprecation is handled by the action major version, which is a separate concern; if you notice a GitHub deprecation *warning* about an action's host runtime, note it as a follow-up in the PR description, do NOT act on it.)
- The `cache:` / `cache-dependency-path:` lines (84-85) — leave unchanged.
- The backend job, secrets-scan job, Python version, gitleaks version — all unrelated.
- `frontend/package.json`, lockfiles, `.nvmrc` (none exists) — do NOT create or modify.
- Any application/source code — none is involved.

## Default rules for likely ambiguities

- **Quoting:** keep the single quotes — write `node-version: '22'` (string), matching the existing `'20'` and the `python-version: '3.12'` convention in the same file. Do NOT write `node-version: 22` unquoted.
- **Exact target:** 22 (the issue specifies Node 22). Do not pick 20-LTS-successor by inference — it is literally 22.
- **No other edits:** resist the urge to also bump action majors or "tidy" adjacent YAML. One line changes.

## Failure-mode escape hatch

This change is structurally trivial; a block is not anticipated. If somehow the line is not where this brief says (e.g. the file was refactored since brief-writing), follow the source: change the single `node-version` value under the frontend `setup-node` step to `'22'`, and note the location drift in the PR description.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only `.github/workflows/ci.yml` is modified (verify with `git diff --name-only`).
- [ ] The diff is exactly one line: `node-version: '20'` → `node-version: '22'`.
- [ ] `cache:`, `cache-dependency-path:`, and the `setup-node@v4` action pin are unchanged.
- [ ] The YAML is still valid (the change is inside an existing quoted scalar; indentation untouched).
- [ ] No `engines`/`.nvmrc`/package.json changes were introduced.
- [ ] PR description includes the "Production touch: no" line.

## PR shape

- **Branch**: `fix/issue-17-node-22-ci-bump`
- **Title**: `fix(#17): bump CI Node from 20 to 22`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by: CI-only change; deployed frontend runs in users' browsers, unaffected by build-time Node"** line; the self-review checklist with each item marked; a test plan ("CI runs the frontend job on Node 22 — `npm ci` + `npm run build` must pass green; no Node-version deprecation warning in logs"); `Closes #17`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges. The `gh pr merge*` deny rule blocks you anyway.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to docs/agent-fixes/agent-friendly-outcomes.md with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Confirm you are in the worktree on a fresh branch off `main` (`git status`).
2. Read the issue (`gh issue view 17`) and open `.github/workflows/ci.yml`; confirm `node-version: '20'` is still at the frontend `setup-node` step (around line 83).
3. Make the one-line change: `'20'` → `'22'`. Stay strictly within IN scope.
4. There is no local build/lint/test for this change — verify the YAML diff visually instead (`git diff`).
5. Run the self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
