---
id: uc-hr-recruiting-relevant-experience-detection
title: Detect whether a resume evidences a specific required experience
verdict: good
domain: hr-recruiting
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (recruiting: "Identify relevant experience"; "Score evidence for required competencies")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (atomic questions over one broad one; "Broad questions hide several judgments behind one answer")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 2: counting; failure mode 3: durations and dates in code; failure mode 1: literal reading)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (13 questions in one call: 12.2x cheaper, 10.0x faster, same answers)
related: [uc-hr-recruiting-resume-composite-scoring, uc-hr-recruiting-application-completeness, uc-hr-recruiting-candidate-routing]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether a candidate has a specific experience?" Also
"does this CV show they have actually shipped a mobile app?", "can jev do our must-have
checklist?", and "can we replace the boolean search string?".

## Verdict

**Good.** One requirement, one Noul, over one resume is the most atomic form this domain
offers, and it is also the most defensible: each answer maps to a written requirement a
recruiter can check by reading the CV. It is `good` rather than `strong` because no cookbook
runs it, and because two requirements in three are secretly compound — "5+ years of
production Kubernetes" bundles a duration (arithmetic), a technology (semantic) and a
qualifier ("production", semantic). Split them, keep the duration in code, and the semantic
residue is a clean fit. Literal reading (failure mode 1) is the live risk: the model answers
the question you wrote, so "has experience with X" will come back true for "attended a
workshop on X" unless the criteria say otherwise.

## What jev decides

State: the resume text, filtered to the experience and projects sections. One Noul per
requirement, all in one call.

```
req_shipped_mobile_app: Noul
  instructions: {question: "Does the resume show the candidate personally built and released a
                            mobile application to an app store?",
                 inspect: "`resume.experience`",
                 focus: "Require evidence of building and releasing, not proximity to a team
                         that did."}
  criteria:
    true:  {what: "States they built, led, or released a named mobile app",
            examples: ["Shipped the iOS client, 200k installs"]}
    false: {what: "No such evidence",
            not_for: "Worked at a company that has a mobile app; took a course in Swift;
                      listed iOS as a skill with no project"}

req_managed_direct_reports: Noul
  instructions: "Does the resume state the candidate had people reporting directly to them?"
  criteria:
    false: {not_for: "Tech lead, mentor, or project lead with no stated reports"}

req_regulated_industry: Noul
  instructions: "Does the resume show work in an industry named in `job.regulated_domains`?"

req_customer_facing: Noul
  instructions: "Does the resume show the candidate worked directly with external customers?"

evidence_is_first_person: Noul
  instructions: "Does the resume attribute the described work to the candidate rather than to
                 their team or employer?"
```

That last question is the one that pays for itself: CVs are written in the plural, and "we
migrated 400 services" is the sentence that makes every other answer ambiguous. Bands: Noul
answers are probabilities, not confidences — act above your tuned threshold, treat the middle
as "recruiter should check this one", and never carry a threshold from a Noul to a Choice
(failure mode 8).

## What stays in code

Durations, counts and eligibility. "At least five years" is `sum(end - start)` over parsed
employment dates; the jaggedness page is explicit that dates are read as text and that
counting is unreliable, and both errors here are the ones a candidate would notice. Work
authorisation, licences and location are structured filters. The requirement list itself is
configuration, and the decision to advance or reject is a human's.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 6,000-character resume plus
eight requirement Nouls with criteria (~2,400 characters) is ≈ 2,100 tokens, **≈ $0.000088 per
candidate** for the whole checklist in one call. The batching is the point: the
parallel-questions cookbook measured 13 questions in one request at 12.2x cheaper and 10.0x
faster than 13 requests, with means identical on 11 of 13 questions and within 0.01 on the
other two. Latency 70–500 ms. No published accuracy for experience detection. Validate by
having two recruiters answer the same checklist on 100 CVs and reporting agreement between
each of them and the model — inter-rater agreement between the humans is the ceiling, and it
is usually lower than people expect.

## When the verdict flips

- The requirement is a duration, a count, a date or a certification number. Compute or look it
  up; asking is failure modes 2 and 3.
- The answers gate rejection automatically. Advisory only; a false negative here ends someone's
  application over a phrasing choice.
- Requirements are written as the job advert wrote them, compound and vague. Rewrite them as
  atomic, checkable statements first — if you cannot, the question is not ready (fit-test
  question 4).
- Candidates learn the checklist and write to it. Resumes are already adversarial in this
  mild sense; criteria that demand evidence rather than keywords are the mitigation, and
  failure mode 6 says do not expect the model to police it alone.

## Alternatives considered

- **Boolean / keyword search in the ATS.** Exact, free, and matches the word rather than the
  experience; it is why "Kubernetes" in a skills list outranks a CV describing the migration.
- **Frontier LLM with the checklist in a prompt.** Same answers plus a rationale, at seconds
  and cents per CV and with a real chance of a confident invented citation from the resume.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures, and less stable across repeats.
- **Skills-taxonomy extraction products.** Map CVs to a standard skills ontology; excellent
  for search, and they answer "mentions X", not "did X".
- **Structured application questions.** The cheapest fix available: ask the candidate
  directly. Use jev for the CVs you receive without them.
- **Recruiter reading.** The decision-maker; this orders their reading queue.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`,
`concepts/how-to-build-with-system-one.md` (decomposition guidance),
`model-jaggedness/jev-1.13.md` (modes 1, 2, 3, 6, 8), `cookbooks/parallel_questions.md`
(12.2x / 10.0x), `models.md`.
