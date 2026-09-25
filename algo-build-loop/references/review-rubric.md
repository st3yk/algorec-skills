# Severity rubric for code review

When a finding is ambiguous between two tiers, choose the more severe one. An extra review round is cheap; shipping a real bug is not.

## blocker
The code doesn't do what the milestone claims, or it breaks something outright.
- The build fails, or tests fail on the reviewed head.
- A core formula or algorithm differs from the plan in a way that produces wrong results on the main path (e.g. a bound applied with the wrong sign, or a constraint that is never added to the solver).
- It violates a hard constraint the plan states (e.g. an interface contract field is missing or means something else).
- Data loss, a committed secret, or a commit to the base branch.

## major
The code works on the happy path, but a domain expert would call this a real problem.
- An acceptance check has no test, or only a vacuous one (asserts on a mock, a tolerance so wide that anything passes, a fixture that never reaches the branch).
- A correctness bug on an edge case the plan explicitly mentions (empty pool, cold start, infeasible constraints, ties).
- An unrecorded deviation from the plan.
- Nondeterminism that makes results or tests flaky.
- A commit that doesn't build on its own, or that mixes unrelated concerns so it can't be reverted on its own.

## minor
A real improvement that changes observable behavior, but isn't blocking.
- Missing validation on an input outside the plan's stated range.
- A clearer error message for a failure that is already handled.
- A test that would catch a regression the current tests would miss.

## nit
Doesn't change behavior: naming, comments, formatting, ordering, a commit-message wording.

## Calibration checks
- **blocker vs. major**: does the code produce wrong results, or fail, on the main path? Then blocker. Does it work but carry a real gap? Then major.
- **major vs. minor**: would a reviewer block the PR over it? Then major.
- **minor vs. nit**: would fixing it change any behavior or test outcome? Then minor.
