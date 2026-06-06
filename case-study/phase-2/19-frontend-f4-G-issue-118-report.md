# Session 19 — Frontend F-4.G: Issue #118 (ResearchEditor unsaved-changes guard)

## Identification

- **Run**: F-4.G — fourteenth autonomous run; first **same-file concurrent run** with F-4.I (#120).
- **Wave**: F-4 Wave 2 (concurrent with F-4.F #116, F-4.H #119, F-4.I #120).
- **Issue**: #118 — *EditDrawer ResearchEditor has no unsaved-changes guard — research edits discarded silently.*
- **Label**: `agent-friendly`, `code-quality:moderate`.
- **Track**: `frontend-admin`.
- **Branch**: `fix/issue-118-researcheditor-unsaved-changes-guard`.

## Scope as briefed

Mirror the existing `isDirty()` + `requestClose()` + `requestCloseRef` pattern (used by `ArticleEditor`, `SuggestionEditor`, `OutlineEditor`, `EduSuggestionEditor`) onto `ResearchEditor` so backdrop-click / Escape / X-button / Cancel-button all prompt before discarding unsaved research-document edits.

- **IN**: `ResearchEditor` (lines 40-117) + the minimum parent-wiring change in `EditDrawer` (lines 1226-1247).
- **OUT**: every other sub-component in `EditDrawer.jsx`. OutlineEditor (line 654+) was F-4.I's territory; read-only inspected, not touched.

## What landed

**`ResearchEditor` (lines 40-145 in post-edit file):**

- Accepts a new `requestCloseRef` prop (parity with the four sibling editors).
- `savedSnapshot = useRef('')` captures the loaded `content_html` once the API call resolves.
- `isDirty()` (`useCallback`) compares current `contentHtml` against `savedSnapshot.current`.
- `markClean()` (`useCallback`) updates the snapshot to current value on save success.
- `requestClose()` (`useCallback`): if dirty, opens an inline amber-banner confirm (mirrors `SuggestionEditor`'s pattern); otherwise calls `onClose()` directly.
- A `useEffect` assigns `requestCloseRef.current = requestClose` so the drawer parent can invoke it on X-button / backdrop / Escape.
- The footer **Cancel button** now calls `requestClose` (was `onClose` directly).
- `handleSave` calls `markClean()` before `onClose()`.

**`EditDrawer` parent (the lines-1223+ region; outside the lines-40-117 ownership band but explicitly permitted by the brief's "minimum surrounding change" clause):**

- New `researchRequestCloseRef = useRef(null)`.
- `handleClose` adds a `Research` branch matching the four sibling editors' shape:
  ```
  } else if (recordType === 'Research' && researchRequestCloseRef.current) {
    researchRequestCloseRef.current();
  }
  ```
- `renderEditor()` passes `requestCloseRef={researchRequestCloseRef}` to `<ResearchEditor>`.

**Confirm-prompt wording**: `"You have unsaved research edits. Discard them?"` — the exact string suggested in the brief's "Default rules" section.

**Confirm UX shape**: inline amber banner (copying SuggestionEditor's pattern) rather than `window.confirm()`. The brief mentioned `window.confirm()` as one option but the existing codebase pattern across the four siblings uses inline banners; consistency with the existing pattern won. The banner offers "Cancel" (dismisses the banner, keeps editing) and "Discard & Close" (calls `onClose()`).

## Diff stats

```
frontend/src/components/admin/EditDrawer.jsx | 59 ++++++++++++++++++++++++++--
1 file changed, 55 insertions(+), 4 deletions(-)
```

- Hunks at lines 37, 50, 89, 96 (all inside ResearchEditor 40-117) + hunks at lines 1227, 1237, 1244 (inside the parent's wiring region).
- **No hunks** in the OutlineEditor function (line 654+) — confirmed by `git diff` line-range inspection.
- **No hunks** in ArticleEditor, SuggestionEditor, EduSuggestionEditor, EduResearchEditor, EduMaterialEditor, PlaceholderEditor, useResizableDrawer.

## Verification

- `npm run lint`: **47 problems** (33 errors, 14 warnings) — identical to `main` baseline. `EditDrawer.jsx` errors that surface in the report (704, 748, 1230) are all pre-existing, inside other sub-components (OutlineEditor, parent's unused-`recordType` arg in `PlaceholderEditor`'s arg list); none are introduced by this PR.
- `npm run build`: **2336 modules**, 4.25s — clean, matches the baseline that F-4.A through F-4.E reported.

## Ambiguity-resolution events

Zero in-session. Two within-band decisions whose right answer was obvious:

1. **Confirm-prompt shape — `window.confirm()` vs inline banner.** The brief listed `window.confirm("You have unsaved research edits. Discard them?")` as the example but its "Default rules" section said "use this exact string or one of similar spirit." The four sibling editors all use an inline amber-banner pattern, not `window.confirm()`. Going with the codebase pattern matches "follow existing patterns in the codebase" (CLAUDE.md, Quality Standards). The brief's wording string is preserved verbatim inside the banner.
2. **`useRef` capture timing.** The brief said "use `useRef` to capture it once `getResearchDetail` returns." The ArticleEditor pattern uses a `stabilizingRef` because TipTap can normalize HTML on load and shift the snapshot. ResearchEditor uses the same `RichTextEditor` (TipTap). I considered porting the `stabilizingRef` machinery but chose the simpler `SuggestionEditor` pattern (snapshot at API return, no stabilization window) because (a) the brief said "mirror ArticleEditor's approach" but also "match SuggestionEditor's simpler reference per the issue body" — the issue body explicitly names SuggestionEditor as the simpler reference, and (b) ResearchEditor has only one field (`contentHtml`), not the multi-language multi-tag complexity that motivated stabilization in ArticleEditor. **Trade-off flagged**: if TipTap normalizes the loaded HTML and the user immediately tries to close without typing, they may see the false-positive "unsaved" banner. Operator may want to add a stabilization window in a follow-up if this surfaces.

## Self-review checklist

- [x] Only the `ResearchEditor` function (lines 40-117) modified inside `EditDrawer.jsx` (plus the explicitly-permitted parent-wiring change at lines 1226-1247).
- [x] `isDirty()` and `requestClose()` added, mirroring `ArticleEditor`/`SuggestionEditor`'s pattern.
- [x] `requestCloseRef` accepted as a prop and wired via `useEffect`.
- [x] Parent caller of `<ResearchEditor>` wired to pass `requestCloseRef` (minimal change, three hunks in the parent region).
- [x] **OutlineEditor section (line 654+) is unchanged** — verified by diff hunks list.
- [x] Other sub-components in EditDrawer.jsx are unchanged.
- [x] `npm run lint` clean (47 = 47 baseline).
- [x] `npm run build` succeeds (2336 modules).
- [x] Outcomes-log row appended.
- [x] Session report at `docs/phase-2/19-frontend-f4-G-issue-118-report.md`.

## Parallel-mode notes

Concurrent Wave 2 run with F-4.F (#116, App.jsx), F-4.H (#119, new file + AdminLayout.jsx), F-4.I (#120, OutlineEditor in same EditDrawer.jsx). **First autonomous run in the experiment with deliberate same-file overlap** — F-4.G's hunks are at lines 37-150 + 1275-1296; F-4.I's hunks (per the brief) are at line 654+. The two hunk regions are 500+ lines apart in a 1300-line file; git's three-way merge should auto-resolve.

Did not observe F-4.I in flight.

## Methodology data point

The brief-tightening list continues to generalize beyond Wave 1: F-4.G's brief pre-resolved every plausible ambiguity (exact lines, exact pattern to mirror, exact prompt wording, exact OUT-of-scope list, parent-wiring permission flagged). Zero ambiguity-resolution events; the only operator-flag-able call (banner-vs-window.confirm) was a near-trivial codebase-consistency decision.

Cumulative autonomous-run count after this PR: **14** (F-1, F-2.1, F-2.2, F-2.3, F-3.A, F-3.B, F-3.C, F-4.A, F-4.B, F-4.C, F-4.D, F-4.E, prior single-issue run, F-4.G).
