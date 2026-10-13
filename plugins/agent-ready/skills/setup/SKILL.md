---
name: setup
description: One-run, idempotent onboarding for the Agent Ready methodology — checks prerequisites, installs the guardrails deny/ask/allow policy on this machine, ensures the target repo is bootstrapped (labels/CI/branch-protection) and carries the methodology docs, then health-checks the result. Safe to re-run anytime; re-running a half-configured machine or repo is the supported way to repair it. Use when the operator says "set up my machine", "onboard me", "get this repo ready for agents", "run the setup", "run the health check", or when the guardrails/methodology aren't in place. Delegates the repo infra to repo-bootstrap and the docs to methodology-install rather than duplicating them.
---

# setup — one-run onboarding for the methodology

Takes a machine and a target repo from "Claude Code installed, the Agent Ready
plugins just added" to ready-to-run: prerequisites checked, the safety floor
installed, the repo bootstrapped and documented, everything verified. **Every
step is idempotent** — re-running on a half-configured or fully-configured
setup is the supported way to repair it.

Two layers, and they are separate on purpose:

- **Machine-level (once per machine):** the guardrails policy. It is not
  repo-specific, and it is the piece most easily left behind — a repo can look
  fully bootstrapped while the machine pointing agents at it has no safety
  floor at all. Install it once; it protects every repo.
- **Repo-level (once per target repo):** labels, CI, branch protection
  (`repo-bootstrap`) and the methodology docs (`methodology-install`).

You are driving a conversation with the operator. Do the automatable parts
yourself; for the human-only parts (a `gh auth login`, admin-only branch
protection), give the exact step and wait for confirmation before verifying.

## Hard rules

- **The two scripts here are read-only** (`preflight.sh`, `health-check.sh`) —
  they check and report, never change state. The only state changes in this
  flow are the idempotent plugin installs, the policy installer, and the
  delegated `repo-bootstrap` / `methodology-install`.
- **Do not duplicate `repo-bootstrap` or `methodology-install`.** This skill
  *sequences* them; it does not reimplement their work. If the repo already has
  labels/CI/docs, those steps are no-ops you skip.
- **Dogfood order:** set up your own machine (guardrails policy installed)
  before onboarding a repo or another person.
- If a step fails twice, stop and show the operator the error rather than
  looping.

## Paths

The guardrails installer lives in the sibling plugin, reachable from the
marketplace checkout root (not this plugin's `CLAUDE_PLUGIN_ROOT`):

```bash
MP_ROOT=$(jq -r '.["agent-ready"].installLocation' ~/.claude/plugins/known_marketplaces.json)
```

## Flow

### 0. Preflight

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/scripts/preflight.sh"
```

Checks `git`, `jq`, `gh` + auth, and whether the marketplace is added. Fix any
**FAIL** (install the tool; `gh auth login`) before proceeding; INFO/WARN lines
are advisory.

### 1. Marketplace + plugins (idempotent)

```bash
claude plugin marketplace add wanderindev/agent-ready   # no-op if already added
claude plugin marketplace update agent-ready
claude plugin install agent-ready-guardrails@agent-ready # the safety floor
claude plugin install agent-ready@agent-ready            # the methodology skills
```

Tell the operator: the guardrails PreToolUse hook and the policy load at
**session start** — they take effect after the restart in step 4.

### 2. Guardrails policy (machine-level safety floor)

```bash
bash "$MP_ROOT/plugins/agent-ready-guardrails/scripts/install-policy.sh"
```

Merges the deny/ask/allow policy into `~/.claude/settings.json` (idempotent —
keeps the operator's own rules, dedups, writes a timestamped backup, prints a
rule count). For a centrally-administered machine, use the strict variant
instead: `sudo install-policy.sh /etc/claude-code/managed-settings.json`.

### 3. Target repo (only when onboarding a specific repo)

Run this from inside the target repo. Let the health check (step 4) tell you
what's missing, then delegate — do not hand-roll:

- **Missing methodology docs** (`docs/methodology/` absent) → run
  `/agent-ready:methodology-install`.
- **Missing labels / CI / branch protection** → run `/agent-ready:repo-bootstrap`
  (idempotent; needs `gh` admin on the repo for branch protection).

If the repo is already bootstrapped and documented, this step is nothing to do.

### 4. Health check + restart

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/scripts/health-check.sh"
```

Verifies the machine (guardrails policy installed) and, when run inside a repo,
the repo (methodology docs, labels, CI, branch protection, event-log exclude),
and prints PASS/WARN/FAIL. Fix any **FAIL** (a missing safety floor) and re-run
until clean. **WARNs are "not set up yet" or "can't verify from here"** — a
machine with no target repo yet will show repo WARNs and that's fine; explain
them rather than chasing them.

Finish by telling the operator to **restart Claude Code** (or `/reload-plugins`)
so the guardrails hook and any newly installed skills load.

## Bootstrap (how a clean machine gets this skill)

Two commands, then the guided run:

```bash
claude plugin marketplace add wanderindev/agent-ready
claude plugin install agent-ready@agent-ready
# then start Claude Code and run:  /agent-ready:setup
```

`setup` installs `agent-ready-guardrails` for you in step 1, so you only need
the methodology plugin to reach this skill.

## Notes

- **No credentials, no connectors.** Unlike a team onboarding, there is nothing
  per-identity to configure here — Agent Ready runs on `git` + `gh` + the two
  plugins. The only machine state is the guardrails policy in your settings.
- **Re-run to repair.** Every step tolerates being run again. If something looks
  half-broken, the first move is to re-run `setup` and read the health check.
