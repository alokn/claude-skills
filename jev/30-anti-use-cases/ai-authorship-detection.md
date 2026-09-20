---
id: au-ai-authorship-detection
title: Do not use jev to decide whether a text was written by AI
verdict: no
domain: media-content
decision_shapes: [detection, classification]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds  (37 documents x 21 questions = 777 judgments in under 0.7 s for about $0.0025; 4 writing checks over 12 passages, jev caught 6 of 7 planted defects, Fable 5.1 caught 7; the miss was an "unexplained action", repeated across three attempts)
  - https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/  (339 hard-benign security documents: many dimensions flag 37.2% vs a single direct question 1.5%)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 8, overconfidence on out-of-distribution input)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-media-content-ai-writing-slop-detection, au-decisions-that-need-an-explanation, au-resume-auto-rejection, au-review-loop-pass-fail-gate]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect AI-generated writing?" Also: "can we add an
`is_ai_generated` Noul?", "can jev tell us which submissions were written by a model?", "can
it reject drafts that read as machine-written?".

## Verdict

**No.** Authorship is a fact about how a text was produced, and none of that evidence is in
the text you send. What jev can read is *style* — and the inference from style to authorship
is exactly the step that has no ground truth, no published measurement for jev, and a
catastrophic asymmetry when it is wrong: a false positive accuses a person of not writing
their own work. There is no rationale field to appeal against
(`au-decisions-that-need-an-explanation`). Detecting *prose defects* — unexplained actions,
hedging without content, claims without sources — and letting an editor draw their own
conclusion is a different proposal with its own verdict:
`uc-media-content-ai-writing-slop-detection` (`conditional`, advisory only).

## What jev would get wrong

The unusual human. Failure mode 8 is overconfidence on out-of-distribution input, and an
idiosyncratic but good writer, a non-native speaker, or a house style built on short
declarative sentences all look, stylistically, like the thing the question is hunting. The
model will return a well-formed probability anyway; the type guarantee says well-formed, not
right.

The question also invites decomposition, which makes it worse rather than better. The most
detailed independent experiment in this corpus found that asking many dimensions instead of
one direct question raised false positives from **1.5% to 37.2%** on **339 hard-benign
documents** (agentjournal.dev). Twenty-one style questions rolled into an authorship verdict
is that shape, with the error landing on a person rather than on a document.

And there is no labelled set to fix it with: you cannot collect reliable ground truth for
"was this written by a model" at the scale you would need, which is why the defect framing
exists.

## What stays in code

Chunking into paragraphs, word and sentence counts, readability formulas, repeated-phrase
detection and n-gram overlap against a banned-phrase list — exact, free, and not to be spent
on a question (`au-count-items-in-text`). Also: the decision. Who is contacted, whether a
submission is held, and the record of which flags an editor dismissed, which is the only
calibration set this workflow will ever have.

## Numbers

**No source measures jev on authorship detection.** The available field report measures
throughput and defect-catching, not authorship: 37 documents × 21 questions = 777 judgments
in under 0.7 s for about $0.0025, and 4 writing checks over 12 passages where jev caught 6 of
7 **planted** defects against Fable 5.1's 7, missing an "unexplained action" across three
attempts (every.to, Mike Taylor and Dan Shipper, 2026-09-15). The defects were planted by the
author, the judgement of a catch is the author's, n is 12 passages, and this corpus's
source-reliability table rates that report's bias risk **high**. Cost by method:
`chars/4 × $0.042/1e6` — about **$0.000028 per paragraph**. The unit cost is not the risk.

## When the verdict flips

It flips to **conditional** when the output is a set of concrete, observable prose defects,
shown to a human editor beside the passage, with no `is_ai_generated` question anywhere in
the state and no automatic consequence —
`uc-media-content-ai-writing-slop-detection`. It flips back to **no** the moment a flag
blocks publication, fails a contributor, or is reported to anyone as evidence of authorship.

## Alternatives considered

- **Perplexity-based AI detectors.** Purpose-built and widely reported as unreliable on edited
  text; they also cannot be told what your publication considers a defect.
- **Banned-phrase and n-gram lists.** Free, exact, instantly gameable, useful for the crudest tells.
- **Frontier LLM.** Better at explaining a problem to a writer, and no better placed to know who
  typed it.
- **A style linter (vale, proselint).** Deterministic and reviewable; the right tool for rules
  you can state as patterns.
- **A human editor.** The ground truth and the destination. Provenance questions are answered by
  process — drafts, commit history, a conversation — not by a classifier.

## Sources

- https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds
  — accessed 2026-09-20
- https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — accessed 2026-09-20
  (37.2% vs 1.5% false positives on 339 hard-benign documents)
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
