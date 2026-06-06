We're starting Phase 1 prep. This is a focused setup task that produces a
single PR before we begin Phase 1 proper (the codebase audit and issue
filing).

Phase 0 is complete. Its report is in docs/pilot/phase-0-report.md (or
wherever you've stored it — locate it if needed). Read it first so you
understand the context, the Phase 1 backlog already identified, and the
overall pilot structure.

## Goal of this session

Land the infrastructure that Phase 1 proper will use to track its findings.
Specifically, one PR that adds:

1. The 4 missing GitHub labels
2. The 4 GitHub issue templates
3. A written `agent-friendly` criteria document
4. A short Phase 1 README explaining how the labels and templates relate

Nothing else. No code-quality fixes, no audits, no opening of issues. We're
building the filing cabinet, not filling it.

## Item 1 — Create the missing labels

These four labels are missing per the Phase 0 audit:
- `code-quality:critical`
- `code-quality:moderate`
- `code-quality:nice-to-have`
- `agent-friendly`

Create them via `gh label create`. Pick sensible colors — the three
`code-quality:*` labels should share a color family that signals severity
(e.g. red/orange/yellow), `agent-friendly` should be visually distinct
(e.g. green or blue) since it's an orthogonal axis.

Include short descriptions on each label. The `agent-friendly` description
should reference the criteria document we'll create in item 3.

These are created via the API, not via files, so they don't go through the
PR. Do this first and confirm with me before moving on.

## Item 2 — Create the 4 issue templates

In `.github/ISSUE_TEMPLATE/`:

- `bug_report.yml` — for bugs found in production or local testing. Should
  capture: what happened, what was expected, reproduction steps, affected
  area, Sentry link if applicable, severity.
- `feature_request.yml` — for new features or significant enhancements.
  Should capture: problem being solved, proposed solution, scope estimate
  (small/medium/large), any PRD/ADR reference.
- `code_quality.yml` — for refactors, technical debt, code smells. Should
  capture: location (file/module), current state, desired state, why it
  matters, whether it's `agent-friendly` per the criteria.
- `agent_task.yml` — for work specifically scoped for autonomous agent
  execution. Should capture: clear acceptance criteria, files in scope,
  files explicitly out of scope, test requirements, link to the
  `agent-friendly` criteria doc, any safety notes.

Use GitHub's issue form (YAML) format, not the legacy Markdown format —
the forms give better structure and are easier for both humans and agents
to fill out consistently.

Also add `.github/ISSUE_TEMPLATE/config.yml` to disable blank issues and
point to the agent-friendly criteria doc as a contact link.

Show me the templates before committing — I want to review the field choices.

## Item 3 — Write the `agent-friendly` criteria document

Create `docs/pilot/agent-friendly-criteria.md`. This document is the
authoritative answer to "should this issue be marked agent-friendly?"

Base it on the criteria already discussed in the pilot:
- Single-file or tightly-scoped multi-file change
- No business logic decisions required
- No schema migrations
- No changes to auth, payment, or PII handling
- Tests exist for the affected area, or can be added trivially
- Clear acceptance criteria

Expand each one with a sentence or two of context. Include 2-3 worked
examples: an issue that clearly qualifies, an issue that clearly doesn't,
and a borderline case with the reasoning for which side it lands on.

Also include a short section on what "stop the line" means in this project:
during any agent or audit session, if a serious security issue or an actual
production bug affecting the public-facing UI is discovered, it gets fixed
inline rather than deferred. Everything else gets deferred to an issue.

Keep the doc under 200 lines. It should be readable in 5 minutes.

## Item 4 — Write a Phase 1 README

Create `docs/pilot/phase-1-readme.md`. Brief — under 100 lines.

It should explain:
- What Phase 1 is about (audit existing code, file issues, no fixes except
  stop-the-line)
- How the labels work and when to apply each
- How the issue templates map to the work
- How `agent-friendly` is determined (link to the criteria doc)
- What Phase 1 explicitly does NOT do (no fixes, no refactors, no new
  features — that's Phase 4+ work)
- A pointer to the Phase 0 report and the broader pilot structure

This becomes the doc I send to my own future self when I come back to this
project after a break.

## PR

Once items 2-4 are done, open a PR with all of them in a single commit
(or a small number of logically grouped commits). Title:
`Phase 1 prep: labels, issue templates, and agent-friendly criteria`.

PR description should reference the Phase 0 report and explain that this
unblocks Phase 1 proper.

Branch protection is on, so the PR will need to pass CI and be approved
before merging. Since I'm the only reviewer, I'll review and merge it
myself. Don't merge from your end.

## Working style

- Confirm with me after item 1 (labels created) before starting item 2.
- Show me the issue template YAMLs before committing them.
- Don't open any issues during this session. Even if you notice problems,
  add them to a "Phase 1 candidates" note at the bottom of your session
  output — but don't file them yet.
- If something doesn't fit cleanly in scope, ask rather than expand.
