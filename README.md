# Agent Ready

**A methodology for making an existing codebase safe and clear enough to hand work to AI agents — then resolving the backlog with autonomous agents on the tractable subset and human pairing on the rest.**

> Status: **v0.1 — all seven skills built; pending live validation.** The
> manifests, methodology docs, case study, and all skills are in place. The whole
> pipeline has not yet been run end-to-end on a second codebase — that's the next
> milestone, and the methodology stays v1 (calibrated to one codebase) until it
> is. See [Roadmap](#roadmap).

This repository is a [Claude Code](https://claude.com/claude-code) **plugin
marketplace**. Installing the plugin gives you a set of skills that walk a
project through the full pipeline:

1. **Bootstrap** the repository for agent work — branch protection, CI, issue
   labels, issue templates.
2. **Install** the methodology docs into the project's own tree.
3. **Audit** the codebase area by area, filing a labeled, agent-classified
   backlog of issues.
4. **Resolve** those issues — autonomously where the audit proved the work
   tractable, in pair-mode where judgment is load-bearing.

It was extracted from a real audit-to-autonomy run on a deployed bilingual
content-and-booking site, where the methodology took the project from a
stalled, vibe-coded state to **138 issues filed and closed, 165 PRs merged,
zero breakages of `main`**. That run is documented as the [case study](case-study/README.md).

## Why this exists

Most attempts to put AI agents on an existing codebase pick one of two losing
patterns: pair with the agent and watch every keystroke (trust, but no
autonomy), or point it at the repo and hope (autonomy, but no trust). The third
path — the one this methodology encodes — is to **audit first to find the work
that is genuinely tractable for autonomy, then deploy autonomy only there**, and
to write briefs tight enough that an agent's only job is to execute a verified
specification.

The surprising lesson from the pilot was that the biggest win wasn't autonomy at
all — it was **clarity**. A well-specified issue backlog cured the stop-start
"blank page" problem that quietly kills side projects, and made every session
productive from minute one. The full, honest account is in the
[retrospective](case-study/retrospective.md).

## Install

```bash
# Add this repository as a marketplace
/plugin marketplace add wanderindev/agent-ready

# Install the methodology plugin
/plugin install agent-ready@agent-ready

# Recommended: the safety baseline the methodology assumes is in place
/plugin install agent-ready-guardrails@agent-ready
```

Skills then appear namespaced as `/agent-ready:<skill>`.

### Guardrails (install first)

The methodology's skills assume a deny/ask/allow floor already exists in the
repos you point agents at — no force-push, no push to `main`, no `pr merge`, no
touching secrets. [`agent-ready-guardrails`](plugins/agent-ready-guardrails/) is
where that floor comes from: a codebase-agnostic policy plus a PreToolUse guard
that blocks the catastrophic subset the moment the plugin is enabled. Install it
once per machine, then apply the policy:

```bash
plugins/agent-ready-guardrails/scripts/install-policy.sh   # idempotent; backs up first
```

It ships as a separate plugin because safety should not depend on running the
full audit — you want the floor on every repo, audited or not. This mirrors a
lesson from taking the methodology to a second codebase, where the guardrails
were the piece most easily left behind. See the plugin's
[README](plugins/agent-ready-guardrails/README.md) for the policy design and how
to extend it for your stack.

## The skills

| Skill | Phase | What it does |
|---|---|---|
| `repo-bootstrap` | Setup | Idempotently configures git branch protection, a CI workflow, issue labels, and issue templates on the target repo (via `gh`/`git`). |
| `methodology-install` | Setup | Copies the methodology docs into the target's own tree, walks the worked-example placeholders for domain-appropriate replacements, and resets the cross-session register. |
| `area-audit` | Audit | Scaffolds the 10-slot area-audit prompt for one area, gating on the per-area fills; enforces the closing gates when a session reports back. |
| `plan-epic` | Resolve | Clusters the open backlog high→low by severity into a workable epic — proposes 2–3 candidates, creates the chosen one in GitHub. |
| `fix-epic` | Resolve | Executes an epic in **pair-mode** — works the whole cluster on one coherent branch/PR, in dependency order, closing the issues and the epic. |
| `fix-issue` | Resolve | Drives one or more GitHub issues to agent-written PRs via a brief-writing + implementation agent pipeline, with non-skippable verification gates (**autonomous**). |
| `update-pr` | Resolve | Brings an open PR up to date with `main` and resolves conflicts in an isolated worktree. |

The two **Resolve** paths are deliberate complements: `fix-issue` is autonomous
dispatch for the agent-tractable subset; `plan-epic` + `fix-epic` is the
clustered pair-mode path the pilot's retrospective found more productive and
lower-friction for a solo reviewer.

## How it fits together

```
repo-bootstrap ──► methodology-install ──► area-audit (×N) ──┬─► plan-epic ─► fix-epic   (pair-mode clusters)
   (infra)            (docs)                  (backlog)       └─► fix-issue              (autonomous subset)
```

Plugins are read-only once installed; they cannot push GitHub state or write
files into your project on their own. So the two **setup** skills do that work
explicitly, running `gh`/`git`/`cp` against your target repo. The bundled
templates they copy out live under `plugins/agent-ready/assets/` and are
referenced at runtime via `${CLAUDE_PLUGIN_ROOT}`.

## Repository layout

```
agent-ready/
├── .claude-plugin/marketplace.json     # makes this repo an installable marketplace (two plugins)
├── plugins/agent-ready/
│   ├── .claude-plugin/plugin.json
│   ├── skills/                         # the seven skills above
│   └── assets/                         # templates the setup skills copy into a target
│       ├── github/                     # labels.json + ISSUE_TEMPLATE/
│       ├── ci/                         # stack-specific CI workflow stubs
│       └── methodology/                # the portable methodology docs
├── plugins/agent-ready-guardrails/     # the safety baseline (deny/ask/allow + PreToolUse guard)
│   ├── .claude-plugin/plugin.json
│   ├── policy/permissions.json         # the canonical deny/ask/allow policy
│   ├── hooks/                          # guard.sh + hooks.json (catastrophic-subset backstop)
│   └── scripts/install-policy.sh       # idempotent policy merge into a settings file
├── case-study/                         # the pilot retrospective + worked corpus
└── LICENSE                             # MIT
```

## Roadmap

- [x] Scaffold: marketplace + plugin manifests, folder skeleton, license
- [x] Specify the `plan-epic` + `fix-epic` pair-mode cluster skills (scaffolds)
- [x] Lift & sanitize the methodology docs, the `area-audit` / `fix-issue` /
      `update-pr` skills, issue templates, and the case study from the pilot
- [x] Build `repo-bootstrap` (idempotent labels + templates + CI stub + branch protection)
- [x] Build `methodology-install` (copy docs, rewrite dangling cross-links, init prompts dir + empty register)
- [x] Build `plan-epic` and `fix-epic` (severity-ranked clustering + pair-mode epic execution)
- [x] Add the `agent-ready-guardrails` plugin (deny/ask/allow baseline + PreToolUse guard + installer)
- [ ] Validate the whole pipeline on a second codebase

## Status & honesty

The methodology is **v1, calibrated to one codebase, one operator, one model
family.** It is promising, not proven across codebases — the next repositories
are the test plan, not the confirmation. See the case study's caveats.

## License

[MIT](LICENSE) © 2026 Javier Feliu
