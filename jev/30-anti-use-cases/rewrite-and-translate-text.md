---
id: au-rewrite-and-translate-text
title: Do not use jev to rewrite, paraphrase, or translate text
verdict: no
domain: content
decision_shapes: [classification, verification]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9, Generation)
  - https://docs.typesafe.ai/models.md  (language support: English primary, other languages "not equally well")
  - https://docs.typesafe.ai/concepts/system-one.md  (typed decisions, not generated text)
related: [au-write-customer-replies, au-non-english-at-scale-unevaluated, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to rewrite this in plain English / translate our help centre into German /
make this subject line punchier?" Also "can jev normalise our product descriptions", "use jev for
localisation QA by re-translating".

## Verdict

**No.** Rewriting and translating both produce new text, and text production is failure mode 9:
"`jev-1.13` is not trained to generate text." Translation additionally lands on jev's weakest input
axis. The models page states that "English is the primary training language and where accuracy is
currently best. Other languages, including CJK scripts, are handled but not equally well; test on your
own content before relying on Jev for a non-English workload." So even the judgement half of a
translation workflow needs your own evaluation before you trust it.

## What jev would get wrong

The only way to attempt a rewrite is a Choice over pre-written variants, which is not a rewrite — it is
selection from a fixed set, and it cannot handle any input the set does not already cover. For
translation, the failure is subtler and more dangerous: teams ask jev "Is `translation` a faithful
translation of `source`?" as a QA gate. That is a legitimate Noul in shape, but it is a judgement about
non-English text, where the docs say accuracy is lower and instruct you to "pay close attention to
Confidence when routing". Run without a measured threshold on your own language pairs, that gate will
pass bad translations silently.

## What stays in code

All text production. A generative model writes the rewrite or the translation; code stores it, versions
it, and decides what ships. Style rules that are actually mechanical — sentence length, banned words,
reading level, placeholder integrity, HTML tag parity between source and target — belong in code or a
linter, not in a model of any kind.

Where jev fits is after generation, as a bounded judge, and only on evaluated language pairs: a Noul
"Does `translation` omit a fact stated in `source`?", a Noul "Does `translation` add a claim absent from
`source`?", and a Score over three described levels of register match. Code combines them and sends the
low-confidence cases to a human linguist.

## Numbers

No published benchmark measures jev on rewriting or translation quality; it is not a generation model.
TypeSafe's own workflow evals place jev at 67.8% combined accuracy against Opus 5 at 73.1% and Sonnet 5
at 67.8% on decomposed English workflows (https://evals.typesafe.ai, read 2026-09-19) — those are
decision tasks, not generation, and they say nothing about translation. Verification calls cost the
source plus target plus questions at $0.042 per million input tokens, output free
(https://docs.typesafe.ai/models.md).

- Field evidence (community-report): Langfuse's evaluator write-up (2026-09-18) calls jev "entirely unsuitable" for generation tasks; `fdsimms/todo#2781` reached the same conclusion for 7 of 15 planned features, 2026-09-17. Source: https://langfuse.com (post dated 2026-09-18; full URL not recorded in `50-sources/`)

## When the verdict flips

For producing the text, **no rewrite exists**. The task flips to *conditional* when it is reframed as
post-generation verification — one Noul per named defect, English-side wherever possible — and the
condition is explicit: you have measured agreement against human linguists on your own language pairs
and tuned the threshold, per the models page's instruction to test non-English content before relying
on it. A second conditional case: choosing which of N already-written variants to ship, as a Choice with
a `none of these` option.

## Alternatives considered

- **Regex / deterministic**: correct for placeholder, tag, and length checks; use it first and for free.
- **Small LLM**: standard choice for rewrites and for bulk machine translation.
- **Frontier LLM**: for marketing copy or legal text where nuance matters.
- **Fine-tuned classifier**: viable for translation-quality estimation if you have labelled data; a
  dedicated MT quality-estimation model beats a general judge.
- **Embeddings**: cross-lingual embeddings can flag gross mismatch cheaply; they miss omissions.
- **Human**: the final gate for published localised content.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19 (language support, price)
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
