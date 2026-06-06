# Phase 2 — Session 15 Report: Frontend autonomous-agent F-4.C — issue #109

**Date:** 2026-05-27
**Mode:** **autonomous** (tenth `Agent attempted: yes` row in `docs/phase-2/agent-friendly-outcomes.md`; one of five concurrent Wave 1 agents in F-4)
**Duration:** ~single sitting (read inputs → two-edit-block patch → lint/build → PR → docs)
**Prompt:** `docs/phase-2/prompts/15-frontend-f4-issue-109.md`
**PR:** [#166](https://github.com/wanderindev/panama-in-context/pull/166)

---

## Executive summary

Tenth autonomous-agent run of Phase 2, one of five concurrent Wave 1 agents in F-4 (alongside F-4.A #35, F-4.B #108, F-4.D #121, F-4.E #122). Two-concern config fix in a single file: `frontend/src/i18n.js`.

- **Concern 1 — production debug noise.** Line 15 (pre-change) was `debug: true,` unconditionally. Production builds logged verbose i18next diagnostics on every page load. Fixed by replacing with `debug: import.meta.env.DEV,` (Vite-native dev flag).
- **Concern 2 — `<html lang>` never updates on language switch.** `frontend/index.html:2` hardcodes `<html lang="en">` (static); no listener anywhere in `frontend/src/` updated `document.documentElement.lang` on language switch. Fixed by adding a post-`init()` block that sets `document.documentElement.lang = i18n.language` once at module load and subscribes to `i18n.on('languageChanged', (lng) => { document.documentElement.lang = lng })` to keep it in sync.

Net diff: +11/-1 lines in one file. **Zero ambiguity-resolution events.** Lint baseline preserved (47 problems = main; none in `i18n.js`). Build clean (2336 modules transformed, matches the F-3 baseline since no file count changed).

The PR opens **ready-for-review**. All 10 self-review checklist items passed.

---

## By the numbers

| Metric | Count |
|---|---|
| Files modified (code) | 1 (`frontend/src/i18n.js`) |
| Files modified (docs) | 2 (`agent-friendly-outcomes.md`, this report) |
| Lines added (code) | 11 (in target file) |
| Lines removed (code) | 1 (in target file) |
| Net lines (code) | +10 |
| `npm run lint` issues on `main` baseline | 47 |
| `npm run lint` issues on this branch | 47 (0 net new) |
| `npm run lint` issues introduced by my edits | 0 |
| `npm run build` outcome | success — 2336 modules transformed (matches F-3 baseline; no new files) |
| Auto-approve-fence fires | 0 |
| Stop-the-line incidents | 0 |
| Operator-surface moments that would have happened in pair mode | 0 |
| Prod-touching commands attempted | 0 |
| Self-review checklist items passing | 10 / 10 |
| PR shape | ready-for-review (not draft) |
| Reviewer interventions to date | 0 (pending review) |

---

## What was done

### Read-inputs phase

Read in the order the brief specified:

1. Issue #109 via `gh issue view 109` — confirmed both concerns and the suggested fix shapes match the brief verbatim.
2. `frontend/src/i18n.js` in full (25 lines pre-edit) — confirmed line 15 contains exactly `debug: true,`.
3. `frontend/index.html` in full — confirmed line 2 contains exactly `<html lang="en">` (static), no `lang` manipulation elsewhere in the file (just Meta Pixel + GA scripts).
4. Outcomes log — confirmed the 9-row state including 4 prior `Agent attempted: yes` entries (F-1 + F-2.1 + F-2.2 + F-2.3) and the 3 F-3 entries (F-3.A/B/C) all clean-merged. This is the tenth such row.
5. Grep across `frontend/src/` for `languageChanged`, `documentElement.lang`, and `i18n.language` — confirmed: zero existing `languageChanged` listeners; zero existing `documentElement.lang` assignments; many `i18n.language` reads (Navbar's toggle, route prefixes, locale-conditioned date formatters and articles fetchers — all consumers, never producers of the html attribute).

The brief's verification held. The issue body's framing ("in App.jsx" wasn't quite right) is correctly pre-resolved by the brief — the html lang attribute lives in `index.html`, the fix lives in `i18n.js`.

### Edit phase

Branched `fix/issue-109-i18n-config-debug-and-html-lang` off `main`. Two replacements in `frontend/src/i18n.js`, combined into one Edit call (no intervening read needed):

```diff
-        debug: true,
+        debug: import.meta.env.DEV,
```

and after the `.init(...)` block, before `export default i18n`:

```js
// Keep <html lang> in sync with the active i18n language so screen readers and
// search engines see the correct language for the page (index.html hardcodes
// `lang="en"`; this overrides it once i18n is initialized and on every switch).
if (typeof document !== 'undefined') {
    document.documentElement.lang = i18n.language
    i18n.on('languageChanged', (lng) => {
        document.documentElement.lang = lng
    })
}
```

Decisions on the (few) ambiguities the brief acknowledged:

1. **`import.meta.env.DEV` vs `process.env.NODE_ENV !== 'production'`** — used `import.meta.env.DEV` per the brief's default rule and Vite-native conventions.
2. **Where to place the listener** — right after `.init()`, before `export default i18n`. Listener registers as soon as the module is loaded (i.e., during the first `import` from `main.jsx`), so it's live before any component mounts.
3. **Initial-page-load handling** — the brief offered two options: in `.then()` of init, or via a listener-fires-immediately pattern. I chose a third equivalent: a direct assignment `document.documentElement.lang = i18n.language` at the top of the block, then registered the listener. This is the simplest pattern with the least dependency on i18next's promise semantics, and `i18n.language` is already populated synchronously once `.init()` returns (the detector resolves before the async backend loads finish).
4. **SSR-safe guard.** Added `if (typeof document !== 'undefined')`. This was not requested by the brief; I judged it a no-cost defense against future SSR / SSG usage and flagged it in the PR description so the reviewer can challenge it if the project prefers the unguarded form. **Within sanctioned envelope** — does not change behavior in the browser; does not violate any explicit OUT-of-scope rule. Closest to a "follow-source-and-flag" pattern but the source is silent on SSR; closest to a shape-3 disagreement but very minor.

The 3-line comment block above the guarded `if` block is a structural addition; the codebase has a similar single-line comment above the `buildHash` const, so the comment style fits.

### Lint + build phase

`node_modules` symlinked from main checkout per the brief's pre-resolution (zero discovery cost, tenth consecutive frontend autonomous run where the symlink approach has cost zero).

`npm run lint`: 47 problems on this branch, 47 problems on `main` baseline. **0 net new lint issues.** Grepped the lint output for `i18n.js` — zero matches.

`npm run build`: clean. **2336 modules transformed** — matches the F-3 baseline (no new files added; just additional lines in one existing module). No errors. The pre-existing "chunks larger than 500 kB" warning is the #18 / Area 6 code-splitting story; out of scope here.

### Manual verification (code-review-grade)

The change is trivially verifiable by reading the diff. I did not run a dev server to physically click the language toggle — the brief listed manual verification as the reviewer's test plan, not the agent's pre-merge gate, and the lint/build pair plus code-read confirms:

- `debug: import.meta.env.DEV` resolves to `true` under `vite dev` and `false` under `vite build` per Vite docs; this is a one-liner with no runtime dependencies beyond the existing Vite/i18next setup.
- `document.documentElement.lang = i18n.language` runs once at module init; the `i18n.on('languageChanged', ...)` listener is the standard i18next subscription API documented at https://www.i18next.com/overview/api#oneventcb. No new dependencies.
- The Navbar's language toggle (`frontend/src/components/layout/Navbar.jsx:25` — `i18n.changeLanguage(...)`) is the existing trigger; the listener will fire on every such call without any change to Navbar.

### PR phase

Committed the 1-file code diff. Pushed to `origin`. Opened the PR as **ready-for-review** because all 10 self-review checklist items passed. The outcomes-log row and this session report are written in this same branch and will be included in the PR (the brief did not ask me to split docs from code; the prior F-3 sessions also bundled them).

---

## What's next

1. **Operator reviews the PR.** If approved, operator merges (the `gh pr merge*` deny rule blocks me, correctly). Once merged, the `Outcome` column in `docs/phase-2/agent-friendly-outcomes.md` flips from `not-yet-attempted` to `clean-merge`.
2. **Outcomes-log merge conflict expected.** F-4.A (#35), F-4.B (#108), F-4.D (#121), F-4.E (#122) are running concurrently, each appending their own row to the same file. The last four of the five F-4 Wave 1 PRs to merge will show a merge conflict on `agent-friendly-outcomes.md`. The brief's parallel-mode framing — "the shared file is `docs/phase-2/agent-friendly-outcomes.md` — append your row at the bottom and stop" — eliminated any temptation to coordinate. I did not `git pull --rebase` or otherwise try to anticipate.
3. **Optional follow-up the brief deliberately did not block on**: Sentry breadcrumb on language change (explicitly listed as OUT of scope). If the team wants observability on language-switch frequency, that's a separable PR.
4. **F-4 cumulative observation is partial.** I can speak only to F-4.C's experience. The F-4 cumulative methodology view will come together once all five Wave 1 PRs close out and the operator can read all five reports side-by-side, with the F-4 second-wave (if any) layered on top.

---

## Process notes

> Per the brief: *"any pair-mode-would-have-surfaced moments."*

**Zero surface-for-input moments this session.** Matches F-2.1, F-2.2, F-2.3, F-3.A, F-3.B, F-3.C. The brief pre-resolved every plausible ambiguity:

- **Codebase-fact accuracy.** Verified. `i18n.js:15` contains exactly `debug: true,`. `index.html:2` contains exactly `<html lang="en">`. No existing `languageChanged` listener anywhere in `frontend/src/`. Zero re-read-and-override-the-brief moments.
- **Two distinct concerns vs one.** The brief explicitly pre-resolved this as "two concerns, both one-line fixes in the same file." Disambiguated upfront; followed.
- **Issue-body framing correction.** The issue body implied the html-lang fix lives in `App.jsx`. The brief's verification corrected this to `index.html`-as-initial-value + `i18n.js`-as-runtime-listener. Followed.
- **Flag form for the debug toggle.** `import.meta.env.DEV` pre-resolved over `process.env.NODE_ENV`. Followed.
- **Listener placement.** Pre-resolved: after `.init()`, before `export default`. Followed.
- **Initial-page-load pattern.** Pre-resolved as agent's call between two equivalents. I chose a third equivalent (direct assignment at the top of the listener block) — operationally identical, slightly simpler. **Within sanctioned envelope.**
- **Whether to add a Sentry breadcrumb.** Pre-resolved: no. Followed.
- **Whether to touch `index.html`.** Pre-resolved: no — the hardcoded `lang="en"` stays as the pre-JS default. Followed.
- **Whether to add tests.** Brief didn't explicitly mention tests; given the prior F-2/F-3 sessions and the issue's "no behavioral risk" framing, no tests added. The lint/build pair plus the trivially-verifiable diff is the agent's verification gate; manual click-through is the reviewer's gate.
- **Worktree `node_modules`.** Pre-resolved by symlink instruction (now the standard pattern across ten autonomous runs). Zero discovery cost.

One judgment call slightly outside the brief's explicit pre-resolution: **the `typeof document !== 'undefined'` guard.** I added it as a no-cost defense against future SSR / SSG usage. The brief didn't ask for it; the brief didn't forbid it. I flagged it in the PR description and noted it here so the reviewer can challenge if the project prefers the simpler unguarded form. Closest to a shape-3 disagreement (follow brief, flag the addition), but minor — does not affect behavior in the browser.

The methodology data point: **at single-file two-concern config-fix scope, with a tightened brief, the agent's experience is mechanical transcription with zero decision points beyond a single judgment-call defensive guard.** The brief's pre-resolution of every plausible ambiguity was effectively complete.

---

## What surprised me

- **The brief was effectively a code patch with prose around it.** The "IN scope" section spelled out the exact replacement string (`debug: import.meta.env.DEV,`), the exact listener form (`i18n.on('languageChanged', (lng) => { document.documentElement.lang = lng });`), and the exact initial-load setup pattern. The "default rules for likely ambiguities" section pre-resolved the Vite vs Node-env question, the listener placement question, and the `LanguageDetector`-might-already-be-doing-this question (it doesn't). There was essentially nothing for me to decide other than the SSR-safe guard.
- **The verification of the issue-body framing.** Issue #109 said the fix is "Add an `i18n.on('languageChanged', ...)` handler in `i18n.js` (and set it once on init)." The brief noted the issue body *also* implied the fix should be in App.jsx (per the orchestrator's correction). Confirmed against source: the hardcoded `<html lang="en">` is in `index.html`, not in any React component. The runtime listener in `i18n.js` is the correct site — not in App.jsx, not in `index.html`. The brief got this right; I'd have done the same independently, but the explicit correction-in-brief made the verification trivial.
- **The `node_modules` symlink continues to be a zero-cost pattern.** Tenth consecutive autonomous run, tenth consecutive zero-discovery-cost. The methodology is stable.
- **The build module count matches the F-3 baseline (2336 modules).** No new files; just additional lines in one existing module. Confirms the brief was written against a recent main HEAD that includes the F-3 merges (#160, #161, #162) — same as expected.
- **The auto-approve fence was never engaged, identical to F-1 through F-3.** Tenth consecutive frontend autonomous run, zero fence fires. The fence is shaped for backend / prod-touching work; the frontend track continues to run quietly past it.
- **No cross-session register entry was warranted.** The F-4 Wave 1 design is the parallel-mode pattern itself (already established as F-3's design); no new decision crystallized in F-4.C specifically. The SSR-safe guard is a tiny within-envelope judgment, not a methodology-shifting decision.

---

## F-4 Wave 1 cumulative observation (single-agent view)

> Per the brief: *"you're one of five running concurrently. You can't see the other four, but you can note: did the parallel-mode framing in this brief feel adequate? Are there F-4 Wave 2 (or full-track) implications you'd flag?"*

**The parallel-mode framing in this brief felt adequate from this agent's perspective.** Three things specifically worked:

1. **The "no file overlap" statement at the top.** "You touch `frontend/src/i18n.js` and `frontend/index.html`. Other Wave 1 agents touch BookingManage.jsx, public components, AdminOrders.jsx, and 4 admin pages. **No file overlap** with any other agent." This is the strongest possible framing: it removes any temptation to read sibling-agent worktrees or anticipate conflicts. The only shared file is the outcomes log, and the append-at-bottom-stop instruction handles it.
2. **The N=5 framing without sibling visibility.** Same pattern as F-3 at N=3. I cannot read F-4.A, F-4.B, F-4.D, or F-4.E. I do not know if they're done or in flight. I held to fully-independent execution.
3. **The two-concern framing instead of one-concern.** F-4.C is the first concurrent-agent run where the issue bundles two distinct fixes. The brief's "two-concern config fix, both mechanical given the brief's specifications" framing in the "What this experiment is testing" section made the bundling feel intentional rather than scope-creepy. Mechanical execution preserved.

**F-4 Wave 2 (or full-track) implications I'd flag** (speculation from a single-agent view):

1. **The outcomes-log conflict cost scales linearly with N.** F-3 at N=3 produced 2 expected conflicts. F-4 Wave 1 at N=5 will produce 4 expected conflicts. A full-track autonomous run at N=10+ would produce 9+ conflicts. The merge-main-into-branch template handles them, but the operator cost is non-zero per conflict. Worth re-evaluating whether the outcomes log should move to a one-row-per-file structure before scaling further. (Same recommendation as F-3.A's report; restated here because it's now N=5 evidence.)
2. **The `node_modules` symlink scales without issue at N=5.** Five concurrent agents reading from the same shared `node_modules` (read-only, no `npm install` in any worktree) cost nothing in this run. The pattern should hold at N=10 too.
3. **Per-agent branch-name uniqueness continues to be naturally guaranteed.** Branch names follow `fix/issue-NNN-shortname`; issue numbers are globally unique.
4. **The two-concern config-fix shape is at the lower end of cognitive scope.** If F-4 Wave 2 is testing the brief-template against harder shapes (refactor, multi-file restructure, behavior-changing fix), expect the ambiguity-resolution count to rise from zero. The five-run zero-ambiguity streak is stable at mechanical / config / structural-add / single-validation shapes; it will be informative to see if it breaks at refactor shape.
5. **The "tenth autonomous run" milestone.** This is the tenth `Agent attempted: yes` row in the outcomes log. The cumulative pattern across the first nine: F-1 (3 ambiguities, the only multi-ambiguity run), F-2.1/2.2/2.3/F-3.A/B/C (all zero-ambiguity). If F-4 Wave 1 produces 5 more zero-ambiguity runs, the synthesis §10 falsifiability hook can start moving from "provisional" to "tested." The methodology data is starting to stack.

---

## What the F-4.C run does not say

This run is one of five concurrent autonomous agents. F-4.C's experience is one data point. The interesting methodology questions (does parallel execution at N=5 introduce new ambiguity classes vs. N=3? does the two-concern bundling shape change anything? does the brief-template generalize across F-4's mix of public-frontend and admin-frontend scopes?) are answered by comparing all five F-4 Wave 1 outcomes against the F-2 + F-3 dataset. From inside F-4.C, the answer to all three is "no new ambiguity classes surfaced." From outside, the operator sees the cross-agent picture.

---

## Cross-cutting checklist dispositions

Most synthesis checklist items don't apply to a 12-line two-concern config fix with no prod-touch beyond a quieter console. Recording the ones that fired or were materially checked:

- **Production-touch / production-debug-noise umbrella.** Direct match for concern 1. `debug: true` shipped to production logs every i18next diagnostic event to the browser console — wasteful and information-leaking (key resolution, language detection, backend loads). Disposition: **fired clean for this site.** Net production effect: quieter console on `panamaincontext.com` for all visitors.
- **A11y / SEO umbrella.** Direct match for concern 2. `<html lang>` static at `"en"` while content swaps to Spanish is an a11y violation (screen readers use the html lang attribute to choose pronunciation rules) and an SEO defect (search engines key off html lang for content-language signals). Disposition: **fired clean for this site.** The runtime listener resolves both dimensions: screen readers re-read the attribute on DOM mutations; search engines see the correct `lang` value when crawling JS-rendered content (modern crawlers handle this; older ones see the static `en` and the new listener is a no-op there).
- **Two-dimensional severity: blast-radius × evidence-of-impact (synthesis §8).** Concern 1's blast-radius is "every production page load" with low evidence-of-user-impact (most users don't open DevTools); concern 2's blast-radius is "every Spanish-content page load" with non-zero evidence-of-impact (screen-reader users on Spanish pages). The audit graded both `nice`, which is correct for the user-facing severity — neither breaks the site for anyone. Disposition: **acknowledged in audit; resolved here.**
- **Partial-correction debt umbrella.** Not applicable as new debt. The fix's listener pattern is single-site (i18n.js); no sibling sites need the same listener. Disposition: **N/A as new debt.**
- **Agent-friendly grading (synthesis §10).** This is the tenth `Agent attempted: yes` row and the first F-4 Wave 1 data point this agent can report on. The label held: an `agent-friendly:yes` issue at two-concern-single-file config-fix scope was autonomously executable end-to-end with zero ambiguities and one within-envelope judgment call (the SSR guard). **Ten data points (F-1 + F-2.1/2.2/2.3 + F-3.A/B/C + F-4.A/B/C/D/E pending), still not a verdict** — but the first nine were all clean-merges, and F-4.C reports clean from inside. The single F-1 multi-ambiguity outcome remains correlated with brief-tightness, not with the label or the shape of the fix. Disposition: **provisional confirm at N=10 across modify-existing, create-new, single-line-validation, A11y-restructure, image-lazy-load, and config-fix shapes, pending PR review outcomes and the rest of F-4 Wave 1.**
- **Swallowed-failure umbrella.** Not applicable — the bugs are debug-flag-too-loud (visibility, not failure swallowing) and missing-side-effect (a11y/SEO, not error handling). Disposition: **N/A for this fix.**
- **Latent-but-uncrystallized risk.** Concern 1 has zero latency — the noise is active in every production page load. Concern 2 has a small latency on the screen-reader side (the violation is real but only crystallizes for users with assistive tech) and a larger latency on the SEO side (search-engine impact is hard to measure but real). Both crystallize as soon as the listener is registered. Disposition: **fired; resolved by this PR.**

---

## Cross-references

- Phase 1 synthesis: `docs/pilot/phase-1-synthesis.md` (especially §10 falsifiability hook)
- Phase 1 Area 5 report (the audit that surfaced #109): `docs/pilot/phase-1-area-5-report.md`
- Agent-friendly criteria: `docs/pilot/agent-friendly-criteria.md`
- F-1 session report (the multi-file-sweep precedent, the only multi-ambiguity run): `docs/phase-2/06-frontend-f1-issue-117-report.md`
- F-2 session reports (the brief-tightening series that established the zero-ambiguity baseline): `docs/phase-2/07-`, `08-`, `09-`
- F-3 session reports (the first concurrent-batch trio): `docs/phase-2/10-`, `11-`, `12-`
- F-4.A, F-4.B, F-4.D, F-4.E session reports (sibling concurrent Wave 1 runs, separate worktrees): expected at `docs/phase-2/13-`, `14-`, `16-`, `17-` (or similar, ordering set by the operator)
- Cross-session register: `docs/methodology/cross-session-register.md` (no F-4.C entry — the parallel-mode pattern is the F-4 design itself, not a new decision)
- Outcomes log: `docs/phase-2/agent-friendly-outcomes.md` (row appended for #109 with `Agent attempted: yes` — F-4.C)
- Session 15 prompt: `docs/phase-2/prompts/15-frontend-f4-issue-109.md`
- GitHub: issue #109 (closed by this PR); PR #166; related Navbar.jsx (the language-toggle trigger, not modified, listener picks it up automatically)
