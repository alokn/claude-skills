---
id: uc-sdlc-deferral-detection-in-review-text
title: Detect that a review comment or plan defers the work instead of doing it
verdict: good
domain: sdlc
decision_shapes: [detection, classification]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/bestdan/workflow-skills/pull/757  (deferral detection "94% vs 33% for the existing lexical scanner on 18 sentences")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sdlc-semantic-lint-team-conventions, uc-sdlc-duplicate-review-comment-detection, uc-agents-harness-premature-completion-check, uc-sdlc-pr-description-explains-why]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to spot deferred work in review comments?" Also: "our TODO
scanner misses 'we can handle that later' — can jev read the paraphrase?", "can we flag a
plan that punts the hard part?", "how do we stop 'out of scope for now' disappearing into
the merge?".

## Verdict

**Good.** A merged internal assessment measured exactly this decision and reported "94% vs
33% for the existing lexical scanner on 18 sentences" — that is 17 of 18 against 6 of 18, on
a set small enough that the percentage is decoration and the comparison is the point. It is
`good` rather than `strong` because n=18 is not a measurement of your corpus; it is `good`
rather than `conditional` because the incumbent is a keyword list that *structurally* cannot
see a paraphrase, and the failure mode is a flag on a comment — cheap, visible, reversible.

## What jev decides

One sentence or one comment per call. State is `{"text": comment, "context": pr_title}` and
nothing more: a whole thread in the state is jaggedness mode 5 and the question stops being
about this sentence.

```
defers_work: Noul
  instructions: {question: "Does this text postpone work rather than do it or decide against
                            it?",
                 focus: "Postponement, not incompleteness. A short answer is not a deferral."}
  true:  "The author names something that should happen and moves it out of this change: a
          follow-up, a later ticket, 'for now', 'out of scope', 'we can revisit', an inline
          TODO, or an accepted gap with no owner."
  false: "The author decided *not* to do it and said why; the author did it; the author asked
          a question; or the text describes work someone else already owns with a reference."
deferral_has_a_home: Noul
  instructions: "Does the text point at a ticket, an issue number, or a named owner for the
                 deferred work?"
```

The second question carries the value. An explicit deferral with a ticket is good engineering;
the one to surface is `defers_work` true and `deferral_has_a_home` false. Below the confidence
floor, do nothing — the lexical scanner's existing behaviour is unchanged.

## What stays in code

Splitting the thread into sentences or comments, and the per-unit loop. The existing
`TODO|FIXME|XXX` regex, which stays and short-circuits — it is exact and free on the cases it
covers. Resolving whether a referenced ticket actually exists and is open (a lookup, not a
judgement). Counting deferrals, comparing counts across PRs, and any threshold arithmetic —
mode 2. Posting, deduplicating and suppressing the comment.

## Numbers

Measured, verbatim: "94% vs 33% for the existing lexical scanner on 18 sentences"
(github.com/bestdan/workflow-skills/pull/757). Read it as 17/18 vs 6/18 on one author's
18-sentence set; no precision, recall or false-positive rate is published, and the same PR
records that jev confidence swung 0.16-0.48 between runs on the same item elsewhere in the
assessment, so treat a single borderline probability as noise.

Cost by method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
400-character comment plus two questions with criteria (~1,400 characters) is about 450
tokens, **≈ $0.000019 per comment**. Latency from the models page: "70 to 500 ms". Your own
labelled set is easy to build: every "follow-up" issue your team filed after a merge, matched
back to the comment that promised it.

## When the verdict flips

- **You gate a merge on it.** False positives on decisions-not-to-do-it would block
  legitimate work; keep it advisory.
- **Your team already writes disciplined `TODO(owner, TICKET-123)` comments.** The regex is
  right and jev adds a network call.
- **You send the whole thread or the whole diff.** Mode 5; the question degrades into "is
  anything deferred anywhere".
- **Non-English review comments** without a per-language check of your own.

## Alternatives considered

- **Keyword/lexical scanner.** The incumbent, free and exact; measured at 33% against jev's
  94% on the same 18 sentences precisely because paraphrase is invisible to it. Keep it as
  the first pass.
- **Embeddings against a set of deferral exemplars.** Cheap and catches paraphrase, but has
  no way to express the `false` criterion ("decided against it, and said why") that does the
  real separating work here.
- **Frontier LLM.** Better at explaining *what* was deferred and drafting the follow-up
  ticket; seconds and cents per comment on a high-volume stream.
- **Fine-tuned classifier.** Viable once you have a few hundred labelled comments from the
  shadow log — and you will have them.
- **A human reading the thread.** The current control, and the one this feeds rather than
  replaces.

## Sources

- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
