# A safety floor you commit, not remember

The first version of Agent Ready assumed a safety floor existed. The skills were written as if every repo they touched already denied the dangerous things: no force-push, no push straight to `main`, no merging a pull request from inside an agent, no writing to a secrets file. The methodology talked about that floor constantly. It just never shipped one.

I found out it mattered when I took the method to a second codebase. The repo looked fully set up. Branch protection, CI, labels, docs, all present. And the machine I was pointing agents at from that repo had no permission policy at all. The floor had been a habit on the first project, encoded in my personal settings, and habits do not travel with a git clone. A repo can look completely bootstrapped while the environment operating on it is wide open. That is the exact gap that turns "an agent did something surprising" into "an agent did something surprising and I could not undo it."

So the floor became a plugin: `agent-ready-guardrails`. This page is about what is in it and why it is shaped the way it is.

## Deny, ask, allow, and the rule that orders them

The policy sorts every risky action into three buckets, and the whole design follows from one fact about how those buckets interact: a deny set at the user level can never be overridden by an allow set at the project level. Deny wins, always. That makes deny a blunt, permanent instrument, and it dictates how you use each bucket.

- **Deny is for the catastrophic only.** Force-pushing, rewriting history, recursive force-deletes, merging a PR (people merge, agents do not), writing to `.env` or credential files, and any command that carries a raw secret token or reaches into a credential store. These are things that should never happen unattended in any repo, so denying them globally costs nothing and prevents the worst outcomes.
- **Ask is the production door.** Pushing to `main`, running a schema migration, pushing a container image. These are legitimate things to do locally and dangerous things to do without thinking, so they stop and wait for a human yes. The mistake here is over-denying: if you deny everything that is dangerous in production, you break the developer's real local workflow, and a broken workflow gets bypassed. Anything that is fine locally but scary in production belongs in ask, not deny.
- **Allow keeps the quiet things quiet.** Building an image, reading files, editing your own config. If these prompted every time, people would stop reading the prompts, which is its own failure mode.

Getting that sort right is most of the work. Over-deny and people route around you. Under-deny and the net has holes. The rule of thumb that kept me honest was to ask, for each action, not "is this dangerous" but "is there any legitimate reason to do this in this repo," and to send the yeses to ask and reserve deny for the true never.

## Three layers, because one is not enough

A Claude Code plugin cannot ship permission rules directly. So the policy travels as a JSON asset plus an installer that merges it into your settings, keeping your own rules and writing a backup. That is layer one.

Layer two is a `PreToolUse` hook that ships inside the plugin and runs the moment the plugin is enabled, before the policy is even installed. It hard-blocks the catastrophic subset on its own. The reason it exists is a specific failure I could picture clearly: someone enables the plugin, never runs the installer, and believes they are protected. The hook makes that person protected anyway. It is a backstop for the gap between "installed the plugin" and "finished the setup."

Layer three is the model's own judgment, which is real but is the layer you trust least, because it is the one that varies.

The point of stacking them is that no single layer has to be perfect. The installed policy is the fuller net; the hook catches the worst even when the net is not up yet; the model's caution catches things neither anticipated. You assume each layer will occasionally fail and you make sure something is behind it.

## A net, not a sandbox

I want to be precise about what this is, because overselling a safety mechanism is how people get hurt by it. The guard matches commands with patterns. Patterns can be worked around by anyone actually trying, and the guard cannot read intent. It is a strong net against accidents and drift. It is not a sandbox that contains an adversary.

I got a small, funny demonstration of exactly how blunt it is while building the very thing you are reading about. I went to open a pull request whose description quoted the guardrail policy, and my own guard blocked the command, because the description contained a literal string it recognizes as dangerous. It could not tell that the string was prose about a rule rather than an instance of the rule. That is the tradeoff in one incident: a substring guard cannot distinguish a description of a forbidden action from the action itself, and it will occasionally stop you doing something harmless for the same reason it stops something harmful. I would rather it err that direction, and I write the parts of the methodology that depend on it accordingly, as "this makes accidents much less likely," never "this makes bad outcomes impossible."

## Why it ships centrally

The deeper reason the floor is a committed, installable plugin and not a paragraph of advice is the team question underneath this whole write-up. A single developer can rely on their own discipline. A group cannot rely on everyone's, because the weakest configured machine sets the real floor, and discipline does not survive contact with a deadline. Committing the policy means one person's carefulness becomes everyone's baseline, installed the same way on every machine, updated in one place. The floor stops being something each person has to remember and becomes something the setup guarantees. That shift, from remembered to committed, is the whole point.
