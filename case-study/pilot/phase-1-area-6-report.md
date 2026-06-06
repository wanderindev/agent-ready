# Phase 1 — Area 6 Report: Frontend Admin CMS

**Date:** 2026-05-20
**Duration:** ~2 hours (~30 min mapping + route-map approval, ~1 hour audit + filing, ~30 min report)
**Scope:** `frontend/src/pages/admin/*` (12 gated pages + `AdminLogin`), `frontend/src/components/admin/*` (`EditDrawer`, `RichTextEditor`, `MediaDetailModal`, `InlineStatusCell`, and the rest of the cell-renderer / modal set), `frontend/src/services/admin.js`, `frontend/src/contexts/AdminAuthContext.jsx`, `frontend/src/components/layout/AdminLayout.jsx`, and the admin touch-points of `services/booking.js`. The backend admin endpoints these call were audited in Areas 1–4; the public site in Area 5.

This is the **final Phase 1 audit area.** The next session is the Phase 1 synthesis report.

---

## Executive summary

The admin CMS is **the best-built surface audited in Phase 1.** Route protection is sound, `services/admin.js` has consistent and correct error handling on all ~50 methods, four of the five `EditDrawer` editors implement unsaved-changes guards, the two most destructive actions (delete-admin-email, cancel-order) are confirmed, and the one large table (media candidates) is server-paginated. None of those things were true of the services layer. **No critical findings, no stop-the-line** — expected for an internal-facing tool with a single-digit user population.

The findings that do exist share one shape: **partial correction.** Every Area 6 finding is a good pattern that was applied to some call sites and not others.

- Error surfacing via the `Toast` component was added to `AdminArticles`' translate / series-sections handlers — and to *none* of the other 22 `console.error`-only catch blocks (**#117**).
- The unsaved-changes guard was wired into four `EditDrawer` editors — and not `ResearchEditor` (**#118**), and never into the browser-level `beforeunload` path at all (**#119**).
- Confirmation prompts guard delete-admin-email and cancel-order — and not `mark-paid` or `send-invoice` (**#121**).

This is the same shape Area 5 flagged as its fourth instance (`EducatorAuthContext` has a `try/catch` its sibling `CartContext` lacks). Area 6 makes it five, six, and seven. The pattern is now the single most consistent cross-area finding in Phase 1 and belongs in the synthesis as a named structural observation, not three more backlog lines (see *Newly observed*).

The other notable finding is **#120**: `OutlineEditor` is a non-functional editor — an editable textarea with no Save button — and it carries a dead `handleSave` that sends `content_html: ''`. That function is one wired-up button away from blanking article bodies. It is the dormant cousin of #99 (the article-pipeline content-corruption incident).

**6 issues filed (#117–#122): 0 critical, 5 moderate, 1 nice-to-have. All 6 agent-friendly.** Plus three verify-only confirmations of pre-existing issues (#57, #18, #111).

---

## By the numbers

| Metric | Value |
|---|---|
| Admin files read in full | ~12 (pages, `EditDrawer`, `RichTextEditor`, `MediaDetailModal`, `InlineStatusCell`, `AdminAuthContext`, `AdminLayout`, `admin.js`) |
| Admin files grep-characterized | ~8 (remaining cell renderers, `AdminCalendar`, `AdminOutlines`, `AdminEduResearch`/`AdminEduSuggestions`) |
| Issues filed | 6 (#117–#122) |
| — `code-quality:critical` | 0 |
| — `code-quality:moderate` | 5 (#117, #118, #119, #120, #121) |
| — `code-quality:nice-to-have` | 1 (#122) |
| — `agent-friendly` | 6 (all) |
| Stop-the-line incidents | 0 |
| Pre-existing issues verified | 3 (#57, #18, #111) |
| `console.error`-only catch blocks (admin) | 22 across 9 files |
| `window.confirm` / inline-confirm usages | 2 (delete-admin-email, cancel-order) |
| `beforeunload` handlers | 0 |

---

## Admin route + auth model

The reference output this audit produces — the intended vs. actual admin frontend model.

| Layer | Intended | Actual | Status |
|---|---|---|---|
| Route gate | Every `/admin/*` route requires auth | `AdminLayout` wraps all 12 routes in `AdminAuthProvider`; `AdminLayoutInner` renders `loading → "Loading…"`, then `!isAuthenticated → <Navigate to="/admin/login">`, then `<Outlet>` | **Sound** |
| Data-before-auth | No admin page renders before auth resolves | The `<Outlet>` (all admin pages) renders only when `isAuthenticated` is true | **Sound** — Area 5's concern refuted |
| Dev bypass | Local-dev only, cannot reach prod | `import.meta.env.DEV` → `dev-token`. This is a **build-time** constant — compiled out of production bundles. Unlike backend #55 (runtime `DEBUG`), the frontend bypass is safe | **Sound** |
| Token transport | Header / cookie | URL query string everywhere — `AdminLogin` navigates `?token=`, `AdminAuthContext` reads `?token=`, all ~50 `admin.js` calls append `?token=` | **#57** (pre-existing) |
| Logout | Clears session + revokes server-side | Clears `sessionStorage`; admin pages unmount (state GC'd). Does **not** revoke the token server-side — the 24h token stays valid after logout | Gap — see *Newly observed* |
| Service error handling | Non-2xx surfaced | `admin.js` checks `res.ok` on all ~50 methods and parses `err.detail` — **correct and consistent** | **Sound** |
| Inline action error handling | Failure shown to operator | 22 handlers `console.error` only | **#117** |
| Unsaved-work protection | Guarded on every exit path | 4/5 editors guard in-app exits; `ResearchEditor` unguarded; no `beforeunload` | **#118, #119** |

The healthy rows here are the story: the admin **security perimeter is correct** (gate, no data leak before auth, build-time dev bypass) and the **service layer is correct** (consistent `res.ok` checks — the opposite of Area 5's #107, where `educators.js`/`subscribe.js` skipped them). The gaps are all in operator-experience tiers: failure visibility and unsaved-work protection.

---

## What was audited

**Auth / layout:** `AdminAuthContext.jsx` (token lifecycle, dev bypass, logout), `AdminLayout.jsx` (gate, sidebar), `AdminLogin.jsx` (request-access flow).

**Service:** `services/admin.js` — all 749 lines, ~50 methods. Verified `res.ok` handling, the `err.detail` parsing, the `uploadResearch`/`uploadEduResearch` validation-error shape handling, the comprehensive `?token=` usage.

**Editor:** `RichTextEditor.jsx` (TipTap — `StarterKit` + `Link` + a `CustomImage` node view; `allowBase64: false`; schema-constrained output), `EditDrawer.jsx` (all 43 KB / 7 editor variants — `Research`, `Article`, `Suggestion`, `Outline`, `EduSuggestion`, `EduResearch`, `EduMaterial`, plus `PlaceholderEditor`).

**Pages, full read:** `AdminHome`, `AdminSuggestions`, `AdminArticles`, `AdminResearch`, `AdminEduMaterials`, `AdminMediaLibrary`, `AdminOrders`, `AdminSettings`. **Grep-characterized:** `AdminCalendar` (confirmed `cancel-order` has an inline confirm; `mark-paid` does not), `AdminOutlines`, `AdminEduResearch`, `AdminEduSuggestions`.

**Components:** `MediaDetailModal` (full), `InlineStatusCell` (full); `ActionsCellRenderer`, `SharedCellRenderers`, `StatusDropdown`, `TagInput`, `Toast`, `MediaPickerModal`, `MediaCard`, `MediaGrid` — characterized via grep + call-site reads.

**Build:** the Area 5 production build (one 2.65 MB chunk) was not re-run; the admin contribution to it was confirmed by inspection (`AllCommunityModule`, TipTap, no `React.lazy`).

---

## Item-by-item findings

### #117 — Inline admin actions swallow failures to `console.error` (moderate, agent-friendly)

22 `console.error`-only catch blocks across 9 admin files. Inline grid-cell handlers (`handleStatusChange`, `handleGenerateTags`, `handleGenerateSummary`, `handleDownload`, `refreshGrid`) give the operator no feedback on failure — a rejected status change makes the `StatusDropdown` silently snap back with no message. The `Toast` component exists and `AdminArticles.handleTranslate` / `handleSeriesSections` use it correctly; the rest were never retrofitted. The headline finding.

### #118 — `EditDrawer` `ResearchEditor` has no unsaved-changes guard (moderate, agent-friendly)

`ArticleEditor` / `SuggestionEditor` / `OutlineEditor` / `EduSuggestionEditor` implement `isDirty` + a confirm dialog exposed via `requestCloseRef`. `ResearchEditor` does not — its Cancel button calls `onClose` directly, and `EditDrawer.handleClose` routes `recordType === 'Research'` to the unguarded `else` branch. Editing a 4,000-word research document and mis-clicking the backdrop discards it with no prompt.

### #119 — No `beforeunload` guard anywhere (moderate, agent-friendly)

Grep-confirmed: zero `beforeunload` handlers in `frontend/src/`. The `EditDrawer` dirty guard only covers the drawer's own close paths. Refresh / tab-close / browser-Back during an article, suggestion, or pricing edit discards unsaved work with no prompt. Pairs with #118 — #118 is the missing in-app guard on one editor; #119 is the missing browser-level guard on all of them.

### #120 — `OutlineEditor` is non-functional; dead `handleSave` would blank article content (moderate, agent-friendly)

The outline `<textarea>` is editable but the footer has only a `Close` button — edits can never be saved, yet the dirty-check still fires a scary "unsaved changes" warning. The dead `handleSave` sends `content_html: ''` + `tag_ids: []` to `updateArticle`; if a future change wires a Save button to it, saving an outline blanks the article body. Dormant cousin of #99.

### #121 — Consequential order actions lack confirmation (moderate, agent-friendly)

`mark-paid` (AdminOrders + AdminCalendar) and `send-invoice` fire immediately on click. `mark-paid` flips an order to `PAID` and the action footer then disappears (`!isPaid` gate) — no in-UI undo. `send-invoice` emails the real customer. delete-admin-email and cancel-order *are* confirmed; these two were missed.

### #122 — Long-running generation modals dismissable mid-operation (nice-to-have, agent-friendly)

`writeArticle` / `generateEduMaterials` / `generateEduSlides` / `generateResearchSummary` run minutes; the modal `Dialog onClose` is not gated on `loading`, so backdrop/Escape dismiss it mid-flight. No progress affordance beyond a disabled button. Nice-to-have because no operator *work* is lost (the backend completes and the grid refreshes) — the gap is feedback and accidental dismissal. Making these survive a refresh is a separate backend-async change, explicitly out of scope.

---

## Stop-the-line discussion

**None triggered.** Checked against every Area 6 trigger:

- *Admin route reachable without auth* — no. `AdminLayout` gates all 12 routes; the `<Outlet>` renders only after `isAuthenticated`. The build-time `import.meta.env.DEV` bypass cannot reach production.
- *XSS via admin actions* — no. TipTap's `RichTextEditor` is ProseMirror-schema-constrained: `getHTML()` serializes only schema nodes, and `setContent` parses input through the same schema, so the editor cannot emit or round-trip a `<script>`. The unsanitized-HTML risk (#111) lives in the **LLM-markdown → `markdown_to_html`** path, not the editor — and that path is not reachable by a public user.
- *Admin token leak* — #57 (token in URL) is real and confirmed comprehensively, but it is a **pre-existing filed issue**, not a newly discovered live exploit. Commented, not re-filed.
- *Data destroyed without confirm and no undo* — `mark-paid` is the closest call: no confirm, no in-UI undo. But it changes a status field rather than destroying data, and it is recoverable via the database. Filed moderate (#121), not stop-the-line. `OutlineEditor`'s `content_html: ''` *would* qualify — but it is dead code (no button calls `handleSave`), so it is a latent landmine, not a live vector. Filed moderate (#120).

The audit plan predicted Area 6 as low-stop-the-line ("internal-facing… bounded user-impact"). Confirmed.

---

## What's filed vs. deferred

**Filed (6):** #117–#122.

**Verified, commented, not re-filed (3):**
- **#57** — token in URL. Commented with the frontend confirmation: `AdminLogin` navigates `?token=`, `AdminAuthContext` reads it, all ~50 `admin.js` methods append it. The fix is a coordinated backend (`Query` → header) + frontend (~50 call sites) change. The comment also records the **logout-doesn't-revoke** gap (below).
- **#18** — bundle. Commented to assign the admin track ownership: no `React.lazy`, every grid page imports full `AllCommunityModule`, TipTap in `RichTextEditor`. One PR splitting at the public/admin route boundary serves both #18 and Area 6's code-splitting need — Area 6 deliberately did **not** file a separate code-splitting issue (per the brief).
- **#111** — `dangerouslySetInnerHTML`. `EditDrawer`'s `EduResearchEditor` and `EduMaterialEditor` render `content_html` unsanitized — two more consumers of the same un-sanitized field. #111's proposed backend fix (sanitize in `markdown_to_html`) covers all consumers; no new issue.

**Deferred / not filed (judgment calls):**
- *Admin is English-only (no i18n).* No `useTranslation` anywhere in `pages/admin/*`. Deliberate — the admin has one bilingual operator (Diego). Filing an admin-i18n issue would be churn for zero benefit. Noted, not filed.
- *`ArticleEditor`'s `stabilizingRef` 500 ms timeout.* A hack to let TipTap normalize HTML before locking the dirty snapshot; a slow machine could lock early and show a spurious "unsaved changes." A `useEffect` that keeps re-snapshotting while stabilizing mitigates it. Works in practice; filing it is noise. Noted.
- *TipTap link insertion via `window.prompt` with no URL validation.* `@tiptap/extension-link` v3 sanitizes `javascript:` hrefs by default, and the operator is trusted. Noted, not filed.
- *Double-fetch on `AdminMediaLibrary` filter change* (the `setPage(1)` effect races the fetch effect). Minor inefficiency, current data volume makes it invisible. Noted.

---

## Newly observed — for the Phase 1 synthesis report

This section feeds the synthesis, not a further audit (there is none).

### 1. The partial-correction pattern is the dominant cross-area finding — promote it to a named structural observation

Across Phase 1, the same shape recurs: a correct pattern is introduced, applied to the call sites in front of whoever introduced it, and never swept across the rest.

- **4a** — `mailing_list.py`'s Sheets helpers check `result.get("successful")`; the older `composio_client.send_email` does not (#67).
- **4b-2** — the article pipeline guards regeneration in four of five mutating flows; `series-sections` was missed (#99).
- **Area 5 (4th)** — `EducatorAuthContext.getStored()` wraps its `JSON.parse` in `try/catch`; sibling `CartContext` does not (#110).
- **Area 6 (5th, 6th, 7th)** — error surfacing on 2 of ~24 catch sites (#117); dirty guard on 4 of 5 editors (#118) and 0 browser paths (#119); confirmation on 2 of ~6 consequential actions (#121).

This is no longer an anecdote. The synthesis should name it — "**partial-correction debt**" — and recommend the corresponding remediation discipline: when a fix introduces a pattern, sweep it across all sibling call sites in the same PR. Several filed issues (#117 especially) are explicitly "finish the sweep" work.

### 2. The frontend HTML-sanitization gap now has three endpoints

`content_html` is rendered unsanitized in three places: public `ArticleContent` (#111), admin `EduResearchEditor`, admin `EduMaterialEditor`. All three are fixed by one backend sanitizer in `markdown_to_html`. The synthesis should schedule #111 **once, backend-side**, and note it discharges three frontend consumers.

### 3. Admin logout does not revoke the token server-side

`AdminAuthContext.logout` clears `sessionStorage` only. The 24h admin token remains valid server-side after logout, and (via #57) also persists in browser history. Server-side token revocation on logout is a real gap. It is backend work, #57-adjacent; recorded on the #57 comment thread, not filed separately. The synthesis should fold it into the #57 / token-lifecycle cluster.

### 4. Reference artifact produced

The **admin route + auth model** table above is the Area 6 reference output — the intended-vs-actual map for the admin frontend, analogous to Area 3's auth-model table. The synthesis can cite it directly.

### 5. Open item to close before the synthesis

4b-2 flagged that 4a's caller-grep missed `image_prompt`'s caller because of a function-local import — a note that the module inventory should be re-derived including function-local imports. That is a **backend** verification task; Area 6 (frontend) could not close it. It remains open for the synthesis to either resolve or explicitly carry as a known inventory caveat.

---

## What surprised me

1. **The admin CMS is the highest-quality surface in Phase 1.** Going in, the expectation (internal tool, one user, never battle-tested) was "rough." Instead: the auth gate is correct, `admin.js` checks `res.ok` on every one of ~50 methods, four editors have dirty guards, the big table is server-paginated. The services layer (Areas 2–4) had *worse* error handling than this internal-only UI. The thing nobody else uses turned out to be the most carefully built.

2. **The frontend dev-token bypass is the *safe* one.** Area 3's #55 (backend `dev-token` on runtime `DEBUG`) was the scariest finding of that area. The frontend has a structurally identical bypass — but gated on `import.meta.env.DEV`, a *build-time* constant that Vite compiles out of production. Same idea, opposite safety. A good illustration that "where the flag is evaluated" matters more than "is there a bypass."

3. **`OutlineEditor` is a UI that cannot do its job.** An editable textarea, a dirty-check that warns you'll lose changes, and no Save button — so the warning is always true and never escapable. And one function below it, `handleSave` sits with `content_html: ''` hardcoded. Reading it felt like finding a light switch wired to nothing, next to a switch wired to the building's main breaker.

4. **TipTap quietly closed the XSS question.** I expected the editor to be the second endpoint of #111's unsanitized-HTML story. It is not: ProseMirror's schema enforcement means the editor can neither emit nor paste a `<script>`. The #111 risk is entirely the LLM-markdown path. The editor is the one place in the content pipeline that *is* safe by construction.

5. **Every Area 6 finding is the same finding.** Six issues, one shape: a good pattern, half-applied. I did not go looking for that — it emerged from tabulating call sites. It is the cleanest cross-area signal Phase 1 has produced.

---

## Fix ordering for the admin frontend

Fourth fix-ordering analysis (after edu, article, public frontend). The admin track, like the public frontend, is **wide and shallow** — six independent, agent-friendly issues, no linchpin. Waves are value-priority, not dependency.

### Wave 1 — operator trust

The admin tool must tell the truth about failure and protect operator work.

- **#117** (silent failures → `Toast`) — the highest-value fix: today a failed admin action is indistinguishable from a successful one. Restores the operator's ability to trust the UI.
- **#118 + #119** (the unsaved-work pair) — #118 wires the missing in-app guard into `ResearchEditor`; #119 adds the browser-level `beforeunload` guard across all editors. Land them together — they are two halves of "the admin never silently loses an edit."

### Wave 2 — safety rails

- **#121** (confirmations on `mark-paid` / `send-invoice`) — closes the mis-click vectors on the consequential order actions.
- **#120** (`OutlineEditor`) — make the textarea read-only (the likely-correct fix) and **delete the dead `handleSave`**. Removing the `content_html: ''` landmine is the priority; the read-only change is cosmetic alongside it.

### Wave 3 — polish

- **#122** (long-running modal dismissal + progress affordance) — nice-to-have; do it whenever.

### Separate track — code-splitting (#18)

Independent of all six. One PR lazy-loading the `/admin/*` route subtree at the public/admin boundary; serves Area 5 and Area 6 simultaneously. No ordering constraint against Waves 1–3.

### Interactions within the admin track

- **#118 ⇄ #119** — the unsaved-work pair; ship together.
- **#117** — fully independent; pure sweep work, the most agent-friendly issue in the area.
- **#120 ⇄ #99** — `OutlineEditor`'s dead `handleSave` is the same *class* of bug as #99 (a mutating path that corrupts article content). No code dependency, but whoever fixes #120 should know #99's history — content-wiping paths in this codebase have already fired once.
- **#121, #122** — independent of everything.

---

## Toward a global fix ordering

The fourth and final bridge section. After this, the Phase 1 synthesis has all four (edu 4b-1, article 4b-2, public frontend Area 5, admin frontend Area 6).

### Where the admin track is independent

**Almost entirely.** #117, #118, #119, #120, #121, #122 are pure frontend-admin — no backend file, schema, or endpoint involved. The admin track runs as its own concurrent track alongside every backend wave and alongside the Area 5 public-frontend track. Combined with Area 5's finding that the public frontend is equally independent, the synthesis can state it plainly: **the entire frontend (Areas 5 + 6) is one schedulable, near-fully-independent, near-fully-agent-friendly track** — 17 issues, all but two agent-friendly, almost none coupled to backend work.

### Where the admin track interacts with the backend orderings

Three interaction points, decreasing coupling:

1. **#57 (token in URL) — a backend + frontend coordinated change.** The admin frontend is comprehensively affected: ~50 `admin.js` call sites, plus `AdminAuthContext` and `AdminLogin`. The global ordering carries **one** #57 work item spanning the backend (`Query(...)` → header dependency) and the frontend (every call site). Fold in the **logout-doesn't-revoke** gap (server-side token revocation) — same token-lifecycle cluster. This is the admin analog of Area 5's educator-access merge and 4b-2's research-upload merge: a place where two backlogs must be physically merged, not merely sequenced.

2. **#18 (code-splitting) — shared Area 5 ⇄ Area 6.** One PR at the public/admin route boundary. The global ordering schedules it once; the admin track owns it. Independent of the educator-access and LLM-foundation work.

3. **#111 (HTML sanitization) — one backend fix, now three frontend consumers.** Public `ArticleContent` + admin `EduResearchEditor` + admin `EduMaterialEditor`. The global ordering schedules #111 once, backend-side (`markdown_to_html`), and records that it discharges all three. No frontend work needed if the backend sanitizes.

A fourth, looser affinity: **#120 ⇄ #99** — both are article-content-corruption paths. Not a scheduling dependency, but the synthesis's "content integrity" theme should list them together.

### Where shared foundations slot in

None. The admin track has no dependency on the LLM foundation (#76/#77/#78/#68). The admin pages *invoke* the long-running LLM pipelines (`writeArticle`, `generateEduMaterials`), but none of the six admin issues depends on that backend work landing — #122 explicitly scopes out the "survive a refresh" improvement that would benefit from an async backend. The admin track can start on day one regardless of backend wave order.

### The asymmetry, completed

4b-2 contrasted *startability* (article #99 ungated vs. edu #91 gated). Area 5 contrasted *shape* (backend narrow-and-deep vs. public-frontend wide-and-shallow). Area 6 completes the picture: the admin frontend is also wide-and-shallow, and now the statement is whole — **the backend backlog is narrow-and-deep with linchpins (#76, #67) that gate large clusters and punish wrong sequencing; the entire frontend backlog (Areas 5 + 6) is wide-and-shallow, ~all agent-friendly, with no linchpins and almost no inter-issue dependencies.** For the synthesis's global Wave 1 this is decisive: the frontend is the **lowest-risk, most-parallelizable, most-autonomous-agent-suitable** work in Phase 1. If Phase 2 hands a track to an autonomous agent, it is the frontend track — and Area 6's #117 (a pure mechanical sweep with the target pattern already in the same file) is the single cleanest entry point in the entire backlog.

---

## Process notes for the Phase 1 final report

- **All four bridge sections now exist.** edu (4b-1), article (4b-2), public frontend (Area 5), admin frontend (Area 6). The synthesis's global ordering should compose them: backend critical paths (#97→#91→#90, #99) + LLM foundation (#76) as narrow-and-deep Wave 1 tracks; the frontend (Areas 5+6, 17 issues) as a single wide-and-shallow concurrent track; the three cross-cutting merges (#57 token-lifecycle, #18 code-split, #111 sanitization) scheduled once each.

- **Promote partial-correction debt to a named theme.** Five-plus instances across four areas (see *Newly observed* #1). The synthesis should name it and carry the remediation discipline ("sweep the pattern across all siblings in the introducing PR") as a process recommendation, not just a backlog observation.

- **The verify-only-and-comment practice held.** #57/#18/#111 confirmed and commented rather than re-filed — same as Area 5's handling of #7/#18/#50/#52/#60. The synthesis should treat "confirm pre-existing issues with a comment, don't duplicate" as a settled Phase 1 practice. Total Phase 1 issues stayed clean because of it.

- **Batch sizes of 4 + 2 worked.** Consistent with Areas 1–5.

- **One open item for the synthesis to close** (*Newly observed* #5): 4b-2's function-local-import caveat on the backend module inventory. Frontend audits could not resolve it; the synthesis must either re-derive that inventory or carry the caveat explicitly.

- **Counts.** Phase 1 Part B filed issues #21–#122 across Areas 1–6 (with gaps for the issues that were Part A / Phase 0). Area 6 added 6. The audit is complete; the next session is the synthesis.