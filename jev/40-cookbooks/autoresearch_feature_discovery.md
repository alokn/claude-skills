---
id: cb-autoresearch_feature_discovery
title: Autoresearch feature discovery
url: https://docs.typesafe.ai/cookbooks/autoresearch_feature_discovery.md
decision_shapes: [feature-extraction, scoring]
primitives: [score, noul]
related: [uc-data-ml-text-features-for-tabular-model, uc-commerce-review-sentiment-rubric, uc-risk-forecasting-incident-report-risk-indicators, au-predict-outcome-instead-of-features]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Turn free text into numeric columns for a supervised CatBoost regressor, discovering the
questions automatically. An LLM proposes TypeSafe questions, jev answers them for every
row, CatBoost trains on the answers, and CatBoost's error and importance report feeds the
next proposal call.

Dataset: 2,000 wine reviews from the pinned HuggingFace CSV `GroNLP/ik-nlp-22_winemag`
(`train.csv`, revision `90eb39f3...`), deduplicated on the description, sampled with
`seed=0`. Split `N_DEV, N_TEST = 1200, 800`: "1200 dev rows, 800 held out; scores run
80-98, mean 88.73, sd 3.17". Input is the tasting note, label the critic's 80-100 score.
"The numbers came from TypeSafe `jev-1.12` and `claude-sonnet-5` on 2026-08-03."
`propose()` has a second branch for `gpt-5.6-luna`, "which was not run."

## Decomposition (state, questions, how answers are combined)

State is the bare note string: `client.system_one(state=note, questions=..., model=model)`.
All of a round's questions ride one request per row, so "one more question costs no extra
request". The proposer emits `kind: "intensity"` (a `Score`) or `"presence"` (a `Noul`),
against fixed criteria it cannot change:

```python
INTENSITY_LEVELS = [
    "Not present in this note at all",
    "Barely present - mentioned once, in passing",
    "Present at a moderate level",
    "Present strongly - the note dwells on it",
    "Dominant - the note is largely about this",
]
PRESENCE_CRITERIA = NoulCriteria(
    true="The note states this or clearly implies it",
    false="The note gives no indication of this",
)
```

The final set is 38 questions: "29 score, 9 noul". The top-importance one, verbatim -
`note_overall_tone_positivity`: "Setting aside specific descriptors, how positive is the
overall emotional tone and word choice of the note taken as a whole (warm, admiring
language throughout vs. flat, neutral, or lukewarm phrasing)?" A separate shortcut arm
asks jev for the score directly: one `Score` over ten `SCORE_LEVELS` bands, "Judging only
by what this tasting note says, how good is the wine?", rescaled
`80.0 + 20.0 * expected / top`, then moved by one dev-measured offset.

Encoding is code, not jev. With `ENCODING = "mean_spread"` a score answer gives
`mean = probabilities @ levels` plus `sqrt(variance)`; a noul gives its one probability.
So "29 score questions x 2 columns = 58" plus "9 noul questions x 1 column = 9" = 67
numeric columns. The accept/reject arithmetic is also code:

```python
ROUNDS = 5; PROPOSALS = 18; EXAMPLES = 60
MIN_SPREAD = 0.05        # a flat column is not kept
CHANGE_TOLERANCE = 0.0   # a revision or drop must improve dev error
FOLDS, REPEATS = 5, 3
if cv_trial <= cv + tolerance:   # keep the change
```

An `add` goes in unless `float(column[split.dev].std()) < min_spread`. Every `revise` and
`drop` is refit under 5-fold, 3-repeat cross-validation on the dev rows and kept only if
dev RMSE falls. Round 1 shows the proposer 60 dev notes across the score range; later
rounds show "the 30 worst-predicted dev notes + the 30 best" plus per-question importance
and spread. No confidence band, no abstain path: answer spread is a feature, not a gate.

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run date 2026-08-03, `jev-1.12`, proposer `claude-sonnet-5`. All arms scored once on the
same 800 held-out rows.

| arm | RMSE (intro table) | RMSE (computed) | spearman |
|---|---|---|---|
| predict the average/mean score of the dev rows | 3.09 | 3.088 | -0.014 |
| the note as word counts, same CatBoost | 2.47 | 2.466 | 0.605 |
| ask for the score itself, shifted -1.71 | 2.15 | 2.145 | 0.761 |
| 18 questions from round 1, no loop | 1.87 | 1.869 | 0.778 |
| 38 questions after all 5 rounds | 1.77 | 1.772 | 0.799 |

Dev cross-validated RMSE per round (features in brackets): `1.903` (18), `1.881` (23),
`1.861` (30), `1.838` (35), `1.840` (38). Round actions: "18 add, 0 revise, 0 drop";
"5 add, 3 revise, 3 drop"; "7 add, 2 revise, 1 drop"; "5 add, 2 revise, 3 drop"; "4 add,
2 revise, 8 drop".

Loop gain: "round 1 -> round 5 on the held-out rows: -0.097 points, 95% CI [-0.147,
-0.050]", from "the same held-out rows resampled 2,000 times"; restated as "the four
rounds after it are worth 0.10 points on the held-out rows".

Importance shares (CatBoost importance normalized to 100% over the 38 questions):
`note_overall_tone_positivity` 17.4% (score), `savory_food_wine_seriousness` 8.7%,
`positive_superlative_language` 8.4%, `single_vineyard_or_prestige_signal` 7.2% (noul),
`descriptive_detail_density` 5.7%, then `elegance_finesse_language`, `complexity` and
`aging_potential` at 5.0% each, down to `flavor_distinctiveness` 2.6%.

Volume: "a round answers questions for all 2,000 rows: 2,000 requests"; "one request per
row per round, so 100,000 rows is 100,000 requests a round"; pool of 8 workers, "Eight is
already enough to hit a rate limit on a shared key." Cost: not reported. Latency: not
reported.

## Caveats the cookbook itself states

"All of this is one dataset and one run of the loop." "The word-count row is CatBoost's own
text handling, not a tuned text-regression pipeline." Most of the gain is in the first
proposal call; the four feedback rounds move the held-out number 0.097 points and
"everything on it happens inside a fifth of a point". Round 5 "gave the first dev number
that did not improve": "There is only so much to ask about a 245-character note." The dev
line sits above the held-out line throughout, which "is a training-size effect".
`importance share` "is not a share of rows, of questions, or of prediction accuracy." Ten
levels is the ceiling for a `Score`: "eleven comes back as a server error." The
direct-score arm needs the dev-measured offset because "nothing in the question says where
this publication's scores actually sit on it". "Next steps" lists what this run skipped:
candidate screening, correlated-feature pruning, TF-IDF and embedding baselines, and
stability checks across seeds.

## Lessons transferable to other use cases

- Fan-out: a round's questions all ride one request per row, so the call count grows with rows
  and not with questions — but question text is billable input on every row, so cost grows with
  rows x (state tokens + question tokens). Budget by rows and by the size of the question set.
- jev as featurizer, not predictor. A Score distribution becomes two columns (mean and
  spread) and a supervised model does the regression; asking jev for the target directly
  was worse here (2.145 vs 1.772 RMSE).
- Code does the arithmetic and the selection: the encoding, the `0.05` flat-column filter,
  the `<= cv + 0.0` accept rule, the k-fold refits.
- Machine-written questions are safe when the schema is fixed: the proposer writes only
  instruction strings, so nothing it writes can break the output type.
- Measure a discovery loop's marginal value on held-out rows with an interval: here the
  feedback rounds were worth far less than the first proposal call.
- Does not generalise: the RMSE figures, the domain, and the premise that 2,000 labelled
  rows exist. With no labels the loop has nothing to steer by.

## Use-case entries this supports

- `uc-data-ml-text-features-for-tabular-model` - convert free-text fields into numeric columns for a tabular model
- `uc-commerce-review-sentiment-rubric` - score review prose on rubric dimensions rather than one sentiment label
- `uc-risk-forecasting-incident-report-risk-indicators` - turn narrative text into scored columns for a risk model

**Anti-use-case implied:** `au-predict-outcome-instead-of-features` - asking jev for the numeric
target itself reached RMSE 2.145 against 1.772 for the same model fed jev-derived features; jev
supplies features, a fitted model supplies the number.
