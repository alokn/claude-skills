---
id: au-open-ended-agent-loop
title: Do not let jev choose its own next action in an open-ended loop
verdict: no
domain: agents
decision_shapes: [routing]
primitives: [choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("every loop introduces another opportunity to go off the rails"; "Avoid agent `while` loops when a software workflow can express the same behavior")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("System Two tasks: more layers of indirections")
  - https://docs.typesafe.ai/primitives.md  ("Every answer is independent")
  - https://empryo.com/blog/jev-and-the-harness  (15% on next-tool prediction)
related: [au-predict-next-tool-call, au-chain-questions-in-one-request, au-review-loop-pass-fail-gate, au-real-time-from-raw-pixels]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to build an agent whose planner is jev?" Also "let jev pick the next step until the
task is done", "jev as the orchestrator over our tools", "replace our ReAct loop with a cheap typed
model".

## Verdict

**No.** Jev is a decision function, not a planner, and TypeSafe's design guidance is built around the
distinction. The how-to-build guide contrasts three architectures and says of the agent one: "An agent
processes instructions and chooses its next step. This works well when a person is monitoring the process,
but every loop introduces another opportunity to go off the rails." Its first design step is "Use code
when you can ... Avoid agent `while` loops when a software workflow can express the same behavior." The
jaggedness page lists "System Two tasks: more layers of indirections" among the things to avoid.

Closest failure mode: **indirection** — every loop adds a layer between the state and the
decision, which is the System Two shape the jaggedness page says to avoid.

## What jev would get wrong

Planning needs memory of what has been tried and inference about what follows, and jev has neither within
a call: "Every answer is independent. One question's answer is not hidden context for another." Every step
would need a fresh request carrying a state your code assembled — so your code is already the planner. The
one published measurement of jev choosing a next action is discouraging: Empryo found 15% accuracy on
predicting subsequent tool calls, behind keyword counting at 26%. An open loop also has no bound on steps,
so errors compound with no stopping condition, and jev cannot generate the reasoning a human would need to
debug the plan.

## What stays in code

The control flow, in full. A state machine, a DAG, or an ordinary function with branches. Code decides
what runs next, code holds the step budget, code holds the termination condition, and code performs every
side effect. That is the "AI-powered software" architecture the guide describes: "Code handles
deterministic work and owns the control flow. The model appears only where the system needs programmable
common sense or needs to interpret unstructured data. Each AI task is kept atomic and constrained."

Jev's place inside that workflow is at the branch points: a Choice over the small, enumerated set of next
steps *this* node allows, with described criteria and a confidence gate; a Noul "Is `evidence` sufficient
to answer `request`?" as a termination check evaluated by code; a Choice over which specialist model or
queue should handle the case. Bounded routing, not planning.

## Numbers

Empryo measured jev at 15% on next-tool prediction against 26% for keyword counting
(https://empryo.com/blog/jev-and-the-harness, accessed 2026-09-19). A routing Choice over 12 next steps
with a 1,000-token state is roughly 1,400 input tokens, about $0.00006 at $0.042 per million input tokens
with output free (https://docs.typesafe.ai/models.md), typically about 100 ms per branch point.

## When the verdict flips

It flips to **good** when the loop becomes a graph your code owns. Conditions: the set of next actions at
each node is enumerated and small; the number of steps is bounded by code; every side effect is executed
by code after a confidence check; and a second jev call is used only where the first answer determines
what evidence to fetch — which the docs support, since an answer can be "put into the state of a follow-up
request". That is a two-step workflow, not an agent. **No rewrite exists** for an unbounded loop in which
jev both chooses and acts; if you need open-ended planning, that is System Two work and belongs to a
reasoning model with a human watching.

## Alternatives considered

- **Regex / deterministic**: the state machine. This is the answer for anything whose steps you can draw.
- **Small LLM**: can plan, badly; still needs the same guard rails.
- **Frontier LLM / agent framework**: the correct tool for open-ended planning, with human monitoring.
- **Fine-tuned classifier**: could learn the branch policy from traces; loses the calibration.
- **Embeddings**: retrieve similar past workflows.
- **Human**: monitors the agent — the condition under which the guide says agents work well.

## Sources

- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
