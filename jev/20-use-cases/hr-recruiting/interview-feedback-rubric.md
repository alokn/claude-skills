---
id: uc-hr-recruiting-interview-feedback-rubric
title: Score interview feedback for evidence quality against a hiring rubric
verdict: good
domain: hr-recruiting
decision_shapes: [scoring, verification]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (recruiting: "Evaluate resumes, applications, and interview feedback against explicit, job-related criteria")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (independent dimensions, weights owned by code)
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (does the supplied context support the claim; confidence flags for review)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: do not reconstruct a magnitude by interpolating between score levels)
related: [uc-hr-recruiting-resume-composite-scoring, uc-support-response-quality-check, uc-hr-recruiting-application-completeness]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to evaluate interview feedback?" Also "can jev tell us which
scorecards are evidence-free?", "can we check interviewers are assessing the competency they
were assigned?", and "can jev flag feedback that is really about culture fit?".

## Verdict

**Good**, aimed at the *feedback*, not the candidate. Asking jev to decide whether to hire
someone from a scorecard is a decision with no acceptable low-confidence path; asking whether
a scorecard actually contains evidence for the rating it gives is a verification task of
exactly the published shape — does the supplied text support the claim — and it is the
highest-leverage thing you can automate in an interview process. Most hiring debt is written
feedback that says "strong candidate, good communicator" and cannot be audited six months
later. Running this as an advisory nudge to the interviewer before they submit is where the
value is; running it as a report on interviewers is where the trust goes.

## What jev decides

State: the scorecard text, the competency the interviewer was assigned, and the rating they
gave. Not the candidate's resume — that is a different question and a distractor here.

```
evidence_for_rating: Score
  instructions: {question: "How much specific evidence from the interview does `feedback.text`
                            give for the rating in `feedback.rating`?",
                 focus: "Look for what the candidate said or did, not the interviewer's
                         conclusion about them."}
  criteria: ["Only conclusions and adjectives, no observed behaviour",
             "One general example, no detail",
             "At least one specific thing the candidate said or did, with context",
             "Several specific observations, including what was probed and how the candidate
              responded"]

assesses_assigned_competency: Noul
  instructions: "Does `feedback.text` assess the competency named in `feedback.competency`?"

rating_consistent_with_text: Noul
  instructions: "Is the rating in `feedback.rating` consistent with what `feedback.text` describes?"
  criteria:
    true:  {what: "The written assessment and the rating point the same way"}
    false: {what: "The text describes concerns while the rating is positive, or the reverse"}

non_job_related_criterion: Noul
  instructions: "Does `feedback.text` base its assessment on something not related to job
                 performance — background, accent, school, personal similarity, or 'fit'
                 without a defined behaviour?"

actionable_for_next_round: Noul
  instructions: "Does `feedback.text` name something the next interviewer should probe further?"
```

Bands: below `evidence_for_rating` level 2 with high confidence, show the interviewer a
prompt before submission asking for one concrete example. `rating_consistent_with_text` below
0.4 or `non_job_related_criterion` above 0.5 flags the scorecard for the hiring manager's
attention — flagged, not blocked, and never as an accusation.

## What stays in code

The hiring decision, entirely. Also the rubric definition, the aggregation across
interviewers, and the debrief workflow. Do not average the Score across a panel and present
a number: the jaggedness page states score levels are weak in numerical calibration and must
not be interpolated, so report the count of scorecards below the evidence threshold instead.
Who can see the flags, and whether they reach a performance review, is a policy question that
should be settled before the first call is made.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 1,500-character scorecard plus
these five questions with criteria (~1,600 characters) is ≈ 775 tokens, **≈ $0.000033 per
scorecard** — negligible against the hour of interviewer time it is checking. Latency
70–500 ms, fast enough to run as the interviewer clicks submit, which is the only placement
where the feedback can still be improved. The closest published shape is the citation-check
cookbook (does the supplied context support the claim, with confidence flagging for review);
it publishes no accuracy metric for this task. **Nothing is published on interview-feedback
scoring.** Validate against scorecards your hiring leads have already graded, and report
agreement per dimension, not overall.

## When the verdict flips

- The output influences the hire/no-hire decision directly. That is a decision about a person
  with no acceptable automated band; keep it advisory about the writing only.
- Interviewers are measured on the scores. They will write to the rubric, the evidence signal
  will saturate within a quarter, and you will have lost the metric and some goodwill.
- Feedback is a rating with a one-line comment. There is nothing to read; fix the form first.
- You send the resume as well and ask about the candidate. Different question, multi-hop
  (failure mode 4), and it imports the anchoring you were trying to remove.
- Feedback is in several languages across regions. Validate per language.

## Alternatives considered

- **Required-field validation and minimum character counts.** Deterministic, free, and
  trivially satisfied by padding; keep them as the floor.
- **Structured scorecards with behavioural anchors.** The real fix, and orthogonal — this
  checks whether the anchors were actually used.
- **Frontier LLM review of each scorecard.** Can also suggest the missing probe; seconds and
  cents per scorecard, and a rewrite is generation, which is jev's hard boundary. Combine:
  jev flags, an LLM drafts the nudge.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures. Do not add a stability claim: in the choices cookbook
  `claude-haiku-4-5` at temperature 0 was the more repeatable condition (100.0% against jev's
  90.8% raw, SD 0.0012 against 0.0098). Measure it on your own scorecards.
- **Hiring manager reading every scorecard.** What they already do, too late to change it.
- **Calibration sessions.** Effective and expensive; this tells you which interviewers to
  invite.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/composite-scoring.md`,
`cookbooks/citation_check.md`, `model-jaggedness/jev-1.13.md` (score-magnitude warning,
mode 4), `models.md`.
