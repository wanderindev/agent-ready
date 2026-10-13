# Fix brief — issue #60: [Quality] EducatorAuthContext grants access from stale localStorage on network error

## Identification

You are an autonomous agent resolving issue #60 in the Panama In Context (`panama-in-context`) codebase. You were launched via the Agent tool with `isolation: "worktree"` — you are in an isolated git worktree branched from `main`. The orchestrator is NOT in the loop during your run; you finish, open a PR, and the operator reviews it.

This brief is your contract. Every codebase fact below was verified against source at brief-writing time. If you read the source and it contradicts this brief, follow the source and flag the discrepancy in your PR description (see the disagreement taxonomy below).

## Operational notes

- This is a frontend (React 19 + Vite) change. Your worktree has no `frontend/node_modules` (gitignored). Near the start of your run, create the symlink so lint/build work:
  `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`
  Zero diff impact (gitignored).
- Verification is **lint + build only**. There is NO frontend test infrastructure: `frontend/package.json` has no `test` script and no vitest/jest/@testing-library dependency. Do not add tests or a test harness — that is out of scope.
- Lint: `cd frontend && npm run lint` (eslint). Build: `cd frontend && npm run build` (vite build).
- The fix is client-side only. The real server-side access gate is tracked separately (issue #50); do not attempt server work.

## When this brief and the source disagree — the four shapes

1. **Brief said exclude, source implies include** → include it and flag in the PR description.
2. **Brief is factually wrong about the codebase** → follow the source, not the brief; flag in the PR description.
3. **Brief is correct for the primary case but didn't anticipate a sub-case** → follow the brief AND surface the tension in the PR description for the reviewer to decide.
4. **You see a clearly-improvable adjacent thing within the issue's intent** → make the improvement and flag it transparently. Do NOT expand scope beyond the issue's intent.

In all four: the PR description is where you surface the disagreement. Never silently work around a brief-vs-source mismatch.

## The task (verified facts)

**Root cause** — `frontend/src/contexts/EducatorAuthContext.jsx`, the mount `useEffect` catch branch (lines 59-64, current source):

```jsx
.catch(() => {
  // Network error — trust local cache if not expired
  if (!stored.expired) {
    setHasAccess(true);
  }
})
```

On a network error during the mount-time `educatorCheckAccess` call, this grants access (`setHasAccess(true)`) purely from a stale localStorage row. Per the issue's "Desired state": network errors must NOT grant access — leave `hasAccess` false and surface a "we can't verify your access right now" message so the user can retry.

The context renders no UI of its own; the consumer `frontend/src/components/public/EducatorAccessGate.jsx` renders the gate (it reads `{ hasAccess, loading: authLoading, grantAccess }` from the context at line 19). So the fix has three parts:

**Part 1 — `EducatorAuthContext.jsx`:**
- Add a new state flag: `const [verifyError, setVerifyError] = useState(false);` (place it next to the existing `const [loading, setLoading] = useState(false);` at line 30).
- Rewrite the catch branch (lines 59-64) to NOT grant access and to set the error flag:
  ```jsx
  .catch(() => {
    // Network error — do NOT grant access from stale local cache.
    // Surface a "can't verify" state so the user can retry.
    setHasAccess(false);
    setVerifyError(true);
  })
  ```
- In the `.then` success branch, reset the flag on a successful resolution. Add `setVerifyError(false);` at the top of the `.then((result) => { ... })` body (before the `if (result.has_access)` check) so a later successful check clears a prior error.
- Expose `verifyError` through the context Provider `value` (the object at lines 86-88: `value={{ email, hasAccess, expiresAt, loading, grantAccess, logout }}`). Add `verifyError` to that object: `value={{ email, hasAccess, expiresAt, loading, verifyError, grantAccess, logout }}`.

**Part 2 — `EducatorAccessGate.jsx`:**
- Pull `verifyError` from the context: change line 19 to `const { hasAccess, loading: authLoading, verifyError, grantAccess } = useEducatorAuth();`.
- When `verifyError` is true (and the user has no access), render the network-unavailable message. The simplest mirror of the existing pattern: in the LOGIN view (the default return, lines 314-360), show the unavailable message using the same `{message && <p className={...}>{message}</p>}` mechanism. Since `verifyError` is context state (not the local `message` state), add a dedicated line just below the existing `{message && ...}` line at line 328 inside the login card:
  ```jsx
  {verifyError && (
    <p className="mt-3 text-sm text-center text-red-600">
      {t('edu_materials.access.verify_unavailable')}
    </p>
  )}
  ```
  Use `text-red-600` directly (matches the error color from `messageColor` at line 152 — `messageType === 'error' ? 'text-red-600' : 'text-indigo-600'`).

**Part 3 — i18n keys.** Add a `verify_unavailable` key to the `edu_materials.access` block in BOTH locale files, mirroring the existing `error` key. Insert it adjacent to the existing `"error"` key:
- `frontend/public/locales/es/translation.json` — the `access` block ends at line 1149 (`"go_to_materials"`); the `"error"` key is at line 1145. Add:
  `"verify_unavailable": "No pudimos verificar su acceso en este momento. Verifique su conexión e intente de nuevo.",`
- `frontend/public/locales/en/translation.json` — same `access` block (block starts at line 1165). Add the English equivalent:
  `"verify_unavailable": "We couldn't verify your access right now. Check your connection and try again.",`
  Read the en file's `access` block first to place the key correctly and match its exact formatting/trailing-comma style.

**No issue-body-vs-source drift.** The issue's quoted code, line numbers (33-66), and localStorage shapes all match current source exactly. The only thing the issue under-specifies is that surfacing the message requires touching the gate component + locales, not just the context — Parts 2 and 3 above cover that.

**Note on the `expiresAt` defense-in-depth point in the issue:** `getStored()` (lines 8-21) already enforces `expiresAt > now` client-side (sets `expired: true`). That logic is already correct — do not change it. The catch branch is the only defective site.

## Scope

### IN scope
- `frontend/src/contexts/EducatorAuthContext.jsx` — Part 1.
- `frontend/src/components/public/EducatorAccessGate.jsx` — Part 2.
- `frontend/public/locales/es/translation.json` — Part 3 (one key).
- `frontend/public/locales/en/translation.json` — Part 3 (one key).

### OUT of scope (do NOT touch)
- The server side. The real access gate (issue #50) is separate; do NOT add backend endpoints, server checks, or touch `backend/`.
- Offline support / service-worker / IndexedDB. The issue explicitly says offline support is NOT a current requirement — do NOT build it.
- The plaintext-email-in-localStorage concern mentioned in "Additional context" — that is informational, tied to issue #52; do NOT change the storage shape or attempt encryption.
- `getStored()` expiry logic (lines 8-21), `grantAccess` (68-76), `logout` (78-83) — already correct.
- `frontend/dist/locales/*` — build artifacts; never edit. Only edit `frontend/public/locales/*`.
- Adding any test framework or test files — none exists; do not introduce one.

## Default rules for likely ambiguities

- **New context field name**: `verifyError` (boolean). Initialize `useState(false)`.
- **Where to surface the message**: in `EducatorAccessGate.jsx`'s default LOGIN view only, as shown in Part 2. Do NOT add a brand-new full-screen view/state — the user lands on the login view by default and can retry from there, which satisfies "the user retries when connectivity returns."
- **Color/styling**: reuse `text-red-600` (the established error color). Do not invent new styles.
- **i18n key name**: exactly `verify_unavailable` under `edu_materials.access`. Use the Spanish/English strings given above verbatim.
- **Reset semantics**: clear `verifyError` (`setVerifyError(false)`) at the start of the `.then` branch so a later successful re-check clears the banner. Do NOT clear it in `grantAccess`/`logout` (those are separate flows; leaving them untouched is fine — `hasAccess: true` short-circuits the gate before the banner renders).
- **Trailing commas / formatting in JSON**: match the surrounding lines' style exactly (the file uses 2-space indent and trailing commas between keys). Read the relevant block before editing to get the comma placement right.
- **Initial optimistic `hasAccess` seeding** (lines 25-28: `return stored && !stored.expired ? true : false;`): this is a *related* sub-case (it can flash content before the mount check resolves), but note that `loading` becomes `true` synchronously in the mount effect (line 37) whenever a stored email exists, and the gate renders the loading state (line 35) — not content — while the check is in flight. So the optimistic seed does NOT leak content in the network-error path once the catch sets `hasAccess(false)`. Leave the initial seeding as-is for this fix; if you believe it still leaks, surface it in the PR description per disagreement-shape #3 rather than changing it.

## Failure-mode escape hatch

If the primary path is blocked — e.g., the context value object isn't where described, or a referenced line has moved materially — STOP and open the PR as a **draft** with a comment describing exactly what's blocked. Re-read the current source first; line numbers may have shifted slightly, which is fine — follow the source.

## Self-review checklist (before opening the PR)

Run this list. If any item fails, open the PR as a **draft** with a comment naming the failed item.

- [ ] Only the four IN-scope files modified; no `backend/`, no `frontend/dist/`, no test files.
- [ ] The catch branch no longer calls `setHasAccess(true)`; it sets `hasAccess` false and `verifyError` true.
- [ ] `verifyError` is exposed in the context Provider `value` and consumed in `EducatorAccessGate.jsx`.
- [ ] The `verify_unavailable` key exists in BOTH `es` and `en` locale files and the JSON parses (no trailing-comma/brace errors).
- [ ] `npm run lint` is clean with no new warnings/errors vs the `main` baseline.
- [ ] `npm run build` succeeds.
- [ ] PR description includes the production-touch line (Production touch: no).

## PR shape

- **Branch**: `fix/issue-60-educator-stale-access`
- **Title**: `fix(#60): don't grant educator access from stale localStorage on network error`
- **Body must include**: a one-line summary; a **"Production touch: no — verified by:"** line (client-side React only, no DB/.env/deploy/server-auth); the self-review checklist with each item marked; a test plan (manual: with a stored `educator_access` localStorage row and the network offline / `check-access` failing, the gate now shows the login view with the "couldn't verify" message instead of granting access; with network restored and a valid record, access is granted normally); `Closes #60`; and the `🤖 Generated with [Claude Code](https://claude.com/claude-code)` footer.
- **Draft vs ready-for-review**: ready-for-review if all self-review items pass; draft otherwise.
- **DO NOT MERGE.** The operator merges.

## Deliverable on completion

Report back to the orchestrator with: the PR number, draft-vs-ready status, what shipped, and any flags you surfaced. Append one row to `docs/agent-fixes/agent-friendly-outcomes.md` with Agent attempted: yes, Outcome: not-yet-attempted.

## Begin by

1. Symlink node_modules: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. Read the issue (`gh issue view 60`) and the four IN-scope files; confirm the verified facts (catch branch at lines 59-64, context value object at lines 86-88, gate consumer at line 19, locale `access` blocks) still hold.
3. Make the change across the four files, staying strictly within IN scope.
4. Run `cd frontend && npm run lint && npm run build`; iterate until clean.
5. Self-review checklist.
6. Open the PR (draft if any checklist item failed; ready-for-review otherwise).
7. Append the outcomes-log row.
8. Report back and STOP.
