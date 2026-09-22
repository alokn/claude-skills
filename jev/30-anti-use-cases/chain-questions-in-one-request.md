---
id: au-chain-questions-in-one-request
title: Do not chain dependent questions inside one jev request
verdict: no
domain: ml
decision_shapes: [classification, verification]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/primitives.md  ("Every answer is independent. One question's answer is not hidden context for another")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Questions are evaluated independently and in parallel. One primitive's result does not become hidden context that changes another primitive's result")
  - https://docs.typesafe.ai/patterns/fan-out.md  (speculative fan-out: ask everything, ignore what you do not need)
related: [au-multi-hop-and-double-negatives, au-average-noul-with-choice, au-open-ended-agent-loop]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ask 'what is the category?' and then 'given that category, what is the
sub-category?' in the same request?" Also "question two should use question one's answer", "if
`is_bug` is true, then ask about severity", "can I reference another question's id in my instructions".

## Verdict

**No** — the dependency silently does not exist. Two docs pages state the guarantee. Primitives: "Every
answer is independent. One question's answer is not hidden context for another. You can add or remove
questions without changing the others' results." The how-to-build guide: "Questions are evaluated
independently and in parallel. One primitive's result does not become hidden context that changes another
primitive's result." A question phrased as "given your answer above..." is evaluated against the state
alone, with no answer above to refer to.

Closest failure mode: **structural invariants** — question independence is a documented
property of the request, so a dependency has to be expressed as a second call rather than as
wording inside one.

## What jev would get wrong

It will answer the dependent question as best it can from the state, producing a plausible result that
was not conditioned on anything. The design appears to work because both answers are usually consistent —
they were computed from the same state — and it fails exactly where conditioning would have mattered: the
cases where question one's answer is surprising. Question ids do not help either; they "are for your code.
They are not sent to the model", so an instruction naming another question's id refers to nothing. The
result is a workflow that looks conditional in the source and is unconditional at runtime.

## What stays in code

The conditionality. Code reads answer one, applies the threshold, and decides what happens next — whether
that is using answer two, ignoring it, or issuing a second request. This is not a limitation to work
around so much as the shape the API is built for.

Two patterns cover nearly every case. **Speculative fan-out:** ask every question the decision tree might
need in one call and let code ignore the irrelevant answers. Asking about severity on a ticket that turns
out not to be a bug costs only that question's tokens — "Asking a question you might not need is close to
free" — and adds little latency, since questions run in parallel ("barely changes" in the docs,
not zero). **A second request:** when the first answer
determines what *evidence* to fetch, code fetches it, builds a new state that includes the first answer as
a field, and asks again. The docs endorse putting an answer "into the state of a follow-up request".

## Numbers

Speculative fan-out costs only the extra question tokens: adding questions "barely changes the response
time and costs only the tokens for the extra questions, which are cheap"
(https://docs.typesafe.ai/primitives.md). Twelve speculative questions over a 1,200-token state is roughly
1,900 input tokens, about $0.00008 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), one call, typically about 100 ms. A genuine two-stage design is two
calls per item — still cheap, but count them rather than assuming one.

## When the verdict flips

It flips to **good** in two concrete forms, neither of which chains inside a call. First, fan out
speculatively and branch in code: this covers every case where the dependent question could have been
asked unconditionally. Second, make a second request whose state contains the first answer as an explicit
field and whose evidence code selected based on that answer — a bounded two-step workflow. **No rewrite
exists** for making one request's questions see each other; the independence is a design property, and it
is the same property that makes fan-out cheap and questions individually tunable.

## Alternatives considered

- **Regex / deterministic**: owns the branching. This is the alternative and it is free.
- **Small LLM**: a single prompt can chain reasoning internally, at the cost of latency, parse failures,
  and no per-step probabilities.
- **Frontier LLM**: genuine chained reasoning when the chain is open-ended; that is System Two work.
- **Fine-tuned classifier**: would need the composite label and loses per-step visibility.
- **Embeddings**: no role.
- **Human**: handles the branch where the first answer lands in the uncertain band.

## Sources

- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/fan-out.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
