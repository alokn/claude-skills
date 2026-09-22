---
id: au-expect-fine-tuning-from-feedback
title: Do not expect jev to be fine-tuned or to learn from your feedback
verdict: no
domain: ml
decision_shapes: [classification]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/models.md  ("Jev is not fine-tuned or LoRA-adapted with customer data ... the same weights serve every account"; "Jev is not trained on customer requests or responses")
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (train a classical model on jev's probabilities)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (combine outputs in code or feed a classical ML model)
related: [au-private-knowledge-not-in-state, au-exact-grade-prediction-high-stakes, au-tiny-volume-human-reviewed-workflow]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to fine-tune jev on our labelled tickets?" Also "will it get better as our reviewers
correct it", "can we upload examples so it learns our taxonomy", "does it adapt to our domain over time".

## Verdict

**No** — the capability does not exist, and planning around it will strand a roadmap. The models page:
"Jev is not fine-tuned or LoRA-adapted with customer data. It is trained with RLCD to return calibrated
decisions, and the same weights serve every account." It also states that "Jev is not trained on customer
requests or responses." There is no training endpoint, no adapter, no feedback channel that changes the
model, and corrections you record have no effect on future answers.

Not a model failure: **deployment** veto — the capability does not exist in the product.

## What jev would get wrong

Nothing at inference; the error is in the plan. Teams write "accuracy will improve as we collect
corrections" into a business case and then find, months later, that the accuracy curve is flat because
nothing is learning. A related and more insidious version: a team assumes a thumbs-down button is
feeding a training loop, so nobody tunes the questions — the one lever that actually moves the answers
goes unused.

## What stays in code

The adaptation, and there is plenty of it. The models page names three levers explicitly: put your
proprietary content in `state`; encode your domain rules and boundary cases in `instructions` and
`criteria`; decompose broad judgements into atomic questions and combine the outputs in code. All three
live in your repository, are versioned, are reviewable, and take effect immediately — which is arguably
better than a training run.

There is also a documented way to *actually* learn from your labels without touching jev: use jev's
probabilities as features in a downstream classical model. The AutoResearch cookbook trains a CatBoost
model on System One outputs against ground-truth outcomes; the how-to-build guide's composition step says
the same — "For learned composition, use the probabilities as features in a downstream classical
machine-learning model." Your corrections train *that* model. Jev stays fixed.

## Numbers

No training cost, because there is no training. Inference is $0.042 per million input tokens with output
free (https://docs.typesafe.ai/models.md). The cost of adaptation is engineering time spent on criteria
and decomposition. One version-management number matters: the `jev-latest` alias currently resolves to
`jev-1.13.0`, and "an alias moves when a new release ships, so the answers behind it can change without a
change on your side" — pin the versioned ID once thresholds are tuned.

- Field evidence (independent-benchmark): bitnovus/jev-spam-eval, 5,733 messages — detailed criteria written from labelled error analysis lifted jev from 93.62% (text only) to 98.64% three-way accuracy; the author's own summary is that "no task-specific fitting is not no supervision", and TF-IDF logistic regression needs roughly 10,000 labels to match jev on the 18,514-message binary task, 2026-09-19. Source: https://github.com/bitnovus/jev-spam-eval

## When the verdict flips

For fine-tuning, **no rewrite exists** — it is not on offer. What flips to **good** is the substitute
learning loop: log every jev answer with its probabilities alongside the eventual ground-truth outcome,
and train a classical model on those features. That loop genuinely improves with feedback, is cheap, and
stays inside your infrastructure. The second thing that flips is prompt-side adaptation: treat criteria as
code, keep a regression set of labelled cases, and re-run it whenever you change a question or move
versions. If your requirement is genuinely per-customer weights, jev is the wrong product category —
use a fine-tuned encoder.

## Alternatives considered

- **Regex / deterministic**: encodes hard domain rules with no training at all.
- **Small LLM with few-shot examples**: in-context adaptation without weight changes; slower and less
  consistent than jev, and also does not learn.
- **Frontier LLM**: same; in-context only.
- **Fine-tuned classifier**: the correct choice when you have thousands of labels and need the model to
  absorb them. This is the real alternative.
- **Embeddings + nearest neighbour over labelled examples**: a cheap learning loop that does improve with
  feedback.
- **Human**: supplies the labels that train the downstream model.

## Sources

- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
