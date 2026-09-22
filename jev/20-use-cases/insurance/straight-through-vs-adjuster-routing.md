---
id: uc-insurance-straight-through-vs-adjuster-routing
title: Flag claims to remove from straight-through processing
verdict: conditional
verdict_as_asked: no
domain: insurance
decision_shapes: [routing, classification, scoring]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (insurance claims: "Prioritize claims for straight-through processing or specialist review"; "Escalate uncertain or high-risk cases to a human adjuster")
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; a 0.6 floor, 0.85 for the risky action; "the answer tells you what; confidence tells you whether to act")
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify intent and complexity, then route to code, a specialist model, or a human)
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with the stakes of the action)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (the pipeline it stands in for "sorts incoming claims into pay, deny, or send-to-a-human"; the band is "illustrative", not "an optimized threshold")
related: [au-straight-through-claim-payment-decision, uc-insurance-rubric-claim-triage-uncertain-band, uc-insurance-claim-complexity-and-missing-info, uc-insurance-fraud-indicator-signals, cb-consistency_noul_cookbook, df-rollout, au-payments-and-access-control-decision]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide which claims can be paid straight through?" Also
asked as "can jev decide which claims need an adjuster?", "can we use the confidence value
as an STP gate?", and "can jev replace our straight-through eligibility rules?".

## Verdict

The question as literally asked — "can jev decide which claims are paid straight
through?" — is answered **no**, and that answer has its own entry:
`au-straight-through-claim-payment-decision`. Paying money is the irreversible action,
straight-through eligibility is a contractual and regulatory invariant, and confidence is
not a probability of correctness for the pay decision (failure mode 8).

**This entry describes a different proposal, and its verdict is conditional:** flag claims
to *remove* from straight-through processing. Keep your existing deterministic eligibility
rules authoritative and running first, and let jev only ever move a claim *out* of
straight-through processing, never into it. Within that constraint the fit is good — the use-case map names "Prioritize claims for straight-through
processing or specialist review" and "Escalate uncertain or high-risk cases to a human
adjuster", and the confidence-routing pattern is built for exactly this asymmetry, where
"some actions are riskier than others and thus demand a higher confidence threshold". A
threshold tuned on one question does not transfer to another, so every band must be
fitted on your own closed claims.

## What jev decides

State: the claim narrative, the peril and coverage already resolved by code, the attachment
manifest, and nothing else. A full claims record is the archetype of failure mode 5.

```
handling_route: Choice
  instructions: {question: "Which handling route does `claim` require?",
                 focus: "Judge what the file needs, not whether it should be paid."}
  criteria:
    straightforward: {what: "One party, one clear cause, damage consistent with the cause,
                             all required documents described as attached",
                      not_for: "Any disputed fact or any injury",
                      examples: ["Windscreen chip, receipt attached, no other party"]}
    desk_adjuster:   {what: "Needs a person to read the file but no field work",
                      not_for: "Suspected coverage dispute",
                      examples: ["Minor liability question between two accounts"]}
    field_or_specialist: {what: "Injury, disputed liability, suspected coverage dispute,
                                 litigation mentioned, or an unusual loss type"}
    other:           {what: "None of the above describes this file"}

coverage_dispute_likely: Noul
  instructions: "Does `claim.narrative` describe circumstances the policy exclusions in
                 `policy.exclusions` may exclude?"
injury_described: Noul
third_party_liability_described: Noul
complexity: Score  (the four-level rubric from uc-insurance-claim-complexity-and-missing-info)
```

Ride all of them in one call; extra questions cost tokens and no latency.

The routing rule, in code, is deliberately asymmetric, following the voice-banking example
in the confidence-routing pattern where checking a balance clears at 0.6 and approving a
transfer needs above 0.85:

```python
if r.confidence < 0.60:                      route_to_desk_adjuster(claim)   # floor
elif r.choice == "field_or_specialist":      route_to_specialist(claim)      # act at 0.60
elif injury.noul > 0.30 or dispute.noul > 0.30 or complexity.score > 1.5:
                                             route_to_desk_adjuster(claim)
elif r.choice == "straightforward" and r.confidence >= 0.90 and stp_rules_pass(claim):
                                             straight_through(claim)
else:                                        route_to_desk_adjuster(claim)
```

Note the direction: escalation clears at a low threshold because escalating is cheap and
reversible; straight-through requires both a high confidence and the deterministic rules.
Every uncertain case has somewhere to go, which is fit-test question six.

## What stays in code

`stp_rules_pass()` is the authoritative gate and stays exactly as it is: amount against the
straight-through ceiling, deductible arithmetic, per-incident limit, policy in force on the
loss date, reporting window, sanctions and watch-list checks, prior-claim count. All of that
is arithmetic and date comparison — failure modes 2 and 3 — and the consistency cookbook's
own anti-pattern is instructive: its rubric contains `line_items_sum` and a deductible
question, and the cookbook's borderline probabilities show why a near-0.5 answer cannot be
the authority for a payout. Payment execution, reserve setting, and the audit record are
code.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A 2,000-character narrative plus resolved coverage fields, the four-option
Choice with contrastive criteria (~1,100 characters), three Nouls and one Score (~1,000
characters) is about 4,400 / 4 ≈ 1,100 tokens, so **≈ $0.000046 per claim**. Latency 70-500
ms, "most queries about 100 ms"; measured comparators on claim-shaped rubrics, sampled
2026-09-11: jev 111 ms / $0.000043, `claude-haiku-4-5` 1,780 ms / $0.001798, `gpt-5.5-reasoning`
11,125 ms / $0.033157. Straight-through rate, leakage, or agreement with adjuster decisions:
**not published**. The labelled set you need already exists — every closed claim carries the
route a human chose. Plot confidence against agreement on those before flipping anything, and
expect the cookbook's caution to hold: its band "is illustrative; it is neither a calibrated
guarantee nor an optimized threshold".

## When the verdict flips

- To `no` if jev's answer alone can release a payment, or if the direction reverses and a
  high-confidence answer moves a claim *into* straight-through processing. Money is an
  invariant; the deterministic gate must remain. That is
  `au-straight-through-claim-payment-decision`.
- To `weak` if your straight-through rate is already set by structured eligibility rules and
  the narrative adds nothing — check by measuring how often adjusters overturn the rule.
- To `no` where a regulator requires a per-decision explanation of why a claim was not
  straight-through; the probability is not an explanation, though the decomposed answers
  help.
- To `conditional` on a much tighter leash for non-English books of business without your own
  evaluation.

## Alternatives considered

- **Deterministic eligibility rules.** The incumbent, and they stay. They cannot read a
  narrative, which is the gap jev fills.
- **Small LLM (Haiku-class).** Same decision, ~16x the latency and ~42x the cost on the
  measured rubric, and forced yes/no output destroys the uncertainty signal the gate needs.
- **Frontier LLM.** Better judgement, seconds per claim and cents per claim; sensible as the
  escalation target for the low-confidence band, not as the router.
- **Fine-tuned classifier on closed claims.** Viable and probably accurate; slower to change
  when the STP ceiling or product mix moves.
- **Embeddings.** No notion of "needs an adjuster".
- **Human triage on every claim.** The status quo in many books; the point of the design is
  that only the uncertain band reaches a person, and you can measure that share on history
  before committing.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (straight-through vs specialist review;
escalate uncertain cases), `patterns/confidence-routing.md` (per-action thresholds, 0.6
floor, >0.85 for the risky action), `patterns/intent-routing.md`, `confidence.md`,
`cookbooks/consistency_noul_cookbook.md` (pay / deny / send-to-a-human framing; band caveats;
111 ms, $0.000043, comparator latencies and costs, 2026-09-11), `models.md` (price, latency).
