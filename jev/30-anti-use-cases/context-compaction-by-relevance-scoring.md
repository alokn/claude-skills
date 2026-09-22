---
id: au-context-compaction-by-relevance-scoring
title: Do not compact an agent's context by scoring each item's relevance with jev
verdict: weak
domain: agents-harness
decision_shapes: [detection, scoring, retrieval]
primitives: [noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Harness Engineering: "semantic context retrieval"; "Select useful context for downstream AI workflows")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5: filter in code first; a Noul can filter for relevance; mode 9: generation is not a jev task)
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (progressive disclosure; leave the cheap index alone so prefix caching holds)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (batching N questions over one state)
  - https://x.com/theo/status/2100762304862384257  (five shipped compaction implementations, no retention or quality numbers; "This is a terrible compaction strategy")
related: [uc-search-retrieval-context-selection-for-downstream-ai, uc-agents-harness-agent-trace-classification, uc-agents-harness-skill-or-tool-selection, au-whole-document-in-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide what to keep when we compact an agent's context?"
Also: "our summariser throws away the one constraint that mattered", "can jev mark which tool
results are still live?", "which turns can we drop before the window fills?"

**This entry is `inferred`.** The use-case map names semantic context retrieval under harness
engineering, and the jaggedness page endorses a relevance Noul as a filter, but no cookbook
compacts an agent transcript.

## Verdict

**Weak**, and the reason is an absence rather than a defect. At least five independent
tool-history pruning and compaction implementations shipped within days of launch and
**not one of them publishes a retention figure or an answer-quality measurement** —
nothing on how often a still-binding constraint was dropped, nothing on task success
after compaction against the recency-window baseline. The strategy is also publicly
contested: "This is a terrible compaction strategy"
(x.com/theo/status/2100762304862384257). A selector nobody has measured, replacing a
baseline that is free and predictable, is not something to ship on mechanism alone;
keeping the last N turns plus the system prompt is the honest comparator and it costs
nothing.

**Separate proposal: conditional, if you measure it.** If you do build it, jev must
select rather than summarise — compaction has two halves, *what to keep verbatim* (a
selection problem) and *what to compress into prose* (generation, failure mode 9, which
jev cannot do at all) — and a deterministic keep-list must hold the system prompt, the
original task, the current plan, the last N turns and any tool result the agent is
mid-way through using. Then measure task success after compaction against the recency
window, and only keep the selector if it wins.

## What jev would get wrong

The failure is silent. A dropped item does not raise an error; it changes an answer several turns
later, and nobody attributes the change to the compaction. That is exactly the failure none of the
five shipped implementations measured. The decomposition below is the most defensible version of
the design, and it is still unmeasured.

State is the live task plus one candidate item — a turn, a tool result, a file excerpt — so the
judgement is about the pair, not about the item in isolation:

```json
{"current_task": "Migrate the billing service off the v1 auth client",
 "item": {"index": 37, "kind": "tool_result", "tool": "grep",
          "excerpt": "...", "chars": 2140}}
```

Three Nouls and one Score in one request per item:

```python
"still_binding": Noul("Does this item state a constraint, decision, or fact that the remaining work must still respect?",
  true="Dropping it would let a later step violate something already settled.",
  false="It is background, or the task no longer depends on it.")
# "superseded" is deliberately absent: the state above holds the task and one item, so the
# model cannot see the later items the question asks about. Either put the candidate's
# successors in the state (the later items that mention the same file, key or decision,
# selected in code) and ask about those explicitly, or leave supersession to code, which has
# the whole transcript and can compare by index.
"reproducible": Noul("Could this item's content be recovered cheaply by running a tool again?",
  true="The same command or lookup would return it.",
  false="It came from the user, from a one-off observation, or from a source no longer available.")
"detail_needed": Score("How much of this item must survive?",
  criteria=["Nothing — it can be dropped", "Its existence only, as one line",
            "Its conclusion, without the body", "Verbatim — the exact text matters"])
```

Code keeps verbatim at level 3, records a one-line reference at levels 1-2, drops level 0, and
never drops anything on the keep-list regardless of the answers.

## What stays in code

Token accounting and the budget, the keep-list, ordering, deduplication, the summary itself
(an LLM or a template), and the rule that a dropped item is *referenced* rather than erased so
the agent can re-fetch it. Follow the skill-suggestion cookbook's discipline: leave the stable
prefix untouched so prefix caching still holds, and spend the tokens on the tail.

## Numbers

Cost is one call per candidate item: a 500-token excerpt plus four questions is roughly 700
input tokens, about $0.00003 at $0.042 per million input tokens with free output. A 200-item
transcript is therefore about $0.006 per compaction — negligible against the frontier tokens
saved, which is the entire argument. Latency 70-500 ms per item; run them concurrently, and
compact off the critical path where possible.

No published measurement exists for compaction quality with jev. The transferable evidence is
indirect: the RAG-passage cookbook shows per-pair relevance Nouls separating items whose
embedding scores sat inside a 0.584-0.455 band, and the parallel-questions cookbook shows N
questions over one state costing one call. Measure what matters — task success after
compaction — not the selector's agreement with your intuition.

Closest jaggedness modes: **5**, which compaction exists to fight, and **9**, which is why jev
selects and does not write the summary.

- Field evidence (community-report): at least five independent tool-history pruning and compaction implementations shipped within days of launch, none publishing retention or answer-quality numbers; the strategy itself is publicly contested - "This is a terrible compaction strategy", 2026-09. Source: https://x.com/theo/status/2100762304862384257
- Field evidence (community-report): one of those projects also uses jev to decide how much conversation history to keep, not just which tool results to drop; no retention or quality numbers published, 2026-09. Source: https://github.com/compozy/yoshi

## When the verdict flips

- To **conditional**, once you have measured it: publish (or at least record internally) the
  retention rate for still-binding items and task success after compaction against a recency
  window on the same transcripts. A selector that beats the window on your own traffic is worth
  keeping; until then the window is the better default.
- **Recency is good enough** in most harnesses. Keeping the last N turns plus the system prompt is
  free and predictable, and it is the baseline any selector has to beat.
- **You use jev to write the summary.** That is **no**. Generation is mode 9.
- **The decision is arithmetic** ("drop until we are under 100k tokens"). Code counts; jev only
  ranks what is droppable.
- **Dropping is irreversible.** If the agent cannot re-fetch a dropped item, a false drop is a
  silent failure. Keep references, or keep the item.
- **Compaction is on the critical path of an interactive turn** and the transcript is long:
  hundreds of sequential calls will be felt. Batch, cache per item, and only re-judge new items.

## Alternatives considered

- **Recency window / sliding buffer** — free, predictable, and the honest baseline; it drops the
  early constraint that mattered, which is the failure this addresses.
- **LLM summarisation of the middle** — the standard approach and the one that loses exact
  values and constraints. The testable hypothesis is that pairing it with jev-selected verbatim
  keeps beats either alone on task success after compaction; nobody has measured it, so treat it
  as a hypothesis to run, not a result.
- **Embedding similarity to the current task** — cheap and indexable; it ranks topical overlap
  rather than "still binding", which is the decision that matters. Supersession is code's job in
  either design.
- **Structured scratchpad / external memory the agent writes to** — architecturally the best
  answer where you control the agent: make the constraints explicit instead of recovering them.
  Prefer it; use jev where you are compacting someone else's transcript.
- **Larger context window** — solves it with money until it does not; context rot is a real
  accuracy cost, which is the jaggedness page's own point.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
