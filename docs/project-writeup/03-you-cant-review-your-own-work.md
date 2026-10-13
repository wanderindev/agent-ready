# You can't review your own work

There is a failure mode that arrives the moment AI starts writing a real share of your code, and it is not the one people worry about. Everyone worries the code will be wrong. The quieter problem is that the code will be plausible, there will be a lot of it, and the person reviewing it will stop actually reading.

A reviewer facing a long, tidy, confidently-written diff from an agent is under a specific pressure. The diff looks fine. It usually is fine. Reading it carefully takes real time, and the last twenty like it were fine, so the rational-in-the-moment move is to skim and approve. Do that enough and review becomes a rubber stamp, which means the one place a mistake was supposed to be caught has quietly stopped catching anything. The more your agents produce, the stronger this pressure gets, which is a bad property: the mechanism erodes exactly as you lean on it harder.

## The rule

The principle I landed on is simple to state and annoying to accept: you may not sign off on work using the same context that produced it.

In the original pipeline, the implementation agent reviewed its own diff before opening a pull request, running a self-review checklist, and then decided whether the PR was ready. That is the review you cannot trust. The agent that just wrote the code has every reason its own change is correct loaded into its head, and it will read the diff the way the author of anything reads their own draft, seeing what it meant rather than what it says. A checklist run by the author is a good pre-flight. It is not a review.

So I split the two apart. The implementation agent now always opens its pull request as a draft and reports back that it believes the work is complete. It no longer gets to decide that it is. Readiness is conferred by something else.

## A genuinely fresh pair of eyes

That something else is a separate review agent with none of the implementer's context. It reads the diff, checks it, and returns a structured verdict. Only a pass flips the PR from draft to ready.

The nice thing about the way Agent Ready is built is that a fresh reviewer is almost free to arrange. Every agent the orchestrator spawns starts with a clean context. It does not inherit the implementer's history, because it is a different agent, and it does not inherit the orchestrator's, because the orchestrator hands it only the pull request reference and the scope it is allowed to check against. So the "fresh session" that the anti-rubber-stamp principle demands is just another subagent, not a second tool or an external process. The independence is structural, and the only rule I have to hold to is to never collapse the two roles back together by letting the implementer review itself. The value is entirely in the reviewer being a different mind than the writer. Merge them and you have kept the cost and thrown away the point.

There is a bonus that falls out of doing this inside the methodology rather than as a generic diff check. The reviewer is handed the brief's scope: what was in bounds, what was explicitly off limits. So it does not just ask "is this diff reasonable," it asks "does this diff do what the issue asked, and does it stay inside the lines the brief drew." A context-free reviewer cannot check scope adherence, because it does not know the scope. This one does. It turned out to be a stronger review than the human-scale version I adapted it from, for that exact reason.

## Distrusting the verdict too

An independent reviewer is only worth something if you do not let it wave its own work through, so the orchestrator does not take the verdict at face value. If the reviewer claims a pass but its own findings include a blocker, or its documentation check failed, the verdict is downgraded to a fail. A pass has to be consistent with the findings it is paired with, or it is not a pass.

And the whole thing is fail-closed. If the review agent errors, or returns something that cannot be parsed into a verdict, that counts as a fail and the PR stays a draft. A pull request is never marked ready on a verdict that could not be read. The safe default when the check itself breaks is to assume the worst and leave the work for a human, not to sail through because the gate malfunctioned.

## Once, then hand it back

When a review fails, the methodology does one thing and then stops: it leaves the PR as a draft, posts the findings on it, and surfaces it to me. It does not enter an unattended fix-and-re-review loop. That restraint is deliberate. A draft pull request with an honest list of what is wrong is a good outcome, a real unit of progress a person can pick up in a minute. An agent grinding on the same change through cycle after cycle, its context ballooning as it goes, is the single most expensive way to fail, and it tends to end somewhere worse than where it started. Review once, be honest about the result, and put a human back in the loop rather than spending tokens to avoid one.

## Why this belongs to the team story

I built this while thinking about what happens when a whole team scales up AI-written code, and the rubber-stamp problem is worst there, not in solo work. A solo developer at least implicitly reviews their own agents' output because they are watching. On a team, review is peer review, and peer review of high-volume AI output is precisely where quality silently drains: the reviewer trusts the author, the author trusted the agent, and no one actually read the diff. An independent reviewer that has to pass before "ready" is one structural answer to that. The cultural half, which no tool can install for you, is the cheap norm that on an AI-authored change the reviewer leaves a note saying what they actually verified. The tool makes the independent look mandatory. The team has to make the honesty normal.
