---
id: uc-insurance-rubric-claim-triage-uncertain-band
title: Run a fixed yes/no claim rubric with an explicit uncertain band for human review
verdict: good
domain: insurance
decision_shapes: [verification, classification, routing]
primitives: [noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (the 14-question auto-claim rubric, the 0.30-0.70 band, 111 ms, $0.000043 per call, std dev 0.0102, run sampled 2026-09-11)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (insurance claims: classify FNOL and adjuster notes; escalate uncertain cases to a human adjuster)
  - https://docs.typesafe.ai/patterns/fan-out.md  (all rubric questions in one request)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (math and dates belong in code; structural invariants are not guaranteed)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-insurance-straight-through-vs-adjuster-routing, uc-insurance-claim-complexity-and-missing-info, uc-insurance-fraud-indicator-signals, cb-consistency_noul_cookbook, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to run our claim adjudication checklist?" Also asked as "can
jev answer a fixed list of policy questions about a claim?", "how do we stop a model
flip-flopping around 0.5 on borderline claims?", and "can we send only the uncertain claims
to an adjuster?".

## Verdict

**Good** — the shape is demonstrated by the noul-consistency cookbook, which measures
stability and not correctness; no task-matched labelled accuracy is published;
shadow-evaluate against the incumbent before acting. This is not an analogy to an
official example; it *is* the official example. TypeSafe's self-consistency cookbook
"takes one auto-insurance claim, runs a 14-question rubric over it 15 times, and checks
whether each answer holds still across the repeats", standing in for a pipeline that
"sorts incoming claims into pay, deny, or send-to-a-human". The design that makes it
work is the explicit third outcome: a band around the middle whose only action is human
review, so a claim at 0.49 and a claim at 0.51 stop producing opposite automatic
decisions. The claimable property is stability, not accuracy — the cookbook never
measures whether the answers are right, and says so.

## What jev decides

State: the claim as structured JSON plus the policy terms the questions reference. The
cookbook sends `{"uid": ..., "claim": CLAIM}` where `CLAIM` carries the policy and claim
ids, amounts, line items, dates, exclusions and an auto-triage note.

Fourteen Nouls in one request, "phrased so a yes means the thing we are checking for is
true. That keeps every row comparable". Verbatim from the cookbook:

```python
"covered": "Is the loss covered under the policy's collision coverage?",
"exclusion": "Does a policy exclusion apply to this loss?",
"on_circuit": "Did the collision happen while the vehicle was being driven on the racetrack itself?",
"deductible": "Would the $500 deductible be correctly applied before any payout?",
"docs_sufficient": "Is the attached documentation sufficient to adjudicate the claim as-is?",
"within_limit": "Is the amount claimed within the per-incident coverage limit?",
"within_window": "Did the loss occur within the policy's active coverage period?",
```

plus `reported_timely`, `rental_eligible`, `fraud_flag`, `human_review`, `manual_review`,
`line_items_sum`, `subrogation`.

The band is code, not a question — "no new question, no second API call":

```python
NOUL_UNCERTAINTY_LOW = 0.30
NOUL_UNCERTAINTY_HIGH = 0.70
```

stated as "`no` below `0.30`; `uncertain` from `0.30` through `0.70`, including both
boundaries; `yes` above `0.70`." Uncertain rows go to an adjuster. Because every question
points the same way, one rule covers all fourteen instead of fourteen rules.

Note what is *not* in the design: no Choice asking "pay, deny or review", and no averaging
of a Noul with a Choice. Failure mode 8 is explicit that "`P(noul)` and `1 - P(not noul)`
may not be directly comparable" and that a threshold tuned on a Noul does not carry to a
Choice.

## What stays in code

The band, the aggregation from fourteen answers to one route, and every number. The
cookbook's own rubric is the warning here: `line_items_sum` ("do the claimed line-item costs
add up to the total claimed") and the deductible question are arithmetic, and the
`within_window` / `reported_timely` pair are date arithmetic — failure modes 2 and 3. Compute
all four in code and use the model's answer, if at all, only as a cross-check that gets
flagged when it disagrees with the computation. Policy lookup, payout execution, reserve,
and the audit trail are code.

## Numbers

All verbatim from `https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md`, one
synthetic claim, `NUM_SAMPLES` = 15 repeats, "run uses `jev-latest` on the production API,
sampled on 2026-09-11", the alias resolving to `{'jev-1.13.0': 15}`:

| condition | calls | time/call | cost/call | speed vs ts_noul | cost vs ts_noul |
|---|---|---|---|---|---|
| `typesafe_noul` | 15 | 111ms | $0.000043 | 1.0x | 1.0x |
| `claude-haiku-4-5` t=0 | 15 | 1780ms | $0.001798 | 16.0x | 42.2x |
| `gpt-5.4-mini` t=0 | 15 | 1405ms | $0.001089 | 12.7x | 25.6x |
| `gpt-5.5-reasoning` | 15 | 11125ms | $0.033157 | 100.2x | 778.9x |
| `claude-opus-4-8-reasoning` | 15 | 13886ms | $0.034275 | 125.0x | 805.1x |

"In this run TypeSafe has a mean round-trip latency of 111ms." Stability: "TypeSafe's mean
per-question probability standard deviation is `0.0102`, below all LLM probability
conditions here." Spread: "Its `covered` answers span `0.43` to `0.53`, crossing a `0.5`
decision threshold"; "TypeSafe's `covered` row crosses `0.5`; its other 13 questions stay on
one side of that threshold throughout this run." Prices are the cookbook's historical
assumptions and it states they "are not verified `jev-latest` prices or current billing
amounts". Accuracy: not measured. Agreement rates and token counts: not reported.

## When the verdict flips

- To `no` if an answer above 0.70 releases a payment with no deterministic gate. The
  cookbook is explicit: "an automatic decision that clears the band is not shown to be
  correct."
- To `conditional` if your rubric is mostly arithmetic. Rewrite those rows as code first;
  what remains may be three questions, not fourteen, and the case for a call weakens.
- To `weak` if an adjuster already reads every claim and volume is low; the saving is the
  share of claims that clear the band, and you should measure that share on history before
  building anything.
- Watch the band edges. "A value near either outer boundary can still move between
  `uncertain` and yes or no." Widen the band rather than tightening it when the cost of a
  wrong automatic answer is high.

## Alternatives considered

- **Deterministic rules.** Already own the arithmetic rows and should keep them; they cannot
  answer `covered` or `docs_sufficient`.
- **Small LLM (Haiku-class).** 16.0x slower and 42.2x more expensive on this rubric, and the
  cookbook notes it "wraps nearly every reply in a ` ```json ... ``` ` fence that strict
  `json.loads` rejects". Forcing yes/no output also "leaves no mass in the middle, so a model
  cannot tell you it is unsure" — which removes the band.
- **Frontier reasoning LLM.** 100x to 125x the latency and 779x to 805x the cost on the same
  rubric; a reasonable escalation target for the uncertain band, not the rubric runner.
- **Fine-tuned classifier.** One head per rubric row and retraining whenever the policy
  wording changes; jev needs an edited string.
- **Embeddings.** No mapping to "does an exclusion apply".
- **Human adjudication of everything.** The baseline. The design keeps the adjuster for the
  band, and the measurement you owe yourself is what fraction of claims land in it.

## Sources

Accessed 2026-09-19. `cookbooks/consistency_noul_cookbook.md` (rubric, band, all figures,
caveats; run sampled 2026-09-11, `jev-1.13.0`), `concepts/use-case-map.md`,
`patterns/fan-out.md`, `model-jaggedness/jev-1.13.md` (math, dates, structural invariants),
`models.md` (price, latency).
