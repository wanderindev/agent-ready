# Auditing a codebase you can't trust yet

Every side project that survives long enough arrives at the same place. It works. It is deployed. Real people use it. And you have stopped touching it, because the parts you understand are tangled up with parts you wrote at 2am eight months ago and no longer remember, and you cannot tell by looking which is which. The codebase is not bad, exactly. It is unaudited. The uncertainty is small and everywhere, and small-and-everywhere is the hardest kind to clear.

That is the state Agent Ready starts from, and it is why the first phase is not "write code" but "find out what is actually here."

## Why you cannot skip straight to autonomy

The obvious move, once you have a capable agent, is to point it at the repo and start assigning work. The problem is that an agent inherits your uncertainty and adds its own. It does not know which of two nearly-identical helper functions is the canonical one either, and unlike you, it will not feel the small hesitation that makes you go check. So it picks one, plausibly, and moves on, and now the thing you were unsure about is baked into a diff that looks finished.

You cannot safely automate work you have not mapped. So the methodology maps first. The audit exists to convert a vague sense of "this area is sketchy" into specific, written-down claims about what is wrong, how bad it is, and whether a machine can be trusted to fix it.

## How the audit runs

The audit goes area by area, one fresh agent session per area, because a single session trying to hold the whole codebase in its head degrades exactly the way a person would. Each session is driven by a filled-in prompt with a fixed set of slots: what this area is, where its edges are, what "severe" means here stated as concrete failure modes, what would count as safe to automate, and pointers to what earlier areas already found.

Those per-area fills are not optional, and they are not a suggestion in a document. The skill that scaffolds the prompt refuses to emit a complete one until the fills are supplied. That is the first instance of a pattern that runs through the whole project: where a discipline is most likely to be skipped under time pressure, and a skill is in the loop at the moment it matters, I build a gate instead of writing a guideline. A stated request to "please ground your severity examples in this area" does not survive a tired operator. A structural refusal does.

Each area session ends by filing issues, and every issue gets two classifications. The first is severity, on a scale that considers both blast radius and evidence of real impact, so a scary-looking thing that cannot actually happen ranks below a boring thing that already burned someone. The second is the one that makes autonomy possible.

## The agent-friendly line

An issue is labeled `agent-friendly` only if it clears a six-part rubric:

- its scope is single and tight,
- it requires no business-logic judgment call,
- it involves no schema migration,
- it touches no authentication, payment, or personal-data path,
- tests either exist for it or can be added trivially, and
- it has acceptance criteria clear enough to know when it is done.

Everything that fails the rubric is still a real issue and still gets fixed. It just gets fixed with a human in the loop, through the paired path rather than the autonomous one. The rubric is not a quality bar on the issue. It is an honest statement about where unsupervised judgment is safe, and the methodology reserves autonomous execution for exactly that subset and no more.

## The brief is the thing that matters

Here is the finding I did not expect and now consider the center of the whole method: the quality of an autonomous fix depends almost entirely on the brief, and almost not at all on the agent or the issue.

A brief is the specification handed to the implementation agent. In Agent Ready it is written by a separate, read-only agent that reads the issue and then verifies every claim in it against the current source before writing anything down. Does the function the issue names still exist. Is the pattern it says to copy actually the pattern used elsewhere. Is the count of affected files right. The brief that comes out is not "here is a task," it is "here is a task, and here are the verified facts about the code as it exists right now, and here is exactly what is in scope and what you must not touch."

When a brief is that tight, the implementation agent's job stops being "figure out the right change" and becomes "carry out a change that has already been reasoned through." That is a job a smaller, cheaper model does reliably. When a brief is loose, no model saves you, because the agent has to make the very judgment calls the audit was supposed to remove. So the methodology spends nearly all its effort on producing and gating briefs, and treats the code-writing dispatch as the easy part it earned.

## Looking twice, weeks apart

The other thing that made autonomy trustworthy was looking at every change twice, independently. Once at audit time, when the issue is verified and classified. Again at brief-writing time, when a fresh agent re-checks the claims against source before committing to a specification. The two passes happen weeks apart and by different sessions with no shared memory, which means a mistake in the first has to survive a reader who has no reason to trust it. Most do not.

This is the same instinct that later became the [fresh-session review](03-you-cant-review-your-own-work.md) of finished diffs, and the same instinct that made a committed [safety floor](02-a-safety-floor-you-commit-not-remember.md) non-negotiable. Independent verification, applied at more than one point in the pipeline, is most of what separates "autonomy I trust" from "autonomy I hope about."

## What I would tell you honestly

Two things did not go the way I first designed them.

I started by running many autonomous agents in parallel and quickly hit merge friction: independent PRs stepping on each other, each needing a rebase and a CI round-trip. The fix was to cluster related work onto single branches handled in paired mode, and to reserve full parallel autonomy for genuinely independent, file-disjoint issues. The autonomous path is real and it earns its keep, but it is a scalpel, not a firehose.

And the durable value was never the autonomy. It was the audit-and-classify discipline that produced a backlog I could reason about. On the pilot that backlog reached 138 issues, all filed and all closed, across 165 merged pull requests, without once breaking `main`. But if I had to keep only one half of the method, I would keep the half that turns a codebase I am afraid of into a list I am not. The agents are how you go faster. The list is how you start at all.
