---
id: au-count-items-in-text
title: Do not ask jev how many of something there are
verdict: no
domain: data
decision_shapes: [extraction, classification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (Counting: "does not count reliably"; one-Noul-per-item code sample)
  - https://docs.typesafe.ai/patterns/fan-out.md  (many questions in one call)
related: [au-numeric-thresholds-and-arithmetic, au-interpolate-magnitude-from-score, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to count how many action items are in this meeting transcript?" Also "how
many times does the customer mention cancelling", "how many of these 200 rows are food products", "how
many characters in this string".

## Verdict

**No** as asked; **conditional** after the standard rewrite. The jaggedness page is unambiguous:
"`jev-1.13` does not count reliably. This covers characters in a word, occurrences of a term in a
passage, and items in a long list. The model recognizes the shape of an answer rather than tallying, and
the error grows with the size of the thing being counted." A count is arithmetic, and "Jev is not a
calculator. We strongly recommend implementing any mathematical logic in code."

Closest failure mode: **math and counting** — this entry is that mode; code counts, and jev at
most answers a bounded per-item question whose answers code adds up.

## What jev would get wrong

It will return a plausible-looking number rather than a tallied one, and the error scales with the size
of the collection — so a design that looks fine on ten items degrades silently at two hundred. Because
a Choice or Score is constrained to the levels you supplied, the wrong count still arrives as a
well-typed, confidently-presented integer. The failure is invisible to your schema. Worse, the same page
warns that a count you can obtain another way is wasted spend: "Before asking a counting question, ask
why the count needs a model at all. If the unit is something a regular expression or a parser can find,
the count belongs in code and the model has nothing to add."

## What stays in code

The tally, always. Code splits the collection, code sums, code thresholds. The jaggedness page ships the
exact pattern: iterate over candidates, ask one Noul per candidate, and add up the answers yourself —

```python
result = client.system_one(
    {"items": items},
    {f"item_{i}": Noul(instructions=f"Is `items[{i}]` the name of a fruit?")
     for i in range(len(items))},
)
count = sum(result.nouls[f"item_{i}"].noul > YES for i in range(len(items)))
```

The threshold `YES` is yours and lives in code. Questions are evaluated in parallel against one shared
state, so N per-item Nouls in one request cost tokens and little extra latency (the docs say
latency "barely changes", not that it is free).

## Numbers

Per-item Nouls over a 60-item list of short strings run to roughly 1,200-2,000 input tokens in a single
request, about $0.00005-$0.00008 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), one call, typically about 100 ms. No published benchmark reports
jev's counting accuracy; the docs simply say it is unreliable, which is disqualifying on its own.

- Field evidence (independent-benchmark): RINNECODER/jev-behavior-study, 11,621 requests — counting failures 117/216 across spacing variants, and the letter 'r' in "raven" miscounted 18/18, 2026-09-19. Source: https://github.com/RINNECODER/jev-behavior-study

- Field evidence (community-report): `betmoar/cc-operator-plugin#151` framed its probe with a kill condition and listed jev's counting, date and state-size limits as directly in the way of the intended integration, 2026-09-19. Source: https://github.com/betmoar/cc-operator-plugin/issues/151

## When the verdict flips

It flips to **conditional** when the unit being counted is enumerable in code and the count is the sum of
per-item judgements. Two conditions: the item list must fit the 32k-token state-plus-longest-question
budget, and each per-item question must be a real semantic judgement (is this a complaint, is this a
food) rather than something a regex already answers. If a regex can identify the unit, do not call jev at
all — the docs say the model "has nothing to add". It never flips for counting characters, tokens, or
occurrences of a literal string.

## Alternatives considered

- **Regex / deterministic**: wins whenever the unit is lexically identifiable. First choice.
- **Small LLM**: also unreliable at counting; no advantage.
- **Frontier LLM with a code tool**: correct but slow and expensive for what a loop does.
- **Fine-tuned classifier**: viable as the per-item judge at very high volume; jev needs no training data.
- **Embeddings**: no role.
- **Human**: only for the items where the per-item Noul lands near 0.5.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/patterns/fan-out.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
