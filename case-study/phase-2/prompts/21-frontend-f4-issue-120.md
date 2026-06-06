# Phase 2 — Session 21: Frontend autonomous-agent experiment, F-4.I — issue #120 (OutlineEditor non-functional)

## Identification

You are the **autonomous agent** running **F-4.I**, the last of four concurrent Wave 2 agents in F-4. F-4.I is also the **final F-4 run** — your PR closes the experiment at N=16.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body says "EditDrawer OutlineEditor is non-functional — editable textarea with no Save, dead handleSave would blank article content." **Verified**: `frontend/src/components/admin/EditDrawer.jsx` line 654+: `function OutlineEditor({ record, token, onClose, requestCloseRef })`. It accepts `requestCloseRef` (unlike ResearchEditor — interesting), suggesting the parent ALREADY wires it for OutlineEditor. The `handleSave` behavior is broken — the issue body claims it would "blank article content"; verify the exact failure mode by reading the function.

## Parallel-mode notes (CRITICAL)

Wave 2: you (F-4.I) + F-4.F (#116, App.jsx + deletes) + F-4.G (#118, ResearchEditor at lines 40-117) + F-4.H (#119, hook + AdminLayout).

**Your file ownership**: you may modify ONLY the `OutlineEditor` function (line 654+ to wherever it ends) inside `EditDrawer.jsx`. Do not modify any other sub-component. Specifically:
- DO NOT touch `ResearchEditor` (lines 40-117 — F-4.G's territory).
- DO NOT touch `ArticleEditor`, `SuggestionEditor`, `useResizableDrawer`.
- READ-ONLY access to those sections (e.g., to mirror ArticleEditor's `handleSave` pattern).

**Shared imports**: if your fix needs a new import at the top of `EditDrawer.jsx`, that line MAY collide with F-4.G's imports. Conflict resolves operator-side per option (b). Don't anticipate.

F-4.F owns App.jsx. F-4.H creates a new hook + modifies AdminLayout.jsx. **No overlap with EditDrawer.jsx.**

## Agent-vs-brief disagreement taxonomy

Three shapes. For this brief, all three are realistic:

- **(2)**: the issue body's claim that handleSave "would blank article content" might be wrong if the code has been updated since the audit. Follow the source.
- **(3)**: if the Save logic depends on a backend endpoint that doesn't exist yet or has a different signature than expected, follow the brief's "make Save work" goal AND flag the backend assumption.

## What this experiment is testing

F-4.I tests a **functional fix to a broken admin component**: the editor has a textarea and a (dead) Save button; the fix is to wire Save correctly so admins can actually edit outlines. Concrete and high-value.

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #120** — `gh issue view 120`. The full body. The "would blank article content" claim is important.
2. **`frontend/src/components/admin/EditDrawer.jsx`** — read end-to-end. Focus on:
   - `OutlineEditor` (line 654+, your target). Read until you find its end.
   - `ArticleEditor.handleSave` (around line 234) — the canonical Save pattern.
   - The parent component that renders `<OutlineEditor>` — find via search; this is where the `requestCloseRef` is wired in. Likely line 1256 based on earlier inspection.
3. **`frontend/src/services/admin.js`** — find the admin service method for saving outlines (likely `updateOutline` or `saveOutline` or similar). Verify the signature.
4. **`docs/pilot/phase-1-area-6-report.md`** — the audit that surfaced #120.
5. Prior session reports — skim.
6. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **In `OutlineEditor` (line 654+ of EditDrawer.jsx) ONLY**: implement a working `handleSave` that:
  1. Reads the current outline content from local state.
  2. Calls the appropriate admin service method (e.g., `adminService.updateOutline(token, record.id, outline)` — verify the actual method name and signature in `services/admin.js`).
  3. On success, calls `onClose()` to close the drawer.
  4. On error, displays the error to the user (via the existing toast pattern from F-1 / PR #148 — `showToast({type: 'error', ...})` is now standard).
  5. **Does NOT** mutate or save anything that would blank article content. If the dead handleSave was doing that, replace it with the correct behavior (save the OUTLINE, not the article content).
- **Add an `isDirty()` pattern** mirroring ArticleEditor (lines 139-200) — useRef for the loaded snapshot, useCallback for isDirty, useCallback for requestClose with confirm prompt. The `requestCloseRef` is already wired (per the function signature) — populate it.
- **Add a working Save button** if one doesn't exist; if the dead one exists, wire it to call the new handleSave.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **ResearchEditor, ArticleEditor, SuggestionEditor** (other sub-components).
- **Other broken admin behaviors** elsewhere.
- **Backend changes** — if the admin service method doesn't exist or has a different shape, STOP and flag in draft PR.
- **No new dependencies.**

## Default rules for likely ambiguities

- **The admin service method name**: read `services/admin.js` and use whatever name exists (e.g., `updateOutline`, `saveOutline`, `updateArticleOutline`). If multiple candidates exist, pick the one matching the function naming pattern of other editors' Save methods.
- **Confirm-prompt wording for `requestClose`**: `"You have unsaved outline edits. Discard them?"` — mirror ResearchEditor's planned wording (consistent voice across editors).
- **Toast pattern**: `import { showToast } from ...` — the canonical Toast hook from F-1 is already wired into the admin pages. Use whichever import path the file already uses (or add it if the OutlineEditor section doesn't import it yet — that's a small per-file addition).
- **What if the dead `handleSave` is referenced from elsewhere in the file?** — examine all callers; rewrite them too if minimal. If the change cascades widely, flag in draft PR.

## Self-review checklist

- [ ] Only the `OutlineEditor` function (line 654+ to its end) modified.
- [ ] `handleSave` calls the correct admin service method with the outline payload.
- [ ] On success: `onClose()`. On error: toast.
- [ ] `isDirty()` + `requestCloseRef.current = requestClose` wired.
- [ ] No mutation that would blank article content (verified by tracing what `handleSave` actually does).
- [ ] **ResearchEditor section (lines 40-117) is unchanged** — verify by diff.
- [ ] Other sub-components unchanged.
- [ ] `npm run lint` clean.
- [ ] `npm run build` succeeds.
- [ ] PR description: production touch line; explanation of what the dead handleSave was doing and how the fix differs; mention you read but did not modify ResearchEditor; test plan; `Closes #120`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/21-frontend-f4-I-issue-120-report.md`.

## PR shape

- **Branch**: `fix/issue-120-outlineeditor-functional-save`
- **Title**: `fix(#120): implement OutlineEditor handleSave (was dead and would blank article content)`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `120` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-admin` |
| Agent attempted? | `yes` (F-4.I — sixteenth autonomous run; closes the F-1→F-4 experiment at N=16) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary. Final F-4 run; describe the dead-handleSave fix concretely. |

## Session report

`docs/phase-2/21-frontend-f4-I-issue-120-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs — focus on EditDrawer.jsx end-to-end (especially OutlineEditor at 654+ and ArticleEditor at 121-401 as the canonical pattern).
3. Verify the admin service method for saving outlines.
4. Implement handleSave + isDirty/requestClose for OutlineEditor.
5. Lint + build.
6. Self-review (especially "ResearchEditor unchanged").
7. Open PR.
8. Outcomes-log row + session report.
9. **Stop.**
