---
id: au-non-english-at-scale-unevaluated
title: Do not roll jev out on non-English content without evaluating it first
verdict: weak
domain: support
decision_shapes: [classification, routing, detection]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/models.md  ("English is the primary training language ... Other languages, including CJK scripts, are handled but not equally well; test on your own content")
  - https://docs.typesafe.ai/confidence.md  (thresholds must be tuned on your own data)
  - https://github.com/zhuyansen/jev-search-rerank-eval  (164 Chinese / English / mixed queries evaluated)
related: [au-rewrite-and-translate-text, au-replace-vector-retrieval-with-jev-rerank, au-expect-headline-speed-cost-multipliers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to switch our whole multilingual support queue to jev?" Also "we validated on English
tickets, can we turn it on for Japanese", "route our German, Spanish and Thai traffic through the same
questions".

## Verdict

**Weak** until you have measured it, and the docs make the measurement a precondition rather than a
nicety. The models page: "English is the primary training language and where accuracy is currently best.
Other languages, including CJK scripts, are handled but not equally well; test on your own content before
relying on Jev for a non-English workload, and pay close attention to Confidence when routing." An
English pilot's numbers do not transfer, and confidence thresholds tuned on English do not transfer
either.

Not a model failure: **governance** veto — an unmeasured deployment on a distribution the
vendor itself calls weaker; measure per language before rollout.

## What jev would get wrong

Two coupled problems. The first is accuracy: lower on non-English content, by an amount TypeSafe does not
publish, so you cannot estimate it — you have to measure it. The second is the thresholds, and it is the
more dangerous one. A confidence cut-off tuned so that 80% of English tickets clear the high band will
route a different — and unknown — share of Japanese tickets automatically. If the distribution shifts
without the threshold shifting, automation rate and error rate both move silently. Criteria written in
English for concepts that do not map cleanly across languages (politeness registers, indirect refusal,
honorifics) add a third failure: the question means something slightly different in each locale.

## What stays in code

Language detection, first, in code — it is cheap, deterministic, and it lets you apply per-language
thresholds. Code keeps a per-language routing table, a per-language high/medium/low confidence band, and
a per-language kill switch. Code also keeps the incumbent path alive during the evaluation so you can
compare on live traffic.

The evaluation itself is the work: assemble a labelled sample per language from your own historical
decisions, run jev in shadow mode, and plot confidence against accuracy separately for each language —
the how-to-build guide's instruction is to "test thresholds by plotting confidence against accuracy on
your data". Ship one language at a time.

## Numbers

TypeSafe publishes no per-language accuracy figures; the models page states the degradation
qualitatively. One independent evaluation ran "164 real Chinese / English / mixed queries" over a
33,047-entry catalogue and found jev useful only in fusion with an embedding ranker
(https://github.com/zhuyansen/jev-search-rerank-eval, accessed 2026-09-19) — evidence that mixed-language
work is feasible, not that it is free. Cost is unchanged by language at $0.042 per million input tokens
with output free (https://docs.typesafe.ai/models.md), though non-Latin scripts tokenise less efficiently,
so tokens per character are higher — measure it rather than assuming parity.

- Field evidence (community-report): jev-skip (valentynkit), 23 videos — catches 77% of the sponsor seconds SponsorBlock's crowd marked, 34 seconds/hour of false positives, $0.0008 per video, 0.9 s, with the explicit caveat "non-English captions perform weaker". Source: https://github.com/valentynkit/jev-skip

- Field evidence (independent-benchmark): mahlernim/jev-korean-benchmark, 100 items per condition — Belebele/PAWS-X/MedQA EN 97/80/89 against KO 96/76/80, where gpt-5.6-luna scored 95/72/88 in Korean; the author states a +/-8 point margin, 2026-09-19. Source: https://github.com/mahlernim/jev-korean-benchmark

## When the verdict flips

It flips to **good** per language, one at a time, once four conditions hold: a labelled sample of your own
non-English content shows agreement you accept; confidence thresholds are tuned separately for that
language; criteria have been reviewed by a speaker of it, not translated mechanically; and the
low-confidence band routes to a human who reads that language. It stays **weak** for any language you
have not measured, and for a design that applies one global threshold across all of them.

## Alternatives considered

- **Regex / deterministic**: language detection and script checks. Free; keep them.
- **Small LLM**: multilingual coverage varies too; the same evaluation obligation applies.
- **Frontier LLM**: generally the strongest multilingual option, at seconds and cents.
- **Fine-tuned classifier**: a multilingual encoder fine-tuned on your labelled tickets is a strong
  competitor precisely where you have per-language data.
- **Embeddings**: multilingual embeddings handle cross-lingual retrieval well.
- **Human**: native-speaker reviewers define the labels your evaluation needs.

## Sources

- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19
