---
id: au-image-audio-video-input
title: Do not send jev an image, audio clip, or video
verdict: no
domain: data
decision_shapes: [classification, detection]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  ("Images, audio, and video are not supported (yet)")
  - https://docs.typesafe.ai/models.md  ("Text only. String, JSON object, or array of text values. No image, audio, or video input"; "Pre-process non-text inputs ... into text or structured fields")
related: [au-real-time-from-raw-pixels, au-free-form-value-extraction, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to moderate uploaded images?" Also "classify these scanned invoices with
jev", "have jev detect the sentiment in this support call recording", "check the screenshot for PII".

## Verdict

**No.** This is a hard capability limit, not a quality judgement. The models page states the input
contract: "Text only. String, JSON object, or array of text values. No image, audio, or video input."
The System One concept page repeats it: "Jev currently accepts text input only. It evaluates strings,
JSON objects, and arrays of text. Images, audio, and video are not supported (yet)." A request carrying
binary media has no valid shape.

Not a model failure: **deployment** veto — the input contract is text only.

## What jev would get wrong

Nothing, because the request cannot be made. The realistic mistake is the workaround: base64-encoding an
image into a string field and sending it as text. That does produce a well-formed request and a
well-typed answer, and the answer is meaningless — jev reads the encoding as characters, and the
jaggedness page already warns that "questions about high-level programming languages will perform better
than questions about low level assembly, or binary encoded instructions." A base64 blob is the extreme
case of a binary encoding. It will also consume the 32k state budget almost immediately and cost money to
produce noise.

## What stays in code

The pre-processing pipeline, and the docs say so directly: "Pre-process non-text inputs (images, audio,
video, binaries) into text or structured fields before sending them as `state`." That means OCR for
scanned documents, automatic speech recognition for calls, a vision model for image captioning and object
tags, EXIF and file-metadata extraction, and perceptual hashing for known-bad media. Code owns all of it,
along with the confidence and quality signals those tools emit.

Once text or structured fields exist, jev's ordinary strengths apply to them: a Noul "Does `transcript`
contain a request to cancel the subscription?"; a Score over described levels of caller frustration on
the transcript; a Choice over document types given the OCR text and the detected layout labels. Pass the
upstream tool's own confidence into the state as a named field so jev's judgement can be read alongside
it in code.

## Numbers

Not applicable to the media itself. Once transcribed, a 3,000-token call transcript with ten questions is
roughly 3,600 input tokens, about $0.00015 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md), typically about 100 ms — negligible beside the cost of the ASR or
vision step, which dominates. Budget the pipeline, not the jev call.

- Field evidence (community-report): `fdsimms/todo#2781` concluded "no integration now" — of 15 planned AI features, 5 need images (jev cannot), 7 generate text (jev cannot), and the 2 that fit already had solutions, 2026-09-17. Source: https://github.com/fdsimms/todo/issues/2781

## When the verdict flips

It flips to **good** as soon as a text representation exists and the decision depends only on that
representation. The condition is honest scoping: the OCR or ASR output must actually contain the evidence
the question needs. "Is this invoice from an approved vendor?" survives OCR; "is this signature forged?"
and "does this photo show a weapon?" do not, because the evidence is pixels, and the text layer never had
it. For those, **no rewrite exists** — use a vision model. The docs' "(yet)" is a roadmap note, not a
present capability; re-check the models page before designing around it.

## Alternatives considered

- **Regex / deterministic**: file-type sniffing, size limits, EXIF checks, perceptual hash blocklists.
  Cheap and exact; run them first.
- **Small multimodal LLM**: the correct tool for image and audio understanding; can also produce the text
  layer jev then judges.
- **Frontier multimodal LLM**: for hard visual reasoning.
- **Fine-tuned classifier (CNN / audio model)**: best for high-volume, narrow visual or acoustic
  detection with labelled data.
- **Embeddings (CLIP-class)**: image similarity and near-duplicate detection.
- **Human**: reviews what the pipeline flags.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
