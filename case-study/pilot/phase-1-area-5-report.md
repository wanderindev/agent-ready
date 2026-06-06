# Phase 1 — Area 5 Report: Frontend Public Site

**Date:** 2026-05-20
**Duration:** ~2 hours (~30 min mapping + route map approval, ~1 hour audit + filing, ~30 min report)
**Scope:** `frontend/src/` minus admin routes — `App.jsx`, `main.jsx`, `i18n.js`, `index.html`, `vite.config.js`; the public pages (Home, Blog, Article, AcademicExcursions, Tours, EducationalMaterials, Contact, ContactConfirmation, ProductDetails, ConfirmSubscription, Unsubscribe, EducatorConfirm, legal pages); public components (`sections/*`, `public/*`, `cart/*`, `booking/CartIcon`, `layout/*`); the public contexts (`CartContext`, `BookingModalContext`, `EducatorAuthContext`); the public service modules (`articles.js`, `publicMedia.js`, `educators.js`, `subscribe.js`); Sentry frontend instrumentation; the `public/locales/{en,es}/translation.json` files. The checkout flow (Checkout, OrderConfirmation, BookingManage, BookingCancel, BookingRenewPayment) was referenced but **not re-audited** — Area 2 covered it. Admin routes are Area 6.

---

## Executive summary

The public site is in **better shape than the services layer**, exactly as the audit plan predicted. The failure modes are user-visible (a blank page, an English string on a Spanish site, a slow first paint) rather than data-corruption-shaped, and the per-finding stakes are correspondingly lower. **No critical findings, no stop-the-line.** That is the expected and correct outcome for a public-frontend audit, not a quality signal.

Three things stand out as genuinely good. **i18n is excellent** — 611 EN keys, 610 ES keys, near-perfect parity (one missing ES key), and the 14 "identical" values are legitimately identical (proper nouns, "PayPal", "Blog"). The #35 time-slot bug was an i18n-key-*mismatch*, not a key-*absence*; there is no widespread translation drift. **Cart persistence works** — `CartContext` writes `localStorage['pic_cart']` on every change, which substantiates the "your cart is saved" copy in Checkout's Sentry fallback that Area 2 flagged for verification. **Accessibility is acceptable** — semantic landmarks, `sr-only` labels, `aria-hidden` icons, and form `<label htmlFor>` are generally present; the bounded pass surfaced one structural defect, not a systemic problem.

The findings cluster into three themes. **Error/crash safety net**: there is no top-level error boundary (#7, Phase 0), no 404 route, and `CartContext` will crash the *entire* site to a blank page if `localStorage` cart data is ever corrupt — because `CartProvider` wraps everything and nothing catches the throw. **Content correctness**: a handful of hardcoded English strings, two analytics IDs that fire in every environment, and a `/producto/:slug` route that serves hardcoded placeholder tour content with fake prices. **Defense-in-depth**: article HTML is rendered via `dangerouslySetInnerHTML` and *nothing* in the pipeline (`markdown_to_html` backend → frontend) sanitizes it — bounded today because article content is LLM-generated rather than public-user-supplied, but the trust boundary is an LLM, not a security-conscious human.

The educator-access gate was the headline thing to verify. Confirmed: **the frontend gate is purely cosmetic.** `EducatorAccessGate` renders its children iff `hasAccess` is true, and `hasAccess` derives from `localStorage['educator_access']` — settable in DevTools in five seconds. Even without that, `PublicMediaLibrary` calls `/api/v1/public-media`, which is open server-side (Area 3 #50). No new issue filed: #50 already states "access system is frontend-only" and #52 already captures the forgeable token. The frontend gate is a UX affordance, and the only real fix is the backend one.

**11 issues filed (#106–#116): 0 critical, 6 moderate, 5 nice-to-have. 9 agent-friendly.** Plus four verify-only confirmations of pre-existing issues (#7, #18, #50/#52, #60).

---

## By the numbers

| Metric | Value |
|---|---|
| Files read in full | ~35 (pages, components, contexts, services, config) |
| Production build run | 1 (bundle measurement) |
| Issues filed | 11 (#106–#116) |
| — `code-quality:critical` | 0 |
| — `code-quality:moderate` | 6 (#106, #107, #108, #110, #111, #112) |
| — `code-quality:nice-to-have` | 5 (#109, #113, #114, #115, #116) |
| — `agent-friendly` | 9 (all except #111, #112) |
| Stop-the-line incidents | 0 |
| Pre-existing issues verified | 4 (#7, #18, #50/#52, #60) |
| Translation keys | 611 EN / 610 ES — 1 missing ES key |
| Production JS bundle | 2,649,933 bytes (732 KB gzip), **single chunk** |

---

## Public-site error-handling model

The reference output this audit was designed to produce — a clear statement of the intended vs. actual resilience model. Future changes should start here.

| Layer | Intended | Actual | Issue |
|---|---|---|---|
| Top-level error boundary | Uncaught render error → recovery UI | None — error unmounts the tree to a blank page | #7 (pre-existing) |
| Per-page error boundary | Each page soft-fails | Only Checkout, OrderConfirmation, Contact wrapped | #7 / #106 |
| Unknown URL | "Page not found" page | Blank `<main>` (no `path="*"` route) | #106 |
| Async fetch states | loading + error + empty, all three | Blog/Article/FeaturedArticles/MediaLibrary have all three; `FeaturedArticles` returns `null` on error (silent) | — (acceptable) |
| Service-layer HTTP errors | Non-2xx surfaced to the user | `articles.js`/`publicMedia.js` check `response.ok`; `educators.js`/`subscribe.js` do **not** | #107 |
| Persisted-state read | Corrupt data tolerated | `EducatorAuthContext` tolerates it; `CartContext` crashes the app | #110 |
| Educator route gate | Server-enforced | Client-only; `localStorage`-settable; API open | #50/#52 (pre-existing) |
| Stale-cache on network error | Deny access | Grants access from stale `localStorage` | #60 (pre-existing) |
| Rendered article HTML | Sanitized | Unsanitized end to end | #111 |
| Analytics | Production only | Fires in every environment | #112 |

The healthy rows: loading/error/empty states are *present* on every public async fetch (Blog, Article, FeaturedArticles, PublicMediaLibrary all have the three-state pattern). The skeleton loaders in `Article.jsx` and `BlogList.jsx` are well-built. The gaps are all in the *error* tier, not the *loading* tier.

---

## What was audited

**Entry / config:** `App.jsx` (route table — all routes eagerly imported, no lazy boundaries, no `path="*"`), `main.jsx` (Sentry init — minimal: DSN + `sendDefaultPii: true`, no `tracesSampleRate`, no integrations, no `ErrorBoundary`), `i18n.js` (`debug: true`, `fallbackLng: 'es'`, http-backend), `index.html` (GA + Meta Pixel bootstraps), `vite.config.js` (no `manualChunks`, no chunk config).

**Pages:** Home, Blog, Article, AcademicExcursions, Tours, EducationalMaterials, Contact, ContactConfirmation, ProductDetails, ConfirmSubscription, Unsubscribe, EducatorConfirm, TermsAndConditions (PrivacyPolicy is structurally identical). Checkout/OrderConfirmation/BookingManage/BookingCancel/BookingRenewPayment referenced only — Area 2.

**Components:** `layout/{AppShell,Navbar,Footer}`, `sections/home/*` (Hero, FeaturedArticles, MailingListBlog, MailingListEducators), `sections/blog/{BlogList,ArticleContent,RelatedArticles}`, `sections/tours/DestinationGrid`, `public/{EducatorAccessGate,PublicMediaLibrary,PublicMediaCard,PublicMediaDetailModal}`, `cart/CartDrawer`, `booking/CartIcon`.

**Contexts:** `CartContext`, `BookingModalContext`, `EducatorAuthContext`.

**Services:** `articles.js`, `publicMedia.js`, `educators.js`, `subscribe.js`.

**Backend touch-point:** `backend/app/utils/markdown.py` — read to calibrate the `dangerouslySetInnerHTML` finding.

**Build:** `npm run build` — measured the production bundle (one chunk, 2.65 MB / 732 KB gzip).

---

## Findings filed

| # | Title | Severity | Agent-friendly |
|---|---|---|---|
| #106 | No catch-all 404 route and no error boundaries on public pages | moderate | yes |
| #107 | `educators.js` / `subscribe.js` never check `response.ok` | moderate | yes |
| #108 | Hardcoded English strings in public components | moderate | yes |
| #109 | i18n config hygiene: `debug:true` in prod, `<html lang>` never synced | nice-to-have | yes |
| #110 | `CartContext` crashes the entire app on corrupt `localStorage` cart data | moderate | yes |
| #111 | Article content rendered via `dangerouslySetInnerHTML` with no sanitization | moderate | no |
| #112 | Meta Pixel + GA fire in every environment with hardcoded IDs | moderate | no |
| #113 | `ContactConfirmation` navigates to an unvalidated `from` query param | nice-to-have | yes |
| #114 | Public images not lazy-loaded; HeroSection eager-loads 8 hero images | nice-to-have | yes |
| #115 | `PublicMediaCard` nests a clickable div inside a button (a11y) | nice-to-have | yes |
| #116 | Remove placeholder `ProductDetails` route and dead `RelatedArticles` | nice-to-have | yes |

### Verify-only (pre-existing issues confirmed, no new issue)

- **#7** (no top-level `<Sentry.ErrorBoundary>`) — **confirmed.** `main.jsx` renders `<App />` with nothing above it; `App.jsx` has no boundary. Still accurate.
- **#18** (2.6 MB bundle) — **confirmed and sharpened.** The production build emits a *single* `index-*.js` of 2,649,933 bytes (732 KB gzip) — Phase 0's "~2.6 MB" was exact. Zero code-splitting: `vite.config.js` has no `manualChunks`, `App.jsx` has no `React.lazy`. AG Grid (~500 KB) and TipTap (~300 KB) — both admin-only — ship to every public visitor.
- **#50 / #52** (educator gate is frontend-only / forgeable token) — **confirmed from the frontend side.** `EducatorAccessGate` gates on `hasAccess`, which `EducatorAuthContext` derives from `localStorage['educator_access']`. Anyone can set that key; and `PublicMediaLibrary` fetches the open `/api/v1/public-media` API regardless. No new issue — #50 already says "access system is frontend-only."
- **#60** (stale-cache trust) — **confirmed.** `EducatorAuthContext.jsx:59-64` — on a network error during the mount-time access check, `.catch()` does `if (!stored.expired) setHasAccess(true)`.

---

## Newly observed — for later areas

- **Area 6 (Frontend admin):**
  - `App.jsx` eagerly imports 12 admin route components (`AdminHome`, `AdminSuggestions`, `AdminMediaLibrary`, …). These are the bulk of the #18 bundle. Area 6's code-split work and #18 are the same work item — see the fix-ordering note below.
  - `services/admin.js` is 26 KB — the largest service module, untouched here. Area 6.
  - `components/admin/*` (TipTap `RichTextEditor`, AG Grid cell renderers, `MediaPickerModal`, etc.) — not read. Area 6.
  - `AdminLayout.jsx` is gated by `useAdminAuth` (Area 3 confirmed the *intent* was always admin-only). Area 6 should confirm no admin *page* renders sensitive data before the auth check resolves.
- **Cross-area:**
  - `main.jsx` sets `sendDefaultPii: true` on the **frontend** Sentry init — the same setting Area 3/4a flagged on the backend. On the frontend it means user IP and request context attach to every captured event. Whoever does the cross-cutting Sentry hardening pass should treat frontend and backend together.
  - Frontend Sentry init is minimal — no `tracesSampleRate`, no `browserTracingIntegration`, no `replayIntegration`. Not a defect, but the frontend gets error capture only, no performance/replay data. A conscious-config decision for whoever owns observability.
  - `Article.jsx`'s fetch effect (`[slug, i18n.language]`) has no `AbortController`; switching language mid-fetch races two `getArticleBySlug` calls and the slower one wins, including a stale `navigate(...)`. Low probability, visible only on fast toggling — **noted, not filed.** If a frontend test suite ever exists, this is the kind of thing it should cover.
  - `Contact.jsx` falls back to `http://localhost:8000` for its API base; `articles.js`/`publicMedia.js`/`educators.js`/`subscribe.js` fall back to `https://api.panamaincontext.com`. Inconsistent default, harmless in practice (env var is set in prod) — noted, not filed.

---

## Fix ordering for the frontend public site

This is the **third** fix-ordering analysis (after edu 4b-1 and article 4b-2). The composition pattern is established; this section applies it to the public-frontend backlog.

The defining structural fact: **the frontend backlog is wide and shallow.** Unlike the backend — where #76 (LLM wrapper) and #67 (Composio contract) are linchpins that gate large downstream clusters — the public-frontend findings are almost entirely *independent* of each other. There is no frontend equivalent of a linchpin. Nine of eleven are agent-friendly. This is a scheduling advantage: the track parallelizes trivially. The waves below are about *value priority*, not dependency.

### Wave 1 — the error/crash safety net

The one place the frontend backlog has real coupling.

- **#7** (top-level `<Sentry.ErrorBoundary>`) is the keystone. It converts *every* uncaught render error — including any future regression — from a blank page into a recovery UI. Do it first.
- **#110** (`CartContext` crash on corrupt `localStorage`) is the highest-value *individual* fix in the area: it is a full-site blank-page crash, and `CartProvider` wraps the entire app. #7 reduces its blast radius; #110 removes the known trigger. They are a pair — #7 is the net, #110 is the specific hole. Fix both.
- **#106** (404 route + public error boundaries) is the routing half of the same "no soft-fail" gap that #7 is the error-boundary half of. The brief framed them as a pair; they are.

Wave 1 is small, agent-friendly, and turns the site from "one bad render = blank page" into "graceful degradation."

### Wave 2 — error UX and content correctness

All independent, all agent-friendly, all parallelizable.

- **#107** (`response.ok` in `educators.js`/`subscribe.js`) — the service-layer half of error UX. With Wave 1 done, this makes server errors *visible* instead of silent.
- **#108 + #109** (hardcoded strings + i18n config) — one i18n mini-batch. Same subsystem, fix together.
- **#116** (delete `ProductDetails` placeholder route + dead `RelatedArticles`) — pure deletion; do it early to stop a fake-price page being reachable and to shrink the bundle marginally.
- **#35** (BookingManage time-slot) — Area 2 filed it agent-friendly; it is the one *live* user-visible UX bug touching the frontend and slots naturally into this wave. (See the global-ordering note — it is also a frontend↔backend contract issue.)

### Wave 3 — performance

- **#18 + #114** as one performance batch. #18 (route-level code-splitting, the admin chunk especially) is the high-impact change; #114 (lazy-load images, fix HeroSection's 8-image eager load) is the low-effort complement. #18 is shared with Area 6 — see below.

### Parallel / independent track — small fixes and decisions

No ordering constraints; pick up whenever.

- **#115** (PublicMediaCard nested-interactive a11y) — localized JSX restructure.
- **#113** (ContactConfirmation `from` validation) — one-line guard.
- **#111** (article HTML sanitization) — cross-cutting backend + frontend; best fixed backend-side in `markdown_to_html`. Pairs with backend work, not frontend.
- **#112** (analytics env-gating) — needs a product decision ("should analytics fire in staging?") before implementation; once decided, mechanical. Belongs to the analytics cluster below.

### Where fixing one issue changes another's scope

- **#7 makes #110 survivable.** Independently of #110's own fix, a top-level boundary means the *next* context-initializer crash is recoverable. Do #7 first.
- **#18 is shared with Area 6.** The 2.65 MB chunk is large *because* admin code (AG Grid, TipTap, 12 admin routes) ships to public visitors. Route-level code-splitting is one PR that serves both areas; whoever picks up #18 should split at the public/admin route boundary, which is also Area 6's lazy-loading work. Do not schedule #18 twice.
- **#106 and #7 are halves of one gap.** Filing them separately is correct (routing vs. rendering), but they should land together — the "page not found" page and the "something went wrong" page are the same UX surface.

---

## Toward a global fix ordering

The third data point for the Phase 1 final report's global synthesis. 4b-2 established the bridge format: where the orderings are *independent*, where they *interact*, where *shared foundations* slot in. Applied here to the public-frontend track against the backend orderings (edu, article, services).

### Where the frontend track is independent

**Most of it.** #7, #106, #107, #108, #109, #110, #113, #114, #115, #116, and #18 are pure-frontend — no backend file, schema, or endpoint involved. The public-frontend backlog can run as its **own concurrent track** alongside every backend wave, assigned to a different person on day one with zero collision risk. This is a stronger independence statement than 4b-2 could make about the two backend pipelines (which at least shared the LLM foundation). The frontend has no shared foundation with the backend at all.

### Where the frontend track interacts with the backend orderings

Four interaction points, in decreasing order of coupling:

1. **The educator-access cluster — a frontend↔backend coordinated fix.** Area 3's #50 (server-side gate on `/public-media/*`) is the load-bearing fix. This audit confirms the frontend half: `EducatorAccessGate` + `EducatorAuthContext` are cosmetic. The global ordering should carry **one** educator-access work item: land #50 (backend gate) *and* rework the frontend so the gate reflects server truth (the client calls a real authenticated endpoint instead of trusting `localStorage`). Doing the backend alone leaves a frontend that still grants itself access; doing the frontend alone is impossible — there is no server check to call. #52 (forgeable token) and #60 (stale-cache trust) fold into the same item and stop mattering once the server enforces. This is the frontend's analog of 4b-2's "research-upload hardening" — a place where two backlogs must be *merged*, not merely sequenced.

2. **The order-confirmation / analytics cluster.** #36 (OrderConfirmation doesn't fetch the order — Area 2) is the root: its fix requires a **backend schema change** (`OrderResponse` must return the magic-link token). #47 (Meta Pixel `Purchase` value `0`) *depends on* #36 — the page can't report a real value until it fetches the order. #112 (this audit — analytics fire in every environment) is independent of both but is the same subsystem. The global ordering should carry one "order-confirmation + analytics" work item spanning backend (`OrderResponse` schema) and frontend (#36 page, #47 pixel, #112 env-gating). Sequence inside it: #36 → #47; #112 rides along.

3. **The time-slot representation cluster.** #35 (BookingManage renders every booking "Afternoon") is a frontend bug, but its *root* is a frontend↔backend value-contract split: the backend serializes `AM`/`PM`, the frontend has a `timeSlotMap` in Checkout and forgot the inverse in BookingManage. Meanwhile `CartContext` stores `morning`/`afternoon`. Three representations of one concept. #35's fix is the one-line frontend correction Area 2 specified — but the global ordering should *note* that the durable fix is one agreed representation across cart, checkout, the API, and BookingManage. A small concern, but it is exactly the kind of cross-layer contract drift the global synthesis exists to surface.

4. **#111 (article HTML sanitization) — cross-cutting, backend-resident.** The frontend `dangerouslySetInnerHTML` is the *symptom*; the fix belongs in the backend `markdown_to_html` (one chokepoint, protects every consumer of `content_html`). #111 joins the backend ordering as a small independent fix, not the frontend track.

### Where shared foundations slot in

There are none on the frontend side. The backend orderings have #76/#77/#78/#68 as a shared Wave-1 foundation. The public-frontend track has no linchpin — #7 is the closest thing to a "foundation," but it is frontend-local and gates only the frontend's own Wave 1. The global Wave 1 therefore runs **four** concurrent tracks, not three:

- **edu critical:** #97 → #91 → #90
- **article critical:** #99 (+ articles 39/40 prod cleanup)
- **LLM foundation:** #76 (+ #68, #77/#78)
- **frontend safety net:** #7 → (#110, #106)

### The asymmetry worth carrying forward

4b-2's asymmetry was *startability* (article's #99 ungated, edu's #91 gated by #97). The frontend's asymmetry is **shape**: the backend backlog is *narrow and deep* (linchpins gating clusters — get the sequence wrong and you redo work), the frontend backlog is *wide and shallow* (many independent agent-friendly fixes — sequence barely matters). For the final report's global Wave 1 this means the frontend safety-net track is the **lowest-risk, most-parallelizable** work in the entire phase: it can absorb an extra contributor with no coordination cost, and it is almost entirely agent-friendly. If Phase 2 wants an autonomous-agent entry point, Wave 1's #7/#106/#110 and Wave 2's #107/#108/#109/#116 are the cleanest candidates in the whole Phase 1 backlog.

---

## What surprised me

1. **i18n was the predicted high-finding-density area and turned out to be the cleanest.** Going in, the #35 time-slot bug suggested translation drift. The opposite: 611/610 keys, one missing ES key, and the "identical" values are all legitimate. #35 was a *value-contract* bug (`AM` vs `morning`) wearing an i18n costume — the keys themselves are fine. The two i18n findings filed (#108 hardcoded strings, #109 config) are hygiene, not drift. The walk-order bet that i18n would be finding-dense was wrong, and that is good news for the project.

2. **The worst finding is a `try/catch` that exists 50 lines away.** `EducatorAuthContext.getStored()` wraps its `JSON.parse` in `try/catch`. `CartContext` — same file directory, presumably same author, same `localStorage`-read pattern — does not, and because `CartProvider` wraps the whole app, that one missing `try/catch` is a whole-site blank-page crash waiting for one corrupt write. The safe pattern was already in the codebase. This is the public-frontend version of 4a's "one wrapper does the right thing, its sibling doesn't."

3. **The educator gate is even more cosmetic than Area 3 implied.** Area 3 established the *token* is forgeable. But you don't even need to forge a token — `localStorage.setItem('educator_access', JSON.stringify({email:'x@x.com', expiresAt:'2099-01-01'}))` in the console grants access instantly, and the media API is open anyway. The gate stops a curious teacher who doesn't open DevTools. That is its entire threat model. No new issue — #50 covers it — but it is worth saying plainly.

4. **Nothing sanitizes article HTML, anywhere.** I expected the backend `markdown_to_html` to at least run `bleach`. It doesn't — Python-Markdown with five extensions and no sanitizer, raw HTML passes straight through to a frontend `dangerouslySetInnerHTML`. It is not a public-user XSS vector (article content is LLM-generated, admin-edited), which is why it is moderate not critical. But "the LLM won't emit a `<script>` tag" is the only thing between the pipeline and a stored XSS, and that is not a control.

5. **`/producto/:slug` is a live route serving fake prices.** A reachable, Meta-Pixel-tracked URL that renders hardcoded "$180 / $45" tour pricing and ignores its slug. Not linked from nav, so low-traffic — but it is the kind of scaffold that ships to production and nobody remembers. `RelatedArticles.jsx` is its sibling: fully-fake content (fake authors, `href="#"`), and `grep` shows it is imported nowhere. Bundled into #116 as a deletion.

6. **The audit plan's severity prediction was exactly right.** "Area 5 will likely produce more nice-to-have findings and fewer critical ones." 0 critical, 6 moderate, 5 nice-to-have, 0 stop-the-line. The public frontend genuinely is lower-stakes than the services layer — there is no production data to corrupt — and the findings reflect that. The count (11) landed just above the 6–10 estimate and well inside the 15 re-scope ceiling.

---

## Process notes for the next area

- **The route-map-and-walk-order approval gate was worth it.** Mapping all public routes and proposing the walk order before reading per-page caught the #61-vs-#50 issue-number discrepancy in the brief up front (the brief said "#61, gating `/api/v1/public-media/*`"; #61 is the auth-audit-log issue — the public-media gate is #50). Resolving that before filing avoided mislabeled cross-references.

- **Building the bundle beat estimating it.** `npm run build` took 4.5 s and turned "#18 says ~2.6 MB" into "2,649,933 bytes, one chunk, here are the admin contributors." For Area 6, run the build again *after* any code-splitting prototype to measure the public/admin split concretely rather than arguing about it.

- **Batch sizes of 4/4/3 worked**, same cognitive grain as Areas 1–4. The mid-batch user adjustment (make #116 agent-friendly by reframing it as a deletion task) is a good pattern — "remove the placeholder" is genuinely agent-friendly in a way "remove or implement" is not.

- **Verify-only findings should be stated in the report, not re-filed.** #7, #18, #50, #52, #60 were all confirmed; filing duplicates would have inflated the count and split the backlog. The report's "verify-only" subsection is the right home for them. Area 6 will have its own set of these (the audit plan's Area-6 hints).

- **Area 6 entry conditions:** the admin frontend is `pages/admin/*` (12 pages), `components/admin/*` (TipTap `RichTextEditor`, AG Grid renderers, modals), `services/admin.js` (26 KB), `AdminAuthContext`, `AdminLayout`. #18's code-split work overlaps Area 6 — coordinate, don't double-schedule. The frontend `sendDefaultPii: true` (this audit) plus the backend one (Area 3/4a) is a cross-cutting Sentry item that neither area should fully own — flag it for the Phase 1 final report's cross-cutting section.

- **For the Phase 1 final report:** this is the third and final fix-ordering analysis. The global synthesis now has four tracks for Wave 1 (edu critical, article critical, LLM foundation, frontend safety net) and a clear shape contrast — backend narrow-and-deep, frontend wide-and-shallow. The frontend track is the recommended autonomous-agent entry point for Phase 2.
