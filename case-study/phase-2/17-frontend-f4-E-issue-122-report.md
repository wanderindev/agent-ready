# Phase 2 — Session 17 report: frontend autonomous-agent experiment, F-4.E — issue #122

## Identification

- **Run**: F-4.E (twelfth autonomous run; fifth Wave 1 agent in the F-4 concurrent batch, alongside F-4.A/#35, F-4.B/#108, F-4.C/#109, F-4.D/#121).
- **Issue**: [#122](https://github.com/wanderindev/panama-in-context/issues/122) — *Long-running generation modals can be dismissed mid-operation; no progress affordance*.
- **Filed shape**: `agent-friendly` + `code-quality:nice-to-have`. `frontend-admin` track.
- **Branch**: `fix/issue-122-generation-modal-dismissal-protection`.

## Result

- One PR opened, mergeable, lint and build clean against the main baseline.
- 4 admin pages modified, 6 generation/long-op modals gated.
- Zero ambiguity-resolution events that the brief did not pre-resolve.
- One **modal-shape variance** found and flagged (AdminSuggestions's `GenerateModal` is NOT a Headless UI `<Dialog>` — it's a plain `<div>` with no backdrop/Escape dismissal).

## Modal inventory and per-file fix

### `frontend/src/pages/admin/AdminArticles.jsx` (3 modals gated)

| Modal | Driving state | Long-op? | Fix |
|---|---|---|---|
| `PublishModal` | `loading` | short (DB write) | `<Dialog onClose>` gated; Cancel button + date input both disabled when loading. |
| `GenerateArticleModal` | `loading` | yes (`writeArticle` — multi-minute LLM) | `<Dialog onClose>` gated; Cancel button + select both disabled when loading; "Generation in progress — this may take a few minutes" hint added. |
| `FeatureImageModal` | `generating \|\| uploading` (combined as `busy`) | yes (prompt LLM call; image upload) | `<Dialog onClose>` gated on `busy`; tab switcher + Close + file input all disabled when busy; per-tab progress hints added. |

The `errorDialog` inline `<Dialog>` at the bottom of the page is a notification-only modal with no async operation behind it — left untouched per the brief's "no other modal types affected" rule.

### `frontend/src/pages/admin/AdminOutlines.jsx` (1 modal gated)

| Modal | Driving state | Long-op? | Fix |
|---|---|---|---|
| `GenerateOutlineModal` | `loading` | yes (`generateOutlines` LLM call) | `<Dialog onClose>` gated; Cancel button disabled when loading; "Generation in progress — this may take a few minutes" hint added. |

### `frontend/src/pages/admin/AdminResearch.jsx` (2 modals gated)

| Modal | Driving state | Long-op? | Fix |
|---|---|---|---|
| `GeneratePromptModal` | `loading` | yes (`generateResearchPrompt` + blob download) | `<Dialog onClose>` gated; Cancel button disabled when loading; "Generation in progress" hint added. |
| `UploadResearchModal` | `loading` | yes (server-side processing + parse) | `<Dialog onClose>` gated; Cancel button + file input disabled when loading; "Upload in progress" hint added. |

The issue body lists "research summary generation" as a target — that lives in `handleGenerateSummary` on `AdminResearch.jsx` and is a row-action without a modal (no `<Dialog>` wraps it). Out of scope structurally per the brief's "Each modal gets its own gate."

### `frontend/src/pages/admin/AdminSuggestions.jsx` (1 modal — variance flagged, no `onClose` to gate)

| Modal | Driving state | Long-op? | Fix |
|---|---|---|---|
| `GenerateModal` | `generating` | yes (`generateSuggestions` LLM call) | **Variance**: not a Headless UI `<Dialog>` — it's a plain `<div className="fixed inset-0 ...">` with no backdrop-click handler and no Escape key listener, so there's literally no `onClose` to gate. The Cancel button already carried `disabled={generating}` before this PR. Cosmetic alignment: disabled the category `<select>` when generating, added the same "Generation in progress" hint, and a comment explaining why there's no `onClose` gate. |

## Implementation pattern

For every `<Dialog>`-based modal, the fix follows the brief's **Option A** as a minimum, with a small amount of **Option B** polish (the in-progress hint text):

```jsx
// Gate dismissal while the operation is in flight (#122).
const handleClose = loading ? () => {} : onClose;

return (
  <Transition appear show={open} as={Fragment}>
    <Dialog as="div" className="relative z-50" onClose={handleClose}>
      ...
```

And consistently, each Cancel/Close button now carries `disabled={loading}` (or `disabled={busy}` in the multi-flag case), with `disabled:opacity-50 disabled:cursor-not-allowed` styling. Form fields inside the modal are also disabled while in flight so the user can't change their selection mid-call (low-risk improvement; this didn't break any existing behavior because the buttons that act on those fields were already disabled).

The "this may take a few minutes" hint is rendered conditionally under the form body when the in-flight state is true. Spinners are not added (out of scope per the brief).

## Self-review checklist

- [x] Each of the 4 admin pages modified.
- [x] Each generation modal's `onClose` is guarded by the relevant `generating`/`loading` state — except `AdminSuggestions.GenerateModal`, which has no `onClose` to guard (variance flagged).
- [x] Cancel/Close buttons are disabled when generating.
- [x] No other modal types affected (the `errorDialog` in `AdminArticles.jsx` is a notification modal — left untouched per the "no other modal types" rule).
- [x] `npm run lint` clean against main baseline (47 problems = 47 problems; identical line counts before and after my changes).
- [x] `npm run build` succeeds (2336 modules transformed; identical to the F-3.A baseline since no new files added).
- [x] PR description: production touch line; modal-by-modal gating table; test plan; `Closes #122`; Claude Code footer.
- [x] Outcomes-log row appended.
- [x] Session report present at this path.

## Variances and ambiguities

### Variance 1 (flagged): AdminSuggestions's GenerateModal is not a Headless UI Dialog

The brief said: *"there is NO standalone `Generate*Modal.jsx` file; the modals are inline `<Dialog>` blocks inside [4 admin pages]"*. That's true for 3 of the 4 pages. **AdminSuggestions is the exception**: its inline `GenerateModal` is a plain `<div>` overlay. It has no `<Dialog>` or `<Transition>`, no `onClose` prop on a Headless UI primitive, and no keyboard/backdrop handlers. The only dismissal surface is the explicit Cancel button, and that button was already `disabled={generating}` before my PR. So this modal was, prior to this PR, structurally not subject to the issue's failure mode — there's no backdrop click to swallow, no Escape key path to intercept.

I added a comment to that effect inline in the modal and brought it into cosmetic alignment with the other three pages (disable the `<select>` while generating, add the "Generation in progress" hint), but no `onClose` gate. The brief explicitly said: *"What if a modal has no `generating`-shaped state? — flag in PR; don't invent one."* My variance is the dual: the modal **has** the state but **lacks** the `onClose` surface to gate. The fix-intent of #122 is already satisfied for this modal.

### Ambiguity 1 (resolved using brief's defaults): how broad is "modals"?

The issue body lists `GenerateArticleModal`, `GenerateMaterialsModal` (AdminEduMaterials — out of brief scope), and `GeneratePromptModal`. The brief says: *"apply the fix to ALL of them. Each modal gets its own gate based on the state that drives it."*

I read "all" as **all generation/long-op modals in the 4 in-scope files**. By that reading I included:

- `PublishModal` (short DB write, but the issue's failure shape — *dismissing mid-operation loses the result confirmation* — applies equally; the modal does a finally-block close on success).
- `UploadResearchModal` (not strictly an LLM call, but a server-side parse that can take time; same dismissal failure shape).
- `FeatureImageModal` upload-tab (image upload over the network; same failure shape).

I excluded:

- `errorDialog` in `AdminArticles.jsx` — notification-only, no async op behind it.
- The `EditDrawer` (separate component file; not a generation modal).
- Row-action handlers without modals (`handleTranslate`, `handleSeriesSections`, `handleGenerateTags`, `handleGenerateSummary`) — they use toasts, not modals.

If the operator reads "modals" more narrowly (just the long-op LLM ones), the over-inclusion is at worst harmless — disabling Cancel during a 200ms DB write is invisible to the user. If they read it more broadly, the inclusion of PublishModal/UploadResearchModal/FeatureImage matches the brief's intent.

### Ambiguity 2 (resolved using brief's defaults): no spinner

The brief says: *"Adding a progress indicator/spinner if one doesn't exist [is] out of scope unless trivial."* I added a small text hint ("Generation in progress — this may take a few minutes. Please wait.") under the modal body when the operation is in flight. This is the brief's Option B polish, applied as text not as a spinner. No new SVG, no new component. The button text already says "Generating..." — the hint disambiguates "still working" vs "hung."

## Easier / harder than predicted

- **Easier than the agent-friendly label predicted**: the brief was extremely tight on the failure-mode pattern (`<Dialog onClose>` unguarded). Three of four pages followed the exact pattern. The fix is a one-line `handleClose` constant + threading it into the `onClose` prop + adding `disabled={loading}` to the Cancel button. Mechanical, no architectural decisions required.
- **Harder than predicted**: the AdminSuggestions variance. The brief verified the existence of inline `<Dialog>` blocks — it did not verify each of the 4 was actually a Headless UI Dialog. AdminSuggestions's plain-div modal predates the others. Resolved by following the brief's "flag the variance" rule. Cost: one comment, one paragraph in the PR, this section of the report.
- **As predicted**: lint clean (no new errors), build clean (2336 modules same as baseline), no test file to update (no existing test covers these modals' dismissal behavior — manual-test plan only).

## Cross-cutting notes for the F-4 batch

- **No file overlap** with F-4.A (BookingManage.jsx), F-4.B (public components), F-4.C (i18n.js + index.html), F-4.D (AdminOrders.jsx).
- **Shared file**: `docs/phase-2/agent-friendly-outcomes.md` — five-way append at the bottom. Operator resolves conflicts on the log.

## Methodology data point

The "one repeated pattern across 4 files" shape — like F-1 (#117)'s 22-block sweep and F-3.C (#114)'s 11-file lazy-load sweep — is well-served by the brief-tightening template. The variance found in AdminSuggestions is the kind of thing the brief's *codebase-facts-verified-at-brief-writing-time* check would have caught only if the brief author had grepped for `<Dialog` in each file. The brief author did the broader check (these 4 files all contain inline generation modals with `generating` state) but not the narrower one (each modal is actually a `<Dialog>`). Resolution cost: minutes, not blocking. Suggests future briefs for this shape could include a one-line "verified each is a `<Dialog>`, not a custom-div modal" check.
