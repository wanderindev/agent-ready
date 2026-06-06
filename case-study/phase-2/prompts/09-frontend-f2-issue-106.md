# Phase 2 — Session 09: Frontend autonomous-agent experiment, F-2.3 — issue #106 (catch-all 404 + NotFound)

## Identification

You are the **autonomous agent** running **F-2.3** of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. Launched via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run.

**F-2 is the sequential phase** — three autonomous runs, one after the other, each merging before the next starts. F-1 tested multi-file sweep scale. F-2.1 tested narrow single-file scope. F-2.2 tested smaller-scale sweep. **F-2.3 (this run) tests a structural-add shape — adding a new component file and wiring it into existing routing.** The methodology question: does the brief-template hold when the change isn't a modification of existing files but a creation of a new one?

You are in a worktree; source-of-truth is the repo here.

## Three operational notes

1. **Worktree `node_modules` resolution.** Symlink: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`. Zero diff impact.
2. **Codebase-fact claims verified.** Verified against worktree `main` HEAD at brief-writing time. If source contradicts, follow source and surface in PR.
3. **Issue-body count interpretation, pre-resolved.** The issue body identifies two coupled changes: (a) add a `NotFound` page component and a `<Route path="*">` catch-all, (b) the issue *pairs with* #7 (top-level `<Sentry.ErrorBoundary>`). **Only (a) is in scope for this PR.** #7 is a separate operator-driven issue. After this PR lands, missing-route URLs render NotFound; uncaught render errors on other pages remain a blank-page issue (until #7 lands separately).

## What this experiment is testing

F-2.3 specifically tests the brief-template against a **structural-add shape**: create a new file (`NotFound.jsx`), add a new import to `App.jsx`, add a new `<Route>` element. The previous F-1/F-2.1/F-2.2 runs all modified existing files; this one creates a new one. The methodology question: does the autonomous-mode template generalize from "modify existing" to "create + wire"?

If you get stuck, **open a draft PR with a comment** and stop.

## Read these first, in order

1. **Issue #106** — `gh issue view 106`. The full body.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #106.
3. **`frontend/src/App.jsx`** (full file) — the target. The `<AppShell>` route group starts around line 64; there is no `<Route path="*">` inside it. You'll add one.
4. **`frontend/src/pages/Contact.jsx`** (focus on the bottom of the file — the `Sentry.withErrorBoundary` wrapper at the end) — a canonical example of a page-level error boundary, **for context only** (this PR doesn't add error boundaries; it adds the catch-all 404 only).
5. **`frontend/src/pages/TermsAndConditions.jsx`** or **`PrivacyPolicy.jsx`** (full file) — these are good shape-references for a static informational page. NotFound should follow this kind of layout.
6. **Any one of the existing public pages** (e.g., `frontend/src/pages/Home.jsx`'s top) — confirms how i18next is wired in (`useTranslation`, the `t` function).
7. **`frontend/public/locales/en/translation.json`** and **`frontend/public/locales/es/translation.json`** — confirm the i18next namespace / structure. You'll add a small `notFound` block to each (or use a sensible key under an existing block).
8. **`docs/phase-2/06-frontend-f1-issue-117-report.md`** — F-1's session report. Skim.
9. **`docs/phase-2/07-frontend-f2-1-issue-110-report.md`** and **`docs/phase-2/08-frontend-f2-2-issue-107-report.md`** — F-2.1 and F-2.2 session reports (will exist by the time you run).
10. **`docs/phase-2/agent-friendly-outcomes.md`**.
11. **`docs/methodology/cross-session-register.md`**.
12. **`.claude/settings.json`**.
13. **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **Create `frontend/src/pages/NotFound.jsx`** — a new file. A simple page component that:
  - Renders a clear "Page not found" message, bilingual via i18next.
  - Includes a link back to home (`/`).
  - Matches the visual style of other static pages (e.g., `TermsAndConditions.jsx`, `PrivacyPolicy.jsx`).
- **Add translation keys** for the page in both `frontend/public/locales/en/translation.json` and `frontend/public/locales/es/translation.json`. Use a `notFound` namespace or place under an existing sensible one. Keep keys minimal: a title (e.g., "Page not found" / "Página no encontrada"), a body sentence, and a back-home link label.
- **Wire the route in `frontend/src/App.jsx`**: add `import NotFound from './pages/NotFound.jsx'` to the imports block, and add `<Route path="*" element={<NotFound />} />` as the **last child route** of the `<AppShell>` route group (so it catches any unmatched URL under the public site shell).
- **Verify locally** by running the dev server and navigating to a bogus URL like `/this-route-doesnt-exist`. The NotFound page should render (with Navbar + Footer via `<AppShell>`). If the dev server isn't easily startable in the worktree, skip the manual test and document the skip.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope (do NOT touch)

- **`Sentry.ErrorBoundary` work** — that's #7's responsibility. Do not add a top-level boundary; do not add per-page boundaries on the un-boundaried pages.
- **The admin routes** — the `*` catch-all goes inside `<AppShell>` (public-site shell), not on the top-level admin routes.
- **Anything under `backend/`.**
- **Any other page or component** — only `App.jsx`, the new `NotFound.jsx`, and the two `translation.json` files.
- **No new dependencies.**
- **No `.env*` writes** (denied).
- **No `gh pr merge`** (denied; operator merges).

## Default rules for likely ambiguities

- **Where to place `<Route path="*">`** — as the **last child route inside `<AppShell>`** (the route element at line ~64 with `path="/"`). React Router's catch-all only fires when no prior child route matches, so placement-last-inside-AppShell ensures all public-site URLs get NotFound instead of a blank `<main>`. Do NOT place a `*` catch-all outside the AppShell — that would catch admin routes too.
- **What if the admin routes (`/admin/*`) should also have a catch-all?** — out of scope. The issue body only addresses the public-site shell. Admin's missing-route behavior is a separate question (and is generally less of a problem because admins know their own URLs).
- **Translation keys structure** — pick the simplest shape consistent with the existing translation files. Examples: `{ "notFound": { "title": "...", "message": "...", "backHome": "..." } }`. Don't proliferate keys.
- **NotFound visual style** — match `TermsAndConditions.jsx` / `PrivacyPolicy.jsx` in their use of tailwind classes for a centered, plain-text page. Don't introduce new design patterns.
- **The "back home" link** — use `react-router-dom`'s `<Link to="/">` (matches existing usage across pages).
- **i18next hook** — `useTranslation()` from `react-i18next` (matches existing usage). The page should select its language via the standard hook; no per-page language detection needed.
- **HTTP status code** — frontend route pages can't set HTTP status codes (the response was 200 from the SPA's index.html). Don't add `<head>` manipulation to try to fake a 404 status; it's not the point of this fix.
- **SEO / `<meta>` tags** — out of scope. The visible UX is the goal.

## Self-review checklist

- [ ] Three or four files modified: `frontend/src/App.jsx` (route + import added), `frontend/src/pages/NotFound.jsx` (new), `frontend/public/locales/en/translation.json` and `frontend/public/locales/es/translation.json` (new keys added). Plus the two docs files.
- [ ] `NotFound.jsx` exists, follows the same component shape as `TermsAndConditions.jsx` / `PrivacyPolicy.jsx`, uses `useTranslation` and `Link`.
- [ ] `<Route path="*" element={<NotFound />} />` is the **last** child route of `<AppShell>` in `App.jsx`.
- [ ] Translation keys exist in both `en` and `es` and are referenced correctly from `NotFound.jsx`.
- [ ] `npm run lint` clean.
- [ ] `npm run build` succeeds.
- [ ] Manual test outcome (or skip-with-reason): navigated to `/this-route-doesnt-exist` and NotFound rendered with Navbar/Footer.
- [ ] PR description contains production-touch line; test plan; `Closes #106`.
- [ ] Outcomes-log row appended with `Agent attempted: yes`.
- [ ] Session report at `docs/phase-2/09-frontend-f2-3-issue-106-report.md`.

## PR shape requirements

- **Branch name**: `fix/issue-106-catch-all-404-notfound`
- **Title**: `fix(#106): add catch-all 404 route and NotFound page`
- **Body must include**: summary; production touch: no; self-review checklist; test plan; `Closes #106`; Claude Code footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review pass; draft otherwise.

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `106` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-2.3 — fourth-ever autonomous run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary of what was easier/harder than the label predicted. Specifically: was the structural-add shape (create new file + wire) meaningfully harder than the modify-existing shapes of F-1/F-2.1/F-2.2? |

## Session report

Write to `docs/phase-2/09-frontend-f2-3-issue-106-report.md`. Mirror session 06's shape. Key sections:

- **Process notes** — pair-mode-would-have-surfaced moments. Codebase-fact contradictions (high-grade data point if found).
- **What surprised you** — the structural-add shape's actual difficulty vs. the brief's expectation. If the answer is "no harder than modify-existing," that's the synthesis-§10-relevant claim. If meaningfully harder, also methodology-relevant.
- **F-2 cumulative observation** — after three sequential autonomous runs (F-2.1, F-2.2, F-2.3, completing F-2): does the template feel adequate, or are there template improvements you'd suggest for F-3? F-3 is parallel — 2-3 agents concurrent on independent issues. The next prompt round will fold in any F-2 lessons before F-3 launches.

## Begin by

1. Symlink `frontend/node_modules` from main checkout.
2. Read the inputs in order.
3. Confirm `App.jsx`'s `<AppShell>` route group structure (last child route is where `*` goes).
4. Confirm a canonical static-page shape from `TermsAndConditions.jsx` or `PrivacyPolicy.jsx`.
5. Confirm i18next wiring from any existing page + the two `translation.json` files.
6. Create `NotFound.jsx`, add translation keys, wire the route.
7. Run lint + build.
8. Manual test (or document skip).
9. Self-review checklist.
10. Open the PR.
11. Append outcomes-log row; write session report.
12. **Stop.**
