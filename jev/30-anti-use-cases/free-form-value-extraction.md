---
id: au-free-form-value-extraction
title: Do not ask jev for a free-form extracted value
verdict: no
domain: extraction
decision_shapes: [extraction]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9; "extract possible options using regex ... and let jev pick")
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  (candidates then Choice)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (extract, verify, escalate)
  - https://evals.typesafe.ai  (invoice processing 61.8%, jev's weakest category)
related: [au-date-ordering-and-overdue, au-whole-document-in-state, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract the invoice total / the customer's address / the vendor name
from this email?" Also "pull the fields out of this document with jev", "replace our extraction LLM with
jev".

## Verdict

**No**, as posed — with a well-documented rewrite that makes it *conditional*. Asking jev for a value it
must produce is generation: the jaggedness page's ninth failure mode says "For data extraction, it is
better to extract possible options using regex or a generative model and let `jev-1.13` pick the correct
extraction", and "when the answer space is bounded, turn extraction into a Choice over the options rather
than asking for the value itself." Extraction accuracy is also jev's measured weak spot: invoice
processing is its lowest workflow-eval category at 61.8% (https://evals.typesafe.ai, read 2026-09-19).

## What jev would get wrong

There is no request shape that returns an arbitrary string, so the failure is upstream of the model: the
design cannot be expressed. Teams work around it by building a Choice whose options are guesses at what
the value might be, which reintroduces every problem the typed output was supposed to remove — the true
value may not be among the options, and a Choice "is relative, settling *which* option", so it will
pick the least-bad wrong one unless you add an explicit `none of these`. On a dense invoice the second
failure mode also bites: sending the whole document means "accuracy falls as the state grows with content
unrelated to the decision."

## What stays in code

The parser. A regex or a document parser enumerates every candidate amount, email address, date, or id
in the text, with its position and surrounding label. Code deduplicates and caps the candidate list.
Code then owns validation (checksum, format, currency), normalisation, and persistence. Jev is asked one
bounded question: a Choice over the enumerated candidates plus `none of these`, with instructions naming
the field precisely — the pre-parsed value extraction cookbook is the worked version.

The alternative shape is the SDE cascade: a small LLM extracts every field, jev verifies each one with a
Noul against the source text, and only the fields that fail verification go to a reasoning model.

## Numbers

Jev's weakest published workflow category is invoice processing at 61.8%, against a combined 67.8% and
Opus 5's 73.1% (https://evals.typesafe.ai, read 2026-09-19). A selection call over a 1,500-token document
excerpt with twelve candidates costs roughly 2,000 input tokens, about $0.00008 at $0.042 per million
input tokens with output free (https://docs.typesafe.ai/models.md), typically about 100 ms.

- Field evidence (community-report): `qte77/doc-pipeline-engine#196` recorded a "don't adopt" decision — the pipeline "needs open-ended extraction rather than bounded label sets", alongside proprietary API-only hosting, 2026-09-19. Source: https://github.com/qte77/doc-pipeline-engine/issues/196

## When the verdict flips

It flips to **conditional** the moment code produces the candidates. Concretely: regex finds every
currency amount in the document; jev answers a Choice "Which of `candidates` is the grand total the
customer must pay?" with criteria distinguishing subtotal, tax, and total, plus a `none of these` option;
code validates that the chosen total equals subtotal plus tax and routes mismatches and low-confidence
answers to review. It also flips to conditional in verify-only form (cascade). It never flips for "give
me the value" with no candidate list.

## Alternatives considered

- **Regex / deterministic**: wins outright where the field has a fixed format (IBAN, order id, ISO date).
  Use it and stop.
- **Small LLM**: extracts free-form values well and cheaply; pair with jev verification.
- **Frontier LLM**: for dense or adversarial documents, or as the escalation tier in the cascade.
- **Fine-tuned classifier / layout model (LayoutLM-class)**: the strongest option for high-volume,
  fixed-template documents with labelled data.
- **Embeddings**: no role in value extraction.
- **Human**: reviews the low-confidence band; that band is what jev buys you.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
