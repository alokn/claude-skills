---
id: au-numeric-thresholds-and-arithmetic
title: Do not use jev to do arithmetic or test a number against a threshold
verdict: no
domain: finance
decision_shapes: [classification, verification]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Jev is not a calculator"; "Asking the model something code can compute exactly")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Use code when you can"; days_overdue example)
related: [au-count-items-in-text, au-date-ordering-and-overdue, au-interpolate-magnitude-from-score, au-archive-after-n-days-rule]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether this refund exceeds our $200 auto-approval limit?" Also
"does this order total more than the customer's credit", "is this discount above 30%", "compute the
weighted risk score with jev".

## Verdict

**No.** The jaggedness page's second failure mode opens with "Jev is not a calculator. We strongly
recommend implementing any mathematical logic in code. Jev will perform better on semantic questions
than mathematical ones", and its closing reminder lists "Asking the model something code can compute
exactly" as a thing to avoid. A comparison between two numbers is the definition of something code
computes exactly. Routing it through a probabilistic model converts a correct answer into an
approximately-correct one and adds a network hop.

## What jev would get wrong

Threshold questions fail in the boundary region, which is precisely the region that matters. `$199.50`
versus `$200.00` is where the business rule lives and where a model that "recognizes the shape of an
answer" is least dependable. The typed output hides it: a Noul returns 0.83 and your code reads that as
yes, with nothing in the response indicating that the comparison was estimated rather than performed.
Compound arithmetic (subtotal plus tax against a limit, percentage of a base, currency conversion) is
worse, because each step is an opportunity for the same approximation.

## What stays in code

Every number. Parse the amount, convert the currency, do the comparison, apply the limit. The
how-to-build guide's very first design step is "Use code when you can — keep deterministic work in code.
It is reliable and cheap", and its worked example is exactly this shape: compute `days_overdue` in
Python and branch on it.

Jev's role is the semantic half that surrounds the arithmetic and cannot be computed: a Noul "Does
`ticket.messages[0].text` give a reason that our policy recognises as an exception?", a Score over three
described levels of "how strong is the customer's justification", a Noul "Does `request` describe a
goodwill gesture rather than a billing error?". Code does the comparison; jev judges whether the
exception is warranted; code applies the outcome.

## Numbers

A code comparison costs nothing and is exactly right. A jev call over a short state with four semantic
questions is on the order of 500-1,000 input tokens, about $0.00002-$0.00004 at $0.042 per million input
tokens with output free (https://docs.typesafe.ai/models.md), typically about 100 ms. No published
benchmark measures jev on arithmetic; TypeSafe's own guidance ("not a calculator") makes one unnecessary.

- Field evidence (community-report): bestdan/workflow-skills#757, task-scope forecasting — restating the counts numerically hit 40/40, "at which point it is arithmetic, so rule 4 gives it to code", 2026-09-19. Source: https://github.com/bestdan/workflow-skills/pull/757

## When the verdict flips

For the arithmetic itself it does not — **no rewrite exists**, because there is nothing to rewrite: code
already does it correctly. The surrounding decision flips to *good* when you split the task. Code
computes the number and buckets it into a named band (`under_limit`, `within_10_percent_of_limit`,
`over_limit`), puts the band in the state as a word rather than a figure, and jev answers only the
semantic question. The jaggedness page prescribes exactly this: "do the conversion in code and pass in
either the computed number or a named bucket. Keep the model for the part that is genuinely a judgment."

## Alternatives considered

- **Regex / deterministic**: wins. This is arithmetic; the language runtime is the tool.
- **Small LLM**: also unreliable at arithmetic, and slower.
- **Frontier LLM with a calculator tool**: correct, but a hundred times slower and more expensive than
  the comparison operator you already have.
- **Fine-tuned classifier**: no role; the relation is exact, not learned.
- **Embeddings**: no role.
- **Human**: only for the exceptions jev flags as uncertain.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
