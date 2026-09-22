---
id: uc-observability-evals-judge-every-trace-sample-failures
title: Judge every production trace with jev and send only the flagged ones to an LLM judge
verdict: good
domain: observability-evals
decision_shapes: [classification, detection, routing, scoring]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://arize.com/blog/typesafe-jev-llm-judge/  (the hybrid recommendation; "much less directional signal of how to improve"; TypeSafe's own numbers "compare model outputs against reference probabilities from other models, rather than human-labeled ground truth"; Arize has not run its own benchmark yet)
  - https://github.com/zhuyansen/jev-search-rerank-eval  (judge circularity measured: +0.053 under jev-only labels, -0.028 under Claude Haiku 4.5 labels)
  - https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals  (6,003 rubric checks; $160/M verdicts at 91.5% agreement with Claude Fable 5.1)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-observability-evals-rubric-scoring-llm-judge-replacement, uc-agents-harness-agent-trace-classification, uc-verification-structured-extraction-cascade, uc-observability-evals-confidence-threshold-calibration-fitting, au-tiny-volume-human-reviewed-workflow]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to monitor all our production traces?" Also: "we sample 1% of
traces for LLM-judge review and miss everything — can jev cover 100%?", "how do we keep the
explanations if jev cannot explain?", "what is the right split between a cheap judge and an
expensive one?"

## Verdict

**Good.** This is an architecture, not a single decision, and it is the one Arize recommends:
jev scores **every** trace as it lands, and only the traces it flags — plus a random control
sample — go to an LLM judge that can say *why* (arize.com/blog/typesafe-jev-llm-judge/). The
mechanism is clear and the economics are the point: full coverage moves from impossible to
routine, while the expensive judge keeps doing the one thing jev cannot, which is explain.
It is `good` rather than `strong` because Arize states it **has not run its own benchmark
yet**, and because the evidence for the underlying scoring step is agreement with another
model rather than accuracy.

## What jev decides

State is the filtered trace summary, assembled in code: `user_request`, `final_output`,
`tool_names_called` (names only, not payloads), `turn_count` as an integer, and
`error_strings` if any. Never the whole trace — Langfuse names "context rot" as a real effect
and this is where it bites hardest.

```
user_got_what_they_asked: Noul
  instructions: "Does `final_output` give the user what `user_request` asked for?"
  criteria: {false: "It answers a neighbouring question, refuses, or stops partway."}

user_disagreed: Noul
  instructions: "In the later turns, does the user contradict, correct, or push back on the
                 assistant's answer?"
  criteria: {false: "The user asks a follow-up question without disputing the answer."}

loop_or_repetition: Noul
  instructions: "Do the tool names in `tool_names_called` show the same call repeated with no
                 progress between repeats?"

severity: Score
  criteria: ["Nothing wrong.", "Degraded but the user was served.",
             "The user was not served.", "The system did something it should not have."]
```

Routing, in code: anything flagged, plus everything in the uncertain band around your fitted
threshold, plus a fixed random percentage of the *unflagged* traces, goes to the LLM judge.
That control sample is not optional — it is the only way to measure jev's false-negative rate
in production, and without it you have built a filter you cannot audit.

Closest jaggedness mode: **5, large state full of irrelevant detail.** Avoided by summarising
the trace in code before the call.

## What stays in code

Trace assembly, redaction, sampling rates, the queue to the LLM judge, cost caps, aggregation
into dashboards, and every deterministic signal you already have: HTTP status, exception
class, token counts, latency percentiles, tool-call counts, and explicit user thumbs-down.
Those are exact. Use them to route *before* the call, not inside it.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A summarised
trace of ~2,500 characters plus four questions with criteria (~1,800 characters) is about
1,075 tokens, **≈ $0.000045 per trace**; multiply by your own trace volume, which this entry
does not supply. The published comparison for a rubric-judging workload is "$160 per million
verdicts" for jev against "$33,000" per million for Claude Fable 5.1
(langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals, 6,003 checks). The second stage
costs whatever your flag rate times the LLM-judge price is — that product, not the jev cost,
is the number to design against.

Arize publishes no accuracy figure and says so; the post is an aggregation of early
independent tests plus commentary. It also records the structural complaint that applies to
every number in this area: TypeSafe's own evals "compare model outputs against reference
probabilities from other models, rather than human-labeled ground truth".

## When the verdict flips

- **jev is both the system and the judge.** Measured self-preference is +0.053 NDCG@10 under
  jev-only labels against −0.028 under an independent judge
  (zhuyansen/jev-search-rerank-eval). If the traces being judged were produced by jev
  decisions, this is **no** — use a different model as the judge.
- **You drop the control sample.** Without it the false-negative rate is unobservable and the
  architecture is a black hole. Verdict drops to **weak**.
- **The flag rate is high.** If jev flags 40% of traces you have not reduced the LLM-judge
  bill, you have added a call. Fit the threshold first.
- **You need the explanation on every trace, not the flagged ones.** Then the cheap stage
  buys nothing; keep the LLM judge on a sample.
- **Trace volume is small.** Under a few thousand traces a month, judge them all with an LLM
  and skip the architecture (`au-tiny-volume-human-reviewed-workflow`).

## Alternatives considered

- **Sample and LLM-judge the sample.** The incumbent. Explains itself, misses everything
  outside the sample — which is the failure this design exists to fix.
- **Deterministic trace assertions** (status codes, exception classes, schema checks). Free,
  exact, and should run first. Blind to "answered a different question".
- **Cheap LLM as the first stage.** The honest competitor: in the Langfuse run DeepSeek V4.1
  Flash agreed 93.5% at $260/M against jev's 91.5% at $160/M. Benchmark both on your traces.
- **Embeddings plus outlier detection.** Good at "this trace is unlike the others", useless
  at "this trace failed the user".
- **Human review queue.** Stays as the destination for the top severity band and as the
  ground truth everything else is calibrated against.

## Sources

- https://arize.com/blog/typesafe-jev-llm-judge/ — accessed 2026-09-19 (hybrid architecture;
  "much less directional signal of how to improve"; reference-probability critique; no own
  benchmark run yet)
- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19 (judge
  circularity, +0.053 vs −0.028)
- https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
