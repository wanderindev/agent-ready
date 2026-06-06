# Phase 2 — Session 15: Frontend autonomous-agent experiment, F-4.C — issue #109 (i18n config + html lang)

## Identification

You are the **autonomous agent** running **F-4.C**, one of five concurrent Wave 1 agents in F-4.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body identifies two distinct concerns:
   - `debug: true` ships to production — **verified** at `frontend/src/i18n.js:16` (`debug: true,`)
   - `<html lang>` never updates on language switch — **verified**: `frontend/index.html:2` has `<html lang="en">` (static); no `i18n.on('languageChanged', ...)` listener exists anywhere to update it. The orchestrator's verification: the html lang attribute is in `index.html`, NOT in `App.jsx` (correction relative to the issue body's framing, which implied an in-React fix location).

## Parallel-mode notes

You touch `frontend/src/i18n.js` and `frontend/index.html`. Other Wave 1 agents touch BookingManage.jsx, public components, AdminOrders.jsx, and 4 admin pages. **No file overlap** with any other agent. Outcomes log is the only shared file.

## Agent-vs-brief disagreement taxonomy

Three shapes (override / follow-source / follow-brief-and-flag). For this brief, shape (2) is unlikely since the verification was thorough; shape (3) is the realistic risk if your investigation reveals additional related concerns the brief doesn't cover.

## What this experiment is testing

F-4.C tests the brief-template against a **two-concern config fix**: one obvious (`debug: true` → environment-conditional), one structural (add an event listener). Both are mechanical given the brief's specifications.

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #109** — `gh issue view 109`.
2. **`frontend/src/i18n.js`** (full file — it's short, ~25 lines) — the target for the debug-flag fix.
3. **`frontend/index.html`** — the html lang attribute lives here.
4. **`docs/pilot/phase-1-area-5-report.md`** — the audit context.
5. Prior session reports (06-12) — skim.
6. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **Fix the `debug: true` line** in `frontend/src/i18n.js`. Replace with `debug: import.meta.env.DEV,` (Vite's standard dev-only flag). This makes debug logs appear in dev only; not in production.
- **Add an `i18n.on('languageChanged', ...)` listener** to `frontend/src/i18n.js` after the `.init()` block. The listener should update `document.documentElement.lang` to the new language code. Use `i18n.on('languageChanged', (lng) => { document.documentElement.lang = lng; });`.
- **Also call** `document.documentElement.lang = i18n.language;` once after init (or inside the init's success callback) to handle the initial-page-load case (the html attribute is hardcoded to `"en"`; the user may have a `"es"` preference detected by `LanguageDetector`).
- **Leave `frontend/index.html` mostly unchanged.** The hardcoded `<html lang="en">` stays — it's the initial value before JS runs. The runtime listener overrides it.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **Other i18n config changes** (fallbackLng, namespaces, caching, etc.).
- **Adding a `LanguageSwitcher` component** if one doesn't exist (likely it does; not your concern either way).
- **No backend changes. No new dependencies.**

## Default rules for likely ambiguities

- **`import.meta.env.DEV` vs `process.env.NODE_ENV !== 'production'`** — use `import.meta.env.DEV`. It's Vite-native; the codebase is Vite-based (per `CLAUDE.md`).
- **Where to place the listener** — right after the `i18n.init(...)` call, before `export default i18n`. This way the listener registers as soon as the `i18n` module is loaded.
- **What about Sentry breadcrumb on language change?** — out of scope. Don't add it.
- **What if `LanguageDetector` is doing something with `<html lang>` already?** — the verification showed it doesn't. If you find evidence otherwise, follow the source (shape-2 disagreement) and flag.

## Self-review checklist

- [ ] `frontend/src/i18n.js`: `debug: true` → `debug: import.meta.env.DEV,`.
- [ ] `frontend/src/i18n.js`: `i18n.on('languageChanged', ...)` listener added after init.
- [ ] `frontend/src/i18n.js`: initial-load `document.documentElement.lang = i18n.language` setup (in `.then()` of init or via the listener-fires-immediately pattern — your call).
- [ ] `frontend/index.html` `<html lang="en">` left as-is.
- [ ] No other files modified (beyond outcomes-log + session report).
- [ ] `npm run lint` clean.
- [ ] `npm run build` succeeds.
- [ ] PR description: production touch line; test plan (mention manual verification: switch language in the running dev server, inspect `<html>` element's `lang` attribute in DevTools — should update); `Closes #109`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/15-frontend-f4-C-issue-109-report.md`.

## PR shape

- **Branch**: `fix/issue-109-i18n-config-debug-and-html-lang`
- **Title**: `fix(#109): i18n debug:true → env-conditional; sync <html lang> on language change`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `109` |
| Filed agent-friendly? | `yes` |
| Filed severity | `nice` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-4.C — tenth autonomous run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary. Two-concern config fix. |

## Session report

`docs/phase-2/15-frontend-f4-C-issue-109-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs.
3. Confirm the verified facts (i18n.js:16, index.html:2).
4. Apply the two changes to `i18n.js`.
5. Lint + build.
6. Self-review.
7. Open PR.
8. Append outcomes-log row; write session report.
9. **Stop.**
