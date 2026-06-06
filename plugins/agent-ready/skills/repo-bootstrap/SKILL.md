---
name: repo-bootstrap
description: "Make a git repository safe and structured for agent work — idempotently configure the methodology's issue labels, issue templates, a CI workflow, and branch protection on the default branch. The first setup step of the audit-to-autonomy pipeline, run before any audit. Use when the operator says any of \"bootstrap this repo\", \"set up branch protection and CI\", \"create the issue labels\", \"agent-ready setup\", \"prepare this project for the audit methodology\", or is starting the pipeline on a fresh repository. Runs gh/git against the CURRENT repo and opens nothing destructive without confirmation."
---

# repo-bootstrap

Brings a target repository to the **Phase 0 floor** the methodology requires
before any autonomous agent does unattended work: a labeled issue surface,
issue templates, a CI gate, and a protected default branch. This is what the
pilot set up by hand; the skill makes it one idempotent, re-runnable step.

## What this does — and what it doesn't

It configures **infrastructure**, not code. It does not fix tests, rotate
secrets, or audit anything — those are the operator's Phase 0 work and the
later audit's job. It only stands up the guardrails the rest of the pipeline
relies on.

Everything is **idempotent**: re-running detects existing-and-correct state and
leaves it alone, creates what's missing, and reports what drifted. Nothing
irreversible happens without an explicit confirmation.

## Prerequisites (check first, STOP if unmet)

- `gh` authenticated with **admin** on the repo (branch protection needs admin):
  `gh auth status` and `gh repo view --json viewerPermission -q .viewerPermission`
  (expect `ADMIN`).
- `jq` available (the helper scripts need it).
- The working directory is a git repo with a GitHub remote (`gh repo view`).

If any prerequisite is missing, surface it and stop — do not partially apply.

## Workflow

### Step 1 — Detect and confirm context
- Default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
- Stack: look for `pyproject.toml`/`requirements.txt` (Python), `package.json`
  (Node), else generic. This selects the CI stub.
- Subdirectory layout: note if code lives in `backend/`, `frontend/`, etc. (the
  CI stub's `working-directory` will need it).
- Existing state: `gh label list`, presence of `.github/workflows/`,
  `.github/ISSUE_TEMPLATE/`, and current protection
  (`gh api repos/{owner}/{repo}/branches/{branch}/protection` — a 404 means
  none yet).
- **Present a plan** of what will be created/updated and the chosen CI stub +
  required-check names. Get the operator's nod before changing anything.

### Step 2 — Labels (idempotent, no branch impact)
Run the bundled script against the bundled label set:
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/repo-bootstrap/scripts/sync-labels.sh" \
     "${CLAUDE_PLUGIN_ROOT}/assets/github/labels.json"
```
Creates/updates `code-quality:critical|moderate|nice-to-have`, `agent-friendly`,
`epic`. Report created vs updated.

### Step 3 — Issue templates
Copy `${CLAUDE_PLUGIN_ROOT}/assets/github/ISSUE_TEMPLATE/` into the repo's
`.github/ISSUE_TEMPLATE/`. If a template already exists and differs, show the
diff and ask before overwriting — don't clobber a customized template silently.

### Step 4 — CI workflow
Copy the chosen stub from `${CLAUDE_PLUGIN_ROOT}/assets/ci/` into
`.github/workflows/ci.yml`. Then **adapt it to this repo with the operator**:
language version, `working-directory`, dependency install, test/lint commands.
Note the required-check **context names** (the job `name:` values — e.g.
`Secret scan`, `Test`); they are needed in Step 6.

> **Load-bearing:** a job's `name:` is its branch-protection required-check key.
> Pick the names now and never rename them — renaming strands the required check
> forever. Change steps, not names.

### Step 5 — Land the infra (the one-time bootstrap exception)
The default branch is **not protected yet**, so commit the labels-are-already-done
plus the templates + CI directly to it (or via a quick PR if the operator
prefers). This is the single sanctioned direct-to-default commit — it exists to
make CI run at least once so its check contexts register. After this step, every
change goes through a PR. Push and **wait for the first CI run to complete**
(`gh run watch` or `gh run list`) so the contexts exist.

### Step 6 — Branch protection
Once the first run has registered the contexts, apply protection:
```
bash "${CLAUDE_PLUGIN_ROOT}/skills/repo-bootstrap/scripts/protect-branch.sh" \
     <default-branch> "Secret scan" "Test"
```
(Use only the context names your chosen stub actually exposes — `generic.yml`
has just `Secret scan`.) The default enforces: PRs required, checks must pass
(strict), no force-push, no deletion, 0 required approvals (solo-friendly), and
`enforce_admins` ON so even the owner can't push straight to the branch.

> Offer `--no-enforce-admins` only if the operator explicitly wants an admin
> escape hatch. The methodology's default is the strict gate — it's what kept
> the pilot's `main` unbroken.

### Step 7 — Report
Summarize: labels (created/updated), templates (added/skipped), CI (stub used +
adaptations), protection (checks required, enforce_admins state), and anything
that needs operator attention. Point the operator at the next step:
`methodology-install`, then the first `area-audit`.

## Idempotent re-runs

Re-running is safe and is the intended way to repair drift: labels re-sync,
templates re-diff, an existing CI file is shown rather than overwritten blindly,
and existing protection is reported with an offer to bring it to the standard.

## Guardrails this skill itself respects

- Never force-push; never weaken protection without explicit confirmation.
- The direct-to-default commit in Step 5 is the *only* sanctioned one and only
  because protection doesn't exist yet — surface it as such.
- Treat `enforce_admins: false` as a deviation worth flagging, not a default.

## Files this skill uses

- `${CLAUDE_PLUGIN_ROOT}/assets/github/labels.json` — the label set.
- `${CLAUDE_PLUGIN_ROOT}/assets/github/ISSUE_TEMPLATE/` — the issue templates.
- `${CLAUDE_PLUGIN_ROOT}/assets/ci/{python-pytest-ruff,node,generic}.yml` — CI stubs.
- `scripts/sync-labels.sh`, `scripts/protect-branch.sh` — the idempotent helpers.
