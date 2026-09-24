---
name: algo-design-loop
description: "Use this skill when the user wants a rigorously vetted implementation plan for an algorithm or ML-system design task, especially when they say they know little about the domain and want to learn while designing, or explicitly ask for a design to be stress-tested, adversarially reviewed, or iterated until solid. Runs a research -> plan -> adversarial-critique loop: research current best practices and viable approaches, draft a step-by-step implementation plan with rationale, send it to a fresh-context reviewer subagent that hunts for flaws (wrong assumptions, missing edge cases, scalability gaps, correctness issues, gaps vs current best practice), apply the fixes, and repeat until only nitpicks remain. Trigger on: 'help me design an algorithm/system for X and I don't know much about it', 'give me an implementation plan for X', 'research the best approach for X', 'stress-test this design', 'adversarially review my plan', 'find flaws in this approach', 'poke holes in this before I build it', 'iterate on this design until it's solid'. Also trigger any time the user is about to commit to a from-scratch algorithm or ML-system design where getting the approach right matters more than getting an answer fast. Do NOT use it for quick single-shot code generation, for reviewing existing production code (use code-review instead), or for tasks with no real design space (the approach is fixed, or there is obviously only one sane option)."
version: 0.1.0
---

# Algorithm Design Loop

## Why this exists

A single pass of "research it, write a plan" is anchored on whatever the researching agent happened to read first, and it can't see its own blind spots — that's what blind spots are. The fix isn't a smarter first pass, it's a **second, independent** pass: a reviewer that never saw how the plan was derived, so it isn't primed to agree with it. That independence is the whole mechanism. If the reviewer runs in the same context window as the author, it inherits the author's framing and will rubber-stamp the author's own assumptions — so the review step below always spawns a **fresh** subagent (not a fork), with no memory of the research or reasoning that produced the plan. It only ever sees the plan itself plus the original problem statement.

The loop is: research and draft (you, in this conversation) -> critique (fresh subagent) -> revise (you) -> critique again (another fresh subagent) -> ... until the critiques stop finding anything but nitpicks.

## Step 0 — Scope the task

Before researching, make sure you actually know what you're designing for. The single biggest failure mode in system design isn't picking the wrong algorithm, it's picking the right algorithm for the wrong constraints (e.g. recommending a two-tower retrieval model with a nightly batch job for someone who actually needs sub-second personalization on day-one users with no click history yet).

Check whether the user's request already answers these; if not, ask (batch it into one AskUserQuestion call rather than trickling questions):
- **Scale**: rough traffic/data volume, or "no idea yet, this is a prototype."
- **Constraints**: latency budget, existing infra/data pipelines, team size/expertise, timeline.
- **Success criteria**: what does "working" mean — a metric, a demo, production-readiness?

If the user explicitly says they don't know and want you to figure it out (as in "I know very little about this"), don't ask them to specify constraints they can't specify — instead state your assumed constraints plainly in the plan's "Constraints" section and flag them as assumptions, so the adversarial reviewer (and the user) can challenge them.

Also settle the output location now: default to a new directory `./<task-slug>-design/` in the current working directory, containing `plan.md` and `review-log.md`. Tell the user where you're writing and let them redirect you.

## Step 1 — Research and draft (main context)

Do this yourself, in this conversation — it benefits from the user's presence and any clarifications from Step 0.

1. Research the problem space: use web search to find how this problem is actually solved in practice, not just textbook theory. For an algorithm/ML design task, that usually means: what do real production systems do (look for engineering blog posts, papers, conference talks from companies operating at the relevant scale), what are the 2-4 genuinely viable approaches, and what are their tradeoffs for *this* user's constraints from Step 0.
2. Pick an approach and justify it against the alternatives — don't just present the option you liked first. A plan that doesn't say "I considered X and rejected it because Y" reads as if no options were considered at all, and the adversarial reviewer will (correctly) treat unexplained choices as unjustified ones.
3. Write the plan to `<task-slug>-design/plan.md` using `assets/plan-template.md` as the starting structure. Keep the implementation plan itself simple and step-by-step, per the user's request — the rationale and options-considered sections can carry the nuance so the step list stays actionable.

## Step 2 — Adversarial review (fresh subagent)

Spawn a fresh subagent (not a fork — it must not inherit your reasoning) with the Agent tool. Give it a fully self-contained prompt: it has none of this conversation's context, so include the original problem statement and constraints from Step 0, plus the full current plan content (read the file and paste it in, don't just reference the path — a fresh agent starting cold benefits from not having to do file discovery for the one document that matters).

Use this prompt shape, filled in with the real content each round:

```
You are an adversarial technical reviewer. You have no context beyond what's below — that's intentional, so review this cold, on its own merits.

PROBLEM & CONSTRAINTS:
{{problem statement and constraints from Step 0}}

CANDIDATE IMPLEMENTATION PLAN (round {{N}}):
{{full current contents of plan.md}}

Your job is to find real flaws, not to be agreeable. For each issue, check:
- Wrong or unstated assumptions (about data, scale, user behavior, infra).
- Missing edge cases (cold start, empty results, adversarial/abusive input, ties, staleness).
- Scalability or latency problems the plan doesn't address.
- Correctness problems: does each step actually achieve what it claims to?
- Gaps versus current best practice: is there a known better approach for this exact constraint set that the plan ignores?
If you're unsure whether something reflects current practice, use web search to check rather than guessing.

Rate every finding's severity using this rubric (full definitions in the reviewer's judgment, but calibrate against these examples):
- blocker: the plan will not work as described, or violates a stated hard constraint.
- major: a significant gap or risk that should be fixed before implementing — the plan works but is meaningfully wrong, incomplete, or risky without this.
- minor: a real improvement, not blocking — the plan would work without it.
- nit: cosmetic, phrasing, ordering, redundancy, "could also mention X."

Report each finding as: severity, the specific part of the plan it targets, what's wrong, and what you'd do instead.

End with exactly this block, filled in truthfully based on what you found above:

​```verdict
blocker: <count>
major: <count>
minor: <count>
nit: <count>
recommendation: <SHIP if blocker=0 and major=0, else ITERATE>
​```
```

See `references/severity-rubric.md` if you or the reviewer want more worked examples of where a finding lands — pass its content along to the reviewer subagent if the plan is in a domain where the line between "major" and "minor" is genuinely fuzzy.

## Step 3 — Apply, log, decide

Read the reviewer's output and parse the `verdict` block — that's the checkable stop condition, not a vibe call:

- **blocker=0 and major=0** (recommendation: SHIP): the substantive review is done. Apply any cheap minor/nit fixes directly (typically worth it — low cost, real quality gain), or if a suggestion conflicts with another design goal, note it in the plan as a deliberately-not-applied tradeoff with one line of reasoning. Don't silently drop feedback either way. Go to Step 4.
- **Otherwise**: apply fixes for every blocker and major finding (and any cheap minor/nit ones along the way). If you disagree with a finding — reviewers are sometimes wrong — you may decline it, but say so explicitly in the log with your reasoning; don't just ignore it. Append this round to `review-log.md` using `assets/review-log-template.md`'s format. Go back to Step 2 with the revised plan (round N+1).

**Safety valve:** cap at 5 rounds. If round 5 still isn't SHIP-eligible, stop anyway, write up the current plan plus the outstanding blocker/major findings, and hand it to the user — tell them the loop hit its cap and ask whether to keep iterating, change the constraints, or ship with known gaps. This is a real possibility for genuinely hard or under-constrained problems, not a bug in the loop.

Track round count with whatever task-tracking is available to you — it's easy to lose count across several subagent spawns in one turn.

## Step 4 — Finalize

Write the finished `plan.md` and `review-log.md`, then tell the user, in the conversation, in 3-5 sentences: what approach was chosen and why, how many rounds it took, and the single most significant thing the adversarial review changed (this is usually the most convincing evidence to the user that the process was worth running, more than the round count itself). Point them at the two files rather than pasting the whole plan into chat.

## Notes on cost and judgment

Each round costs one real subagent spawn plus whatever web research it does — this is not free or instant. Don't pad rounds: if round 1 comes back SHIP-eligible, stop there, don't manufacture a second round for appearances. Conversely, don't rationalize a major finding into "basically a nit" to end the loop early — the rubric exists precisely so that decision isn't left to whoever's motivated to be done.
