---
id: uc-risk-forecasting-incident-report-risk-indicators
title: Turn incident report narratives into probabilistic risk indicators and a severity score
verdict: good
domain: risk-forecasting
decision_shapes: [detection, scoring, feature-extraction]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (risk assessment: "Convert incident reports, claims notes, transaction descriptions, and vendor assessments into probabilistic risk indicators"; "Score severity and prioritize review")
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (atomic scores combined with weights owned by code)
  - https://docs.typesafe.ai/patterns/fan-out.md  (every question in one request; parallel evaluation makes latency "barely change")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score": do not interpolate a magnitude between levels; failure modes 2, 3, 5)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-risk-forecasting-vendor-assessment-scoring, uc-risk-forecasting-demand-signal-feature-extraction, uc-legal-compliance-policy-violation-detection, df-fit-test, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to score incident reports for risk?" Also asked as "can jev
turn our free-text incident narratives into indicators an underwriter can sort on?", "can
jev assign a severity to a safety report?", and "can jev give us a risk number per
incident?".

## Verdict

**Good.** The use-case map names this shape directly — convert incident reports into
probabilistic risk indicators, score severity, prioritise review — and the mechanism is
clear: several atomic Nouls for the presence of individual risk factors plus one or two
Scores on ordered rubrics, all in one call, combined with weights that live in your code.
It is *good* rather than *strong* because there is no published cookbook measuring it on
incident data, so it ships in shadow mode against whatever your reviewers decided last year.
The one design rule that is not optional: the composite number is computed in code from the
individual answers, and the Score expectation is used to threshold and rank, never to
reconstruct a magnitude.

## What jev decides

State: the narrative, the incident type as recorded, and the location or asset class if your
rubric depends on them. Not the whole claim file, not the attachments index, not the
adjuster's correspondence thread — failure mode 5 is the standing risk on any record with a
long history.

```
severity: Score
  instructions: {question: "How severe is the outcome described in `incident.narrative`?",
                 inspect: "`incident.narrative`",
                 focus: "Judge the outcome that occurred, not the outcome that could have occurred."}
  criteria: ["No injury and no property damage described",
             "Minor property damage or first-aid-only injury",
             "Significant property damage, or an injury requiring medical treatment",
             "Injury requiring hospitalisation, or damage disabling the asset",
             "Fatality, or total loss of the asset"]

near_miss_potential: Score
  instructions: "How severe could the outcome plausibly have been, given what the narrative
                 describes?"
  criteria: [ ... four levels, same ladder framed as potential ... ]

# One Noul per risk factor — multi-label, so never a Choice
third_party_involved:        Noul("Does `incident.narrative` describe a person or property
                                   not belonging to the insured being affected?")
procedure_not_followed:      Noul("Does the narrative state that a required procedure,
                                   permit, or safety step was skipped?")
equipment_failure_cited:     Noul("Does the narrative attribute the incident to equipment
                                   that failed or malfunctioned?")
recurrence_indicated:        Noul("Does the narrative say this has happened before at this
                                   site or with this asset?")
litigation_language_present: Noul("Does the narrative mention a lawyer, a claim threat, or
                                   a regulator?")
information_missing:         Noul("Is the narrative missing the date, location, or what was
                                   damaged?")
```

Combination in code, following the composite-scoring pattern — normalise each Score to 0–1
by dividing by `levels − 1`, weight, add the Nouls as flags:

```python
sev  = answers["severity"].score / 4
pot  = answers["near_miss_potential"].score / 3
risk = 0.5 * sev + 0.2 * pot + 0.15 * answers["procedure_not_followed"].noul \
                             + 0.15 * answers["litigation_language_present"].noul
```

Bands: `information_missing ≥ 0.6` returns the report to the submitter before anything else
happens. `severity.confidence < 0.6` routes to a human regardless of the composite. Above
that, the composite orders the review queue; it does not decide reserves.

## What stays in code

The weights, and therefore the risk appetite — the point of composite scoring is that you
tune the weights without re-running inference. Every number in the narrative: costs,
headcounts, days lost, distances. Extract candidates with a regex, have jev select the right
one, then do all arithmetic in code (failure modes 2 and 3). Reserve setting, reporting
obligations and their statutory clocks. Site and asset lookups. The queue write.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
2,500-character narrative plus two Scores with level descriptions and six Nouls
(~3,000 characters of questions) is about (2,500 + 3,000) / 4 ≈ 1,375 tokens, so
**≈ $0.00006 per incident**. Adding the sixth, seventh and eighth Noul costs tokens and no
latency, per the fan-out pattern. Latency 70–500 ms, "most queries about 100 ms".

Accuracy and agreement on incident data: not published. The closest published measurement of
this *shape* is the consistency-noul cookbook, which ran a 14-question rubric over one
insurance claim 15 times and reported "TypeSafe's mean per-question probability standard
deviation is `0.0102`", a mean round trip of 111 ms and $0.000043 per call, sampled
2026-09-11 (https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md). That is
stability, not correctness — the same cookbook notes its `covered` answers "span `0.43` to
`0.53`, crossing a `0.5` decision threshold". Measure your own agreement against closed
incidents where the eventual cost or outcome is known.

## When the verdict flips

- The risk score must be an actuarial quantity. Then jev supplies features and a model
  computes the number; see the demand-signal entry for that pattern. A Score expectation is
  not a magnitude.
- The indicators are already structured fields on the form. Then it is a lookup, and the
  narrative adds nothing.
- The score drives an automatic pricing or declination decision. Then it is an input to an
  underwriter, not a decision.
- Reports arrive as scanned forms or photos. Text only; OCR first and expect noise.

## Alternatives considered

- **Keyword lists over the narrative.** What most incident systems do today: brittle, no
  confidence, and a maintenance backlog. Jev's case rests on that, not on accuracy.
- **Small LLM (Haiku-class).** Same answers achievable at seconds and cents; the consistency
  cookbook measured `claude-haiku-4-5` at 1,485–1,780 ms per 14-question rubric call against
  111 ms for jev, with less stable probabilities at default temperature.
- **Frontier LLM.** Better at the causal narrative an investigator wants written; that is
  generation, and it is a different job from producing indicators.
- **Fine-tuned severity classifier.** Strong if you have tens of thousands of closed
  incidents with outcome labels — and if you do, jev's probabilities are better used as
  *features* for it than as a replacement.
- **Embeddings + clustering.** Finds families of similar incidents; does not produce a
  per-risk-factor probability to threshold on.
- **Human reviewer.** Stays, and owns the top of the ordered queue. The measurable claim is
  ordering quality, which you test by replaying closed incidents.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (risk assessment entries),
`patterns/composite-scoring.md` (atomic scores, weights in code, normalisation by level
count), `patterns/fan-out.md`, `model-jaggedness/jev-1.13.md` ("Math using score"; modes 2,
3, 5), `cookbooks/consistency_noul_cookbook.md` (0.0102 mean per-question std dev, 111 ms,
$0.000043, sampled 2026-09-11), `models.md` (price, latency).
