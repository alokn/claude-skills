---
id: uc-data-ml-transcript-coding-codebook
title: Code interview transcripts and open-ended survey responses against a predefined codebook
verdict: good
domain: data-ml
decision_shapes: [classification, detection, scoring]
primitives: [noul, choice, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Scientific discovery: "Label passages in interview transcripts, open-ended survey responses, and field notes using predefined themes or categories")
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (per-question stdev ~0.01 vs LLMs drifting at temperature 0; explicit uncertain outcome for human review)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (N questions over one state in one call; measured run-to-run std devs)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (confidence band with a coarser fallback)
related: [uc-data-ml-map-reduce-corpus-labelling, uc-data-ml-systematic-review-screening, uc-data-ml-text-features-for-tabular-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for qualitative coding?" Also: "we have 900 interview transcripts
and two coders", "can jev apply our thematic codebook to open-ended survey answers?", "how do we
report inter-rater reliability if one of the raters is a model?"

## Verdict

**Good.** The use-case map names it directly — "Label passages in interview transcripts,
open-ended survey responses, and field notes using predefined themes or categories" — and the
shape is a clean fit: a codebook is a fixed set of labels with written definitions, which is
exactly a criteria dict. No cookbook measures qualitative coding, so treat published
consistency as the transferable property and agreement with your human coders as the thing you
must measure. One methodological condition: report jev as a coder with a measured agreement
statistic, not as ground truth.

## What jev decides

Unit of analysis first — code segments the transcript into utterances, turns or paragraphs, and
each segment is one call. State is the segment plus the minimum context needed to interpret it:

```json
{"question_asked": "What made you stop using the service?",
 "response": "...", "speaker": "P07"}
```

Multi-label coding means **one Noul per code**, never a Choice — a Choice is relative and always
elects a winner, while "each Noul is absolute and can be low for all of them". Paste the
codebook's own definition into the criteria, unchanged:

```python
"code::cost_concern": Noul(
  instructions="Does this response express that the price or ongoing cost was a reason for the participant's decision?",
  criteria=NoulCriteria(
    true="The participant names cost, price, budget, or value for money as a factor in the decision.",
    false="Cost is mentioned only as background, or not mentioned at all."))
```

Where the codebook is genuinely mutually exclusive (one primary theme per segment), use a Choice
with an explicit `none_of_these` option and read `confidence`, with the coarser-level fallback
from the SIC recipe if your codebook has parent themes.

Add one intensity Score only where the codebook already defines degrees; do not invent a 1-10
scale — Score levels must describe concrete situations, and 2 to 10 levels is the limit.

## What stays in code

Segmentation, speaker attribution, de-identification, the codebook and its version, the
thresholds per code, all counts and co-occurrence statistics, and the agreement calculation. The
double-coded sample, the disagreement queue and the codebook revision cycle stay human.

## Numbers

Cost: a 300-word segment with 25 code Nouls is roughly 800 input tokens, about $0.00003 per
segment at $0.042 per million input tokens with output free — roughly $3 for 100,000 segments.
All 25 codes ride one call: the parallel-questions cookbook measured 13 questions over one
document as "12.2x cheaper, 10.0x faster" in one call than sequentially, with identical answers.

The property that matters most for coding is stability, and it is published: the consistency
cookbooks report jev's per-question standard deviation at about 0.01, and the noul cookbook's
run found LLM probabilities moving between repeats even at temperature 0 — though the choices
cookbook's run went the other way, with `claude-haiku-4-5` at temperature 0 the more repeatable
condition (100.0% against jev's 90.8% raw, mean probability SD 0.0012 against 0.0098). Scope the
claim to the configuration you test. Both cookbooks build an explicit "uncertain" outcome for
human review. In the
parallel-questions run, eleven of thirteen questions returned identical means with "std dev
exactly 0.0" across 5 runs. A human coder does not have that property, which changes how you
interpret agreement.

No accuracy or kappa figure is published for qualitative coding. Double-code a stratified sample
(the standard practice anyway), report Cohen's or Krippendorff's alpha between jev and each human
coder, and only then decide which codes jev may apply alone.

Closest jaggedness mode: **1, literal reading.** Codebook definitions written for humans rely on
tacit understanding; jev "answers the question you wrote, not the one you meant". The
disagreements in your double-coded sample are the missing half of each definition — put them in
the criteria.

## When the verdict flips

- **The codebook is emergent** (grounded theory, open coding). Jev applies codes; it does not
  discover them. Use it for the closed-coding phase only.
- **Codes depend on context beyond the segment** — something said forty turns earlier. Mode 4 and
  mode 5: either widen the state deliberately or accept the miss.
- **The corpus is not English.** English is strongest; other languages are accepted with lower
  accuracy. Measure per language.
- **Transcripts are audio only.** Text input only; transcribe first, and the transcription error
  becomes part of your error.
- **Publication requires human coders by methodological convention.** Then jev is a first pass
  and a disagreement filter, not a coder — which is still most of the saving.
- **Segments contain identifiable data.** Cloud only (US West); de-identify before sending, and
  note that zero data retention is an enterprise term.

## Alternatives considered

- **Manual coding by two coders** — the standard and the cost being addressed; irreplaceable for
  codebook development and for the reliability sample.
- **Dictionary methods (LIWC, keyword lists)** — fast, transparent, reproducible, and the honest
  baseline for simple codes; blind to paraphrase and to implied meaning.
- **Topic models (LDA, BERTopic)** — discover themes rather than apply yours; good upstream of a
  codebook, not a substitute.
- **Fine-tuned classifier per code** — best once you have a few hundred coded segments per code,
  which is exactly what you rarely have at the start.
- **Frontier LLM coding** — accurate and expressive; in the noul cookbook's run the LLM
  conditions moved between repeats at temperature 0, which matters when the deliverable is a
  reliability statistic. Measure it on your codebook rather than assuming it; also dollars per
  hundred transcripts.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/classification_using_confidence.md — accessed 2026-09-19
