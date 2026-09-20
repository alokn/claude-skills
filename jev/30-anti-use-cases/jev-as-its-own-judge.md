---
id: au-jev-as-its-own-judge
title: Do not evaluate a jev system with jev as the judge
verdict: no
domain: ml
decision_shapes: [verification, scoring, ranking]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/zhuyansen/jev-search-rerank-eval  (self-preference measured: +0.053 under jev labels, -0.028 under Haiku labels)
  - https://arize.com/blog/typesafe-jev-llm-judge/  (TypeSafe's own numbers compare against reference probabilities from other models)
  - https://news.ycombinator.com/item?id=49717558  (calibration curve "from someone other than TypeSafe")
related: [au-zero-hallucination-means-always-right, au-replace-vector-retrieval-with-jev-rerank, au-copy-calibration-thresholds-across-domains, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to score our jev-powered ranker with a jev rubric?" Also "use jev as the LLM judge for
our jev classifier", "generate labels with jev and measure jev against them", "our internal eval says
+8%, is that real?".

## Verdict

**No.** The one study that measured this put a number on it. zhuyansen's rerank evaluation scored the
same system under two label sets over 164 queries and 9,831 graded pairs: with jev-generated labels the
rerank gain was **+0.053 NDCG@10**; with Claude Haiku 4.5 as an independent judge the same system scored
**−0.028 [−0.052, −0.004]**. The sign of the result is decided by who labels it. An internal "jev agrees
with jev" eval should be discounted by roughly that swing, which is larger than most improvements anyone
is trying to detect.

Not a model failure: **governance** veto — an evaluation-design error; the judge has to be
independent of the system under test.

## What jev would get wrong

Nothing visible — that is the problem. A judge that shares a model's priors rewards the outputs that
model already prefers, so the eval is measuring agreement, not accuracy, and it returns a clean typed
number with a confidence value attached. The same criticism was made of the vendor's own evidence: Arize
notes TypeSafe's numbers "compare model outputs against reference probabilities from other models, rather
than human-labeled ground truth", and the most-repeated request in the launch thread was for a
calibration curve "from someone other than TypeSafe". Langfuse's 6,003-check study shows the softer
version of the same trap — jev agreed with Claude Fable 5.1 on 91.5% of verdicts while DeepSeek V4.1 Flash
agreed 93.5%, and agreement with a frontier model is not correctness either.

## What stays in code

The label set and the comparison. Hold out a sample labelled by humans, or at minimum by a *different*
model family, and keep it frozen and versioned so successive runs are comparable. Record which judge
produced which label. Where a judge model is unavoidable, run both judges and report both numbers, as the
rerank study did — the cheapest honest artefact in this corpus is a table with two columns. Keep a small
hand-adjudicated subset (that study hand-adjudicated 30 of 164 queries) to catch the case where both
judges are wrong together.

## Numbers

Self-preference swing: +0.053 under jev-only labels against −0.028 [−0.052, −0.004] under Haiku-only
labels, a spread of roughly 0.081 NDCG@10 on the same system, 164 queries over a 33,047-entry catalogue
(https://github.com/zhuyansen/jev-search-rerank-eval, accessed 2026-09-19). Agreement is not accuracy:
91.5% jev-versus-Fable-5.1 agreement at $160 per million verdicts, against DeepSeek V4.1 Flash at 93.5%
and $260 per million, over 6,003 rubric checks (Langfuse citing Good Start Labs, 2026-09-18 — a
vendor-integration post). Judging 1,000 items at 1,200 tokens each costs about $0.05 at $0.042 per million
input tokens with output free (https://docs.typesafe.ai/models.md); human labels for the same 1,000 items
cost hours. That asymmetry is exactly why the shortcut is tempting.

## When the verdict flips

It flips to **conditional** for *regression detection* rather than quality measurement: a jev-judged
suite run against a frozen baseline can tell you something changed between two versions of your own
system, provided the judge's version is pinned and you never quote the absolute number as accuracy. It
never flips for a claim of improvement, for a vendor comparison, or for a calibration curve — for those,
**no rewrite exists** short of independent labels.

## Alternatives considered

- **Regex / deterministic**: where the correct answer is checkable, check it; no judge needed.
- **Small LLM**: a different family is a genuinely useful second judge, and cheap.
- **Frontier LLM**: better judge, still correlated with whatever produced the output; report both.
- **Fine-tuned classifier**: trained on your human labels, it *is* the ground-truth proxy.
- **Embeddings**: can measure drift between runs, not correctness.
- **Human**: the only label that ends the argument; sample rather than label everything.

## Sources

- https://github.com/zhuyansen/jev-search-rerank-eval — accessed 2026-09-19
- https://arize.com/blog/typesafe-jev-llm-judge/ — accessed 2026-09-19
- https://news.ycombinator.com/item?id=49717558 — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
