---
id: uc-hr-recruiting-candidate-routing
title: Route an applicant to the role, recruiter, or review path that fits them
verdict: good
domain: hr-recruiting
decision_shapes: [classification, routing]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (recruiting: "Match candidates to roles", "Route candidates to hiring managers or recruiters", "Escalate uncertain cases for human review")
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify first, route to deterministic code, a specialist, or a human; confidence floor)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  ("a Choice works reliably up to roughly 240 options"; answering one level coarser when unsure turned 39/60 right into 48/60 useful)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (thresholds scale with the stakes of the action)
related: [uc-hr-recruiting-resume-composite-scoring, uc-hr-recruiting-relevant-experience-detection, uc-support-intent-routing-handlers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to route candidates?" Also "we have 40 open reqs — which one
does this speculative application fit?", "can jev send applications to the right recruiter?",
and "can jev tell us someone applied to the wrong role?".

## Verdict

**Good**, with the routing understood as *suggesting an additional consideration*, never as
removing one. Matching a candidate to a role from a set of open requisitions is a Choice over
a closed list with confidence, which the docs name directly under recruiting, and it solves a
real and unglamorous problem: strong applicants land on a closed req or a badly titled one and
are never seen by the team that wanted them. It is `good` rather than `strong` because there
is no published run of this shape and because the stakes demand a wide human band — the
confidence-routing pattern's rule that thresholds scale with consequences is doing real work
here.

## What jev decides

State: the resume (experience and projects only) plus a compact list of open requisitions,
each reduced in code to a title and two lines of requirements. Fifteen reqs at 200 characters
is fine; 240 is near the practical Choice ceiling the classification cookbook reports.

```
best_fit_req: Choice
  instructions: {question: "Which open requisition does this candidate's experience best match?",
                 focus: "Match demonstrated experience to the requirements, not the job title
                         they held."}
  criteria: { REQ-1042: "Senior backend engineer — distributed systems, Go, on-call ownership",
              REQ-1077: "Engineering manager — 5-15 reports, platform teams",
              ...,
              none: "No open requisition matches this candidate's experience" }

applied_to_matching_role: Noul
  instructions: "Does the candidate's experience match the requirements of `application.applied_req`?"

seniority_band: Choice
  criteria: {early_career: "...", mid: "...", senior: "...", staff_or_principal: "...",
             manager: "...", director_or_above: "..."}

ic_or_manager_track: Choice
  criteria: {individual_contributor: "...", people_manager: "...",
             both_recently: "...", unclear: "..."}

specialist_review_needed: Noul
  instructions: "Does the background require a specialist reviewer — research, security,
                 hardware, or a regulated profession — to assess fairly?"
```

`none` is mandatory. A Choice is relative and will always name a req, so a speculative
application from a chef will match your backend role at some probability. Routing: act at
`confidence >= 0.7`; between 0.4 and 0.7, follow the classification cookbook's coarser-answer
policy and route to the *function* (engineering, sales) rather than the requisition; below
0.4, or whenever `specialist_review_needed >= 0.5`, route to a human recruiter with no
suggestion attached, so the suggestion cannot anchor them.

## What stays in code

Everything that removes an option. Eligibility, location, work authorisation, req status and
headcount are structured checks; a closed req is filtered out before the call, not judged.
The routing writes a suggestion field and a queue assignment, not a rejection. Audit logging
of what was suggested and what the recruiter did is how you later show the system did not
decide.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 6,000-character resume plus 15
requisition descriptions (~3,000 characters) plus the other four questions (~900 characters)
is ≈ 2,475 tokens, **≈ $0.000104 per application**. Note where the cost sits: the requisition
list, not the resume, so trimming each req to two lines matters more than trimming the CV —
and it helps accuracy too, since irrelevant detail is failure mode 5. Latency 70–500 ms. The
only published calibration evidence of this shape is the classification-with-confidence
cookbook's 75-option run: 27/30 correct above `confidence >= 0.9` and 12/30 below it, with
the coarser-answer policy lifting 39/60 to 48/60 useful answers (`jev-1.12`, 2026-08-12).
That is the argument for the band, not a number to expect on your reqs.

## When the verdict flips

- The routing suppresses an application from the req the candidate chose. It must only ever
  add a destination.
- More than ~240 open reqs in one call. Shortlist in code first — by function, level and
  location — then let jev choose among the survivors.
- The suggestion is shown to the reviewer before they read the CV. Anchoring is a real cost in
  hiring; show it after, or only in the low-stakes band.
- Reqs are described so vaguely that two options overlap. A Choice forced between
  indistinguishable options produces unstable labels; fix the descriptions, add `not_for`.

## Alternatives considered

- **Candidate self-selection.** Free and already there; it fails on speculative applications
  and on badly titled reqs, which is the whole target population.
- **Keyword matching CV to job description.** Rewards vocabulary mirroring and misses career
  changers, the candidates this is most useful for.
- **Embedding similarity between CV and req.** Cheap and reasonable as a shortlister; no
  `none` option, no per-candidate probability, and similarity to a job advert is not fit.
- **Frontier LLM.** Better on unusual backgrounds, seconds and cents per application, and its
  rationale is unverified prose about a person that will end up in a discovery request.
- **Small LLM.** Roughly an order of magnitude more cost and latency per call, with a
  free-text answer that can name a req that does not exist.
- **Recruiter triage of every application.** The baseline, and the destination for everything
  below the band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `patterns/intent-routing.md`,
`patterns/confidence-routing.md`, `cookbooks/classification_using_confidence.md`
(240-option guidance, 27/30 and 12/30, 39/60 -> 48/60; `jev-1.12`, 2026-08-12),
`model-jaggedness/jev-1.13.md`, `models.md`.
