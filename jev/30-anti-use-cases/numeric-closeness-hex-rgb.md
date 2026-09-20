---
id: au-numeric-closeness-hex-rgb
title: Do not use jev to judge whether two hex or RGB values are close
verdict: no
domain: design
decision_shapes: [classification, verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (Numeric representations, verbatim)
related: [au-numeric-thresholds-and-arithmetic, au-count-items-in-text, au-image-audio-video-input]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether the brand colour in this design token matches the
approved palette?" Also "are #E03A3A and #DC2626 the same red", "flag components whose background drifts
from the spec", "does this RGB triple read as a warning colour".

## Verdict

**No** for the numeric comparison, **good** for the semantic one — and the jaggedness page draws that
line itself. Under Numeric representations: "`jev-1.13` will perform better on semantic representations
than numeric. For example, questions about colors using hex values will underperform compared to those
using the English names. Given RGB triples or hex values it cannot reliably judge whether two values are
near each other." Perceptual distance between two colours is a computation, not a judgement.

Closest failure mode: **math and counting** — perceptual distance between two colour values is
a computation; the semantic question ("is this off-brand?") is the one left for jev.

## What jev would get wrong

Hex and RGB are numeric encodings, and jev reads them as strings. It will treat `#DC2626` and `#DD2626`
as more similar than `#DC2626` and `#D42B2B` because they differ in fewer characters, which is the wrong
metric entirely — perceptual closeness runs through a colour space, not through string edit distance.
The same failure generalises beyond colour: the page notes that "questions about high-level programming
languages will perform better than questions about low level assembly, or binary encoded instructions."
Any numeric encoding — hex, binary, base64, opcode, IP address, version integer — is the same trap.

## What stays in code

The distance. Convert both values to a perceptually uniform space (CIELAB) and compute ΔE, or compute
whatever metric your design system already agreed on. Code owns the threshold, code owns the pass/fail,
and code turns the number into a named bucket before it goes anywhere near the model.

Jev's role is the part that is genuinely a judgement, and the docs name it: "Keep the model for the part
that is genuinely a judgment, such as whether a color reads as a warning." Pass English names and
computed buckets, not hex — for example a Noul "Does a `deep crimson` background read as an error state
in a banner?", or a Choice over `error`, `warning`, `success`, `neutral` given the colour name and the
component's label text. The jaggedness page's instruction is explicit: "do the conversion in code and pass
in either the computed number or a named bucket."

## Numbers

A ΔE computation costs nothing and is exact. A semantic call over a colour name plus component context
with three questions is a few hundred input tokens, well under $0.00002 at $0.042 per million input
tokens with output free (https://docs.typesafe.ai/models.md), typically about 100 ms. There is no
published benchmark of jev on colour-distance judgements; the docs state the limitation directly.

## When the verdict flips

The closeness question never flips — **no rewrite exists**, because a colour-space library already
answers it exactly and no amount of prompting turns a string comparison into a metric. The surrounding
review flips to **good** when code does the conversion first: compute ΔE in code, bucket it
(`identical`, `within_tolerance`, `visibly_different`), convert the hex to the nearest named colour, and
ask jev only about meaning — whether the colour is appropriate for the component's role, whether the
label and the colour contradict each other, whether the pairing is likely to read as an error.

## Alternatives considered

- **Regex / deterministic**: a colour library (`colour-science`, `culori`, `chroma.js`) wins outright.
  This is the alternative.
- **Small LLM**: same numeric weakness, no benefit.
- **Frontier LLM with a code tool**: correct but absurdly indirect for a ΔE call.
- **Fine-tuned classifier**: no role; the relation is exact.
- **Embeddings**: no role.
- **Human**: a designer settles whether the tolerance itself is right; code enforces it thereafter.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
