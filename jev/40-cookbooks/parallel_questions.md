---
id: cb-parallel_questions
title: Parallel questions
url: https://docs.typesafe.ai/cookbooks/parallel_questions.md
decision_shapes: [verification, classification, scoring]
primitives: [choice, score, noul]
related: [uc-legal-compliance-regulatory-briefing-parallel-questions, uc-legal-compliance-regulatory-requirement-verification, uc-observability-evals-rubric-scoring-llm-judge-replacement]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Run a 13-question regulatory briefing over one long document and measure whether it
matters that the questions are batched into a single call. The cookbook's own summary:
"Runs a 13-question regulatory briefing over the GDPR Wikipedia article, showing that
batching every question into one TypeSafe call is 12.2x cheaper and 10.0x faster with no
change in answers."

Dataset: the English Wikipedia article "General Data Protection Regulation", fetched as
plain text from pinned revision `1363040264` ("as of 2026-07") at
`https://en.wikipedia.org/?oldid=1363040264`. Size: `53,777 characters` (the prose calls
it "\~54,000 characters, a document-dominated workload where the document is most of
every request"). One document, 13 questions, no labelled ground truth. Model:
`TYPESAFE_MODEL = "jev-1.12"`. Price constant: `PRICE = (0.042, 0.00)` "$ per 1M tokens
(input, output); TypeSafe jev-1.12 as of 2026-09". Run date of the API calls: not
reported beyond those dates; calls are cached in `json_cache.json` shipped with the
cookbook.

## Decomposition (state, questions, how answers are combined)

State is the whole article under one key, byte-identical in every call:

```python
state={"article": DOCUMENT}   # DOCUMENT = {"source": <oldid url>, "text": <53,777 chars>}
```

13 questions: 8 `Noul`, 2 `Choice`, 3 `Score`. Representative quotes:

```python
"breach_72h": Noul(instructions="Must a personal data breach be reported to the
    supervisory authority within 72 hours?")
"us_federal_law": Noul(instructions="Is the GDPR a United States federal law?")
"instrument_type": Choice(instructions="What kind of EU legal instrument is the GDPR?",
    criteria={"Regulation": "Directly binding law in all member states, no national
    implementation needed.", "Directive": "...", "Treaty": "...", "Recommendation":
    "Non-binding guidance."})
"penalty_severity": Score(instructions="How severe are the penalties the GDPR provides
    for non-compliance?", criteria=["None: no penalties of any kind.", "Symbolic: ...",
    "Substantial: fines large enough to matter to most companies.", "Severe: fines
    scaled to global revenue, material even to the largest companies."])
```

The other Noul keys: `applies_non_eu` (extraterritorial scope), `dpo_all_orgs` (must
every org appoint a DPO), `pre_ticked_consent` (is pre-ticked consent valid),
`right_erasure`, `data_portability`, `criminal_penalties`. The other Choice key:
`max_fine` (4 labels, `TwentyM_or_4pct` / `TenM_or_2pct` / `FixedCap` / `NoFines`). The
other Score keys: `individual_rights` (4 levels), `compliance_burden` (5 levels).

Answers are not combined into a verdict. Each answer is reduced to one tracked number,
then compared across two batching strategies:

```python
METRIC = {Noul: "p(yes)", Choice: "max prob", Score: "normalized score"}
# Score is normalized: answer.score / (len(QUESTIONS[key].criteria) - 1)
batched = [priced(ask(tuple(QUESTIONS), run)) for run in range(RUNS)]   # 1 call x 5
singles = [{key: priced(ask((key,), run)) for key in QUESTIONS} for run in range(RUNS)]
```

`RUNS = 5` repeats per strategy. Cost is applied after retrieval:
`input_tokens / 1e6 * PRICE[0] + output_tokens / 1e6 * PRICE[1]`. No thresholds, no
confidence bands, no abstain path — the comparison is mean and run-to-run std dev per
question under each strategy.

## Numbers reported (verbatim, with what they compare against and the run date if given)

Cost and speed, averaged over the 5 runs:

| batching | calls | cost | total time |
|---|---|---|---|
| one call, all 13 | 1 | $0.000497 | 0.27s |
| 13 calls, one each | 13 | $0.006090 | 2.71s |

"batching: 12.2x cheaper, 10.0x faster". The prose also states "the 13x token cost
stays" if the single calls are fired concurrently.

Per-condition token counts: not reported as raw numbers. The cookbook captures
`response.usage.input_tokens` / `output_tokens` and caches them, but prints only the
derived cost above.

Agreement between batching strategies (mean / std dev over 5 runs, batched vs single):
`breach_72h` p(yes) 0.804 vs 0.814, std 0.0055 vs 0.0055; `criminal_penalties` 0.108 vs
0.108, std 0.0045 vs 0.0084. The other eleven questions returned identical means with
`std dev exactly 0.0` under both strategies: `applies_non_eu` 0.990, `dpo_all_orgs`
0.030, `pre_ticked_consent` 0.040, `right_erasure` 0.990, `data_portability` 0.990,
`us_federal_law` 0.010, `instrument_type` max prob 1.000, `max_fine` 1.000,
`individual_rights` 1.000, `penalty_severity` 1.000, `compliance_burden` 0.750.

Accuracy against a gold label: not measured. Comparison against named LLMs: none —
this cookbook compares jev against itself under two batching strategies.

## Caveats the cookbook itself states

- TypeSafe's own primitives page summarises this experiment as 11.5x cheaper and 9.6x faster rather than the 12.2x / 10.0x stated here; treat the ratio as roughly 10-12x, not a precise constant (source: https://docs.typesafe.ai/primitives.md).

- The speed figure is serial: "the figure sums the 13 single-call latencies, so it
  assumes they run one after another. Fire them concurrently and the gap shrinks, but the
  13x token cost stays."
- The saving is a property of the workload, not of jev: "The document dominates every
  request... The bigger the document, the nearer that saving comes to a full Nx."
- Two questions do carry noise (`breach_72h`, `criminal_penalties`); the claim is only
  that "The noise is a property of the question, not of how you batch."
- Prices are pinned and historical: `$0.042` per 1M input tokens "as of 2026-09"; the
  document is a pinned revision "so the document and its numbers stay fixed even as the
  live article gets edited".
- Answers are cached; re-rendering replays the published numbers rather than re-measuring.

## Lessons transferable to other use cases

- Fan-out: one call, many questions. Each question is scored independently against the
  state, so "no question's answer depends on the 12 other questions sharing its request."
  This is the load-bearing property; the cost multiple follows from it.
- The cost win scales with how document-dominated the workload is. N questions over a
  short state will not approach Nx.
- Mixed primitives in one request: Noul, Choice and Score can share a state and a call.
- Reducing every answer to one comparable number (p(yes), max prob, normalized score) is
  what makes a batching A/B testable at all — reusable for any consistency check.
- Measure run-to-run std dev before trusting a threshold: most answers here are exactly
  stable, but not all, and the unstable ones are unstable regardless of batching.
- Does not generalise: the 12.2x/10.0x figures are specific to this article, this
  question set, and serial single calls.

## Use-case entries this supports

- `uc-legal-compliance-regulatory-briefing-parallel-questions` — answer a fixed checklist of
  compliance questions over one long document in a single call
- `uc-legal-compliance-regulatory-requirement-verification` — verify stated facts about a legal
  instrument against its text, one question per requirement
- `uc-observability-evals-rubric-scoring-llm-judge-replacement` — score one document on several
  written rubrics at once

**Anti-use-case implied:** no corpus entry covers it — sending one request per question over the
same large document pays the document's tokens N times (`$0.006090` vs `$0.000497` here) for
answers that were near-identical, not identical: eleven of the thirteen questions returned
identical means at std dev 0.0, and the other two differed by 0.010 (`breach_72h` 0.804 batched vs
0.814 single) and 0.000 (`criminal_penalties`).
