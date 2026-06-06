# Phase 2 — Session 20: Frontend autonomous-agent experiment, F-4.H — issue #119 (beforeunload guard foundation)

## Identification

You are the **autonomous agent** running **F-4.H**, one of four concurrent Wave 2 agents in F-4.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body says "No beforeunload guard — browser refresh/close/back discards unsaved admin edits." **Verified**:
   - No `beforeunload` listener exists anywhere in `frontend/src/` (grep returned 0 results).
   - `frontend/src/components/layout/AdminLayout.jsx` exists at 288 lines and is the natural top-level listener location.
   - F-4.G (#118) and F-4.I (#120) are concurrently adding per-editor dirty tracking to ResearchEditor and OutlineEditor. **Your fix is scope-resolved to be INDEPENDENT of them**: you ship the foundation (a custom `useBeforeUnload` hook + AdminLayout listener) without requiring the editors to use it. Future PRs can wire editors in.

## Parallel-mode notes (CRITICAL)

Wave 2: you (F-4.H) + F-4.F (#116, App.jsx + deletes) + F-4.G (#118, EditDrawer ResearchEditor) + F-4.I (#120, EditDrawer OutlineEditor) run concurrently.

**Your file ownership**:
- CREATE: `frontend/src/hooks/useBeforeUnload.js` (NEW FILE)
- MODIFY: `frontend/src/components/layout/AdminLayout.jsx`

**Do NOT modify**:
- `frontend/src/components/admin/EditDrawer.jsx` (F-4.G + F-4.I own this; they're adding per-editor dirty tracking but NOT consuming your hook — that's a future PR's job).
- `frontend/src/App.jsx` (F-4.F owns this).
- Any other admin page.

**Your scope is "ship the foundation"**: the hook exists, AdminLayout installs the listener with a default no-op predicate. Consumers can plug in later.

## Agent-vs-brief disagreement taxonomy

Three shapes. Most likely for this brief: (3) — you may realize the foundation pattern is unhelpful without consumers (the listener never fires, so why ship it?). The pre-resolution: **ship the hook anyway** to establish the API + foundation. Flag the "but no consumers wired in" tension in the PR description; the operator decides whether to file a follow-up.

## What this experiment is testing

F-4.H tests **infrastructure-only shipping**: a hook with no immediate consumers. The methodology question: can autonomous agents ship "foundation" cleanly, or does the lack of an end-to-end test surface make them anxious / off-scope?

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #119** — `gh issue view 119`.
2. **`frontend/src/components/layout/AdminLayout.jsx`** (full file — ~288 lines) — your target for the listener wiring.
3. **`frontend/src/contexts/EducatorAuthContext.jsx`** (top 25 lines) — reference for the existing pattern of localStorage + React Context (just for style guidance; don't import).
4. **`docs/pilot/phase-1-area-6-report.md`** — the audit that surfaced #119.
5. Prior session reports — skim.
6. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

**Create the hook file** `frontend/src/hooks/useBeforeUnload.js`:

```jsx
import { useEffect } from 'react'

/**
 * Install a window.beforeunload listener while `when` is true.
 * When the user attempts to close/refresh/navigate-away, they get the browser's
 * default "You have unsaved changes" warning.
 */
export function useBeforeUnload(when) {
    useEffect(() => {
        if (!when) return
        const handler = (e) => {
            e.preventDefault()
            e.returnValue = ''
            return ''
        }
        window.addEventListener('beforeunload', handler)
        return () => window.removeEventListener('beforeunload', handler)
    }, [when])
}
```

**Wire AdminLayout to install the listener** with a default `false` predicate (foundation only):

```jsx
import { useBeforeUnload } from '../../hooks/useBeforeUnload'
// ...inside AdminLayout component
useBeforeUnload(false)  // foundation: no consumers wired yet; future PRs can lift this to a context/state
```

**Add a TODO comment** at the AdminLayout call site noting that future PRs (or a follow-up issue) should wire this to a real "is any editor dirty?" signal — see issue #119's body and reference issues #118 / #120 which add per-editor dirty tracking.

**Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **EditDrawer.jsx** (F-4.G/F-4.I's territory).
- **App.jsx** (F-4.F's territory).
- **A React Context for dirty state** (out of scope; the hook accepts a simple boolean predicate; future PR can introduce a context if needed).
- **Wiring per-editor dirty signals** into the hook (out of scope; that's the future PR).
- **Backend changes. No new dependencies.**

## Default rules for likely ambiguities

- **Filename**: `useBeforeUnload.js` (not `.jsx`; pure JS, no JSX). Path: `frontend/src/hooks/useBeforeUnload.js`. If the `hooks/` directory doesn't exist yet, create it.
- **Hook signature** — `useBeforeUnload(when)` takes a single boolean. If `when` is true, the listener is installed; if false, no listener. Mirror common React patterns.
- **Custom message in the dialog** — modern browsers ignore custom strings (they always show their own default text). The `e.returnValue = ''` and `return ''` lines are the canonical no-op setup that triggers the dialog. Don't try to customize the message.
- **What if the AdminLayout already imports many hooks** — add your import to the existing import block.
- **What about page-level beforeunload (not admin-wide)?** — out of scope. AdminLayout-level is sufficient for "any admin edit"; per-page is finer than the issue asks for.

## Self-review checklist

- [ ] `frontend/src/hooks/useBeforeUnload.js` created (new file).
- [ ] `frontend/src/components/layout/AdminLayout.jsx` modified: imports the hook; calls `useBeforeUnload(false)` with a TODO comment.
- [ ] No EditDrawer.jsx or App.jsx changes.
- [ ] `npm run lint` clean — no new issues vs main baseline.
- [ ] `npm run build` succeeds.
- [ ] PR description: production touch line; explanation that this ships the foundation only (no consumers wired); mention the "future-PR consumers" tension; test plan (mention manual verification: in dev, temporarily change `useBeforeUnload(false)` to `useBeforeUnload(true)`, navigate away, verify the browser warning appears — then revert before commit); `Closes #119`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/20-frontend-f4-H-issue-119-report.md`.

## PR shape

- **Branch**: `fix/issue-119-beforeunload-guard-foundation`
- **Title**: `fix(#119): add useBeforeUnload hook + AdminLayout foundation (consumers in follow-up)`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `119` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-admin` |
| Agent attempted? | `yes` (F-4.H — fifteenth autonomous run; infrastructure-only shipping shape) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary. Note: infrastructure-only, no consumers wired; follow-up needed to plug editors in. |

## Session report

`docs/phase-2/20-frontend-f4-H-issue-119-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs.
3. Create the hook file.
4. Wire AdminLayout (import + call with `false` + TODO).
5. Lint + build.
6. Self-review.
7. Open PR.
8. Outcomes-log row + session report.
9. **Stop.**
