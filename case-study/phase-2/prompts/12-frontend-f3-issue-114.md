# Phase 2 — Session 12: Frontend autonomous-agent experiment, F-3.C — issue #114 (image lazy-loading sweep)

## Identification

You are the **autonomous agent** running **F-3.C** of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. Launched via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run.

**F-3 is the parallelism phase.** You are one of three running concurrently — F-3.A (issue #113, `ContactConfirmation.jsx` one-line input validation), F-3.B (#115, `PublicMediaCard.jsx` a11y JSX restructure), F-3.C (this run, #114). You don't see them; they don't see you. F-2's four sequential clean-merge runs argue per-agent quality should hold; F-3 measures parallelism's operational cost.

## Three operational notes (folded in from F-2)

1. **Worktree `node_modules` resolution.** Symlink: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`. Zero diff impact.
2. **All codebase-fact claims below have been verified at brief-writing time.** Source-contradicts-brief: follow source, surface in PR.
3. **Issue-body count interpretation, pre-resolved — and the issue body is wrong about one count.** The issue body says *"HeroSection eagerly loads all 8 rotating hero images"*. The actual `heroImages` array in `frontend/src/components/sections/home/HeroSection.jsx` lines 4-17 has **12 entries**, not 8. The work is unchanged (render only active + preloaded next; lazy-load below-the-fold elsewhere), but the count in the issue body is stale relative to the current source. Use the actual 12 from the source. The orchestrator's verification at brief-writing time confirmed 12.

## Parallel-mode notes

1. **Three F-3 agents running concurrently on different code files.** Yours is the broadest scope: `HeroSection.jsx` plus 10 other component files where below-the-fold `<img>` tags need `loading="lazy"`. F-3.A: `ContactConfirmation.jsx`. F-3.B: `PublicMediaCard.jsx` (a11y restructure). **`PublicMediaCard.jsx` is also mentioned in your issue body as the canonical example of a correctly-lazy-loaded `<img>` in the codebase — read it for the pattern, but DO NOT modify it** (F-3.B owns that file).
2. **`docs/phase-2/agent-friendly-outcomes.md`** is the one file all three F-3 agents will touch (one appended row each). Conflicts at PR-merge time are expected; the operator resolves via merge-main-into-branch. **Append your row to whatever state of the file is in your worktree and stop.** Do NOT anticipate or resolve the conflict.
3. **Your session-report number is 12.** Report path: `docs/phase-2/12-frontend-f3-C-issue-114-report.md`.

## What this experiment is testing

Same as F-3.A and F-3.B: does per-agent quality hold under parallelism? F-3.C specifically tests **the broadest-scope F-3 run** — a multi-file sweep with one component-level refactor (HeroSection) plus mechanical attribute additions across ~10 sibling component files. The methodology question for this run: does the brief-tightening discipline scale to multi-file F-3 work in parallel?

If you get stuck, open a draft PR with a comment and stop.

## Read these first, in order

1. **Issue #114** — `gh issue view 114`. The full body. Pay attention to the **Fix** section's two-part split.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #114.
3. **`frontend/src/components/sections/home/HeroSection.jsx`** (full file — ~70 lines) — the target for Part A. Verified structure:
   - `heroImages` array at lines 4-17: **12 entries** (not 8 as the issue body states).
   - `useState(0)` + `useEffect` interval at lines 21-28: rotates `currentImageIndex` every 5 seconds.
   - `heroImages.map((image, index) => <img .../>)` at lines 35-44: renders ALL 12 simultaneously, toggling opacity by index. Browser fetches all 12 on mount because they're all in the DOM.
4. **`frontend/src/components/public/PublicMediaCard.jsx`** (focus the `<img loading="lazy" .../>` at line ~30) — the canonical example of `loading="lazy"`. **Read only**; F-3.B is modifying this file.
5. **The 10 files for Part B (below-the-fold lazy-loading):** `frontend/src/components/sections/home/ExcursionsCTA.jsx`, `ToursCTA.jsx`, `ExcursionsHero.jsx`, `ToursHero.jsx`, `DestinationGrid.jsx`, `AudienceTypes.jsx`, `ExperienceShowcase.jsx`, `MeetGuideSection.jsx`, `FeaturedArticles.jsx`, `BlogList.jsx`. Open each and grep for `<img` to find the eager-loaded tags.
6. **`docs/phase-2/06-frontend-f1-issue-117-report.md`** through **`09-frontend-f2-3-issue-106-report.md`** — F-1/F-2 session reports. Skim.
7. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log.
8. **`docs/methodology/cross-session-register.md`** — append only on cross-session decisions.
9. **`.claude/settings.json`** — fence rules.
10. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope, Part A — `HeroSection.jsx`

The simplest correct change per the issue body: **render only the currently-active image plus one preloaded "next" image**, rather than all 12. Approach:

- Keep the existing `useState`/`useEffect` rotation logic unchanged.
- In the JSX `heroImages.map(...)`, render `<img>` elements ONLY for indices `currentImageIndex` and `(currentImageIndex + 1) % heroImages.length`. The other 10 are not in the DOM, so the browser doesn't fetch them.
- The active image stays opacity-1 (or 60, per current code's `opacity-60`); the preloaded "next" stays opacity-0 (browser fetches it but doesn't render visibly).
- When `currentImageIndex` advances, React re-renders: the previously-active image unmounts, the new active image becomes visible, the new "next" mounts and starts loading.

Acceptance: on first paint, exactly **one** hero image is fetched (the active one); the "next" image fetches in the background but doesn't block paint. After the first 5-second interval, the rotation continues working as before.

### IN scope, Part B — Below-the-fold `loading="lazy"` sweep

For each of the 10 files listed above:

1. Open the file.
2. Find every `<img ...>` tag.
3. Add `loading="lazy"` to it (if not already present).

Important: every `<img>` in these 10 files is below-the-fold by definition — the homepage's only above-the-fold imagery is in `HeroSection.jsx` (handled by Part A) and the navbar logo (which is not in these 10 files). The 10 files contain CTA bands, secondary hero sections, showcases, blog cards, etc., all of which sit below the homepage's viewport on first paint or live on non-homepage routes.

If a file contains multiple `<img>` tags, ALL of them get `loading="lazy"`. If a file contains zero `<img>` tags, surface in the PR description (the file was named but might not match the issue's claim) — but don't halt; continue with the others.

### Both parts together — verification

- **Run `npm run lint` and `npm run build`** — both clean (no new issues vs `main` baseline).
- **Optional manual verification** — if a dev server is easily runnable in your worktree, navigate to `/`, open DevTools Network → Img filter, hard-reload, and confirm only 1-2 hero images are in the initial requests. If the dev server isn't easily startable, skip this and document the skip in the session report.

### OUT of scope (do NOT touch)

- **`PublicMediaCard.jsx`** — F-3.B owns it; read only.
- **`ContactConfirmation.jsx`** — F-3.A owns it; not relevant to lazy-loading.
- **Any `<img>` ABOVE the fold** — the active hero image; the navbar logo (if present). The Part-A change handles the hero image lazily-by-construction; don't add `loading="lazy"` to it because that would defer the LCP element.
- **`<img>` tags in admin pages** — admin isn't optimized for first-paint LCP; out of scope.
- **`fetchPriority`** attribute additions — out of scope. `loading="lazy"` is sufficient for this fix.
- **Image format conversions** (JPEG → WebP / AVIF), responsive `srcset`, or any other image optimization — out of scope. This issue is `loading="lazy"` only.
- **`<picture>` element conversions** — out of scope.
- **No new dependencies.** No `.env*`. No `gh pr merge`.

## Default rules for likely ambiguities

- **HeroSection Part A — what does "preloaded next" mean exactly?** Render the `<img>` for `(currentImageIndex + 1) % heroImages.length` in the JSX. The browser will fetch its `src` even though its opacity is 0 (browsers don't tree-shake by computed CSS). This is the "preload" — when the rotation advances, the image is already cached.
- **HeroSection Part A — should the rendered `<img>` tags get `loading="lazy"`?** No. The active hero image is the LCP element; `loading="lazy"` on it would defer the most important paint. The "next" image doesn't strictly need `loading="lazy"` either (it's prefetched intentionally), so leave both without `loading="lazy"`. The point of Part A is to eliminate the *fetch* of the other 10 images, which the map-only-2 approach accomplishes structurally.
- **Part B — order to edit files?** Pick any order; the changes are independent.
- **Part B — `<img>` count discovery method** — `grep -n "<img" <file>` works. If a file has both eager and lazy `<img>`s already, leave the lazy ones alone (idempotent edit).
- **Part B — JSX comment additions** — don't add explanatory comments. The `loading="lazy"` attribute is self-documenting.
- **What if a listed file has `loading="lazy"` on ALL its `<img>` tags already?** Note it in the PR description (file already conformant — no change needed) and move on.
- **What if a listed file doesn't have any `<img>` tags?** Note in PR description; move on.
- **Final commit count** — your call. One commit per file (~11 commits) is fine; one commit per logical group (Part A as one, Part B as one) is also fine; one commit for everything is fine. The reviewer cares about the diff, not the commit boundaries.

## Self-review checklist (before opening the PR)

- [ ] `HeroSection.jsx` modified: the `heroImages.map(...)` JSX now renders only `currentImageIndex` and `(currentImageIndex + 1) % heroImages.length` (two `<img>` tags, not twelve).
- [ ] Each of the 10 listed component files: every `<img>` tag has `loading="lazy"` (or the file is documented as no-change in the PR body).
- [ ] **No `<img>` in `HeroSection.jsx` has `loading="lazy"`** (Part A's structural fix replaces it; lazy on the active image would harm LCP).
- [ ] **No `<img>` in `PublicMediaCard.jsx`** (not modified).
- [ ] **No `<img>` above-the-fold** elsewhere accidentally got `loading="lazy"` (no `Navbar.jsx` or similar).
- [ ] `npm run lint` clean — no new issues vs `main` baseline.
- [ ] `npm run build` succeeds.
- [ ] PR description contains: `Production touch: no`; self-review checklist; test plan; `Closes #114`; Claude Code footer; explicit note about the 12-vs-8 count discrepancy from the issue body.
- [ ] Outcomes-log row appended.
- [ ] Session report written.

## PR shape requirements

- **Branch name**: `fix/issue-114-image-lazy-loading-sweep`
- **Title**: `fix(#114): render only active+next hero image, add loading="lazy" to below-fold sweep`
- **Body**: summary (call out the 12-not-8 discrepancy explicitly); `Production touch: no`; self-review checklist; test plan; `Closes #114`; Claude Code footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review pass; draft otherwise.

## Outcomes-log row

Append at the bottom of `docs/phase-2/agent-friendly-outcomes.md`:

| Column | Value |
|---|---|
| Issue # | `114` |
| Filed agent-friendly? | `yes` |
| Filed severity | `nice` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-3.C — seventh autonomous run; first concurrent-batch run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary. Call out the 12-vs-8 count discrepancy from the issue body explicitly (a small instance of the codebase-fact-vs-stated-fact pattern from session 06). Any file that didn't match the issue body's expectation gets a brief note. |

## Session report

Write to `docs/phase-2/12-frontend-f3-C-issue-114-report.md`. Mirror sessions 06-09's shape. Key sections:

- **Process notes** — pair-mode-would-have-surfaced moments. The 12-vs-8 discrepancy is the most likely; others might surface from the 10-file sweep (a file with zero `<img>`, a file with already-lazy `<img>`, etc.).
- **What surprised you** — anything the brief didn't anticipate.
- **F-3 cumulative observation** — you're one of three concurrent. Note: did the parallel-mode framing feel adequate? You're the broadest-scope of the three (11 files vs 1 vs 1); the F-3 methodology question for your run specifically is whether scale + concurrency together change the outcome.

## Begin by

1. Symlink `frontend/node_modules` from main checkout.
2. Read the inputs in order.
3. Confirm the 12-vs-8 count in `HeroSection.jsx` matches the brief.
4. Confirm each of the 10 sibling files exists and contains `<img>` tags (skip-with-note any that don't).
5. Apply Part A to `HeroSection.jsx`.
6. Apply Part B to each of the 10 files (or 9, or 8 — however many actually have `<img>` tags).
7. Run `npm run lint` and `npm run build`. Iterate until clean.
8. Self-review checklist.
9. Open the PR.
10. Append the outcomes-log row.
11. Write the session report.
12. **Stop.**
