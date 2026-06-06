# Audit before autonomy: how I shipped 16 autonomous-agent PRs on an existing codebase

Over four weeks earlier this year, sixteen pull requests on my codebase were written entirely by autonomous AI agents and merged with zero reviewer interventions on code substance. The agents ran in isolated git worktrees, opened PRs against `main`, and I never paired with them mid-session — I briefed each one, reviewed its work after it finished, and merged. The variety mattered: a one-character bug fix; an i18n sweep that extracted seventeen hardcoded strings to translation keys across thirteen files; a new bilingual React component with a catch-all route; a JSX accessibility restructure on a card component with a nested-button defect; a multi-file lazy-loading sweep across eleven public components; the deletion of two dead pages plus their route. None of it was trivial. None of it required a human at the keyboard.

The codebase isn't a toy. It's a bilingual content and booking site I run, built over months: React 19 + Vite on the frontend, FastAPI + Postgres on the backend, with the usual real-codebase complications — payment integrations, email pipelines, admin CMS, a public site. The pull requests weren't accepted because I was lenient. I merged them because they were genuinely correct.

**The methodology that made this work isn't about the agents — it's about auditing the codebase first to find the tractable subset, then writing briefs tight enough to pre-resolve every ambiguity an agent would otherwise resolve unsupervised.**

That sentence is the article. The rest is how I got there and what surprised me.

## Why this isn't obvious

Most teams trying autonomous AI agents on existing codebases pick one of two patterns. The first is to pair with the agent — open a chat, hand it tasks, watch every tool call, approve every edit. This works but doesn't scale; the human is the bottleneck and the agent is barely faster than a senior developer with good autocomplete. The second pattern is to point the agent at the codebase and hope: "implement X, here's the repo." This is faster when it works but hits a wall fast on any real codebase — the agent makes plausible-but-wrong assumptions, fixes the wrong file, introduces silent regressions, or grinds for hours on the wrong abstraction.

Neither pattern delivers what you actually want, which is *autonomous output you can trust at PR-review time.* Pair-mode produces trust but no autonomy. Hand-off produces autonomy but no trust.

There's a third option that worked at sixteen-out-of-sixteen on my codebase: **audit the codebase first to find the work that's tractable for autonomous agents, then deploy autonomy only against that subset.** Humans stay on the work that isn't tractable — the deep refactors, the cross-cutting concerns, the financial flows, the parts of the codebase where a wrong assumption is expensive. Agents do the tractable subset cleanly, freeing human attention for everything else.

This sounds obvious in summary. It wasn't obvious to me when I started, and the literature I'd read didn't propose it. What made it work was that the audit produced more than a list of bugs — it produced a *classification* of which bugs were agent-tractable. That classification is the bridge.

## The methodology

Three components, in execution order.

### 1. Audit, with classification

I spent six weeks before any agent ran a fix on a structured audit of the codebase. Nine area audits, ~110 issues filed against GitHub, each carrying a severity label *and* an orthogonal `agent-friendly` label per a six-criterion rubric. The criteria: (1) single-file or tightly-scoped multi-file change; (2) no business logic decisions required; (3) no schema migrations; (4) no auth, payment, or PII handling; (5) tests exist or can be added trivially; (6) clear acceptance criteria. All six must hold for the label to apply. Borderline cases default to no.

This is the most important thing I did. The label isn't a guess about agent capability in the abstract — it's a domain-specific judgment about the codebase. *This* issue is agent-friendly because it's a sweep across sibling call sites with a canonical pattern already in the codebase; *that* issue isn't because it requires choosing between two payment flow architectures. The audit teaches you which subset is tractable for autonomy by forcing you to articulate why, in writing, per issue.

The audit also revealed the shape of the codebase in a way the labels alone don't. My frontend turned out to be wide-and-shallow: many small components, lots of similar patterns, ~88% of frontend issues `agent-friendly:yes`, no linchpin dependencies. My backend was the opposite: narrow-and-deep, with linchpin clusters (one issue gates a dozen others), only ~29% agent-friendly. The autonomous track became the frontend; the backend stayed operator-driven. That decision wasn't theoretical — it followed directly from what the audit found.

### 2. Brief-tightness as the load-bearing variable

The first autonomous run produced a clean-merge PR — but also three ambiguity events I hadn't anticipated. The agent encountered three places where the brief I'd written didn't match the source code I was asking it to modify, and resolved each one on its own. None of them broke anything; the agent picked the right answer each time. But they were free signals that my brief was looser than I'd thought, and I treated them as data.

From the second run onward, every brief tightened on three concrete disciplines. **(a) Every codebase-fact claim in the brief is traceable to a specific `file:line` I read at brief-writing time.** No "the canonical pattern is in X" from memory; if I claim a pattern exists, I've just re-read it. **(b) Count interpretations are pre-resolved in the brief.** If the issue says "22 catch blocks across 9 files," the brief specifies which 22 — including which ones are already-conformant exemplars vs which need the fix. **(c) Worktree setup is pre-resolved.** Agents work in isolated git worktrees; those worktrees don't have a `node_modules` directory; the brief explicitly tells the agent how to handle that (symlink from the main checkout).

Result: across the next fifteen autonomous runs, the total ambiguity events were two — both surfaced by the agent transparently, neither requiring my intervention. Same agent. Same codebase. Same kinds of issues. Tighter brief.

The conclusion that fell out of this comparison surprised me: **the brief is the load-bearing variable for autonomous quality. Not the model, not the codebase, not the issue. The brief.** The agents I was using were the same agents whether the brief was tight or loose; the difference between ambiguities-in-three and ambiguities-in-zero was the brief.

This was the methodology-relevant moment. Most discussions of AI-agent capability treat the agent as the variable being tested. At my scale, the agent's job was straightforward — execute against a specification. The variable was whether the specification was good enough.

### 3. Autonomy on the audited subset; humans on everything else

The remaining choice was straightforward: deploy autonomy on what the audit classified as `agent-friendly:yes`; keep humans on everything else.

For the frontend, this meant a four-phase ramp-up: one agent on the cleanest single issue, then three serial runs, then three parallel runs, then a full track of nine more split across two waves of five and four. Each step's data justified the next. If the single-agent run had produced a draft PR with surfaced ambiguities, I'd have stopped there and tightened the brief template before scaling. It clean-merged, so I scaled. The four-step ramp-up isn't a recipe I invented before starting; it's the structure that emerged from being honest about what each batch's data argued for.

For the backend, the operator (me) stayed in the loop. The backend work that did get done — a Composio→SMTP migration, the resolution of a critical regeneration bug, a few smaller items — was all pair-mode, because that's what the audit said it should be. The agents didn't run on backend issues at all.

The variety inside the autonomous frontend track was the unexpected payoff. Issues ranging from one-character fixes to multi-file sweeps to JSX restructures to dead-code removal to infrastructure-only-shipping (a custom hook with no immediate consumers, intentionally) all landed clean. The brief tightness traveled across shape.

## The two things I didn't expect

### The brief was harder than the agent

The first autonomous run's three ambiguity events are the clearest illustration. One of them: I'd told the agent that the codebase's toast notification hook came from a `ToastProvider` wrapping the admin pages. It didn't. The hook was local state; each consumer rendered its own container. The agent caught the contradiction by reading the source, followed the source over my brief, and surfaced the discrepancy in the PR description.

That was the moment I stopped thinking about agent capability and started thinking about brief-writing as engineering work in its own right. The agent could have done what I asked. It would have wired up a `ToastProvider` that didn't exist, broken the surrounding code, and produced a PR I'd have had to reject. Instead, it noticed that the world I described in the brief wasn't the world it was looking at, and chose the world. The methodological cost of that choice was small for the agent and substantial for me: I had to re-think how I wrote briefs.

The fix was simple. Every brief from then on described codebase facts only when I'd just re-read the source. The discipline survived contact with eight more autonomous runs and never produced another shape-2 disagreement. Most of the work of "deploying AI agents on a codebase," for me, turned out to be the work of writing briefs that didn't lie about the codebase.

### The failure mode worked

The sixteenth autonomous run is the second anchor worth telling. The brief asked the agent to make a broken Save button work in an admin editor. The agent investigated, discovered that the backend had no endpoint for the operation, found that the issue body itself anticipated this case ("if this is supposed to be read-only, the right answer is to make the read-only path explicit"), and opened the PR as a draft with a comment explaining the situation.

The draft PR wasn't a failure. It was the methodology working. Every brief I wrote for autonomous runs included an explicit escape-hatch clause: "if the primary path is blocked, stop and surface as draft, with the alternative if the issue body anticipates one." The agent followed that, found the alternative the issue body itself anticipated, removed a latent safety hazard (a dead handler that would have blanked article content if anyone ever wired it to a button), and stopped. I reviewed the draft, agreed with the agent's read, marked it ready-for-review, and merged.

One draft PR in sixteen runs — 6.25% draft rate. Zero stalls. Zero inappropriate scope expansions. The escape hatch didn't just save time at the stop point; it produced agent behavior I'd describe as *sophisticated.* The agent didn't just stop; it found a value-positive alternative within the brief's framing and surfaced it for me to ratify or reject.

The lesson generalizes: when you give autonomous agents a brief, give them an explicit failure mode. Without one, you risk stalls (agent does nothing) or scope expansions (agent unblocks itself by changing the work). With one, agents handle blocked paths the way a good engineer would: stop, write up what you found, propose the next move.

## What I don't know yet

One codebase. One operator. One model family. Sixteen issues from one audit's `agent-friendly:yes` pool. Four weeks. The methodology is *promising*, not *proven.*

The findings I've described — the audit-then-autonomy pipeline; brief-tightness as the load-bearing variable; the escape-hatch pattern; the agent-tractable-subset framing — are all calibrated against my codebase's specific shape. My codebase happens to have high *pattern density:* canonical patterns live in the same codebase as the fix targets, often in the same file. That made brief-tightness easier to achieve than it might be on a codebase where every fix requires inventing the pattern from scratch. Whether the methodology survives lower pattern density is a thing I can't tell you yet.

The next two tests are already scheduled. The first is a personal project of mine, smaller and structurally different from this one. The second is a small company project where I won't be both the auditor and the fix-executor. Different orchestrator, different memory of the audit, different production topology. If the methodology produces similar results on both, the findings start to generalize. If it doesn't, the findings get refined down to "this works on a codebase with shape X under conditions Y," which is still useful but more bounded.

Until then: methodology v1, dated, calibrated to one codebase, honest about the caveat.

## If you want to try this

Two notes for anyone considering autonomous agents on an existing codebase:

**Do the audit first.** I spent six weeks on the audit before any agent did a fix. That seems long until you compare it to six months of fix-mode false starts. The audit produces something you can't get any other way: a written justification, per issue, of why this work is or isn't tractable for an agent. The labels themselves are less important than the act of articulating them — the audit teaches *you* the shape of your codebase along the way.

**Treat the brief as the engineering work.** The agent does what the brief tells it to do. If the brief is wrong, the agent is wrong; if the brief is loose, the agent fills the looseness with its own judgment, which is sometimes right and sometimes not. The brief is the contract. Write it like one. Re-read the source you reference. Pre-resolve the counts. Specify the escape hatch. The hour you spend tightening a brief is the hour you don't spend reviewing a misaimed PR.

The full methodology — the audit pattern, the brief-template disciplines, the agent-vs-brief disagreement taxonomy, the auto-approve fence, the failure-mode escape hatch — lives in the project's GitHub repository as a Phase 1 synthesis document and a Phase 2 addendum. Both are explicitly v1, calibrated to one codebase, falsifiable on the next. If you try the methodology and get different results, that's the data the v2 version will be built on. The promising part of v1 is that it produced sixteen-out-of-sixteen at the codebase it was calibrated against. The honest part is that one codebase is one codebase.

If you do try it, tell me how it went. The next two repos will tell me whether the methodology generalizes; another two or three would tell me whether it generalizes broadly. Methodology survives on contact with codebases that weren't its training data.
