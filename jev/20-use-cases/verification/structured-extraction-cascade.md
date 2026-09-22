---
id: uc-verification-structured-extraction-cascade
title: Build structured extraction as a cascade — cheap model, jev verifier, reasoning model only on failures
verdict: good
domain: verification
decision_shapes: [routing, verification, extraction]
primitives: [noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (rung 0 / verifier / rung 1; price table; gpt-5.5-reasoning ~0.81 quality for ~$0.10/extraction; threshold swept 0->1)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (code owns control flow; insert System One where AI is needed)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (weakest on precise extraction; extraction as Choice over candidates)
related: [uc-verification-extraction-field-verification, uc-agents-harness-model-difficulty-routing, uc-data-ml-pre-parsed-value-selection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev in our document-extraction pipeline?" Also: "we pay reasoning-
model prices on every invoice — can we only escalate the hard ones?", "should jev do the
extraction or check it?", "how much of the big model's quality can we keep for a fraction of
the cost?"

## Verdict

**Good**, with the roles fixed: jev is the *verifier* and the *spend router*, not the
extractor — the shape is demonstrated by the `sde_cascade` cookbook; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
"get most of the quality of a big reasoning model at a fraction of the cost" is the
cookbook's own framing, and the architecture is the one the design guide describes —
code owns the control flow and inserts a typed decision where judgement is needed. Two
conditions: the verifier "has to be cheap, or there are no savings left to capture", and
the gate threshold is a knob to sweep on your data, not a number to copy.

## What jev decides

Three rungs, all orchestrated by code:

1. **rung 0** — a cheap model extracts the record against your schema.
2. **verifier** — one jev call carrying the whole battery of `field::metric` Nouls over
   `{system_message, instruction, source_text, schema, extraction}`, every question framed so
   `true` means the field is wrong (see the field-verification entry for the seven heads).
3. **rung 1** — a reasoning model re-extracts, but only for records the gate fires on.

```python
fired = {qid: p for qid, p in checks.items()
         if not qid.startswith("__overall__") and p > FIRE_T}      # FIRE_T = 0.7
escalate = bool(fired)
final_record = extract(REASONING, ...) if escalate else mini_record
```

The cookbook also computes a holistic `__overall__::judge` head "to contrast a whole-record
judgment with the per-field heads", and then states that "the gate in Step 4 does **not** use
it" — keep it as an observability column, not as the gate.

## What stays in code

The rung ladder, the schema, JSON parsing, the gate threshold and its sweep, the escalation
budget, and the fail-safe. The cookbook claims the fail-safe is automatic — a record that fails
`json.loads` returns `{}`, "so every field reads as absent, which the verifier flags and the gate
escalates — the safe direction" — but **its own code does not do this**, so you must. There is no
abstain; the low-confidence direction is escalation.

Parse failures and missing required fields are code's job and must be handled
deterministically *before* jev verification runs: an empty or unparseable extraction, or
a record missing a required key, has to escalate on the schema check alone. The
`sde_cascade` cookbook's own loop iterates `record.items()`, so `{}` produces no field
checks at all and a missing key is never asked about. Code also owns a separate
uncertainty policy for middling error probabilities — a `P(wrong)` near 0.5 is neither a
pass nor a fire under a one-sided gate, so route that band to review explicitly rather
than letting the default carry it.

## Numbers

From `sde_cascade.md`. Prices, "$ per 1M tokens, input / output; standard rates checked
September 15, 2026":

| Rung | Model | Price |
|---|---|---|
| rung 0 (mini) | `gpt-5.4-mini` | $0.75 / $4.50 |
| rung 1 (reasoning) | `gpt-5.5` | $5.00 / $30.00 (roughly 7x the mini) |
| verifier | TypeSafe `jev-1.12` | $0.042 / $0.00 (output tokens are free) |

That ratio is the mechanism: the verifier costs about 1/18th of the mini's input rate and
nothing for output, so it can run on every record and still be rounding error against the rung
it avoids. Aggregate run: "100 scrapegraphai prompts" with the gate threshold "swept 0->1",
plotted in (cost, quality) space. The only numeric point given in prose is the strongest single
model: `gpt-5.5-reasoning` "sits top-right at ~0.81 quality for ~$0.10/extraction". **The
cascade's own cost and quality points, and the escalation rate at any threshold, are not
reported numerically** — they appear only in the chart. Latency and token counts: not reported.
The 100-prompt figures are "internal TypeSafe results", and "the chart is a historical snapshot;
its costs have not been recalculated at the current Jev rate listed above".

Closest jaggedness mode: **9, generation.** The rewrite is structural — a generative model
produces the value, jev judges it.

## When the verdict flips

- **You copy the cookbook's escalation gate verbatim.** That is a known defect, not a starting
  point: `sde_cascade` iterates `record.items()`, so an empty `{}` produces no field checks and
  the escalation flag stays `false`; missing required keys evade the per-field checks the same
  way; and a `P(wrong)` of 0.5 does not escalate under the `> 0.7` gate. Schema-validate first and
  add an explicit uncertain band, or the cascade silently passes exactly the records it exists to
  catch.
- **The cheap model is already good enough.** No escalation means no savings to route; the
  verifier is then pure overhead — **weak**.
- **The cheap model is bad enough that almost everything escalates.** You pay all three rungs.
  Sweep the threshold and measure the escalation rate before committing.
- **The fields are exactly checkable** — totals that must sum, ids that must exist, dates in a
  known format. Validate deterministically; that is cheaper and certain.
- **You ask jev to do the extraction.** That is **no** for anything precise: TypeSafe's own
  evals place jev weakest on invoice-style extraction. Bounded fields are the exception —
  enumerate candidates and use a Choice.
- **Latency per document matters.** The cascade adds a hop, and escalated records pay two
  extraction calls.

## Alternatives considered

- **One strong model on everything** — the quality ceiling and the cost baseline (~$0.10 per
  extraction here); the cascade exists to approach it for less.
- **One cheap model on everything** — cheapest and the quality you are trying to recover.
- **Schema validation plus retry** — free and necessary, and it passes fluent fabrications; the
  cookbook's own record printed `schema-valid: True`.
- **Self-consistency (extract three times, vote)** — no verifier needed and triples the
  extraction cost, and stochastic extractors can agree on the same plausible fabrication; the
  cookbook notes `gpt-5.4-mini` "invents a different `description` on nearly every run" even at
  temperature 0, which is what makes voting expensive here.
- **A small fine-tuned extractor** — the right long-term answer with labelled data; the cascade
  is how you get labelled data cheaply in the meantime.
- **Human QA on a sample** — measures the pipeline; cannot gate it at volume.

## Sources

- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
