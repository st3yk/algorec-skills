---
name: algo-build-loop
description: "Use this skill when the user wants to actually implement (code) a proof-of-concept or first version of an algorithm or ML system from an existing design or implementation plan — especially a plan.md produced by algo-design-loop — in a long agentic coding session where correctness matters more than speed. Runs a milestone loop: research the current APIs/libraries the milestone needs, implement it test-first in small verified increments, commit each logical change separately on a dedicated feature branch, send the milestone diff to a fresh-context adversarial reviewer subagent that runs the tests itself and hunts for bugs and plan deviations, fix what it finds, and repeat. Finishes by publishing an artifact that explains the branch's changes commit by commit. Trigger on: 'implement the plan', 'build the PoC', 'start coding this design', 'turn plan.md into code', 'code this up milestone by milestone', 'implement step N of the plan', 'continue building the PoC', or any request to write a multi-component algorithm/ML codebase from a written plan. Do NOT use it for one-off snippets or small bug fixes, for designing the approach when no plan exists yet (use algo-design-loop first), or for reviewing someone else's existing code (use code-review)."
version: 0.1.0
---

# Algorithm Build Loop

## Why this exists

Implementing a design over a long session goes wrong in predictable ways:
- **The code drifts from the plan** without anyone noticing.
- **Tests pass without proving much**, because the author wrote them for the code, not for the plan's acceptance criteria.
- **Context runs out** mid-milestone and work is lost or redone.
- **History becomes one giant commit** that nobody can review or bisect.

This skill counters each of these:
- A **fresh-context reviewer** per milestone. It never saw how the code was written, so it isn't primed to agree with it. It reads the diff and runs the tests itself. This is the same independence mechanism as algo-design-loop, applied to code.
- **Tests derived from the plan**, written before or with the code.
- **State kept on disk** in a build log, so a compacted or resumed session can pick up where it left off.
- **Small, logical commits on a feature branch**, so every step can be reviewed and reverted on its own.
- **A final artifact** explaining the changes, so the user sees what was built without reading the whole diff.

The loop per milestone: research → implement + verify + commit (repeat in small steps) → fresh-reviewer critique → fix → re-review, until only nitpicks remain. At the end of the session: publish the change artifact.

## Step 0 — Set up

Do these before writing any code.

1. **Find the spec.** Look for the plan, typically `<task>-design/plan.md` from algo-design-loop. If there is no written plan and the task has real design choices, stop and suggest running algo-design-loop first. Code built against an unvetted design will have to be rebuilt. If the user wants to proceed anyway, write a short plan with them first (goal, components, acceptance checks) and save it, because the reviewer needs something to check against.

2. **Git preflight.**
   - Confirm this is a git repository. If it isn't, ask before running `git init`.
   - Run `git status`. If the working tree has uncommitted changes you didn't make, ask the user what to do with them. Don't stash, commit or discard their work on your own.
   - Find the base branch (usually `main` or `master`). Create a feature branch from it: `feat/<task-slug>`, or `feat/<task-slug>-<milestone>` if the user wants a branch per milestone.
   - **All commits go on the feature branch. Never commit to the base branch.** Only push, open a PR or merge when the user asks: these are outward-facing actions.

3. **Split the plan into milestones.** Each milestone is a vertical slice that can be verified on its own, usually 1–4 plan steps. Give each one:
   - the plan steps it covers;
   - **acceptance checks** taken from the plan's success criteria or step descriptions. These are what the reviewer will verify, so make each one concrete: a test, a command, or an observable result.

   Order the milestones so the build skeleton and the pieces with the highest risk or least review come first. For a plan from algo-design-loop, the "Review Status" / "Known Risks" sections say where that is.

4. **Create the build log** at `<task>-design/build-log.md` (next to the plan) from `assets/build-log-template.md`. Add `review-log.md` entries there as well, or in a separate `build-review-log.md` using `assets/review-log-template.md`.
   - The build log is the session's memory. Update its "Current state" section before every long-running command and at every milestone boundary. After a context compaction or in a new session, **read it first** and continue from "Next action".

5. **Get a green baseline.** Run the project's build and test commands, taken from the plan (e.g. `bazel build //... && bazel test //...`) or from the repo, and record them in the build log. If the project doesn't exist yet, the first milestone is the skeleton that makes these commands pass.

Tell the user in one or two lines where the branch and build log are, and which milestone you're starting with.

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
   - Encode the plan's acceptance checks as tests: property tests for mathematical guarantees, contract tests for interfaces, small deterministic fixtures for pipelines.
   - The test must be able to fail. A test that passes against a stub proves nothing.
2. **Implement** the change.
3. **Verify**: build, run the relevant tests, and run the full suite before each commit if it's fast. For slow steps (full builds, training, data jobs), run in the background and update the build log's "Current state" first.
4. **Commit** once the increment builds and its tests pass. Follow `references/commit-guidelines.md`. The short version:
   - One concern per commit, with the tests next to the code they test.
   - Mechanical changes (formatting, renames, dependency or lock updates, generated code) go in their own commits.
   - Stage explicit paths (`git add <paths>`), not `git add -A`, so stray files don't slip in.
   - The message says what changed and **why**, and names the plan step.
   - Every commit should build and pass tests, so the history can be bisected.
   - If the conversation provides commit attribution lines, end each message with them.

**Plan deviations.** Sometimes the plan turns out to be wrong or incomplete once you're in the code: an API doesn't exist, a bound is infeasible, a step is underspecified.
- **Small local fix** (a parameter, a library swap with the same behavior): make it and record it in the build log's "Plan deviations" with one line of reasoning.
- **Design-level change** (different algorithm, changed guarantee, changed interface contract): stop and ask the user. Offer to re-run algo-design-loop on that part of the plan. Silently re-designing mid-implementation is exactly the drift this skill exists to prevent.

## Step 3 — Adversarial milestone review (fresh subagent)

Once all of a milestone's acceptance checks are implemented and committed, spawn a **fresh** reviewer with the Agent tool: `subagent_type: "general-purpose"`, not a fork, so it doesn't inherit your reasoning.
- Prefer `isolation: "worktree"`, so the reviewer can build and run tests without touching your working tree.
- Its prompt must be self-contained: include the milestone's plan excerpt and acceptance checks **pasted in full**, plus the repo path and git refs so it can read the diff itself.

Use this prompt shape, filled in each round:

~~~~
You are an adversarial code reviewer. You have no context beyond what's below — that's intentional; review this cold, on its own merits. Do not commit, push, or modify tracked files; you may build and run tests.

REPO: {{absolute repo path}}
CHANGES UNDER REVIEW: `git diff {{milestone_base_sha}}..{{head_sha}}` and `git log {{milestone_base_sha}}..{{head_sha}}`
BUILD / TEST COMMANDS: {{commands}}

PLAN EXCERPT THIS MILESTONE IMPLEMENTS:
{{pasted plan steps}}

ACCEPTANCE CHECKS:
{{numbered list}}

Your job is to find real flaws, not to be agreeable. Run the build and tests yourself; don't trust claims. Check:
- Does each acceptance check have a test that would fail if the behavior were wrong? (Look for vacuous tests: asserting on mocks, tolerances so loose anything passes, fixtures that never hit the branch in question.)
- Correctness: off-by-ones, wrong formulas vs the plan, unhandled empty/degenerate inputs, numeric edge cases, ordering/nondeterminism, resource leaks.
- Plan fidelity: anything implemented differently from the plan without a recorded reason.
- Commit hygiene: commits that mix unrelated concerns, commits that don't build on their own, generated or secret files committed.
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
- **ITERATE**: fix every blocker and major finding, each fix as its own commit (e.g. `fix(assembly): enforce creator slack in fallback path`). Rewriting earlier commits isn't possible here (interactive rebase is unavailable), and separate fix commits also keep the review trail visible.
  - You may decline a finding you believe is wrong. Say so in the review log with your reasoning.
  - Log the round, then re-review with another fresh subagent against the updated head.
- **SHIP**: apply cheap minor/nit fixes as separate commits, or note them as deliberately not applied. Log the round, tick the milestone in the build log, and continue with the next milestone.
- **Cap: 3 review rounds per milestone.** Code review rounds are expensive. If round 3 still has blockers or majors, stop and hand the user the open findings. Ask whether to keep going, re-scope the milestone, or revisit the design.

Track milestone and round counts with the task-tracking tool; they're easy to lose across many subagent spawns.

## Step 4 — Present the changes (end of session or on request)

When all milestones are done, when stopping at a cap, or whenever the user asks "what changed?":

1. **Collect the real data.** Run `scripts/collect_changes.sh <base-branch>` from the repo. It prints the branch, commits with bodies and per-commit diffstats, overall diffstat, and a warning if the tree is dirty. Build the explanation from this output and the build/review logs, not from memory: the artifact must match the actual history.
2. **Build the artifact.** Load the `artifact-design` skill first, as the Artifact tool requires, then write an HTML page and publish it with the Artifact tool. Content, in this order:
   - **Summary**: what was built, mapped to plan steps, in 3–5 sentences.
   - **Branch facts**: branch name, base, commit count, overall diffstat, and whether anything is pushed (normally not).
   - **Commit walkthrough**: one entry per commit, in order. Show the hash, subject, *why* it exists, and the files touched. Group entries by milestone, and mark review-fix commits as such.
   - **Verification evidence**: build/test commands and their latest results, and the review verdicts per milestone and round.
   - **Deviations from the plan**, and findings deliberately not applied, each with its reasoning.
   - **Open items / next steps**, including anything left at a review cap.
   - **How to build and run** the result.

   If the Artifact tool is unavailable, write the same page to `<task>-design/changes.html` and give the user the path.
3. **Tell the user**, in the conversation, in 3–5 sentences: what was built, the branch name and commit count, and the most significant bug the reviewers caught. That bug is usually the best evidence the loop was worth it. Link the artifact. Say plainly if tests are failing or a milestone stopped at the cap. Don't push or open a PR unless asked; offer it in one line.

## Notes on long sessions and judgment

- **Resuming**: read the build log's "Current state", run `git log --oneline <base>..HEAD` and `git status`, re-run the tests, then continue. Don't trust your recollection over the log and the repo.
- **Background work**: start long builds and jobs in the background, and record in the build log what you're waiting on.
- **Cost**: each review round is a real subagent that builds and runs tests. If round 1 is SHIP-eligible, move on; don't add rounds for appearance. Conversely, don't talk a major finding down to a nit to finish a milestone. The rubric exists so that decision isn't made by whoever wants to be done.
- **Honesty in the artifact**: report failing tests, skipped checks and capped milestones as they are. A page that looks green but isn't is worse than no page.
