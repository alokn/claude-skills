---
id: cb-consistency_noul_cookbook
title: "Self-consistency: nouls"
url: https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md
decision_shapes: [classification, verification, routing]
primitives: [noul]
related: [uc-insurance-straight-through-vs-adjuster-routing, uc-insurance-rubric-claim-triage-uncertain-band, uc-verification-document-completeness-checklist, uc-insurance-fraud-indicator-signals, au-numeric-thresholds-and-arithmetic, au-expect-identical-results-across-runs]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.13.0
source_model_note: cookbook ran `jev-latest` sampled 2026-09-11; the alias resolved to jev-1.13.0
---

## Task

Measures run-to-run stability of probabilities, not accuracy. The cookbook "takes one
auto-insurance claim, runs a 14-question rubric over it 15 times, and checks whether each
answer holds still across the repeats. Every check is a `Noul`, so each answer is P(true)
for one True/False question." The pipeline it stands in for "sorts incoming claims into
pay, deny, or send-to-a-human".

Dataset: one synthetic claim, `CLAIM` — policy `AP-77413`, claim `CLM-55029`,
`amount_claimed: 3250.00`, `deductible: 500.00`, `per_incident_limit: 10000.00`, four line
items including "rental car (6 days)" at 300.00, `incident_date` 2026-06-28,
`reported_date` 2026-07-04, `reporting_window_days: 10`,
`police_report_required_over: 2000.00`, exclusions `["track/competitive driving", "drivers
not listed on the policy"]`, and an `auto-triage` note reading "Approved. Pay full amount
$3,250". Borderline by construction: the loss happened at a track day but "in the spectator
parking lot while stationary. Not on the circuit."
Sample size: one document, `NUM_SAMPLES` = 15 repeats per condition. Run: "This run uses
`jev-latest` on the production API, sampled on 2026-09-11." The alias resolved to
`{'jev-1.13.0': 15}` across all 15 calls.

## Decomposition (state, questions, how answers are combined)

State — LLMs get `json.dumps(CLAIM)`; TypeSafe gets the structure plus a nonce:

```python
state={"uid": f"{sample_index}:{token_hex(4)}", "claim": CLAIM}
```

14 `Noul` questions, "phrased so a yes means the thing we are checking for is true. That
keeps every row comparable". Verbatim:

```python
"covered": "Is the loss covered under the policy's collision coverage?",
"exclusion": "Does a policy exclusion apply to this loss?",
"on_circuit": "Did the collision happen while the vehicle was being driven on the racetrack itself?",
"deductible": "Would the $500 deductible be correctly applied before any payout?",
"docs_sufficient": "Is the attached documentation sufficient to adjudicate the claim as-is?",
"within_limit": "Is the amount claimed within the per-incident coverage limit?",
"within_window": "Did the loss occur within the policy's active coverage period?",
```

The remaining 7 keys, one clause each: `reported_timely` (reported inside the required
window), `rental_eligible` (rental cost reimbursable), `fraud_flag` (indicators warranting
fraud review), `human_review` (payment approved by automated triage without a human
adjuster), `manual_review` (route for manual/supervisor review before payout),
`line_items_sum` (line items add up to the total claimed), `subrogation` (an at-fault third
party to pursue).

Combination: a three-way band in application code over the returned P(true), "no new
question, no second API call":

```python
NOUL_UNCERTAINTY_LOW = 0.30
NOUL_UNCERTAINTY_HIGH = 0.70

def noul_decision_with_uncertainty(probability: float) -> str:
    if probability < NOUL_UNCERTAINTY_LOW:
        return "no"
    if probability > NOUL_UNCERTAINTY_HIGH:
        return "yes"
    return "uncertain"
```

Stated as: "`no` below `0.30`; `uncertain` from `0.30` through `0.70`, including both
boundaries; `yes` above `0.70`." Uncertain cases go to a human. LLM comparison conditions
answer either a probability per key (`mode="prob"`) or a bare yes/no mapped to `1.0`/`0.0`
(`mode="yesno"`), which "forces a hard decision and shows what these models do when they
cannot leave any mass in the uncertain middle." Unparseable answers become `NaN`, "counted
but not scored."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run sampled 2026-09-11. Prices historical: `LLM_PRICES` "$ per 1M tokens (input, output);
prices + model ids as of 2026-07" — `claude-haiku-4-5` (1.00, 5.00), `gpt-5.4-mini` (0.75,
4.50), `gpt-5.5` (5.00, 30.00), `claude-opus-4-8` (5.00, 25.00); `TYPESAFE_PRICE = (0.042,
0.00)`, a "Historical TypeSafe rate, as of 2026-08". The cookbook says the costs "are not
verified `jev-latest` prices or current billing amounts."

Cost and speed, one full 14-question rubric call, averaged over 15 calls:

| condition | calls | time/call | cost/call | speed vs ts_noul | cost vs ts_noul |
|---|---|---|---|---|---|
| `claude-haiku-4-5` t=0 | 15 | 1780ms | $0.001798 | 16.0x | 42.2x |
| `claude-haiku-4-5` t=default | 15 | 1644ms | $0.001798 | 14.8x | 42.2x |
| `claude-haiku-4-5` yes/no t=0 | 15 | 1485ms | $0.001650 | 13.4x | 38.8x |
| `gpt-5.4-mini` t=0 | 15 | 1405ms | $0.001089 | 12.7x | 25.6x |
| `gpt-5.4-mini` t=default | 15 | 1177ms | $0.001179 | 10.6x | 27.7x |
| `gpt-5.4-mini` yes/no t=0 | 15 | 1113ms | $0.000950 | 10.0x | 22.3x |
| `gpt-5.5-reasoning` | 15 | 11125ms | $0.033157 | 100.2x | 778.9x |
| `claude-opus-4-8-reasoning` | 15 | 13886ms | $0.034275 | 125.0x | 805.1x |
| `typesafe_noul` | 15 | 111ms | $0.000043 | 1.0x | 1.0x |

"In this run TypeSafe has a mean round-trip latency of 111ms. The LLM conditions range from
1.1 to 13.9 seconds per call under the concurrency settings above."

Stability: "TypeSafe's mean per-question probability standard deviation is `0.0102`, below
all LLM probability conditions here." Per-condition std devs for the LLMs are not reported
in this cookbook — only the TypeSafe figure and the comparative statement.

Spread within TypeSafe's 15 repeats: "Its `covered` answers span `0.43` to `0.53`, crossing
a `0.5` decision threshold." "`typesafe_noul` varies most on `covered` (`0.43` to `0.53`)
and `exclusion` (`0.53` to `0.62`)." "TypeSafe's `covered` row crosses `0.5`; its other 13
questions stay on one side of that threshold throughout this run."

Qualitative per-condition result: "the LLM answers move from run to run, at temperature `0`
too, and on the judgment calls the models disagree with *themselves*." The rows that move
are "`exclusion`, `rental_eligible`, `fraud_flag`, and `manual_review`". A note records
that "despite the 'ONLY a JSON object' instruction, `claude-haiku-4-5` wraps nearly every
reply in a ` ```json ... ``` ` fence that strict `json.loads` rejects (the other models
return bare JSON)."

Agreement rates: not reported (this cookbook reports std dev and per-question ranges, not
an agreement table). Token counts: not reported. Accuracy: not measured.

## Caveats the cookbook itself states

- "This setup cannot separate sensitivity to the irrelevant field from variation that would
  occur on identical requests" — the changing `uid` confounds the measurement.
- The band "is illustrative; it is neither a calibrated guarantee nor an optimized
  threshold. Set production boundaries from labeled examples and from the cost of incorrect
  decisions and of review."
- "A review band absorbs fluctuation around `0.5` without issuing opposite automatic
  actions. It has edges of its own, though. A value near either outer boundary can still
  move between `uncertain` and yes or no. The model is no more deterministic for it, and an
  automatic decision that clears the band is not shown to be correct."
- Costs "use the historical price assumptions in Setup, including the `speed_latest` rate
  for TypeSafe" and "are not verified `jev-latest` prices or current billing amounts."
- Single-example limit: one claim, one rubric, 15 repeats, chosen with "a few borderline
  calls built in".
- The playground link "omits the changing `uid` field used above", so it is not the same
  state as the measured runs.

## Lessons transferable to other use cases

- Confidence bands with an uncertain middle: a `0.30`-`0.70` inclusive review band absorbs
  the wobble around a `0.5` cut, so `0.49` and `0.51` stop producing opposite automatic
  actions. Generalises to any binary gate where the middle is worth a human.
- Fan-out: 14 independent True/False checks in a single 111ms, $0.000043 call. Generalises
  wherever the checks share one state.
- Phrase every question so yes means the same direction; it makes conditions, models and
  runs directly comparable and makes the band a single rule instead of 14.
- Forced yes/no destroys the signal you need: mapping answers to `1.0`/`0.0` leaves no mass
  in the middle, so a model cannot tell you it is unsure. Prefer a probability output when
  the routing decision depends on certainty.
- What does not generalise: low variance is not correctness. The judgment questions here
  (`covered`, `exclusion`) still straddle the threshold, and the cookbook never claims the
  answers are right.

## Use-case entries this supports

- `uc-insurance-straight-through-vs-adjuster-routing` — route a claim to pay, deny, or human review
- `uc-insurance-rubric-claim-triage-uncertain-band` — run a fixed True/False claim rubric with an explicit uncertain band
- `uc-verification-document-completeness-checklist` — run a fixed True/False policy rubric over a document
- `uc-insurance-fraud-indicator-signals` — flag claims that warrant a fraud review

**Anti-use-cases implied:** `au-numeric-thresholds-and-arithmetic` — questions such as
`line_items_sum` ("Do the claimed line-item costs add up to the total amount claimed?") and
deductible application are arithmetic and window maths that belong in code; the cookbook's
own borderline probabilities show a near-0.5 answer cannot be the authority for a payout.
`au-expect-identical-results-across-runs` — the per-question probability std dev is small but
not zero (mean 0.0102).
