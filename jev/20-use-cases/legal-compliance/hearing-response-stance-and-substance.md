---
id: uc-legal-compliance-hearing-response-stance-and-substance
title: Classify a consultation response by stance and score whether it argues substantively
verdict: conditional
domain: legal-compliance
decision_shapes: [classification, scoring]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://lindfors.no/blog/a-first-look-at-typesafes-jev/  (24 Norwegian hearing responses: stance 20/24, substance 19/24 vs 14/24, "$0.22" vs "$1.31" per 1k docs, p50 "0.32 s" vs "2.7 s", 0.9+ bin agreed 14/15)
  - https://github.com/mahlernim/jev-korean-benchmark  (non-English parity holds on reading, drops on domain knowledge: KorMedMCQA 80 vs 88)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 large state full of irrelevant detail)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-legal-compliance-document-type-classification, uc-data-ml-transcript-coding-codebook, uc-data-ml-map-reduce-corpus-labelling, uc-legal-compliance-regulatory-briefing-parallel-questions, au-non-english-at-scale-unevaluated]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to sort consultation responses?" Also: "a regulator's hearing got
400 submissions — can a model tell us who supports it?", "can jev separate a real argument from
a form letter?", "does this work in a language that is not English?".

## Verdict

**Conditional.** A first-look study on 24 Norwegian hearing responses is the only measurement,
and it is encouraging in a specific way: jev tied the frontier comparator on stance ("20/24"
each) and clearly beat it on the harder question of whether the response offers substantive
argument ("19/24" against "14/24"), at "$0.22" versus "$1.31" per 1,000 documents and a p50 of
"0.32 s" against "2.7 s". The conditions are the study's own limits: n=24, reference labels from
a single frontier model, one author, one language. Use it to order and pre-sort a reviewer's
queue; do not publish a tally of who supports what without a human reading the ones that matter.

## What jev decides

Code splits the submission into sections and sends the sections that carry position and argument
— the summary, the numbered responses to the consultation's questions, the conclusion — not the
whole PDF. Boilerplate letterheads and appendices are stripped first (failure mode 5).

```
stance: Choice
  instructions: {question: "What position does `response_text` take on `proposal_summary`?",
                 focus: "Judge the position on the proposal as written, not the respondent's
                         general views."}
  criteria:
    supports:     {what: "Endorses the proposal as drafted, with or without minor suggestions"}
    opposes:      {what: "Argues the proposal should not proceed in its current form"}
    mixed:        {what: "Supports some parts and opposes others in substance",
                   not_for: "Support with a suggestion that does not change the proposal"}
    no_position:  {what: "Comments, asks questions, or notes it has no view"}

substance: Score
  criteria: ["Asserts a position with no supporting reasoning.",
             "Gives reasons, but general ones that would apply to any similar proposal.",
             "Gives reasons specific to this proposal: a named clause, a figure, a legal
              authority, an operational consequence."]

is_coordinated_template: Noul
  instructions: "Does `response_text` read as a campaign template rather than an
                 individually written submission?"

proposes_alternative: Noul
  instructions: "Does `response_text` propose a specific alternative wording or mechanism?"
```

Bands matter here because the study measured them: in the 0.9-and-above confidence bin the model
agreed with the reference "14/15". Route everything below your fitted floor to a human, and route
`mixed` to a human regardless — it is the class a four-way Choice gets wrong most often.

## What stays in code

Document intake, section extraction, deduplication of identical submissions, the respondent
register (who they are, which sector, whether they are a statutory consultee), counting, and
every tally the final report publishes. Dates, deadlines and whether a submission was late are
code's job (failure mode 3). The aggregate "62% opposed" is arithmetic over labels, not a
question.

## Numbers

From https://lindfors.no/blog/a-first-look-at-typesafes-jev/, 24 Norwegian hearing responses:
stance "20/24" — a tie with DeepSeek V4.1 Flash with reasoning off, which also scored 20/24;
substance "19/24" against that comparator's "14/24"; cost "$0.22" per 1,000 documents against
"$1.31"; p50 "0.32 s" against "2.7 s"; and in the 0.9-and-above confidence bin agreement was
"14/15". With reasoning switched **on**, the comparator reached "22/24" on stance, at "$3.08"
per 1,000 documents and 26 s per document — so the frontier model wins on stance if you pay for
reasoning, and still loses on substance.

Read the caveats as part of the result. n=24 means a single reclassification moves the score by
four percentage points. The reference labels came from one frontier model, not from the
consultation's own analysts. The same post notes Norwegian tokenises at about **2.06 characters
per token against roughly 2.5 for English**, so the same document costs about 20% more in
Norwegian than the English arithmetic suggests. Cost method for your own estimate:
`input_tokens ~= chars/2.06` for Norwegian, `cost = tokens x $0.042 / 1e6`, output free.

The general non-English pattern is worth carrying: an independent Korean check found reading
comprehension held up (Belebele 96 vs 97 English) while domain knowledge dropped (KorMedMCQA 80
against a frontier model's 88). Stance is reading; substance edges toward domain judgement.

Closest failure mode: **5, large state full of irrelevant detail** — avoided by sending extracted
position sections rather than the filed PDF.

## When the verdict flips

- **The tally is the output.** If a published count drives a policy decision, every response
  needs a human reader. This is a pre-sort, not a census.
- **Your language is neither English nor evaluated.** The measurement is Norwegian, n=24. Run
  your own 100-row check before trusting it.
- **Submissions are long and structured** — a 60-page legal analysis with annexes. Split and
  ask per section, or the state defeats the model.
- **The consultation is adversarial** and respondents know a model reads first. Text that argues
  with the classifier is failure mode 6.
- **You need to explain a classification to a respondent.** There is no reasoning to show.

## Alternatives considered

- **Manual coding by analysts.** The incumbent and the ground truth; the reason this is worth
  automating is that 400 submissions is weeks of work.
- **Frontier LLM with reasoning on.** Measured better on stance (22/24) and worse on substance
  (14/24), at roughly 14x the cost and 80x the latency in the same study. Reasonable as the
  escalation path for low-confidence and `mixed` cases.
- **Keyword and template matching.** Genuinely useful for detecting coordinated campaigns —
  identical text is an exact-match problem — and useless for stance.
- **Topic models / embeddings.** Cluster submissions by subject; cannot separate "supports" from
  "opposes" on the same subject.
- **Trained classifier on past consultations.** The right long-run answer where an agency has
  years of coded responses. Jev is for the first consultation.

## Sources

- https://lindfors.no/blog/a-first-look-at-typesafes-jev/ — accessed 2026-09-19
- https://github.com/mahlernim/jev-korean-benchmark — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
