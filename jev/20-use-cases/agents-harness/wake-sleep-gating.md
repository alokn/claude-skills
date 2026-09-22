---
id: uc-agents-harness-wake-sleep-gating
title: Decide on each cheap poll whether anything warrants waking the expensive agent loop
verdict: good
domain: agents-harness
decision_shapes: [detection, classification, routing]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://github.com/shitianfang/wakegate  (wake/sleep gating for long-running agents; no numbers published)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify, then route to deterministic code, a specialist model, or a human)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot: filter before the call)
related: [uc-observability-evals-alert-worthiness-gating, uc-agents-harness-model-difficulty-routing, au-context-compaction-by-relevance-scoring, uc-support-urgency-detection, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide when an agent should wake up?" Also: "our monitoring
agent burns a frontier turn every five minutes on nothing — can something cheaper stand
watch?", "how do we poll often without paying to think often?", "can jev be the trigger for a
background agent?"

## Verdict

**Good.** The decision is bounded ("is there anything here worth a full turn?"), the input is
text your poller already fetched, the action is cheap and reversible (you wake, look, and go
back to sleep), and there is an obvious low-confidence path. A community project ships exactly
this shape (github.com/shitianfang/wakegate); it publishes no numbers, which is why this is
`good` and not `strong`.

The argument is economic and it is large. A frontier turn per poll costs cents and seconds; a
jev call costs about `chars/4 x $0.042/1e6` and 70-500 ms. That ratio is what lets you raise
the polling frequency, which is usually the actual goal — the agent is not too expensive, it is
too slow to notice things.

## What jev decides

Code fetches the cheap signals and diffs them against the last poll. **Send the diff, not the
world.** This is the design decision that matters: a full inbox, a full dashboard or a full log
is the context-rot failure (jaggedness mode 5), and it is also the expensive part of the bill.

```
warrants_wake: Noul
  instructions: {question: "Does anything in `new_since_last_poll` require the agent to act now?",
                 focus: "A change that needs a decision or a response, not a change that is
                         merely visible."}
  true:  "Something here needs a decision, a reply, or an intervention before the next poll."
  false: "Routine activity, informational updates, or things already handled: nothing that
          needs the agent."

urgency: Score
  criteria: ["Can wait for the next scheduled run.",
             "Should be handled within the hour.",
             "Needs the agent immediately."]

nothing_new: Noul
  instructions: "Is `new_since_last_poll` empty of substantive change?"
```

`nothing_new` is not redundant with `warrants_wake`. A Choice or a Noul is answered relative to
what it is given; an explicit "there is genuinely nothing here" option stops the model
manufacturing significance out of a quiet poll.

Bands, and the asymmetry that sets them: **a false negative is silent.** A missed wake produces
no log line, no alert and no complaint until something has already gone wrong. So the low band
wakes. Wake on `warrants_wake = true` above your threshold, wake on anything below the
confidence floor, sleep only on a confident `false`. That is fail-open by design.

## What stays in code

The poll schedule, backoff, and every API call that fetches the signals. The diff against last
poll state and the deduplication of things already handled. Deterministic wake triggers —
a page, a webhook, an SLA breach, a keyword on a known-critical channel — fire first and never
consult jev. The maximum sleep interval: wake unconditionally every N polls regardless of the
answer, so a systematic false negative cannot last forever. Secret redaction before the call.
The budget cap. And the counters: polls, wakes, wakes that found nothing, and the delayed-wake
audit described below.

## Numbers

No source publishes accuracy, wake precision or recall for this pattern; wakegate ships without
measurements.

Cost method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A 2,000-character
diff plus three questions with criteria (~1,600 characters) is about 900 tokens, **=
$0.000038 per poll**. Multiply by your own poll rate and resource count: at one poll a minute
that is 43,200 polls per resource per month, but the cadence and the resource count are
assumptions, not measured volumes, so no dollar total here is sourced.
Latency from the model page: "70 to 500 ms, most queries about 100 ms"; one integration author
reports it "slower from Europe than the published 70 to 500 ms"
(github.com/AboveColin/HA-Jev), so measure from where your poller runs.

The number that decides whether this is working is not accuracy, it is **the false-negative
audit**. Because a missed wake is silent, you must manufacture the label: wake unconditionally
on a random sample of polls (say 5%) and record how often the full agent found something the
gate had rated `false`. That sampled miss rate is the only honest measure of the gate, and it
doubles as the labelled set for fitting the threshold — roughly 100+ labelled polls per
question before a threshold means anything.

## When the verdict flips

- **A missed wake is expensive or irreversible.** Then `no`. Pager duty, safety, payment
  deadlines, anything with an SLA. Poll deterministically.
- **A deterministic trigger exists.** Webhooks, change feeds and event streams beat polling
  outright: no model, no cost, no misses. Use them wherever the source offers them.
- **You never run the false-negative audit.** Without it the gate looks perfect forever, because
  its failures produce silence.
- **The diff is large or unstructured.** Sending a whole dashboard re-introduces context rot and
  the cost advantage shrinks toward the frontier call you were avoiding.
- **Wake-ups are cheap anyway.** If the agent's turn costs a fraction of a cent, the gate is
  added latency and an added failure mode for no saving.
- **The API is unavailable.** A launch-day outage has been reported for this API; the circuit
  breaker must fail to waking, not to sleeping.

## Alternatives considered

- **Deterministic rules on the diff** (new row, status changed, keyword present). Free, exact,
  auditable, and correct for most of the volume. Keep them as the first-pass trigger; jev is for
  the residue that rules keep getting wrong in both directions.
- **Webhooks or an event stream.** Strictly better when available — push beats poll.
- **Waking the frontier agent every poll.** The incumbent, and the cost this removes. Also the
  ground truth for the audit sample.
- **A small local LLM as the gate.** No network hop, no per-call cost, comparable labels;
  independent head-to-heads put a small model at roughly 1.4x-3.7x the latency, and in one
  149-row run the two differed in how often they fell below the chosen threshold (34.7%
  against 2.7%). That is a coverage trade-off: a local model exposing logprobs can carry the
  same below-threshold wake rule, and without one it sleeps through things confidently.
- **A fine-tuned classifier on your own wake history.** The right destination once the audit has
  produced a few hundred labels. jev buys the cold start.
- **Embedding similarity to previously-interesting diffs.** Cheap and local, but it cannot
  express "needs a decision" versus "looks like things that needed decisions".

## Sources

- https://github.com/shitianfang/wakegate — accessed 2026-09-19 (wake/sleep gating for
  long-running agents; no numbers published)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19 ($0.042 per million input tokens,
  output free; 70-500 ms, "most queries about 100 ms")
- https://docs.typesafe.ai/patterns/intent-routing.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19 (mode 5)
- https://github.com/AboveColin/HA-Jev — accessed 2026-09-19 (latency "slower from Europe than
  the published 70 to 500 ms")
