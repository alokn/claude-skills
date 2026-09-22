---
id: uc-hr-recruiting-resume-composite-scoring
title: Score a resume against job criteria as independent weighted dimensions
verdict: good
domain: hr-recruiting
decision_shapes: [scoring, ranking]
primitives: [score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (resume screening as the worked example: `python_depth`, `team_leadership`, `system_design`, `generalist`, each a 5-level Score, normalised by /4 and combined with role-specific weights in code)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (recruiting: "Evaluate resumes, applications, and interview feedback against explicit, job-related criteria"; "Score evidence for required competencies")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: score levels are weak in numerical calibration; failure mode 3: dates and durations belong in code)
  - https://docs.typesafe.ai/primitives/score.md  (2 to 10 ordered level descriptions)
related: [uc-hr-recruiting-relevant-experience-detection, uc-hr-recruiting-candidate-routing, uc-sales-marketing-icp-fit-scoring]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score resumes?" Also "can jev rank applicants for a role?",
"can we stop keyword-filtering CVs?", and "can jev give us a fit score per candidate?".

## Verdict

**Good** as a decomposed, weighted, human-reviewed ranking; **never** as a rejection
gate — the shape is demonstrated by the composite-scoring pattern page; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
TypeSafe publishes resume screening as the worked example of the composite-scoring
pattern — four independent competency Scores, normalised and combined with role-specific
weights in code — and the reason it publishes it is the property that matters for
hiring: the composite is inspectable. You can see that a candidate ranked low because
the leadership weight is 0.40 for the EM profile, and you can change that weight without
re-running inference. A single "how good is this candidate" question would hide all of
it. The legal and ethical frame is not optional: in most jurisdictions an automated
rejection needs a human decision-maker, and the fit test's counter-signal on decisions
with no review path applies squarely.

## What jev decides

State: the resume text, plus the requirements section of the job description if any level
references it. Strip contact details, names, addresses, photographs and education dates in
code before the call — partly for bias reasons, partly because they are pure distractors
(failure mode 5).

```
python_depth: Score
  instructions: "How much depth of python experience does this candidate have, based on the
                 supplied resume?"
  criteria: ["No Python experience mentioned",
             "Mentioned but no detail",
             "Used in projects, some specifics",
             "Primary language, multiple projects",
             "Deep expertise: architecture, performance, libraries"]

team_leadership: Score
  criteria: ["No management experience mentioned",
             "Informal mentorship or tech lead role",
             "Led a small team or project",
             "Managed a team with direct reports",
             "Managed multiple teams or an engineering org"]

system_design: Score
  criteria: ["No architecture work mentioned",
             "Contributed to design discussions",
             "Designed components of a larger system",
             "Owned architecture of a significant system",
             "Designed systems at scale across multiple domains"]

domain_experience: Score
  criteria: ["No experience in the domain named in `job.requirements`", ... ]

evidence_quality: Score
  criteria: ["Claims with no supporting detail",
             "Responsibilities listed without outcomes",
             "Concrete projects with scope and outcomes stated"]
```

Every level describes a situation a reader can check against the text. "Somewhat experienced"
is not a level. Composition in code, as published:
`ic_score = 0.40*py + 0.10*lead + 0.40*arch + 0.10*general`, with a different weight vector
for the manager profile — same inference, two rankings.

## What stays in code

The shortlist, and every fact. Years of experience, employment gaps, graduation dates and
notice periods are date arithmetic (failure mode 3) and must be computed, not judged. Hard
eligibility — work authorisation, a required licence, location — is a deterministic filter
that runs before the call. Weights, thresholds, the number of candidates advanced, and the
record that a human made the decision all live in code.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 6,000-character resume plus
five Scores with five levels each (~2,000 characters) is ≈ 2,000 tokens, **≈ $0.000084 per
candidate**; a 500-applicant req is about **$0.042** of inference for the whole funnel. Adding
a sixth competency costs tokens and little extra latency ("barely changes" in the docs, not
zero) — the parallel-questions cookbook measured 13
questions in one call at 12.2x cheaper and 10.0x faster than sequentially, with identical
means on 11 of 13. Latency 70–500 ms, so a recruiter can re-weight and re-rank interactively
if the scores are cached. **No accuracy or validity figure is published for resume scoring,
and none should be inferred**: the meaningful measurement is agreement with your own
reviewers on a blind sample, plus an adverse-impact analysis across protected groups, which
you must run yourself.

- Field evidence (community-report): a CV screening tool scores candidates against an editable plain-text hiring policy rather than hard-coded rules, so the criteria can be changed by the hiring manager without a deploy; no accuracy published, 2026-09. Source: https://github.com/gtaras7/typesafe-jev

## When the verdict flips

- The score auto-rejects. Then it is a sole gate on a life-affecting decision and the verdict
  is **no**, regardless of how good the scores are.
- You interpolate. The jaggedness page states score levels are "weak in numerical calibration";
  use them to rank and to threshold, not to report "3.7 out of 5".
- The criteria are proxies rather than job requirements (school prestige, employer brand,
  continuous employment). Then the rubric encodes bias and the tool makes it faster.
- Resumes are non-English or in unusual formats. English is strongest; PDFs must be text
  already, since jev takes no images.
- You ask one question: "is this candidate a good fit?". Several judgements in one number,
  and nothing to audit when a candidate asks why.

## Alternatives considered

- **Keyword and boolean CV search.** The incumbent in most ATS products, and the reason good
  candidates are missed: it matches vocabulary, not evidence of doing the thing.
- **Frontier LLM per resume.** Comparable judgement with a written rationale, at seconds and
  cents each, and the rationale is a liability as well as an asset — it is unverified prose
  about a person.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' measurements. Stability is not the differentiator: in the choices
  cookbook `claude-haiku-4-5` at temperature 0 was the more repeatable condition (100.0% against
  jev's 90.8% raw, SD 0.0012 against 0.0098). For a ranking candidates may contest, measure
  run-to-run variation on your own rubric for whichever model you pick.
- **Trained ranking model on past hires.** Learns who you hired before, including whom you
  passed over; the best-documented way to automate historical bias.
- **Embedding similarity to the job description.** Rewards mirroring the job advert's
  vocabulary; candidates have noticed.
- **Human screening of everything.** The status quo, and what the ranking reorders rather
  than replaces.

## Sources

Accessed 2026-09-19. `patterns/composite-scoring.md` (the four Scores and weight vectors
verbatim), `concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` (modes 2, 3, 5),
`primitives/score.md`, `cookbooks/parallel_questions.md` (12.2x / 10.0x), `models.md`.
