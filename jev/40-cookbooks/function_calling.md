---
id: cb-function_calling
title: Function calling
url: https://docs.typesafe.ai/cookbooks/function_calling.md
decision_shapes: [routing, classification, extraction]
primitives: [choice, noul]
related: [uc-agents-harness-function-call-argument-filling, uc-agents-harness-skill-or-tool-selection, uc-search-retrieval-query-intent-classification, uc-support-intent-routing-handlers, uc-realtime-voice-command-intent-risk-scaled-thresholds, au-free-form-value-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

"Turns natural-language trading requests into calls to ordinary typed functions by mapping
function names and closed-set arguments to confidence-aware TypeSafe questions." A sentence
goes in; "out comes a function name and its arguments as evaluated enums, each with a
confidence." The result is a `Dispatcher` you point at your own functions.

Dataset: 10 ordinary Python functions in a trading assistant (`trader.py`) over "156,780
one-minute bars", and 14 hand-written commands run through the dispatcher. Source: the
cookbook's own modules; no external corpus. Model: `TYPESAFE_MODEL = "jev-1.12"`. Date
sampled: not reported. Answers are read from a shipped cache so "re-rendering replays the
numbers below without calling the API."

## Decomposition (state, questions, how answers are combined)

State: the raw command string (e.g. `"is amd tracking nvidia lately"`). No JSON envelope.

Questions are generated, not hand-written. `closed_sets` reads each signature and sorts
arguments into three shapes — "a **choice** (a `Literal`, so one value out of the list), a
**set** (a `list[Literal[...]]`, so any number of them), or a **flag** (a `bool`, so on or
off)." Arguments outside those shapes get no question: "Free text, numbers and dates work
the same way: no question, and the function's own default stands" (e.g. `top_movers`'
`limit: int` keeps its default of 3).

Counts: `plot_price` 7 fillable arguments, `rolling_correlation` 4, `intraday_pattern` /
`compare_returns` / `volatility` / `drawdown` 3 each, `summary_stats` / `top_movers` 2,
`market_summary` 1, `list_symbols` 0 — "28 fillable arguments in total", expanding to "54
questions per command".

`spec.json` supplies the wording: "a question per argument, a line per option, a
description per function, and one more question that picks between the functions."
Verbatim example:

```json
{"style": {
  "question": "Does the user want a plain line or candles?",
  "stated": "Does the user say how the chart should be drawn, such as a line, candles, or OHLC bars?",
  "options": {"line": "a simple line through the closing prices",
              "candles": "a candlestick or OHLC chart, showing each bar's open, high, low and close"}}}
```

Four representative generated questions and their types:

```
__tool__                      choice  What is the user asking the trading assistant to do?
plot_price.style              choice  Does the user want a plain line or candles?
plot_price.style?             noul    Does the user say how the chart should be drawn, such as a line,
compare_returns.symbols.NVDA  noul    Does the user want NVDA in the comparison?
```

Combination: "Each command is then one request carrying the choice of function and every
function's arguments, and the dispatcher reads only the chosen function's answers." The
`stated` companion `Noul` makes an argument optional — "When the answer is no, the call
leaves that argument out and the function's own default applies." A set argument "gets its
question once per member, with `{}` standing in for the member name". Option keys are the
strings the function takes, "so nothing has to map a label back to an argument afterwards."

Confidence: "`confidence` reports the least certain judgement in the call, rather than the
product of all of them, since one wrong argument is enough to spoil the result. A product
answers a different question ('is every part right'), and it falls as a function takes more
arguments, whether or not any one judgement is shaky." `call.weakest()` names the weakest
argument. No abstain threshold is defined in this cookbook.

**Possible source inconsistency — the stated rule may not reproduce the printed example.** For
"is amd tracking nvidia lately" the cookbook reports call confidence **0.82** while the weakest
argument it names, `benchmark`, is printed at **p 0.78**. If both figures are the same statistic,
a minimum over the argument judgements would give 0.78. They may not be: the printed `p` is an
argument-level probability and may not be the quantity the call's `confidence` minimises, and the
two figures may come from different runs. The cookbook does not say, so read the aggregation code
and confirm which fields are being compared before asserting a contradiction. Treat minimum-of-arguments as a **heuristic summary**, not a definition,
and never as a probability that the whole call is correct — a minimum is not a joint probability,
and the cookbook is explicit that a product "answers a different question".

## Numbers reported (verbatim, with what they compare against and the run date if given)

Scale: "10 functions over 156,780 one-minute bars"; "28 fillable arguments in total"; "54
questions per command".

All 14 commands and their resulting call confidence and `__tool__` probability:

| command | call | confidence | tool |
|---|---|---|---|
| "show nvda 1h" | `plot_price(symbol='NVDA', resolution='1h')` | 0.78 | 1.00 |
| "plot rolling correlation between nvda and spy for the past month" | `rolling_correlation(symbol='NVDA', benchmark='SPY', window='1mo')` | 0.91 | 1.00 |
| "when during the day does nvda trade the most" | `intraday_pattern(symbol='NVDA')` | 0.53 | 1.00 |
| "what moved today" | `top_movers(window='1d', direction='gainers')` | 0.90 | 0.90 |
| "what tickers do you have" | `list_symbols()` | 1.00 | 1.00 |
| "how did the market do this week" | `market_summary(window='1w')` | 0.96 | 0.99 |
| "candles for tesla with a 20 period moving average" | `plot_price(symbol='TSLA', style='candles', moving_average='20')` | 0.69 | 0.97 |
| "compare nvda amd and msft over the past three months" | `compare_returns(symbols=['NVDA', 'AMD', 'MSFT'], window='3mo')` | 0.94 | 1.00 |
| "how volatile is tsla" | `volatility(symbol='TSLA')` | 0.96 | 1.00 |
| "biggest losers today" | `top_movers(window='1d', direction='losers')` | 0.98 | 0.98 |
| "worst drawdown for nvda this quarter, and chart it please" | `drawdown(symbol='NVDA', window='3mo', plot=True)` | 0.84 | 0.84 |
| "spy stats for the last month" | `summary_stats(symbol='SPY', window='1mo')` | 0.88 | 0.88 |
| "show me apple daily with volume" | `plot_price(symbol='AAPL', resolution='1d', include_volume=True)` | 0.75 | 0.85 |
| "is amd tracking nvidia lately" | `rolling_correlation(symbol='AMD', benchmark='NVDA')` | 0.82 | 0.82 |

Per-argument breakdown for "is amd tracking nvidia lately" (confidence 0.82):

```
  symbol      'AMD'                     p 0.87   AMD 0.87  NVDA 0.13  AAPL 0.00
  benchmark   'NVDA'                    p 0.78   NVDA 0.92  AMD 0.08  AAPL 0.00
  window      omitted, default stands   p 0.96
  resolution  omitted, default stands   p 0.99
  weakest argument: benchmark
```

Accuracy: not reported (no ground-truth scorecard; the text says "Both long commands came
out as asked"). Latency: not reported. Cost: not reported. Token counts: not reported.
`NUM_SAMPLES` / repeats: not reported — each command is run once. Comparison against named
LLMs: not reported; this cookbook runs no LLM baseline.

## Caveats the cookbook itself states

- Question wording carries the load: "Write each question about the idea rather than the
  words a user might pick, because the match is on meaning"; "Avoid naming a question after
  its parameter - `\"Which resolution?\"` gives the command nothing to match against."
- Two arguments drawing from the same list only separate because the spec spells out their
  roles: "*the one being measured, named first*" against "*the second one named, the
  yardstick*".
- Without the `stated` companion question, "the choice would have to name some window, and
  it would have named one confidently" — i.e. an argument that must be picked will be
  picked, plausibly and wrongly.
- Coverage limit by type: only `Literal`, `list[Literal[...]]` and `bool` arguments get
  questions; ints, free text, numbers and dates never do.
- Confidence is a minimum over judgements, not a probability the whole call is right.
- The run is cached and replayed; the numbers are one pass over 14 commands.

## Lessons transferable to other use cases

- Select-not-generate for tool calls: because every argument is a `Choice` over the
  function's own `Literal` values, "whatever reaches the function is a value the function
  accepts" — no JSON repair, no invalid-enum retries. Generalises to any dispatcher whose
  arguments are closed sets.
- Fan-out: one request carries the routing choice plus every function's arguments (54
  questions), and code reads only the chosen branch. Cheap when questions are cheap;
  it does not generalise to functions with open-ended arguments.
- Companion questions read only when relevant: a `stated` Noul per optional argument keeps
  the function's own defaults instead of forcing a guess.
- Confidence as a minimum, not a product: use the weakest judgement for a gate, and surface
  `weakest()` so a human sees which argument to check.
- Schema as the spec source: signatures give the option keys, so nothing maps labels back
  to arguments; the prose spec only adds meaning the type cannot express.
- What does not generalise: free-text, numeric and date arguments stay in code or in a
  separate parser, and this cookbook reports no accuracy, latency or cost measurement.

## Use-case entries this supports

- `uc-agents-harness-function-call-argument-filling` — fill closed-set tool arguments without JSON repair
- `uc-agents-harness-skill-or-tool-selection` — pick which tool a natural-language request should call
- `uc-search-retrieval-query-intent-classification` — turn a search phrase into typed filter values
- `uc-support-intent-routing-handlers` — route a user utterance to one of N handlers with a confidence
- `uc-realtime-voice-command-intent-risk-scaled-thresholds` — map a spoken command onto fixed option lists with risk-scaled thresholds

**Anti-use-case implied:** `au-free-form-value-extraction` — free text, numbers and dates get no
question at all; jev fills closed sets only, so anything with an unbounded value space must
be parsed in code or the function's default must stand.
