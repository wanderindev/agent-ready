# Agent Ready — project constitution

This repository is **not an application**. It is a Claude Code **plugin
marketplace** that packages the "audit-to-autonomy" methodology so it can be
installed into other projects.

## What this repo is

- A marketplace (`.claude-plugin/marketplace.json` at the root) hosting two
  plugins: `plugins/agent-ready/` (the methodology) and
  `plugins/agent-ready-guardrails/` (the safety baseline).
- The `agent-ready` plugin bundles **skills** (the operational entry points) and
  **assets** (templates the setup skills copy into a target repo).
- The `agent-ready-guardrails` plugin bundles a deny/ask/allow **policy**, a
  PreToolUse **guard hook**, and an idempotent **installer** — the floor the
  methodology assumes is in place before agents touch a repo. It ships no
  permission rules in `plugin.json` (plugins can't); the policy travels as a
  JSON asset the installer merges, with the hook as a backstop.
- A **case study** (`case-study/`) — the pilot retrospective and worked corpus
  the methodology was extracted from.

## Structure rules

- Only `plugin.json` goes in `plugins/agent-ready/.claude-plugin/`. Everything
  else (`skills/`, `assets/`) lives at the plugin root.
- Skills auto-discover from `plugins/agent-ready/skills/<name>/SKILL.md`. No
  declaration in `plugin.json` is needed for the default `skills/` location.
- Skills reference bundled files via `${CLAUDE_PLUGIN_ROOT}` (resolves to the
  installed plugin's directory at runtime — works after the plugin is cached).
  Never hard-code absolute paths to assets.

## Provenance

The methodology was extracted from the Panama In Context (PIC) pilot. When
lifting content from that project, scan for `PIC-WORKED-EXAMPLE` blocks and
replace PIC-specific domain content with codebase-agnostic equivalents — the
block structure stays; the content is sanitized. The case study keeps PIC's
real numbers as the proof; the skills and methodology docs must be generic.

## Conventions to preserve

The methodology's own two load-bearing practices (preserve every session's
verbatim prompt; keep the cross-session register current) and its
gate-not-guideline meta-principle apply to development of this repo too. When a
discipline can be enforced by a skill that is in the loop at the moment it
applies, build a gate, not a guideline.

## Status

v0.1 — scaffolding. See `README.md` Roadmap for what is built vs. pending.
