---
id: au-zero-data-retention-regulated-data
title: Do not send regulated or customer-confidential data to jev without enterprise zero data retention
verdict: weak
domain: compliance
decision_shapes: [classification, extraction, detection]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/legal.md  ("We also offer zero data retention (ZDR) for enterprise customers")
  - https://docs.typesafe.ai/models.md  ("Jev is not trained on customer requests or responses")
  - https://github.com/fdsimms/todo/issues/2781  ("no integration now"; ZDR on all tiers named as a flip condition)
related: [au-air-gapped-or-self-hosted, au-private-knowledge-not-in-state, au-whole-document-in-state, uc-trust-safety-pii-exposure-detection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to run patient notes / card data / employee files through jev on our current plan?"
Also "is jev zero-retention?", "does TypeSafe train on our data?", "what do we tell the DPO?".

## Verdict

**Weak** on a non-enterprise plan for data that carries a retention obligation. Two statements have to be
kept apart. Training: "Jev is not trained on customer requests or responses", reinforced by "We wouldn't
train on your data even if you asked us to (no offense)." Retention: "We also offer zero data retention
(ZDR) for enterprise customers. Contact privacy@typesafe.ai to learn more." Not training is not the same
control as not retaining, and ZDR is scoped to enterprise in the documentation read 2026-09-19. A team
running the same evaluation reached the same place: `fdsimms/todo#2781` concluded "no integration now",
and named zero data retention on all tiers as one of exactly two conditions that would make them
reconsider.

Not a model failure: **governance** veto — a retention and contracting question, not an
accuracy one.

## What jev would get wrong

Again, not the decision — the disclosure. The state field is where jev's accuracy comes from, so the
pressure is always toward putting more of the record in it: the whole ticket, the whole note, the whole
file. Each addition is another category of personal or regulated data crossing a boundary your DPA may
not cover, and no hosting region is published to anchor a residency argument ("our published evals are
generally run from our laptops on the West Coast (this is where our service is currently based)" is a
statement about where the team sits, not a residency commitment).

## What stays in code

Minimisation and the paper trail. Redact or tokenise identifiers before the call; send the clause, the
sentence or the derived features rather than the document — which the docs recommend for accuracy anyway;
keep the mapping from token back to identity on your side; log what was sent, not just what came back;
and record the lawful basis and the DPA version alongside the integration. Where the decision only needs
structure ("does this note mention a missed appointment?"), code can often strip every direct identifier
and still get the same answer.

## Numbers

ZDR is enterprise-only and no price is published for the enterprise tier; the DPA, MCA and privacy policy
are the governing documents (https://docs.typesafe.ai/legal.md, read 2026-09-19). No hosting region or
data-residency policy is published (https://docs.typesafe.ai/models.md). On the field side, one of the
four documented don't-adopt decisions is explicitly gated on this: ZDR on all tiers plus "a genuine
sub-second latency requirement" were the two flip conditions in `fdsimms/todo#2781` (2026-09-17). Cost of
the minimisation itself is negative: a redacted 300-token excerpt instead of a 4,000-token file is about
$0.000013 against $0.00017 per call at $0.042 per million input tokens with output free.

## When the verdict flips

It flips to **conditional** with enterprise ZDR signed, the DPA reviewed against your obligations, a
documented minimisation step in front of every call, and the residency question answered in writing. It
also flips for data that is not regulated at all — public content, internal telemetry, synthetic
fixtures — where this entry simply does not apply. It does not flip on the strength of "they don't train
on it", which answers a different question.

## Alternatives considered

- **Regex / deterministic**: no data leaves; use it for anything checkable.
- **Small LLM**: self-hosted, the data stays inside; you own the compliance surface instead.
- **Frontier LLM**: same boundary crossing, usually with its own enterprise-tier ZDR.
- **Fine-tuned classifier**: trained and served in your environment, the cleanest answer for regulated
  workloads.
- **Embeddings**: local models keep vectors in-house; vectors are still personal data.
- **Human**: already inside the boundary, and already in the audit trail.

## Sources

- https://docs.typesafe.ai/legal.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://github.com/fdsimms/todo/issues/2781 — accessed 2026-09-19
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
