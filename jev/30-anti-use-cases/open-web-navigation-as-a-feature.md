---
id: au-open-web-navigation-as-a-feature
title: Do not ship open-web link-path navigation (Wikiracing-style) as a product feature
verdict: weak
domain: search
decision_shapes: [ranking, search, routing]
primitives: [choice, score]
evidence_level: community-report
sources:
  - https://github.com/komikat/jev-bfs  (Wikipedia link-path search by ranking jev over outbound links; no accuracy, path-length or cost numbers published)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (the Wikiracing demo; "each step can mean choosing between hundreds to thousands of links"; two-stage Score-then-Choice and "the occassional slowdown"; "Our speedups here tend to be a lot less than in previous demos… The LLMs look much worse at this task than with reasoning enabled")
  - https://docs.typesafe.ai/primitives/choice.md  (a Choice accepts up to 255 options)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 4, indirection and multi-hop; failure mode 5, large state full of irrelevant detail)
related: [au-multi-hop-and-double-negatives, au-flat-choice-over-255-options, au-open-ended-agent-loop, uc-realtime-game-decision-from-structured-state, uc-search-retrieval-rerank-keyword-shortlist]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to navigate the web by picking links?" Also: "can jev find the path
from one Wikipedia article to another?", "TypeSafe demoed Wikiracing — can we ship that?"

## Verdict

**Weak** as a product feature, and the launch demo is the reason for caution rather than the
reason to build it. Wikiracing is a *demo*: TypeSafe's own post discounts it — "Our speedups here
tend to be a lot less than in previous demos… The LLMs look much worse at this task than with
reasoning enabled" — and the one public implementation, `komikat/jev-bfs`, publishes no success
rate, no path length against optimal and no cost per run. Underneath the demo the task is graph
search, and graph search belongs in code: bidirectional BFS over a link graph is exact and cheap,
and no amount of per-step judgement recovers a wrong turn ten hops back.

**Separate proposal: conditional.** Where the graph is yours, small and already indexed, jev is a
reasonable *heuristic* inside a search your code runs — score the frontier, let the algorithm
expand it, keep a hop budget and a deterministic fallback. That is re-ranking, not navigation.

## What jev would get wrong

**Cardinality.** A Choice accepts at most 255 options and degrades well before that. The launch
post states the problem: "each step can mean choosing between hundreds to thousands of links". Its
own fix is a two-stage Score-then-Choice, which adds a round trip per hop and, in the post's
words, "the occassional slowdown". Ten hops then cost twenty calls.

**Compounding, under a no-recovery policy.** The policy being criticised here is the one the demo
implies: one forward choice per hop, no visited set, no backtracking. Under *that* policy each hop
is an independent judgement and errors compound — *assume* a 90% per-hop hit rate and ten
independent hops and you get about 35% arrival. That is an assumption about the policy, not a
measured navigation success rate; nobody has published one. The fix is architectural and belongs
to code, not to the model: keep the path and the visited set, allow backtracking, and give the
search a budget. What jev sees is whatever state you build for it, so a single-page state with no
history is a design choice; asking a per-hop chooser to recover from a wrong turn it cannot see is
failure mode 4, indirection.

**State.** A rendered page is failure mode 5; a bare anchor list throws away the context that made
a link right; and open-web text is written by strangers, which the jaggedness page says jev does
not treat as hostile by default.

## What stays in code

The graph, the crawl, the visited set, the hop budget, the cycle check, the timeout and the
fallback. For a shortest path, compute it. For a semantic path, code still owns the search
algorithm and jev only scores a frontier code enumerated.

## Numbers

**None published for this task.** `komikat/jev-bfs` reports no success rate, no path length
against optimal, no latency and no cost; the Wikiracing demo publishes no accuracy and annotates
its own speed comparison as run "against the non-reasoning modes of the models". Estimated cost:
at two calls per hop and 2,000-6,000 input tokens each, a ten-hop run is roughly $0.002-$0.005 at
$0.042 per million input tokens with output free — trivial per run, unbounded if the search never
terminates, which is the number nobody has reported.

## When the verdict flips

- To **conditional**, on a bounded graph you own (a docs site, an internal wiki) where code runs
  the search and jev ranks a frontier under 255 items.
- To **no**, if navigation performs side effects — logging in, submitting forms, spending money —
  or runs unattended with no hop budget. That is `au-open-ended-agent-loop`.
- Back toward **good** only once someone publishes a success rate and path-length-against-optimal
  on a labelled set of start/goal pairs, for a *stated* search policy — a code-run search with
  backtracking and a budget is a different measurement from a bare per-hop chooser.

## Alternatives considered

- **Bidirectional BFS over a link dump.** Exact, free, milliseconds; the baseline to beat.
- **Embedding search over page text.** Answers "which page is about X" without walking the graph.
- **A\* with an embedding heuristic.** The conventional form of guided search.
- **Frontier LLM with a browser.** Carries the path in its own context, so it can propose a
  backtrack without the harness supplying one; seconds and cents per hop, and it still needs a
  budget and a visited set in code. Compare bounded searches, not bare choosers.
- **Human.** Wikiracing is a game people play for fun; that is the honest framing of the demo.

## Sources

- https://github.com/komikat/jev-bfs — accessed 2026-09-19
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
