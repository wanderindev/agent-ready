# Phase 2 — Session 20: F-4.H session report (issue #119, beforeunload guard foundation)

## Identification

- **Wave**: F-4 Wave 2 (concurrent with F-4.F #116, F-4.G #118, F-4.I #120).
- **Run index**: F-4.H — fifteenth autonomous agent run.
- **Shape**: infrastructure-only — a hook with no immediate consumers.
- **Issue**: [#119](https://github.com/wanderindev/panama-in-context/issues/119) — *No beforeunload guard — browser refresh/close/back discards unsaved admin edits*.
- **Branch**: `fix/issue-119-beforeunload-guard-foundation`.
- **PR**: see Outcomes-log row.

## What this run tested

Whether an autonomous agent can ship a "foundation" cleanly — a new module + a single
install site — when no end-to-end test surface exists yet (no consumer wires into the
hook, so the listener is provably never installed at runtime today). The methodology
risk: the lack of an observable behavior change could make the agent anxious / off-scope
(invent consumers, file a follow-up PR mid-stream, expand into EditDrawer.jsx, etc.).

## What landed

**File created** — `frontend/src/hooks/useBeforeUnload.js` (new, ~30 lines incl. JSDoc):

- Exports a single named hook `useBeforeUnload(when)`.
- When `when` is truthy, installs a `window.beforeunload` listener that calls
  `e.preventDefault()`, sets `e.returnValue = ''`, and returns `''` — the canonical
  no-op idiom that triggers the browser's default "Leave site?" dialog. Modern browsers
  ignore custom message strings; the brief pre-resolved this.
- Cleanup removes the listener; the effect depends on `[when]`, so flipping the boolean
  installs / removes the listener exactly once per transition.

**File modified** — `frontend/src/components/layout/AdminLayout.jsx`:

- Imported `useBeforeUnload` from `../../hooks/useBeforeUnload`.
- Inside `AdminLayoutInner` (the component that wraps the entire admin shell, rendered
  inside `AdminAuthProvider`), added a `useBeforeUnload(false)` call with a TODO
  comment explicitly linking back to issue #119 and naming the follow-up shape: a
  small React context populated by per-editor dirty signals (and pointing at sibling
  issues #118 and #120 which add the per-editor tracking).

## What did not change

- `frontend/src/components/admin/EditDrawer.jsx` — owned by F-4.G (#118) and F-4.I (#120) in Wave 2.
- `frontend/src/App.jsx` — owned by F-4.F (#116) in Wave 2.
- Any admin page (e.g., `AdminSettings`, `AdminOrders`, `AdminCalendar`) — the brief
  explicitly out-of-scoped per-page wiring; the issue body lists those as future
  consumers, not Wave 2 work.
- No new dependencies, no Context/Provider, no backend changes.

## The "no consumers wired" tension

The brief flagged this as the most likely agent-vs-brief disagreement: the listener
never installs at runtime today, so a strict "ship code that does something" rule would
delete the wiring entirely and just ship the hook file. Pre-resolution from the brief:
**ship the foundation anyway** — the value is establishing the API + single install
site so a future small PR (or one of the in-flight Wave 2 PRs, if the operator chooses
to extend their scope before merge) can flip the `false` to a real dirty-state signal
without touching `AdminLayout`'s structure again. The PR description flags this
tension and recommends the operator file or schedule a follow-up issue for
"plug per-editor dirty state into useBeforeUnload."

The hook itself is also independently testable by hand: temporarily change
`useBeforeUnload(false)` to `useBeforeUnload(true)` in dev, navigate away, observe the
browser warning. This manual test is documented in the PR's Test plan and was used
to confirm the implementation behaves correctly before reverting to `false` for commit.

## Ambiguity-resolution events

**Zero.** The brief pre-resolved:

- Filename (`useBeforeUnload.js`, not `.jsx`).
- Hook signature (`useBeforeUnload(when)`, single boolean).
- Install site (`AdminLayoutInner`, not `App.jsx`).
- The "modern browsers ignore custom strings" gotcha.
- The "what about page-level beforeunload" question (out of scope; AdminLayout-level
  is the right granularity for "any admin edit").
- The "but no consumer is wired" disagreement (ship anyway; flag in PR).
- The `node_modules` symlink (pre-documented).
- The TODO comment requirement at the install site.

Within-band defensive choices I made:

- The hook lives in a new `frontend/src/hooks/` directory (the directory did not exist
  in main; created it). This matches the convention I've seen across many React
  codebases — but the brief did not explicitly mandate it over, say, `frontend/src/utils/`.
  Reasoning: hooks/ is the React-idiomatic location, and a future PR adding more
  custom hooks will land here naturally.
- The TODO comment is a JSX block comment placed immediately above the
  `useBeforeUnload(false)` call site, naming both issue #119 (the issue this PR
  closes) and issues #118 / #120 (where the per-editor dirty tracking is being added
  concurrently). I went slightly longer than the brief's minimum because the install
  site is otherwise unobvious — `false` reads as dead code without context.

## Verification

- `npm run lint`: **47 problems (33 errors, 14 warnings)** — identical to the main
  baseline confirmed by `git stash && npm run lint && git stash pop`. Zero new lint
  hits from my two-file diff.
- `npm run build`: clean, 2337 modules (main baseline was 2336; +1 = my new hook
  file). Same gzipped sizes give-or-take rounding (`index-*.js` ≈ 733.81 kB gzip).
- Manual smoke: confirmed by toggling `useBeforeUnload(true)` in dev, attempting
  navigation, observing the browser dialog, then reverting to `false`. Listener
  install + cleanup behave as expected; no console warnings.

## Self-review checklist

- [x] `frontend/src/hooks/useBeforeUnload.js` created (new file, named export).
- [x] `frontend/src/components/layout/AdminLayout.jsx` modified: import added, hook
      called with `false` inside `AdminLayoutInner`, TODO comment explains the
      consumer-wiring follow-up.
- [x] No `EditDrawer.jsx` or `App.jsx` changes.
- [x] Lint clean vs. main baseline (47 = 47).
- [x] Build succeeds.
- [x] PR description: production-touch line, foundation-only disclosure,
      "future-PR consumers" tension flagged, Test plan with manual-verification
      steps, `Closes #119`, Claude Code footer.
- [x] Outcomes-log row appended.
- [x] Session report (this file) at `docs/phase-2/20-frontend-f4-H-issue-119-report.md`.

## Methodology data point

Fifteenth autonomous run; **infrastructure-only shape** — the first F-series run where
the diff ships code that demonstrably does nothing at runtime today (the hook's effect
short-circuits on `!when`, and `when === false` at the only call site). The brief's
pre-resolution of the "but why ship a hook with no consumers?" question was the
load-bearing piece that kept the run on rails — without it, the agent's reasonable
move would be to either widen scope (touch EditDrawer.jsx, violating the
file-ownership boundary with F-4.G/F-4.I) or narrow scope (ship the hook file only,
skip the AdminLayout wiring, leaving zero install sites for future PRs to point at).

Zero ambiguity-resolution events, matching every F-4 Wave 1 run (F-4.A/B/C/D/E) and
all three F-3 runs and all three F-2 runs. The brief-tightening discipline established
in session 06 generalizes from single-file fixes → mechanical sweeps → text extraction
→ a11y restructure → modal-dismissal sweeps → confirm-dialog sweeps → **infrastructure-only
foundations**. The pattern: when the brief pre-resolves the "why does this matter"
disagreement, the agent doesn't litigate it in-session.

## Concurrency notes (Wave 2)

Wave 2 has four concurrent agents. File-ownership boundaries observed:

- **F-4.H (this run)**: created `frontend/src/hooks/useBeforeUnload.js`; modified
  `frontend/src/components/layout/AdminLayout.jsx`.
- **F-4.F (#116)**: owns `frontend/src/App.jsx`.
- **F-4.G (#118)**: owns one half of `frontend/src/components/admin/EditDrawer.jsx`
  (ResearchEditor dirty tracking).
- **F-4.I (#120)**: owns the other half of `frontend/src/components/admin/EditDrawer.jsx`
  (OutlineEditor dirty tracking).

The only contested file across all four runs is `docs/phase-2/agent-friendly-outcomes.md`
— the shared outcomes log. Row-append conflicts are expected and the operator resolves
them when merging the four PRs. From this agent's perspective, F-4.F/G/I are
unobservable in flight (separate worktrees, separate branches); the brief's
file-ownership table is the only coordination mechanism, and it was sufficient.

The interesting cross-agent observation: F-4.G and F-4.I are adding per-editor dirty
tracking to `EditDrawer.jsx` but **not** consuming the `useBeforeUnload` hook this run
ships — that's deliberate per the brief, and the right call given the parallel-mode
constraints. The natural follow-up PR (post-merge of all four Wave 2 PRs) is a small
context that bridges the per-editor dirty signals from F-4.G/F-4.I into the
AdminLayout install site this PR establishes. Whoever writes that follow-up will see
the TODO comment in `AdminLayout.jsx` and the cross-references to issues #118 / #120.
