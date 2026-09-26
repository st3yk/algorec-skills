# Implementation Plan: {{TASK}}

_Status: draft (round 0) — updated as the adversarial review loop progresses._

## Problem Statement

{{One or two paragraphs: what is being built and for whom.}}

## Constraints & Success Criteria

- Scale: {{traffic/data volume, or "prototype / unknown"}}
- Latency / performance budget: {{...}}
- Existing infra / data available: {{...}}
- Team / timeline: {{...}}
- Success looks like: {{metric, demo, or production bar}}

_If any of these are assumptions rather than user-stated facts, mark them "(assumed)" — the adversarial reviewer should be free to challenge them._

## Options Considered

| Option | Summary | Pros | Cons | Verdict |
|---|---|---|---|---|
| {{Option A}} | | | | Rejected — {{why}} |
| {{Option B}} | | | | **Chosen** — {{why}} |
| {{Option C}} | | | | Rejected — {{why}} |

## Chosen Approach

{{2-4 sentences: the approach and the one or two reasons it wins given the constraints above.}}

## Step-by-Step Implementation Plan

1. {{Step}}
2. {{Step}}
3. {{...}}

## Verification

| Step | The check that would fail if this step were wrong | New tests needed |
|---|---|---|
| 1 | {{test / command / observable result}} | {{property test, brute-force comparison, regression test, or "existing: <name>"}} |

## Guardrail impact

{{"None." — or each step that changes the repo's own checks (judge, lint/test config, hooks, CI, agent settings), why it's needed, and "for a human to apply": the repo's judge can't vouch for a change to itself, so these never become agent PRs.}}

## Known Risks / Open Questions

- {{Anything you flagged yourself before the reviewer even sees it.}}

## Deliberately Not Applied

_(Filled in during the review loop — suggestions considered and rejected, with reasoning. Leave empty in the initial draft.)_
