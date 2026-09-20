---
id: au-availability-and-rate-limits
title: Do not put jev on a path that cannot tolerate rate limits or a waitlist
verdict: weak
domain: ops
decision_shapes: [routing, classification, detection]
primitives: [choice, score, noul]
evidence_level: community-report
sources:
  - https://docs.typesafe.ai/models.md  (250,000 tokens/sec, 1,200 requests/min; "the limits above can change without notice")
  - https://openchamber.dev/blog/jev-typesafe-ai/  (507 waitlist complaints in 12,759 posts)
  - https://github.com/valentynkit/jev-plays-pokemon-red  (calibration study cut short by rate limiting)
related: [au-latency-slo-outside-us, au-air-gapped-or-self-hosted, au-expect-headline-speed-cost-multipliers, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to make jev a hard dependency of checkout / login / our moderation queue?" Also "what
happens when we get a 429?", "can we run a 100,000-row backfill tonight?", "is capacity guaranteed?".

## Verdict

**Weak** for any path with no fallback, four days after launch. The documented limits are 250,000 tokens
per second and 1,200 requests per minute, with a `429 Too Many Requests` past either, and the docs add
the caveat themselves: "Rate limits are adjusting dynamically. We are serving a very large volume of
demand, and the limits above can change without notice." TechCrunch reports the company "briefly lost the
ability to serve users from its API because demand was so high", and a survey of 12,759 public posts
counted 507 waitlist complaints against 13 price complaints. No SLA is published.

Not a model failure: **deployment** veto.

## What jev would get wrong

Nothing — it will not be there. The interesting version of this failure is not an outage but a truncated
measurement: the `jev-plays-pokemon-red` author left calibration deliberately unpublished because the
study ran into rate limiting and ended at "n=5 turns with wide confidence intervals". That pattern
matters more than it looks. Rate limits shape which evaluations get finished, so the public evidence base
is skewed toward small samples, and your own calibration run — the one thing this corpus says you must do
before shipping — is exactly the kind of bursty workload that hits the limit first.

## What stays in code

The fallback, the backoff and the budget. Every call site needs a defined behaviour on `429` and on
timeout: the deterministic rule, the previous answer, a queue, or "escalate to human" — never an implicit
"allow". The SDKs "retry with backoff by default and honor the `retry-after` header when the response
carries one", which is the floor, not the design. For batch work, schedule under the requests-per-minute
ceiling with a token-bucket limiter rather than a thread pool, checkpoint progress so a partial run is
resumable, and spread calibration runs over hours. Alert on the 429 rate as a first-class metric.

## Numbers

250,000 tokens per second and 1,200 requests per minute, "measured in tokens per second and requests per
minute. A request over either limit returns `429 Too Many Requests`", with higher limits "available on
custom and enterprise plans" (https://docs.typesafe.ai/models.md, read 2026-09-19). 1,200 requests per
minute is 72,000 per hour, so a 500,000-item backfill at one call each takes about 7 hours at the ceiling
with zero headroom for production traffic. 507 waitlist complaints among 12,759 collected posts, 15-18
September 2026 (https://openchamber.dev/blog/jev-typesafe-ai/). One calibration study abandoned mid-run
(https://github.com/valentynkit/jev-plays-pokemon-red). Availability incident reported second-hand by
TechCrunch, 2026-09-18 — press, not a status page.

## When the verdict flips

It flips to **good** when the dependency is soft: a documented fallback on every call site, a measured
429 rate, headroom against both limits at peak, batch work throttled and resumable, and — for anything
revenue-bearing — enterprise limits negotiated in writing. It also flips as the service matures; this
entry is pinned to 2026-09-19, four days after launch, and capacity is the claim most likely to have
changed by the time you read it. Re-verify the models page before relying on this.

## Alternatives considered

- **Regex / deterministic**: no dependency, no limit; the natural fallback to code on 429.
- **Small LLM**: self-hosted capacity you control, at the cost of running it.
- **Frontier LLM**: a second provider is a real redundancy strategy, at 40-400x the price per call.
- **Fine-tuned classifier**: in-process, unlimited, once you have labels.
- **Embeddings**: local index, no external dependency.
- **Human**: the queue that absorbs the overflow, if it is sized for it.

## Sources

- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://openchamber.dev/blog/jev-typesafe-ai/ — accessed 2026-09-19
- https://github.com/valentynkit/jev-plays-pokemon-red — accessed 2026-09-19
- https://techcrunch.com — article dated 2026-09-18, accessed 2026-09-19
