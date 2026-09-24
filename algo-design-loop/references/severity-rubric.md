# Severity rubric — worked examples

The four tiers exist to make "keep iterating vs. ship" a checkable decision instead of a judgment call that drifts toward whichever answer is more convenient in the moment. When a finding is genuinely ambiguous between two tiers, round it up (treat it as the more severe tier) — the cost of one extra review round is small; the cost of shipping a plan with an unaddressed major gap is not.

## blocker
The plan will not work as described, or it violates a constraint the user stated as hard.

- "Step 3 assumes user embeddings are precomputed nightly, but Step 0 says the product needs sub-second personalization for first-session users who have no embedding yet — this breaks for exactly the users the product cares most about."
- "The candidate-generation stage retrieves from a single index sharded by user region, but the ranking stage in Step 5 needs cross-region candidates for the stated 'trending anywhere' feature — these two steps are mutually incompatible as written."
- "The plan proposes computing full pairwise similarity between all videos for ranking. At the stated scale (10M+ videos), this is computationally infeasible regardless of hardware — not a performance nit, a wrong algorithm."

## major
The plan works, but is meaningfully wrong, incomplete, or risky without addressing this. Implementing as-is would produce a system with a real, known problem.

- "No cold-start strategy for new videos — they'll never accumulate engagement signal to enter the ranking pool. This needs an explicit exploration mechanism (e.g. exploration bucket, content-based fallback), not just 'the model will learn it eventually.'"
- "The plan optimizes purely for watch-time, which is a known engagement-metric trap (rewards rage-bait and autoplay-lock-in over genuine satisfaction) — current production systems combine this with an explicit negative-feedback or satisfaction signal. This should at least be a stated tradeoff, not an omission."
- "No mention of how duplicate or near-duplicate content is deduplicated before ranking — at scale this is a near-certain problem, not a hypothetical edge case."

## minor
A real improvement. The plan would work without it, but would be better with it.

- "Consider logging exposure (not just engagement) so the eventual training data isn't survivorship-biased toward what was already shown."
- "The plan doesn't specify a re-ranking diversity mechanism — worth adding to avoid single-topic feedback loops, but not something that breaks the core approach."
- "A/B test plan isn't specified — worth adding before rollout, doesn't change the design itself."

## nit
Cosmetic, phrasing, ordering, redundancy, or "could also mention X for completeness." Would not change anyone's decision to implement the plan as written.

- "Step 4 and Step 6 both mention normalizing engagement scores — could be consolidated into one step."
- "'Leverage' in Step 2 could just be 'use.'"
- "Might be worth a one-line mention of Netflix's original collaborative-filtering approach for historical context, though it's not load-bearing for the recommendation."

## Calibration checks

Ask, for any finding sitting on a tier boundary:

- **major vs. minor**: if this were left unaddressed and the system shipped, would a domain expert reviewing the live system call it a real problem, or a nice-to-have? Real problem -> major.
- **blocker vs. major**: does this findings say the plan *cannot* work as written (a contradiction, an infeasible computation, a violated hard constraint), or that it *works but shouldn't ship like this*? Cannot work -> blocker.
- **minor vs. nit**: would fixing this change any observable behavior of the resulting system? If yes, it's at least minor — nits are behavior-invariant.
