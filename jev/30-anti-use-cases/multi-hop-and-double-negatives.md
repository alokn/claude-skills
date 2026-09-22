---
id: au-multi-hop-and-double-negatives
title: Do not ask jev a question that needs several hops of reasoning or a double negative
verdict: no
domain: agents
decision_shapes: [classification, verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 4, Indirection; failure mode 1, Literal reading; failure mode 7)
  - https://docs.typesafe.ai/primitives.md  ("Ask for a judgment a knowledgeable person makes in a second")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (decompose the questions)
related: [au-chain-questions-in-one-request, au-whole-document-in-state, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ask jev whether the customer is not ineligible for the discount their account tier
doesn't exclude?" More realistically: "does the policy that governs the plan this user is on permit the
action they requested", "is there no reason we shouldn't refund", "would a reasonable person conclude
from the thread that the bug is ours".

## Verdict

**No** as a single question; **good** once decomposed. Failure mode 4 says "Instructions carrying double
negatives or complex indirection are answered less reliably. A question about a property of a property
or something that requires multiple hops of reasoning costs accuracy." Failure mode 1 compounds it:
"`jev-1.13` answers the question you wrote, not the one you meant. Scoping words, negations, and implied
conditions are read at face value." The primitives page sets the bar: "Ask for a judgment a knowledgeable
person makes in a second given the right context."

## What jev would get wrong

Two distinct errors. With a double negative, jev may resolve the polarity the way the words run rather
than the way you meant, and failure mode 7 notes the related case: "a Noul where `true` maps to no and
`false` maps to yes will perform worse." With multi-hop indirection — find the plan, find the policy for
that plan, find the clause in that policy, apply it to the request — each hop costs accuracy, and the
single returned probability gives you no way to tell which hop failed. You get one number that hides
three judgements, which is the opposite of the property the how-to-build guide calls "probably the most
important concept in this guide": "Broad questions hide several judgments behind one answer. Atomic
questions expose those judgments so you can inspect, tune, and combine them in code."

## What stays in code

The hops. Code looks up the plan from the account record, code selects the governing policy text, and
code places *only that clause* in the state alongside the request. That turns a three-hop question into a
one-hop one. Code then combines the atomic answers with the boolean logic you actually meant — and code,
not the model, applies any negation.

The decomposed form: a Noul "Does `request` ask for a discount?"; a Noul "Does `policy_clause` permit the
discount described in `request`?"; a Noul "Does `account.status_note` describe a suspension?". Code
computes `permitted and not suspended`. Each question is single-hop, positively phrased, and names a state
path in backticks — the docs recommend naming the path because it removes a hop.

## Numbers

Decomposition costs almost nothing: adding questions "barely changes the response time and costs only the
tokens for the extra questions" (https://docs.typesafe.ai/primitives.md). Six atomic Nouls over a
1,000-token filtered state run about 1,400 input tokens, roughly $0.00006 at $0.042 per million input
tokens with output free (https://docs.typesafe.ai/models.md), typically about 100 ms. No published
benchmark isolates jev's multi-hop accuracy; the docs state the degradation directly.

- Field evidence (independent-benchmark): RINNECODER/jev-behavior-study — 32-link indirection tasks 7/18 correct against 8-link tasks 12/18, over 11,621 requests, 2026-09-19. Source: https://github.com/RINNECODER/jev-behavior-study

- Field evidence (community-report, second-hand): surfaced via search over the bestdan/workflow-skills assessment, not verified at a primary source — "The co-review-reconciler needs reasoning Jev cannot do, so Jev must not replace it." Source: https://github.com/bestdan/workflow-skills/pull/757

## When the verdict flips

It flips to **good** when three conditions hold: every question is one hop from the state; every question
is phrased positively (ask "is the account suspended?", never "is the account not unsuspended?"); and
code does the lookup that supplies the intermediate object, so the model never has to traverse. Failure
mode 1's advice applies where interpretation is unavoidable: "split it into two literal questions and
combine them in code." If you cannot decompose — because the reasoning chain is open-ended rather than
fixed — the verdict stays **no** and the task belongs to a reasoning model.

## Alternatives considered

- **Regex / deterministic**: owns the lookups and the boolean combination.
- **Small LLM**: worse at chained inference than jev and slower.
- **Frontier LLM**: the right tool for genuinely open-ended chains; that is System Two work.
- **Fine-tuned classifier**: only if you have labels for the composite outcome; you lose per-hop visibility.
- **Embeddings**: can retrieve the governing clause, which is the hop code should take.
- **Human**: for cases where the decomposed answers land near 0.5.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
