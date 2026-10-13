# Phase 2 — Session 18: F-4.F — issue #116 (placeholder route + dead component) — session report

## Identification

- **Run**: F-4.F — thirteenth autonomous run; first dead-code-removal run in the experiment.
- **Wave**: F-4 Wave 2 (concurrent with F-4.G #118, F-4.H #119, F-4.I #120).
- **Issue**: [#116](https://github.com/wanderindev/panama-in-context/issues/116) — `[Agent] Remove placeholder ProductDetails route and dead RelatedArticles component`.
- **Branch**: `fix/issue-116-remove-productdetails-route-and-relatedarticles`.
- **PR**: see outcomes log row.

## What shipped

Two file deletions and three line removals across two consumer files:

1. **Deleted** `frontend/src/pages/ProductDetails.jsx` (104 lines) — placeholder page with hardcoded English content, Unsplash stock images, hardcoded prices ($180 / $45). Ignored its `:slug` param entirely.
2. **Deleted** `frontend/src/components/sections/blog/RelatedArticles.jsx` (123 lines) — never-imported dummy component with fake authors ("Maria Rodriguez" / "Carlos Gomez"), `href="#"` links, Unsplash images.
3. **`frontend/src/App.jsx`**: removed line 13 (`import ProductDetails from './pages/ProductDetails.jsx'`) and line 79 (`<Route path="producto/:slug" element={<ProductDetails />} />`).
4. **`frontend/src/components/layout/AppShell.jsx`**: removed line 23 (`'/producto/',` in `CONTENT_PREFIXES`). See agent-vs-brief disagreement note below.

## Pre-verification grep results

Per the brief's "Pre-verify before deleting" instruction, grepped the entire codebase before deleting:

- `grep -rn "ProductDetails" frontend/src/` returned exactly three hits: `App.jsx:13` (import), `App.jsx:79` (route), `pages/ProductDetails.jsx:1` (own export). All three resolved by this PR (two removed from App.jsx, file deleted).
- `grep -rn "RelatedArticles" frontend/src/` returned exactly one hit: the file's own `export default function RelatedArticles()` declaration at line 62. Zero consumers, as the orchestrator predicted.
- `grep -rn "producto" frontend/src/` returned two hits: `App.jsx:79` (route, removed) and `AppShell.jsx:23` (`CONTENT_PREFIXES` entry, also removed — see below).
- Wider grep across `frontend/` JSON/HTML/MD returned only an unrelated Spanish translation string about "productos y servicios" in the privacy policy — not a reference to `ProductDetails` or the `/producto/` route.

No unexpected consumers; no STOP-and-comment trigger fired.

## Agent-vs-brief disagreement (resolved)

The brief's structural guards listed only:

- Delete `ProductDetails.jsx`.
- Delete `RelatedArticles.jsx`.
- Remove the App.jsx import (line ~13).
- Remove the App.jsx route line (line ~79).

But the issue body (#116) explicitly lists a fourth surface: `frontend/src/components/layout/AppShell.jsx:23` — the `'/producto/'` entry in the `CONTENT_PREFIXES` array, which causes the SPA to fire a Meta Pixel `ViewContent` event for any `/producto/*` URL.

This is taxonomy shape (2) from the brief: the brief verification was incomplete relative to the issue body. The brief itself notes "**You own App.jsx exclusively in Wave 2**" but doesn't restrict `AppShell.jsx`; checked the other Wave 2 agents' files per the brief's parallel-mode notes — F-4.G/I touch `EditDrawer.jsx`, F-4.H touches `AdminLayout.jsx` + a new hook file. **No Wave 2 overlap on `AppShell.jsx`**, so removing the line is safe.

Resolution: include the `AppShell.jsx` line removal. Reasoning:

1. The issue body is the source of truth; it explicitly enumerates this surface.
2. Once the route is gone, the `'/producto/'` prefix is verifiably dead — no route serves URLs under that prefix any more. Leaving the entry in `CONTENT_PREFIXES` would mean any stale/external link to `/producto/foo` still fires `ViewContent` *en route to a 404*, which is the very risk the issue calls out.
3. Auto-mode bias: make the reasonable call and keep going.

Flagged to the operator in the PR description and in the outcomes-log Notes column.

## Verification

- **Lint**: 47 problems (33 errors, 14 warnings) — identical to `main` baseline. All pre-existing in admin pages unrelated to the deletions.
- **Build**: clean. `vite build` succeeded in 4.24s. 2335 modules (one fewer than main's 2336 — `ProductDetails.jsx` no longer transformed; `RelatedArticles.jsx` wasn't transformed before because it had no consumers).
- **Bundle size shrank**: `dist/assets/index-*.js` 2,656.41 kB → 2,651.16 kB (-5.25 kB raw, gzip 733.80 kB → 732.60 kB, -1.20 kB). `dist/assets/index-*.css` 87.72 kB → 85.83 kB (-1.89 kB raw, gzip 15.30 kB → 15.02 kB, -0.28 kB). The expected slight shrink the brief predicted.

## Self-review checklist

- [x] `frontend/src/pages/ProductDetails.jsx` deleted.
- [x] `frontend/src/components/sections/blog/RelatedArticles.jsx` deleted.
- [x] `frontend/src/App.jsx`: import line removed.
- [x] `frontend/src/App.jsx`: route line removed.
- [x] No other App.jsx lines changed (preserve surrounding context).
- [x] `frontend/src/components/layout/AppShell.jsx`: `'/producto/'` entry removed from `CONTENT_PREFIXES` (per issue body; agent-vs-brief resolution above).
- [x] Grep verification documented in PR description.
- [x] `npm run lint` clean — no new issues vs main baseline (47 = 47).
- [x] `npm run build` succeeds; bundle shrank slightly.
- [x] PR description: production touch line; verification grep results; test plan; `Closes #116`; Claude Code footer.
- [x] Outcomes-log row appended.
- [x] This session report at `docs/phase-2/18-frontend-f4-F-issue-116-report.md`.

## Methodology notes (for synthesis)

1. **First dead-code-removal run** in the experiment. The shape is qualitatively different from the modify-existing (F-1, F-2, F-3, F-4.A/B/C/D/E) and structural-add (F-2.3) shapes seen earlier. Result: still zero ambiguity-resolution events.
2. **The pre-verify-grep step was load-bearing.** It surfaced the `AppShell.jsx` reference the brief omitted, which would have left the issue partially unaddressed if the agent had trusted the brief alone. Brief-tightening recommendation for future dead-code-removal briefs: always include an exhaustive `grep -rn` enumeration of every identifier referenced by the deletion targets, sourced from both the issue body and an independent grep at brief-write time.
3. **Brief-to-issue drift detected and resolved without operator intervention.** The agent applied the auto-mode bias ("make the reasonable call and keep going") to include the `AppShell.jsx` line, and flagged the deviation transparently. This is the same shape as F-4.C's `index.html` vs. `App.jsx` framing correction (the brief corrected an inherited issue-body error) — except here the polarity is reversed: the issue body corrected the brief.
4. **Bundle-size delta confirms the deletions are reachable from the App entry.** `ProductDetails.jsx` was tree-shaken into the production bundle (its removal shrank the bundle). `RelatedArticles.jsx` was *not* — it had no consumers, so the bundle didn't shrink from its removal directly; the shrink is entirely attributable to `ProductDetails.jsx`. This is consistent with the dead-component-vs-placeholder-route distinction in the issue body.
5. **Translation keys orphaned by the deletion**: zero. Neither deleted file used `useTranslation`/`t()`. Both shipped hardcoded English strings — which is partly why the issue exists. No orphan-keys cleanup needed.

## Out-of-scope (not done, per brief)

- Other dead-code candidates (other unused components, unused imports).
- Refactoring `App.jsx` routes beyond the removal.
- Adding a real, data-driven product-detail page (separate net-new work per the issue body).
