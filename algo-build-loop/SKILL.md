---
name: algo-build-loop
description: "Use this skill when the user wants to actually implement (code) a proof-of-concept or first version of an algorithm or ML system from an existing design or implementation plan — especially a plan.md produced by algo-design-loop — in a long agentic coding session where correctness matters more than speed. Runs a milestone loop: research the current APIs/libraries the milestone needs, implement it test-first in small verified increments, commit each logical change separately on a dedicated feature branch, check each milestone with the repo's own judge (e.g. tools/verify) and a fresh-context adversarial reviewer subagent, fix what they find, and repeat. When the repo declares an agent-workflow contract, the branch reaches GitHub only through the repo's open-PR door once the judge says it is ready. Trigger on: 'implement the plan', 'build the PoC', 'start coding this design', 'turn plan.md into code', 'code this up milestone by milestone', 'implement step N of the plan', 'continue building the PoC', '/algo-build-loop <plan> --autonomous', or any request to write a multi-component algorithm/ML codebase from a written plan. Do NOT use it for one-off snippets or small bug fixes, for designing the approach when no plan exists yet (use algo-design-loop first), or for reviewing someone else's existing code (use code-review)."
version: 0.2.0
---

# Algorithm Build Loop

## Why this exists

Implementing a design over a long session goes wrong in predictable ways:
- **The code drifts from the plan** without anyone noticing.
- **Tests pass without proving much**, because the author wrote them for the code, not for the plan's acceptance criteria.
- **"It passes" is a claim, not a fact**: the agent tested its working copy, a stale cache, or a check it quietly loosened.
- **Context runs out** mid-milestone and work is lost or redone.
- **History becomes one giant commit** that nobody can review or bisect.

This skill counters each of these:
- **The repo's judge decides, not you.** When the repo provides one (for example `tools/verify`), its exit code is the only definition of "good". You run it, paste its report, and never summarize a verdict from memory.
- A **fresh-context reviewer** per milestone. It never saw how the code was written, so it isn't primed to agree with it. It reads the diff and runs the judge and tests itself.
- **Tests derived from the plan**, written before or with the code.
- **State kept on disk** in a build log, so a compacted or resumed session can pick up where it left off.
- **Small, logical commits on a feature branch**, so every step can be reviewed and reverted on its own.
- **A PR only when the change is ready**, opened through the repo's door, with a description built from the judge's report.

The loop per milestone: research → implement + verify + commit (repeat in small steps) → judge + fresh-reviewer critique → fix → re-review, until only nitpicks remain. At the end: judge the branch, and open the PR only if it's ready.

## Step 0 — Set up

Do these before writing any code.

1. **Read the repo's contract.** Look for an "Agent workflow" section in `AGENTS.md` (or `CLAUDE.md`). It names the commands this skill uses:

   | Key | Used for | Example |
   |---|---|---|
   | `verify-fast` | every increment | `tools/verify --fast` |
   | `verify` | every milestone head, and before any PR | `tools/verify --base origin/master` |
   | `verify-deep` | optional flake hunt before the PR | `tools/verify --deep --base origin/master` |
   | `design-dir` | where the plan, logs and PR summary live | `design/<slug>/` |
   | `open-pr` | the only way to push or open a PR | `tools/agent/open_pr.sh <slug>` |
   | `pr-body` | the PR description | `tools/pr_body <slug>` |

   Also read the repo's product promises (`NORTH_STAR.md` or equivalent). They're hard constraints for the build and for the reviewer. With no contract, fall back to the plan's or the repo's build and test commands, keep logs next to the plan in `<task>-design/`, and ask the user before any push or PR.

2. **Decide the mode.**
   - **Interactive** (default): you may ask the user questions.
   - **Autonomous**: the prompt contains `--autonomous`, or the session was started by the repo's `start-build` hand-off. Never ask questions. When you'd need a decision (a design-level deviation, a cap reached, a hard NEEDS_HUMAN), write it into the build log's "Blockers" and into `design-dir/summary.md`'s "Not done", then stop.

3. **Find the spec.** Look for the plan, in `design-dir/plan.md` or `<task>-design/plan.md` from algo-design-loop. If there is no written plan and the task has real design choices, stop and suggest running algo-design-loop first. Code built against an unvetted design will have to be rebuilt. In interactive mode, if the user wants to proceed anyway, write a short plan with them first (goal, components, acceptance checks) and save it, because the reviewer needs something to check against.

4. **Git preflight.**
   - Confirm this is a git repository. If it isn't, ask before running `git init`.
   - Run `git status`. If the working tree has uncommitted changes you didn't make, ask the user what to do with them (in autonomous mode: stop and report). Don't stash, commit or discard their work on your own.
   - Find the base branch (usually `main` or `master`). Work on `feat/<task-slug>`, created from it or already created by the hand-off. Repos with a door often only let `feat/*` branches through.
   - **All commits go on the feature branch. Never commit to the base branch.**
   - **Never `git push`, `gh pr create`, `gh pr ready`, `gh pr edit` or `gh pr merge` directly.** In a repo with `open-pr`, that door is the only route to GitHub, and only in Step 4. Without one, pushing and opening a PR happen only when the user asks. Nobody but the user merges.

5. **Split the plan into milestones.** Each milestone is a vertical slice that can be verified on its own, usually 1–4 plan steps. Give each one:
   - the plan steps it covers;
   - **acceptance checks** taken from the plan's success criteria, step descriptions and "Verification" section. These are what the reviewer will verify, so make each one concrete: a test, a command, or an observable result.

   Order the milestones so the build skeleton and the pieces with the highest risk or least review come first. For a plan from algo-design-loop, the "Known Risks" section says where that is. A plan step listed under "Guardrail impact" changes the judge itself. The judge can't vouch for such a change, so it will come out as a hard NEEDS_HUMAN. Put it in its own milestone at the end, or leave it for a human, and say so in the build log.

6. **Create the build log** at `design-dir/build-log.md` (or next to the plan) from `assets/build-log-template.md`. Keep review rounds in `review-log.md` next to it, using `assets/review-log-template.md`. Commit both on the feature branch as you go (`docs(design): ...`).
   - The build log is the session's memory. Update its "Current state" section before every long-running command and at every milestone boundary. After a context compaction or in a new session, **read it first** and continue from "Next action". A repo's SessionStart hook may print it for you.

7. **Get a green baseline.** Run `verify-fast` (or the build and test commands) on the unchanged branch, and record the result in the build log. If the project doesn't exist yet, the first milestone is the skeleton that makes these commands pass.

Tell the user in one or two lines where the branch and build log are, and which milestone you're starting with (in autonomous mode, write it into the build log instead).

## Step 1 — Research the milestone (before coding it)

Your memory of library APIs goes stale; the plan's named libraries and versions may not match what's installed or current.

For each milestone:
- **Check the libraries it touches** against current docs, e.g. solver APIs, gRPC/protobuf rules, the ML framework. Use web search or the docs, not memory.
- **Check the pinned versions** in the repo's lock files.
- **When unsure, write a 5-line throwaway spike** to confirm an API behaves as the plan assumes. Delete it afterwards; don't commit it.
- **Record** anything non-obvious in the build log under "Research notes": a signature that differs from the plan, a version constraint, a gotcha.

Keep it proportional. A milestone that only uses the standard library doesn't need research.

## Step 2 — Implement in small, verified, committed increments

Work in increments of one logical change each. For each one:

1. **Write or extend the test first** when the behavior is specified by the plan.
   - Encode the plan's acceptance checks as tests: property tests for mathematical guarantees, contract tests for interfaces, small deterministic fixtures for pipelines, brute-force comparisons on small inputs for optimizers.
   - The test must be able to fail. A test that passes against a stub proves nothing. When you add tests for a bug or a guardrail, run them once against the old code and see them fail.
2. **Implement** the change, and update the docs page the repo's conventions tie to that code **in the same commit** (the judge may check this).
3. **Verify** with `verify-fast` (or the relevant tests) before each commit. Run it after adding or moving files too, not only after edits: new files can fall outside a coverage or lint set. For slow steps, run in the background and update the build log's "Current state" first.
4. **Commit** once the increment passes. Follow `references/commit-guidelines.md`. The short version:
   - One concern per commit, with the tests and docs next to the code they cover.
   - Mechanical changes (formatting, renames, dependency or lock updates, generated code) go in their own commits.
   - Stage explicit paths (`git add <paths>`), not `git add -A`, so stray files don't slip in. Commit only what you tested: a formatter run after the tests can leave the committed file different from the one that passed.
   - Subject: `type(scope): imperative summary`, at most 72 characters. The body says what changed and **why**, and names the plan step.
   - Every commit should build and pass tests, so the history can be bisected.
   - If the conversation provides commit attribution lines, end each message with them.

**Never make it green by weakening the judge.** Don't pass `--no-verify`, don't bypass hooks, don't retry a failing gate until a flake passes, and don't edit the repo's guardrail files (the judge, lint and test configuration, hooks, CI workflows, agent settings) to get a pass. Repos with a judge flag every such edit, and many deny it outright. If a guardrail looks wrong, record it as a finding in the build log and the PR summary, and leave the change to a human.

**Plan deviations.** Sometimes the plan turns out to be wrong or incomplete once you're in the code: an API doesn't exist, a bound is infeasible, a step is underspecified.
- **Small local fix** (a parameter, a library swap with the same behavior): make it and record it in the build log's "Plan deviations" with one line of reasoning.
- **Design-level change** (different algorithm, changed guarantee, changed interface contract): stop. In interactive mode, ask the user and offer to re-run algo-design-loop on that part of the plan. In autonomous mode, record it under "Blockers" and stop. Silently re-designing mid-implementation is exactly the drift this skill exists to prevent.

## Step 3 — Milestone check: the judge, then a fresh reviewer

Once all of a milestone's acceptance checks are implemented and committed:

1. **Run the judge at the milestone head**: `verify` (the gate) on a clean tree. Paste its verdict and the report path into the build log. FAIL or ERROR: fix before reviewing. A NEEDS_HUMAN that the milestone didn't intend (for example, a test body changed): fix it or justify it in the build log.

2. **Spawn a fresh reviewer** with the Agent tool: `subagent_type: "general-purpose"`, not a fork, so it doesn't inherit your reasoning.
   - Prefer `isolation: "worktree"`, so the reviewer can build and run tests without touching your working tree.
   - Its prompt must be self-contained: include the milestone's plan excerpt and acceptance checks **pasted in full**, the repo's promises, the repo path and git refs, and the judge's verdict you got.

Use this prompt shape, filled in each round:

~~~~
You are an adversarial code reviewer. You have no context beyond what's below — that's intentional; review this cold, on its own merits. Do not commit, push, or modify tracked files in REPO; you may build and run tests. If you need scratch branches or commits, make them only in a `git clone --no-hardlinks` under /tmp (use `set -e` and check your cwd before every git write), and delete them when you're done.

REPO: {{absolute repo path}}
CHANGES UNDER REVIEW: `git diff {{milestone_base_sha}}..{{head_sha}}` and `git log {{milestone_base_sha}}..{{head_sha}}`
BUILD / TEST / JUDGE COMMANDS: {{verify-fast, verify, and the build/test commands}}
THE AUTHOR'S JUDGE RESULT AT {{head_sha}}: {{verdict, e.g. "PASS" or "NEEDS_HUMAN (soft): ..."}}
PRODUCT PROMISES THAT MUST HOLD: {{pasted from NORTH_STAR.md or equivalent}}

PLAN EXCERPT THIS MILESTONE IMPLEMENTS:
{{pasted plan steps}}

ACCEPTANCE CHECKS:
{{numbered list}}

Your job is to find real flaws, not to be agreeable. Run the judge, the build and the tests yourself at {{head_sha}}; don't trust claims. If your judge verdict differs from the author's, report it as a blocker (a flake, or an environment leak). Check:
- Does each acceptance check have a test that would fail if the behavior were wrong? (Look for vacuous tests: asserting on mocks, tolerances so loose anything passes, fixtures that never hit the branch in question.)
- Did the diff weaken any test, check or guardrail, or get around one (skips, deleted or moved asserts, loosened tolerances, changed test or CI configuration)?
- Correctness: off-by-ones, wrong formulas vs the plan, unhandled empty/degenerate inputs, numeric edge cases, ordering/nondeterminism, resource leaks, any break of the product promises.
- Plan fidelity: anything implemented differently from the plan without a recorded reason.
- Commit hygiene: commits that mix unrelated concerns, commits that don't build on their own, missing docs updates, generated or secret files committed.
- Current practice: misuse of a library API, deprecated calls — verify with docs/web search if unsure.

Rate each finding with the rubric below (round up when ambiguous) and report: severity, file:line or commit, what's wrong, a concrete failing scenario, and the fix you'd make.
{{contents of references/review-rubric.md}}

End with exactly:
```verdict
blocker: <count>
major: <count>
minor: <count>
nit: <count>
recommendation: <SHIP if blocker=0 and major=0, else ITERATE>
```
~~~~

Then:
- **Parse the verdict block.** It's the stop condition; don't decide "good enough" by feel.
- **ITERATE**: fix every blocker and major finding, each fix as its own commit that says which finding it fixes (e.g. `fix(assembly): enforce creator slack in fallback path` with "Review finding (M2 round 1, major)" in the body). Separate fix commits keep the review trail visible.
  - You may decline a finding you believe is wrong. Say so in the review log with your reasoning.
  - Log the round, run the judge again, then re-review with another fresh subagent against the updated head.
- **SHIP**: apply cheap minor/nit fixes as separate commits, or note them as deliberately not applied. Log the round, tick the milestone in the build log, and continue with the next milestone.
- **Cap: 3 review rounds per milestone.** If round 3 still has blockers or majors, stop and hand the open findings to the user (autonomous: record them under "Blockers"). Ask whether to keep going, re-scope the milestone, or revisit the design. Don't open a PR over open blockers.

Track milestone and round counts with the task-tracking tool; they're easy to lose across many subagent spawns.

## Step 4 — Ready → PR (through the door)

When every milestone is SHIP:

1. **Write the PR prose** in `design-dir/summary.md` with three sections, `## Summary`, `## Why` and `## Not done`, and commit it. Everything else in the description (verdict, commits, review rounds, deviations) comes from tools.
2. **Run the judge on the branch head** with `verify` (optionally `verify-deep` first), and read the verdict and, for NEEDS_HUMAN, its kind (soft or hard) from the report.
3. **Act on the verdict:**

   | Verdict | Action |
   |---|---|
   | `PASS` | Run `open-pr`. It pushes the branch and opens a ready PR, or updates the open one. |
   | `NEEDS_HUMAN`, soft | Run `open-pr`. It opens the PR with a `needs-human` label. List the reasons in "Not done". |
   | `NEEDS_HUMAN`, hard | **No PR.** The change touches what the judge can't vouch for (usually guardrail files). Tell the user the branch is ready for a human to review and push themselves. |
   | `FAIL` / `ERROR` | **No PR.** Go back to Step 2 and fix it. It counts toward the milestone's review cap. |

   Without an `open-pr` door, tell the user the verdict and offer to push and open a PR, in one line. Only do it if they say yes.

   **If the gate fails only on commit messages** (for example a subject over the length limit) and nothing is pushed yet, reword those commits with a scripted, non-interactive message rewrite (`git filter-branch --msg-filter` over `<base>..HEAD`, messages only). Confirm every tree is unchanged, then remap any hashes the build and review logs cite. Never rewrite anything already pushed.
4. **After the PR opens, watch CI.** Run `gh pr checks <pr> --watch` for the pushed commit.
   - If CI agrees with the local verdict, you're done.
   - If CI is red while the local verdict was PASS, that's a blocker finding: an environment leak or a flake. Reproduce it locally from the report's reproduce line, fix it as a `fix(...)` commit, and run `open-pr` again, which updates the PR. At most 3 attempts; then stop and report.

   A repo's gatekeeper may turn a PR that isn't ready back into a draft. Never mark it ready yourself: `open-pr` does that, and only on a ready verdict.

## Step 5 — Present the changes

When done, when stopping at a cap, or whenever the user asks "what changed?":

1. **Collect the real data.** Run `scripts/collect_changes.sh <base-branch>` from the repo. It prints the branch, commits with bodies and per-commit diffstats, overall diffstat, and a warning if the tree is dirty. Build your explanation from this output and the build and review logs, not from memory.
2. **The PR description is the main deliverable** when a PR was opened. It already carries the judge's report, the commit table, the review rounds and the deviations. If the user wants more, or there's no PR, build an HTML artifact (load the `artifact-design` skill first). Content, in order:
   - a summary mapped to plan steps;
   - branch facts;
   - a commit walkthrough grouped by milestone, with review fixes marked;
   - the verification evidence, meaning the judge's verdicts and the review verdicts per round;
   - deviations and declined findings;
   - open items;
   - how to build and run the result.
3. **Tell the user**, in 3–5 sentences:
   - what was built, the branch name and commit count;
   - the judge's final verdict, and the PR link or why there's no PR;
   - the most significant bug the reviewers or the judge caught, which is usually the best evidence the loop was worth it.

   Say plainly if anything is failing, NEEDS_HUMAN, or stopped at a cap.

## Notes on long sessions and judgment

- **Resuming**: read the build log's "Current state", run `git log --oneline <base>..HEAD` and `git status`, run `verify-fast`, then continue. Don't trust your recollection over the log and the repo.
- **Parking work**: if you must set aside uncommitted work (for example, because it belongs in a later PR), use a named `git stash push -u -m "<what and for which PR>"` and note it in the build log. Never discard it.
- **Background work**: start long builds and jobs in the background, and record in the build log what you're waiting on.
- **Your own guardrails will stop you, and that's correct.** If a repo hook or permission rule blocks a command, don't look for another spelling of it. Use the intended path (for example `open-pr`), or ask the user to run it.
- **Cost**: each review round is a real subagent that builds and runs tests. If round 1 is SHIP-eligible, move on; don't add rounds for appearance. Conversely, don't talk a major finding down to a nit to finish a milestone. The rubric exists so that decision isn't made by whoever wants to be done.
- **Honesty**: report failing checks, NEEDS_HUMAN findings, skipped steps and capped milestones as they are. A description that looks green but isn't is worse than none.
