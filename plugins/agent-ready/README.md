# agent-ready (plugin)

The plugin half of the [Agent Ready](../../README.md) methodology. Installing it
adds the five skills below; the `assets/` directory holds the templates the two
setup skills copy into a target repository.

## Skills

| Skill | Status | Purpose |
|---|---|---|
| [`repo-bootstrap`](skills/repo-bootstrap/) | scaffold | Configure branch protection, CI, labels, issue templates on a target repo. |
| [`methodology-install`](skills/methodology-install/) | scaffold | Copy methodology docs into a target, sanitize worked-example placeholders, init the register. |
| [`area-audit`](skills/area-audit/) | to lift | Scaffold + gate the 10-slot area-audit prompt. |
| [`fix-issue`](skills/fix-issue/) | to lift | Drive issues to agent-written PRs through a gated brief→implementation pipeline. |
| [`update-pr`](skills/update-pr/) | to lift | Bring an open PR up to date with `main` in an isolated worktree. |

## Assets

| Path | Status | What |
|---|---|---|
| [`assets/github/labels.json`](assets/github/labels.json) | ready | The label set `repo-bootstrap` creates. |
| `assets/github/ISSUE_TEMPLATE/` | to lift | Issue templates copied into the target's `.github/`. |
| `assets/ci/` | to build | Stack-specific CI workflow stubs. |
| `assets/methodology/` | to lift | The portable methodology docs `methodology-install` copies out. |

Skills reference these via `${CLAUDE_PLUGIN_ROOT}/assets/...` so they resolve
correctly wherever the plugin is cached.
