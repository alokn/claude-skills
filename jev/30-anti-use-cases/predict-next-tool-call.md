---
id: au-predict-next-tool-call
title: Do not use jev to predict an agent's next tool call
verdict: weak
domain: agents
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: independent-benchmark
sources:
  - https://empryo.com/blog/jev-and-the-harness  (15% accuracy vs 26% for keyword counting; "the intent to call specific tools is largely absent until initial file inspection occurs")
  - https://docs.typesafe.ai/cookbooks/function_calling.md  (function selection from an explicit request)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (agents: "every loop introduces another opportunity to go off the rails")
related: [au-grep-line-ranking, au-open-ended-agent-loop, au-review-loop-pass-fail-gate]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to predict which tool the agent will call next, so we can prefetch it?"
Also "speculatively warm the tool the model is about to use", "route the turn to the right toolset
before the LLM decides".

## Verdict

**Weak**, and measured as such. Empryo's harness evaluation found jev achieved only 15% accuracy on
predicting subsequent tool calls, "significantly underperforming keyword counting (26%) and frontier
models". A keyword-frequency baseline beat it by 11 points at zero cost. The stated reason is not a model
defect but a property of the task: "the intent to call specific tools is largely absent until initial
file inspection occurs."

Closest failure mode: **indirection** — the next tool call is a two-hop inference from an
intent that is not yet in the state, which is why keyword counting beat it (26% against 15%).

## What jev would get wrong

The information required to make the prediction is not in the state. At the point of prediction the agent
has not yet read the files that will determine what it does next, so the future tool call is not
determined by anything jev can see. Jev will still return a well-typed Choice with a confidence value,
because a Choice is relative and always selects something — the output looks like a prediction and is
close to a prior. The failure is therefore invisible unless you benchmark it, which is exactly what
Empryo did.

Note the contrast with a superficially similar task that *does* work: TypeSafe's function-calling
cookbook maps an explicit natural-language request to a function name with a Choice plus closed-set
arguments. There the intent is stated in the state. Prediction of an unstated future intent is a
different task wearing the same clothes.

## What stays in code

The prefetch heuristic, if you want one: keyword counting over the turn so far, recency of tool use,
and the static tool-dependency graph (a `get_weather` call almost always follows a `geocode_city` call).
These are cheap, measured better here, and trivially auditable. Keep the agent's actual tool selection
where it belongs — in the agent model that has the reasoning context.

Jev's productive role in a harness is on traces that already happened, not futures: verifying a tool call
after the fact with one Noul per property (does the tool name suit the request, do the arguments conform
to the schema, do the coordinates match the previous result), which is the decomposition the how-to-build
guide walks through in full.

## Numbers

Measured: 15% accuracy for jev against 26% for keyword counting on next-tool prediction
(https://empryo.com/blog/jev-and-the-harness, accessed 2026-09-19). Cost of the keyword baseline: $0.
Cost of a jev Choice over 30 tool descriptions plus a turn excerpt: roughly 2,000-3,500 input tokens,
about $0.00008-$0.00015 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), plus about 100 ms in the loop.

- Field evidence (community-report): Empryo harness field report, next-tool-call prediction — "keyword counting on the prompt outperformed both Jev (26% vs. 15%)" and frontier models, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness

## When the verdict flips

It flips to **good** when the intent is already expressed rather than predicted. Two concrete forms:
(1) the user's message states what they want and jev picks the function — the function-calling cookbook
shape, with a `none of these` option and a confidence gate; (2) the agent has already read the files, and
jev selects among tools given the now-visible evidence. It also flips for *post hoc* trace verification,
where jev's calibration and ~100 ms latency are genuine advantages over an LLM judge. It does not flip
for predicting an intent the state does not yet contain — **no rewrite exists** for information that is
not there.

## Alternatives considered

- **Regex / keyword counting**: the measured winner at 26%. Free. Use it if you need a prefetch signal.
- **Small LLM**: slower and unmeasured here.
- **Frontier LLM**: Empryo reports frontier models also beat jev on this task, but they are the agent
  itself — asking them to predict their own next call is circular and expensive.
- **Fine-tuned classifier**: viable if you have a large trace corpus; the ceiling is still low because
  the signal is absent.
- **Embeddings**: could match the turn to historical traces; same information limit.
- **Human**: not applicable.

## Sources

- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/function_calling.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
