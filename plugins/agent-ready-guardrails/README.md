# agent-ready-guardrails

A codebase-agnostic safety baseline for Claude Code — the deny/ask/allow floor
the [Agent Ready](../../README.md) methodology assumes is in place before you
hand work to agents. It exists in three layers:

| Layer | File | Active when |
|---|---|---|
| **Canonical policy** — deny/ask/allow rules | `policy/permissions.json` | after running the installer |
| **Installer** — merges the policy into a settings file | `scripts/install-policy.sh` | run once (manually or by an onboarding step) |
| **PreToolUse guard** — hard-blocks the catastrophic subset | `hooks/guard.sh` + `hooks/hooks.json` | immediately, as soon as the plugin is enabled |

Claude Code plugins cannot ship permission rules directly (a plugin's
`settings.json` supports only `agent`/`subagentStatusLine`), which is why the
policy travels as a JSON asset plus an installer. The hook layer exists so a
machine that enabled the plugin but never ran the installer is still protected
against the worst actions — a PreToolUse hook exiting 2 blocks the call *before*
permission rules are evaluated.

> Why this ships with Agent Ready: the methodology's skills expect deny rules
> (no force-push, no push to `main`, no `pr merge`) to already live in the
> target repo. This plugin is where that baseline comes from — install it once
> per machine so those guarantees hold in every repo you point an agent at.

## Install

```
/plugin marketplace add wanderindev/agent-ready
/plugin install agent-ready-guardrails@agent-ready
```

then apply the policy (once per machine):

```bash
# from your marketplace checkout / the cached plugin directory
plugins/agent-ready-guardrails/scripts/install-policy.sh
```

For centrally-administered machines, the strict variant writes managed settings
(cannot be overridden by user or project settings):

```bash
sudo scripts/install-policy.sh /etc/claude-code/managed-settings.json
```

The installer is idempotent: your own existing rules are preserved, policy rules
are added, duplicates removed, and a timestamped backup is written next to the
settings file. Re-run it after a plugin update to pick up policy changes.

> Hooks load at session start. After installing, restart your session (or
> `/reload-plugins`) so the PreToolUse guard is active.

## Policy design

**A user-level deny can never be overridden by a project-level allow.** So:

- **`deny` is catastrophic-only:** force-push, history rewrites (`reset --hard`,
  `filter-branch`, `rebase -i`, `clean -f`), recursive force-delete (`rm -rf`),
  PR merges (humans merge — `gh pr merge`), secret-token literals appearing in a
  command (`AKIA…` AWS access keys, `ghp_…`/`github_pat_…` GitHub tokens), any
  touch of a secret store (`~/.aws/`, `~/.ssh/`, `**/secrets/**`), and writes to
  `.env*`/`credentials*` files.
- **`ask` is the prod door / workflow gate:** pushes to `main`/`master`,
  `docker push`, and schema migrations (`alembic upgrade`/`downgrade`/`stamp` as
  the shipped example) — routine locally, human-confirmed.
- **`allow` keeps prompts quiet** for the safe daily set: `docker build`,
  editing `CLAUDE.md` and `.claude/`.

Known tradeoff: the blanket `.env.*` write-deny also catches `.env.example` —
intentional; a human touches env files, of any flavor.

## Extending the baseline

This is a *starter*, tuned to be safe for any repo. Make it yours in two places:

1. **Your team/machine baseline** — edit `policy/permissions.json` (or a copy
   the installer merges) to add:
   - your stack's migration/deploy commands to `ask`
     (`prisma migrate deploy`, `rails db:migrate`, `terraform apply`, …);
   - your providers' token prefixes to `deny`
     (`sntrys_` Sentry, `xoxb-` Slack, `ATATT` Atlassian, …);
   - any extra credential stores your machine keeps to `deny`
     (`~/.config/<org>/`, …).
2. **A single repo's own fences** — put things specific to one codebase (its
   production DB host, its deploy target) in that repo's `.claude/settings.json`,
   layered on top of this global baseline.

The PreToolUse guard in `hooks/guard.sh` enforces only the catastrophic subset
and is deliberately conservative; the installed policy is the fuller net. This
is a strong safety net, not an airtight sandbox — substring/regex matching can
be worked around, so phrase what you rely on accordingly.
