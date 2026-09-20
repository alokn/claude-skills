---
id: uc-legal-compliance-regulatory-briefing-parallel-questions
title: Answer a fixed regulatory briefing checklist over one long document in a single call
verdict: good
domain: legal-compliance
decision_shapes: [verification, classification, scoring]
primitives: [noul, choice, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13-question GDPR briefing; 53,777 characters; one call $0.000497 / 0.27s vs 13 calls $0.006090 / 2.71s; "12.2x cheaper, 10.0x faster"; per-question agreement; jev-1.12)
  - https://docs.typesafe.ai/patterns/fan-out.md  (all questions in one request; parallel evaluation makes latency "barely change")
  - https://docs.typesafe.ai/concepts/use-case-map.md  (legal and compliance: classify and verify regulatory filings)
  - https://docs.typesafe.ai/models.md  (64k per request, 32k for state plus the longest single question; $0.042 per million input tokens, output free)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5 context rot; failure mode 9 generation)
related: [uc-legal-compliance-regulatory-requirement-verification, uc-legal-compliance-document-type-classification, cb-parallel_questions, df-cost-model, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to run our standard regulatory briefing questions over a
document?" Also asked as "can jev answer the same 20 compliance questions across every new
regulation we track?", "should we batch the questions or ask them one at a time?", and "can
jev replace the LLM call that summarises a regulation for our compliance memo?".

## Verdict

**Good** — the shape is demonstrated by the `parallel_questions` cookbook, which
measures batching and not accuracy; no task-matched labelled accuracy is published;
shadow-evaluate against the incumbent before acting. This is the cookbook. TypeSafe runs
a 13-question regulatory briefing over the GDPR Wikipedia article and measures batching
against sequential calls: one call is "12.2x cheaper and 10.0x faster with no change in
answers". The shape is a fixed checklist of bounded questions over one document — eight
Nouls, two Choices, three Scores — with no generation anywhere. The one thing it cannot
be is the memo itself: jev does not write prose (failure mode 9). It fills the answer
fields; an LLM or a human writes the narrative around them, if one is needed at all.

## What jev decides

State is the document under one key, byte-identical for every question. The cookbook's is
`state={"article": DOCUMENT}` where `DOCUMENT = {"source": <oldid url>, "text": <53,777
chars>}`.

Thirteen questions, verbatim from the cookbook, which are worth copying as a template for
your own register:

```
breach_72h:      Noul("Must a personal data breach be reported to the supervisory
                      authority within 72 hours?")
us_federal_law:  Noul("Is the GDPR a United States federal law?")     # a negative control
applies_non_eu, dpo_all_orgs, pre_ticked_consent, right_erasure, data_portability,
criminal_penalties: Noul(...)

instrument_type: Choice("What kind of EU legal instrument is the GDPR?",
  criteria={"Regulation": "Directly binding law in all member states, no national
                           implementation needed.",
            "Directive": "...", "Treaty": "...",
            "Recommendation": "Non-binding guidance."})
max_fine:        Choice(4 labels: TwentyM_or_4pct / TenM_or_2pct / FixedCap / NoFines)

penalty_severity: Score(criteria=["None: no penalties of any kind.",
                                  "Symbolic: ...",
                                  "Substantial: fines large enough to matter to most companies.",
                                  "Severe: fines scaled to global revenue, material even to
                                   the largest companies."])
individual_rights: Score(4 levels)
compliance_burden: Score(5 levels)
```

Include a negative control like `us_federal_law` in your own set. It costs nothing, it runs
in the same call, and a wrong answer on it tells you the state or the question set has
drifted.

Bands: the cookbook does not route on confidence — it measures stability. For a production
briefing, gate per question by what the answer drives: a Noul feeding a "does this apply to
us" flag can act at `P ≥ 0.8` / `≤ 0.2` with the middle to a reviewer; a Score feeding a
prioritisation only needs to rank.

## What stays in code

Fetching and pinning the document — the cookbook pins Wikipedia revision `1363040264`, which
is the discipline that makes a re-run comparable. Chunking. A 32k-token ceiling applies to
`state` plus the longest single question, so a full regulation in the tens of thousands of
words must be split by article in code, with the per-chunk answers combined in code
(`any`, `all`, max). Effective dates, transition periods and filing deadlines. The memo
itself, if a human needs one. Storage of `{answers, probabilities, model version, document
revision}` so a later re-run is a diff rather than a re-read.

## Numbers

From `cookbooks/parallel_questions.md`, `TYPESAFE_MODEL = "jev-1.12"`, document 53,777
characters ("~54,000 characters, a document-dominated workload where the document is most of
every request"), price constant `PRICE = (0.042, 0.00)`, averaged over 5 runs:

| batching | calls | cost | total time |
|---|---|---|---|
| one call, all 13 | 1 | $0.000497 | 0.27s |
| 13 calls, one each | 13 | $0.006090 | 2.71s |

"batching: 12.2x cheaper, 10.0x faster". The cookbook also notes that firing the 13 single
calls concurrently removes the latency penalty but "the 13x token cost stays" — you re-send
the document once per question.

Answers do not move between the two strategies. `breach_72h` p(yes) was 0.804 batched vs
0.814 single (std 0.0055 both); `criminal_penalties` 0.108 vs 0.108 (std 0.0045 vs 0.0084).
"The other eleven questions returned identical means with std dev exactly 0.0 under both
strategies."

The cookbook's own caveat matters for how you cite it: accuracy against a gold label was not
measured, and no named LLM baseline was run — "this cookbook compares jev against itself
under two batching strategies". Treat the 12.2x as a batching result, not an accuracy or a
vendor-comparison result.

## When the verdict flips

- The deliverable is the prose memo. That is generation; jev supplies the fields, an LLM
  writes the text.
- The document exceeds the state budget and cannot be chunked meaningfully because the
  answers depend on cross-references between distant articles. That is multi-hop over a large
  state — the two failure modes that compound worst together.
- The questions change per document. The economics here come from a *fixed* checklist run
  many times; a bespoke question set per document is a research task for a reasoning model.
- You need the answer to be authoritative for a filing. It is an input to counsel's view.

## Alternatives considered

- **Frontier LLM with a long-context prompt.** Can answer all 13 and write the memo, at
  seconds and cents per document, with the answers embedded in prose you have to parse. The
  cookbook's comparison is jev-to-jev, so treat any accuracy comparison as unmeasured.
- **Small LLM (Haiku-class).** Same shape, cheaper than frontier, still seconds, and no typed
  per-question probability unless you read logprobs.
- **Regex / keyword search over the regulation.** Answers "does the word 'erasure' appear",
  which is not the question. Useful only to locate the article to chunk.
- **Fine-tuned classifier.** There is no training set; each regulation is one document. Wrong
  tool.
- **Embeddings / RAG.** The right way to select which articles go in the state when the
  document is too long. Not a substitute for the questions.
- **Human analyst.** Stays. The realistic effect is that the analyst starts from thirteen
  filled fields with probabilities attached rather than a blank template.

## Sources

Accessed 2026-09-19. `cookbooks/parallel_questions.md` (question set, 53,777 characters, cost
and time table, 12.2x / 10.0x, per-question agreement and std devs, "accuracy against a gold
label: not measured"; `jev-1.12`), `patterns/fan-out.md`, `concepts/use-case-map.md`,
`models.md` (64k/32k limits, price), `model-jaggedness/jev-1.13.md` (modes 5 and 9).
