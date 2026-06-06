# Phase 2 — Session 08: Frontend autonomous-agent experiment, F-2.2 — issue #107 (response.ok sweep)

## Identification

You are the **autonomous agent** running **F-2.2** of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. You have been launched from the orchestrator's main session via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run.

**F-2 is the sequential phase of the frontend experiment** — three autonomous runs, one after the other, each merging before the next starts. F-1 (session 06, PR #148) tested the brief-template at multi-file sweep scale. F-2.1 (session 07, immediately preceding this) tested the narrowest single-file scope. **F-2.2 (this run) tests a smaller-scale sweep than F-1** — 9 functions across 2 files, with the canonical pattern in two sibling files in the same directory. F-2.3 (session 09) follows with a structural-add shape.

You are running in a worktree; the project source-of-truth is the repo as it exists in this worktree. Do not assume any conversational context.

## Three operational notes (folded in from F-1's session-06 lessons)

1. **Worktree `node_modules` resolution.** Symlink from the main checkout near the start of your run: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`. Documented in the cross-session register (2026-05-26) as the expected resolution for autonomous-agent worktrees. Zero diff impact (`node_modules` is gitignored).
2. **All codebase-fact claims below have been verified by the orchestrator at brief-writing time against the worktree's `main` HEAD.** If source contradicts the brief, follow the source and surface in the PR.
3. **Issue-body count interpretation, pre-resolved.** The issue body identifies **9 functions total** lacking `if (!response.ok) throw` guards — 6 in `educators.js` (`educatorLogin`, `educatorSignup`, `educatorConfirm`, `educatorVerifyCode`, `educatorCheckAccess`, `educatorUnsubscribe`) and 3 in `subscribe.js` (`subscribe`, `confirmSubscription`, `unsubscribe`). Every function in both files lacks the guard. The fix is 9 identical inserts.

## What this experiment is testing

F-2.2 specifically tests the brief-template against a **smaller-scale sweep than F-1's 22-block sweep**. The shape is the same (mechanical, near-identical edits across multiple sites, canonical pattern in sibling files); the question is whether the autonomous mode produces clean output at this scale too. If F-2.2 lands clean-merge, the cumulative F-1 + F-2.1 + F-2.2 data argues the template holds for sweep shapes across at least two orders of magnitude (22 vs 9).

If you get stuck, **open a draft PR with a comment** and stop. Draft PR with honest "needs human input" comment > non-draft PR that quietly worked around an ambiguity.

## Read these first, in order

Read each one fully before writing code.

1. **Issue #107** — `gh issue view 107`. The full body. It is the spec.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #107.
3. **`frontend/src/services/educators.js`** (full file) — 6 functions to fix; every one has the same shape (await fetch, return response.json()). None checks `response.ok`.
4. **`frontend/src/services/subscribe.js`** (full file) — 3 functions to fix; same shape.
5. **`frontend/src/services/articles.js`** (top ~30 lines) — contains the **canonical pattern**: `if (!response.ok) throw new Error('Failed to fetch X')` right after the `await fetch(...)`, before `response.json()`.
6. **`frontend/src/services/publicMedia.js`** (full file — it's short) — same canonical pattern, applied uniformly across all its functions. Use this as the strict template for what every function in `educators.js` / `subscribe.js` should look like after the fix.
7. **`docs/phase-2/06-frontend-f1-issue-117-report.md`** — skim. F-1's process notes about ambiguity-cost are relevant.
8. **`docs/phase-2/07-frontend-f2-1-issue-110-report.md`** — F-2.1's session report (read at session start if it exists; will exist after F-2.1 merges before you launch).
9. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log.
10. **`docs/methodology/cross-session-register.md`** — append an entry ONLY if a genuine cross-session decision crystallizes.
11. **`.claude/settings.json`** — auto-approve fence rules.
12. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope

- **Add `if (!response.ok) throw new Error('Failed to <verb>')` after each `await fetch(...)` and before each `return response.json()`** in:
  - `frontend/src/services/educators.js` — all 6 functions.
  - `frontend/src/services/subscribe.js` — all 3 functions.
- **Error-message text** — mirror `publicMedia.js`'s pattern of short action-noun phrases: `'Failed to log in educator'`, `'Failed to sign up educator'`, etc. Keep messages in English (these are service-layer thrown errors that callers will catch and translate; English here matches the canonical pattern's choice).
- **Run `npm run lint` and `npm run build`** — both clean (no new issues vs main).
- **One PR** containing all 9 inserts.

### OUT of scope (do NOT touch)

- **Anything under `backend/`.**
- **Anything outside `frontend/src/services/educators.js` and `frontend/src/services/subscribe.js`** (plus the docs files for outcomes-log + session report).
- **The `articles.js` and `publicMedia.js` files** — they're the canonical pattern; leave them alone. (They already have the guards.)
- **Any caller-side changes.** Callers' existing `try/catch` blocks already handle `throw`n errors. If you find a caller without `try/catch`, do NOT add one — that's a separate concern.
- **`EducatorAccessGate.handleLogin`** specifically — the issue body cites it as a concrete failure case (a 500 with `result.status === undefined` reaches `setSubmitting(false)` with no message). The fix at the service layer (this PR) resolves it: the `throw` propagates to the caller's existing `try/catch`. **Do not modify `EducatorAccessGate.handleLogin`** unless its `try/catch` somehow doesn't exist — verify by reading the file before deciding.
- **No new dependencies.**
- **No `.env*` writes** (denied).
- **No `gh pr merge`** (denied; operator merges).

## Default rules for likely ambiguities

- **Error-message text** — short, action-verb phrasing matching `publicMedia.js`: `'Failed to <verb> <noun>'`. Don't include the HTTP status code (the canonical pattern doesn't). Don't include the URL (canonical pattern doesn't).
- **Whether to include the `response.statusText` in the error message** — no. `publicMedia.js` doesn't; mirror that.
- **Verb choice per function**:
  - `educatorLogin` → `'Failed to log in educator'`
  - `educatorSignup` → `'Failed to sign up educator'`
  - `educatorConfirm` → `'Failed to confirm educator'`
  - `educatorVerifyCode` → `'Failed to verify educator code'`
  - `educatorCheckAccess` → `'Failed to check educator access'`
  - `educatorUnsubscribe` → `'Failed to unsubscribe educator'`
  - `subscribe` → `'Failed to subscribe'`
  - `confirmSubscription` → `'Failed to confirm subscription'`
  - `unsubscribe` → `'Failed to unsubscribe'`
  (If a phrasing reads awkwardly when you write it, pick a near-synonym. The strict requirement is "short action-noun phrase that matches the canonical pattern's tone.")
- **Guard placement** — between `await fetch(...)` and `return response.json()`. The canonical pattern (`articles.js` / `publicMedia.js`) places it on the line immediately after the `fetch` result is assigned.
- **JSDoc updates** — `educators.js` has no JSDoc; leave it bare. `subscribe.js` has JSDoc on each function. **Do not modify the JSDoc** — the `@returns` types are the success-case shapes; they remain accurate (callers using `try/catch` see those shapes on success, see thrown `Error` on failure).

## Self-review checklist (before opening the PR)

- [ ] Exactly 9 `if (!response.ok) throw new Error(...)` lines added — 6 in `educators.js`, 3 in `subscribe.js`.
- [ ] Each guard sits between the `await fetch(...)` and the `return response.json()`.
- [ ] No other files modified (apart from outcomes-log row + session report).
- [ ] Error-message texts match the verb-per-function table above (or near-synonym).
- [ ] `npm run lint` clean — no new issues vs main baseline.
- [ ] `npm run build` succeeds.
- [ ] Sanity-check: each function still returns `response.json()` on the success path. (The guard adds a throw on non-2xx; the success path is unchanged.)
- [ ] PR description contains production-touch line; test plan; `Closes #107`.
- [ ] Outcomes-log row appended with `Agent attempted: yes`.
- [ ] Session report written at `docs/phase-2/08-frontend-f2-2-issue-107-report.md`.

## PR shape requirements

- **Branch name**: `fix/issue-107-services-response-ok-guards`
- **Title**: `fix(#107): add response.ok guards to educators.js and subscribe.js`
- **Body must include**: summary; production touch: no; self-review checklist; test plan; `Closes #107`; Claude Code footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review pass; draft otherwise.

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `107` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-2.2 — third-ever autonomous run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary of what was easier/harder than the label predicted. |

## Session report

Write to `docs/phase-2/08-frontend-f2-2-issue-107-report.md`. Mirror session 06's shape. Key sections:

- **Process notes** — flag any pair-mode-would-have-surfaced moments.
- **What surprised you** — codebase-fact contradictions (the brief was written against verified source; if you find a contradiction, that's a high-grade data point).
- **Comparison to F-1** — F-1 was a 22-block sweep; F-2.2 is a 9-function sweep. Note whether the smaller scale changed the agent's experience meaningfully (it shouldn't, if the brief is right; but data either way).

## Begin by

1. Symlink `frontend/node_modules` from main checkout.
2. Read the inputs in order.
3. Confirm the canonical pattern at `articles.js` / `publicMedia.js`.
4. Apply the 9 guards. Run lint + build.
5. Self-review checklist.
6. Open the PR.
7. Append outcomes-log row; write session report.
8. **Stop.**
