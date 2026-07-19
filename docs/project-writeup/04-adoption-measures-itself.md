# Adoption measures itself

The headline numbers from the pilot, the 138 issues and the 165 pull requests and the zero broken builds, were all counted by hand at the end. I sat down when it was over and reconstructed them from the issue tracker and the git log. That is fine to do once, for a retrospective. It is useless for steering, because a number you only compute at the end tells you how it went, never how it is going. By the time you have it, the run you would have adjusted is finished.

The team version of this project is where the better idea came from. When you are trying to get a group to actually adopt a way of working, the question "are people adopting it" is tempting to answer with a survey, and a survey is the worst possible instrument: it measures what people say they do, filtered through what they think you want to hear. The move that works is to stop asking and start instrumenting. Make the work itself leave evidence. Then "are we adopting this" stops being a question you ask people and becomes a set of artifacts the workflow produces on its own, whether or not anyone is thinking about measurement.

## Measuring a method, not a person

Ported back to a solo methodology, that principle changes shape in a useful way. There is no team to measure the adoption of, so the thing that measures itself is the methodology's own effectiveness. Did the audit-to-autonomy loop actually work this month. Where is it breaking. The loop emits its own evidence as it runs, and a report rolls that evidence up on demand. The retrospective I used to reconstruct by hand now computes itself, at any point, from data the loop already produced.

## Store almost nothing

The design decision I am most happy with is what not to store.

Most of what you would want in a report is already sitting in GitHub and git, durably, whether or not you write it down anywhere. How many issues the audit filed and at what severity: that is issue labels. How many pull requests merged: that is the PR list. Whether `main` got a panic-fix right after a merge: that is the commit log. Whether the pace picked up: that is commit cadence. Copying any of it into a separate store would just create a second, staler copy of a fact GitHub already owns. So the report derives all of that live, at the moment you ask, and keeps none of it.

What it does keep is the small set of facts GitHub genuinely cannot reconstruct: the process events that happen inside the methodology and leave no public trace. Whether an issue was handed to an agent or fixed by hand. Whether a brief was held at the gate before dispatch, and why. And the review verdict that happens before a human ever sees the pull request, which is the sharpest quality signal the method produces and which exists nowhere unless the loop records it. Those go into a small append-only log.

That log lives locally and is never committed, following the same discipline as the rest of the methodology's working records. It is written only by the orchestrator, never by an agent off in its own worktree, because a shared file written from parallel worktrees was an old source of merge conflicts. And it is excluded from git automatically, through the local exclude file rather than the tracked ignore list, so it protects itself without anyone having to remember to. There is no service, no database, no dashboard to host. The team version reached for a hosted rollup to compare usage across people; that is the right tool for measuring people and the wrong one here, so it stayed out. Here, the whole instrument is some local lines of JSON and a script that reads them alongside `git` and the GitHub CLI.

## What it tells you

The report comes out in four parts. Backlog and clarity, from the labels: what the audit surfaced and how much of it is safe to automate. Autonomous quality, from the local log: how dispatched work turned out, and the first-pass rate of the fresh-session review, a number that only exists because [that review gate](03-you-cant-review-your-own-work.md) exists. Safety, from git: pull requests merged, and any revert or hotfix that landed on the base branch. Throughput, from the commit history: this window against the last one.

## Read it as a smell, not a score

I am careful about how much weight these numbers can bear, because a measurement you trust too much becomes a target you game. Some of the signals are honest heuristics: the safety number, for instance, is a search of commit messages for the words people use when they are undoing something, which finds real trouble but is not proof of it. Work I fix by hand, outside the autonomous loop, never shows up in the autonomy numbers at all, though it still moves the backlog and the throughput. So the report is a smell test, not a scoreboard. Its most useful reading is a trend and a direction to look. When the fresh-review first-pass rate starts sliding, the message is not "the agents got worse," it is "the briefs are slipping," because the brief is the [load-bearing variable](01-auditing-a-codebase-you-cant-trust-yet.md) and its quality shows up as review failures downstream. The number does not fix anything. It tells you which end of the pipeline to go look at, which is most of what a good measurement is for.
