# Phase 2 — Session 07: Frontend autonomous-agent experiment, F-2.1 — issue #110 (CartContext)

## Identification

You are the **autonomous agent** running **F-2.1** of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. You have been launched from the orchestrator's main session via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run. You finish; the orchestrator reviews your PR.

**F-2 is the sequential phase of the frontend experiment** — three autonomous runs, one after the other, each merging before the next starts. F-1 (session 06, PR #148) was a single-shot test; F-2 tests whether the brief-template holds across multiple sequential issues. You are the first of three. The other two (#107 service-layer error-handling sweep; #106 catch-all 404 + NotFound component) follow this one in their own sessions.

You are running in a worktree; the project source-of-truth is the repo as it exists in this worktree. Do not assume any conversational context. Everything you need is in files this brief points at.

## Three operational notes (folded in from F-1's session-06 lessons)

1. **Worktree `node_modules` resolution.** Your worktree starts with no `frontend/node_modules` (gitignored, so not present in any new worktree). The brief's "no `npm install`" + "lint + build must pass" combination is only satisfiable by symlinking from the main checkout. Run this once near the start of your run: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`. This is documented in the cross-session register (2026-05-26) as the expected resolution; the symlink is local-only and `node_modules` is in `.gitignore` so it has zero diff impact.
2. **All codebase-fact claims below have been verified by the orchestrator at brief-writing time against the worktree's `main` HEAD.** If you read a file and the source contradicts the brief, follow the source and surface the discrepancy in the PR description — but don't expect contradictions; the brief was written against verified source this time.
3. **Issue-body count interpretation, pre-resolved.** The issue body identifies **one** `JSON.parse` site without error handling. The fix is a `try/catch` wrap of that one site, plus a fallback to the empty-cart default. No sweep semantics; one site is one site.

## What this experiment is testing

This is **F-2.1** — the first of three sequential autonomous runs in F-2. Cumulative methodology question (across F-1 + F-2 + F-3): does the flat `agent-friendly:yes` label hold up under unattended execution? F-1 produced one clean-merge data point at N=1. F-2 produces three more sequential data points, taking the corpus to N=4. F-2.1 specifically tests the brief-template at its narrowest scope — a single-file defensive-coding fix where the safe pattern lives in a sibling file in the same directory.

If you get stuck (ambiguity beyond what this brief specifies, a test failure you can't diagnose, scope that grows beyond #110), **open a draft PR with a comment describing exactly where autonomy ran out**, and stop. A draft PR with an honest "needs human input on X" comment is a *good* outcome — it's actionable methodology data. A non-draft PR that quietly worked around an ambiguity is a *worse* outcome.

## Read these first, in order

Read each one fully before writing any code. Don't skim.

1. **Issue #110** — run `gh issue view 110`. The full body. It is the spec.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #110.
3. **`frontend/src/contexts/CartContext.jsx`** (full file) — the target. The unsafe `JSON.parse` site is at lines 11-14, inside the `useState` initializer.
4. **`frontend/src/contexts/EducatorAuthContext.jsx`** (full file, or at minimum the top 25 lines) — contains the **target pattern**: `getStored()` at lines 8-21 wraps `JSON.parse` in `try/catch` and returns `null` on parse failure. Mirror this shape.
5. **`docs/phase-2/06-frontend-f1-issue-117-report.md`** — F-1's session report. Skim, don't deep-read. You're inheriting its working-model patterns (production-touch disclosure line, outcomes-log row on PR-open, session report at end) and its discoveries (the brief-tightening list now folded in here).
6. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log; you'll append one row.
7. **`docs/methodology/cross-session-register.md`** — append an entry ONLY if a genuine cross-session decision crystallizes during your run. F-2.1 specifically: probably no entry (sequential autonomous runs are the expected pattern; novel observations should be flagged in the session report's process notes, not the register).
8. **`.claude/settings.json`** — the auto-approve fence's deny rules. They will block dangerous commands. You have no audience to approve a denied command — if you reach for one, you've drifted.
9. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope

- **Wrap the `JSON.parse` site in `CartContext.jsx` (lines 11-14) in `try/catch`.** On parse failure, fall back to the empty-cart default `{ items: [], createdAt: null }`. Mirror the shape of `EducatorAuthContext.getStored` — that function logs no error message in its `catch` (it just `return null`); the equivalent here returns the empty-cart default.
- **Consider whether to also log the failure** — `EducatorAuthContext.getStored` does not. The brief's default: **do not log to console or Sentry inside the `catch`**, matching the canonical pattern. A corrupt cart is recoverable silently (the user can re-add items); silent recovery is the right shape.
- **Optionally**, the issue body suggests considering a `version` field on the persisted cart object. **Out of scope for this PR** — leave it as a follow-up note in the session report. The defensive-coding fix is sufficient.
- **Run `npm run lint` and `npm run build`** before pushing. Both must be clean (no new issues vs main baseline).
- **One PR** containing the single-file fix.

### OUT of scope (do NOT touch)

- **Anything under `backend/`.** If you find yourself reading or editing a backend file, you've drifted.
- **Anything outside `frontend/src/contexts/CartContext.jsx`.** A glob check: only one file should be modified by this PR (plus the docs files for the outcomes-log row and session report).
- **The `version` field idea** from the issue body — leave for a follow-up.
- **No new dependencies.** No `npm install` (besides the symlink workaround for `node_modules`).
- **No `.env*` writes** (denied by the fence).
- **No `gh pr merge`** (denied; operator merges).
- **Other related issues** (#7 top-level Sentry boundary, #106 catch-all 404, etc.) — out of scope for F-2.1. F-2.3 handles #106; #7 is operator-driven.

## Default rules for likely ambiguities

The brief is the contract. Mirror these defaults when uncertain:

- **Empty-cart default value** — use the exact existing default `{ items: [], createdAt: null }`. Don't invent a different shape.
- **Where to put the `try/catch`** — inside the existing `useState` initializer callback, replacing the current ternary. Don't extract to a top-level helper unless mirroring `EducatorAuthContext.getStored`'s extraction-to-a-helper-function shape feels cleaner; either is acceptable. The bar: the existing call-site `useState(() => { ... })` shape should remain readable.
- **Whether to log the error** — no (matches `EducatorAuthContext.getStored` which uses a bare `catch {}` and returns `null`).
- **JSDoc / type annotations** — match the existing file's style. CartContext.jsx has no JSDoc on its existing code; don't add it.
- **If the parsed cart object is structurally valid JSON but the wrong shape** (e.g., `JSON.parse` returns `null`, a string, an array, or an object missing `items`) — the brief does NOT require you to validate the parsed shape. The issue is about parse failure specifically. If you want to add shape validation, it's worth a *very short* mention in the session report's "what's next" — but don't expand scope to include it.

## Self-review checklist (before opening the PR)

Run through this list. If any item fails, **open the PR as a draft** with a comment naming the failed item.

- [ ] One file modified (`frontend/src/contexts/CartContext.jsx`) plus the two docs files (outcomes-log row, session report).
- [ ] The `JSON.parse` site is now inside a `try/catch`.
- [ ] On `catch`, the function returns the empty-cart default — same object shape as the existing fallback.
- [ ] No console / Sentry logging inside the `catch` (matches canonical pattern).
- [ ] No `.env*` files touched.
- [ ] `npm run lint` clean — no new issues vs `main` baseline (run `git stash && npm run lint` against main, then unstash, to verify the delta is 0).
- [ ] `npm run build` succeeds.
- [ ] Manually tested: set `localStorage.pic_cart = '{bad'` in DevTools console, reload the dev server (`npm run dev` running, navigate to `http://localhost:5173`), the page renders cleanly with an empty cart instead of a blank page. **NB**: the dev server may not be running in your worktree. If it isn't and you can't easily start it, skip the manual test and document the skip in the session report — code review + lint + build is sufficient evidence for this scoped a fix.
- [ ] PR description contains: a "Production touch: no — verified by:" line; a test plan; a `Closes #110` line (only in this implementing PR).
- [ ] Outcomes-log row appended with `Agent attempted: yes`.
- [ ] Session report written at `docs/phase-2/07-frontend-f2-1-issue-110-report.md`.

## PR shape requirements

- **Branch name**: `fix/issue-110-cartcontext-localstorage-defensive`
- **Title**: `fix(#110): wrap CartContext localStorage parse in try/catch (defensive)`
- **Body must include**:
  - **Summary** — 2-3 lines.
  - **Production touch: no — verified by:** one line (no `.env`, no DB, no backend, no deploy).
  - **Self-review checklist** — copy the checklist above and mark each item.
  - **Test plan** — lint + build pass; manual test outcome (or skip-with-reason).
  - **Closes #110**.
  - **🤖 Generated with [Claude Code](https://claude.com/claude-code)** footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** Operator merges.

## Outcomes-log row

Append exactly one row to `docs/phase-2/agent-friendly-outcomes.md`:

| Column | Value |
|---|---|
| Issue # | `110` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (the F-2.1 data point — second-ever autonomous run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` (flipped at merge by the orchestrator) |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary of what was easier/harder than the agent-friendly label predicted. Honest. Note any worktree-setup friction beyond the documented `node_modules` symlink. |

## Session report

Write to `docs/phase-2/07-frontend-f2-1-issue-110-report.md`. Mirror `docs/phase-2/06-frontend-f1-issue-117-report.md`'s shape (executive summary; by the numbers; what was done; what's next; process notes; what surprised you; cross-cutting checklist dispositions).

Two report sections matter more than others for the F-2 experiment:

- **Process notes** — flag anything that would have surfaced for operator-input in pair mode. The methodology question is whether the autonomous mode loses the value of those surface-for-input moments. F-1 had 3 such moments; F-2.1 might have 0 (the brief is tighter now); either result is informative.
- **What surprised you** — anything the brief didn't anticipate. The brief was written against verified source this time; if you find a codebase-fact wrong, that's a higher-grade data point than F-1's `ToastProvider` discovery (because we tried to prevent it).

## Begin by

1. Symlink the worktree's `frontend/node_modules` from the main checkout (see "Three operational notes" §1).
2. Read the inputs in the order listed in "Read these first."
3. Confirm the canonical pattern at `EducatorAuthContext.jsx:8-21` matches the brief's description.
4. Apply the fix to `CartContext.jsx:11-14`.
5. Run `npm run lint` and `npm run build`. Iterate until clean.
6. Self-review checklist.
7. Open the PR (ready-for-review if all checklist items pass; draft otherwise).
8. Append the outcomes-log row.
9. Write the session report.
10. **Stop.** The operator merges; the orchestrator handles the post-merge outcomes-log flip.
