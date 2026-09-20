---
id: au-over-decompose-when-one-question-works
title: Do not decompose into many dimensions when one question already scores well
verdict: weak
domain: ml
decision_shapes: [classification, detection, verification, feature-extraction]
primitives: [choice, score, noul]
evidence_level: independent-benchmark
sources:
  - https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/  (37.2% vs 1.5% false positives on 339 hard-benign security documents; four tasks, 15,508 rows)
  - https://docs.typesafe.ai/primitives.md  (extra questions are cheap; parallel evaluation)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1, literal reading)
related: [au-single-question-framing-sensitivity, au-chain-questions-in-one-request, au-sole-security-gate, cb-parallel_questions]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to replace our single judge question with twelve dimension questions?" Also "more
questions is always better, right?", "should we score every rubric dimension separately?", "why did our
false-positive rate explode after we decomposed?".

## Verdict

**Weak** when the single question is already strong, and actively harmful on near-miss content. The
agentjournal experiment ran both configurations across four datasets and 15,508 rows. Decomposition won
three of them — weak-cue detection 64.7% → 74.0%, Japanese NLI 83.7% → 90.8%, a ledger task 40.0% →
91.1% — and lost the one where the single call was already near-perfect: synthetic B2B replies 100%
single against 98.0% decomposed. The headline number is from the fourth measurement: on 339 hard-benign
security documents, the dimension design flagged **37.2%** against **1.5%** for the direct question, about
25x worse on false positives.

## What jev would get wrong

Each dimension is answered literally and in isolation — "`jev-1.13` answers the question you wrote, not
the one you meant" — so a document that legitimately discusses credentials, exfiltration or privilege
escalation trips several individually-correct signals at once. Combine them with an OR, or with a
threshold on the count, and the benign case that a holistic read would dismiss becomes a confident flag.
The more dimensions you add, the more opportunities a hard-benign item has to look guilty; the effect
compounds with the decision rule, not with the model's error rate.

## What stays in code

The combination rule, and the measurement that justifies it. Do not OR the dimensions together by
reflex. Fit the combiner on labelled data — a weighted sum, a small logistic regression over the
dimension outputs, or a rule that requires two specific signals rather than any one — and evaluate it on
a hard-benign slice explicitly, not just on the positives. Keep the single holistic question running
alongside as a control: it costs one more question in the same call and it tells you whether the
decomposition is earning its place.

## Numbers

Hard-benign security documents, n=339: 37.2% flagged by the 12-14 dimension design against 1.5% by the
single question. Synthetic B2B replies, n=200: single 100%, dimensions 98.0%. Weak-cue detection, n=300:
64.7% → 74.0%. Japanese NLI, n=8,000: 83.7% → 90.8%. Ledger task, n=7,008: 40.0% → 91.1%
(https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/, accessed 2026-09-19; hand-written
dimensions, noisy Japanese NLI labels). Cost is not the deciding factor either way: extra questions
"barely change the response time and cost only the tokens for the extra questions"
(https://docs.typesafe.ai/primitives.md) — twelve dimensions over a 1,500-token document is roughly 2,300
input tokens, about $0.0001 at $0.042 per million input tokens with output free.

## When the verdict flips

It flips to **good** — and decomposition is the corpus's default advice — whenever the single question is
compound, multi-hop, or scoring below its ceiling: three of the four measured tasks gained, two of them
by more than 9 points, and the ledger task by 51. The rule that reconciles them is empirical: measure
both configurations on your own data, including a benign-but-similar slice, and keep the one that wins.
Never assume the decomposition is safe because it is more thorough.

## Alternatives considered

- **Regex / deterministic**: a precise rule on the one signal that matters beats a wall of soft ones.
- **Small LLM**: same trade-off, without typed per-dimension probabilities to combine.
- **Frontier LLM**: holistic judgement is its strength; too slow per item at volume.
- **Fine-tuned classifier**: learns the combination rule from labels instead of you guessing it.
- **Embeddings**: no dimension structure to exploit.
- **Human**: adjudicates the hard-benign slice that decides which design ships.

## Sources

- https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — accessed 2026-09-19
- https://docs.typesafe.ai/primitives.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
