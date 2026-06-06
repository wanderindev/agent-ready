# Phase 2 — Session 11: Frontend autonomous-agent experiment, F-3.B — issue #115 (PublicMediaCard nested-button a11y)

## Identification

You are the **autonomous agent** running **F-3.B** of the frontend autonomous-agent experiment, in PIC's Phase 2 fix-execution phase. Launched via the Agent tool with `isolation: "worktree"`. You run in an isolated git worktree branched from `main`; the orchestrator is **not in the loop** during your run.

**F-3 is the parallelism phase.** You are one of three running concurrently — F-3.A (issue #113, ContactConfirmation `from` validation), F-3.B (this run, #115), F-3.C (#114 lazy-loading sweep). You don't see them; they don't see you. F-2's four sequential clean-merge runs argue per-agent quality should hold; F-3 measures the operational cost of parallelism.

## Three operational notes (folded in from F-2)

1. **Worktree `node_modules` resolution.** Symlink: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`. Zero diff impact.
2. **All codebase-fact claims below have been verified at brief-writing time.** Source-contradicts-brief: follow source, surface in PR.
3. **Issue-body count interpretation, pre-resolved.** This is **one file** (`PublicMediaCard.jsx`), **one structural change** (restructure the nested `<button>` → `<div role="button">` pattern into siblings). The fix is a JSX-only refactor — no state, no logic, no API changes.

## Parallel-mode notes

1. **Three F-3 agents are running concurrently on different code files.** Yours: `frontend/src/components/public/PublicMediaCard.jsx`. F-3.A: `ContactConfirmation.jsx`. F-3.C: `HeroSection.jsx` + 10 other component files (none of which is `PublicMediaCard.jsx`, even though `PublicMediaCard.jsx` is mentioned in F-3.C's brief as the **canonical example of correctly-lazy-loaded images** — F-3.C reads it but does not modify it). Expect no code-merge conflicts.
2. **`docs/phase-2/agent-friendly-outcomes.md`** is the one file all three F-3 agents will touch (appending one row each). The last two PRs to merge will show conflicts on that file. **Expected; operator resolves.** Append your row to whatever state of the file is in your worktree and stop. Do NOT anticipate or resolve the conflict.
3. **Your session-report number is 11.** Report path: `docs/phase-2/11-frontend-f3-B-issue-115-report.md`.

## What this experiment is testing

Same as F-3.A: does per-agent quality hold under parallelism? F-3.B specifically tests an **a11y / JSX-restructure** shape — neither a sweep nor a defensive-coding fix nor a structural-add. The methodology question for this run: does the brief-tightening discipline cover restructure-shapes too?

If you get stuck, open a draft PR with a comment and stop.

## Read these first, in order

1. **Issue #115** — `gh issue view 115`. The full body. Pay attention to the **Fix** section's specific restructure recommendation.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #115. The "accessibility bounded pass" framing matters: the issue is filed as a single representative a11y defect; the broader site is acceptable.
3. **`frontend/src/components/public/PublicMediaCard.jsx`** (full file — ~70 lines) — the target. Verified structure:
   - Outer wrapper at line 22: `<button onClick={() => onClick(item)} className="...">` (the whole card is a button).
   - Thumbnail block (lines 27-42): `<img>` or fallback `<div>`, inside the outer button.
   - **Nested invalid markup** at lines 43-51: `<div role="button" tabIndex={-1} onClick={handleDownload}>` containing an `<ArrowDownTrayIcon>`. This is the keyboard-inaccessible download control.
   - Info block (lines 55+): title and license/source spans.
4. **`docs/phase-2/06-frontend-f1-issue-117-report.md`** through **`09-frontend-f2-3-issue-106-report.md`** — F-1/F-2 session reports. Skim.
5. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log.
6. **`docs/methodology/cross-session-register.md`** — append only if a genuine cross-session decision crystallizes.
7. **`.claude/settings.json`** — fence rules.
8. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope

- **Restructure `PublicMediaCard.jsx`** so the card and the download control are **siblings**, not nested:
  - The outer wrapper becomes a non-button clickable container — a `<div>` with `role="button"`, `tabIndex={0}` (so it IS in the tab order, unlike the current download `tabIndex={-1}`), `onClick`, and `onKeyDown` handlers for keyboard support (Enter and Space, as a button would have).
  - The download control becomes a real `<button>` (not a `<div role="button">`) with `aria-label="Download {item.title}"` (or similar; English text — admin-style messages, but this is public-facing, so include the item title for screen-reader users). It gets a real tab stop (no `tabIndex={-1}`).
  - The download `<button>` must `e.stopPropagation()` inside its onClick (the current `handleDownload` already does this — keep it).
- **No state changes, no data-flow changes.** The `onClick` prop, `item` prop, `getDownloadUrl` import, the `failed` state, the `handleDownload` function — all stay.
- **Keep the visual appearance identical** (Tailwind classes preserved). The download control's visual treatment (absolute positioning, opacity-0 → opacity-100 on hover, etc.) carries over.
- **Run `npm run lint` and `npm run build`** — both clean.
- **One PR** containing the single-file restructure.

### OUT of scope (do NOT touch)

- **Anything outside `frontend/src/components/public/PublicMediaCard.jsx`** (plus the docs files).
- **A new accessibility test** — the issue body says manual verification (keyboard nav + HTML validator) is the expected check. Don't introduce test infrastructure.
- **The detail modal** (`PublicMediaDetail.jsx` or wherever the card's `onClick` lands) — it stays untouched. The card's external contract (call `onClick(item)`) is unchanged.
- **Other a11y improvements** elsewhere in the codebase — out of scope. The issue's *Scope note* says the broader site's a11y posture is acceptable; this card is the one defect filed.
- **No new dependencies.** No `.env*`. No `gh pr merge`.

## Default rules for likely ambiguities

- **Card outer element** — use a `<div>` with `role="button"` + `tabIndex={0}` (NOT `<a>` or `<button>`). `<a>` would imply navigation; `<button>` re-introduces the original problem.
- **Keyboard handler** — implement `onKeyDown` that triggers the same `onClick` on `Enter` and `Space` (and calls `preventDefault()` on `Space` to avoid page-scroll). This is the standard `role="button"` pattern.
- **Download `<button>` placement** — keep it absolutely positioned over the thumbnail (same Tailwind classes: `absolute bottom-1.5 right-1.5 ...`). Same visual treatment as today.
- **Download `<button>` `type` attribute** — explicit `type="button"` (to avoid implicit-submit behavior).
- **`aria-label` text** — use `${t('publicMedia.download')} ${item.title}` if `useTranslation` is already imported; otherwise hardcode `Download ${item.title}` in English (the issue body doesn't require i18n; localizing the aria-label is a stretch we're not asking for). Check the file for an existing `useTranslation` import: if present, use it; if absent, hardcode English. **Verify against source rather than guessing.**
- **`onClick` on the download `<button>`** — same `handleDownload` function as today. Its `e.stopPropagation()` prevents the card's `onClick` from also firing.
- **Whether to move the JSX comment** (`{/* Download overlay icon */}`) — keep it next to the new `<button>` for the same explanatory role.
- **Whether to break out a `KeyDown` helper function** — your call. Inline is fine for this scope; a helper is fine if it reads cleaner. Pick one, don't agonize.

## Self-review checklist (before opening the PR)

- [ ] One code file modified (`PublicMediaCard.jsx`) plus the two docs files.
- [ ] Outer wrapper is now a `<div>` (not a `<button>`) with `role="button"`, `tabIndex={0}`, `onClick`, `onKeyDown`.
- [ ] Download control is now a real `<button type="button">` with `aria-label`.
- [ ] The download `<button>` is a sibling of (not nested inside) the card-click handler — i.e., no interactive element is inside the card's click-handler element... wait, restate: the new structure has the card wrapper containing the thumbnail (img / fallback div) AND the download button as siblings, with the card wrapper itself being the clickable container. The download button still visually overlays the thumbnail (absolute positioning) but is NOT a child of the same interactive element that the card's click handler is on. The card wrapper IS the click target; the download button is a separate interactive element inside it. **This is the "button-not-nested-in-button" fix**: the outer is a `<div role="button">`, not a `<button>`, so the inner `<button>` is structurally valid.
- [ ] `handleDownload` still calls `e.stopPropagation()`.
- [ ] Visual appearance unchanged (Tailwind classes preserved).
- [ ] Keyboard test (manual or describe-the-expected-behavior in the PR body): pressing Tab focuses the card; Enter or Space triggers card `onClick`; Tab again focuses the download button; Enter or Space triggers download.
- [ ] `npm run lint` clean — no new issues vs `main` baseline.
- [ ] `npm run build` succeeds.
- [ ] PR description contains: `Production touch: no`; self-review checklist; test plan; `Closes #115`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report written.

## PR shape requirements

- **Branch name**: `fix/issue-115-publicmediacard-button-nesting`
- **Title**: `fix(#115): restructure PublicMediaCard to fix nested-button a11y defect`
- **Body**: summary; `Production touch: no`; self-review checklist; test plan; `Closes #115`; Claude Code footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review pass; draft otherwise.

## Outcomes-log row

Append at the bottom of `docs/phase-2/agent-friendly-outcomes.md`:

| Column | Value |
|---|---|
| Issue # | `115` |
| Filed agent-friendly? | `yes` |
| Filed severity | `nice` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-3.B — sixth autonomous run; first concurrent-batch run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary. Restructure ambiguities: any decisions about the `<div role="button">` vs `<a>` vs `<button>` outer wrapper, the keyboard handler shape, the `aria-label` text source. |

## Session report

Write to `docs/phase-2/11-frontend-f3-B-issue-115-report.md`. Mirror sessions 06-09's shape. Key sections:

- **Process notes** — pair-mode-would-have-surfaced moments. Restructure ambiguities are likely candidates.
- **What surprised you** — codebase-fact contradictions; brief-spec gaps for the restructure shape.
- **F-3 cumulative observation** — you're one of three concurrent. Note: did the parallel-mode framing feel adequate? F-3.A and F-3.C are working on different shapes (1-line input validation; multi-file lazy-load sweep) at the same time as you (JSX restructure). The three together stress-test whether the brief-template generalizes across shape and concurrency simultaneously.

## Begin by

1. Symlink `frontend/node_modules` from main checkout.
2. Read the inputs in order.
3. Confirm `PublicMediaCard.jsx`'s structure (outer button at line 22, nested div role-button at line 43-51).
4. Plan the restructure (note variations the brief leaves open: helper-function-for-keydown vs inline; existing useTranslation import vs hardcoded English aria-label).
5. Apply the JSX restructure.
6. Run `npm run lint` and `npm run build`. Iterate until clean.
7. Self-review checklist.
8. Open the PR.
9. Append the outcomes-log row.
10. Write the session report.
11. **Stop.**
