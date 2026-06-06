---
name: repo-bootstrap
description: "Make a git repository safe and structured for agent work — idempotently configure branch protection on the default branch, a CI workflow, the methodology's issue labels, and issue templates. Invoked as the first setup step before any audit. Use when the operator says any of \"bootstrap this repo\", \"set up branch protection and CI\", \"create the issue labels\", \"agent-ready setup\", \"prepare this project for the audit methodology\", or is starting the audit-to-autonomy pipeline on a fresh repository. Runs gh/git against the CURRENT repo; STATUS: scaffold — not yet implemented."
---

# repo-bootstrap

> **STATUS: scaffold.** This skill is specified but not yet implemented. The
> design below is the build target for the agent-ready roadmap. Do not run it as
> production yet.

## What this skill will do

Bring a target repository to the "Phase 0" floor the methodology requires before
any autonomous agent does unattended work: a protected default branch, a CI
gate, a labeled issue surface, and templates that route work to the right track.
Everything is **idempotent** — safe to re-run; existing-and-correct state is left
alone, missing state is created, drifted state is reported.

## Planned workflow

1. **Detect context.** Confirm we're in a git repo with a GitHub remote
   (`gh repo view`). Detect the default branch. Detect the stack (Python/Node/
   other) to pick a CI stub. Ask the operator to confirm anything ambiguous.
2. **Labels.** Create the methodology's label set from
   `${CLAUDE_PLUGIN_ROOT}/assets/github/labels.json` via `gh label create`
   (skip/update existing). The set: `code-quality:critical|moderate|nice-to-have`,
   `agent-friendly`, `epic`.
3. **Issue templates.** Copy `${CLAUDE_PLUGIN_ROOT}/assets/github/ISSUE_TEMPLATE/`
   into the target's `.github/ISSUE_TEMPLATE/` (don't clobber customized ones
   without confirmation).
4. **CI.** Write a stack-appropriate workflow from `${CLAUDE_PLUGIN_ROOT}/assets/ci/`
   into `.github/workflows/`. Includes secret scanning + lint + test as the
   required check.
5. **Branch protection.** Apply protection to the default branch: require the CI
   check, block direct pushes, require PRs. (Via `gh api` branch-protection.)
6. **Report.** Summarize what was created vs. already-correct vs. needs operator
   attention. Commit the file changes on a branch and open a setup PR (never push
   to the now-protected default branch directly).

## Guardrails to encode (from the methodology)

- **The CI job `name:` is the branch-protection required-check key** — choose it
  once and never rename it (renaming strands the required check forever).
- Branch protection must be applied *after* the first CI run exists, or the
  required-check name won't be selectable.
- Never force-push; never bypass protection. The skill configures the fence; it
  does not climb over it.

## Reference

The PIC pilot did all of this by hand across Phase 0 + Phase 1 prep. The
[case study](../../../../case-study/) records what was set up and why.
