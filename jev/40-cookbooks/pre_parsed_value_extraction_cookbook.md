---
id: cb-pre_parsed_value_extraction_cookbook
title: Pre-parsed value extraction
url: https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md
decision_shapes: [extraction, classification]
primitives: [choice, noul]
related: [uc-data-ml-pre-parsed-value-selection, uc-verification-invoice-three-way-match, uc-commerce-attribute-extraction, au-free-form-value-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Extract a verbatim value from a document without letting a model write the value. "A regex
finds the candidate values, TypeSafe picks the one the question asks for, and code copies
it verbatim." The regex is tuned to over-find; jev picks the candidate the question asks
for "and reads off any attribute the code needs downstream (currency, country, whether an
amount is a credit or a charge)"; code copies and normalizes. The guarantee claimed is
structural: "Because TypeSafe only ever chooses among the spans the regex found, the value
you get back is one of those spans, copied unchanged. It cannot invent a value or transpose
a digit."

Dataset: three short synthetic documents written into the cookbook - an email thread with
four addresses, a two-sentence note with three phone numbers, and a five-line invoice with
four amounts. No corpus, no benchmark, no sample size. Model `jev-1.12`, client
`timeout=30.0`; run date: not reported.

## Decomposition (state, questions, how answers are combined)

State is the raw document string (`state=document`), not a dict. Three helpers each carry
one question.

`pick` - a `Choice` whose options are the regex spans themselves, plus one escape hatch:

```python
NONE = "none"
criteria = {c: None for c in candidates} | {NONE: "None of these is the requested value."}
Choice(instructions=question, criteria=criteria)
```

Questions asked verbatim: "Which email address does the sender want their receipt sent
to?", "Which email address did this message come from (the From line)?", "Which of these is
the direct mobile / cell number?", "Which amount is the total the customer must pay?",
"Which amount is the courtesy credit that was applied?".

`classify` - a `Choice` over a fixed label set: "In what country is this office located?"
with `["US", "GB", "DE", "FR", "CA", "AU"]`, and "What currency are these amounts in?" with
`["USD", "EUR", "GBP", "JPY", "CAD"]`.

`is_true` - a `Noul` returning P(yes): "Is the amount {chosen} a credit or refund to the
customer, not a charge?"

Candidate finding stays in code, with recall-tuned regexes:

```python
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE_RE = re.compile(r"\(?\+?\d[\d\s()\-.]{6,}\d")
MONEY_RE = re.compile(r"[$€£¥]\s?\d[\d,]*(?:\.\d{2})?")
```

Combination is arithmetic and formatting in code: the picked email is lowercased; the
picked phone plus the classified country go to `phonenumbers.parse(...)` and are formatted
to E.164; the picked amount goes through `to_decimal()` (`Decimal(re.sub(r"[^\d.]", "",
value))`) and the Noul is thresholded with the only comparison in the file:

```python
kind = "credit" if is_credit > 0.5 else "charge"
```

Confidence is returned with every pick but no auto-accept band or abstain route is wired
up; the `none` option is the abstain path at the answer level.

## Numbers reported (verbatim, with what they compare against and the run date if given)

Email case - candidates `['dana.whit@acme-corp.com', 'billing@acme-corp.com',
'orders@acme-corp.com', 'dana.personal@gmail.com']`; `receipt -> dana.personal@gmail.com
(conf 0.98)`; `sender -> dana.whit@acme-corp.com (conf 1.00)`.

Phone case - candidates `['(415) 555-0199', '(415) 555-0142', '(415) 555-0177']`;
`mobile -> (415) 555-0177 (conf 1.00)`; `country -> US (conf 0.90)`; `E.164 ->
+14155550177`.

Money case - candidates `['$1,200.00', '$115.50', '$1,315.50', '$50.00']`;
`total due : $1,315.50 -> 1315.50 USD (charge, P(credit)=0.01)`; `credit : $50.00 ->
50.00 USD (credit, P(credit)=0.99)`.

Documented limit: "A `Choice` question allows at most 255 options."

Accuracy over a dataset: not reported (three worked examples, one call each). Cost: not
reported. Latency: not reported. Token counts: not reported. Repeats: not reported.
Comparison against named LLMs: none run.

## Caveats the cookbook itself states

- "A `Choice` question allows at most 255 options. With more candidates than that, narrow
  in two stages: pick the section first, then the span inside it."
- "Finding the candidates is the part that takes work. Emails, phone numbers and amounts
  have regexes that cover them; a name does not, so its candidates have to come from a
  roster you already have, or from a named-entity recognizer or an LLM that proposes them."
- Normalization assumptions are the code's problem, not the model's: "`to_decimal` assumes
  the comma groups thousands and the dot is the decimal point. That holds for `$1,315.50`;
  in `€1.315,50` it is the other way round. Ask a `Noul` question which convention the
  document uses, and branch on it in code."
- The regex is deliberately imprecise ("Tune it to over-find"), and everything shown is
  three hand-written documents with one call each.

## Lessons transferable to other use cases

- Select, do not generate. Making the options the found spans means the returned string is
  a copy; there is no path by which a digit can be transposed.
- Pre-parsed candidates: the split is regex for recall, jev for the semantics ("nothing in
  the digits says which number is the mobile or what country it is in; the words around
  them do").
- Companion questions: a small fixed-label `Choice` supplies the attribute (currency,
  country) the normalizer needs, and a `Noul` supplies the sign. Code owns the arithmetic
  and formatting - `Decimal` parsing, lowercasing, E.164 assembly.
- Always include an explicit `none` option, so "no candidate fits" is a representable
  answer rather than a forced wrong pick.
- Does not generalise: entity types with no regex (names, products, addresses) need a
  roster or an NER pass first, and candidate sets above 255 need a two-stage narrowing.

## Use-case entries this supports

- `uc-data-ml-pre-parsed-value-selection` - choose the correct span among regex candidates instead of generating a value
- `uc-verification-invoice-three-way-match` - pick the total due from several amounts on an invoice, with the comparison done in code
- `uc-commerce-attribute-extraction` - fill structured fields from unstructured text with verbatim spans

**Anti-use-case implied:** `au-free-form-value-extraction` - do not ask jev to emit a value
as text (or to normalize, reformat or do currency/decimal arithmetic); it selects among
spans and code does the rest.
