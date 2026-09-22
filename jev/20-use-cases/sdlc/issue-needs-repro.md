---
id: uc-sdlc-issue-needs-repro
title: Detect whether a bug report contains enough information to reproduce it
verdict: good
domain: sdlc
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/fan-out.md  ("has_reproducible_steps" as a Noul riding along with the category Choice in one call)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (atomic decomposition; NoulCriteria true/false with `not_for` and examples)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 1 literal reading: state the exact condition, boundary cases in criteria)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-sdlc-issue-triage-bot, uc-sdlc-pr-description-explains-why, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether an issue has reproduction steps?" Also: "can we
auto-ask for a repro before a maintainer reads it?", "can a model tell a real bug report from
'it doesn't work'?", "can this run as the author types?".

## Verdict

**Good.** `has_reproducible_steps` is literally one of the Nouls in TypeSafe's own fan-out
example, and the judgement is about the text in front of the model with no indirection. The
low-confidence path is free — say nothing — and the action (a polite comment asking for more
detail) is reversible and cheap. `good` rather than `strong` because the docs show the question
in a support-ticket context, not measured on issue reports. **Advisory first, gate later:**
comment, never close, never require. Running it in the issue form as the author types is the
highest-value placement, because the fix costs the author thirty seconds instead of a round
trip.

## What jev decides

Do not ask "is this a good bug report" — that hides several judgements in one answer. Ask one
Noul per missing element, which is also what tells the comment what to request:

```
has_repro_steps: Noul
  instructions: {question: "Does `issue.body` describe a sequence of actions someone else could
                            follow to see the problem?",
                 inspect: "`issue.body`"}
  criteria:
    true:  {what: "Gives concrete actions, inputs, or a command, in an order that can be followed",
            examples: ["Run `app export --to /tmp` on an empty project, then open the file"]}
    false: {what: "Describes only the symptom, the context, or the author's conclusion",
            not_for: "Steps that are terse but followable",
            examples: ["Export is broken", "It crashes on startup sometimes"]}

has_expected_vs_actual: Noul
  instructions: "Does `issue.body` state both what the author expected to happen and what
                 happened instead?"
has_environment:   Noul  "Does `issue.body` state the operating system, browser, or runtime it ran on?"
has_error_output:  Noul  "Does `issue.body` include an error message, stack trace, or log excerpt?"
is_intermittent:   Noul  "Does `issue.body` say the problem happens only sometimes?"
```

All five in one call. Failure mode 1 is the risk here: without the `not_for` clause, a terse
but perfectly followable one-liner ("run `app export` in an empty dir") reads as "not steps"
to a literal reader looking for a numbered list.

Bands: post the request only when the *sum* of missing elements crosses a bar code owns — for
example, comment when `has_repro_steps < 0.3` and `has_error_output < 0.3`. One missing
element is normal; three is a report nobody can act on. Do not ask jev to count them (failure
mode 2); sum the Nouls in code, which is the remedy the jaggedness page itself prescribes.

## What stays in code

Detecting fenced code blocks, attached files, screenshots, and log uploads — those are
structural facts a parser gets right every time, and a Noul about them is the lexical trap.
Template field completion. Whether the author is a maintainer (skip). Rate limiting so the bot
comments once. Applying and removing the `needs-repro` label, and the stale-bot timer, which
is date arithmetic and belongs nowhere near the model.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,500-character body plus five Nouls with criteria (~1,600 characters) is about 780 tokens,
**≈ $0.000033 per issue**. Inline in a form, latency 70-500 ms fits a debounced keystroke
budget; `df-cost-model` recommends budgeting 300-600 ms end to end for inline UI, with a
deterministic fallback on timeout. Accuracy: not published. Labelled data for calibration:
issues a maintainer actually closed as `needs-more-info`, or where the first maintainer comment
asked for a reproduction — both are already in your tracker and both are a clean positive
class.

## When the verdict flips

- You use it to **block** issue creation. Reporters leave; you lose the bug.
- The template already has a required "Steps to reproduce" textarea and your form enforces it.
  Then the field is present by construction and only its *quality* is in question, which is a
  narrower and harder judgement — keep it advisory and expect lower agreement.
- Support conversations rather than bug reports, where the reproduction is a phone call.
- Issues written mostly in languages other than English, without your own evaluation.

## Alternatives considered

- **Length and code-block heuristics.** Free, and roughly right: a 20-character issue has no
  repro. Run them first and only call jev on what survives.
- **Required template fields.** The best fix, because it changes the input rather than judging
  it. This entry exists for the issues that bypass the template.
- **Frontier LLM.** Writes a much better request comment, naming exactly what is missing; use
  it downstream of jev's decision rather than for the decision.
- **Small LLM.** Comparable at roughly 1.4x-3.7x the latency in the public head-to-head; the
  gap that matters for an inline check is latency, and jev was the fastest model in that field
  at 455 ms p50 (github.com/wotai-dev/typesafe-jev-tools, 2026-09-18).
- **Fine-tuned classifier.** Plausible on a large tracker; five separate Nouls would become
  five models, and re-wording a criterion becomes a retrain.
- **Embeddings.** No; "contains followable steps" has no cosine analogue.
- **Maintainer reading the issue.** The incumbent, and the beneficiary.

## Sources

Accessed 2026-09-19. `patterns/fan-out.md` (`has_reproducible_steps`),
`concepts/how-to-build-with-system-one.md`, `model-jaggedness/jev-1.13.md` (modes 1 and 2),
`models.md`. Field report: https://github.com/wotai-dev/typesafe-jev-tools (455 ms p50, the
fastest in a 16-model field, 2026-09-18).
