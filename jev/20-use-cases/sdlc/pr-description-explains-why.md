---
id: uc-sdlc-pr-description-explains-why
title: Check in CI whether a pull request description explains why the change was made
verdict: good
domain: sdlc
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting: "Define checks for your team's coding conventions and writing guidelines. Run these checks in CI and flag violations for review.")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (decompose one broad judgement into atomic Nouls; criteria as true/false objects with examples)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1 literal reading; failure mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 32k state limit)
  - https://github.com/devagrawal09/jev-code  (advisory PR/diff reports: "There is no 'pass' result"; exact checks run first)
related: [uc-sdlc-pr-title-matches-diff, uc-sdlc-semantic-lint-team-conventions, uc-sdlc-pr-risk-tier-review-routing, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check that a PR description explains why the change was
made?" Also: "can we lint PR descriptions semantically in CI?", "our template has a Why
section everyone leaves empty — can a model tell?", "can jev enforce contribution
guidelines without a human reading every PR?".

## Verdict

**Good.** All seven fit-test questions pass and TypeSafe's use-case map lists semantic code
linting — "define checks for your team's coding conventions and writing guidelines, run
these checks in CI and flag violations for review" — as a category, but no official worked
example covers this check, so `good` not `strong`. The judgement is one semantic read of a
short text you already have and the output is one probability per check. **Advisory first,
gate later:** post it as a review comment or non-blocking check run for at least one release
cycle before it can fail a build.

## What jev decides

State: `{pr: {title, body}, diff_summary: [<changed paths, +/- counts, top-level symbols>]}`.
Send the *summary* of the diff, not the diff. The full patch is the classic way to walk into
failure mode 5 (large state full of irrelevant detail), and this question does not need it.

```
explains_why: Noul
  instructions: {question: "Does `pr.body` state why the change is being made?",
                 inspect: "`pr.body`",
                 focus: "Look for the motivation: the bug, the request, the constraint, or the
                         decision that made this change necessary. Restating what the code now
                         does is not a reason."}
  criteria:
    true:  {what: "Names a cause, problem, ticket, or decision that motivated the change",
            examples: ["Legacy-plan customers were double charged on renewal (#4211)"]}
    false: {what: "Describes only what changed, or is empty, or is a bare checklist",
            not_for: "A short but real reason",
            examples: ["Refactor the billing service", "See title", "- [x] tests added"]}

describes_testing:  Noul  "Does `pr.body` say how the change was verified?"
mentions_rollback:  Noul  "Does `pr.body` describe how to undo or disable the change?"
```

Fan the companion checks out in the same call; they share the state and add little latency ("barely changes" in the docs, not zero).
Bands: `noul >= 0.7` pass silently; `0.3-0.7` post an advisory comment quoting the missing
half; `< 0.3` post the same comment with a stronger wording. Nothing blocks.

The `false` criteria matter more than the `true` ones here. Failure mode 1 (literal reading)
is the one this design must dodge: without "restating what the code now does is not a
reason", a body reading "This PR refactors the billing service" scores high on a question
about "why", because a literal reader accepts a purpose clause.

## What stays in code

"Does the body link an issue?" is a trap: issue ids match a regex (`#\d+`, `PROJ-\d+`), so
the regex is the authority and a Noul would be waste. One public field report names this
exact trap — "a judgment model measured against labels that a regex could produce gives you
a confident, meaningless number" (github.com/wotai-dev/typesafe-jev-tools). Also in code:
skipping bots, reverts and PRs under N changed lines; building the diff summary; posting the
comment; the check-run status. `jev-code` states the same ordering — "exact checks run
first" — and returns no "pass" verdict at all, only findings.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free
(models.md). A 1,200-character body plus a 600-character diff summary plus three questions
with criteria (~1,200 characters) is about 750 tokens, so **≈ $0.000032 per pull request**.
Latency 70-500 ms, "most queries about 100 ms"; one public harness report observed "70 to
300 milliseconds for $0.042 per million input tokens" (empryo.com/blog/jev-and-the-harness).
No accuracy figure is published for this check. Labelled data for calibration: your own
merged PRs — label a few hundred past descriptions, or take the reviewer comments that asked
"why are we doing this?" as the positive class for the failing case, and plot `noul` against
that label before choosing a threshold.

## When the verdict flips

- You **block** merges on day one: a gate with no low-confidence path, and the team learns to
  type a sentence that scores well.
- Descriptions are bot-generated from the diff; every PR then fails identically.
- Three people who review everything within the hour: the saving is negligible.
- Non-English descriptions at scale, without your own evaluation.

## Alternatives considered

- **Regex / length threshold.** What most repos do ("body must exceed 50 characters"). Free,
  and trivially defeated; it measures typing, not reasoning. Keep it as the pre-filter.
- **Frontier LLM.** Better at explaining *what* is missing; seconds and cents per PR. Good
  hybrid: jev decides, an LLM writes the comment only when jev says fail.
- **Small LLM (Haiku-class).** Closest competitor. One public 150-row head-to-head put jev
  and Claude Haiku 4.5 at the same accuracy (66.0% each), jev at 455 ms p50 against 631 ms,
  and jev unsure on 34.7% of rows against 2.7% (github.com/wotai-dev/typesafe-jev-tools,
  2026-09-18). That gap is a coverage trade-off, not extra safety: abstention is a
  developer-defined threshold policy that any model returning probabilities or logprobs can
  implement, and on accuracy the two tied.
- **Fine-tuned classifier.** Thousands of labels for a check you will reword next quarter.
- **Embeddings.** No meaningful notion of "explains why" in cosine space.
- **Human review.** Stays; this saves the reviewer a round trip, it does not replace them.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `concepts/how-to-build-with-system-one.md`,
`model-jaggedness/jev-1.13.md` (modes 1 and 5), `models.md`. Field reports:
https://github.com/devagrawal09/jev-code, https://github.com/wotai-dev/typesafe-jev-tools
(150-passage head-to-head, 2026-09-18), https://empryo.com/blog/jev-and-the-harness.
