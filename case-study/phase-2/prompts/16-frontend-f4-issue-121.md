# Phase 2 — Session 16: Frontend autonomous-agent experiment, F-4.D — issue #121 (admin order action confirmations)

## Identification

You are the **autonomous agent** running **F-4.D**, one of five concurrent Wave 1 agents in F-4.

## Operational notes

1. **Symlink `node_modules`**: `ln -s /home/javier/vc/panama-in-context/frontend/node_modules frontend/node_modules`.
2. **Codebase facts verified at brief-writing time.**
3. **Count interpretation, pre-resolved.** The issue body says "consequential admin order actions lack confirmation prompts." **Verified**: `AdminOrders.jsx` has 4 action sites via `handleAction(action, label)`:
   - `'create-invoice'` (line ~298)
   - `'send-invoice'` (line ~308) — emails the customer
   - `'cancel-invoice'` (line ~315 and ~325)
   - `'mark-paid'` (line ~334)
   The "consequential" subset: send-invoice (emails customer), cancel-invoice (revokes an in-flight invoice), mark-paid (irreversible accounting state change). create-invoice is less destructive (admin can cancel after) but borderline.

## Parallel-mode notes

You touch `frontend/src/pages/admin/AdminOrders.jsx`. Other Wave 1 agents touch BookingManage.jsx, public components, i18n.js+index.html, 4 admin pages (Suggestions/Outlines/Research/Articles — NOT AdminOrders). **No file overlap.**

## Agent-vs-brief disagreement taxonomy

Three shapes. Most likely shape for this brief: (3) — if you decide create-invoice ALSO needs a confirmation, follow the brief's primary list AND flag the create-invoice question for the operator in the PR description.

## What this experiment is testing

F-4.D tests an **admin-CMS confirmation-prompt sweep**: 3-4 sites, each needing a `window.confirm()` or similar gate before the existing action fires. Mechanical pattern; the variability is in the confirm wording.

If stuck, draft PR + comment + stop.

## Read these first, in order

1. **Issue #121** — `gh issue view 121`.
2. **`frontend/src/pages/admin/AdminOrders.jsx`** (full file) — the target. The `handleAction` function starts around line 59; action sites are the various `onClick={() => handleAction('action', 'Label')}` buttons.
3. **`docs/pilot/phase-1-area-6-report.md`** — the audit that surfaced #121.
4. Prior session reports (06-12) — skim.
5. **`docs/phase-2/agent-friendly-outcomes.md`**, **`.claude/settings.json`**, **`CLAUDE.md`**.

## Scope — structural guards

### IN scope

- **Add a `window.confirm(...)` gate** at the top of `handleAction(action, label)` (line ~59), BEFORE any state mutation or network call. Confirm wording should be specific to the action:
  - `mark-paid`: `"Mark this order as paid? This action affects accounting state and is hard to reverse."`
  - `cancel-invoice`: `"Cancel this invoice? The customer's existing PayPal invoice will be cancelled."`
  - `send-invoice`: `"Send this invoice to ${order.customer_email}? This emails the customer."`
  - `create-invoice`: NOT required — out of scope unless your read of the file suggests otherwise (in which case follow shape-3 and flag).
- **The confirm pattern**: at the top of `handleAction`, branch on the `action` value and call `window.confirm()` with the appropriate prompt. If the user cancels, return early before doing anything. Existing pattern for early-return: check the existing `handleAction` for similar guards (e.g., loading-state checks).
- **Use the action's English-language `label` parameter** (already passed to `handleAction`) where appropriate, or hardcode English strings for the confirm prompts (admin CMS is English-only).
- **One PR** with the gate added.
- **Run `npm run lint` and `npm run build`** — both clean.

### OUT of scope

- **Other admin pages** (AdminBookings, AdminSettings, etc.).
- **Replacing `window.confirm` with a custom Dialog** — out of scope. `window.confirm` is simpler and the existing codebase mixes both patterns; the issue doesn't specify a custom Dialog.
- **Logging the cancellation event** to Sentry or anywhere — out of scope.
- **Backend changes. No new dependencies.**

## Default rules for likely ambiguities

- **Confirm-prompt wording** — use the strings above. If you want to tweak for grammar, you may; preserve the intent (action name + consequence statement).
- **What about other actions in the file** that aren't in the issue's scope (e.g., `view-detail`, `export-csv` if they exist)? — out of scope; don't add confirms.
- **Should `create-invoice` get a confirm?** — the brief says no; if your read of the code suggests YES (e.g., create-invoice fires a PayPal API call that's hard to reverse), follow the brief AND flag the question for the operator.
- **What if `handleAction` is called from a context other than `onClick`?** — the confirm logic applies regardless; if any caller passes user-input rather than admin button-click, surface in PR.

## Self-review checklist

- [ ] `AdminOrders.jsx` is the only code file modified.
- [ ] `handleAction` has an action-specific `window.confirm()` gate for `mark-paid`, `cancel-invoice`, `send-invoice` (3 actions).
- [ ] Each gate returns early when the user cancels.
- [ ] Action sites (the `onClick` handlers) are unchanged — they still call `handleAction(action, label)` the same way.
- [ ] No other actions got confirms (unless you flagged a sub-case per shape-3).
- [ ] `npm run lint` clean.
- [ ] `npm run build` succeeds.
- [ ] PR description: production touch line; the list of actions gated; test plan (mention manual verification: click each action in dev, verify the confirm fires and clicking Cancel actually stops the action); `Closes #121`; Claude Code footer.
- [ ] Outcomes-log row appended.
- [ ] Session report at `docs/phase-2/16-frontend-f4-D-issue-121-report.md`.

## PR shape

- **Branch**: `fix/issue-121-admin-order-action-confirmations`
- **Title**: `fix(#121): add confirmation prompts to consequential admin order actions`

## Outcomes-log row

| Column | Value |
|---|---|
| Issue # | `121` |
| Filed agent-friendly? | `yes` |
| Filed severity | `moderate` |
| Track | `frontend-admin` |
| Agent attempted? | `yes` (F-4.D — eleventh autonomous run) |
| PR # | the PR you opened |
| Outcome | `not-yet-attempted` |
| Reviewer interventions | `0 — clean (pending review)` |
| Notes | One-line summary; which actions you gated and any sub-case flags. |

## Session report

`docs/phase-2/16-frontend-f4-D-issue-121-report.md`.

## Begin by

1. Symlink `node_modules`.
2. Read inputs.
3. Confirm the 4 action sites in `AdminOrders.jsx`.
4. Add the gate to `handleAction` for the 3 specified actions.
5. Lint + build.
6. Self-review.
7. Open PR.
8. Outcomes-log row + session report.
9. **Stop.**
