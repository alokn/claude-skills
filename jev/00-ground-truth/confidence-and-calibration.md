---
id: gt-confidence-and-calibration
title: Probability, confidence, calibration, and what is not guaranteed
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/confidence.md  (definition, three paths, thresholds scale with risk)
  - https://docs.typesafe.ai/introduction/machine-learning-primer.md  (calibration definition verbatim)
  - https://docs.typesafe.ai/primitives.md  (answer fields, Noul has no confidence)
  - https://docs.typesafe.ai/primitives/noul.md  (Noul does not return a separate confidence value)
  - https://docs.typesafe.ai/primitives/choice.md  (worked confidence values)
  - https://docs.typesafe.ai/primitives/score.md  (confidence on a Score, what low confidence means)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (structural invariants NOT guaranteed)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (self-consistent card, route on uncertainty)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (self-consistency run, nouls)
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (self-consistency run, choices)
  - https://typesafe.ai/  (homepage FAQ: deterministic vs consistent, can Jev get things wrong)
---

## Probability vs confidence

`probabilities` is the distribution the model returns over your options or levels.
`confidence` is a single number derived from that distribution.

> "All Score and Choice answers from TypeSafe include a `probabilities` property representing the probability distribution across the options (for Choice) or levels (for Score). The *shape* of that distribution is what tells you how certain the model is: concentrated on one outcome means a confident answer, spread out means an uncertain one.
>
> The answer's `confidence` property collapses that shape into a single number from 0 to 1, so you can threshold on it without doing the math yourself. (Noul answers don't carry one.)"
> — https://docs.typesafe.ai/confidence.md

> "`confidence` is a statistic computed from the probability distribution the answer already gives you. TypeSafe computes it for you and returns it on every Choice and Score answer, so the common case needs no extra work on your side."
> — same page

**The exact formula is not published.** The docs say only that it is derived from the distribution and
that a flatter distribution means lower confidence. They also say it is replaceable:

> "**A solid default:** We provide `confidence` as a convenient measure that fits most use-cases, but you are never locked into our definition. Depending on what you are evaluating, a different measure may serve you better, which is exactly why we give you the full `probabilities` in the response. The pros and cons of different computations is a specialized topic that we'll keep to a separate cookbook rather than this page, and will add the link here when we do!"
> — https://docs.typesafe.ai/confidence.md

The v1 migration page notes confidence changed definition between the preview API and v1:
"Confidence | old computation | new computation" (https://docs.typesafe.ai/migrating-to-v1.md).
Thresholds tuned on the preview API do not transfer.

### Worked values

From https://docs.typesafe.ai/primitives/choice.md, one ticket, five Choice questions:

* `department` = `returns`, probabilities `{returns: 0.6, billing: 0.38, shipping: 0.02}`, **confidence 0.39** — "The top option is clear enough to act on, but the second option is not noise."
* `return_reason` = `wrong_size`, probability 1.0, **confidence 1.0**.
* `requested_resolution` = `exchange` at 0.37 with `refund` 0.29 and `replacement` 0.24, **confidence 0.16** — "because of the flat probability distribution... the customer didn't say what they want."
* `tone` = `frustrated` at 0.92, **confidence 0.88**.

From https://docs.typesafe.ai/primitives/score.md, a three-level severity scale: probabilities
`{0: 0.0, 1: 0.7, 2: 0.3}` give `score` 1.3 and **confidence 0.54**; `{0: 0.0, 1: 0.88, 2: 0.12}` give
`score` 1.12 and **confidence 0.81**; an all-on-one-level distribution gives confidence 1.0.

> "In these examples, confidence 1.0 means the returned distribution puts all its probability on one level. This describes the model's answer, not a guarantee that the answer is correct."

## Noul has no confidence

> "Noul | `noul` | The probability that the answer is yes. Near 1 is a strong yes, near 0 a strong no, near 0.5 uncertain. Noul has no separate `confidence`."
> — https://docs.typesafe.ai/primitives.md

> "A value near 1 means a strong yes. A value near 0 means a strong no. A value near 0.5 gives yes and no similar probability."
> — https://docs.typesafe.ai/primitives/noul.md

And the trap the docs call out explicitly: "A Noul value of 0.5 means the model gives yes and no equal
probability. It does not mean the candidate has a medium skill level."
(https://docs.typesafe.ai/primitives.md). To measure a level, use a Score.

## Three bands

> "**High confidence:** Act automatically. The model has a clear read and you can proceed without human involvement.
>
> **Medium confidence:** Proceed with caution. The model has a reasonable answer but is not certain. Depending on context, you might ask the user to confirm, flag for review, or gather more information before acting.
>
> **Low confidence:** Do not act. Route to a human, request clarification, or fall back to a different system. The model is telling you it does not have enough information or the question is not a good fit."
> — https://docs.typesafe.ai/confidence.md

> "If an intelligent system, whether human or machine, cannot express honest uncertainty, the system cannot be trusted."
> — same page

## Thresholds scale with risk

> "A confidence threshold is not one number. Different actions within the same system should be gated at different levels depending on the consequences of getting it wrong."
> — https://docs.typesafe.ai/confidence.md

The worked example puts a 0.5 floor on everything, routes `check_balance` at anything above it, and
requires `> 0.9` before executing `approve_transfer` without asking. "The 0.5 confidence floor catches
anything the model reports as genuinely uncertain. Above that, the threshold for acting without
confirmation is higher for a destructive operation than for a read-only one. Your code encodes the
risk tolerance."

The Confidence-gated routing pattern uses a 0.6 floor and `> 0.85` for the risky action
(https://docs.typesafe.ai/patterns/confidence-routing.md). The build guide's example uses `< 0.8`
to route to human review (https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md).
There is no single blessed number:

> "The correct threshold values depend on your domain and the performance of the model for your use case. Start with conservative thresholds, test with your own data, and adjust as you observe results."
> — https://docs.typesafe.ai/confidence.md

> "Test thresholds by plotting confidence against accuracy on your data."
> — https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md

The agent-skill page adds a caution against over-using confidence: "If all you care about is choosing
the best option, you just need to choose the option with the highest confidence (rather than setting a
confidence threshold). If you have a specific statistical algorithm in mind, you should probably be
using probabilities instead of confidence." (https://docs.typesafe.ai/agent-skill.md)

## Calibration, defined (verbatim from the AI primer)

> "RLCD optimizes for a different output contract:
>
> * The model does not generate text.
> * It returns decisions and probabilities.
> * Higher probability should correspond to a greater chance that the answer is correct.
>
> Calibration makes uncertainty usable by software. Across many predictions from a well-calibrated model:
>
> * Outcomes assigned a probability of `0.2` should occur about 20% of the time.
> * Outcomes assigned a probability of `0.8` should occur about 80% of the time.
> * Outcomes assigned a probability of `1.0` should occur 100% of the time.
>
> These rates describe groups of predictions, not a guarantee about any single answer."
> — https://docs.typesafe.ai/introduction/machine-learning-primer.md

Restated on the System One page: "System One models are trained for calibrated decisions: their
probabilities are optimized against outcomes to reflect uncertainty. Calibration is measured across
groups of predictions; it does not guarantee that an individual answer is correct."
(https://docs.typesafe.ai/concepts/system-one.md)

**TypeSafe publishes no calibration curve, ECE or Brier score.** First-party, calibration is stated
as a training objective and a design property, not as a measured number. Independent measurements do
exist and they disagree by dataset — ECE 0.045 (20 Newsgroups ORDER BY), 0.0505 and 0.0712
(themsquared), 0.121 (decision triage), 0.242 (Amazon ESCI), 0.246 (forced-uncertainty items in the
decision-model benchmark) — collected with their sample sizes and bias notes in
`evidence-independent.md`. Treat the quality of calibration on your own data as something you must
measure yourself.

## Structural invariants are NOT guaranteed

This is the most load-bearing caveat in the corpus. Verbatim from
https://docs.typesafe.ai/model-jaggedness/jev-1.13.md:

> "`jev-1.13` is extremely consistent, meaning you should expect quantitatively similar outputs for semantically similar inputs. However there are many structural invariants one might imagine to hold that simply aren't guaranteed by the model."

**Example 1 — the same question as a Noul and as a yes/no Choice.** Ticket: "I'm not happy with the fit.
What are my options here?"

| Noul `noul` | Choice `yes` | Choice `no` | Choice `confidence` |
| --- | --- | --- | --- |
| 0.22 | 0.01 | 0.99 | 0.97 |

> "The comparable numbers are `noul` and `probabilities["yes"]`, and it is not obvious how to interpret either the Choice output and confidence for the Noul question or vice versa."

**Example 2 — a question and its negation as two Nouls.** Ticket: "I was charged twice for the same
order. Can someone look into this?"

| `refund` | `not_refund` | Sum |
| --- | --- | --- |
| 0.72 | 0.47 | 1.19 |

> "There are many reasons that `P(noul)` and `1 - P(not noul)` may not be directly comparable."

The prescribed response:

> "**Instead:** don't rely on expected structural invariance, and word questions to mean directly what you want. Don't carry a threshold tuned on a Noul over to a Choice, and don't hold the model to arithmetic identities between separate questions. A Choice over options and one Noul per option answer different questions: the Choice is relative, settling *which* option, while each Noul is absolute and can be low for all of them."

Design implications: probabilities within one answer sum to 1 (that is guaranteed by the API contract:
"floats that sum to 1"), but probabilities *across* separate questions obey no identity. Thresholds
are per question type, per question wording, and per model version.

## Self-consistency claims

The build guide lists self-consistency as a design property: "System One is designed to return stable
answers across repeated evaluations."
(https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md). The homepage FAQ distinguishes it
from determinism:

> "Determinism means returning the same result for an identical input. This is less valuable than consistency. We define consistency as making similar decisions when the meaning stays similar, even if the wording changes. Jev is designed for consistency."
> — https://typesafe.ai/

Two official cookbooks measure it. Both ran `jev-latest` on the production API, sampled 2026-09-11,
15 repeats per condition with a fresh throwaway `uid` field on each call.

**Nouls** (14-question rubric on one auto-insurance claim,
https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md):

> "TypeSafe's mean per-question probability standard deviation is `0.0102`, below all LLM probability conditions here. Its `covered` answers span `0.43` to `0.53`, crossing a `0.5` decision threshold."

So: low variance, but *still enough to flip a threshold* when the underlying probability sits near it.

**Choices** (8-question moderation rubric on one borderline post,
https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md):

> "In this run the LLM distribution settings repeat their plurality labels 87.5% to 100% of the time, compared with TypeSafe's 90.8%. TypeSafe has lower mean probability variation than five of the six LLM distribution conditions; Haiku at temperature 0 varies less. Close probabilities still permit routing changes: TypeSafe flips on 2 of the 8 questions."
>
> "For application decisions, we also require a top probability of at least `0.60`; otherwise the result is `uncertain` and goes to human review. TypeSafe's agreement then rises to 99.2%, with automatic labels on 74.2% of answers."

Read honestly: jev is *not* run-to-run identical, it is low-variance; an abstention threshold is what
converts low variance into stable routing, at the cost of sending roughly a quarter of answers to
review in that particular run.

## Correctness is separate from typing

> "Yes. Jev guarantees the shape of its answers, not that every decision is correct. If you provide a list of categories, it can't invent a category outside that list, but it can choose the wrong one."
> — https://typesafe.ai/ (FAQ)

Accuracy is therefore never claimable from these sources alone; see `evals-official.md` for the
accuracy-shaped numbers TypeSafe itself publishes and their stated biases, and
`evidence-independent.md` for the third-party measurements.
