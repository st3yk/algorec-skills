# Commit guidelines

The goal is a history that another engineer can review one commit at a time, bisect, and revert piece by piece.

## Size and scope
- **One logical concern per commit.** "Add dimension registry loader", not "registry, retrieval and some fixes".
- **Tests go in the same commit as the code they test.** A reviewer should see behavior and proof together.
- **Separate mechanical changes** into their own commits: formatting, renames or moves, dependency and lock-file updates, generated code (e.g. protobuf stubs, if checked in). Mixing them into logic commits hides the real diff.
- **Every commit builds and passes tests.** If a change needs two steps, order them so each one is green (e.g. add the new function, switch callers to it, remove the old one).
- **Review fixes are separate commits** (`fix(scope): …`) that reference the finding. They are not folded into earlier commits.

## Staging
- Stage explicit paths: `git add path/to/file …`. Check `git status` and `git diff --cached --stat` before committing.
- Never commit secrets, datasets, model artifacts, large binaries, or local environment files. Add a `.gitignore` entry instead.

## Message format
```
<type>(<scope>): <imperative summary, ≤ 72 chars>

<Why this change exists and what it does, wrapped at 72. Name the plan
step (e.g. "Plan step 17: stage-0 slack minimization"). Mention any
deviation from the plan and where it is recorded.>

<attribution lines, if the conversation provides them>
```
- Types: `feat`, `fix`, `test`, `refactor`, `build`, `chore`, `docs`, `perf`.
- Examples:
  - `build: add Bazel module with rules_python and protobuf`
  - `feat(assembly): solve per-page ILP with stage-0 slack minimization`
  - `test(assembly): property test that the bound tightens monotonically in |s|`
  - `fix(retrieval): exclude in-flight video IDs from every source`

## Checked, not assumed
- Commit only what you tested. A formatter or fix-up run after the tests can leave the committed file different from the one that passed; re-run the checks, or let the repo's gate judge the commit itself.
- If the repo's conventions tie code to a docs page, change the page in the same commit.

## Branch
- Work on `feat/<task-slug>` created from the base branch. Never commit to the base branch.
- Never push, open, ready, edit or merge a PR directly. If the repo declares an `open-pr` door, it is the only route to GitHub, and only once the judge says the branch is ready. Otherwise push and open a PR only when the user asks. Only the user merges.
- Reword commit messages only on unpushed commits, with a scripted, messages-only rewrite, and remap any hashes the logs cite.
