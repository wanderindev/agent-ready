I'm starting a multi-phase pilot to introduce autonomous and semi-autonomous
agentic workflows to this project (Panama In Context). The project has been
in production for several months but largely untouched — it's roughly 70%
complete with known unfinished features and accumulated technical debt from
moving fast during initial development.

The broader pilot has 7 phases. You and I will work through them sequentially.
This conversation is strictly about Phase 0: re-establishing baseline.

The goal of Phase 0 is to make sure the project is in a known-good state
before any agent does autonomous work on it. We are NOT fixing code quality
issues, adding features, or refactoring in this phase. We are auditing,
verifying, and setting up safety nets.

## Phase 0 checklist

Please help me work through these, in order. After each one, stop and report
findings before moving on — don't chain through them autonomously.

1. **Tool Search verification.** Run `/doctor` and `/context`. Report which
   MCP servers are connected, total token cost of tool definitions, and
   whether Tool Search has activated (it kicks in automatically above 10K
   tokens of tool definitions). If any MCP is loading heavily but rarely
   used in this project, flag it.

2. **CLAUDE.md audit.** Read the current CLAUDE.md (and any nested ones).
   Compare what it claims about the project against what's actually true
   in the codebase right now. Specifically check:
   - Stated tech stack vs actual (we migrated from Flask to FastAPI;
     confirm CLAUDE.md reflects that)
   - Stated directory structure vs actual
   - Any references to deprecated dependencies (we used to use Rube; we
     still use Composio for email but plan to replace it)
   - Any stated conventions that the code no longer follows
   Produce a diff proposal — don't apply changes yet. I want to review
   before we update.

3. **Build and test verification.** Confirm:
   - Dependencies install cleanly
   - The application builds/starts locally
   - The test suite runs and passes (if any tests are flaky or skipped,
     flag them — don't fix)
   - Report test coverage if it's measurable
   If anything is broken, stop and report. Don't fix.

4. **Sentry connection check.** Verify Sentry is still wired up correctly
   in the application (DSN configured, error reporting code paths intact).
   Don't trigger test errors — just confirm the integration is in place
   based on the code.

5. **GitHub repo hygiene check.** Look at:
   - Branch protection status on main (if accessible via gh CLI)
   - Whether there are open PRs or stale branches I should clean up
   - .gitignore covers what it should
   - Any secrets accidentally committed (do a quick scan)

6. **Backlog readiness.** Verify the GitHub issue templates and labels
   I'll need for later phases exist or need to be created. Specifically,
   I'll want labels: `code-quality:critical`, `code-quality:moderate`,
   `code-quality:nice-to-have`, `agent-friendly`, `bug`, `enhancement`.
   List what's missing — don't create them yet.

## Working style for this phase

- Read-only first. Don't modify files unless I explicitly approve.
- Report findings clearly with file paths and line numbers where relevant.
- If you discover problems that aren't part of Phase 0, note them in a
  "deferred findings" list — we'll convert those into GitHub issues during
  Phase 1, not now.
- Ask before running anything that costs significant tokens or makes
  external calls (Sentry API, GitHub API beyond basic reads, etc.).

Start with item 1 and wait for me to confirm before moving to item 2.
