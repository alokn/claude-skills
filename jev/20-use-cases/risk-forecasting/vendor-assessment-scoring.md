---
id: uc-risk-forecasting-vendor-assessment-scoring
title: Score vendor questionnaire free text on independent risk dimensions and combine in code
verdict: good
domain: risk-forecasting
decision_shapes: [scoring, ranking, detection]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (resume screening: four independent Scores normalised to 0-1 and combined with weights in code; two different weightings over the same answers)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (risk assessment: "Convert incident reports, claims notes, transaction descriptions, and vendor assessments into probabilistic risk indicators")
  - https://docs.typesafe.ai/primitives/score.md  (ordered rubric, 2 to 10 levels; probability-weighted expectation, confidence)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score"; failure mode 1 literal reading; failure mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-risk-forecasting-incident-report-risk-indicators, uc-risk-forecasting-demand-signal-feature-extraction, uc-legal-compliance-regulatory-requirement-verification, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score vendor risk assessments?" Also asked as "can jev read
the free-text answers in our third-party security questionnaire and rate them?", "can jev
rank suppliers for review?", and "can we stop having an analyst read every SIG response
end to end?".

## Verdict

**Good.** A vendor questionnaire is a set of free-text answers, each of which a reviewer
judges against an ordered expectation — which is the Score primitive, and the
composite-scoring pattern is the published recipe for combining several of them. TypeSafe's
worked example is resume screening: four independent Scores, each normalised to 0–1, each
weighted in code, with two different weightings computed over the same model answers. Swap
the dimensions and it is vendor assessment. It is *good* rather than *strong* because the
published example is resumes, not vendors, and because the whole design depends on your
rubric levels describing concrete situations rather than adjectives.

## What jev decides

State: one questionnaire section at a time — the question asked, the vendor's free-text
answer, and any evidence text they pasted. Not the whole 300-question response; the
dimensions are judged per section, and a 60-page SIG response in one state is the textbook
context-rot case (failure mode 5).

```
access_control_maturity: Score
  instructions: {question: "How mature are the access controls `vendor.answer` describes?",
                 inspect: "`vendor.answer`",
                 focus: "Judge only what the answer states. Absence of a control is the
                         lowest level, not a middle level."}
  criteria: ["No access control described, or the answer does not address the question",
             "Shared or role-less accounts; access granted informally",
             "Named accounts with role-based access; joiner-mover-leaver process described",
             "Role-based access plus MFA on all administrative paths and periodic recertification",
             "All of the above plus least-privilege enforcement and evidenced quarterly review"]

incident_response_maturity: Score   # 5 levels, same style
subprocessor_transparency:  Score   # 4 levels
evidence_quality:           Score
  criteria: ["Assertion only, no evidence referenced",
             "Policy document referenced but not attached",
             "Policy attached",
             "Independent attestation (SOC 2, ISO 27001) referenced with a date and scope"]

answer_is_evasive:   Noul("Does `vendor.answer` avoid answering the question that was asked?")
answer_is_copied:    Noul("Does `vendor.answer` restate the question rather than describe a
                           practice?")
mentions_exception:  Noul("Does the answer describe an exception, carve-out, or
                           not-yet-implemented plan?")
```

Combination in code, exactly as in the pattern — normalise each Score by `levels − 1`, then
apply a weighting per vendor tier:

```python
ac   = answers["access_control_maturity"].score / 4
ir   = answers["incident_response_maturity"].score / 4
sub  = answers["subprocessor_transparency"].score / 3
evid = answers["evidence_quality"].score / 3

critical_vendor = 0.35*ac + 0.30*ir + 0.15*sub + 0.20*evid
low_risk_vendor = 0.25*ac + 0.20*ir + 0.10*sub + 0.45*evid
```

The pattern's stated benefit applies directly: "If the highest ranking candidates are not
matching your expectations, you can adjust the weights" — no re-inference.

Bands: `evidence_quality.score` at the bottom level, or `answer_is_evasive ≥ 0.7`, sends the
section back to the vendor rather than to a reviewer. `confidence < 0.6` on any dimension
puts the section in the analyst's queue with the probability distribution shown. The
composite orders the review queue and never, by itself, approves a vendor.

## What stays in code

The weights and the tiering that selects them. The pass/fail gates that are contractual —
"no SOC 2, no onboarding" is a rule, not a judgement. Certificate expiry dates and
attestation scope periods: date arithmetic, so extract the parts as a Choice over enumerated
components and compare in code. Mapping sections to dimensions. The approval workflow and
every write. Storage of `{per-dimension score, probabilities, confidence, model version}` so
that a re-assessment next year is a comparison rather than a re-read.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,500-character section plus four Scores with full level descriptions and three Nouls
(~4,000 characters of questions) is about (1,500 + 4,000) / 4 ≈ 1,375 tokens, so
**≈ $0.00006 per section**. A questionnaire with 40 free-text sections is therefore about
$0.0023 per vendor, one pass. Latency 70–500 ms per section, parallelisable; "most queries
about 100 ms".

The closest published latency and cost measurement for a multi-Score, multi-Choice call is
the choice-consistency cookbook: an eight-question rubric at a mean 114 ms round trip and
$0.000046 per call, with a mean probability standard deviation of 0.0098 across 15 repeats,
sampled 2026-09-11 (https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md).
Agreement with your analysts' ratings: not published. Your last two years of completed
assessments are the labelled set.

## When the verdict flips

- The questionnaire is entirely multiple-choice. Then the scoring is arithmetic over
  structured fields and code owns it; there is no text to read.
- The dimensions cannot be written as concrete levels. If your rubric is "rate maturity 1–10"
  with no description per level, the Score will be unstable and the jaggedness page's warning
  about interpolating between levels applies; write 4–6 described levels per dimension instead.
- The composite decides onboarding automatically. It is an input; keep the approval with a
  person and the contractual gates in code.
- Vendors respond in multiple languages without a per-language evaluation.

## Alternatives considered

- **Manual analyst review of every section.** The incumbent. Accurate, slow, and inconsistent
  between analysts — the thing a composite score fixes is comparability across vendors, not
  ceiling accuracy.
- **Keyword scoring ("mentions MFA": +1).** Trivially gamed by a vendor who writes the word.
- **Small LLM (Haiku-class).** Can produce levels; seconds per section. The choice-consistency
  cookbook measured `claude-haiku-4-5` at 3,853 ms and $0.003498 per eight-question rubric call
  at temperature 0, against 114 ms and $0.000046 — a cost and latency argument, not a stability
  one. In that same run Haiku at temperature 0 was the *more* repeatable condition (100.0%
  against jev's 90.8% raw, mean probability SD 0.0012 against 0.0098), so do not claim rating
  drift makes year-over-year comparison unreliable without measuring it on your own rubric.
- **Frontier LLM.** Right for writing the risk memo and for the interaction effects between
  findings. Reserve it for the vendors the composite flags.
- **Fine-tuned scorer.** Needs thousands of rated sections; rubrics change with every
  framework revision.
- **Embeddings.** Can match an answer to previously-rated similar answers, which is a useful
  prior, but it cannot read a new control description against a new rubric level.

## Sources

Accessed 2026-09-19. `patterns/composite-scoring.md` (four Scores, normalisation, two
weightings, tuning without re-inference), `concepts/use-case-map.md` (vendor assessments as
risk indicators), `primitives/score.md` (2–10 levels; expectation and confidence),
`model-jaggedness/jev-1.13.md` ("Math using score"; modes 1, 3, 5),
`cookbooks/consistency_choice_cookbook.md` (114 ms, $0.000046, 0.0098 mean prob std dev,
Haiku comparison, sampled 2026-09-11), `models.md` (price, latency).
