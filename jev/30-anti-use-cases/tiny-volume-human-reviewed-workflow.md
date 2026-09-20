---
id: au-tiny-volume-human-reviewed-workflow
title: Do not add jev to a low-volume workflow a human already reviews
verdict: weak
domain: support
decision_shapes: [classification, routing]
primitives: [choice, noul, score]
evidence_level: community-report
sources:
  - https://github.com/wotai-dev/typesafe-jev-tools  ("If your code does not branch on the confidence value, none of this matters and you should use what you already have")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Use code when you can"; route on uncertainty)
  - https://docs.typesafe.ai/confidence.md  (three bands; the low band needs somewhere to go)
related: [au-archive-after-n-days-rule, au-expect-headline-speed-cost-multipliers, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to add jev to our partner-application review? We get about eight a week and a manager
reads every one." Also "can jev pre-classify our twelve daily escalations", "we want AI in this workflow
but the volume is small".

## Verdict

**Weak**, on the usual version of this workflow — but item count alone does not settle it. Jev's
advantages are throughput, latency and the ability to shrink a queue, and the thing they have to be
weighed against is total human effort per item, the cost of an error, the size of the backlog and how
long an item waits. Eight short applications a manager skims in two minutes each is the case this entry
is about: the effort saved is small, the error cost is absorbed by the reviewer, and nothing waits. Eight
*long* applications that take an expert an hour each, or a queue that sits overnight, or a decision whose
errors are expensive, is a different question and can be worth a pilot even at that volume. The test the
independent evaluation states still applies: "If your code does not branch on the confidence value, none
of this matters and you should use what you already have."
(https://github.com/wotai-dev/typesafe-jev-tools) Work out the effort, error cost and waiting time before
concluding from the count.

Not a model failure: **economic** veto — weighed on effort per item, error cost, backlog and
waiting time rather than on item count.

## What jev would get wrong

Not much, and that is beside the point. The costs are organisational rather than statistical. You take on
a vendor dependency, an API key, a rate limit, an outage path, and a model version that can move under you
when the `jev-latest` alias advances — all in a workflow whose current failure rate is a manager
occasionally being distracted. You also take on an anchoring risk: a reviewer shown a pre-filled
classification tends to agree with it, so at eight items a week you may be replacing independent human
judgement with agreement-with-the-model while measuring nothing, because eight items a week is too few to
detect a change in quality. That is the real harm, and it is invisible.

## What stays in code

The workflow, unchanged. The form, the queue, the notification, the record of who decided. If the pain is
that reviewers forget a check, the cheapest fix is a checklist in the UI, not a model.

If you do add jev, add it where being wrong is free: pre-filling *optional* fields the reviewer confirms,
ordering the queue so the likely-urgent item is on top, or highlighting which paragraph of an application
mentions a risk factor. Never pre-select the decision itself at this volume — there is no statistical
power to notice if the pre-selection is drifting.

## Numbers

Eight items a week at roughly 3,000 tokens each is about 1.2 million input tokens a year, roughly $0.05 a
year at $0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md). The API
cost is effectively zero; the integration, evaluation, monitoring, and on-call cost is not, and it is the
cost to weigh against the reviewer time saved, the error cost avoided and the waiting time removed —
none of which follows from the item count on its own. There is no published benchmark for this scenario because the question is
economic, not technical.

## When the verdict flips

Four things flip it, and any one may be enough. **Effort per item:** each review costs substantial expert
time — long documents, a checklist with many clauses, evidence to gather — so even a handful a week is
real money, and a pilot that reduces reading time is worth measuring. **Volume:** the same decision runs
per request, per event, or per row rather than eight times a week, so a shrunken review queue is worth
real money.
**Latency:** the decision has to happen inside a request path or a UI, where about 100 ms matters and a
human cannot be in the loop. **Automation intent:** you genuinely intend to act on the high-confidence
band without review, and you have historical decisions to measure the automation rate against — the
how-to-build guide's instruction is to "test thresholds by plotting confidence against accuracy on your
data", which needs enough data to plot. Add to those the **cost of an error** and the **cost of waiting**:
where a missed risk factor is expensive, or items sit in a backlog because no reviewer is free, a second
opinion or a pre-read has value that the item count does not show. If none of these holds, the honest
recommendation is to leave the workflow alone; **no rewrite is needed** because nothing is broken.

## Alternatives considered

- **Regex / deterministic**: a validation rule or a UI checklist fixes most low-volume review complaints
  for free.
- **Small LLM**: same conclusion wherever the effort per item is low; if the effort is high, compare it to
  jev on the same task rather than ruling out models by volume.
- **Frontier LLM**: at eight items a week the cost is also negligible, so if you want a model, use the one
  that also writes an explanation the reviewer can read.
- **Fine-tuned classifier**: no training data at this volume.
- **Embeddings**: could surface the most similar past decision, which is genuinely useful to a reviewer.
- **Human**: already doing the job, at a volume they can sustain. That is a valid final answer.

## Sources

- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
