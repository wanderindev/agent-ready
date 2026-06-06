---
name: methodology-install
description: "Install the audit-to-autonomy methodology docs into a target repository's own tree — copy the portable methodology directory in, walk the worked-example placeholders for domain-appropriate replacements, create the prompts directory and INDEX, and reset the cross-session register. Invoked after repo-bootstrap, before the first area audit. Use when the operator says any of \"install the methodology\", \"add the methodology docs\", \"set up docs/methodology\", \"sanitize the worked examples for this repo\", or is onboarding a new project to the audit methodology. STATUS: scaffold — not yet implemented."
---

# methodology-install

> **STATUS: scaffold.** This skill is specified but not yet implemented. The
> design below is the build target for the agent-ready roadmap.

## What this skill will do

Inject the **portable methodology docs** into the target repo's own
documentation tree (so the project owns them, checked in), and walk the
operator through the one irreducibly per-repo step: replacing the pilot's
worked examples with this codebase's domain-appropriate equivalents.

Plugins are read-only once installed and cannot write into a project on their
own — this skill does it explicitly with `cp`/`git`, sourcing the templates from
`${CLAUDE_PLUGIN_ROOT}/assets/methodology/`.

## Planned workflow

1. **Choose the docs home.** Ask where methodology docs should live (default
   `docs/methodology/`). Copy `${CLAUDE_PLUGIN_ROOT}/assets/methodology/` there.
2. **Sanitization walk.** Scan the copied files for `PIC-WORKED-EXAMPLE` blocks.
   For each, surface it and prompt the operator for the domain-appropriate
   replacement (severity-calibration examples, stop-the-line triggers,
   agent-friendly examples grounded in *this* codebase). The block structure
   stays; the content changes. Do **not** silently substitute generics — the
   worked examples are the methodology's irreducible per-repo cost.
3. **Prompts directory.** Create `docs/<phase>/prompts/` and an empty `INDEX.md`
   (the prompt-preservation convention).
4. **Reset the register.** Start `cross-session-register.md` empty (remove the
   pilot's illustrative rows) so this repo's first session begins a clean log.
5. **Report.** List what was installed, which placeholders are still unresolved
   (`[TODO]`), and what to do next (`repo-bootstrap` if not done; then the first
   `area-audit`).

## Gate to encode

Refuse to declare the install "complete" while any `PIC-WORKED-EXAMPLE` block
remains unresolved — mark each unfilled one as `[TODO — fill before first audit]`
and tell the operator the install is not finished. (Gate-not-guideline: the
sanitization step is the most likely to be skipped under time pressure.)

## Reference

The portable docs and the sanitization seam are described in the pilot's
`docs/methodology/README.md` (lifted into `assets/methodology/` during the lift
step of the roadmap).
