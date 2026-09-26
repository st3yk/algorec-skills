# algorec-skills

Claude Code skills used to develop [algorec](https://github.com/st3yk/algorec). Each subdirectory is a skill (`SKILL.md` + any bundled `references/`, `assets/`, `scripts/`).

## Skills

- **algo-design-loop** — research → plan → adversarial-review loop that produces a vetted implementation plan (`plan.md`) for an algorithm or ML-system design.
- **algo-build-loop** — implements a plan (typically one from algo-design-loop) milestone by milestone: test-first, small commits, and a fresh-context reviewer per milestone.

## Repo contract

Both skills read an "Agent workflow" section in the target repo's `AGENTS.md` (or `CLAUDE.md`) when there is one: `verify-fast`, `verify`, `design-dir`, `start-build`, `open-pr` and `pr-body`. With a contract, the repo's judge (for example `tools/verify`) decides whether a change is good, the design loop hands its plan to an unattended build, and a PR reaches GitHub only through the repo's `open-pr` door once the judge says the change is ready. Without one, the skills fall back to the plan's build and test commands and ask before pushing.

## Installation

Skills here are symlinked into `~/.claude/skills/` so they stay active while their source lives in this repo.
