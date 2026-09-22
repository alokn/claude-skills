---
id: uc-agents-harness-function-call-argument-filling
title: Fill closed-set function arguments from a natural-language request without JSON repair
verdict: good
domain: agents-harness
decision_shapes: [routing, classification, extraction]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/function_calling.md  (10 functions, 28 fillable arguments, 54 questions per command, 14 worked commands with confidences)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9: bounded extraction as a Choice, not generation)
  - https://docs.typesafe.ai/patterns/fan-out.md  (one call carries every branch's questions)
related: [uc-agents-harness-skill-or-tool-selection, uc-data-ml-pre-parsed-value-selection, uc-search-retrieval-query-intent-classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for function calling?" Also: "our tool calls come back with
invalid enum values and we keep retrying", "can jev turn 'candles for tesla with a 20 period
moving average' into a typed call?", "how do we keep a function's defaults instead of making
the model invent an argument?"

## Verdict

**Good**, for arguments drawn from closed sets — the shape is demonstrated by the
`function_calling` cookbook; no task-matched labelled accuracy is published;
shadow-evaluate against the incumbent before acting. Because every argument is a Choice
over the function's own `Literal` values, "whatever reaches the function is a value the
function accepts" — no JSON repair, no invalid-enum retries, no schema violation
possible. The condition is coverage: only `Literal`, `list[Literal[...]]` and `bool`
arguments get questions. "Free text, numbers and dates work the same way: no question,
and the function's own default stands."

## What jev decides

State is the raw command string — no JSON envelope. Questions are *generated from the
signatures*, not hand-written; `spec.json` supplies only the wording the type cannot express.

```
__tool__                      choice  What is the user asking the trading assistant to do?
plot_price.style              choice  Does the user want a plain line or candles?
plot_price.style?             noul    Does the user say how the chart should be drawn, such as a line, candles, or OHLC bars?
compare_returns.symbols.NVDA  noul    Does the user want NVDA in the comparison?
```

Three shapes: a `Literal` becomes a Choice whose option keys *are* the strings the function
takes ("so nothing has to map a label back to an argument afterwards"); a `list[Literal[...]]`
gets one Noul per member; a `bool` gets one Noul. Every optional argument gets a `stated`
companion Noul — "When the answer is no, the call leaves that argument out and the function's
own default applies." Without it, "the choice would have to name some window, and it would have
named one confidently."

One request carries the function Choice *and* every function's arguments; code reads only the
chosen branch (speculative fan-out).

Confidence is "the least certain judgement in the call, rather than the product of all of them,
since one wrong argument is enough to spoil the result. A product answers a different question
('is every part right'), and it falls as a function takes more arguments, whether or not any
one judgement is shaky." `call.weakest()` names the argument to check.

## What stays in code

Signature introspection and question generation, the dispatch, every non-closed-set argument
(ints, free text, dates, numbers), the confidence gate before any side effect, and the
confirmation prompt. The cookbook defines no abstain threshold — you must add one, and it must
scale with the action: the confidence-routing pattern uses 0.6 to read a balance and >0.85 to
approve a transfer.

## Numbers

From `function_calling.md`, `jev-1.12`: "10 functions over 156,780 one-minute bars", "28
fillable arguments in total", "54 questions per command", 14 hand-written commands, each run
once. Call confidences ranged 0.53 to 1.00 — e.g. `list_symbols()` 1.00, `volatility(symbol=
'TSLA')` 0.96, `plot_price(symbol='NVDA', resolution='1h')` 0.78, `intraday_pattern(symbol=
'NVDA')` 0.53. Per-argument breakdown for "is amd tracking nvidia lately" (confidence 0.82):
`symbol 'AMD'` p 0.87, `benchmark 'NVDA'` p 0.78, `window` and `resolution` omitted at 0.96 and
0.99, "weakest argument: benchmark". Accuracy, latency, cost and token counts: **not reported**;
no LLM baseline is run.

Closest jaggedness mode: **9, generation.** The whole design is the documented rewrite — "when
the answer space is bounded, turn extraction into a Choice over the options rather than asking
for the value itself."

- Field evidence (community-report): typed function and tool dispatch over a closed argument set is listed as a canonical community pattern in the main awesome list; no numbers published, 2026-09. Source: https://github.com/Anil-matcha/awesome-jev-by-typesafe

## When the verdict flips

- **Arguments are open-ended** — free text, ids, amounts, dates. Jev fills closed sets only;
  parse those in code or let the default stand. A call that is mostly free text is **weak**.
- **Your provider's native tool-calling already validates against the schema and rarely fails.**
  Then the win is latency and cost, not correctness; measure your actual retry rate first.
- **The function has a side effect and you ship without a confidence gate.** That is **no** —
  the cookbook defines none, and 0.53 on a real command shows why you must.
- **Very many functions.** 54 questions over 10 functions is cheap; the fan-out grows with the
  catalogue, so rank first (see the skill-selection entry) and fill arguments for the winner.
- **Two arguments draw from the same list** (symbol vs benchmark). They only separate because
  the spec spells out the roles — "*the one being measured, named first*" against "*the second
  one named, the yardstick*". Without that wording, expect swaps.

## Alternatives considered

- **Native LLM tool calling** — the default, and the one to beat: it handles open-ended
  arguments, which jev cannot. Its costs are latency, price, invalid-enum retries and no
  per-argument confidence.
- **Regex / grammar over the command** — exact for structured commands ("show NVDA 1h"), useless
  for "is amd tracking nvidia lately".
- **Constrained decoding / JSON-schema mode on a small LLM** — also guarantees validity, and is
  the closest technical competitor; it gives no typed per-argument probability and no
  cheap way to say "the user did not specify this".
- **Slot-filling NLU (Rasa, Dialogflow)** — mature and fast, but needs intent/entity training
  data and re-training whenever the signature changes; jev reads the signature.
- **Ask the user** — the correct fallback for the weakest argument, not a replacement.

## Sources

- https://docs.typesafe.ai/cookbooks/function_calling.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/fan-out.md — accessed 2026-09-19
