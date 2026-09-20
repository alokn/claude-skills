---
id: au-whole-ai-feature-backlog
title: Do not plan an AI feature backlog around jev before screening it for images and generation
verdict: no
domain: product
decision_shapes: [classification, extraction, detection]
primitives: [choice, score, noul]
evidence_level: community-report
sources:
  - https://github.com/fdsimms/todo/issues/2781  ("no integration now"; 5 of 15 features need images, 7 generate, 2 fit and already had solutions)
  - https://docs.typesafe.ai/models.md  ("Text only. String, JSON object, or array of text values. No image, audio, or video input.")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9, generation)
related: [au-image-audio-video-input, au-generate-code-and-patches, au-write-customer-replies, au-tiny-volume-human-reviewed-workflow]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to adopt jev as the AI layer for our product roadmap?" Also "we have fifteen AI
features planned, can jev do them?", "should we standardise on jev instead of an LLM provider?", "what
share of our AI backlog does this cover?".

## Verdict

**No** as a platform decision taken before the screen, because the screen is cheap and usually decisive.
One team published the exercise. `fdsimms/todo#2781` (2026-09-17) walked its 15 planned AI features
against jev's constraints and concluded "no integration now": 5 of the 15 need images, which jev cannot
accept; 7 generate text, which jev cannot produce; and the 2 that did fit already had working solutions.
That is a 2-in-15 hit rate before quality is even discussed, and 0-in-15 net of what was already built.

## What jev would get wrong

Nothing it was asked to do — the mistake is upstream, in treating a decision model as a general AI
capability. The model card is unambiguous about input: "Text only. String, JSON object, or array of text
values. No image, audio, or video input." Jaggedness mode 9 is unambiguous about output: "`jev-1.13` is
not trained to generate text. While you can force it to by chaining choices, this will not work well and
will be very slow." A roadmap written without those two filters produces a procurement conversation, a
spike, and a late discovery, which is exactly the sequence the issue documents.

## What stays in code

The screen itself, run as a triage before any integration work. For each feature ask three questions in
order: does it need a non-text input (image, audio, video, PDF page)? does the user receive generated
prose, code or a summary? is the answer set bounded and known in advance? A "yes" to either of the first
two disqualifies jev for that feature outright; a "no" to the third means the feature needs extraction or
generation, not classification. What survives is the shortlist worth prototyping — and then the usual
question applies to each survivor: is there already a rule, an index, or a working model doing the job,
in which case the gain may be zero, as it was for fdsimms' two eligible features.

## Numbers

15 features assessed, 5 blocked on images, 7 blocked on generation, 2 eligible and already solved; the
two conditions the author set for reconsidering were zero data retention on all tiers (enterprise-only
today) and "a genuine sub-second latency requirement"
(https://github.com/fdsimms/todo/issues/2781, accessed 2026-09-19). Cost of running the screen: an
afternoon. Cost of not running it: the integration spike, plus whatever the roadmap promised. For the
features that do survive, per-call economics are the ones quoted throughout this corpus — $0.042 per
million input tokens with output free, about 100 ms (https://docs.typesafe.ai/models.md).

## When the verdict flips

It flips to **conditional** the moment the screen has been run and a real shortlist exists: adopt jev for
the classification, detection, routing, scoring and verification features on that list, and keep a
generative provider for the rest. Most products need both, and the useful framing is a decision layer
alongside a generation layer, not a replacement for one. It also flips per feature when a multimodal step
is added in front — OCR or ASR turning the image or audio into text — at which point jev judges the
transcript, and the pipeline cost is dominated by that first step.

## Alternatives considered

- **Regex / deterministic**: already covers more of a typical backlog than either AI layer.
- **Small LLM**: handles the short generative features the roadmap needs and jev cannot.
- **Frontier LLM**: the default for generation and multimodal input; expensive per call.
- **Fine-tuned classifier**: for the one or two high-volume classification features that justify labels.
- **Embeddings**: for the search and dedup features that are really retrieval.
- **Human**: still the right answer for low-volume, high-stakes features.

## Sources

- https://github.com/fdsimms/todo/issues/2781 — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
