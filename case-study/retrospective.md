# Retrospective: turning a vibe-coded side project into a codebase I can build on

**Date:** 2026-06-06
**Author:** Javier Feliu
**Project:** Panama In Context (PIC)
**Scope:** the whole journey — audit through 138/138 issues closed

> This is the first-person companion to the methodology documents. The
> [Phase 1 synthesis](pilot/phase-1-synthesis.md) and the
> [Phase 2 addendum](pilot/phase-2-addendum.md) describe *the method*; the
> [public article](pilot/public-article.md) makes the tight autonomous-agent
> argument. This document is the honest, fuller arc — what I expected, what
> actually surprised me, and where the story revised itself by the end. It is
> written to seed a reusable methodology repository, so the lessons are stated
> the way I'd want to read them on the next codebase.

---

## Where this started

I'd been watching sessions from a conference in May. A recurring theme was
running Claude autonomously on managed infrastructure — agents picking up
issues and fixing them on their own. It was a compelling pitch, and I was
skeptical of it. Not of the demos, but of whether it mapped onto the codebases
I actually live in: personal, mostly-vibe-coded side projects, or large work
codebases with years of legacy written by tens of developers who came and went,
unevenly tested, inconsistently styled. Autonomous agents finding and fixing
issues on *that* felt more like a pipe dream than something I could use now.

PIC is the personal end of that spectrum. It's a real, deployed, bilingual
content-and-booking site — React 19 + Vite, FastAPI + Postgres, payments, email
pipelines, an admin CMS — but it was built the way side projects get built: in
weekend bursts, over months, by one person.

So I ran the experiment. Not "point an agent at the repo and hope," but: do a
full audit first, see what it surfaces, and decide from the evidence whether
autonomy was real or a pipe dream.

The audit surfaced everything. Leaked production credentials sitting in git
history for five months. A dev `DATABASE_URL` that defaulted to *production*.
Nineteen broken tests, one of them hiding a live `AttributeError`. Swallowed
exceptions, half-applied fixes, an unauthenticated admin router. From those
findings I configured the repository the way it should have been from day one —
branch protection on `main`, a CI pipeline, issue labels, issue templates — and
filed every finding as a well-specified GitHub issue. Some were labeled
`agent-friendly`; only those could be handed to an agent unattended. Everything
else was tackled as human + AI pair programming.

As we went, we tuned the workflow and eventually codified it into skills, so the
whole thing is reproducible on the next project.

---

## What actually surprised me

I went in expecting the *autonomy* to be the revelation. It wasn't. The
revelation was **continuity**.

### The real win: clarity killed the blank page

The way I used to work on this project: I'd start a weekend with an idea for a
feature. By Sunday night it would be partially built and sort of working — but
there was never a clean answer to *what to do next* when I came back weeks
later. Whatever I'd done was no longer fresh. Features sat half-finished. The
audit confirmed this wasn't just a feeling — it found the same shape all over
the code: the right pattern applied in four places and missed in the fifth, a
good idea started and not carried through. ("Partial-correction debt" is the
methodology's name for it.)

GitHub issues — with labels, severities, and full descriptions — completely
fixed the continuity problem. When I sat down, I didn't have to reconstruct my
own context or decide what mattered. I looked at the backlog, picked a cluster
of related issues, and was productive from the first minute. The "blank page"
blocker that writers talk about — the thing that quietly kills side projects
between sessions — was just *gone*. And because starting was frictionless,
I came back more often. The clarity was motivating in a way I didn't predict.

That's the part I'd tell another solo developer first. The agents are great.
But the thing that turned a stalled side project into one I shipped 138 fixes
into was writing the work down clearly enough that future-me could start cold.

### Why autonomy was the unsurprising part

By the time we actually achieved reliable autonomous fixes, the surprise had
been engineered out of it. We'd added tests, stood up CI, written a methodology
for producing tight briefs, and — crucially — selected *which* issues an agent
should ever touch. Given all that prep, autonomy mostly just worked. It felt
less like a leap and more like the obvious payoff of the groundwork. The
headline ("agents wrote and merged 16 PRs with zero interventions") is true,
but the real work was everything that came before it.

---

## The mechanism behind the accuracy: two passes over the code

If I had to name the single thing that made the fixes reliable, it's that every
change got **two independent passes over the relevant code, weeks apart**:

1. **Pass one — the audit.** A session read the area, identified a problem, and
   documented it as one or more GitHub issues with concrete claims (file, line,
   severity, acceptance criteria).

2. **Pass two — implementation.** When the issue was actually picked up, Opus
   re-verified the ticket's claims *against the current source* before any
   implementation plan was written. This second pass routinely caught things
   the first pass got wrong or didn't know yet: stale line numbers, an
   API the issue assumed but that didn't exist, edge cases, and — often — places
   where the change wouldn't be covered by the existing test suite.

After that second verification pass, writing a reliable implementation plan was
easy, because the plan was built on re-confirmed facts rather than on a weeks-old
ticket. The brief is the contract; the second pass is what keeps the contract
honest as the codebase moves underneath it.

---

## The part of the story that revised itself

The public article's headline is autonomous agents running in parallel. That
was a true and exciting moment — but it is not where I landed, and the
retrospective should say so plainly.

At the start of the final fixing stretch I leaned into independent agents:
`agent-friendly` issues dispatched to parallel runs via the `fix-issue` skill,
each in its own worktree. It worked. But the **merge friction was off-putting** —
parallel PRs landing against a moving `main`, conflicts on shared files, an
update-and-rerun cycle per PR. The throughput was real; the experience was not
something I wanted to keep doing.

So I changed how I worked. Instead of fanning issues out to independent agents,
I started taking **groups of related issues into a single pair-programming
session** — and those groups *included* the agent-friendly ones. This was, in my
judgment, more productive: I had far better visibility into the changes, the
issues that touched the same code got resolved together coherently, and the
merge friction largely disappeared. After that point, even with `agent-friendly`
issues still open in the backlog, I mostly stopped sending them to independent
agents.

The honest conclusion: **the audit-and-classify methodology was the durable
win; unattended parallel autonomy was a phase I tried, validated, and then
chose to use sparingly.** The `agent-friendly` label kept earning its keep — but
as a signal of *tractability* that made clustered pair sessions move fast, not
only as a dispatch trigger. For a solo developer who is going to review
everything anyway, clarity + pairing beat fan-out-and-merge. On a team, with
reviewers absorbing the parallel PR load, the balance might tip back. That's a
repo-2 question, not a settled one.

---

## We never broke `main` — and why

Across the entire effort, the project never broke once. The evidence I'd stand
behind:

- **138 issues filed, 138 closed, 0 open.**
- **165 pull requests, all 165 merged — none abandoned, none reverted.**
- Every PR went through branch protection and a required CI check; nothing
  reached `main` without passing.

That record wasn't luck. The guardrails that earned it, in rough order of how
much I credit them:

1. **Phase 0 first.** Before any agent did unattended work, the repo was made
   *safe* for it: green tests, protected `main`, CI with secret scanning,
   credentials rotated, prod separated from dev. The cost of doing this first is
   finite; the cost of not doing it is invisible until something breaks.
2. **The auto-approve fence — reversible-vs-irreversible × prod-vs-non-prod.**
   Not "non-destructive is safe." The audit produced the exact counter-examples
   that prove the naive fence wrong: a routine-looking raw-SQL `UPDATE` that
   corrupted production data; an in-memory DoS with no database touch at all; a
   `SELECT *` that would pull customer PII into an agent's context. The fence is
   enforced in three layers (deny rules in settings, prod access routed through
   named skills, a production-touch line in every PR).
3. **The brief-verification gate.** No issue is implemented from its ticket
   alone — the second pass re-verifies against source, and genuinely risky work
   (schema migrations, PII tables) is *held* for me to handle, not auto-shipped.
   Issues #63 and #64 are the proof: the gate caught them and refused to let an
   agent apply a migration to the production auth table.
4. **Worktree isolation.** Agent work happened in throwaway git worktrees, so a
   bad run could never corrupt my checkout or the protected branch.

The close calls are the evidence the guardrails matter. None of them reached
production *because* a gate was in the way.

---

## The productivity, honestly

I genuinely feel I did six months of improvement in the final couple of
weekends. I want to be careful about that claim, because this is the first time
I've worked this project through issues, so there's no clean per-issue baseline
to compare against. But the raw activity record is stark:

- **409 commits in the last 14 days** vs. **120 commits in the entire previous
  six months** — more than 3× the prior half-year's output, in two weeks.
- The GitHub contribution graph shows ~568 contributions in the last two weeks
  (peaks of 205 on Saturday May 30 and 68 on Sunday May 31) against 398 in the
  previous six months.
- The single biggest day was **152 commits on Saturday, May 30** — one weekend
  day outproducing most prior months.

The timeline is worth being precise about, because "two weekends" is the felt
experience, not the calendar. Building the *methodology* from zero — the audit,
the pilot, the prep, Phases 1 and 2 — took several weeks of experimentation,
because we were inventing the workflow as we went. The *bulk of the actual
coding* then compressed into the final stretch from late May to now, because by
then the backlog was clear, the guardrails were in place, and starting a session
cost nothing. The weeks of methodology-building are what made the two weekends
possible.

---

## What I'd tell someone starting — and what this means for the methodology repo

1. **Do the audit first, and classify as you go.** The labels matter less than
   the act of writing down, per issue, *why* a piece of work is or isn't
   tractable. The audit teaches you the shape of your own codebase.
2. **Treat the issue backlog as the cure for discontinuity, not just a TODO
   list.** For a solo or stop-start project, well-specified issues are what let
   you be productive from minute one of a cold session. That alone justifies the
   whole exercise.
3. **Make the brief the engineering work, and verify it against source twice.**
   The second pass — re-checking the ticket's claims against the live code before
   planning — is the reliability mechanism.
4. **Build the guardrails before you need them.** Branch protection, CI, the
   auto-approve fence, worktree isolation, and a gate that *holds* the genuinely
   risky changes. We never broke `main`; the guardrails are why.
5. **Use autonomy where it's cheap and pairing where it's clarifying.** Parallel
   unattended agents are real and fast, but for a solo reviewer the merge
   friction can outweigh the speed. Clustered pair sessions on related issues —
   agent-friendly ones included — were my most productive mode.

The goal now is to make this reproducible: a methodology repository I can clone
into the next project, with skills that bootstrap the git/CI/label/issue
infrastructure, install the methodology docs, run the audit, and work through the
resulting issues — as a pair, or autonomously where it pays. This retrospective
is the case study that repository will carry as its proof and its honesty.

---

## The honest caveat

Still one codebase, one operator, one model family. PIC is a stop-start solo
project with high pattern density (canonical patterns tend to live in the same
file as the fix targets), which made tight briefs easier than they might be
elsewhere. The methodology is *promising*, calibrated against this codebase's
specific shape — not *proven* across codebases. The next repositories are the
test plan, not the confirmation. What I can say without hedging: on this
codebase, it turned a stalled side project into one I can safely build on, and
it never broke once.
