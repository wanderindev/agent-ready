I'm starting Phase 2 of the Panama In Context (PIC) audit-and-fix
pilot, in a fresh conversation. The full Phase 0 + Phase 1 audit is
complete; this phase is FIXING, not auditing. Before we do anything,
read the repo to reconstitute context — this conversation starts cold
and the repo is the source of truth, not your context window.

## Read these first, in order

1. docs/pilot/phase-1-synthesis.md — the methodology and the
   reasoning. Pay attention to §4 (per-session vs cross-session
   automatability), §5 (the auto-approve fence: reversible-vs-
   irreversible × production-vs-not), §6 (backlog shape and the
   four-track Wave 1).
2. docs/pilot/phase-1-backlog-snapshot.md — the current issue state.
   The §6 cluster list and §7 Wave-1 tracks are what Phase 2
   executes against. Note: this snapshot was taken at end of Phase 1;
   re-confirm current open/closed state via `gh issue list` early,
   since some issues may have moved.
3. docs/methodology/conventions.md — the load-bearing practices,
   including the gate-not-guideline meta-principle and the prompt-
   preservation + cross-session-register conventions that apply to
   Phase 2 too.
4. The Phase 2 planning decisions I recorded in the repo (check
   docs/methodology/cross-session-register.md) — sequential-not-parallel with repo 2; 
   the three-point strategy (PIC Phase 2 → public thesis articulation → repo 2);
   treating the frontend track as the first autonomous-agent
   experiment; Phase 2 instrumentation (an agent-friendly-outcome
   log).

## What Phase 2 is

Phase 2 fixes the backlog Phase 1 produced. It is a MODE SHIFT from
Phase 1: it produces code changes through PRs, it touches production,
and it's where the auto-approve fence and the four-track
parallelization strategy get exercised for real rather than described.

Do NOT use the area-audit skill or an audit-style prompt — those were
built for auditing. Phase 2 needs its own session shapes.

Global Wave 1 is already defined (synthesis §6, snapshot §7), four
concurrent tracks:
- edu critical: #97 → #91 → #90
- article critical: #99 (+ articles 39/40 prod content cleanup)
- LLM foundation: #76 (+ #68, #77, #78)
- frontend safety-net: #7, #106, #110

## This session — planning, then the urgent front-loaded work

Don't start fixing the wave structure yet. First:

### Part A — Reconstitute and confirm
- Read the documents above.
- Run `gh issue list` to confirm current open/closed state against the
  snapshot. Flag any drift.
- Confirm the resolutions of the two Phase-1.5-adjacent items:
  - Was #21 (alembic env.py model imports) closed, and is #3 (initial
    migration) therefore unblocked?
  - Was #5 (docker-compose secrets → env_file) resolved, or is it
    still open?
  Report what you find before proceeding.

### Part B — Front-load the urgent / gating work
Two things should happen before any wave-structure ceremony, because
they're either actively harmful or they gate other work:

1. **Articles 39/40 content cleanup.** These two articles carry
   doubled "About this Article" / "Continue Reading" nav blocks in
   both languages — live production corruption, visible on the public
   site now. This is the content-fix half of #99, decoupled from the
   code fix. A manual edit, not a code change. Surface a plan for
   doing this safely (it touches production content) and get my
   approval before executing.

2. **The Wave-1 infra prerequisites** — whatever the Part A check
   reveals is still gating: the migration cluster (#3 gated by #21,
   pairs with #4), and #5 if still open. These unblock downstream
   work.

### Part C — Propose the Phase 2 working model
Before we execute the four tracks, propose how Phase 2 should run.
Specifically:

- **The auto-approve fence.** Synthesis §5 specifies it: auto-approve
  reversible-AND-non-production work (reading, local tests, issue
  comments, local-DB ops); human-gate anything touching production
  (reads included, for PII/context reasons) or irreversible (history
  rewrites, mass deletions, schema migrations against real data,
  .env/credentials). Propose how to operationalize this for Phase 2
  given the Claude Code tooling available — what gets auto-approved,
  what stays gated.

- **The frontend track as autonomous-agent experiment.** The 17
  frontend issues (~88% agent-friendly, no linchpins, #117 as cleanest
  entry point) are the test bed for "agents run the wide-and-shallow
  track in parallel while humans drive the deep backend paths."
  Propose how to structure that — but this is an experiment to design,
  not execute this session.

- **Phase 2 instrumentation.** Per the recorded planning decision,
  Phase 2 measures which agent-friendly issues merge clean vs need
  revision vs shouldn't-have-been-attempted. Propose a simple log
  format (issue #, agent-friendly y/n, outcome) and where it lives.
  This is the data that tests §10's agent-friendly-gradation question.

## Working style

- This is a fixing phase. Code changes go through PRs; branch
  protection is on; don't merge — I review and merge.
- Preserve this prompt and subsequent Phase 2 prompts under
  docs/phase-2/prompts/ per the conventions doc. Set up that
  directory and its INDEX.md this session.
- Keep the cross-session register current — Phase 2's cross-session
  decisions (track sequencing, any re-scoping, stop-the-line-style
  discoveries) go in the same register, not a new one.
- Expect Phase 2 to generate its own methodology insights the way
  Phase 1 did — the fixing phase has patterns the current artifacts
  don't capture (sequencing a linchpin cluster, what makes an agent-
  friendly fix actually clean, how the fence behaves in practice).
  Note them as they surface; they're the seed of an eventual Phase 2
  methodology.

Begin with Part A — read the documents, confirm issue state, report
the #21/#3 and #5 resolutions. Then propose the Part B plan and the
Part C working model, and wait for my approval before executing any
production-touching fix.
