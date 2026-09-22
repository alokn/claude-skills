---
id: uc-agents-harness-confidence-escalation-to-frontier-model
title: Escalate to a frontier model only when jev's confidence falls below a threshold fitted on your own data
verdict: conditional
domain: agents-harness
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: independent-benchmark
sources:
  - https://github.com/FirasSX914/Janus  (confidence routing jev -> DeepSeek v4 Pro; Banking77 threshold 0.67, 80.2%, -53% cost, p50 302 ms, 11.6% escalation; Web of Science "DO NOT ROUTE")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; confidence is per-question, not per-task)
related: [uc-agents-harness-model-difficulty-routing, uc-observability-evals-confidence-threshold-calibration-fitting, uc-verification-structured-extraction-cascade, uc-search-retrieval-confidence-fallback-broader-level, au-expect-headline-speed-cost-multipliers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev first and fall back to a frontier model when it is unsure?"
Also: "can we cut our classification bill by letting the cheap model handle the easy ones?",
"what confidence threshold should we escalate at?", "is jev's probability good enough to
decide when jev is wrong?"

## Verdict

**Conditional.** The cascade works and has been measured — but only after you fit the
threshold on your own labelled data, for that dataset, and confirm the fitted cascade beats
the single best model on a held-out split. The one study that tried two datasets got opposite
answers from the same procedure: Banking77 said route at 0.67; Web of Science said **"DO NOT
ROUTE"** because no threshold beat the single best model. Its conclusion is the condition:
"A default threshold would therefore be wrong roughly as often as it was right."
(github.com/FirasSX914/Janus)

Distinguish this from difficulty routing. There, a classifier looks at the prompt and picks a
model *before* any work happens. Here jev has already produced the answer you wanted; you are
only deciding whether to pay again for a second opinion. That ordering is why the cheap call
is never wasted — its output is either the final answer or the escalation signal.

## What jev decides

Nothing new. This pattern adds no question to jev; it reads the `confidence` already attached
to the answer you asked for. Say the production question is an intent `Choice`:

```
intent: Choice
  instructions: {question: "What is the customer asking for?",
                 focus: "The action the customer wants taken, not the tone."}
  criteria: {...your label set, each with what / not_for / examples...}
```

The escalation rule lives in code:

```
answer = jev(state, questions)
if answer.intent.confidence >= THRESHOLD:   # THRESHOLD fitted per question, per dataset
    return answer.intent.value
return frontier_model(state)                 # pay here, and only here
```

Fit `THRESHOLD` by sweeping it over a labelled holdout and picking the point where accepted
accuracy clears your target at the lowest escalation rate. Report three numbers for each
candidate threshold: accepted accuracy, coverage, and expected cost. Refit per question — a
single call answering four questions has four confidence distributions, not one.

Low-confidence path: escalate. There is no abstain band here because escalation *is* the
abstain band.

Closest jaggedness mode: **5, context rot** — an escalation cascade tempts you to send the
frontier model more context than jev got, which makes the comparison meaningless. Send both
the same state, or you are measuring context, not models.

## What stays in code

The threshold constant and the sweep that produced it. The escalation counter and its budget
cap. Timeouts on both legs and the fallback if the frontier call fails. The A/B or shadow
harness. Every deterministic rule that already resolves a case — those short-circuit before
jev, not after. And the arithmetic: cost per thousand decisions is `coverage x jev_cost +
(1 - coverage) x frontier_cost`, computed in code, never asked of the model.

## Numbers

All from github.com/FirasSX914/Janus, 2 x 500 rows, jev escalating to DeepSeek v4 Pro:

| Dataset | Fitted threshold | Accuracy | Cost | Latency | Escalation rate |
|---|---|---|---|---|---|
| Banking77 | 0.67 | 80.2% (+1.4 pt) | -53% | p50 302 ms | 11.6% |
| Web of Science | none found | — | — | — | "DO NOT ROUTE" |

The study mentions ECE and Brier but does not tabulate them, and it is a single run per
dataset — treat +1.4 pt as suggestive, not established. Per-call cost method for the jev leg:
`input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A 600-character utterance
plus a 77-label criteria block (~4,000 characters) is about 1,150 tokens, roughly $0.000048 per
decision; the -53% figure is the *blended* saving at 11.6% escalation, not the per-call ratio.

## When the verdict flips

- **You skip the fit and copy 0.67 from this study.** Then it is `no`. Web of Science is the
  counter-example and it came from the same procedure on the same model version.
- **Your label set is high cardinality and the frontier model is much better.** Banking77 gave
  jev 0.78 against GPT-5.6 Terra's 0.85 in a separate evaluation; when the gap is that wide the
  cascade's ceiling is the escalation rate you can afford.
- **You have no labelled holdout.** Without one you cannot fit a threshold or know the cascade
  helped. Collect ~100+ rows per question first.
- **Latency is the binding constraint.** The escalated tail pays jev's latency *plus* the
  frontier model's. p50 improves; p95 gets worse.
- **Confidence is being read as correctness elsewhere in the system.** It is a routing signal
  here because a wrong route only costs money. Any use where a wrong answer is accepted
  silently needs a different design.

## Alternatives considered

- **Frontier model on everything.** The baseline. Correct more often, and the cost and latency
  this pattern exists to remove.
- **Difficulty routing before the work** (uc-agents-harness-model-difficulty-routing). Cheaper
  still, because the cheap model never runs on hard inputs — but it must predict difficulty
  from the prompt alone, which is a harder question than "was I sure".
- **Random or volume-based sampling to the frontier model.** Free to implement, no threshold to
  fit, and the escalations land on easy cases as often as hard ones.
- **Fine-tuned classifier with its own reject option.** Strictly better once you have the
  labels — and fitting the threshold gives you the labels.
- **Two jev calls with different framings, escalate on disagreement.** Cheap, but jev agreeing
  with jev is the circularity that independent evaluations measured at up to +0.081 NDCG@10 of
  self-preference elsewhere. Disagreement is a weaker signal than it looks.
- **Human review of the low band.** The right answer when the escalated volume is small and the
  cost of being wrong is not money.

## Sources

- https://github.com/FirasSX914/Janus — accessed 2026-09-19 (threshold 0.67, 80.2%, -53% cost,
  p50 302 ms, 11.6% escalation, 2 x 500 rows, "DO NOT ROUTE", "A default threshold would
  therefore be wrong roughly as often as it was right")
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
