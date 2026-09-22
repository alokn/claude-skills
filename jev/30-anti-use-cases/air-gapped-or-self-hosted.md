---
id: au-air-gapped-or-self-hosted
title: Do not plan on running jev air-gapped, on-prem, or from open weights
verdict: no
domain: ops
decision_shapes: [classification, detection, routing]
primitives: [choice, score, noul]
evidence_level: community-report
sources:
  - https://github.com/qte77/doc-pipeline-engine/issues/196  ("don't adopt": proprietary API-only, no self-hosting or open weights, air-gapped design goal)
  - https://docs.typesafe.ai/models.md  (hosted API; rate limits; data handling)
  - https://news.ycombinator.com/item?id=49717558  (local-first objections; open reimplementations)
related: [au-zero-data-retention-regulated-data, au-availability-and-rate-limits, au-private-knowledge-not-in-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to build jev into a product that has to run air-gapped?" Also "can we self-host jev
behind our firewall?", "are the weights open?", "our customers are on-prem, can we ship this?", "is there
a VPC deployment?".

## Verdict

**No.** jev is a hosted API. No self-hosting option, no open weights, and no published SLA appear in the
documentation reviewed on 2026-09-19. A team that hit this documented the reasoning: `qte77`'s
doc-pipeline-engine issue #196 (2026-09-19) records a "don't adopt" decision on the grounds that jev is
proprietary and API-only, with no self-hosting or open weights, which "conflicts with an air-gapped local
design goal" — and separately that the pipeline needed open-ended extraction rather than bounded label
sets. If the deployment constraint is hard, the evaluation stops here; nothing about accuracy, price or
latency can change it.

Not a model failure: **deployment** veto.

## What jev would get wrong

Not a model failure but a deployment one, and it shows up late if you let it. The characteristic mistake
is prototyping against the hosted API, proving the decisions work, and then discovering that the target
environment has no egress — at which point there is nothing to port, because the artefact you validated
is a service, not a model you hold. Two of the four documented don't-adopt decisions in this corpus cite
hosting or retention, and the local-first objection is a recurring community theme: "I don't really want
to bounce all my home automation commands to the cloud."

## What stays in code

The portability decision, made first. Write the constraint down before the spike: egress allowed or not,
data residency, retention, and whether a customer-hosted tier is on the roadmap. Then keep the decision
layer behind an interface with at least two implementations — a hosted-jev adapter and a local adapter —
so the questions, criteria and thresholds are assets that outlive the provider. Everything the corpus
recommends anyway (filtering, arithmetic, lookups, the authoritative rules) already lives in code and is
portable by construction.

## Numbers

No self-host price, no on-prem tier, and no SLA are published (https://docs.typesafe.ai/models.md, read
2026-09-19). The hosted service is documented at 250,000 tokens per second and 1,200 requests per minute,
with the note that "the limits above can change without notice". On the local side, the ecosystem carries
15+ open reimplementations by 2026-09-19 — openjev, NanoJev, Laya, kev, jevlike, LitJev, SemIf, reflex,
Verdict-open-jev — but their own authors are careful: openjev states "No matched performance comparison
against Jev … has been completed", and NanoJev's navigation figures (95%, 19/20) are self-reported and
task-specific. Treat them as category evidence, not as drop-in equivalents.

## When the verdict flips

It flips to **conditional** for a hybrid split: if some tenants or some data classes may leave the
network, route those to jev and everything else to a local classifier behind the same interface, and
measure the two paths separately rather than assuming parity. It flips outright if TypeSafe ships a
self-hosted or VPC tier — re-verify the models and legal pages, since this corpus is pinned to
2026-09-19. Otherwise, for a genuinely air-gapped product, **no rewrite exists**.

## Alternatives considered

- **Regex / deterministic**: runs anywhere, and where it fits it is the answer.
- **Small LLM**: a quantised 1-8B model on local hardware is the realistic substitute; slower, and you
  own the serving.
- **Frontier LLM**: same egress problem, larger.
- **Fine-tuned classifier**: a distilled encoder is small, fast, auditable and yours — the strongest
  option for air-gapped deployments with labels available.
- **Embeddings**: local embedding models are mature and solve the retrieval half.
- **Human**: unchanged by hosting; still the fallback for the uncertain band.

## Sources

- https://github.com/qte77/doc-pipeline-engine/issues/196 — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://news.ycombinator.com/item?id=49717558 — accessed 2026-09-19
