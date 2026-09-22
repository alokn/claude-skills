---
id: au-decisions-that-need-an-explanation
title: Do not use jev where the decision has to come with a reason
verdict: no
domain: legal
decision_shapes: [classification, scoring, verification]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  (System One models do not generate explanations of their reasoning)
  - https://arize.com/blog/typesafe-jev-llm-judge/  (System One models produce "much less directional signal of how to improve")
  - https://docs.typesafe.ai/primitives.md  (decomposition into atomic questions as the substitute for a rationale)
related: [au-generate-ticket-summaries, au-resume-auto-rejection, au-legal-determinations-without-counsel, au-show-score-as-a-number-to-users]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev where we have to tell the customer why?" Also "can jev explain its answer?",
"we need an audit trail for the regulator", "where's the chain of thought?", "how do we debug a wrong
label?".

## Verdict

**No** if a free-text rationale is part of the deliverable. jev returns typed values and probabilities and
nothing else: System One models "do not ... generate explanations of their reasoning", and generation is
jaggedness mode 9, so there is no supported way to ask for one. Arize makes the operational consequence
explicit — System One models produce "much less directional signal of how to improve" — and the same
observation recurs independently across Langfuse, DataCamp and the Home Assistant integration's own
documentation: there is nothing to read that explains why.

## What jev would get wrong

Nothing, and that is the difficulty: a wrong label arrives indistinguishable from a right one, with no
trace to inspect. Debugging degrades into re-running variants of the question, which
`au-single-question-framing-sensitivity` shows is itself unstable, and into staring at a state you cannot
attribute the answer to — failure mode 5 says as much, "a large state makes it harder to tell which part
of the input produced a wrong answer". Do not fill the gap by chaining Choices to spell out a sentence;
the docs say that "will not work well and will be very slow", and the resulting text would be a
post-hoc narration, not the reason.

## What stays in code

The explanation, assembled from the decomposition. This is the substitute and it is a good one: instead of
one opaque verdict, ask the five or six atomic questions a reviewer would ask, and let code render the
answers as the rationale — "flagged because the message requests credentials (0.94) and the sender domain
is unrelated to the brand (0.91); not flagged for attachment type (0.07)". Each clause is a question you
wrote, with a probability, traceable to an evidence field you put in the state. Code also stores the
question set, the criteria text, the pinned model version, the probabilities and the confidence with every
decision, so the record reconstructs what was asked, not just what came back. That record is an audit
trail; the model's internal reasoning was never going to be one.

## Numbers

No published source quantifies explanation quality, because no explanation is produced. Decomposition is
what it costs: extra questions "barely change the response time and cost only the tokens for the extra
questions" (https://docs.typesafe.ai/primitives.md), so six rationale-bearing questions over a
1,200-token state is roughly 1,900 input tokens, about $0.00008 at $0.042 per million input tokens with
output free (https://docs.typesafe.ai/models.md), in one call at roughly 100 ms. Compare a frontier model
asked for a paragraph of reasoning: seconds, and output tokens priced "~5x more expensive than input
tokens" — but the paragraph is a generated justification, not a guarantee of the reasoning either.

## When the verdict flips

It flips to **good** when "explanation" means *evidence*, not prose: a decomposed answer set that a person
can read as a checklist satisfies most review, appeal and audit requirements, and it is more honest than a
generated rationale. It stays **no** where a statute, contract or regulator requires a narrative
justification in natural language, and where a human or a generative model must write it — in that case
jev can still pre-fill the structured findings the writer works from.

## Alternatives considered

- **Regex / deterministic**: the rule *is* the explanation; unbeatable where it fits.
- **Small LLM**: can generate a rationale, cheaply and unreliably.
- **Frontier LLM**: the tool if a written justification is the deliverable; slower, dearer, and its
  rationale is still a reconstruction.
- **Fine-tuned classifier**: same opacity as jev, plus feature attributions (SHAP and similar) that jev
  does not offer.
- **Embeddings**: nearest-neighbour examples make a serviceable "similar to these cases" explanation.
- **Human**: writes the reason, using jev's structured findings as the working notes.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://arize.com/blog/typesafe-jev-llm-judge/ — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
