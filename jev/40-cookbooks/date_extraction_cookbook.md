---
id: cb-date_extraction_cookbook
title: Date extraction
url: https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md
decision_shapes: [extraction, classification]
primitives: [choice]
related: [uc-data-ml-date-part-extraction, uc-verification-document-completeness-checklist, uc-verification-extraction-field-verification, au-date-ordering-and-overdue]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

"Extracts absolute and relative dates by asking TypeSafe for the parts named in a document,
then resolving and validating them in code with confidence-based review." The function
built is `extract_date(document, role)`: it "takes a document and a phrase naming the date
you want, such as 'the deadline to return the form', and hands back a `date` with a
confidence." It flags a low-confidence read "and one whose parts do not add up to a date at
all, including a date the document never states."

The division of labour is explicit: "TypeSafe answers `Choice` questions about the date in
one call: what kind of date it is, and which month, day, year, or weekday the text names.
Code turns those answers into a `date`. The model reads what the text says and never does
the calendar math."

Dataset: four short synthetic documents (`CONTRACT`, `FORM`, `SURVEY`, `REVIEW`) and six
(document, question phrase, expected date) examples. Source: written in the cookbook; no
external dataset. Model: `TYPESAFE_MODEL = "jev-1.12"`. Date sampled: not reported;
answers are served from a shipped `json_cache.json` so "re-rendering replays the published
results with no API spend". Reference date is pinned: `TODAY = date(2026, 7, 30)`, "a fixed
reference 'today' so relative dates resolve reproducibly", and a Thursday.

## Decomposition (state, questions, how answers are combined)

State: the raw document string, passed as `state=document`. The target date is named by the
`role` string, which is interpolated into every question's instructions.

Seven `Choice` questions in one call. `mode` routes; the other six read parts, and "Code
reads only the pieces `mode` calls for."

```python
"mode": Choice(instructions=(
    f"How is {role} written? 'absolute' = a calendar date naming a month (e.g. "
    "'August 14', 'the 3rd of March'); 'relative' = given relative to today (today, "
    "tomorrow, the day after tomorrow, or a named weekday such as 'next Thursday'); "
    "'none' = the document does not state this date."),
    criteria={"absolute": None, "relative": None, "none": None}),
```

- `month` — "If {role} is an absolute calendar date, which month is it in?"; 12 months plus
  `none`.
- `day` — "If {role} is an absolute calendar date, which day of the month (1-31)?"; 31
  options plus `none`.
- `year` — "If {role} is an absolute calendar date, which year? Pick 'none' if the document
  states no year (code infers it), or 'out_of_range' if a year is stated but not in the
  list."; `YEAR_WINDOW = list(range(1900, 2051))` plus `out_of_range` and `none`.
- `day_anchor` — "If {role} is relative to today, which day is it?"; `today`, `tomorrow`,
  `day_after`, `weekday`, `none`.
- `weekday` — "If {role} names a day of the week, which one?"; 7 weekdays plus `none`.
- `week_offset` — "'next' for 'next Thursday' or 'Thursday next week'; 'current' for 'this
  Thursday'; 'none' for a bare weekday with no qualifier"; `current`, `next`, `none`.

Shared absent-criterion text: `"The document does not state this, or it is not this kind of
date."`

All arithmetic is in code. `assemble` branches on `mode` and takes the minimum confidence
over only the parts the shape used:

```python
if year == "out_of_range":        # a year stated but off the list -> flag, don't guess
    return result(None, f"year outside {YEAR_WINDOW[0]}-{YEAR_WINDOW[-1]}")
if year == "none":                # no year stated -> infer this year, bump if well past
    resolved = date(today.year, MONTHS[month], int(day))
    if resolved < today - timedelta(days=31):
        resolved = date(today.year + 1, MONTHS[month], int(day))
```

Weekday resolution is an explicit code convention: "a bare weekday is the next occurrence
on or after today; 'next' is the following calendar week; 'current' is this week."
Impossible combinations (`February 30`) are caught by `ValueError` and returned as
`impossible date`, not a date.

Confidence band and abstain path: `REVIEW_BELOW = 0.60` — "a gate: a date below this
confidence is flagged for a human". `needs_review` is true when `resolved is None or
confidence is None or confidence < REVIEW_BELOW`. "A date under `REVIEW_BELOW` = 0.60 goes
to a person, and so does a date code could not assemble at all. The rest go straight
through."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Seven `Choice` questions per call; one call per (document, role). Year option list spans
1900 to 2050. Results over the six examples, against hand-written expected dates:

| result | question | expected | got | conf | flags |
|---|---|---|---|---|---|
| OK | the date the agreement takes effect | 2025-01-01 | 2025-01-01 | 0.97 | |
| OK | the date the agreement expires | 2027-12-31 | 2027-12-31 | 0.91 | |
| OK | the deadline to return the form | 2026-08-14 | 2026-08-14 | 0.95 | |
| OK | the date of the kickoff call | none | none | 0.46 | `<== review (absolute date incomplete)` |
| OK | the date the survey closes | 2026-07-30 | 2026-07-30 | 0.94 | |
| OK | the date of the design review | 2026-08-06 | 2026-08-06 | 0.92 | |

Routing outcome: "auto-accept (5)" and "send to review (1)" — the review case being "the
date of the kickoff call (conf 0.46 / absolute date incomplete)". All six rows are marked
OK, i.e. they match the expected value including the expected `none`.

Cost: not reported. Latency: not reported. Token counts: not reported. Repeats
(`NUM_SAMPLES`): not reported — each example is run once. Comparison against named LLMs:
not reported; this cookbook runs no baseline.

## Caveats the cookbook itself states

- Single-run, six-example demo on four short synthetic documents; no repeats and no
  accuracy figure beyond the six OK marks.
- The reference date is pinned by hand (`TODAY = date(2026, 7, 30)`) because relative dates
  would otherwise not reproduce.
- The year list is long enough to be a design problem: "If a list that long bothers you,
  pull the year-like numbers out of the text first and offer the model only those."
- "next Thursday" is genuinely ambiguous — "'next Thursday' can mean two different days, so
  code decides which" — the resolution is a stated convention, not a fact read off the
  text.
- The year-inference rule is a heuristic: when no year is stated, code "takes the current
  year and moves to the next one only when the date is already more than a month past."
- A wrong `mode` produces a partial read rather than an error: the kickoff-call row "means
  `mode` came back `absolute` with no month to go with it" — the design catches this as
  `absolute date incomplete` rather than emitting a date.

## Lessons transferable to other use cases

- Read the parts, compute the value: the model names month / day / year / weekday; code
  does every calendar operation. Generalises to any value that is a composition of
  text-visible parts and deterministic arithmetic (durations, money with units, versions).
- A `mode` question as a router, with companion questions read only when relevant — six
  part questions ride along in the same call and only the branch's answers are consumed.
- Escape hatches in the label set: `none` and `out_of_range` let the model say "not here"
  or "outside your list" instead of picking a plausible wrong option, and code flags rather
  than guesses.
- Weakest-link confidence with an abstain band: the date's confidence is the minimum over
  the parts actually used, gated at 0.60, so a weak read on any single part sends the whole
  extraction to a person.
- Validity is enforced twice — by the closed label sets, and again by `date()` raising on
  an impossible combination.
- What does not generalise: date maths itself. Nothing about the calendar, the current
  date, or which "Thursday" is meant is delegated to the model.

## Use-case entries this supports

- `uc-data-ml-date-part-extraction` — pull effective, expiry, deadline and relative dates by asking for their parts as Choices and assembling the date in code
- `uc-verification-document-completeness-checklist` — detect that a required date is absent
- `uc-verification-extraction-field-verification` — send low-confidence extractions to a human at 0.60

**Anti-use-case implied:** `au-date-ordering-and-overdue` — jev is never asked to compute a
date. Calendar maths, year inference, weekday offsets and impossible-date validation all stay
in code; the model only reports which parts the text names.
