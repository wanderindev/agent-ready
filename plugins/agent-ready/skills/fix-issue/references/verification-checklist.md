# Codebase-fact verification checklist

This is the gate. The `fix-issue` brief-writing agent must satisfy every applicable item below **against the current source** — not against the issue body, not against memory — before it returns a brief, and the orchestrator's well-formedness gate confirms it. This is the operationalization of the case study's most consequential finding: brief-tightness is the load-bearing variable, and the brief-writer's job is to pre-resolve every ambiguity the agent would otherwise resolve unsupervised.

**Example (from the pilot):** the F-1 run produced three ambiguity events despite a carefully-written brief, because the brief asserted a codebase fact (a `ToastProvider` that didn't exist) from the brief-writer's mental model rather than from source. Every item here exists to prevent that. (Full instance in the case study.)

## Required for every issue

1. **Read the target file(s).** Open every file the issue body references. Confirm the paths exist. Confirm the line numbers are current (issues age relative to the codebase; fix-work moves things). If a path or line number is stale, the brief states the corrected location.

2. **Verify the issue body's factual claims.** For each concrete claim in the issue ("X happens at line Y", "the value is Z", "there are N sites"), check it against source. **Record any drift.** The brief corrects the source-of-truth; per the case study's brief-correcting-issue-body pattern, when the issue body and the source disagree, the source wins and the brief says so explicitly. **Example (from the pilot):** issue #114 said "8 hero images"; the source had 12. The brief corrected it; the agent confirmed 12. (Full instance in the case study.)

3. **Determine IN / OUT scope.** What files/regions does the fix touch? What must the agent NOT touch? State both. The OUT list is as important as the IN list — it's what keeps the agent from scope-creeping.

4. **Production-touch assessment.** Confirm the fix touches no production path (no prod DB, no `.env`, no deploy, no auth/payment/PII code). Agent-friendly issues should be no-prod-touch by the six-criterion rubric. If the fix would touch production, STOP and surface — the label may be wrong.

5. **Anticipate and pre-resolve ambiguities.** Read the issue and the source as the agent will. Where could the agent get stuck or have to choose? Pre-resolve each in the brief's "default rules" section: variable names, exact strings, which of two patterns to follow, what to do with adjacent-but-out-of-scope code. Every ambiguity you resolve now is one the agent won't resolve unsupervised.

## Conditional — apply when the issue shape matches

6. **If the fix mirrors an existing pattern (sweep, defensive-coding, restructure):** identify the canonical pattern in the codebase. Read it. Cite its `file:line` in the brief. The agent mirrors it. The pilot's autonomous runs were clean partly because canonical patterns lived in the same codebase as the fix targets — name the pattern so the agent can find it.

7. **If the fix is a sweep (multiple sites):** count the real sites yourself with `grep`/inspection. Do not trust the issue body's count. Pre-resolve which sites are in-scope vs which are already-conformant exemplars. **Example (from the pilot):** issue #117 said "22 catch blocks"; one was the canonical pattern already; the fix-count was 21. (Full instance in the case study.)

8. **If the fix is dead-code removal:** exhaustive `grep -rn` for every identifier referenced by the deletion targets — not just the obvious files. The brief lists the full reference set. **Example (from the pilot):** in issue #116 the brief omitted an `AppShell.jsx` reference the issue body had listed; the agent caught it. Enumerate exhaustively. (Full instance in the case study.)

9. **If the fix is in a frontend worktree that needs lint/build:** the brief must include the `node_modules` symlink resolution — fresh worktrees have no `node_modules` (gitignored). The resolution: `ln -s <main-checkout-abs-path>/frontend/node_modules frontend/node_modules`. Substitute the real absolute path of the main checkout.

10. **If the fix targets a property of a thing (not just the thing):** verify the sub-attribute, not just existence. **Example (from the pilot):** in issue #122 the brief verified "inline `<Dialog>` blocks exist" but not "they're Headless UI Dialogs specifically" — one target was a plain `<div>` overlay. Verify the property the fix depends on. (Full instance in the case study.)

## Output of this step

Before assembling the brief, you should be able to state, from source you read this session:
- The exact file(s) and line(s) the fix touches.
- The exact count of sites (if a sweep).
- The canonical pattern's `file:line` (if mirroring).
- Any issue-body-vs-source drift, with the correction.
- The IN/OUT scope.
- The pre-resolved ambiguities.
- The production-touch verdict (expected: none).

If you cannot state these, the verification is incomplete and the brief is not ready to assemble.
