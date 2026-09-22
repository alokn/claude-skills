---
id: au-date-ordering-and-overdue
title: Do not use jev to order dates, measure intervals, or decide what is overdue
verdict: no
domain: finance
decision_shapes: [classification, extraction]
primitives: [choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 3, verbatim)
  - https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md  (date parts as Choice; code assembles)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (days_overdue computed in code)
related: [au-numeric-thresholds-and-arithmetic, au-archive-after-n-days-rule, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to flag invoices that are more than 30 days overdue?" Also "which of these
two events happened first", "is this contract inside the current quarter", "did the user reply within
the SLA window".

## Verdict

**No**, with a documented rewrite that makes the *extraction* half conditional. Failure mode 3 states:
"`jev-1.13` reads dates as text, not as ordered quantities. Asking which of two dates comes first, how
far apart they are, or whether one falls inside a window is unreliable. It gets worse with mixed formats,
relative references and domain boundaries such as quarters, settlement windows, and accrual periods."
Overdue, SLA breach, and quarter membership are all exactly those three questions.

## What jev would get wrong

Ordering and interval questions come back as confidently typed booleans that were not computed. The
named degradations are the ones finance systems actually hit: mixed formats (`03/04/26` against
`4 March 2026`), relative references ("end of next month", "30 days from receipt"), and domain
boundaries — quarters, settlement windows, accrual periods. Time zones and business-day counting are not
in scope for the model at all. A wrong answer here does not look wrong; it looks like a `true`.

## What stays in code

Everything after extraction. The jaggedness page's instruction is to "split the work. Extraction is a
judgment, so give it to the model. Arithmetic is not, so keep it in code." Code assembles the date,
applies the calendar, handles time zones and business days, and does every comparison. The how-to-build
guide's first example is this exact line: compute `days_overdue = (today - invoice.due_date).days` in
code and branch on it.

Jev's legitimate contribution is reading a date out of prose when no parser can. Because "every part of a
date is a small closed set: twelve months, thirty-one possible days, a bounded range of years", extraction
becomes a Choice over enumerated parts — month as one of twelve plus `not stated`, day as one of
thirty-one plus `not stated`, year over a bounded range, and a Choice for the reference type when the
text says "next Tuesday". The date extraction cookbook has the worked version including relative dates and
confidence gating.

## Numbers

Extraction-by-parts over a short paragraph with four Choice questions is roughly 800-1,500 input tokens,
about $0.00003-$0.00006 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), one call, typically about 100 ms. The comparison in code costs
nothing. No published benchmark reports jev's date-ordering accuracy; the docs call it unreliable, which
settles it.

- Field evidence (community-report): `betmoar/cc-operator-plugin#151` listed jev's date, counting and state-size limits as directly in the way of the proposed integration and attached a kill condition to the probe, 2026-09-19. Source: https://github.com/betmoar/cc-operator-plugin/issues/151

## When the verdict flips

The comparison never flips — **no rewrite exists** for "let the model order the dates", because code
already does it perfectly. The extraction flips to **conditional** under three conditions: the date parts
are asked as separate Choices over enumerated options; every part has an explicit `not stated` option so a
missing component is reported rather than guessed; and code assembles, validates, and compares. Add a
confidence gate so ambiguous references go to a person rather than into the ledger.

## Alternatives considered

- **Regex / deterministic**: a date parser (`dateutil`, `chrono`, `Temporal`) wins for any recognisable
  format. Try it first; call jev only on what fails to parse.
- **Small LLM**: can parse messy dates, but returns a free-form string you must still validate.
- **Frontier LLM**: overkill and still needs code for the arithmetic.
- **Fine-tuned classifier**: no advantage over a parser.
- **Embeddings**: no role.
- **Human**: for the residue of genuinely ambiguous references.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
