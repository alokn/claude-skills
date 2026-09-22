---
id: uc-data-ml-date-part-extraction
title: Extract a date by asking for its parts as Choices and assembling the date in code
verdict: conditional
domain: data-ml
decision_shapes: [extraction, classification, verification]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md  (seven Choice questions, TODAY pinned, REVIEW_BELOW 0.60, six worked examples)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 3: extract components, compare in code; mode 2: keep arithmetic in code)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Structured Data Extraction)
related: [uc-data-ml-pre-parsed-value-selection, uc-verification-extraction-field-verification, uc-data-ml-structure-recovery-autoformat]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract dates from documents?" Also: "our regex misses 'the
Thursday after next'", "can jev tell us the contract's expiry date?", "how do we handle a
document that states no date at all?"

## Verdict

**Conditional**, and the condition is absolute: jev names the parts the text states, and code
does every calendar operation. The cookbook is explicit — "The model reads what the text says and
never does the calendar math." Date and time comparison is failure mode 3 and arithmetic is mode
2, so a design where jev returns a date, or compares two dates, or decides whether something is
overdue, is **no**. Restructured as parts-plus-assembly it works, with a confidence gate and a
review queue.

## What jev decides

State is the raw document; the target is named by a `role` string interpolated into every
question. Seven Choices in one call — a router plus six part readers, "Code reads only the pieces
`mode` calls for."

```python
"mode": Choice(instructions=(
    f"How is {role} written? 'absolute' = a calendar date naming a month (e.g. 'August 14', "
    "'the 3rd of March'); 'relative' = given relative to today (today, tomorrow, the day after "
    "tomorrow, or a named weekday such as 'next Thursday'); 'none' = the document does not state "
    "this date."), criteria={"absolute": None, "relative": None, "none": None})
```

- `month` — 12 months plus `none`; `day` — 31 options plus `none`
- `year` — `YEAR_WINDOW = list(range(1900, 2051))` plus `out_of_range` and `none`, with the
  instruction "Pick 'none' if the document states no year (code infers it), or 'out_of_range' if
  a year is stated but not in the list"
- `day_anchor` — `today`, `tomorrow`, `day_after`, `weekday`, `none`
- `weekday` — 7 weekdays plus `none`; `week_offset` — `current`, `next`, `none`

Shared absent criterion: "The document does not state this, or it is not this kind of date."
The escape hatches are the design — they let the model say "not here" or "outside your list"
instead of picking a plausible wrong option.

Confidence is the minimum over only the parts the shape used, gated at `REVIEW_BELOW = 0.60`:
"A date under `REVIEW_BELOW` = 0.60 goes to a person, and so does a date code could not assemble
at all."

## What stays in code

Everything numeric and temporal. The reference date (`TODAY = date(2026, 7, 30)`, pinned so
relative dates reproduce), the assembly, the year-inference heuristic, the weekday convention
("a bare weekday is the next occurrence on or after today; 'next' is the following calendar
week"), and validity — `February 30` raises `ValueError` and returns `impossible date`, not a
date. Every downstream comparison, interval and overdue test is code.

## Numbers

From `date_extraction_cookbook.md`, `jev-1.12`, four short synthetic documents and six
(document, role, expected date) examples:

| question | expected | got | conf | flags |
|---|---|---|---|---|
| the date the agreement takes effect | 2025-01-01 | 2025-01-01 | 0.97 | |
| the date the agreement expires | 2027-12-31 | 2027-12-31 | 0.91 | |
| the deadline to return the form | 2026-08-14 | 2026-08-14 | 0.95 | |
| the date of the kickoff call | none | none | 0.46 | review (absolute date incomplete) |
| the date the survey closes | 2026-07-30 | 2026-07-30 | 0.94 | |
| the date of the design review | 2026-08-06 | 2026-08-06 | 0.92 | |

"auto-accept (5)" and "send to review (1)". All six match the expected value including the
expected `none`. Cost, latency, token counts and repeats: **not reported** — each example run
once, no baseline. This is a six-example demonstration, not an accuracy estimate.

Closest jaggedness modes: **3** and **2**, which the whole design exists to route around.

## When the verdict flips

- **The format is fixed.** ISO dates, a `date` column, a form field. `strptime` is exact and free
  — using a model is **weak**.
- **`dateparser`/`duckling` already covers your inputs.** Measure their failure rate first; they
  handle a great deal of "next Thursday" already and cost nothing per call.
- **You ask jev to compare or compute.** "Is this more than 30 days old", "which is earlier",
  "how many business days" — **no**. Assemble, then compare in code.
- **Ambiguity is inherent.** "'next Thursday' can mean two different days, so code decides which"
  — that is a stated convention, not a fact read off the text, and it can be wrong for your users.
- **Many candidate years or locale-specific ordering.** "If a list that long bothers you, pull the
  year-like numbers out of the text first and offer the model only those" — which is the
  pre-parsed-selection shape.
- **A wrong date has legal or financial force.** Keep the 0.60 review gate, and widen it.

## Alternatives considered

- **`strptime` / regex** — exact for known formats and the right first pass; brittle on prose.
- **`dateparser`, `duckling`, `chrono`** — mature natural-language date parsers, free, fast, and
  the real competitor: they resolve "next Thursday" too. What they cannot do is pick *which* of
  five dates in a document is "the deadline to return the form" — that role selection is where
  jev earns its place. Combine: library finds candidates, jev picks the role.
- **NER date model (spaCy, Flair)** — finds date spans; does not assign them roles or normalise.
- **Frontier LLM returning a date string** — convenient and it will confidently emit a date the
  document never stated, and dates are where LLM arithmetic is weakest.
- **Human data entry** — the incumbent for contracts; the 0.60 band is what should still reach it.

## Sources

- https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
