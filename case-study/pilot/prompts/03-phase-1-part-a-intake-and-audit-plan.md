We're starting Phase 1 proper. Phase 0 is complete (report at
docs/pilot/phase-0-report.md) and Phase 1 prep just merged (PR #2 added
labels, issue templates, the agent-friendly criteria doc at
docs/pilot/agent-friendly-criteria.md, and the Phase 1 README at
docs/pilot/phase-1-readme.md). Read these first so you understand the
scaffolding we're filing against.

## What Phase 1 is, and isn't

Phase 1 is a structured audit of the existing codebase that produces a
backlog of well-scoped GitHub issues. It does NOT fix anything — except
the stop-the-line exceptions defined in the criteria doc (serious security
issues, actual production bugs affecting the public-facing UI).

Phase 1 will take multiple sessions. This session is Part A: convert the
Phase 0 deferred backlog into properly structured GitHub issues. Once
that's done, we'll have a follow-up session for each audit area.

## Part A — File the Phase 0 deferred backlog

The Phase 0 report contains a "Phase 1 backlog (deferred findings)"
section organized by High / Medium / Lower value. For each item:

1. Determine which issue template applies:
   - `code_quality.yml` for refactors, technical debt, code smells, lint
     issues, deprecation warnings
   - `bug_report.yml` for actual bugs (probably none in the backlog, but
     check)
   - `feature_request.yml` for new capabilities (also probably none —
     this is a cleanup phase)
   - `agent_task.yml` only for items that pass the 6-checkbox gate and
     genuinely qualify per the criteria doc

2. Determine severity label:
   - `code-quality:critical` — security-relevant, correctness-relevant,
     or blocking other work
   - `code-quality:moderate` — meaningful improvement to maintainability,
     reliability, or developer experience
   - `code-quality:nice-to-have` — cosmetic, low-impact, or purely
     speculative

3. Determine if it's `agent-friendly`. Run it through the criteria doc
   honestly — don't be permissive. Borderline cases default to NO. The
   ruff sweep example in the criteria doc is your reference point for
   "borderline but qualifies"; if your item isn't at least that clearly
   bounded, it's not agent-friendly yet.

4. Write the issue body using the template's required fields. Be specific
   — reference file paths, line numbers, the symptom or smell, what the
   desired end state looks like, and any context an agent or future-you
   would need to act on it later.

## Working style for this session

- **Batch and confirm.** Don't open issues one at a time and wait for me
  on each. Group them in batches of 3-5 logically related items, show me
  the proposed titles + labels + agent-friendly classification for the
  batch, wait for approval, then open them. This is the show-before-act
  pattern we want to reinforce after the Phase 1 prep drift.

- **Don't expand scope.** If you notice issues during this session that
  weren't in the Phase 0 report, note them at the end in a "newly
  observed" section. Don't file them — they'll be picked up in Part B's
  proper audit.

- **Stop-the-line still applies** but is unlikely to trigger here since
  we're reading the Phase 0 report, not exploring code. If it does
  trigger, surface immediately rather than continuing.

- **Cross-reference issues.** If two backlog items are related (e.g.
  "drop orphan tables" and "generate initial alembic migration"), link
  them in the issue bodies. Future-me (or an agent) needs to know that
  fixing one without the other is incomplete.

- **Skip the history rewrite item.** I've decided not to do that
  retroactive cleanup. Note in your output that it's intentionally
  not filed.

## Part B planning (end of session)

After all Phase 0 backlog items are filed, propose an audit plan for
Part B. Specifically:

- Identify 4-7 audit areas in the codebase (e.g. "content pipeline",
  "FastAPI routers and request handling", "data layer / SQLAlchemy
  models", "auth", "background tasks and long-running operations",
  "frontend state management", "frontend Sentry integration", etc.).
  Pick the divisions that make sense for THIS codebase, not generic
  ones.

- For each area, estimate session size (small / medium / large) based
  on file count, complexity, and known problem density from Phase 0.

- Propose an order. Highest-leverage areas first — places where the
  Phase 0 audit hinted at problems, or areas where bugs would be most
  expensive (data integrity, auth, payments).

- Flag any areas you think we should explicitly skip — code that's
  stable, well-tested, or low enough risk that audit time is better
  spent elsewhere.

This is a proposal for me to react to, not a plan to execute. Don't
start any audit this session.

## PR strategy

Filing GitHub issues doesn't require a PR — issues are created via the
GitHub API directly. No commits, no PR for this session. The audit
plan at the end can be a comment on this conversation or, if it's
substantial, a draft `docs/pilot/phase-1-audit-plan.md` that we land
as a separate small PR before Part B begins.

Begin by re-reading the three pilot docs (phase-0-report.md,
agent-friendly-criteria.md, phase-1-readme.md), then propose the first
batch of issues to file. Wait for my approval before creating anything.
