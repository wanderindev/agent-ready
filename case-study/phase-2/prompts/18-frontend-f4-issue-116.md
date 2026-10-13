# Phase 2 — Session 18: Frontend autonomous-agent experiment, F-4.F — issue #116 (placeholder route + dead component)

## Identification

You are the **autonomous agent** running **F-4.F**, one of four concurrent **Wave 2** agents in F-4. Wave 2 launches after Wave 1 merges; you and three others (F-4.G #118, F-4.H #119, F-4.I #120) run concurrently.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body says "remove placeholder ProductDetails route and dead RelatedArticles component." **Verified**:
   - `frontend/src/App.jsx:13`: `import ProductDetails from './pages/ProductDetails.jsx'`
   - `frontend/src/App.jsx:79`: `<Route path="producto/:slug" element={<ProductDetails />} />`
   - `frontend/src/pages/ProductDetails.jsx` exists as the placeholder
   - `frontend/src/components/sections/blog/RelatedArticles.jsx` exists; **0 consumers** in the codebase (verified — grep returned only its own `export default function` declaration)

## Parallel-mode notes

Wave 2 has 4 concurrent agents. **You own App.jsx exclusively in Wave 2**. Other Wave 2 agents touch EditDrawer.jsx (F-4.G + F-4.I, in non-adjacent sections lines 40-117 and 654+) and AdminLayout.jsx + a new hook file (F-4.H). No file overlap with you. Outcomes log is the shared file; append your row at the bottom.

## Agent-vs-brief disagreement taxonomy

Three shapes. Most likely for this brief: (1) — if `ProductDetails.jsx` is actually used somewhere the brief didn't catch (e.g., a hidden test, a TODO route), override and keep it. Or (2) — if `RelatedArticles.jsx` has a consumer the orchestrator's verification missed.

**Pre-verify before deleting**: re-grep for any `import.*ProductDetails` and `import.*RelatedArticles` references in the entire codebase before deleting. If you find any beyond the App.jsx import (for ProductDetails) or the file's own export (for RelatedArticles), STOP and surface in a draft-PR comment.

## What this experiment is testing

F-4.F tests **dead-code removal** — a shape autonomous agents haven't been tested on in this experiment. Delete with confidence (after verification); preserve git history through the file deletion.

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #116** — `gh issue view 116`.
2. **`frontend/src/App.jsx`** — locate the ProductDetails import and route.
3. **`frontend/src/pages/ProductDetails.jsx`** — the placeholder being removed.
4. **`frontend/src/components/sections/blog/RelatedArticles.jsx`** — the dead component being removed.
5. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #116.
6. Prior session reports — skim.
7. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **Verify no consumers** of `RelatedArticles` exist beyond its own definition. Grep the entire `frontend/src/` for `RelatedArticles`. Expected result: only the file itself appears.
- **Verify ProductDetails is only consumed by App.jsx**. Grep for `ProductDetails`. Expected: import in App.jsx + route in App.jsx + the file's own definition.
- **Delete `frontend/src/pages/ProductDetails.jsx`** (the whole file).
- **Delete `frontend/src/components/sections/blog/RelatedArticles.jsx`** (the whole file).
- **Remove the import line** from `frontend/src/App.jsx` (currently line 13): `import ProductDetails from './pages/ProductDetails.jsx'`.
- **Remove the route line** from `frontend/src/App.jsx` (currently line 79): `<Route path="producto/:slug" element={<ProductDetails />} />`.
- **Run `npm run lint` and `npm run build`** — both clean. The build should still pass without these files.

### OUT of scope

- **Other dead-code candidates** in the codebase (other unused components, unused imports).
- **Refactoring App.jsx routes** beyond the removal.
- **Translation key cleanup** if the deleted files had any keys — out of scope (orphan keys in translation.json are harmless).
- **Backend changes.**

## Default rules for likely ambiguities

- **What if `ProductDetails` is referenced in i18n keys** like `productDetails.title`? — translation keys can remain; they'll just go unused. Out of scope.
- **What if a test file imports the deleted components?** — your grep should catch this. If found, STOP and surface in draft-PR. Test files are an out-of-scope dependency that needs operator decision.
- **What if `RelatedArticles` has TypeScript-style dependent declarations** (it shouldn't — codebase is JSX)? — verify visually.
- **What if the App.jsx route block has surrounding context** (comments, adjacent routes) that benefits from cleanup? — remove only the two lines (import + route). Don't touch adjacent lines.

## Self-review checklist

- [ ] `frontend/src/pages/ProductDetails.jsx` deleted.
- [ ] `frontend/src/components/sections/blog/RelatedArticles.jsx` deleted.
- [ ] `frontend/src/App.jsx`: import line removed (line ~13).
- [ ] `frontend/src/App.jsx`: route line removed (line ~79).
- [ ] No other App.jsx lines changed (preserve surrounding context).
- [ ] Grep verification documented in PR description (showed 0 consumers for `RelatedArticles`; 1 consumer for `ProductDetails`, the App.jsx import that's now also removed).
- [ ] `npm run lint` clean — no new issues vs main baseline; the deletions may even reduce the count.
- [ ] `npm run build` succeeds; bundle should shrink slightly.
- [ ] PR description: production touch line; verification grep results; test plan; `Closes #116`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/18-frontend-f4-F-issue-116-report.md`.

## PR shape

- **Branch**: `fix/issue-116-remove-productdetails-route-and-relatedarticles`
- **Title**: `fix(#116): remove placeholder ProductDetails route and dead RelatedArticles component`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `116` |
| Filed agent-friendly? | `yes` |
| Filed severity | `nice` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-4.F — thirteenth autonomous run; first dead-code-removal run in the experiment) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary; mention verification results. |

## Session report

`docs/phase-2/18-frontend-f4-F-issue-116-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs.
3. Verify no unexpected consumers (grep).
4. Delete the two files; remove the App.jsx import and route lines.
5. Lint + build (build must still pass).
6. Self-review.
7. Open PR.
8. Outcomes-log row + session report.
9. **Stop.**
