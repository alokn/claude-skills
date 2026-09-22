---
id: uc-insurance-fraud-indicator-signals
title: Decompose fraud indicators in a claim into one probability per named signal
verdict: conditional
domain: insurance
decision_shapes: [detection, feature-extraction, scoring]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (insurance claims: "Detect claim complexity, missing information, and potential fraud indicators"; risk assessment: "Classify risk types and detect suspicious characteristics")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (spam decomposed into six atomic Nouls rather than one `is_spam`; weighted combination in code)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (`fraud_flag`: "indicators warranting fraud review"; the rows that move run to run include `fraud_flag`)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (weights live in code and are tunable without re-inference)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (adversarial content: "State is data, and `jev-1.13` does not treat it as hostile by default")
related: [uc-insurance-claim-complexity-and-missing-info, uc-insurance-straight-through-vs-adjuster-routing, uc-financial-crime-transaction-narrative-suspicious-characteristics, uc-financial-crime-alert-prioritisation-by-evidence-quality, cb-consistency_noul_cookbook]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect insurance fraud?" Also asked as "can jev flag
suspicious claims for the SIU?", "can we replace our fraud keyword list with a model?", and
"can jev give us a fraud score per claim?".

## Verdict

**Conditional.** The condition is that jev produces *named indicators*, never a fraud
verdict, and that nothing adverse happens to a claimant on a jev answer alone. Ask one Noul
per indicator — "the claim was reported shortly before the policy was due to lapse", "the
narrative describes no independent witness" — and let code combine them into a referral
score with weights you own. A single `is_fraudulent` question is the mistake the docs
themselves warn against, using the structurally identical spam example: one broad question
"hides several judgments behind one answer", while atomic questions "expose those judgments
so you can inspect, tune, and combine them in code". Two failure modes bite here. Failure
mode 6: a claim narrative is text a claimant wrote, and "State is data, and `jev-1.13` does
not treat it as hostile by default", so a narrative that argues for its own innocence can
move the answer. Failure mode 1: "indicator of fraud" is exactly the kind of phrase a
literal reader will interpret differently from you unless each indicator is spelled out.

## What jev decides

State: the narrative, the adjuster note, and only those structured facts an indicator
actually references. Nothing about the claimant's protected characteristics, and nothing
that is not evidence for a named indicator.

```
no_independent_witness: Noul
  instructions: {question: "Does `claim.narrative` describe the incident with no
                            independent witness and no third party present?",
                 inspect: "`claim.narrative`"}
  criteria: {true:  {what: "A single-party account with nobody else named as present",
                     examples: ["I skidded on an empty road at 2am and hit a wall"]},
             false: {what: "Another person, vehicle, or attending official is described",
                     not_for: "A passenger who is a member of the insured's household",
                     examples: ["The other driver gave me their details"]}}

narrative_internally_inconsistent: Noul
  instructions: {question: "Do two statements within `claim.narrative` contradict each other?",
                 focus: "Compare only statements inside the narrative. Do not compare against
                         the policy record."}
  criteria: {true:  {what: "Two statements cannot both be true as written",
                     examples: ["The car was parked, then: I braked hard and slid"]},
             false: {what: "The statements are consistent or merely vague"}}

narrative_unusually_detailed_for_a_small_loss: Noul
prior_loss_described_in_narrative: Noul
requests_cash_settlement_before_inspection: Noul
pressure_to_settle_quickly: Noul
documents_described_as_unavailable: Noul
```

Each is absolute, so several can be low at once — a Choice would be wrong here (failure mode
8: "A Choice over options and one Noul per option answer different questions"). Code
combines them:

```python
referral = (0.25 * a["narrative_internally_inconsistent"].noul
          + 0.20 * a["requests_cash_settlement_before_inspection"].noul
          + 0.15 * a["pressure_to_settle_quickly"].noul
          + 0.15 * a["documents_described_as_unavailable"].noul
          + 0.15 * a["no_independent_witness"].noul
          + 0.10 * a["prior_loss_described_in_narrative"].noul)
```

The weights are in code so they can be tuned against SIU outcomes without re-running
inference, which is the whole point of the composite-scoring pattern. There is no
high-confidence auto-action band: the only outputs are "referred to SIU with the indicator
list attached" and "not referred". The indicator list, not the score, is what the
investigator reads.

## What stays in code

Everything numeric and temporal: days between policy inception and loss, days between loss
and report, claim frequency, amount against limit and deductible, prior-claim counts. These
are the strongest classical fraud features and they are arithmetic — failure modes 2 and 3
put them firmly in code. Deterministic referral rules (mandated referrals, sanctioned
parties, known-ring identifiers) stay authoritative and run *before* jev. All adverse
actions — declining, delaying, referring to law enforcement — are code paths that require a
human decision, and the model output is evidence in that decision, never the decision.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A 2,500-character narrative plus adjuster note and seven Nouls with
contrastive criteria (~2,000 characters) is about 4,500 / 4 ≈ 1,125 tokens, so **≈ $0.000047
per claim**. Reference point: the consistency cookbook's 14-Noul claim rubric cost
$0.000043 at 111 ms, sampled 2026-09-11. That same cookbook is a caution as well as a
benchmark — `fraud_flag` is named among the rows that move: "the rows that move are
`exclusion`, `rental_eligible`, `fraud_flag`, and `manual_review`", which is a judgement
question sitting near a threshold. Detection rate, precision against confirmed fraud, or
any lift over your current rules: **not published anywhere, for anyone**. Measure it against
closed SIU outcomes before the score touches a queue.

## When the verdict flips

- To `no` if the score is used to decline, delay, or price a claim without a human
  decision, or if it is the sole basis of an adverse action. That is a legal and fairness
  invariant; the fit test's counter-signal applies.
- To `no` if you cannot articulate each indicator as a condition a person could check from
  the text. If you are reaching for "it feels off", there is no question to write.
- To `weak` if your fraud signal is overwhelmingly structured (claim velocity, shared bank
  accounts, repeated garages). A gradient-boosted model on those features will beat any
  amount of narrative reading, and jev's role shrinks to a handful of extra features — see
  the autoresearch cookbook pattern for that framing.
- To `weak` if regulation in your market requires an explainable, auditable rule set per
  decision; the indicator list helps, but the probability is not an explanation.

## Alternatives considered

- **Keyword / phrase lists.** What most teams have. No confidence, no boundary, and easy for
  a coached claimant to avoid; still cheaper and exact for named entities and ring
  identifiers, which should stay as a list.
- **Fine-tuned classifier on closed claims.** Strong if you have thousands of confirmed
  outcomes; needs relabelling as fraud patterns shift, where jev needs an edited string.
- **Gradient-boosted model on structured features.** Usually the incumbent and usually
  better; the honest integration is jev indicators *as additional features*, not as a rival.
- **Frontier LLM.** Will write a persuasive fraud narrative, which is precisely the risk —
  a fluent rationale for a wrong referral. Cost and latency also rule it out per claim.
- **Embeddings against known-fraud narratives.** Detects copied text, not novel indicators.
- **Human SIU triage.** Stays, and receives the indicator list rather than a raw score.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (fraud indicators; "detect suspicious
characteristics"), `concepts/how-to-build-with-system-one.md` (decomposition example;
weighted combination in code), `cookbooks/consistency_noul_cookbook.md` (`fraud_flag`
question and its run-to-run movement; 111 ms, $0.000043, 2026-09-11),
`patterns/composite-scoring.md`, `model-jaggedness/jev-1.13.md` (adversarial content;
literal reading), `cookbooks/autoresearch_feature_discovery.md` (probabilities as features
for a classical model), `models.md` (price).
