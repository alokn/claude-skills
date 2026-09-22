---
id: au-startup-idea-and-business-plan-evaluation
title: Do not use jev to evaluate startup ideas or business plans
verdict: weak
domain: product
decision_shapes: [scoring, classification]
primitives: [score, noul]
evidence_level: community-report
sources:
  - https://github.com/monteduro/killmyidea  (startup-idea evaluation with jev; no ground truth, no accuracy, no outcome data published)
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (probabilities are features; a supervised model trained on ground-truth outcomes produces the number)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1, literal reading of a vague predicate; failure mode 9, generation)
  - https://docs.typesafe.ai/confidence.md  ("Jev guarantees the shape of its answers, not that every decision is correct")
related: [au-predict-outcome-instead-of-features, au-decisions-that-need-an-explanation, au-show-score-as-a-number-to-users, au-exact-grade-prediction-high-stakes, uc-sales-marketing-icp-fit-scoring]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score startup ideas?" Also: "can jev tell me if my business plan
is any good?", "can we rank inbound pitches for the investment committee?", "will this idea work?"

## Verdict

**Weak**, for three reasons that stack. There is **no ground truth**: "is this a good idea" has no
label anyone can collect at the moment the question is asked, so there is nothing to calibrate
against, nothing to threshold on, and no way to tell a useful score from a confident one. The
advice is **high-stakes and personal** — people quit jobs and raise money on it — while the model
"guarantees the shape of its answers, not that every decision is correct". And what people
actually want back is **generation**: the reasoning, the market analysis, the critique. Jev does
not write prose (failure mode 9), so a number arrives with no argument attached, which is the
worst possible form for advice a human must weigh. The one public implementation,
`monteduro/killmyidea`, publishes no accuracy, no outcome data and no validation of any kind.

**Separate proposal: conditional.** Narrow, checkable *features* of a written plan are a fair
question — does it name a specific customer, does it state a price, does it describe a
distribution channel, does it claim a market size without a source. Those are single-hop reads
with writable criteria, and they make a completeness checklist, not a verdict. Call it a
checklist and never a score.

## What jev would get wrong

"Is this a good idea" is failure mode 1 in its purest form: a vague predicate that a literal
reader will interpret differently from you, every run, with no criteria text that can pin it down
— because nobody can write the criteria. It also invites a *prediction* of an outcome that is not
present in the state: whether a business succeeds depends on execution, timing, capital and
competition, none of which is in a paragraph of text. That is the same error as
`au-predict-outcome-instead-of-features`.

The failure is also socially expensive: a calibrated-looking 0.31 attached to someone's idea reads
as a judgement, and a Score shown to a user as a number is `au-show-score-as-a-number-to-users`.

## What stays in code

Everything with an answer. Market sizes, funding history, competitor counts and comparables are
lookups against real sources, not judgements; completeness against your template is a checklist.
If you later have outcome data, that is supervised learning and the autoresearch cookbook's
pattern applies: jev supplies features, a fitted model supplies the number.

## Numbers

**None.** No accuracy, agreement, calibration or outcome figure exists for idea or plan
evaluation, from TypeSafe or from any independent source; `monteduro/killmyidea` publishes none.
Cost, if you build the checklist version: a 4,000-character plan plus a dozen questions is roughly
1,500 input tokens, about **$0.000063 per plan** at $0.042 per million input tokens with output
free. The cost was never the obstacle.

## When the verdict flips

- To **conditional**, for a completeness or eligibility checklist over a written application —
  accelerator screening where the criteria are published and a human decides.
- To **good**, only with real outcome labels and a fitted model: score deciles validated against
  what actually happened to past cohorts, with jev as the featuriser.
- Stays **weak** for anything presented to the founder as a verdict, however it is framed.

## Alternatives considered

- **A published rubric a human applies.** The honest version; slower and accountable.
- **Frontier LLM.** Writes the critique people actually want, and is wrong in legible prose.
- **Retrieval over comparables.** Answers "who else tried this and what happened", with evidence.
- **Fitted model on cohort outcomes.** The only form with ground truth; needs years of data.
- **Investor or operator judgement.** Unreplaced.

## Sources

- https://github.com/monteduro/killmyidea — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
