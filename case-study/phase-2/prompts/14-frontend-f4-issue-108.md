# Phase 2 — Session 14: Frontend autonomous-agent experiment, F-4.B — issue #108 (hardcoded English strings sweep)

## Identification

You are the **autonomous agent** running **F-4.B**, one of five concurrent Wave 1 agents in F-4. Launched via Agent tool with `isolation: "worktree"`. F-4 closes the experiment at N=16.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.** Source-contradicts-brief: follow source, surface in PR.
3. **Count interpretation, pre-resolved.** The issue body doesn't specify a count. **Verified scope**: rough grep of `>[A-Z][a-zA-Z ]{4,}<` across public components yielded ~80 candidate sites, BUT this overcounts (the pattern matches class-name-adjacent text and some legitimate already-translated strings). **Your job is the precise count.** Use `grep` + manual review to identify genuine hardcoded English in JSX `>...<` text nodes that should be translation keys. Document the exact count in the PR description.

## Parallel-mode notes

Wave 1 has 5 concurrent agents on independent files. You touch public components: `frontend/src/components/public/*.jsx`, `frontend/src/components/sections/**/*.jsx`, and any public `frontend/src/pages/*.jsx` (NOT admin pages — those are under `pages/admin/`). Other agents touch BookingManage.jsx (F-4.A), i18n.js + index.html (F-4.C), AdminOrders.jsx (F-4.D), 4 admin pages (F-4.E). No code-file overlap expected. Outcomes log is the shared file; append your row at the bottom.

## Agent-vs-brief disagreement taxonomy

When the brief and source disagree, recognize the shape:
1. Brief said exclude, source implied include → override, flag in PR.
2. Brief factually wrong about codebase → follow source, flag.
3. Brief correct for primary case, missed a sub-case → follow brief AND flag.

For this brief: shape (3) is the most likely. If a "hardcoded English" candidate is actually a domain term (a place name, a brand, a TODO comment, etc.) that shouldn't be translated, follow the brief's translation discipline but flag the sub-case in the PR description.

## What this experiment is testing

F-4.B tests the brief-template against the **broadest-scope sweep in F-4**: ~50-80 hardcoded strings across multiple public component files, each needing extraction to `t()` calls plus translation-key additions in en/es JSON files. F-1's 22-block sweep argued sweeps work at moderate scale; this tests at larger scale and a different shape (text extraction, not error-handling).

If you get stuck, open a draft PR and stop.

## Read these first, in order

1. **Issue #108** — `gh issue view 108`. The full body.
2. **`docs/pilot/phase-1-area-5-report.md`** — the audit that surfaced #108.
3. **Sample public component using `useTranslation` correctly** — for example, `frontend/src/pages/Home.jsx` or `frontend/src/pages/Contact.jsx`. The canonical pattern: `import { useTranslation } from 'react-i18next'`; `const { t } = useTranslation()`; `<p>{t('home.hero.title')}</p>`.
4. **`frontend/public/locales/en/translation.json`** and **`frontend/public/locales/es/translation.json`** — the namespace structure. Existing namespaces include `home`, `tours`, `excursions`, `blog`, `contact`, `booking`, `educators`, etc. Add new keys under sensible existing namespaces or create new ones consistent with the structure.
5. **Prior F-1 to F-3 session reports** — skim only.
6. **`docs/phase-2/agent-friendly-outcomes.md`** — outcomes log format.
7. **`.claude/settings.json`** — fence rules.
8. **`CLAUDE.md`** — project conventions.

## Scope — structural guards

### IN scope

- **Find** hardcoded English strings in JSX text nodes across `frontend/src/components/public/*.jsx`, `frontend/src/components/sections/**/*.jsx`, and `frontend/src/pages/*.jsx` (public pages only). Use `grep -rEn ">[A-Z][a-zA-Z ]{4,}<"` as a starting point and refine. The pattern catches `>Welcome<`, `>Get started<` etc. — review each candidate.
- **Extract** each genuine hardcoded string to a `t('namespace.key')` call. Add the key + the English value to `en/translation.json` and the Spanish translation to `es/translation.json`. Use existing namespace structure; create new keys under sensible names.
- **Wire `useTranslation`** in components that don't already import it.
- **Each component file that gets edits**: confirm the `useTranslation` hook is imported and called once at the top.
- **One PR** with all the sweep edits.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **Admin components** (under `frontend/src/components/admin/` or `frontend/src/pages/admin/`).
- **Decorative text that's never user-facing** (e.g., `aria-hidden` icon labels, dev comments).
- **String values in JS that aren't user-facing** (variable names, debug strings, error messages thrown for developers).
- **Place names, brand names, the literal "Panama"** (proper nouns — pass through unchanged).
- **Toast/alert messages already in service-layer code** (those are caller-controllable; out of scope unless they're in a public component file).
- **No new dependencies.** No `.env*` writes.

## Default rules for likely ambiguities

- **Spanish translation accuracy** — if you're unsure, use a literal/conservative translation. The Spanish translations can be reviewed and improved by a native speaker in a follow-up.
- **Namespace selection** — match existing patterns (e.g., text in `Home.jsx` goes under `home.*`; text in a hero section goes under the hero's section namespace).
- **Key naming** — kebab-case or camelCase consistent with existing keys in the same namespace.
- **What if the same English text appears in 2+ components?** — extract a SHARED key (e.g., `common.viewMore`) only if the text is genuinely shared semantically. Otherwise, give each context its own key.
- **What about interpolations** (e.g., `<p>Welcome, {user.name}</p>`)? — use `t('namespace.key', { name: user.name })` and structure the key as `"Welcome, {{name}}"` in the JSON.
- **What about long paragraphs?** — fine as single keys. Multi-sentence values are normal in i18n.
- **What if I find a string that's already in a `t()` call** but wrapping is malformed? — leave it alone; out of scope.

## Self-review checklist

- [ ] Counted candidate sites; reviewed each; extracted N genuine hardcoded strings. Report N in PR description.
- [ ] N matching keys added to both `en/translation.json` and `es/translation.json`.
- [ ] Every modified component imports and uses `useTranslation`.
- [ ] No admin files touched.
- [ ] `npm run lint` clean — no new issues vs main baseline.
- [ ] `npm run build` succeeds.
- [ ] PR description contains: production touch line; the count of strings extracted; test plan; `Closes #108`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/14-frontend-f4-B-issue-108-report.md`.

## PR shape

- **Branch**: `fix/issue-108-hardcoded-english-strings-sweep`
- **Title**: `fix(#108): extract hardcoded English strings to i18n keys across public components`
- **Body**: summary (note the actual count of sites); `Production touch: no`; self-review checklist; test plan; `Closes #108`; Claude Code footer.

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `108` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-public` |
| Agent attempted? | `yes` (F-4.B — ninth autonomous run; broadest-scope F-4 sweep) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary; report exact site count. |

## Session report

Write to `docs/phase-2/14-frontend-f4-B-issue-108-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs.
3. Grep to inventory candidate sites; review each.
4. Extract to t() calls; add translation keys; wire useTranslation imports.
5. Run lint + build.
6. Self-review checklist.
7. Open PR.
8. Append outcomes-log row; write session report.
9. **Stop.**
