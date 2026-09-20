---
id: uc-agents-harness-agent-trace-classification
title: Classify agent traces at scale for observability and failure-mode analysis
verdict: good
domain: agents-harness
decision_shapes: [classification, detection, scoring, feature-extraction]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  ("classify giant agent traces"; Harness Engineering: "reasoning trace classification at lightspeed and a fraction of the cost")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  ("Log structured check results and probabilities to make AI system and harness failures easier to trace")
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13 questions in one call: 12.2x cheaper, 10.0x faster, same answers)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens; 250k tokens/s, 1,200 requests/min)
related: [uc-agents-harness-premature-completion-check, uc-data-ml-map-reduce-corpus-labelling, uc-agents-harness-tool-call-trace-verification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to label our agent traces?" Also: "we have 200k sessions and no
idea why they fail", "can we tag every run with a failure mode instead of reading samples?",
"how do we build a dashboard of agent failure categories?"

## Verdict

**Good** — the shape is demonstrated by the use-case map and the `parallel_questions`
cookbook; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. This is one of the named headline categories — "AI Map Reduce
over Big Data ... classify giant agent traces" and "reasoning trace classification at
lightspeed and a fraction of the cost" — and it is the shape jev is best suited to:
offline, high-volume, bounded labels, no latency constraint, no side effects, and a
human able to audit the label distribution. Because output tokens are free and every
question shares one state, a twenty-question taxonomy over a trace costs the same
request as one question.

## What jev decides

State is a *reduced* trace, not the raw log. Code builds it: the task, the tool-call sequence
with names and truncated arguments, error strings, the final message, and the outcome flag.
Raw stdout and repeated payloads are the definition of mode 5.

```python
"outcome": Choice(instructions="How did this run end?", criteria={
   "completed": "The task the user set was delivered",
   "partial": "Some of the task was delivered and the rest was not",
   "abandoned": "The run stopped without delivering or explaining",
   "blocked_externally": "An external system, permission, or missing input stopped it",
   "other": "None of these fits"}),
"failure_mode": Choice(instructions="What went wrong first in this run?", criteria={
   "wrong_tool": "...", "bad_arguments": "...", "looped": "...",
   "lost_context": "...", "misread_request": "...", "tool_error": "...",
   "none": "Nothing went wrong"}),
"user_had_to_correct": Noul("Did the user restate or correct the request after the agent's first attempt?"),
"repeated_same_action": Noul("Did the agent issue the same tool call more than once with no change in arguments?"),
"friction": Score("How much effort did the user have to spend to get what they asked for?",
   criteria=["None — one request, done", "One clarification", "Repeated correction",
             "The user gave up or did it themselves"]),
```

Read `confidence` per trace and keep the low-confidence tail as its own bucket — an
observability taxonomy is more useful with an explicit "unclassified" slice than with
everything forced into a label.

## What stays in code

Trace reduction and redaction, sampling, the taxonomy, aggregation, the time series, and every
count. Never ask "how many tool calls were there" (mode 2) or "did this take more than five
minutes" (mode 3) — those are fields, and putting them in state makes the semantic questions
better.

## Numbers

Throughput and cost are the case. A reduced trace of 3,000 tokens with a 20-question battery
runs about 3,500 input tokens, roughly $0.00015 per trace at $0.042 per million input tokens
with output free — about $15 per 100,000 traces. Rate limits at the time of writing are 250,000
tokens per second and 1,200 requests per minute, adjusting dynamically, so a large backfill
needs a throttle and the SDK's retry-with-backoff.

Batching is what makes the taxonomy free: the parallel-questions cookbook measured 13 questions
over one ~54,000-character document as one call at $0.000497 and 0.27s versus 13 calls at
$0.006090 and 2.71s — "12.2x cheaper, 10.0x faster" with identical answers, and the saving grows
"the bigger the document". Run-to-run stability there was exact for 11 of 13 questions across 5
runs (std dev 0.0), with two questions showing std 0.0055 and 0.0084 regardless of batching.

Closest jaggedness mode: **5, large state full of irrelevant detail** — the reduction step is
the whole design.

- Field evidence (community-report): Langfuse's worked example runs user-disagreement detection over chat traces as a trace-level jev evaluator alongside its rubric scorers, 2026-09-18. Source: https://langfuse.com/blog/2026-09-18-using-typesafes-jev-for-evals
- Field evidence (community-report): two agent-trace observability tools review permissions granted and completions claimed across recorded sessions; neither publishes numbers, 2026-09. Source: https://github.com/qkal/Canny

## When the verdict flips

- **Structured telemetry already answers it.** Exit codes, error classes, tool-error counts,
  latency percentiles. Those are exact and free; use jev only for the categories your
  instrumentation cannot emit ("misread the request").
- **You need an explanation, not a label.** Generation is mode 9; jev gives you the bucket and
  the probability, and a person or an LLM reads the exemplars.
- **Traces contain secrets or customer data.** Redact in code first. Hosting is cloud-only (US
  West); zero data retention is an enterprise term.
- **The taxonomy is unknown.** Jev classifies into labels you define. Discover the categories by
  reading a sample first, then scale with jev.
- **You want to act on a single trace in real time.** That is a different job — see the
  completion check and tool-call verification entries.

## Alternatives considered

- **Regex and log greps** — free and exact for error strings and exit codes; keep them, and they
  should populate the state.
- **Frontier LLM labelling** — the incumbent for trace analysis and the reason most teams label
  a 200-row sample instead of the population; the cost and latency difference is the point.
- **Small LLM labelling** — cheaper, still returns text to parse, and can emit a label outside
  your taxonomy, which a Choice cannot.
- **Embedding clustering of traces** — good for *discovering* the taxonomy, bad at assigning a
  named category you can act on. Use it first, jev second.
- **Human reading of sampled traces** — the highest-quality signal and the thing to spend on the
  low-confidence bucket rather than on the whole population.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/llm_guardrails.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
