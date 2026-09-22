---
id: uc-data-ml-systematic-review-screening
title: Screen papers against inclusion and exclusion criteria for a systematic review
verdict: good
domain: data-ml
decision_shapes: [detection, classification, routing]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Scientific discovery: "Screen papers against inclusion and exclusion criteria for systematic reviews")
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (a criteria battery over one document in one call; run-to-run std devs)
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with stakes)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  ("Bad = TRUE" framing; max gate rather than a mean)
related: [uc-verification-document-completeness-checklist, uc-data-ml-map-reduce-corpus-labelling, uc-data-ml-transcript-coding-codebook]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for title-and-abstract screening?" Also: "we have 12,000 records
and two reviewers", "can jev do the first pass of a PRISMA screen?", "how do we keep recall high
enough to be defensible?"

## Verdict

**Good**, as a recall-biased first pass with a human confirming every exclusion near the
boundary. The use-case map names the task; no cookbook measures it, so the design below is the
criteria-battery pattern applied. The methodological condition is the whole design: in screening,
a false exclude is unrecoverable and a false include costs ten minutes of reading, so the
thresholds must be asymmetric and the excluded-but-uncertain band must go to a human.

## What jev decides

State is the record — title, abstract, and the structured fields that exist. One request per
record carries every criterion.

Inclusion criteria as Nouls, each stating both sides:

```python
"population_match": Noul(
  instructions="Does the study population consist of adults aged 18 or over with a diagnosis of type 2 diabetes?",
  criteria=NoulCriteria(
    true="The abstract states the participants are adults with type 2 diabetes.",
    false="The population is different, or the abstract does not say who the participants were."))
"has_control_group": Noul("Does the study compare the intervention against a control or comparison condition?")
"reports_primary_outcome": Noul("Does the study report HbA1c or another glycaemic outcome?")
```

Exclusion criteria framed so `true` means exclude — the cascade cookbook's "Bad = TRUE" rule, "so
the threshold has one meaning across all heads":

```python
"is_not_primary_research": Noul("Is this a review, editorial, protocol, commentary, or conference abstract rather than a primary study?")
"is_animal_or_in_vitro": Noul("Is this an animal or in vitro study rather than a study in humans?")
```

Plus one Score to rank the uncertain pile for reviewer attention:

```python
"eligibility_evidence": Score(instructions="How clearly does the abstract establish that this study meets the review's criteria?",
  criteria=["The abstract contradicts the criteria", "The abstract does not say enough to tell",
            "The abstract suggests it fits but leaves a criterion unstated", "The abstract states every criterion explicitly"])
```

Three outcomes, not two: auto-include for full-text retrieval, auto-exclude only where every
inclusion head is confidently low *and* an exclusion head fires, and a human queue for everything
else, ranked by `eligibility_evidence`.

## What stays in code

The search strategy and the database exports, deduplication by DOI and title, the date and
language limits (mode 3 — never ask jev whether a year is in range), the PRISMA counts, the
threshold per criterion, the audit log of every automated exclusion, and the reviewer queue.
Screening decisions must be reproducible and reportable; keep the probabilities.

## Numbers

Cost: a title plus abstract plus a ten-criterion battery is roughly 700 input tokens, about
$0.00003 per record at $0.042 per million input tokens with output free — about $0.36 for 12,000
records. Latency 70-500 ms per record, so a full screen is minutes of wall clock inside the rate
limits (250k tokens/s, 1,200 requests/min, dynamic). Every criterion rides one call: the
parallel-questions cookbook measured 13 questions over one document as one call at $0.000497
against 13 calls at $0.006090, "12.2x cheaper, 10.0x faster", with identical answers.

Stability is the property that makes a screen auditable: in that run, eleven of thirteen
questions returned identical means with "std dev exactly 0.0" across five runs, and the two noisy
ones were noisy regardless of batching — worth checking per criterion before you let one gate an
exclusion.

**No sensitivity or specificity figure is published for jev on screening.** Do not claim one.
Calibrate on a completed review where you already have the human decisions, report recall at your
chosen threshold on that gold set, and set the auto-exclude threshold from it.

Closest jaggedness modes: **1, literal reading** — criteria written for reviewers assume tacit
knowledge; and **3, dates** — publication windows are code's job.

## When the verdict flips

- **The criterion is structured** — publication year, study design tag, language, MeSH term.
  Filter in code. Exact, free, and reportable.
- **You let it auto-exclude without a human check on the boundary.** For a published systematic
  review that is **no**; recall is the metric the method stands or falls on.
- **The abstract does not contain the answer.** Many eligibility criteria are only decidable from
  the full text. Screening at abstract level has a ceiling that no model removes.
- **The review is small** (a few hundred records). Two human screeners are affordable and the
  calibration work costs more than it saves — **weak**.
- **Non-English literature is in scope.** Lower accuracy outside English; screen those separately.
- **The criteria involve counts or thresholds** ("at least 50 participants", "followed for 12
  months or more"). Extract as a Choice over enumerated parts and compare in code (modes 2, 3).

## Alternatives considered

- **Boolean search filters in the database** — the first line and it should stay; precise on
  metadata, hopeless on "was there a control group".
- **Active-learning screening tools (ASReview, Abstrackr, Rayyan)** — purpose-built, validated in
  the literature, and the strongest alternative: they learn from the reviewer's own decisions as
  screening proceeds. Jev needs no seed labels and states its criteria in English; the two
  combine well, with jev's probabilities as an extra feature.
- **TF-IDF / SVM classifier on a seed set** — cheap and effective once a few hundred decisions
  exist; useless at record one.
- **Frontier LLM screening** — capable and costly at 12,000 records. Run-to-run variation is the
  thing to measure for a review's reproducibility requirement, on whichever model you pick: the
  choices cookbook found `claude-haiku-4-5` at temperature 0 *more* repeatable than jev.
- **Two human screeners with adjudication** — the reference standard, and what the uncertain band
  should still reach.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
