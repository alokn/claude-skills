---
id: uc-data-ml-pre-parsed-value-selection
title: Let a parser enumerate candidate values and have jev select the one the question asks for
verdict: conditional
domain: data-ml
decision_shapes: [extraction, classification]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  (regex candidates + Choice with a `none` hatch; email / phone / money worked cases with confidences)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9: "turn extraction into a Choice over the options rather than asking for the value itself")
  - https://docs.typesafe.ai/primitives/choice.md  (255-option cap)
related: [uc-data-ml-date-part-extraction, uc-verification-extraction-field-verification, uc-agents-harness-function-call-argument-filling]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract a value from a document?" Also: "which of the four
amounts on this invoice is the total?", "our regex finds five email addresses and we pick the
wrong one", "can jev extract a field without hallucinating it?"

## Verdict

**Conditional**, on the candidates being produced by code first. Direct extraction is failure
mode 9 and TypeSafe's own evals place jev weakest on invoice-style precise extraction; the
documented rewrite is "when the answer space is bounded, turn extraction into a Choice over the
options rather than asking for the value itself." Done that way the guarantee is structural:
"Because TypeSafe only ever chooses among the spans the regex found, the value you get back is
one of those spans, copied unchanged. It cannot invent a value or transpose a digit."

## What jev decides

Three steps, of which jev owns only the middle one: "A regex finds the candidate values in the
text. Tune it to over-find." Then a Choice whose options *are* the candidate spans, plus an
escape hatch:

```python
NONE = "none"  # the escape hatch on every selection: "none of the candidates fits"

criteria = {c: None for c in candidates} | {NONE: "None of these is the requested value."}
Choice(instructions=question, criteria=criteria)   # state = the whole document
```

Then code "copies the picked value and normalizes it". Two companion question shapes ride along:
a small Choice over a fixed label set for an attribute the normaliser needs (`"In what country is
this office located?"` over `["US","GB","DE","FR","CA","AU"]`), and a Noul for a sign or kind
flag (charge versus credit).

The questions name the *role*, not the pattern — "Which email address does the sender want their
receipt sent to?", "Which of these is the direct mobile / cell number?" — because the role is the
part a regex cannot express.

## What stays in code

The regex or parser, tuned to over-find; the verbatim copy of the chosen span; all normalisation
(lowercasing, `phonenumbers.format_number` to E.164, `Decimal` parsing); the sign applied from the
credit/charge Noul; the confidence gate; and the two-stage narrowing when candidates exceed the
cap. Decimal convention is a worked trap: "`to_decimal` assumes the comma groups thousands and the
dot is the decimal point. That holds for `$1,315.50`; in `€1.315,50` it is the other way round.
Ask a `Noul` question which convention the document uses, and branch on it in code."

## Numbers

From `pre_parsed_value_extraction_cookbook.md`, `jev-1.12`, three worked documents:

- **Email.** Candidates `['dana.whit@acme-corp.com', 'billing@acme-corp.com',
  'orders@acme-corp.com', 'dana.personal@gmail.com']`. Receipt address -> `dana.personal@gmail.com`
  at confidence 0.98 (the `Reply-To` line, "which is what the body asks for"); sender ->
  `dana.whit@acme-corp.com` at 1.00.
- **Phone.** Candidates `['(415) 555-0199', '(415) 555-0142', '(415) 555-0177']`. Mobile ->
  `(415) 555-0177` at 1.00; country -> `US` at 0.90; code produced `+14155550177`. "Nothing in the
  digits says which number is the mobile or what country it is in; the words around them do."
- **Money.** Candidates `['$1,200.00', '$115.50', '$1,315.50', '$50.00']`. Total due ->
  `$1,315.50 -> 1315.50 USD (charge, P(credit)=0.01)`; credit -> `$50.00 -> 50.00 USD (credit,
  P(credit)=0.99)`.

Cost, latency, token counts and any accuracy over a labelled set: **not reported** — three
documents, one run each, no baseline. Per-call cost at $0.042 per million input tokens with free
output is a fraction of a cent for a document of a few thousand characters.

Closest jaggedness mode: **9, generation**, which this shape exists to avoid.

- Field evidence (community-report): structured extraction over a known, bounded field set is listed as a canonical community pattern; the same ecosystem records an explicit don't-adopt for open-ended extraction, on the grounds that System One needs a bounded, known answer set, 2026-09. Source: https://github.com/Anil-matcha/awesome-jev-by-typesafe

## When the verdict flips

- **There is exactly one candidate.** Take it. The model adds latency and a way to be wrong.
- **The regex cannot over-find.** "Emails, phone numbers and amounts have regexes that cover them;
  a name does not, so its candidates have to come from a roster you already have, or from a named
  entity recognizer or an LLM that proposes them." No candidate list, no use case.
- **More than 255 candidates.** The Choice caps there: "narrow in two stages: pick the section
  first, then the span inside it."
- **The document is structured** — a labelled form field, an XML tag, a fixed invoice template.
  Parse the field; that is exact.
- **The value must be transformed, not selected** (redacted, reformatted, split). Generation is
  mode 9; code transforms the copied span.
- **You skip the `none` hatch.** A Choice always picks something; without `none` a document that
  states no such value still returns one confidently.

## Alternatives considered

- **Regex alone with positional heuristics** ("the last amount is the total") — free and exact
  where layout is stable, and the thing that breaks on the invoice whose credit line comes last.
- **Frontier LLM extraction** — flexible, handles unbounded values, and it can transpose a digit;
  this shape exists because a copied span cannot.
- **Small LLM with constrained decoding to the candidate list** — the closest technical competitor
  and also guarantees a valid span; no per-selection probability unless you read logprobs, and you own the
  serving.
- **NER models** — good at finding spans, which is step one; they do not assign roles ("the one
  the sender wants the receipt sent to").
- **Template / layout extraction (document AI)** — the right answer for high-volume fixed forms.
- **Human data entry** — where low-confidence picks should go; the confidence is what makes that
  queue small.

## Sources

- https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
