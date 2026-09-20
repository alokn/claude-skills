---
id: uc-sdlc-duplicate-review-comment-detection
title: Suppress a review-bot comment that repeats one already on the pull request
verdict: good
domain: sdlc
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/bestdan/workflow-skills/pull/757  (redundancy detection in PR review comments, "7 of 8 on real cases")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sdlc-deferral-detection-in-review-text, uc-sdlc-semantic-lint-team-conventions, uc-verification-contradiction-between-records, uc-sdlc-reviewer-and-label-routing]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to stop our review bot repeating itself?" Also: "two linters
flagged the same line in different words — can we post once?", "can jev tell a duplicate
comment from a related one?", "our bot re-comments on every push and people muted it".

## Verdict

**Good.** The decision is a bounded pairwise semantic equality question, the input is two
short texts, and the cost of being wrong is small in both directions. A merged internal
assessment reported "7 of 8 on real cases" — eight real pull-request cases, seven judged
correctly. That is eight cases, not a rate, so this is `good` on mechanism and honesty about
the incumbent (string equality, which cannot see a paraphrase), not on a measured accuracy.

Closest failure mode: **literal reading** — two comments can make the same point in different
words, which is precisely why string equality fails; the question is scoped to one pair of
short texts with criteria for what counts as the same finding.

## What jev decides

One call per (candidate comment, existing comment) pair, and code decides which pairs exist.

```
says_the_same_thing: Noul
  instructions: {question: "Do these two review comments raise the same issue about the same
                            code?",
                 focus: "The issue raised, not the wording or the tone."}
  true:  "Both ask for the same change to the same thing, even in different words, at
          different levels of detail, or from different tools."
  false: "They touch the same lines but ask for different changes; or one is a question and
          the other an instruction; or one is a superset that adds a materially different
          request."
adds_new_information: Noul
  instructions: "Does `candidate_comment` contain a fact, reference or consequence that
                 `existing_comment` does not?"
```

Suppress only when `says_the_same_thing` is high **and** `adds_new_information` is low. The
second question is the guard against silencing the better-worded version of a point.

## What stays in code

**The comparison set.** This is the load-bearing engineering decision: code restricts the
candidates to comments on the same file and the same hunk (and, optionally, an exact-text
match check that short-circuits for free). Compare against every comment on a large PR and
the pair count is O(n^2) calls for a decision worth fractions of a cent each — a 60-comment
PR becomes 60 calls per new comment. Scoping to the hunk keeps it at a handful. Also in code:
resolved/outdated comment filtering, the author filter (do not dedupe a human against a bot),
the posting itself, and any count or rate limit — mode 2.

## Numbers

Measured, verbatim: "7 of 8 on real cases"
(github.com/bestdan/workflow-skills/pull/757). No precision, recall or per-run variance is
published for this specific check; the same assessment records confidence swinging 0.16-0.48
between runs on the same item on a different task, which is an argument for a conservative
threshold rather than a tight one.

Cost by method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Two
comments of ~400 characters each plus two questions with criteria (~1,300 characters) is about
525 tokens, **≈ $0.000022 per pair**. Latency from the models page: "70 to 500 ms"; the pairs
are independent and parallelise.

Set the threshold to favour **posting**. A duplicate comment is mildly annoying; a suppressed
comment that was actually a different point is a bug that reaches production silently and
leaves no trace that anything was dropped. Log every suppression with both texts so the
false-suppression rate is measurable at all.

## When the verdict flips

- **You compare against every comment on the PR.** Cost and latency scale quadratically;
  scope to the hunk or this is `weak`.
- **Your bot's comments are templated.** Then exact or normalised string equality already
  wins, for free.
- **Suppression is silent and unlogged.** Then you cannot measure the only failure that
  matters, and the verdict is `conditional` at best.
- **The comments are long structured reports** rather than single points. Mode 5, and "the
  same issue" stops being a well-formed question.

## Alternatives considered

- **Exact / normalised string match.** Free and exact; the incumbent, and it should run first.
  Blind to two tools saying the same thing differently, which is the whole problem.
- **Embeddings + cosine threshold.** Cheap and catches paraphrase; cannot express the `false`
  criterion that separates "same lines, different request" from "same request", and the
  threshold needs the same fitting work.
- **Rule: one comment per tool per line.** Deterministic and often good enough; fails when two
  different tools own the same rule.
- **Frontier LLM.** Can merge the two comments into one better comment, which jev cannot do at
  all (generation, mode 9). Use it for the merge, jev for the detection.
- **Let the humans skim.** The status quo, and the reason the bot got muted.

## Sources

- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
