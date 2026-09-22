---
id: au-latency-slo-outside-us
title: Do not write a latency budget from the published 70-500 ms if you are not near the US West Coast
verdict: weak
domain: ops
decision_shapes: [routing, classification]
primitives: [choice, score, noul]
evidence_level: community-report
sources:
  - https://github.com/AboveColin/HA-Jev  (latency "slower from Europe than the published 70 to 500 ms")
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  ("our published evals are generally run from our laptops on the West Coast")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Most queries complete in about 100 ms.")
  - https://github.com/wotai-dev/typesafe-jev-tools  (p50 455 ms measured, n=149)
related: [au-expect-headline-speed-cost-multipliers, au-real-time-from-raw-pixels, au-availability-and-rate-limits]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to promise a 200 ms end-to-end response using jev from our Frankfurt region?" Also
"can we put jev in the request path?", "what p95 should we plan for?", "is 100 ms real?".

## Verdict

**Weak** as a planning assumption outside the vendor's own region, until you have measured from where
your service actually runs. Three official numbers circulate — "Most queries complete in about 100 ms",
"End-to-end response time is 70ms-500ms for TypeSafe", and "Frontier intelligence at real-time speeds
(150ms)" — and the launch post says where they come from: "our published evals are generally run from our
laptops on the West Coast (this is where our service is currently based)." The Home Assistant integration
author, running from Europe, reports latency "slower from Europe than the published 70 to 500 ms". No
hosting region, no regional endpoints and no SLA are published.

Not a model failure: **deployment** veto — a hosting and network-path question, measured from
where your service runs.

## What jev would get wrong

Nothing about the answer; the risk is a design that only works at the advertised speed. Voice assistants,
inline editor hints, per-keystroke gating and tick-based control loops are all built around a latency
budget, and a round trip that doubles or triples in another continent turns a "fast enough" feature into
a visible pause. The second-order effect is worse: teams that discover this late compensate by batching
or by dropping the check, which changes the product rather than the infrastructure.

## What stays in code

The measurement and the fallback. Measure p50 and p95 from the region you will deploy in, on your own
payload sizes, before committing to a budget, and keep measuring in production. Put a timeout on the call
with a defined behaviour when it expires — the deterministic default, the previous answer, or a queue —
so the feature degrades rather than hangs. Batch questions into one call rather than chaining calls,
since the state is ingested once and every question is evaluated against it in parallel; and cache
repeated decisions on identical inputs.

## Numbers

Published: 70-500 ms end-to-end, "about 100 ms" typical, 150 ms in the use-case map. Measured
independently: p50 455 ms over 149 rows, against Claude Haiku 4.5 at 631 ms
(https://github.com/wotai-dev/typesafe-jev-tools, run 2026-09-18); median 176 ms and p95 336 ms on
100-item batches of synthetic scenes (iammrduncan/typesafe-ai-benchmark); median 0.643-0.674 s over 40
calls in a Japanese field report (dev.classmethod.jp, 2026-09-17); median 621 ms, range 479-1470 ms, in a
game loop (valentynkit/jev-plays-pokemon-red); and a survey median of 76 ms self-reported across 333
posts (openchamber.dev). The spread across those reports is roughly an order of magnitude, which is the
point.

## When the verdict flips

It flips to **good** once you have your own p95 from your own region and the design fits inside it with
headroom — and it is worth noting that even the slow measurements above beat frontier-model latency by a
wide margin, so a 400 ms jev call can still be the fast option. It flips back to **no** for hard real-time
paths (locks, alarms, control loops), where the integration author's own exclusion list applies
regardless of region.

## Alternatives considered

- **Regex / deterministic**: microseconds, in-process, no network. The only true real-time option.
- **Small LLM**: local inference removes the round trip; slower per token, faster end-to-end for some
  regions.
- **Frontier LLM**: seconds, measured repeatedly across this corpus; not a latency alternative.
- **Fine-tuned classifier**: in-process encoder, single-digit milliseconds, if you have labels.
- **Embeddings**: local vector lookup is fast; answers a different question.
- **Human**: not applicable at this latency.

## Sources

- https://github.com/AboveColin/HA-Jev — accessed 2026-09-19
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://openchamber.dev/blog/jev-typesafe-ai/ — accessed 2026-09-19
