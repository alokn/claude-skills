---
id: df-cost-model
title: Cost and latency model — how to estimate a jev integration honestly
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/models.md  ($42 per billion / $0.042 per million input tokens; output free; 250k tok/s and 1,200 rpm; 64k/32k context)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (70-500 ms; comparison table; "on the higher end of real world gains")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Most queries complete in about 100 ms")
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13 questions in one call: 12.2x cheaper, 10.0x faster than sequential)
  - https://docs.typesafe.ai/introduction/quickstart.md  (usage example: 312 input tokens for a short ticket + 3 questions)
related: [df-fit-test, df-alternatives, gt-limits-pricing-versions, gt-evals-official]
---

## The formula

```
input_tokens   ≈ characters(state) / 4 + Σ characters(each question) / 4
cost_per_call  = input_tokens × $0.042 / 1,000,000          # output tokens are free
latency        = one request; "about 100 ms" in TypeSafe's examples, 264-455 ms medians in independent
                 runs, higher from Europe. Adding questions "barely changes" it per the docs (low
                 incremental cost, not zero). Not an SLA: measure p50/p95/p99 from your region
calls_per_item = 1 if all questions share one state and fit the request budget (speculative fan-out);
                 more when an answer determines what evidence to fetch next, when candidates must be
                 sharded across requests (e.g. one Noul per (query, candidate) pair in the measured
                 rerank recipe = 30 calls/query), or when the state + questions exceed 32k tokens
```

Reference point from the quickstart: a ~120-character ticket with three questions used 312 input
tokens, so about $0.000013. A 1,500-token record with eight structured questions is roughly 2,000
tokens, about $0.00008.

## Rules for quoting numbers

1. **Show the inputs.** Tokens per call, calls per item, and where the volume comes from (a cron
   schedule, a queue depth, a request handler's traffic). A ratio with no inputs is marketing.
2. **Volume unknown means per-call only.** Write "≈ $0.00008 per item; volume not measured" rather
   than inventing a monthly figure.
3. **Current costs are looked up, not recalled.** LLM prices change; fetch the provider's page and cite
   it. Heuristics cost $0 in compute; their cost is maintenance, misroutes, and human review time, and
   you should name which one you are counting.
4. **Batch before you compare.** TypeSafe measured 13 questions over one document as roughly 10-12x
   cheaper and faster in one call than as 13 sequential calls, with near-identical answers (mean
   probability 0.804 vs 0.814; the cookbook says 12.2x / 10.0x, the primitives page 11.5x / 9.6x for the
   same experiment). Compare the batched
   design, and design for batching.
5. **Do not quote TypeSafe's headline multipliers as your expectation.** The launch post's 193.6x faster
   and 444.6x cheaper come from its own workflow evals and the post says they are "on the higher end of
   real world gains." A survey of 12,759 public posts found self-reported medians of about 7x speed and
   30x cost, but from a selection-biased sample (only 24% of posts were from people who had tried jev,
   and only 215 / 180 posts carried a figure). Treat those as retrospective anecdotes, not a prospective
   range. The only defensible estimate is computed from your own state size, question count, incumbent
   price, and measured end-to-end latency.
6. **Accuracy is not part of the cost case** unless you measured it on your data. Nor is run-to-run
   consistency: TypeSafe's own choices cookbook found Claude Haiku 4.5 at temperature 0 more repeatable
   than jev. The case rests on cost, latency, schema safety, and a confidence signal you can route on
   once you have measured its calibration on your distribution.
7. **Count the operational costs of a hosted early-access API**: timeout and retry cost, the fallback
   path that must exist for 429/529 and outages, regional latency, and rate-limit throttling in batch
   jobs. See fit-test Question 0.

## What drives cost up

- Sending the whole record when the questions need three fields. Filter in code; it also improves
  accuracy (failure mode 5).
- Repeating the state across separate calls instead of fanning questions out in one.
- Two-stage designs (rank all, then re-judge the top few) double the calls per item; still cheap, but
  count them.
- Rate limits: 250,000 tokens per second and 1,200 requests per minute per account at the time of
  writing, adjusting dynamically. A batch job over a million rows needs a throttle and the SDK's
  retry-with-backoff. Higher limits are on enterprise plans.

## Latency budgeting

- Inline UI (as-you-type, form validation): budget 300-600 ms end to end including your network hop.
  One public deployment reported a 600 ms p95 with an 800 ms hard timeout and a deterministic fallback.
- Request path (triage on create, routing): fine at typical 100-500 ms; always have the fallback path.
- Batch: per-call latency matters less than throughput, which is bounded by rate limits (1,200 requests
  per minute at the time of writing), retries on 429/529, and concurrency; a million-row job at the
  published limits needs roughly 14 hours of request budget before retries. Model it.
- Real-time control loops (games, agents at 2-10 Hz): possible, as the launch demos show (~$7/hour at
  10 queries/second); each query must carry compact structured state, not raw logs.

## Costs the formula leaves out

- The fallback fraction: every item routed to a human or a reasoning model at low confidence carries
  that path's cost. A design that "abstains" 35% of the time is not 35% cheaper; it is 35% incumbent cost.
- Retries and timeouts on a hosted early-access API, and the engineering cost of the fallback path itself.
- Calibration and monitoring effort: the labelled evaluation set, the shadow-mode logging, and the
  periodic re-check.

## Comparing against the incumbent

Results in the right-hand column are what published reports observed; they are not what you should
expect without measuring your own workload.

| Incumbent | What to measure | Results reported in public sources |
|---|---|---|
| Frontier LLM call for a label | $/call (in + out tokens), p50/p95 latency, parse-failure rate | TypeSafe's own workflow evals: $0.0004 vs $0.03-$0.18 per case and 0.4 s vs 10-38 s, on agreement with a two-model reference. Zero schema violations by construction. Accuracy: measure |
| Small LLM (Haiku-class) for a label | Same | Cost and latency lower; accuracy roughly tied in one public 149-row test; jev abstained far more often |
| Regex / keyword rules | Misroute rate, maintenance commits per quarter, human review time | Cost goes from $0 to cents per thousand; the case rests on misroutes and review time. If the decision is lexical, keep the regex |
| Human queue | Cost per decision, queue latency, agreement between reviewers | Only the uncertain band reaches humans; measure the share of items in the high-confidence band on historical decisions |
| Embeddings + threshold | Precision/recall at the threshold, tuning effort | No public measured comparison on entity matching; TypeSafe's entity-alignment cookbook reports an outcome split (8.9% merge / 11.1% review / 80% unlinked on 450 pairs) but no precision or recall. On retrieval ranking one public catalog test found no standalone win (−0.028 NDCG@10 under independent labels) but a fused-signal gain (+0.064 with bge-m3) |
