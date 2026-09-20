---
id: uc-data-ml-text-features-for-tabular-model
title: Turn free text into numeric features for a downstream classical ML model
verdict: strong
domain: data-ml
decision_shapes: [feature-extraction, scoring, detection]
primitives: [score, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md  (2,000 wine reviews; 38 questions -> 67 columns; RMSE 1.772 vs 2.145 asking jev directly; importance shares)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (ML Feature Extraction; "Combine these features with structured data to train models for tasks with ground-truth outcomes")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens; rate limits)
related: [uc-data-ml-map-reduce-corpus-labelling, uc-data-ml-transcript-coding-codebook, uc-search-retrieval-query-intent-classification]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to featurize text for our model?" Also: "we have a gradient-
boosted model on tabular data and a free-text notes column we ignore", "should we just ask jev
for the prediction?", "can we get interpretable semantic features instead of TF-IDF?"

## Verdict

**Strong**, with the roles fixed: jev supplies *features*, a fitted model supplies the *number*.
The cookbook measured both arms on the same held-out rows and asking jev for the target directly
was worse (RMSE 2.145) than feeding jev-derived features to CatBoost (1.772). The prerequisite
is ground truth — without labels there is nothing to select features against, and the loop has
nothing to steer by.

## What jev decides

State is the bare text: `client.system_one(state=note, questions=..., model=model)`. All of a
round's questions ride one request per row, so "one more question costs no extra request".

Two fixed shapes, so nothing a question-writer does can break the output type:

```python
INTENSITY_LEVELS = [
    "Not present in this note at all",
    "Barely present - mentioned once, in passing",
    "Present at a moderate level",
    "Present strongly - the note dwells on it",
    "Dominant - the note is largely about this",
]
PRESENCE_CRITERIA = NoulCriteria(true="The note states this or clearly implies it",
                                 false="The note gives no indication of this")
```

The top-importance question in the final set, verbatim — `note_overall_tone_positivity`:
"Setting aside specific descriptors, how positive is the overall emotional tone and word choice
of the note taken as a whole (warm, admiring language throughout vs. flat, neutral, or lukewarm
phrasing)?"

Encoding is code, not jev. With `ENCODING = "mean_spread"` a Score answer becomes two columns —
`mean = probabilities @ levels` and `sqrt(variance)` — and a Noul becomes one. "29 score
questions x 2 columns = 58" plus "9 noul questions x 1 column = 9" = 67 numeric columns. The
spread column is the point: uncertainty is a feature, not a gate.

## What stays in code

The encoding, the feature-selection arithmetic, the cross-validation and the model:

```python
ROUNDS, PROPOSALS, EXAMPLES = 5, 18, 60
MIN_SPREAD = 0.05        # a flat column is not kept
CHANGE_TOLERANCE = 0.0   # a revision or drop must improve dev error
FOLDS, REPEATS = 5, 3
```

Also the concurrency pool ("Eight is already enough to hit a rate limit on a shared key") and
the train/test split.

## Numbers

From `autoresearch_feature_discovery.md` — 2,000 deduplicated wine reviews from the pinned
`GroNLP/ik-nlp-22_winemag` CSV, "1200 dev rows, 800 held out; scores run 80-98, mean 88.73, sd
3.17". "The numbers came from TypeSafe `jev-1.12` and `claude-sonnet-5` on 2026-08-03." All arms
scored once on the same 800 held-out rows:

| arm | RMSE | spearman |
|---|---|---|
| predict the dev mean | 3.09 | -0.014 |
| the note as word counts, same CatBoost | 2.47 | 0.605 |
| ask jev for the score itself, shifted -1.71 | 2.15 | 0.761 |
| 18 questions from round 1, no loop | 1.87 | 0.778 |
| 38 questions after all 5 rounds | 1.77 | 0.799 |

Loop gain: "round 1 -> round 5 on the held-out rows: -0.097 points, 95% CI [-0.147, -0.050]" —
most of the value is in the first proposal call. Importance shares over the 38 questions:
`note_overall_tone_positivity` 17.4%, `savory_food_wine_seriousness` 8.7%,
`positive_superlative_language` 8.4%, `single_vineyard_or_prestige_signal` 7.2% (a Noul).

Sample size and label provenance, which is what the `strong` rests on: **n = 800 held-out rows**
(from 2,000 deduplicated reviews, 1,200 used for development). The target is the wine
reviewer's own published 80-98 point score — **human-authored, pre-existing, not synthetic and
not adjudicated for this experiment** — and the metric is RMSE against that score, not agreement
with another model. The comparison the cookbook does not run is TF-IDF or embeddings into the
same CatBoost, so "better than word counts" is the measured claim, not "better than the usual
text-feature baseline".

Volume: "a round answers questions for all 2,000 rows: 2,000 requests"; "one request per row per
round, so 100,000 rows is 100,000 requests a round". Cost and latency: **not reported** by the
cookbook; at $0.042 per million input tokens with free output, a 245-character note with 38
questions is roughly 1,500 input tokens, about $0.00006 per row.

Closest jaggedness mode: **2, math and numbers** — avoided entirely, because jev never produces
the number; CatBoost does.

- Field evidence (independent-benchmark): agentjournal.dev, 15,508 rows total, jev multi-dimension feature extraction feeding a small trained model rather than a single judge call: weak-cue classification 64.7% -> 74.0% (+9.0 pt reported), Japanese NLI over 8,000 rows 83.7% -> 90.8% (+7.0 pt reported), and a 7,008-row ledger task 40.0% -> 91.1%, at "$0.042 per 1k rows" for 12 dimensions. The same study is the counter-example: on 339 hard-benign security documents the dimension set flagged 37.2% against 1.5% for a single direct question, and on synthetic B2B replies the single call won 100% to 98.0%, 2026-09. Source: https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/

## When the verdict flips

- **No ground-truth labels.** Then there is nothing to select features against; you are
  guessing. This is the hard prerequisite.
- **TF-IDF or embeddings already do the job.** The cookbook's own word-count arm reached RMSE
  2.47 with no API calls at all; if your gap to that baseline is small, jev is **weak** here.
  Note the cookbook skipped "TF-IDF and embedding baselines" — so did it.
- **The target is directly extractable** (the note literally states the rating). Parse it.
- **The text is very short.** "There is only so much to ask about a 245-character note" — round 5
  "gave the first dev number that did not improve".
- **Tens of millions of rows.** One request per row per round; at that scale the rate limits
  (250k tokens/s, 1,200 requests/min, dynamic) and the wall-clock become the constraint.
- **More than 10 Score levels.** "eleven comes back as a server error."

## Alternatives considered

- **TF-IDF / bag of words into the same model** — the measured baseline (2.47), free at inference
  and the honest thing to beat; uninterpretable and blind to tone.
- **Sentence embeddings as features** — usually stronger than TF-IDF and dense: 384 opaque
  columns you cannot audit, weight, or explain to a domain expert. Jev's 67 columns each have a
  name and an English definition.
- **Fine-tuned text regressor** — the accuracy ceiling with enough labels, and it gives you one
  number rather than features you can combine with your structured columns.
- **Asking jev for the target directly** — measured and worse: 2.145 against 1.772, and it needed
  a dev-measured offset "because nothing in the question says where this publication's scores
  actually sit on it".
- **Hand-written keyword features** — cheap and brittle; this is the maintenance burden being
  replaced.

## Sources

- https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
