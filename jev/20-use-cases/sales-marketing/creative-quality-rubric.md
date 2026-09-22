---
id: uc-sales-marketing-creative-quality-rubric
title: Score marketing creative against a quality rubric before it ships
verdict: conditional
domain: sales-marketing
decision_shapes: [scoring, ranking]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (advertising: "Evaluate creative quality and ad-to-landing-page alignment")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (score dimensions independently, weight them in code, inspect why an item ranked where it did)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: "do not use score outputs to compute the exact magnitude of a number between two levels"; failure mode 9: generation)
  - https://docs.typesafe.ai/models.md  (text only: no images, audio, or video)
related: [uc-sales-marketing-brand-safety-ad-copy-compliance, uc-sales-marketing-ad-landing-page-alignment, uc-commerce-review-sentiment-rubric]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score ad creative quality?" Also "can jev tell us which of
these 30 headlines is best?", "can we QA creative against the brand guide automatically?",
and "can jev predict which ad will perform?".

## Verdict

**Conditional**, and the condition is what you mean by quality. Jev cannot predict
performance — that needs outcome data and a model trained on it, and any score presented as a
performance forecast is invented. It also cannot see the creative: the model is text only, so
a display ad, a video, or a headline sitting on an image is out of scope except for its copy.
What it can do well is check copy against a rubric you wrote: does it state a benefit, is the
call to action specific, does it name the audience, is it on-brand in tone, does it repeat a
claim the brand guide forbids. That is a composite score over short text with an inspectable
breakdown, and for a team producing hundreds of variants it replaces a review queue nobody has
time for. Use it to filter and to catch defects, not to pick a winner.

## What jev decides

State: the creative's copy fields as structured data — headline, body, call to action — plus
the brand voice guidelines and the target audience description, both trimmed to a few hundred
characters each.

```
states_a_specific_benefit: Score
  instructions: "How specifically does `creative.headline` and `creative.body` state what the
                 reader gets?"
  criteria: ["No benefit stated; brand or product name only",
             "A generic benefit any competitor could claim",
             "A concrete benefit, no specifics",
             "A concrete benefit with a specific outcome, number, or situation"]

cta_is_actionable: Score
  criteria: ["No call to action",
             "A vague invitation such as learn more",
             "A clear next step",
             "A clear next step that says what happens after the click"]

addresses_named_audience: Noul
  instructions: "Does the copy speak to the audience described in `campaign.audience`?"

matches_brand_voice: Score
  instructions: "How well does the copy follow `brand.voice_guidelines`?"
  criteria: ["Contradicts the guidelines",
             "Neutral; neither follows nor contradicts them",
             "Consistent with the guidelines",
             "Distinctly in the brand's voice as described"]

uses_forbidden_phrasing: Noul
  instructions: "Does the copy use wording that `brand.avoid_list` tells writers not to use?"

jargon_heavy: Noul
  instructions: "Would a reader outside the industry need to look up a term to understand the
                 headline?"
```

Composition in code with weights per channel — a search ad weights the call to action, a
social ad weights the benefit — which is the composite-scoring pattern's point: one inference,
several rankings, and you can change the weights when the channel mix changes. Bands: flag
anything with a dimension at the bottom level and high confidence for the writer to revisit;
rank the rest.

## What stays in code

The weights, the channel rules, and every measurable constraint. Character limits, required
legal text, banned-term matching against `avoid_list` as an exact string check, and the
presence of tracking parameters are deterministic, cheaper and exactly right. Performance data
— click-through, conversion, cost per acquisition — is the real quality signal and belongs in
your analytics, not in a rubric. If you want a predictive score, train a model on those
outcomes and use jev's dimensions as features.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 400-character creative plus
brand and audience context (~800 characters) plus these six questions with levels (~2,000
characters) is ≈ 800 tokens, **≈ $0.000034 per variant**. Scoring 500 variants across a
campaign is under **two cents** of inference, which is what makes rubric review of every
variant possible rather than a review of the three someone liked. Latency 70–500 ms, fast
enough to run in the copy tool as a draft is written. Run-to-run stability matters when
writers compare scores between drafts: the consistency cookbooks measured jev's mean
per-question probability standard deviation at 0.0102 (Noul rubric) and 0.0098 (Choice
rubric) over 15 repeats, sampled 2026-09-11. **No accuracy or predictive-validity figure is
published for creative scoring, and there is no reason to expect the rubric to correlate with
performance** until you have checked it against your own results.

## When the verdict flips

- You present the composite as predicted performance. Not measured, not calibrated, and the
  jaggedness page forbids treating a score as a magnitude in the first place.
- The creative is an image, a video, or a carousel. Text only; the copy is a fraction of it.
- You use it to reject a writer's work. It scores conformance to a rubric, which is a
  different thing from good, and the rubric is where all the judgement actually lives.
- You ask it to write a better headline. Generation, failure mode 9 — that is an LLM's job,
  and jev can score the LLM's output.
- The rubric levels are adjectives ("weak", "strong") rather than situations. Then the scores
  mean nothing and the numbers will still look convincing, which is worse.

## Alternatives considered

- **A/B testing.** The only real answer to "which performs better", and slow and expensive per
  variant; this is how you decide what is worth testing.
- **Character limits and banned-term linting.** Deterministic, exact, already necessary; keep.
- **Frontier LLM critique.** Gives a writer a useful paragraph of feedback, which jev
  structurally cannot; seconds and cents per variant, so run it on the flagged ones.
- **Small LLM scoring.** Roughly an order of magnitude more cost and latency per
  multi-question call, and less stable across drafts, which writers notice immediately.
- **Trained performance model on historical creative and outcomes.** The right tool for
  prediction if you have the data; jev's dimensions make reasonable features.
- **Creative director review.** The decision-maker; this clears the obvious defects first.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/composite-scoring.md`,
`model-jaggedness/jev-1.13.md` (modes 2 and 9), `models.md` (text only),
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`
(std dev, sampled 2026-09-11).
