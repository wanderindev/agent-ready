# agent-ready (plugin)

The plugin half of the [Agent Ready](../../README.md) methodology. Installing it
adds the five skills below; the `assets/` directory holds the templates the two
setup skills copy into a target repository.

## Skills

| Skill | Status | Purpose |
|---|---|---|
| [`repo-bootstrap`](skills/repo-bootstrap/) | built | Configure branch protection, CI, labels, issue templates on a target repo. |
| [`methodology-install`](skills/methodology-install/) | built | Copy methodology docs into a target, rewrite dangling cross-links, init the prompts dir + empty register. |
| [`area-audit`](skills/area-audit/) | lifted | Scaffold + gate the 10-slot area-audit prompt. |
| [`plan-epic`](skills/plan-epic/) | built | Cluster the open backlog by severity into a workable epic; propose 2–3, create the chosen one. |
| [`fix-epic`](skills/fix-epic/) | built | Execute an epic in pair-mode — one coherent branch/PR for the whole cluster. |
| [`fix-issue`](skills/fix-issue/) | lifted | Drive issues to agent-written PRs through a gated brief→implementation pipeline, with an independent fresh-session diff review conferring readiness (autonomous). |
| [`update-pr`](skills/update-pr/) | lifted | Bring an open PR up to date with `main` in an isolated worktree. |
| [`report`](skills/report/) | built | Print the self-computed methodology scorecard — backlog/clarity, autonomous quality (outcomes + fresh-review pass rate), safety, throughput. Read-only; joins a local event log with live `gh`/`git`. |

## Assets

| Path | Status | What |
|---|---|---|
| [`assets/github/labels.json`](assets/github/labels.json) | ready | The label set `repo-bootstrap` creates. |
| `assets/github/ISSUE_TEMPLATE/` | ready | Issue templates copied into the target's `.github/`. |
| `assets/ci/` | ready | Stack-specific CI workflow stubs (python / node / generic). |
| `assets/methodology/` | ready | The portable methodology docs `methodology-install` copies out. |

Skills reference these via `${CLAUDE_PLUGIN_ROOT}/assets/...` so they resolve
correctly wherever the plugin is cached.
