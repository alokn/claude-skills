---
id: au-show-score-as-a-number-to-users
title: Do not show a jev Score or confidence to end users as a magnitude
verdict: no
domain: product
decision_shapes: [scoring]
primitives: [score, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/primitives/score.md  ("Different distributions can produce the same score")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score"; score levels "weak in numerical calibration")
  - https://docs.typesafe.ai/confidence.md  ("This describes the model's answer, not a guarantee that the answer is correct")
  - https://github.com/yodablocks/jev-orderby-bench  (inversion 0.255 on ESCI; "Complement" ranked below "Irrelevant")
related: [au-interpolate-magnitude-from-score, au-exact-grade-prediction-high-stakes, au-confidence-as-correctness-gate, au-zero-hallucination-means-always-right]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to show the jev score in the UI as '87% match' or 'risk: 7.2/10'?" Also "display the
confidence next to the answer", "put the propensity score on the customer's dashboard", "show the
reviewer a percentage".

## Verdict

**No** as a magnitude a person will read as a measurement. Two docs statements make the display
misleading rather than merely imprecise. The score is "a probability-weighted mean of the level numbers",
and "Different distributions can produce the same score. A score of 1.0 can mean all probability is on
level 1, or half is on each of levels 0 and 2" — so two items that look identical on screen can be
completely different states of the model's belief. And the jaggedness page says the levels are "weak in
numerical calibration", which forbids exactly the arithmetic a user performs unconsciously when they see
87%: that it is roughly twice 43%, and a bit better than 85%.

Closest failure mode: **math and counting** — a Score is a probability-weighted mean of level
numbers and is weak in numerical calibration, so it must not be shown as a magnitude a reader
will do arithmetic on.

## What jev would get wrong

Nothing in the output; the error is in the reading. Rendered as a number, a Score acquires three
properties it does not have: a scale (that 7.2 sits on a ruler with fixed spacing), comparability (that
7.2 beats 6.9 meaningfully), and precision (that the second digit carries information). The measured
counter-example is blunt: on Amazon ESCI the inversion rate was 0.255 and the "Complement" grade ranked
*below* "Irrelevant", so on that dataset the ordering of the levels was not even preserved, let alone
their spacing. Showing confidence has the same problem with an extra twist — high confidence "describes
the model's answer, not a guarantee that the answer is correct", but every user reads it as a probability
of being right.

## What stays in code

The translation from number to words, done once, in the UI layer. Map the score onto the named levels you
already wrote in the criteria — "strong match", "partial match", "no evidence found" — and show the
label plus the evidence that produced it, not the float. Where an ordering is genuinely useful, show rank
or position in a queue rather than the value. Keep the raw score, probabilities, confidence and model
version in logs and internal dashboards, where the people reading them know what a probability-weighted
mean of level positions is. If a number must appear because a regulator or a contract requires one, it
should be computed in code from countable facts, not read off the model.

## Numbers

Score criteria accept 2 to 10 levels, so ten named buckets is the finest resolution the primitive
supports (https://docs.typesafe.ai/primitives/score.md) — any percentage implies a precision the model
cannot express. Inversion rate 0.255 on 306 Amazon ESCI pairs with ECE 0.242
(https://github.com/yodablocks/jev-orderby-bench, accessed 2026-09-19), against inversion 0.036 and ECE
0.045 on 20 Newsgroups from the same harness. No published source measures how users interpret a
displayed jev score; the docs' own prohibition on reconstructing magnitudes is the operative constraint.

## When the verdict flips

It flips to **conditional** for internal, expert audiences — an analyst queue, a moderation console, a
debugging view — where the reader is told what the number is and the probabilities are shown beside it.
It also flips for a *relative* display with no implied scale: sorted order, a three-band traffic light, or
"top 5% of this week's queue" computed in code from the distribution you observed. For a user-facing
percentage that looks like a measurement, **no rewrite exists** — show the label instead.

## Alternatives considered

- **Regex / deterministic**: where a real number exists in the data, compute and show that.
- **Small LLM**: no typed probability at all unless you read logprobs; worse.
- **Frontier LLM**: a self-reported percentage has no calibration training behind it; jev's is
  trained to be calibrated, and neither is calibrated on your data until you measure it.
- **Fine-tuned classifier**: a probability calibrated on your labels can be shown with an interval.
- **Embeddings**: cosine similarity is even less interpretable to a user.
- **Human**: the reviewer whose judgement the label supports; give them the evidence, not the float.

## Sources

- https://docs.typesafe.ai/primitives/score.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://github.com/yodablocks/jev-orderby-bench — accessed 2026-09-19
