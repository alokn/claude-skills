---
id: uc-hr-recruiting-application-completeness
title: Check an application for missing information before it reaches a reviewer
verdict: good
domain: hr-recruiting
decision_shapes: [detection, verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (recruiting: "Evaluate resumes, applications ... against explicit, job-related criteria"; scientific discovery: "Flag missing methodological details"; insurance: "Detect ... missing information")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (atomic questions; structured state with backticked paths)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 3: dates; failure mode 9: extraction is not generation)
  - https://docs.typesafe.ai/patterns/fan-out.md  (all checks in one call; latency "barely changes" as checks are added)
related: [uc-hr-recruiting-relevant-experience-detection, uc-hr-recruiting-candidate-routing, uc-support-response-quality-check]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check applications are complete?" Also "can jev tell the
candidate what is missing before they submit?", "can we stop recruiters chasing portfolio
links?", and "can jev spot a CV with no dates on it?".

## Verdict

**Good**, and unusually low-risk for this domain, because the only action it takes is asking
the candidate for more information — an error costs a mild inconvenience, not an opportunity.
Completeness is a set of independent yes/no questions about whether a named thing is present
in a document, which is the most literal application of the Noul primitive there is, and the
docs name "flag missing details" as a shape in two other industries. It is `good` rather than
`strong` only because no cookbook runs it. The discipline: every check must be phrased as
"does the document state X", never "extract X", and anything a form field already captures is
not a question at all.

## What jev decides

State: the resume text and the free-text application answers, as structured fields so each
question can name its target.

```
states_employment_dates: Noul
  instructions: "Does `resume` give start and end dates for the listed roles?"
  criteria:
    true:  {what: "Each role carries at least a month or year range"}
    false: {what: "Roles are listed with no dates, or dates for only some roles"}

portfolio_link_present: Noul
  instructions: "Does `application` include a link to work samples, a portfolio, or a code
                 repository?"

answers_addressed_question: Noul
  instructions: "Does `application.motivation_answer` respond to the question asked in
                 `application.motivation_prompt`?"
  criteria:
    false: {not_for: "A short but responsive answer",
            what: "Generic text that would fit any employer, or an answer to a different question"}

role_descriptions_state_scope: Noul
  instructions: "Do the role entries in `resume` say what the candidate did, as opposed to
                 listing only job titles and employers?"

required_certification_mentioned: Noul
  instructions: "Does `resume` mention a certification named in `job.required_certifications`?"

biggest_gap: Choice
  instructions: "Which single missing item would most help a reviewer assess this application?"
  criteria: {dates: "...", scope_of_work: "...", work_samples: "...",
             certification: "...", motivation_answer: "...", nothing_missing: "..."}
```

The Choice exists so the prompt back to the candidate asks for one thing rather than five —
a completion-rate decision, not a modelling one. Bands: send the nudge only when the relevant
Noul is confidently low and `biggest_gap.confidence >= 0.6`; otherwise say nothing. A wrong
nudge is cheap but not free, and telling a candidate their dates are missing when they are not
reads as carelessness.

## What stays in code

Everything structured, and the message. Form fields, file attachments, required checkboxes,
and the presence of a URL are validated deterministically — a regex finds a link far more
reliably than a question about one, and `portfolio_link_present` above is worth asking only
where the link may be inside the CV text rather than a form field. Employment-gap detection
is date arithmetic on parsed dates (failure mode 3), not a judgement. The nudge copy is a
template with the gap name substituted; writing it per candidate is generation and is not
jev's job.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 6,000-character resume plus
short application answers plus these six questions (~1,400 characters) is ≈ 2,000 tokens,
**≈ $0.000084 per application**, and one call covers every check — the parallel-questions
cookbook measured 13 questions in a single request at 12.2x cheaper and 10.0x faster than 13
requests, with identical means on 11 of 13. Latency 70–500 ms, which is inside the budget for
an in-form check as the candidate reviews their submission, the placement where it actually
lifts completion. No accuracy figure is published for completeness checks. Measure the two
numbers that matter to the business instead: the change in applications a recruiter marks
"insufficient information", and the drop-off rate on the nudge itself.

## When the verdict flips

- The item is a structured field. Validate it; a question adds latency and a failure mode.
- The check rejects rather than nudges. Then a false positive costs an application, and the
  verdict for that design is **no**.
- You ask it to extract what is missing as free text. Generation (failure mode 9); use the
  bounded `biggest_gap` Choice.
- Applications arrive as scanned PDFs. Text only — if OCR is poor, you will flag documents as
  incomplete because your pipeline could not read them, which is the worst outcome here.
- Applications are multilingual; the "answers the question" check is the most language-sensitive
  of these and needs per-locale validation.

## Alternatives considered

- **Required form fields.** The right first answer for anything you can put in a field, and
  free. Every field you add costs completion, which is why some information stays in the CV.
- **Regex over the CV text (dates, URLs, emails).** Exact and cheap; keep it for the patterns
  it can see, and note it cannot tell a portfolio link from a company website.
- **Frontier LLM.** Can both detect and write the tailored nudge; seconds and cents per
  application, for a check that should run on every draft.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures.
- **Recruiter chasing by email.** The current cost being removed — and the slowest possible
  feedback loop, arriving days after the candidate has moved on.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`,
`concepts/how-to-build-with-system-one.md`, `model-jaggedness/jev-1.13.md` (modes 3 and 9),
`patterns/fan-out.md`, `cookbooks/parallel_questions.md` (12.2x / 10.0x), `models.md`.
