# Phase 2 — Session 19: Frontend autonomous-agent experiment, F-4.G — issue #118 (ResearchEditor unsaved-changes guard)

## Identification

You are the **autonomous agent** running **F-4.G**, one of four concurrent Wave 2 agents in F-4.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body says "EditDrawer ResearchEditor has no unsaved-changes guard." **Verified**: `frontend/src/components/admin/EditDrawer.jsx` is a single ~1309-line file containing multiple sub-components. **ResearchEditor lives at lines 40-117** (`function ResearchEditor({ record, token, onClose })`). It has `setContentHtml`/`contentHtml` state and a `handleSave` at line 59, but **no `isDirty()` callback and no `requestClose` pattern** — unlike its siblings `ArticleEditor` (lines 121-401, has isDirty at line 139-144 + requestClose at line 194-200) and `SuggestionEditor` (lines 407+, has the same pattern at lines 422-475).

## Parallel-mode notes (CRITICAL — read carefully)

Wave 2 has 4 concurrent agents. **TWO of them modify `EditDrawer.jsx`**: you (F-4.G, ResearchEditor at lines 40-117) and F-4.I (#120, OutlineEditor at line 654+). These sections are **hundreds of lines apart**; git's three-way merge handles non-adjacent same-file edits trivially.

**Your file ownership**: you may modify ONLY the `ResearchEditor` function (lines 40-117). Do not modify any other sub-component in `EditDrawer.jsx`. Specifically: do not touch `ArticleEditor` (lines 121-401), `SuggestionEditor` (lines 407+), `OutlineEditor` (line 654+), or `useResizableDrawer` (lines 9-37). If you need to read those sections (e.g., to mirror `ArticleEditor`'s `isDirty` pattern), READ-ONLY.

**Shared imports**: if your fix needs a new import at the top of `EditDrawer.jsx`, that import line MAY collide with F-4.I's needs. The conflict, if it happens, is operator-resolved at merge time (option (b) — accept conflicts as routine). Don't try to anticipate.

F-4.F (#116) modifies App.jsx. F-4.H (#119) creates a new file `useBeforeUnload.js` hook + modifies AdminLayout.jsx. **No overlap with EditDrawer.jsx.**

## Agent-vs-brief disagreement taxonomy

Three shapes. Most likely for this brief: (3) — if mirroring ArticleEditor's `isDirty`+`requestClose` pattern requires changes to a SHARED upstream (e.g., a parent component that passes `requestCloseRef`), follow the brief's intent (apply the pattern locally to ResearchEditor) AND flag the upstream-coordination need.

## What this experiment is testing

F-4.G tests the brief-template against an **a11y/UX safety fix in a shared file**: adding the existing `isDirty` pattern to a sub-component that's missing it. The canonical pattern is in the same file (ArticleEditor, lines 139-200).

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #118** — `gh issue view 118`.
2. **`frontend/src/components/admin/EditDrawer.jsx`** (full file — read end-to-end; pay attention to lines 40-117 (your target) and lines 121-401 (the canonical pattern in ArticleEditor)). Note: also peek at OutlineEditor at line 654+ — that's F-4.I's territory; you DO NOT modify it.
3. **`docs/pilot/phase-1-area-6-report.md`** — the audit that surfaced #118.
4. Prior session reports — skim.
5. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **In `ResearchEditor` (lines 40-117 of EditDrawer.jsx) ONLY**: add an unsaved-changes guard pattern mirroring `ArticleEditor` (lines 139-200):
  1. Track the **loaded** value of `contentHtml` (use `useRef` to capture it once `getResearchDetail` returns).
  2. Add an `isDirty()` callback that returns `true` when current `contentHtml` differs from the loaded snapshot.
  3. Add a `requestClose()` callback that, if dirty, shows `window.confirm("You have unsaved research edits. Discard them?")` and calls `onClose()` only if confirmed.
  4. Accept a new `requestCloseRef` prop (like ArticleEditor at line 121) and assign `requestCloseRef.current = requestClose` so the parent can invoke it.
  5. Inside `handleSave`, mark the snapshot clean (update the ref to current value, or set a `markClean` flag — mirror ArticleEditor's approach).
- **Pass `requestCloseRef` from the parent caller** of `ResearchEditor` — find where `<ResearchEditor ... />` is rendered (search `EditDrawer.jsx` for `<ResearchEditor`); add the `requestCloseRef` prop wiring the same way the parent already wires it for `ArticleEditor` and `SuggestionEditor`. **If the parent is a region you're not allowed to touch** (e.g., far from your lines-40-117 ownership), include the minimum surrounding change with a clear comment, and flag in PR description.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **OutlineEditor** (F-4.I's territory).
- **ArticleEditor, SuggestionEditor** — they already have the pattern.
- **Shared/foundation refactoring** (e.g., extracting `useUnsavedChangesGuard` into a shared hook). Out of scope; future PR if desired.
- **No backend changes. No new dependencies.**

## Default rules for likely ambiguities

- **`useRef` for the loaded snapshot vs `useState`** — match ArticleEditor's choice. (Likely `useRef` for the captured value + `useCallback` for `isDirty`.)
- **Confirm-prompt wording** — `"You have unsaved research edits. Discard them?"` matches the operator-confirmation tone established in this codebase. Use this exact string or one of similar spirit.
- **Where does the parent invoke `requestCloseRef.current()`?** — the parent (probably the drawer's close handler or backdrop-click handler) calls it instead of calling `onClose` directly. Mirror existing wiring for ArticleEditor.
- **What if ResearchEditor renders inside a region of EditDrawer that already routes through `requestCloseRef`?** — verify the wiring; you may only need to assign `requestCloseRef.current` and not touch the parent.

## Self-review checklist

- [ ] Only the `ResearchEditor` function (lines 40-117) modified inside `EditDrawer.jsx`.
- [ ] `isDirty()` and `requestClose()` added, mirroring `ArticleEditor`'s pattern.
- [ ] `requestCloseRef` accepted as a prop and wired.
- [ ] Parent caller of `<ResearchEditor>` wired to pass `requestCloseRef` (minimal change, flagged if it extends beyond your lines).
- [ ] **OutlineEditor section (line 654+) is unchanged** — verify by diff.
- [ ] Other sub-components in EditDrawer.jsx are unchanged.
- [ ] `npm run lint` clean.
- [ ] `npm run build` succeeds.
- [ ] PR description: production touch line; explanation of which lines you modified; mention that you read but did not modify OutlineEditor; test plan; `Closes #118`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/19-frontend-f4-G-issue-118-report.md`.

## PR shape

- **Branch**: `fix/issue-118-researcheditor-unsaved-changes-guard`
- **Title**: `fix(#118): add unsaved-changes guard to ResearchEditor (EditDrawer)`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `118` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-admin` |
| Agent attempted? | `yes` (F-4.G — fourteenth autonomous run; first same-file concurrent run with F-4.I) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary; note whether the parent-wiring change was minimal or larger than expected. |

## Session report

`docs/phase-2/19-frontend-f4-G-issue-118-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs — focus on EditDrawer.jsx end-to-end, especially the canonical pattern at lines 121-200.
3. Apply the isDirty+requestClose pattern to ResearchEditor (lines 40-117).
4. Wire the parent caller.
5. Lint + build.
6. Self-review (especially the "OutlineEditor unchanged" check).
7. Open PR.
8. Outcomes-log row + session report.
9. **Stop.**
