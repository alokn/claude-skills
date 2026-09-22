---
id: uc-verification-citation-supports-claim
title: Check whether a cited section actually supports the claim built on it
verdict: good
domain: verification
decision_shapes: [verification, classification, detection]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (RFC 7519, 8 citations, three-way Choice, AUTO_ACCEPT 0.8, per-citation confidences)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: "Detect ... citation errors, hallucinations"; Scientific discovery: "Check whether cited passages support claims")
  - https://docs.typesafe.ai/confidence.md  (three bands; thresholds scale with stakes)
related: [uc-verification-llm-output-policy-check, uc-verification-extraction-field-verification, uc-search-retrieval-semantic-find-in-document]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check citations?" Also: "our RAG answers cite the right
document but the passage does not say that", "can we catch hallucinated quotes automatically?",
"how do we verify a manuscript's references without reading every source?"

## Verdict

**Good** — the shape is demonstrated by the `citation_check` cookbook's eight hand-built
citations; no task-matched labelled accuracy is published; shadow-evaluate against the
incumbent before acting. The cookbook builds exactly this function and the division of
labour is the reason it works: a string match catches quotes that are not in the source
and needs no model at all; a single three-way Choice reads the surviving quote's
*context* and decides how the section relates to the claim. Two conditions come from the
cookbook itself: the string match "is exact after normalization" so lightly reworded
quotes come back `fabricated`, and the confidence threshold is deliberately set high —
"start high for more human review as you build trust in the model."

## What jev decides

State is the claim and the section the quote came from, nothing else:

```python
state = {"claim": claim, "section": section}
```

One Choice, `relation`, covering "the three ways a section can relate to a claim":

```python
Choice(instructions="How does the section relate to the claim?",
  criteria={
    "supports":     "The section states the claim or directly implies that it is true",
    "contradicts":  "The section states the opposite of the claim or implies it is false",
    "says_nothing": "The section does not address what the claim asserts, either way"})
```

Code folds the string-match status and the Choice into four verdicts — `verified`,
`contradicted`, `unsupported`, `fabricated` — and reads confidence as the gate:

```python
AUTO_ACCEPT = 0.8   # at or above, the verdict stands; below, a human confirms it
```

Note the shape: three options, not a yes/no. Splitting "does not support" into *contradicts*
and *says nothing* is what lets the pipeline treat a reversed claim differently from a merely
unsupported one.

## What stays in code

Fetching the source, stripping headers and footers, splitting it into addressable sections,
normalising whitespace and curly quotes, the exact substring match, the four-verdict fold, the
threshold, and the review queue. The `fabricated` verdict never reaches the model: "A quote
that is not in the source is fabricated, and no model is needed to find that out."

## Numbers

From `citation_check.md`, `jev-1.12` on 2026-08-16. Source: RFC 7519, "58,365 characters, 45
numbered sections, 8 citations" — four accurate, four deliberately broken.

| citation | quote | relation | conf | verdict | action |
|---|---|---|---|---|---|
| epoch_seconds | found | supports | 0.93 | verified | auto |
| aud_reject | found | supports | 0.95 | verified | auto |
| sig_reporting | missing | – | – | fabricated | auto |
| clock_skew | found | supports | 0.99 | verified | auto |
| exp_required | found | contradicts | 0.99 | contradicted | auto |
| pii_encryption | found | says_nothing | 0.27 | unsupported | review |
| iat_future | section-only | says_nothing | 0.56 | unsupported | review |
| duplicate_names | found | supports | 0.99 | verified | auto |

"The four accurate ones came back `verified` at confidence 0.93 or higher. All four planted
failures were caught." `pii_encryption` is the argument for the model stage: "its quote is in
the source word for word, and the section it came from says nothing about the claim." Cost,
latency and token counts are collected in code but **not reported**; eight citations, one run,
no LLM baseline.

Closest jaggedness mode: **4, indirection.** "Is this citation correct?" is multi-hop (is the
quote there, and does the context back the claim). The design splits it — code answers the
first hop, one single-hop question answers the second.

- Field evidence (community-report): a community citation verifier packages the official `citation_check` decomposition as a standalone tool over arbitrary source sets; no numbers published, 2026-09. Source: https://github.com/MarissaFamularo/citation-verifier

## When the verdict flips

- **Quoting is sloppy** — truncated, paraphrased, or reformatted quotes. The exact match marks
  them `fabricated`. "A production system that tolerates sloppy quoting would need fuzzy
  matching instead", which changes the design and softens this to **conditional**.
- **The source is not text** — a scanned PDF, a figure, a table image. Jev is text only.
- **The claim depends on arithmetic in the source** ("the limit is more than double the old
  one"). Mode 2: extract the numbers and compare in code.
- **Support is distributed across sections.** The cookbook reads one section per claim; a claim
  that only follows from three sections together is multi-hop and will read `says_nothing`.
- **Section splitting is unreliable.** "`load_source()` and `split_sections()` are written for
  an RFC's layout, so a document of another shape needs its own parsing." Bad sectioning makes
  the model's answer meaningless.

## Alternatives considered

- **String match alone** — free, exact, and catches fabrication; blind to the accurate quote
  under a wrong claim, which was 2 of the 8 cases here.
- **Embedding similarity between claim and section** — cheap; it scores topical overlap, and a
  contradicting section is maximally on-topic, so it scores high exactly when it should fail.
- **NLI / entailment model (DeBERTa-MNLI class)** — the closest specialist and genuinely strong
  on this three-way task (entail / contradict / neutral); it is the alternative to beat. Jev
  wins on long real-world sections, on criteria you can reword per domain, and on a confidence to gate on whose
  calibration you measure on your data; a fine-tuned NLI model wins on throughput and can be self-hosted.
- **Frontier LLM as a citation judge** — accurate and the incumbent; dollars and seconds per
  citation, and it returns prose to parse.
- **Human fact-checking** — where the sub-0.8 band goes; 2 of 8 here, which is the saving.

## Sources

- https://docs.typesafe.ai/cookbooks/citation_check.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
