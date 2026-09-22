---
id: au-average-noul-with-choice
title: Do not average a Noul with a Choice, or assume P plus not-P equals 1
verdict: no
domain: ml
decision_shapes: [classification, detection]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 8, Common-sense structural invariants, with both measured tables)
  - https://docs.typesafe.ai/primitives.md  ("Every answer is independent")
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (Choice and Nouls used for different questions on the same shortlist)
related: [au-interpolate-magnitude-from-score, au-chain-questions-in-one-request, au-flat-choice-over-255-options]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ask the same thing as a Noul and as a Choice and average them for robustness?"
Also "we compute P(not refund) as 1 minus the refund Noul", "reuse our 0.7 Noul threshold on the Choice
confidence", "ensemble the two phrasings".

## Verdict

**No.** The jaggedness page's eighth failure mode exists for this exact design, and it publishes the
numbers. Jev "is extremely consistent, meaning you should expect quantitatively similar outputs for
semantically similar inputs. However there are many structural invariants one might imagine to hold that
simply aren't guaranteed by the model." Averaging across primitives, or across a question and its
negation, assumes invariants the model does not provide.

## What jev would get wrong

Two measured cases from the docs. On the ticket "I'm not happy with the fit. What are my options here?",
"Is the customer asking for a refund?" returns `noul` 0.22 as a Noul, while the same question as a yes/no
Choice returns `yes` 0.01, `no` 0.99, `confidence` 0.97. The page's own reading: "The comparable numbers
are `noul` and `probabilities["yes"]`, and it is not obvious how to interpret either the Choice output
and confidence for the Noul question or vice versa." On "I was charged twice for the same order. Can
someone look into this?", the Noul `refund` returns 0.72 and the Noul `not_refund` returns 0.47 — a sum of
1.19. "There are many reasons that `P(noul)` and `1 - P(not noul)` may not be directly comparable."

Averaging 0.22 with 0.01 describes neither question. Deriving P(not-refund) as 1 − 0.72 = 0.28 when the
model itself says 0.47 substitutes an assumption for a measurement.

## What stays in code

The decision logic, on one number per decision. The page's instruction is direct: "don't rely on expected
structural invariance, and word questions to mean directly what you want. Don't carry a threshold tuned
on a Noul over to a Choice, and don't hold the model to arithmetic identities between separate questions."
So: ask each decision once, in the direction you will threshold; tune that threshold on that question
type; and if you need the negation, ask it and use the answer you got rather than one you computed.

Combining answers is fine — it is the recommended pattern — as long as you combine *different* judgements
rather than two phrasings of one. A weighted sum of answers-the-request, citations-supported, and
does-not-contradict is composite scoring. An average of a Noul and a Choice asking the same thing is not.

## Numbers

From the jaggedness page, jev-1.13, verbatim: Noul 0.22 against Choice `yes` 0.01 / `no` 0.99 /
confidence 0.97; and `refund` 0.72 + `not_refund` 0.47 = 1.19. Asking a redundant second phrasing costs
only the extra question's tokens — a few thousandths of a cent at $0.042 per million input tokens with
output free (https://docs.typesafe.ai/models.md) — so the cost of this mistake is wrong answers, not money.

## When the verdict flips

The averaging never flips — **no rewrite exists**, because the identity you would be averaging over is not
a property of the model. What flips to **good** is using both primitives for *different* questions on the
same state, which the docs endorse: "A Choice over options and one Noul per option answer different
questions: the Choice is relative, settling *which* option, while each Noul is absolute and can be low for
all of them." The skill-suggestion cookbook does exactly this — the Choice picks a skill, the Nouls decide
whether to suggest one at all. Two thresholds, two purposes, no arithmetic between them.

## Alternatives considered

- **Regex / deterministic**: owns the combination logic across distinct questions.
- **Small LLM / frontier LLM**: ensembling phrasings is a common LLM trick; it does not transfer here.
- **Fine-tuned classifier**: if you want a single calibrated posterior over a partition, train one — it
  will respect the sum-to-one constraint by construction.
- **Embeddings**: no role.
- **Human**: adjudicates the band where your single chosen question is near 0.5.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
