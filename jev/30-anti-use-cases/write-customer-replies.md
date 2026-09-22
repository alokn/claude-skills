---
id: au-write-customer-replies
title: Do not use jev to draft replies, emails, or any prose a person will read
verdict: no
domain: support
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9, Generation)
  - https://docs.typesafe.ai/concepts/system-one.md  ("do not write replies")
  - https://docs.typesafe.ai/primitives/choice.md  (up to 255 options)
related: [au-generate-ticket-summaries, au-rewrite-and-translate-text, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to draft the reply to this customer?" Also "can jev write the apology
email", "auto-respond to tier-1 tickets with jev", "we want jev to generate the Slack update".

## Verdict

**No.** Writing a reply is generation. The System One page states that System One models "do not write
replies, produce code, or generate explanations of their reasoning", and the jaggedness page's ninth
failure mode says jev "is not trained to generate text" and that forcing it "will not work well and will
be very slow." Jev's value proposition — a typed answer constrained to options you supplied — is exactly
the property that makes free prose impossible.

## What jev would get wrong

Two failure shapes appear in practice. First, teams try a Choice over a library of canned reply
templates. That *is* a legitimate jev question, but it is template selection, not drafting, and it fails
the moment the reply needs a customer-specific fact (an order number, a date, a dollar amount) — jev
cannot supply those, and a Choice cannot interpolate them. Second, teams try to build the reply from a
chain of Choices (greeting, then body clause, then sign-off). The docs call this out directly: chaining
choices to generate text "will not work well and will be very slow", and each link costs a round trip
because "every question in a request sees the same state, is evaluated independently" — one answer never
becomes context for another within a call.

## What stays in code

Template selection is a Choice with up to 255 options
(https://docs.typesafe.ai/primitives/choice.md), including an explicit `none of these` option so the
model can decline. Code does the merge-field substitution from your database, code enforces the
confidence gate, and code sends nothing without a human where the reply commits the company to
something. A generative model writes any reply that is not a template.

The pairing that does work: an LLM drafts, then jev verifies. Nouls such as "Does `draft` answer the
request in `ticket.messages[0].text`?", "Does `draft` promise a refund?", and "Does `draft` state a
policy that does not appear in `policy`?" are single-hop judgements over text in the state, with
confidence available to route the doubtful drafts to a person.

## Numbers

Template selection on a 60-option Choice over a short ticket is on the order of 1,500-2,500 input
tokens, roughly $0.00006-$0.0001 per call at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), at typical latency of about 100 ms. The drafting itself carries
generative-model pricing; jev does not reduce it. No published benchmark measures jev on reply drafting
because the task is out of scope for the model.

## When the verdict flips

For "write the reply", **no rewrite exists**. Two adjacent tasks flip to *good*: (1) **select** a reply
template from a bounded library with a Choice plus a `none of these` option and a confidence gate; (2)
**verify** an LLM-written draft with one Noul per property. Both are decisions, not writing. If the
argument for jev is cost, note that it only removes the classification call, never the generation call.

## Alternatives considered

- **Regex / deterministic**: fine for pure macro insertion keyed by a code-computed condition.
- **Small LLM**: the right tool for drafting tier-1 replies; pair with jev verification.
- **Frontier LLM**: for replies that carry commercial or legal weight, with human sign-off.
- **Fine-tuned classifier**: could pick a template, but a Choice is easier to change and returns a confidence value with each pick.
- **Embeddings**: can retrieve a similar past reply; cannot adapt it.
- **Human**: still required wherever the reply commits money or policy.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
