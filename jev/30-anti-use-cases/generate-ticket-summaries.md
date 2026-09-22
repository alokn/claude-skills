---
id: au-generate-ticket-summaries
title: Do not use jev to write the summary of a ticket, thread, or document
verdict: no
domain: support
decision_shapes: [classification]
primitives: []
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9, Generation)
  - https://docs.typesafe.ai/concepts/system-one.md  ("do not write replies, produce code, or generate explanations")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (code owns the workflow; decompose questions)
related: [au-write-customer-replies, au-generate-code-and-patches, au-free-form-value-extraction, df-rewrites, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to summarise a support ticket for the agent?" Also asked as "can jev give
us a one-line TL;DR of this thread", "we want jev to condense the incident channel into a paragraph",
and "replace our summarisation LLM call with jev, it's cheaper".

## Verdict

**No.** Summarisation is text generation, and generation is failure mode 9 on the jev-1.13 jaggedness
page: "`jev-1.13` is not trained to generate text. While you can force it to by chaining choices, this
will not work well and will be very slow." The System One concept page is equally plain: System One
models "do not write replies, produce code, or generate explanations of their reasoning." There is no
configuration, prompt, or decomposition that makes jev emit prose. This is a category error, not a
tuning problem.

## What jev would get wrong

There is nothing for jev to get wrong, because there is no valid request shape. The only way to force
prose out of jev is to chain Choice questions over a vocabulary, one token at a time — the docs name
this explicitly and say it "will not work well and will be very slow", which also destroys the single
property (about 100 ms end to end) that made jev attractive. A cheaper mistake is the intermediate
version: summarise with jev, then classify the summary. That fails twice — jev cannot write the
summary, and the summary would be a lossy distractor in the state anyway.

## What stays in code

Everything. The workflow is: code assembles the ticket, an LLM writes the summary if a human needs one,
and code decides when that is worth doing.

The productive inversion is to let jev decide *whether* a summary is warranted, not to write it. On the
raw ticket, ask a Noul "Does `ticket.messages` contain more than one distinct issue?", a Noul "Has the
customer restated the same request after a reply?", and a Score for urgency across three described
levels. Code calls the generative model only for tickets that clear the bar. That is the pattern the
how-to-build guide describes: code owns the control flow and the model "appears only where the system
needs programmable common sense".

## Numbers

Not applicable — no jev design exists for this task. For the gating design above, the cost is the
ticket text plus the questions at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), one call per ticket, typically about 100 ms. Whether gating pays
depends on the share of tickets that need a summary, which you must measure; do not quote a saving
without that share.

## When the verdict flips

It does not. **No rewrite exists** for "produce the summary text." The adjacent task that *does* fit is
the gate described above ("does this ticket need a summary / an escalation / a second reviewer?"), and
the verification task: after an LLM writes the summary, jev can check it with Nouls such as "Does
`summary` state a request that appears in `ticket.messages`?" and "Does `summary` contain a claim absent
from `ticket.messages`?" Those are bounded judgements and a good fit; the writing itself never is.

## Alternatives considered

- **Regex / deterministic**: cannot summarise; extractive first-sentence heuristics are worse than an LLM.
- **Small LLM (Haiku-class)**: the right tool. Cheap, fast enough for a human-facing summary, and it
  actually produces text.
- **Frontier LLM**: use when the summary feeds a decision a person will be held to.
- **Fine-tuned classifier**: wrong output shape.
- **Embeddings**: can select representative sentences, not write a summary.
- **Human**: only where the summary is the deliverable.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19 (failure mode 9)
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19 (price)
