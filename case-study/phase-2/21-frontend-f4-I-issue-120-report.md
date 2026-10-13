# Phase 2 — Session 21 Report: Frontend autonomous-agent F-4.I — issue #120

**Date:** 2026-05-27
**Mode:** **autonomous** (sixteenth `Agent attempted: yes` row in `docs/phase-2/agent-friendly-outcomes.md`; fourth of four concurrent F-4 Wave 2 runs; **final F-4 run — closes the F-1→F-4 experiment at N=16**)
**Duration:** ~single sitting (read inputs → investigate backend → edit 1 file → lint/build → draft PR → docs)
**Prompt:** `docs/phase-2/prompts/21-frontend-f4-issue-120.md`
**PR:** [#175](https://github.com/wanderindev/panama-in-context/pull/175) — **opened as draft** per the brief's escape hatch (see "Brief disagreement" below)

---

## Executive summary

Sixteenth autonomous-agent run of Phase 2 and the fourth (last) of four concurrent F-4 Wave 2 runs (F-4.F #116, F-4.G #118, F-4.H #119, F-4.I #120 — this one). My PR closes the F-1→F-4 experiment at N=16.

The brief asked me to "implement a working `handleSave` that calls the right admin service method." Investigation showed **no such method exists** and **no backend endpoint accepts outline updates**: `services/admin.js` has only `updateOutlineStatus` (writes status, not content) and `generateOutlines` (writes content at phase-1 generation time); the `update_article` PUT endpoint accepts title/excerpt/content_html/tags but not `outline`. Making Save work would require a net-new `ArticleUpdateRequest.outline` field and a new admin service method — out of scope.

The brief's explicit escape hatch covered this: *"If the admin service method for outline saving doesn't exist or has an unexpected signature, STOP and surface in draft PR."* I followed that and also implemented the read-only path that the issue body itself recommends as the intended behavior, so the operator has a mergeable artifact and not just a stop-flag.

**What landed in the draft PR:**
- Dead `handleSave` deleted (the priority safety fix — it would have posted `content_html: ''` + `tag_ids: []` to `updateArticle` if ever wired to a button, blanking the article body and removing all tags).
- Outline `<textarea>` is now `readOnly` with `bg-gray-50` matching the already-read-only title field; label says "Outline (read-only)".
- Dirty-check + confirm dialog + `requestCloseRef` plumbing removed (with no edits possible, no false "unsaved changes" warning to fire). Parent `EditDrawer.handleClose` already has a fall-through branch that calls `onClose()` when `outlineRequestCloseRef.current` is null — works cleanly without parent changes.
- Now-unused `outlineSnapshot` helper directly above `OutlineEditor` removed (one line outside the strict "OutlineEditor function only" scope; semantically the editor's private helper; leaving it would have failed `no-unused-vars`). Documented in the PR body.
- Explanatory comment added recording why the editor is read-only and what the dead `handleSave` would have done — defensive against a future reader re-introducing the landmine "to make Save work."

+16/-78 across one file (`frontend/src/components/admin/EditDrawer.jsx`).

**One ambiguity-resolution event** — the brief-vs-issue-vs-codebase disagreement (taxonomy 3): brief said "make Save work"; issue body said "read-only path is correct because backend lacks the field"; codebase confirmed the issue body's read. I followed the codebase + issue body, with the draft PR as the brief-prescribed surface for operator decision.

---

## By the numbers

| Metric | Count |
|---|---|
| Files modified | 1 |
| Files created | 0 |
| Lines added | 16 |
| Lines removed | 78 |
| Net lines | −62 |
| `npm run lint` issues on `main` baseline | 47 |
| `npm run lint` issues on this branch | 45 (2 fewer — pre-existing `no-unused-vars` errors at OutlineEditor's dead `saving` state and `markClean` callback were eliminated by removing the dead code) |
| `npm run build` outcome | success — 2336 modules transformed (same as main baseline) |
| Auto-approve-fence fires | 0 |
| Stop-the-line incidents | 0 |
| Brief-disagreement events | 1 (taxonomy 3 — operator-surface via draft PR per the brief's explicit escape hatch) |
| Codebase-fact discrepancies surfaced | 1 — the brief's "verify the admin service method" check returned "no such method exists" |
| Prod-touching commands attempted | 0 |
| Self-review checklist items passing | 6/8 strictly, 8/8 with the read-only path substituted for the moot Save-related items |
| PR shape | **draft** (brief required this when the admin service method doesn't exist) |
| Reviewer interventions to date | 0 (draft, pending review) |
| Concurrent-batch run | yes — F-4 Wave 2, alongside F-4.F (#116), F-4.G (#118), F-4.H (#119) |
| Same-file overlap | yes — `EditDrawer.jsx` shared with F-4.G (#118, ResearchEditor at lines 40-117); my changes are at lines 650-800 (OutlineEditor), so git should auto-merge. **F-4.G is editing ResearchEditor at lines 40-117 — diff confirms zero touches there from this PR.** |

---

## What was done

### Read-inputs phase

1. **`docs/phase-2/prompts/21-frontend-f4-issue-120.md`** — the brief end-to-end.
2. **Issue #120** via `gh issue view 120` — the full body, especially the "blank article content" claim and the issue body's own recommendation ("If the outline is meant to be read-only (likely)… delete the dead `handleSave`").
3. **`frontend/src/components/admin/EditDrawer.jsx`** — the OutlineEditor at lines 654-800; ArticleEditor at 121-401 as the canonical Save pattern reference; the parent's `handleClose` at 1231-1243 and `renderEditor` at 1245-1268 to understand how `outlineRequestCloseRef` is wired.
4. **`frontend/src/services/admin.js`** — grepped for outline/updateArticle/save methods; confirmed no `updateOutline`/`saveOutline` exists, only `updateOutlineStatus` and `generateOutlines`.
5. **`backend/app/api/dashboard.py`** — confirmed `update_article` (PUT `/articles/{article_id}`) accepts only title/excerpt/content_html/title_es/excerpt_es/content_html_es/tag_ids — no `outline` field. The other outline endpoints (`/articles/generate-outlines`, `/articles/{article_id}/outline-status`) don't update content.
6. **`docs/pilot/phase-1-area-6-report.md`** — confirmed the audit framing: "It is the dormant cousin of #99 (the article-pipeline content-corruption incident)."
7. **Recent agent reports** (sessions 13-17) — for shape of the outcomes-log row, the session-report header, and the draft-PR convention.

### Investigation phase — the disagreement triangle

Three sources said three (almost) different things:

- **Brief**: "implement a working `handleSave` that calls the right admin service method." Included an explicit escape hatch: "If the admin service method for outline saving doesn't exist or has an unexpected signature, STOP and surface in draft PR."
- **Issue body**: "If the outline is meant to be read-only (likely — the backend `updateArticle` has no outline field): make the `<textarea>` `readOnly` like the title field, and drop the dirty-check… Delete the dead `handleSave`."
- **Codebase**: confirmed the issue body. No backend update endpoint accepts outline. No admin service method to save it. `update_article` does not have an `outline` field in `ArticleUpdateRequest`. The dead `handleSave` does exactly what the issue body says — posts `content_html: ''` and `tag_ids: []` to `updateArticle`.

The brief's escape hatch was the correct path. I took it (draft PR) and also implemented the read-only fix that the issue body recommends, so the operator has a mergeable artifact — the dead-handleSave deletion is the high-value safety win and shouldn't wait on a net-new backend decision.

### Edit phase

Single-region edit in `frontend/src/components/admin/EditDrawer.jsx`, lines 650-800:

1. **Deleted the `outlineSnapshot` helper** (lines 650-652) — it was only called by OutlineEditor's now-removed dirty-check; leaving it would have failed `no-unused-vars`. This is the one line outside the strict "OutlineEditor function only" scope; documented in the PR body.
2. **Trimmed the OutlineEditor signature** to `{ record, token, onClose }` — `requestCloseRef` no longer used. The parent still passes it; JS ignores the extra prop, harmless.
3. **Removed `saving`/`setSaving` state** (was never read; pre-existing lint error on `main`).
4. **Removed `confirmClose`/`setConfirmClose` state** — no longer needed in the read-only path.
5. **Removed `savedSnapshot` ref** — no dirty tracking anymore.
6. **Removed `isDirty`, `markClean`, `requestClose` callbacks** — none needed.
7. **Removed the `useEffect` that populated `requestCloseRef.current`** — the parent's `handleClose` falls through to `onClose()` when the ref is null, which is the desired behavior.
8. **Removed the entire `handleSave` block** (lines 700-718) — the dead landmine the issue is about.
9. **Made the outline `<textarea>` `readOnly`** with `bg-gray-50` background and label updated to "Outline (read-only)".
10. **Footer Close button** now calls `onClose` directly instead of the removed `requestClose`.
11. **Added a comment block** above the conditional render explaining why the editor is read-only, citing the absent backend field, and explicitly recording what the dead `handleSave` would have done so a future reader doesn't re-introduce the same landmine "to make Save work."

### Verification phase

- **Diff inspection**: `git diff frontend/src/components/admin/EditDrawer.jsx` confirms only lines 647-797 region touched. ResearchEditor (lines 40-117) untouched. ArticleEditor (121-401) untouched. SuggestionEditor (407+) untouched. Parent EditDrawer (1120+) untouched.
- **Lint**: `npm run lint` reports 45 problems (was 47 on main). The two eliminated were pre-existing `no-unused-vars` errors in OutlineEditor itself (`saving` was assigned but never used; `markClean` was assigned but never used). My change made them go away by removing the dead code. Zero net-new lint errors.
- **Build**: `npm run build` succeeds, 2336 modules transformed in ~4.2s — same baseline as main.
- **PR-scope verification**: `grep -n "OutlineEditor\|outlineSnapshot" frontend/src` confirms the only remaining references are the `function OutlineEditor` declaration at line 650 and the parent's `<OutlineEditor ... requestCloseRef={...} />` at line 1194 (parent unchanged). The `outlineSnapshot` helper is gone (no callers remain). 

---

## Decisions and trade-offs

**1. Read-only over net-new backend.** The brief floated "make Save work" but explicitly required a draft PR if the admin service method didn't exist. I chose to also land the read-only fix the issue body recommends, because (a) the dead-handleSave deletion is the actual safety win and (b) the read-only label-text + textarea-readOnly is a small honest UX improvement that doesn't block on backend work. Operator can still close this and instead file a backend issue if they want the editable path.

**2. Removing `outlineSnapshot` helper (one line outside scope).** The brief said "OutlineEditor function (line 654+ to its end) modified." `outlineSnapshot` is at lines 650-652, directly above. It's only called by OutlineEditor's `isDirty`/`markClean` (both removed). Leaving it would have failed `no-unused-vars` and made the lint count go UP, which would have failed the lint-clean self-review item. I chose to remove it and document the scope-bend in the PR body. Operator can flag if they preferred a different approach (e.g., adding `// eslint-disable-next-line` instead — strictly worse).

**3. Not removing `outlineRequestCloseRef` from the parent.** The parent at lines 1166, 1174-1175, 1194 still references the ref. With OutlineEditor no longer populating it, the ref stays `null`, the `else if (recordType === 'Outline' && outlineRequestCloseRef.current)` branch is skipped, and the final `else onClose()` runs — the desired read-only close behavior. Cleaning up the unused parent ref would have required editing outside the OutlineEditor function, which the brief forbade. The unused ref is harmless; flagged as cleanup follow-up in this report.

**4. Not adding `useToast` / `showToast`.** The brief mentioned "the canonical Toast hook from F-1 is already wired into the admin pages. Use whichever import path the file already uses (or add it if the OutlineEditor section doesn't import it yet)." `EditDrawer.jsx` doesn't import the Toast — all editors use inline `setError` for failure surfacing. Since the read-only OutlineEditor doesn't have any error surface (load errors surface via inline `<p className="text-red-600">` like the other editors), there was nothing to toast. No need to add the import.

**5. Adding the "what the dead handleSave would have done" comment.** Defensive against a future agent or developer re-introducing the same landmine while "making Save work." The comment cites the specific dangerous payload (`content_html: ''` + `tag_ids: []`) and the specific endpoint shape (`update_article` accepts only those fields) so the reasoning is preserved at the call site.

---

## What was harder/easier than expected

**Harder than the agent-friendly label predicted (one ambiguity-resolution event):** the brief asked for the editable path; the issue body and codebase both said read-only. The taxonomy-3 disagreement was visible in the brief's own escape hatch, so it wasn't a methodology surprise — but it is the first F-4 Wave 2 run where the brief itself acknowledged the disagreement might land me in draft-PR territory. Methodology data point: the explicit escape hatch ("STOP and surface in draft PR") worked exactly as designed — there was zero ambiguity about how to proceed once the codebase fact was verified.

**Easier than predicted:** the read-only path turned out to be a substantial *deletion* rather than a re-architecture. +16/-78 net negative across one file. The dead-handleSave deletion alone was the high-value safety fix; the read-only textarea + label-update + comment were trivially additive on top of that.

**Same-file overlap with F-4.G (#118) on `EditDrawer.jsx`:** the brief's prediction (sections hundreds of lines apart, git auto-merges) appears correct from my side — I touched lines 647-797 (OutlineEditor and its private helper); F-4.G is editing lines 40-117 (ResearchEditor). Diff confirms my changes are cleanly contained.

---

## Self-review checklist

- [x] Only the `OutlineEditor` function (lines 650-800, with the `outlineSnapshot` helper at 647-649 directly above it that became dead code) modified.
- [N/A] `handleSave` calls the correct admin service method — **moot**: no such method exists; read-only path substituted; brief's escape hatch triggered → draft PR.
- [x] On success: `onClose()` — N/A for read-only; `onClose()` is wired to the Close button directly.
- [N/A] `isDirty()` + `requestCloseRef.current = requestClose` wired — **moot**: read-only has no dirty state.
- [x] No mutation that would blank article content — verified by deletion (dead `handleSave` removed entirely).
- [x] **ResearchEditor section (lines 40-117) is unchanged** — verified by `git diff`.
- [x] Other sub-components unchanged — verified by `git diff`.
- [x] `npm run lint` clean — 45 problems (2 fewer than main's 47 baseline; zero net-new errors).
- [x] `npm run build` succeeds — 2336 modules, ~4.2s.
- [x] PR description: production touch line; explanation of what the dead handleSave was doing and how the fix differs; mention I read but did not modify ResearchEditor; test plan; `Closes #120`; Claude Code footer.
- [x] Outcomes-log row appended (this report's sibling commit).
- [x] Session report at `docs/phase-2/21-frontend-f4-I-issue-120-report.md`.

---

## Methodology / observations for the experiment retrospective

This is the **final F-4 run** and the **sixteenth autonomous-agent run total** across F-1 (1) → F-2 (3) → F-3 (3) → F-4 Wave 1 (5) → F-4 Wave 2 (4). Notes for the retrospective:

- **First brief-vs-codebase-vs-issue-body triangle disagreement** that resolved to draft-PR via the brief's explicit escape hatch. The escape hatch was load-bearing; without it, I'd have had to choose between (a) following the brief and writing a Save call that targets a non-existent endpoint, (b) ignoring the brief and silently substituting the read-only path, or (c) stopping and waiting for operator input. The "draft PR with the read-only fix + the disagreement explained" outcome combines (b) and (c) without the wait — that's the methodology win.
- **Same-file parallel work appears safe at the function-region grain.** F-4.G (#118) and F-4.I (this one) both edit `EditDrawer.jsx` at function regions ~500 lines apart. The brief's "git auto-merges" prediction can only be confirmed once both PRs are on the same base, but from my side the change is cleanly bounded to lines 647-797.
- **Net-negative diffs (deletion-shaped fixes) are common in the cleanup track.** This PR is +16/-78. F-4.D (#121) was +15/-1. F-4.E (#122) was net +. The cleanup shape is well-represented across F-4 — agents handle deletion-shaped fixes as cleanly as additive fixes, even when the deletion is a safety-critical landmine removal.
- **The "explanatory comment at the deletion site" pattern.** When deleting a landmine, leaving a comment that cites the specific dangerous behavior and the specific reason it can't be re-introduced naively is cheap insurance. The audit report explicitly compared this to #99 — a previous content-corruption incident; the in-code comment now records that lineage so a future agent doesn't re-introduce the same bug while "making Save work."

---

## Follow-ups for the operator

1. **The unused `outlineRequestCloseRef` in the parent EditDrawer** (declared at line 1166, used at 1174-1175 and passed at line 1194) is now dead — OutlineEditor no longer populates it. Out of scope for this PR per brief. A small cleanup-PR could remove it. Non-blocking; the unused ref is harmless.
2. **If the editable-outline path is wanted**, file a backend issue: add `outline: str | None = None` to `ArticleUpdateRequest`, update `update_article` to write it, add `updateOutline(token, articleId, outline)` to `services/admin.js`, then re-wire OutlineEditor with a Save button mirroring ArticleEditor's pattern. That's a multi-file change spanning backend + frontend; not agent-friendly in its current shape.
3. **The issue body's "the title `handleSave` 'saves' is uneditable" observation** is preserved: the title remains `readOnly` in the new code. If the title should be editable from the outlines page, that's a separate decision.
