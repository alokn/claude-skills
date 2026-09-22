---
id: au-real-time-from-raw-pixels
title: Do not build a real-time control loop that reads raw pixels with jev
verdict: no
domain: agents
decision_shapes: [classification, routing]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/models.md  ("No image, audio, or video input")
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (Doom demo uses "structured state as a data structure with text, not on images (yet…)")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Most queries complete in about 100 ms")
related: [au-image-audio-video-input, au-open-ended-agent-loop, au-expect-headline-speed-cost-multipliers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to drive a game agent / a robot / a UI automation loop from the screen?"
Also "the launch demo played Doom, so can jev read our video feed at 10 Hz", "use jev for real-time
visual QA of a production line".

## Verdict

**No** from raw pixels. The demo people remember is real, and the launch post says exactly what it ran
on: the Doom demo uses "structured state as a data structure with text, not on images (yet…)". The
perception layer was a game engine emitting structured facts, not a frame buffer. Combined with the
models page — "No image, audio, or video input" — the loop is only possible when something upstream has
already turned pixels into text or fields.

Not a model failure: **deployment** veto — text-only input; something upstream has to turn
pixels into fields before jev sees anything.

## What jev would get wrong

The request cannot carry a frame, so the failure is architectural: teams see the frame rate in the demo
and budget for jev as the perception system, then discover they still need a vision model in the loop.
That model, not jev, sets the latency and the cost floor. Encoding frames as base64 text is not a
workaround — it is a binary encoding, which the jaggedness page lists among the representations jev
handles worst, and a single frame would consume most of the 32k state-plus-question budget.

## What stays in code

Perception and control. A vision model, an object detector, or the application's own event stream
converts the world into a compact structured state — entity list, positions as named buckets, health as
a number, visible affordances as strings. Code owns the loop, the tick rate, the safety interlocks, and
the fallback when a call is slow or fails. Nothing in a physical or safety-relevant loop should wait on a
network call without a deterministic default.

Jev's role is the decision on top of that structured state: a Choice over the small set of available
actions with described criteria; a Noul "Does `state.threats` include something within the danger
distance bucket?"; a Score over described levels of urgency. This is genuinely well suited to jev —
typical latency about 100 ms and a schema that cannot be violated — provided each query "carries compact
structured state, not raw logs" and not raw frames.

## Numbers

A compact structured state of 300-600 tokens with six action questions runs roughly 700-1,000 input
tokens per tick, about $0.00003-$0.00004 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md). At 10 queries per second that is on the order of $1 per hour in
jev tokens before the vision model, which typically dominates both cost and latency. Rate limits of
250,000 tokens per second and 1,200 requests per minute apply and bind first at high tick rates.

- Field evidence (community-report): jev-plays-pokemon-red (valentynkit) — ~1.3 decisions/sec, median 621 ms (mean 759, n=6, range 479-1470), ~$0.14/hour at ~725 input tokens per call, with calibration deliberately unpublished ("n=5 turns with wide confidence intervals") because rate limiting cut the study short. Source: https://github.com/valentynkit/jev-plays-pokemon-red

## When the verdict flips

It flips to **good** when a perception layer already exists and emits text or structured fields, the tick
rate fits within 1,200 requests per minute, the state per tick is compact, and code holds a deterministic
fallback action for a slow or failed call. It stays **no** whenever the frame itself is the input —
**no rewrite exists** for pixel input on a text-only model — and whenever the control loop is
safety-critical, where a network dependency in the inner loop is the wrong architecture regardless of
which model sits behind it.

## Alternatives considered

- **Regex / deterministic**: the control law, the interlocks, and the fallback. Non-negotiable.
- **Small multimodal LLM**: can do perception, but seconds of latency break a real-time loop.
- **Frontier multimodal LLM**: far too slow for a control loop; fine for offline analysis.
- **Fine-tuned classifier (CNN / detector)**: the correct perception layer — milliseconds, on-device,
  no network.
- **Embeddings**: frame similarity for change detection, cheaply.
- **Human**: supervises; cannot be in a 10 Hz loop.

## Sources

- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://typesafe.ai/blog/introducing-system-one-models-and-jev — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
