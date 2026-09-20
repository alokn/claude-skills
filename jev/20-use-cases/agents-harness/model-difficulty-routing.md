---
id: uc-agents-harness-model-difficulty-routing
title: Route each prompt to the cheapest model that can handle it, using intent and difficulty
verdict: good
domain: agents-harness
decision_shapes: [classification, scoring, routing]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Model routing: "build a custom router that chooses which LLM receives each prompt"; "Estimate difficulty and risk")
  - https://docs.typesafe.ai/patterns/intent-routing.md  (intent Choice + complexity Score; confidence < 0.5 to a human)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds: 0.6 to read a balance, >0.85 to approve a transfer)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens; 70-500 ms)
related: [uc-agents-harness-skill-or-tool-selection, uc-verification-extraction-field-verification, uc-search-retrieval-confidence-fallback-broader-level]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev as an LLM router?" Also: "can we send easy prompts to Haiku and
hard ones to Opus?", "how do we decide when to turn on extended thinking?", "we pay frontier
prices for 'summarise this in one line'."

## Verdict

**Good** — the shape is demonstrated by the use-case map and the intent-routing pattern
page; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. The use-case map names it directly — "Use Jev to build a custom
router that chooses which LLM receives each prompt ... Classify intent and domain.
Estimate difficulty and risk. Escalate requests that need a more expensive model" — and
the intent-routing pattern is the worked shape. The router's own cost has to be
negligible against the call it is routing, and at $0.042 per million input tokens with
free output and ~100 ms it is. No cookbook publishes router accuracy, so the numbers
below are the mechanism's economics, not a quality claim.

## What jev decides

State is the user turn plus a compact description of what the system is being asked to do —
not the whole conversation. Filter first (mode 5).

```python
"domain": Choice(instructions="What kind of work does this request call for?", criteria={
    "lookup": "Answerable from a single fact or record the system already holds",
    "reasoning": "Requires multi-step inference, planning, or weighing trade-offs",
    "writing": "Produces prose, code, or a document for a person to read",
    "other": "None of these fits"}),
"difficulty": Score(instructions="How hard is this request to answer correctly?", criteria=[
    "A single lookup or a templated reply",
    "One judgement over material already supplied",
    "Several steps that must be combined",
    "Novel or ambiguous; a careful expert would take time over it"]),
"high_stakes": Noul(instructions="Would a wrong answer to this request cause financial, legal, or safety harm?",
    criteria=NoulCriteria(true="A wrong answer would cost money, breach a rule, or hurt someone.",
                          false="A wrong answer would be an inconvenience the user can correct.")),
"needs_current_data": Noul(instructions="Does answering this require information more recent than the material supplied?"),
```

All four ride one request (speculative fan-out: "adding more questions to a call typically
doesn't add any latency"). Code picks the tier. The confidence floor comes first, as in the
pattern: `if domain.confidence < 0.5: use the strong model` — when the router is unsure, do
*not* save money.

## What stays in code

The model table and its thresholds, the token-length check (a long input may force a bigger
context window regardless of difficulty), retries and downgrades, cost accounting, the
override list ("enterprise tier always gets the frontier model"), and the escalate-on-failure
path. Difficulty is advice; the tier map is policy.

Router failure handling is code's job and must be deterministic. A missing or malformed router
response, a timeout, or a transport error falls back to a configured safe default tier — the
stronger model for anything user-visible, the cheaper one only where a wrong route is
recoverable — and is logged as a route-by-default, not as a routing decision. A domain
confidence below the floor takes the same path up. Known request classes (a health check, an
internal batch job, an enterprise tenant) are routed by a deterministic allow/deny table that
runs before the router and cannot be overridden by it.

## Numbers

Router cost: a 600-token turn plus four questions is roughly 900 input tokens, about $0.000038
per route at $0.042 per million input tokens, output free. Latency 70-500 ms, typically about
100 ms, added to the request path. Compare that with the call being routed — the SDE cascade
cookbook's price table gives `gpt-5.4-mini` at $0.75 / $4.50 and `gpt-5.5` at $5.00 / $30.00
per million tokens, "standard rates checked September 15, 2026", so a router that moves a
fraction of traffic down a rung pays for itself thousands of times over.

The evidence that the *cascade* shape works is in `sde_cascade.md`: a cheap model runs first, a
jev battery decides what escalates, and only flagged items reach the reasoning model. No
published figure measures routing accuracy on general prompts — TypeSafe's own evals place jev
mid-table (67.8%) on agreement with a two-model reference, not on human ground truth, and
publish no abstention curve. That is why the confidence floor routes *up*.

Closest jaggedness mode: **4, indirection.** "Which model should handle this?" is a two-hop
question (what does the task need, then which model supplies it). Ask about the task's
properties and let code own the mapping.

- Field evidence (community-report): jev as the difficulty-tier classifier in NVIDIA NeMo Switchyard model routing, 4 tiers over 40 calls (10 per tier), median 0.643-0.674 s and $0.000025-$0.000027 per call, confidence 1.0 on the simple / complex / reasoning tiers and 0.57-0.67 on the medium tier, against "Gemini 3.5 Flash" at 2.1 s and "DeepSeek V4 Flash" at 7.2 s; latency evidence only, no accuracy measured and never integrated into Switchyard, 2026-09-17. Source: https://dev.classmethod.jp/en/articles/jev-for-llm-model-routing/
- Field evidence (community-report): at least three independent cheapest-capable-model routers for coding turns shipped within days of launch; none publishes accuracy or latency, 2026-09. Source: https://github.com/gargpratyush/jev-router
- Field evidence (community-report): two independent per-request model routers for the Pi agent; no numbers published, 2026-09. Source: https://github.com/mejiasd3v/pi-jev-router
- Field evidence (community-report): per-message selection of both the Claude model and the reasoning-effort level, treating effort as a second Choice in the same call; no numbers published, 2026-09. Source: https://github.com/adarshmishra07/jcm-router
- Field evidence (community-report): policy-bounded model tiering, where a written policy caps which tier a request may reach and jev picks within the cap; no numbers published, 2026-09. Source: https://github.com/iamvatsalpatel/tiershift
- Field evidence (community-report): difficulty-based subagent delegation inside an OpenCode orchestrator, routing a turn to a cheaper or more capable subagent; no numbers published, 2026-09. Source: https://github.com/aaronshaf/opencode-jev-orchestrator

## When the verdict flips

- **The router has no deterministic default.** If a timeout or a malformed response can leave a
  request unrouted, or if a below-floor confidence quietly picks the cheap tier, the router is a
  new failure source rather than a saving. Fix the default before shipping it.
- **Two models, and the cheap one is nearly as good.** Send everything to the cheap one and
  escalate on a verifier's failure (the cascade) rather than predicting difficulty up front.
- **Deterministic signals already separate the traffic** — endpoint, feature flag, tenant tier,
  input length, presence of an attachment. Use them; they are free and exact.
- **Latency budget under ~150 ms end to end.** The router's own hop may cost more than the
  saving.
- **The router becomes a quality gate.** If a wrong route silently degrades an answer with no
  detection, you have hidden a failure; keep an escalate-on-failure path so a bad cheap answer
  is recoverable.
- **Difficulty depends on counts or sizes** ("more than 20 rows", "over 5MB"). Modes 2 and 3:
  compute in code.

## Alternatives considered

- **Length / token-count heuristic** — free and surprisingly effective; the honest baseline to
  beat, and it should stay as a pre-filter.
- **Trained router on logged (prompt, model, outcome) data** — better once you have outcomes,
  and the endpoint to aim for; jev is the cold-start router that generates those logs.
- **Cascade with a verifier instead of a predictor** — often strictly better: you find out
  whether the cheap model coped rather than guessing. Use jev as the verifier (see the
  extraction-cascade entry). Routing wins when the cheap attempt itself is expensive or
  user-visible.
- **A small LLM as the router** — same latency class as the model it is protecting, returns
  prose to parse, and no typed confidence to floor on unless you read logprobs.
- **Always use the frontier model** — the status quo; correct when volume is low, and the thing
  this replaces when it is not.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/intent-routing.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/confidence-routing.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
