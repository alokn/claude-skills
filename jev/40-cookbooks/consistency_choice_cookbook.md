---
id: cb-consistency_choice_cookbook
title: "Self-consistency: choices"
url: https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md
decision_shapes: [classification, routing]
primitives: [choice]
related: [uc-trust-safety-user-report-triage, uc-trust-safety-policy-violation-bands, uc-observability-evals-rubric-scoring-llm-judge-replacement, uc-observability-evals-confidence-threshold-calibration-fitting, au-sole-security-gate, au-expect-identical-results-across-runs]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.13.0
source_model_note: cookbook ran `jev-latest` sampled 2026-09-11; the alias resolved to jev-1.13.0
---

## Task

Measures run-to-run stability of labels, not accuracy. The cookbook "takes one borderline
user post, runs a moderation rubric over it 15 times, and checks whether each answer holds
still across the repeats." The rubric is 8 `Choice` questions; each run is one call
answering all 8; `NUM_SAMPLES` = 15 repeats per condition, where "a condition is one model
plus one setting."

Dataset: a single synthetic post, `POST` with `post_id` `"P-88213"` — a public reply in
`r/gamedebates` from an account 38 days old with `prior_strikes: 1`, containing insults, a
`discord.gg` link, and `user_reports: 4` with reasons `["harassment", "spam", "threat"]`.
It is "built to sit on the fence". Sample size: one document, 15 repeats per condition.
Run: "This run uses `jev-latest` on the production API, sampled on 2026-09-11." The
TypeSafe alias resolved to `{'jev-1.13.0': 15}` for all 15 calls.

## Decomposition (state, questions, how answers are combined)

State — LLMs get `json.dumps(POST)`; TypeSafe gets the dict plus a throwaway nonce:

```python
state={"uid": f"{rubric_hash}:{sample_index}:{token_hex(4)}", "post": POST}
```

The 8 `Choice` questions and their label sets (each label carries a short description):

| key | instructions (verbatim) | labels |
|---|---|---|
| `category` | "What is the single most applicable content-policy category for this post?" | None, Harass, Hate, Violence, Spam, Sexual |
| `primary_risk` | "What is the primary moderation risk that should drive triage for this post?" | Harassment, Violence, LinkAbuse, AccountHistory, LowRisk |
| `target` | "Who or what is the content primarily directed at?" | None, Person, Group, Platform |
| `action` | "What enforcement action should be taken on this post?" | Allow, Warn, Remove, Strike, Escalate |
| `queue` | "Which single moderation queue should own this post?" | Auto, General, Threat, Spam, TSLead |
| `link_handling` | "How should any external link or off-platform invite in the post be handled?" | Allow, RmLink, Brigade, Escalate |
| `review_path` | "Who should make the final call on this post?" | Auto, Human, Senior, Legal |
| `severity` | "What is the overall severity of this post?" | None, Low, Medium, High |

Combination is pure application code over the returned `probabilities`, with an abstain
band and no second call:

```python
MIN_CHOICE_PROBABILITY = 0.60  # illustrative automatic-action threshold

def choice_decision_with_uncertainty(values, labels):
    label = argmax_label(values, labels)
    if label is None:
        return None
    probabilities = [float(value) for value in values]
    if any(value < 0 or value > 1 for value in probabilities):
        return None
    return label if max(probabilities) >= MIN_CHOICE_PROBABILITY else "uncertain"
```

"At exactly `0.60`, select the top label." Uncertain cases go to a human. The rule "uses
the returned probabilities, not the API's separate `confidence` field, and adds no model
calls." Parse failures return `None` and "count against agreement". Single-pick LLM
conditions are excluded from the agreement chart and table because "they provide no
uncertainty estimate."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run sampled 2026-09-11. Prices are historical: `LLM_PRICES` "$ per 1M tokens (input,
output); prices + model ids as of 2026-07"; `TYPESAFE_PRICE = (0.042, 0.00)` is a
"Historical TypeSafe rate, as of 2026-08". The cookbook states the cost figures "are not
verified `jev-latest` prices or current billing amounts."

Cost and speed, one full 8-question rubric call, averaged over 15 calls (LLMs run in a
16-way pool; TypeSafe drawn sequentially):

| condition | calls | time/call | cost/call | speed vs ts_choice | cost vs ts_choice |
|---|---|---|---|---|---|
| `claude-haiku-4-5` t=0 | 15 | 3853ms | $0.003498 | 33.8x | 76.1x |
| `claude-haiku-4-5` t=default | 15 | 3860ms | $0.003494 | 33.8x | 76.0x |
| `claude-haiku-4-5` single-pick t=0 | 15 | 992ms | $0.001527 | 8.7x | 33.2x |
| `gpt-5.4-mini` t=0 | 15 | 2293ms | $0.002299 | 20.1x | 50.0x |
| `gpt-5.4-mini` t=default | 15 | 1986ms | $0.002164 | 17.4x | 47.1x |
| `gpt-5.4-mini` single-pick t=0 | 15 | 826ms | $0.000936 | 7.2x | 20.3x |
| `gpt-5.5-reasoning` | 15 | 12978ms | $0.041255 | 113.7x | 897.4x |
| `claude-opus-4-8-reasoning` | 15 | 10376ms | $0.028375 | 90.9x | 617.2x |
| `typesafe_choice` | 15 | 114ms | $0.000046 | 1.0x | 1.0x |

"In this run `typesafe_choice` has a mean round-trip latency of 114ms. The LLM conditions
range from 826ms to 13.0 seconds per call under the concurrency settings above."

Probability standard deviation (mean over labels and questions of each label's std dev
across the 15 repeats; max single-label std dev; parse-failure rate):

| condition | mean prob std | max prob std | parse fail | x TypeSafe |
|---|---|---|---|---|
| `claude-haiku-4-5` t=0 | 0.0012 | 0.0221 | 0% | 0.12x |
| `claude-haiku-4-5` t=default | 0.0516 | 0.3150 | 1% | 5.29x |
| `gpt-5.4-mini` t=0 | 0.0312 | 0.0905 | 0% | 3.20x |
| `gpt-5.4-mini` t=default | 0.0543 | 0.2303 | 0% | 5.56x |
| `gpt-5.5-reasoning` | 0.0305 | 0.1047 | 0% | 3.12x |
| `claude-opus-4-8-reasoning` | 0.0245 | 0.0693 | 0% | 2.52x |
| `typesafe_choice` | 0.0098 | 0.0515 | 0% | 1.00x |

"In this run TypeSafe has a mean probability std dev of `0.0098` and a max single-label std
dev of `0.0515`. Haiku at temperature 0 has a lower mean std dev of `0.0012`. The other
five LLM probability conditions range from `0.0245` to `0.0543`, about `2.5x` to `5.6x`
the TypeSafe mean."

Agreement, abstention and conflicts (mean over the 8 questions of the plurality decision's
share of the 15 draws):

| condition | raw agree | policy agree | uncertain | automatic | conflicts |
|---|---|---|---|---|---|
| `claude-haiku-4-5` t=0 | 100.0% | 100.0% | 0.0% | 100.0% | 0 |
| `claude-haiku-4-5` t=default | 87.5% | 86.7% | 0.8% | 98.3% | 2 |
| `gpt-5.4-mini` t=0 | 99.2% | 87.5% | 12.5% | 87.5% | 0 |
| `gpt-5.4-mini` t=default | 90.8% | 84.2% | 22.5% | 77.5% | 2 |
| `gpt-5.5-reasoning` | 90.0% | 93.3% | 30.8% | 69.2% | 1 |
| `claude-opus-4-8-reasoning` | 92.5% | 94.2% | 33.3% | 66.7% | 0 |
| `typesafe_choice` | 90.8% | 99.2% | 25.8% | 74.2% | 0 |

"TypeSafe's agreement rose from 90.8% to 99.2%. Of the answers, 25.8% were uncertain and
74.2% automatic." "Under the same `0.60` rule, Haiku at temperature 0 scored 100%.
TypeSafe scored 99.2%, and the other LLM conditions landed between 84.2% and 94.2%."
"the LLM distribution settings repeat their plurality labels 87.5% to 100% of the time,
compared with TypeSafe's 90.8%."

Per-question detail: before abstention TypeSafe "changes its top label on `primary_risk`
(Harassment 11 times, Violence 4 times) and `link_handling` (RmLink 8 times, Brigade 7
times)" — "TypeSafe flips on 2 of the 8 questions". After the threshold, `primary_risk`
and `link_handling` "came back uncertain on every repeat; `category` alternated between
Violence and `uncertain`". `target` reads Person and `severity` reads High "across the
board". "No question produced two different concrete TypeSafe labels."

Token counts: not reported (usage is collected but not printed).

## Caveats the cookbook itself states

- "These percentages measure repeatability only" and "These measures describe repeatability
  and how often the application acts, not whether its actions are right."
- Chart annotation: "* Haiku t=0: 100% repeatability does not imply correctness. This
  experiment does not measure accuracy."
- "None of this shows accuracy or superiority: Haiku at temperature 0 had 100% agreement
  here, with no abstentions." Haiku t=0 also beats TypeSafe on mean probability std dev.
- The `uid` design confounds two effects: "This setup cannot separate sensitivity to the
  irrelevant field from variation that would occur on identical requests."
- "This policy does not make the model deterministic... a probability near `0.60` can still
  move between a concrete label and `uncertain`."
- The threshold "is an illustrative application policy, not a calibrated guarantee or a
  threshold chosen to maximize this run's agreement. Choose production thresholds using
  labeled examples and the cost of incorrect actions and human review."
- Costs "use the historical price assumptions in Setup" and "are not verified `jev-latest`
  prices or current billing amounts." Latency is measured with LLMs "in a 16-way pool".
- Single-example limit: one post, one rubric, 15 repeats.

## Lessons transferable to other use cases

- Confidence bands with an uncertain middle: a `>= 0.60` top-probability gate over the
  returned distribution turns near-ties into one stable `uncertain` route, raising decision
  agreement 90.8% -> 99.2% here at the price of 25.8% abstention. Generalises to any
  routing decision where human review is cheaper than a wrong action.
- Fan-out: 8 routing questions in one call, priced and timed as one call (114ms,
  $0.000046). Generalises whenever the questions share one state.
- Select-not-generate: fixed label sets make every condition directly comparable and remove
  parse failures (0% for TypeSafe; 1% for `claude-haiku-4-5` t=default).
- Code does the arithmetic: argmax, thresholding, conflict counting and abstention all live
  in Python over `probabilities`, not in the model.
- What does not generalise: stability is not correctness, and jev is not the most stable
  condition on every metric — `claude-haiku-4-5` at temperature 0 was both more repeatable
  (100%) and lower-variance (0.0012) on this single post. The claim that survives is the
  cost/latency ratio and the calibrated middle, not accuracy.

## Use-case entries this supports

- `uc-trust-safety-user-report-triage` — route a reported post to the right enforcement queue
- `uc-trust-safety-policy-violation-bands` — decide allow / warn / review / block from severity and probability
- `uc-observability-evals-confidence-threshold-calibration-fitting` — pick the top-probability cutoff above which you act automatically
- `uc-observability-evals-rubric-scoring-llm-judge-replacement` — answer a multi-question rubric in one sub-second call

**Anti-use-cases implied:** `au-sole-security-gate` — a borderline moderation label is not
stable enough to be the only enforcement authority; the cookbook's own borderline questions
abstain on every repeat and it explicitly measures "repeatability only, not whether its
actions are right". `au-expect-identical-results-across-runs` — raw plurality agreement was
90.8% over 15 repeats, so a rerun is not guaranteed to reproduce a label.
