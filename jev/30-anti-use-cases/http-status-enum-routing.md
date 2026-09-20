---
id: au-http-status-enum-routing
title: Do not use jev to route on an HTTP status code or any other enum
verdict: no
domain: sdlc
decision_shapes: [routing, classification]
primitives: [choice]
evidence_level: independent-benchmark
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Asking the model something code can compute exactly")
  - https://empryo.com/blog/jev-and-the-harness  (deterministic code wins where the signal is already captured)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Use code when you can")
related: [au-exact-lookup-and-id-matching, au-archive-after-n-days-rule, au-grep-line-ranking]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide how to handle a 429 versus a 503?" Also "classify the webhook by
its `event.type` field", "route the job by its enum status with jev", "let jev decide retry-or-fail from
the response code".

## Verdict

**No.** A status code is already a label, produced by a system that knows the truth. Mapping one enum
value to one branch is a `switch` statement, and the jaggedness page's closing reminder tells you not to
ask "the model something code can compute exactly". Empryo's independent evaluation states the general
rule from measurement: "When an exact index, graph traversal, or deterministic heuristic already captures
the signal, deterministic code remains faster, cheaper, and more reliable."

Closest failure mode: **math and counting** — mapping an enum value to a branch is a
computation code already performs exactly.

## What jev would get wrong

Nothing subtle — that is the problem. Jev will usually map `429` to `rate_limited` and `503` to
`service_unavailable`, so the design appears to work in testing and hides a regression risk: the mapping
is now probabilistic, versioned outside your repository, and capable of changing when the model alias
moves. A Choice is relative and always returns an option, so a status code you never enumerated gets
silently absorbed into the nearest neighbour rather than raising. And the confidence value gives you
nothing, because a deterministic mapping has no uncertainty to report. You have added 100 ms, a network
dependency, a rate limit, and a bill to a lookup table.

## What stays in code

The mapping, in full, in the repository, under test. `switch (status) { case 429: ... }`, a dict, or a
match expression. This is also where retry policy, backoff, and circuit-breaking belong — none of them
are judgements.

Jev has a role one level up, on the part of the response that is *not* an enum: the free-text error body.
A Noul "Does `response.body` indicate the failure is caused by our request rather than by the provider?";
a Choice over `quota`, `auth`, `validation`, `provider_outage`, `unknown` given the message text; a Noul
"Does `response.body` name a field we sent?". Code reads the status first and only calls jev when the
status is ambiguous (a 400 or 500 with a prose explanation) and the branch genuinely depends on what the
prose says.

## Numbers

A `switch` is free and exactly right. A jev call over an error body with four questions is roughly
600-1,200 input tokens, about $0.00003-$0.00005 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), typically about 100 ms — but that 100 ms sits in your retry path,
where it is pure added latency for every failed request. In the closest measured analogue, Empryo found
jev behind a keyword-frequency heuristic on next-tool prediction, 15% against 26%
(https://empryo.com/blog/jev-and-the-harness).

- Field evidence (community-report): Empryo failure triage, 102-item set — jev 102/102 at 70-300 ms (median 260-273) and $0.00002 per decision, but the regex baseline scored 98/102 only because `429` matched inside `text_editor_20250429`; digit-bounding the status code took the free deterministic classifier to 102/102 at zero cost, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness

## When the verdict flips

The enum branch never flips — **no rewrite exists**, because the deterministic version is already
correct, free, and instant. What flips to **good** is the free-text triage above: code handles every
status it recognises, and jev classifies only the prose body of the responses whose handling is genuinely
ambiguous. A second case that flips: grouping thousands of distinct error *messages* (not codes) into
themes for an operations dashboard, where the text varies and no enum exists.

## Alternatives considered

- **Regex / deterministic**: wins. A `switch` on an integer is the correct implementation.
- **Small LLM**: slower and less reliable than a `switch`, with no upside.
- **Frontier LLM**: same, at higher cost.
- **Fine-tuned classifier**: no role; the mapping is defined, not learned.
- **Embeddings**: useful for clustering free-text error messages, which is the adjacent task.
- **Human**: reviews the `unknown` bucket and extends the `switch`.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
