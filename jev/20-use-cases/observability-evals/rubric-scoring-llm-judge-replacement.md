---
id: uc-observability-evals-rubric-scoring-llm-judge-replacement
title: Run a fixed eval rubric with jev instead of a frontier LLM judge
verdict: good
domain: observability-evals
decision_shapes: [scoring, classification, verification]
primitives: [noul, score, choice]
evidence_level: community-report
sources:
  - https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals  (6,003 rubric checks; jev $160/M verdicts at 91.5% agreement with Claude Fable 5.1; Fable 5.1 $33,000/M; GPT-5.6 Luna $400/M; DeepSeek V4.1 Flash $260/M at 93.5%; forced answers with no abstention option; "context rot")
  - https://arize.com/blog/typesafe-jev-llm-judge/  (System One models give "much less directional signal of how to improve")
  - https://github.com/zhuyansen/jev-search-rerank-eval  (judge circularity: +0.053 under jev-only labels, -0.028 under Haiku-only labels)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-observability-evals-judge-every-trace-sample-failures, uc-observability-evals-confidence-threshold-calibration-fitting, uc-verification-llm-output-policy-check, uc-agents-harness-agent-trace-classification, au-zero-hallucination-means-always-right]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev as the judge in our eval suite?" Also: "our LLM-judge bill is
bigger than our inference bill — can jev score the rubric instead?", "can we run the eval on
every row instead of a 200-row sample?", "is jev as good a judge as Fable?"

## Verdict

**Good.** This is the best-evidenced eval use of jev and the numbers are real, but read them
precisely — and note the provenance: the source is a **vendor-integration post**, which this
corpus's source-reliability table rates **high bias risk**, so this entry is `community-report`,
not `independent-benchmark`. Over 6,003 rubric checks, jev cost **"$160 per million verdicts"** and agreed with
Claude Fable 5.1 **91.5%** of the time, against Fable 5.1 at **$33,000/M**, GPT-5.6 Luna at
**$400/M**, and DeepSeek V4.1 Flash at **$260/M at 93.5% agreement**
(langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals). Two things follow, and both
keep this off `strong`. First, **agreement with Fable 5.1 is not accuracy** — it measures
similarity to another model's opinion, not correctness. Second, **the cheaper LLM agreed
more**: DeepSeek V4.1 Flash beat jev on agreement at $260/M against $160/M, so the honest
claim is a 1.6x price advantage over the nearest cheap judge at 2 points lower agreement, not
a 206x advantage over Fable.

## What jev decides

One rubric criterion per question, all in one call. State is the eval row and nothing else:
`{"user_request": ..., "system_output": ..., "reference_answer": ...}` — filtered, never the
whole trace.

```
answers_the_question: Noul
  instructions: "Does `system_output` answer what `user_request` actually asked, rather than
                 a neighbouring question?"

contradicts_reference: Noul
  instructions: "Does `system_output` state anything that `reference_answer` contradicts?"
  criteria: {true: "A specific factual conflict, not a difference of emphasis or wording."}

tone_matches_policy: Noul
  instructions: "Is the reply written in the register the policy requires?"

helpfulness: Score
  criteria: ["Unusable.", "Partially useful; the user must ask again.",
             "Fully resolves the request."]
```

Keep one criterion per question and write the `false` text as the near-miss that your
incumbent judge keeps getting wrong. Do **not** ask jev to produce an overall verdict — weight
and combine the dimensions in code, so a rubric change is a config change.

The confidence band is the point of using jev at all: rows below your fitted threshold go to
an LLM judge or a human. Langfuse's setup did not have that — they report **forced answers
with no abstention option**, which is worth avoiding in yours.

Closest jaggedness mode: **5, context rot** — Langfuse names it directly, "accuracy drops with
irrelevant input". Send the filtered row, not the conversation.

## What stays in code

Sampling, the dataset, the pass/fail arithmetic, the score weighting, the regression
comparison between runs, and every deterministic check (JSON validity, schema conformance,
required-field presence, latency, refusal-string matching). Those are exact and free; do not
spend a model call on them. Also in code: storing the probability alongside the verdict, so a
threshold change does not require a re-run.

## Numbers

Verbatim, from the Langfuse post citing Good Start Labs (2026-09-18), 6,003 rubric checks:

| Judge | Cost per million verdicts | Agreement with Claude Fable 5.1 |
|---|---|---|
| TypeSafe jev | $160 | 91.5% |
| DeepSeek V4.1 Flash | $260 | 93.5% |
| GPT-5.6 Luna | $400 | not stated |
| Claude Fable 5.1 | $33,000 | (the reference) |

Method note for your own estimate: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`,
output free. A 3,000-character eval row plus four questions with criteria (~2,000 characters)
is about 1,250 tokens, **≈ $0.000053 per row**, which is why judging 100% of rows becomes
affordable where sampling was the only option before. The evidence base rates this source's
bias risk **high** — it is a vendor-integration post, and agreement with Fable 5.1 is not
accuracy.

## When the verdict flips

- **You let jev judge jev.** Measured self-preference: +0.053 NDCG@10 under jev-only labels
  versus −0.028 under an independent judge (zhuyansen/jev-search-rerank-eval). Discount any
  internal "jev agrees with jev" eval by about that much, or the verdict is **no**.
- **The eval must explain the failure.** Arize: System One models give "much less directional
  signal of how to improve". If your eval's job is to tell an engineer what to fix, keep the
  LLM judge — `au-generate-ticket-summaries` and the no-explanation limit apply.
- **The rubric requires counting, dates, or arithmetic.** Give it to code
  (`au-count-items-in-text`, `au-date-ordering-and-overdue`).
- **Your eval volume is a few hundred rows a week.** At that size Fable costs pennies and the
  cost argument disappears; this becomes **weak**.
- **The criterion is multi-hop** ("does the answer follow from step 3 given step 1?"). See
  `au-multi-hop-and-double-negatives`.

## Alternatives considered

- **Frontier LLM judge (Fable 5.1).** The reference. Explains itself, handles novel criteria,
  and cost $33,000/M verdicts in the same run. Keep it for the sampled tail.
- **Cheap LLM judge (DeepSeek V4.1 Flash).** The real competitor, and it *won on agreement* at
  93.5% for $260/M. Benchmark it against jev on your rubric before assuming jev wins.
- **String and schema assertions.** Free and exact; already the right answer for most of what
  people put in LLM judges.
- **Fine-tuned scorer.** Best ceiling per criterion, worst ergonomics when the rubric changes
  weekly, which rubrics do.
- **Human annotation.** The only actual ground truth, and the thing all of the above are
  agreeing *against*. Keep a standing human-labelled set or none of these numbers mean
  anything for you.

## Sources

- https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals — accessed 2026-09-19
  (6,003 rubric checks; $160/M at 91.5% agreement; Fable 5.1 $33,000/M; GPT-5.6 Luna $400/M;
  DeepSeek V4.1 Flash $260/M at 93.5%; forced answers, no abstention option; "context rot")
- https://arize.com/blog/typesafe-jev-llm-judge/ — accessed 2026-09-19
- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
