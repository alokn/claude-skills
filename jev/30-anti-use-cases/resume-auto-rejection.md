---
id: au-resume-auto-rejection
title: Do not auto-reject job applicants on a jev decision
verdict: no
domain: hr
decision_shapes: [classification, scoring, routing]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration ... does not guarantee that an individual answer is correct")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure modes 1 and 5; no explanations)
  - https://github.com/RINNECODER/jev-behavior-study  (option-position effect 95/108 vs 62/108)
  - https://evals.typesafe.ai  (67.8% combined workflow accuracy)
related: [au-exact-grade-prediction-high-stakes, au-legal-determinations-without-counsel, au-payments-and-access-control-decision, uc-hr-recruiting-relevant-experience-detection, uc-hr-recruiting-resume-composite-scoring]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to let jev sift the application pile and reject the bottom automatically?" Also "auto-
close candidates scoring below 0.4", "screen out applicants who don't meet the criteria", "we get 3,000
CVs a week, can jev cut it to 300 without a human?".

## Verdict

**No** for the rejection. Screening and ordering are legitimate jev work — see
`uc-hr-recruiting-relevant-experience-detection` — but the adverse action is not. Three reasons stack.
Calibration is a group property: "Calibration is measured across groups of predictions; it does not
guarantee that an individual answer is correct", and a rejection is consumed by one person. There is no
explanation: System One models "do not ... generate explanations of their reasoning", so you cannot tell
a candidate, a regulator or a tribunal why. And the model is sensitive to things that have nothing to do
with merit — option position moved correctness from 95/108 to 62/108 in an 11,621-request study, which in
a screening context means CV formatting and ordering can move outcomes.

## What jev would get wrong

The unusual candidate, silently and at scale. Career breaks, non-standard job titles, overseas employers,
a skill described in different words, a CV whose layout puts the relevant experience last — each is a case
where a literal reader ("`jev-1.13` answers the question you wrote, not the one you meant") drops someone
a recruiter would have kept. Unlike a human screener's mistakes, these correlate: the same blind spot
applies to every applicant who shares the pattern, which is precisely the shape that turns an efficiency
project into a discrimination claim. A large state full of irrelevant CV detail makes it worse
(failure mode 5).

## What stays in code

The reject, and the record. Code applies only the objective, documented disqualifiers a human wrote —
right to work, required licence, a hard location constraint — each a deterministic
check on a structured field, not a judgement over prose. Jev's outputs are advisory features: per-criterion
Nouls ("does the CV evidence commercial experience with `skill`?"), a rank order for the reviewer's queue,
and a completeness flag. Store the questions, the version, the probabilities and the reviewer's decision
for every candidate, keep the low-confidence band in the human queue, and audit outcome rates by group —
the corpus rule is that jev may reorder work, never remove a person from it.

## Numbers

No published source measures jev on CV screening. TypeSafe's own workflow evals report 67.8% combined
accuracy against Opus 5's 73.1% (https://evals.typesafe.ai, read 2026-09-19); an independent head-to-head
found 66.0% accuracy with 34.7% abstention over 149 rows
(https://github.com/wotai-dev/typesafe-jev-tools, 2026-09-18). Roughly a third wrong is the planning
number for an unattended reject. Cost is not the constraint: a 1,200-token CV with ten criterion questions
is about 2,000 input tokens, roughly $0.00008 at $0.042 per million input tokens with output free
(https://docs.typesafe.ai/models.md). Multiply by your own pile size; this entry supplies no
volume.

## When the verdict flips

It flips to **conditional** for *ordering and surfacing*: rank the pile, flag missing mandatory documents,
route by role, and put the uncertain band in front of a person — with every candidate still reaching a
human before any rejection is sent. It does not flip for the adverse action itself at any confidence
threshold, and in jurisdictions with automated-decision rules (EU AI Act high-risk employment uses, NYC
Local Law 144 bias audits, GDPR Article 22) the legal requirement is independent of the accuracy number.
**No rewrite exists** for unattended rejection.

## Alternatives considered

- **Regex / deterministic**: the right tool for hard eligibility rules, and auditable.
- **Small LLM**: same problems; a below-threshold "unsure" route needs logprobs, which not every
  small model exposes.
- **Frontier LLM**: more nuance per CV, same legal exposure, far higher cost at pile scale.
- **Fine-tuned classifier**: trained on historic decisions, it learns historic bias.
- **Embeddings**: fine for finding similar CVs, not for deciding on one.
- **Human**: makes the decision. Jev exists here to make the human's queue shorter and better ordered.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://github.com/RINNECODER/jev-behavior-study — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
