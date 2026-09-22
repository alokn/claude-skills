---
id: uc-realtime-ui-component-selection
title: Select which UI component or template renders a piece of content, inline in the render path
verdict: good
domain: realtime
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Real-time applications: "Fast and smart enough to be programmed to play games or embedded into a UI")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Most queries complete in about 100 ms. System One is fast enough for real-time request paths and user interfaces."; code owns control flow)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify first, then route to the handler; confidence floor to a fallback)
  - https://docs.typesafe.ai/cookbooks/function_calling.md  (natural-language request to a name from a closed set, with confidence)
  - https://docs.typesafe.ai/models.md  ($0.042 per Mtok, output free; 255-option cap; text only)
  - https://github.com/genfeedai/genfeed.ai/issues/4863  (public deployment budget: "Provider p95 added latency ≤ 600 ms on the agent turn path, with a hard timeout of 800 ms"; null provider falls back to today's deterministic path)
related: [uc-realtime-game-decision-from-structured-state, uc-realtime-voice-command-intent-risk-scaled-thresholds, df-fit-test, df-cost-model, df-rollout, cb-function_calling, cb-skill_suggestion]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to pick which component renders this?" Also asked as "can jev
choose the right template for a CMS block?", "should the assistant decide whether to show a
table, a chart or a card?", and "can we replace the `if (content.type === …)` ladder that
picks the layout?".

## Verdict

**Good**, and **inferred** — TypeSafe publishes no worked example of component selection,
so the mechanism is clear but the evidence is the general real-time claim plus adjacent
cookbooks, not a measured case. It fits because the answer space is a registry of component
ids you already maintain, the judgement is a single semantic read of the content, and the
docs state the model is "fast enough for real-time request paths and user interfaces". The
one thing that makes it good rather than strong: rendering is user-visible and synchronous,
so the design is only finished once it has a hard timeout and a deterministic fallback
component. The closest jaggedness failure mode is #5, large state full of irrelevant
detail — send an excerpt and the registry, never the whole page model.

## What jev decides

State: a bounded excerpt of the content plus the render context. Not the full document, not
the user's session object.

```
{"content": {"excerpt": "<first 600 chars>", "field_names": ["quarter", "region", "revenue"],
             "row_count": 14},
 "surface": "assistant_reply", "viewport": "narrow"}
```

```
component: Choice
  instructions: {question: "Which component should render `content`?",
                 focus: "Choose by what the content is, not by how long it is."}
  criteria:
    data_table:   {what: "Tabular records the reader will scan or compare row by row",
                   not_for: "Two or three figures quoted in a sentence",
                   examples: ["14 rows of revenue by region and quarter"]}
    line_chart:   {what: "A quantity measured repeatedly over an ordered period",
                   not_for: "Unordered categories, or a single point in time",
                   examples: ["monthly active users, Jan to Dec"]}
    stat_tiles:   {what: "Between one and four headline figures with labels",
                   not_for: "Anything with more than four figures"}
    code_block:   {what: "Source code, a config file, or a shell transcript",
                   not_for: "Prose that merely mentions a function name"}
    callout:      {what: "A short warning, caveat or note addressed to the reader"}
    prose:        {what: "Ordinary running text", examples: ["an explanatory paragraph"]}
    other:        {what: "Content none of the above describes"}

content_is_truncated: Noul
  instructions: {question: "Does `content.excerpt` end mid-structure, such as mid-table or mid-code-block?",
                 focus: "Judge only the end of the excerpt."}
  criteria: {true:  {what: "The excerpt stops inside a structure that clearly continues"},
             false: {what: "The excerpt ends at a natural boundary"}}
```

`other` is mandatory: a Choice is relative and will always name something, so without it a
photo gallery renders as a `data_table` at high confidence. Bands: `confidence >= 0.8`
render the chosen component; `0.55–0.8` render it but keep the "view as…" switcher expanded;
`< 0.55` render `prose`, the deterministic default. `content_is_truncated` at `> 0.6`
suppresses the table and chart options in code regardless of the Choice.

## What stays in code

The registry of component ids (jev picks from what code passed, so it cannot name a
component that does not exist), the render itself, the hard timeout and the fallback,
viewport and accessibility rules, any explicit author override (a `type:` front-matter field
or a user's pinned preference wins outright and skips the call entirely), and every
structural test a parser can answer — "is this valid CSV", "does this parse as JSON", "how
many rows are there". Those are lexical; do not spend a call on them.

## Numbers

Method: `input_tokens ≈ chars(state + questions) / 4`; `cost = tokens × $0.042 / 1e6`,
output free. A 600-character excerpt plus the registry criteria above (~1,700 characters)
plus the Noul (~250) is ≈ 640 tokens ≈ **$0.000027 per render decision**. Volume is your
render rate; do not multiply until you have counted it. Latency: 70–500 ms, "most queries
about 100 ms"; the corpus cost model budgets 300–600 ms end to end for inline UI, and the
public genfeed.ai epic sets exactly that shape for its own deployment — "Provider p95 added
latency ≤ 600 ms on the agent turn path, with a hard timeout of 800 ms" — with the
deterministic path used whenever the provider times out, errors, or is unconfigured. Cache
aggressively: the same content excerpt yields the same decision, so a content-hash cache
removes the call on re-renders entirely. No accuracy figure exists for this task; measure
agreement against the component your authors actually chose.

## When the verdict flips

- **The content already carries its type.** A `type: chart` field, a MIME type, a fenced
  code language — that is lexical and deterministic code wins. Flips to no.
- **Server-side rendering with no fallback path.** If a timeout means a blank page rather
  than a plain-prose render, the design is not finished; flips to no until it is.
- **More than 255 components**, or a deep component taxonomy — the Choice cap binds and you
  need hierarchical classification, which changes the shape.
- **Streaming renders** where the component must be chosen before the content exists. Jev
  reads what is there; it cannot judge what has not arrived.
- **Mostly non-English content**, without your own evaluation.

## Alternatives considered

- **Deterministic rules on the content shape.** Free, exact, and correct whenever a parser
  can tell — keep them, run them first, and call jev only on the residue.
- **Small LLM.** Seconds and a parse failure in the render path; the consistency cookbooks'
  Haiku conditions ran 992–3,860 ms per rubric call. Too slow for inline.
- **Frontier LLM.** Same problem, more expensive.
- **Fine-tuned classifier.** Worth it if the registry is frozen and you have thousands of
  labelled renders; jev wins while components are still being added, because a new option is
  an edited string rather than a retrain.
- **Embeddings + nearest centroid.** Needs threshold tuning and degrades on short excerpts.
- **Human.** The author, via an explicit override — which stays authoritative above jev.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (real-time / embedded in a UI),
`concepts/how-to-build-with-system-one.md` ("about 100 ms", "fast enough for real-time
request paths and user interfaces"), `patterns/intent-routing.md`,
`cookbooks/function_calling.md`, `models.md` (price, 255-option cap, text only),
`github.com/genfeedai/genfeed.ai/issues/4863` (600 ms p95 budget, 800 ms hard timeout,
deterministic fallback — a public engineering plan, not a measured result).
