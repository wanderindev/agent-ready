# Phase 2 — Session 06: Frontend autonomous-agent experiment, F-1 — issue #117

## Identification

You are the **autonomous agent** running F-1 of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. You have been launched from the orchestrator's main session via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run. You finish; the orchestrator reviews your PR.

**This is the first `Agent attempted: yes` row the methodology pilot will collect.** Five prior Phase 2 fix sessions (#134, #137, #143, #144, and the small docs PRs) were all `pair` mode — operator-in-the-loop, surface-for-approval, multi-phase. Session 06 / F-1 is different: you run to completion without surfacing anything; the operator sees only the PR you open.

You are running in a worktree; the project source-of-truth is the repo as it exists in this worktree. Do not assume any conversational context. Everything you need is in files this brief points at.

## What this experiment is testing

The Phase 1 synthesis §4 / §10 questions: can a well-briefed agent execute an `agent-friendly:yes` issue unattended, end-to-end, with a clean-merge outcome and zero reviewer interventions? This single run is one data point — not a verdict — but it is the methodology's first data point of its kind, so the framing matters.

If you get stuck (ambiguity beyond what this brief specifies, a test failure you can't diagnose, scope that grows beyond #117), **open a draft PR with a comment describing exactly where autonomy ran out**, and stop. A draft PR with an honest "needs human input on X" comment is a *good* outcome — it's actionable methodology data. A non-draft PR that quietly worked around an ambiguity is a *worse* outcome.

## Read these first, in order

Read each one fully before writing any code. Don't skim.

1. **Issue #117** — run `gh issue view 117`. The full body. It is the spec.
2. **`docs/pilot/phase-1-area-6-report.md`** — the audit that surfaced #117. Specifically the section *"#117 — Inline admin actions swallow failures to `console.error`"*, and the surrounding "partial-correction debt" framing.
3. **`frontend/src/pages/admin/AdminArticles.jsx`** (full file) — contains the **target pattern**: `handleTranslate` and `handleSeriesSections` use `showToast({type: 'error', ...})` + `dismissToast(toastId)` (the hook is `useToast`, surfacing `showToast` and `dismissToast`). This is the pattern you mirror.
4. **`frontend/src/components/admin/Toast.jsx`** — the `useToast` hook's API. Confirm `showToast`, `dismissToast` signatures.
5. **`docs/pilot/agent-friendly-criteria.md`** — the criteria #117 was filed against. Specifically the "borderline" worked example (the ruff sweep across 30+ files): *"cognitive scope, not file count."* #117 is the same shape — 22 catch blocks, all the same kind of edit.
6. **`docs/phase-2/02-articles-39-40-cleanup-report.md`** through **`docs/phase-2/05-composio-sheets-removal-report.md`** — the five prior session reports. Skim, don't deep-read. You're inheriting their working-model patterns (production-touch disclosure line in the PR, outcomes-log row on PR-open, session report at end) but **NOT** their multi-phase gated execution shape — autonomous mode collapses those phases.
7. **`docs/phase-2/agent-friendly-outcomes.md`** — the outcomes log. You'll append one row.
8. **`docs/methodology/cross-session-register.md`** — append an entry ONLY if a genuine cross-session decision crystallizes during your run. Most F-1 runs probably don't. Don't force one.
9. **`.claude/settings.json`** — the auto-approve fence's deny rules. They will block dangerous commands (`gh pr merge`, `git push * main*`, force-push, `.env*` writes, prod DB access). You have no audience to approve a denied command — so if you find yourself reaching for one, you've drifted from the in-scope work; stop and surface in a draft-PR comment.
10. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope

- **Sweep the 22 `console.error`-only catch blocks** across the files listed in the #117 body (`AdminSuggestions.jsx`, `AdminArticles.jsx`, `AdminResearch.jsx`, `AdminEduMaterials.jsx`, `AdminEduSuggestions.jsx`, `AdminEduResearch.jsx`, `AdminOutlines.jsx`, `AdminCalendar.jsx`, `components/admin/TagInput.jsx`). Add a `showToast({type: 'error', ...})` call in each catch block, **alongside** the existing `console.error` — they're complementary (console for devs, toast for operators). Do NOT remove the `console.error`s.
- **The target pattern** is `AdminArticles.handleTranslate` / `handleSeriesSections` in `frontend/src/pages/admin/AdminArticles.jsx`. Mirror its shape. Use `useToast()` to get `showToast` / `dismissToast`. The error toast's `message` should be the caught error's message (or a sensible fallback if the error has no message).
- **Wire in `useToast`** in the files that don't already import it (`AdminSuggestions.jsx`, `AdminEduResearch.jsx`, `AdminOutlines.jsx`, `AdminCalendar.jsx`, `components/admin/TagInput.jsx` — confirm against the actual import sites in the source rather than this list).
- **Run `npm run lint`** and **`npm run build`** before pushing. Both must be clean.
- **One PR** containing the full sweep. The 22-catch-block scope is "borderline-but-qualifies" per the agent-friendly criteria's worked examples (cognitive scope is small even though file count is 9).

### OUT of scope (do NOT touch)

- **Anything under `backend/`.** If you find yourself reading or editing a backend file, you've drifted. Stop and surface in a draft-PR comment.
- **Anything outside `frontend/src/pages/admin/*.jsx` and `frontend/src/components/admin/*.jsx`.** A glob check: every modified file must match one of those two patterns. If a change requires touching a file outside that glob, surface in a draft-PR comment.
- **No new dependencies.** No `npm install`. No edits to `package.json` or `package-lock.json` beyond what's already in the worktree.
- **No `.env*` writes** (denied by the fence anyway).
- **No `console.error` removals.** They stay; the toast is additive.
- **No `gh pr merge`** (denied by the fence). The operator merges.
- **No related issues** (#118 unsaved-changes guard, #119 beforeunload, #120 outline editor, #121 confirmation prompts, #122 modal dismissal). Each is a separate F-N candidate. Surface the temptation as a process note in the session report; don't act on it.

## Default rules for likely ambiguities

The brief is the contract. When you hit an ambiguity, follow these defaults:

- **`useToast` import location** — if a file imports `useToast` from a path already (check `AdminArticles.jsx` for the canonical import line), use the same path. If a file doesn't import it yet, add the import using the same path the canonical-pattern file uses.
- **Toast error message text** — short, actionable. The pattern in `AdminArticles.handleTranslate`'s error toast is a useful template; adapt the action name (e.g., "Failed to update status", "Failed to generate tags", "Failed to download"). Keep messages in English to match the rest of the admin CMS (admin is English-only; bilingual is for the public site).
- **Error message body** — use `err.message ?? 'Unexpected error'` (or equivalent existing fallback in the codebase). Surface the backend's `detail` field if it's present (`admin.js` already extracts it from non-2xx responses — confirm against `frontend/src/services/admin.js`).
- **`refreshGrid` catch blocks** — these are background-refresh failures, not user-action failures. **Still toast them** (operators need to know the grid is stale) but use a lower-priority message like "Failed to refresh — data may be out of date" rather than presenting as a fatal action failure.
- **If `console.error(...)` calls exist OUTSIDE a `catch` block** (e.g., defensive logging on an unexpected branch) — leave them. The sweep is for `catch (err) { console.error(...) }` only.
- **Toast duration** — use the Toast hook's default. Don't specify duration explicitly unless mirroring an existing pattern (`AdminArticles.handleTranslate` uses `duration: 0` for the in-flight "Translating..." toast; you don't need that for error toasts).
- **If `useToast` is being added to a component that's a child of an `<AdminLayout>`** — the hook should "just work" because `AdminLayout` (or whatever wraps the admin pages) provides the `ToastProvider`. If you find a file that's NOT inside the admin layout (e.g., `TagInput.jsx` used outside admin?), surface in a draft-PR comment.

## Self-review checklist (before opening the PR)

Run through this list. If any item fails, **open the PR as a draft** with a comment naming the failed item.

- [ ] Counted the catch blocks you changed. Number should be 22 (or surface the discrepancy in the PR description).
- [ ] Every modified file matches `frontend/src/pages/admin/*.jsx` or `frontend/src/components/admin/*.jsx`.
- [ ] No `.env*` files were touched.
- [ ] No `console.error` was removed. Each catch block now has both `console.error` AND `showToast({type: 'error', ...})`.
- [ ] No new `console.error` was introduced outside the existing catch blocks.
- [ ] `npm run lint` exits clean on changed files.
- [ ] `npm run build` succeeds (no broken imports, no compile errors).
- [ ] All `useToast` imports use the same import path (consistency across files).
- [ ] PR description contains: a "Production touch: no — verified by:" line; a test plan; a `Closes #117` line (only in the implementing PR, NOT in the prompt-drafting commit body).
- [ ] Outcomes-log row appended with `Agent attempted: yes` (new value; first time).
- [ ] Session report written at `docs/phase-2/06-frontend-f1-issue-117-report.md`.

## PR shape requirements

- **Branch name**: `fix/issue-117-admin-action-toasts`
- **Title**: `fix(#117): surface admin action failures via Toast — sweep across 9 admin files`
- **Body must include**:
  - **Summary** — 2-3 lines on what changed and why.
  - **Production touch: no — verified by:** a one-line statement (no `.env` writes; no DB ops; no backend changes; no deploy).
  - **Self-review checklist** — copy the checklist above and mark each item.
  - **Test plan** — at minimum: lint + build pass; manually testing each error path is operator's call.
  - **Closes #117** (auto-close — this PR is the implementing PR).
  - **🤖 Generated with [Claude Code](https://claude.com/claude-code)** footer.
- **Draft vs ready-for-review**: open as **ready-for-review** if all self-review checklist items pass; open as **draft** if any fail (and include the failed item in the PR description and as a top-level PR comment).
- **DO NOT MERGE.** The `gh pr merge*` deny rule will block you anyway. The operator merges.

## Outcomes-log row

Append exactly one row to `docs/phase-2/agent-friendly-outcomes.md` when the PR opens. Schema:

| Column | Value |
|---|---|
| Issue # | `117` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-admin` |
| Agent attempted? | **`yes`** (new value — first ever; this is the methodology data point) |
| PR # | the PR you just opened |
| Outcome | `not-yet-attempted` (flipped at merge per the tiny-PR-after-merge convention) |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary: what was easier/harder than the agent-friendly label predicted. Honest. If you opened the PR as a draft because the self-review checklist failed, say which item failed and why. |

## Session report

Write to `docs/phase-2/06-frontend-f1-issue-117-report.md`. Mirror the shape of `docs/phase-2/02-articles-39-40-cleanup-report.md` (executive summary; by the numbers; what was done; what's next; process notes; what surprised you; cross-cutting checklist dispositions). The report is your only post-hoc artifact — the orchestrator will read it to understand how the autonomous run went.

Two sections matter more than others for this experiment:

- **Process notes** — flag anything that you would have surfaced to the operator if you had been in pair mode. The methodology question is whether the autonomous mode loses the value of those surface-for-input moments; the answer lives in this section.
- **What surprised you** — anything that the brief didn't anticipate. If the brief was tight, this is short. If it was loose, this is long. Either way is data.

## Begin by

1. Read the inputs in the order listed in "Read these first." Don't skim.
2. Count the actual `console.error`-only catch blocks in scope (the issue body says 22; verify against the source).
3. Identify the canonical import path for `useToast` from `AdminArticles.jsx`.
4. Make the sweep. Keep changes mechanical and consistent across files.
5. Run `npm run lint` and `npm run build`. Iterate until clean.
6. Self-review checklist.
7. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
8. Append the outcomes-log row.
9. Write the session report.
10. **Stop.** The operator sees only your PR + outcomes-log row + session report. You are done.

You have one shot. Make it the best autonomous attempt you can; if you can't, make the most honest draft-PR-with-a-comment you can. Either is good methodology data.
