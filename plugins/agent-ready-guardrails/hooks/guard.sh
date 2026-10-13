#!/bin/bash
# agent-ready-guardrails PreToolUse guard — defense-in-depth for the
# CATASTROPHIC subset of the policy. The full deny/ask/allow policy lives in
# ../policy/permissions.json (installed by scripts/install-policy.sh); this
# hook blocks the worst actions even on a machine where the policy was never
# installed, because it ships with the plugin and is active on enable.
#
# Contract: a PreToolUse hook that exits 2 blocks the tool call BEFORE
# permission rules are evaluated; stderr is shown to the model.

set -u

input=$(cat)

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty')

deny() {
  echo "agent-ready-guardrails: blocked — $1" >&2
  exit 2
}

case "$tool_name" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    [ -z "$cmd" ] && exit 0

    # pattern<TAB>reason — extended regexes, catastrophic actions only
    while IFS=$'\t' read -r pattern reason; do
      [ -z "$pattern" ] && continue
      if printf '%s' "$cmd" | grep -Eq "$pattern"; then
        deny "$reason"
      fi
    done <<'PATTERNS'
git[[:space:]]+push[^|;&]*--force	force-push is not allowed (protected history)
git[[:space:]]+push[[:space:]]+-f([[:space:]]|$)	force-push is not allowed (protected history)
git[[:space:]]+reset[[:space:]]+--hard	hard reset discards work; ask the human to run it
git[[:space:]]+clean[[:space:]]+-[[:alpha:]]*f	git clean -f deletes untracked files; ask the human
git[[:space:]]+filter-branch	history rewriting is not allowed
rm[[:space:]]+-[[:alpha:]]*[rR][[:alpha:]]*[fF]	recursive force-delete is not allowed; ask the human
rm[[:space:]]+-[[:alpha:]]*[fF][[:alpha:]]*[rR]	recursive force-delete is not allowed; ask the human
gh[[:space:]]+pr[[:space:]]+merge	humans merge PRs, agents never do
AKIA[0-9A-Z]{16}	command contains an AWS access key literal — use a named profile / the AWS CLI
gh[pousr]_[0-9A-Za-z]{16}	command contains a GitHub token literal — use gh auth / the GITHUB_TOKEN env var
github_pat_[0-9A-Za-z_]{20}	command contains a GitHub fine-grained token literal — use gh auth / an env var
PATTERNS

    # Secret stores must not be read/copied via the shell either — the
    # file-path tools are blocked below, but a Bash `cat ~/.aws/credentials`
    # (or `cd ~/.ssh`, `tar ... ~/.aws`, `cp -r ~/.aws …`) would otherwise
    # slip past and hand an agent the raw keys. Match the dir at a path
    # boundary whether or not a trailing slash / filename follows.
    ss='(^|[^[:alnum:]])\.aws([^[:alnum:]]|$)'
    ss="$ss"'|(^|[^[:alnum:]])\.ssh([^[:alnum:]]|$)'
    ss="$ss"'|(^|/)secrets([^[:alnum:]]|$)'
    if printf '%s' "$cmd" | grep -Eq "$ss"; then
      deny "secret store referenced in a shell command — credentials are managed by the human"
    fi
    ;;

  Edit|Write|MultiEdit|NotebookEdit|Read)
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -z "$file_path" ] && exit 0

    # Secret stores: no tool may touch them at all (~/.aws and ~/.ssh hold live
    # cloud/host keys — reading them would let an agent bypass every other
    # guardrail by acting directly against the provider).
    if printf '%s' "$file_path" | grep -Eq '(^|/)\.aws(/|$)|(^|/)\.ssh(/|$)|(^|/)secrets/'; then
      deny "secret store ($file_path) — credentials are managed by the human"
    fi

    # Env/credential files: no writes (reads allowed except the stores above)
    if [ "$tool_name" != "Read" ] && printf '%s' "$file_path" | grep -Eq '(^|/)\.env(\.[^/]*)?$|(^|/)credentials[^/]*$'; then
      deny "env/credential file ($file_path) — edit it manually"
    fi
    ;;
esac

exit 0
