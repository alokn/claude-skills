---
id: uc-insurance-fnol-classification
title: Classify a first-notice-of-loss report by peril and line of business
verdict: good
domain: insurance
decision_shapes: [classification, routing, detection]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (insurance claims: "Classify first-notice-of-loss reports, adjuster notes, and supporting documents")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (contrastive Choice criteria with `what` / `not_for` / `examples`; decompose broad judgements)
  - https://docs.typesafe.ai/patterns/fan-out.md  (ride-along speculative questions cost tokens, not latency)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (Choice "works reliably up to roughly 240 options"; coarser answer when confidence is low)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-insurance-claim-complexity-and-missing-info, uc-insurance-straight-through-vs-adjuster-routing, uc-insurance-rubric-claim-triage-uncertain-band, cb-classification_using_confidence, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify FNOL reports?" Also asked as "can jev pick the
peril code from the loss description?", "should the claims intake bot set line of business
automatically?", and "can we drop the keyword table that maps first notice text to a claim
type?".

## Verdict

**Good.** TypeSafe's use-case map names this task directly — "Classify first-notice-of-loss
reports, adjuster notes, and supporting documents" — and the shape is the canonical one: a
short free-text narrative read once into a small closed set of peril codes, with code
owning the assignment and a confidence value giving you the human path you already have in
a claims intake queue. There is no published worked example or accuracy figure for FNOL
specifically, so this is `official-docs`, not `official-cookbook`, and you must measure
agreement against your own historic peril codes before you let it write the field.

## What jev decides

State: only the narrative and the few policy fields the options depend on. Not the whole
policy document, not the claimant's history — failure mode 5 (large state full of
irrelevant detail) is the one this design walks into first, because a claims record is
enormous and almost none of it decides the peril.

```
peril: Choice
  instructions: {question: "Which peril does `fnol.description` describe?",
                 focus: "Classify the cause of the loss, not its severity or cost."}
  criteria:
    collision:      {what: "Impact between the insured vehicle and another vehicle or object",
                     not_for: "Damage found later with no described impact event",
                     examples: ["Rear-ended at a junction", "Hit a bollard reversing"]}
    theft:          {what: "The vehicle or its contents were taken without permission",
                     not_for: "Damage caused during an attempted break-in with nothing taken",
                     examples: ["Car gone from the driveway overnight"]}
    fire:           {what: "Fire or smoke damage from any ignition source", not_for: "Heat damage with no fire described"}
    water_or_flood: {what: "Ingress of water, storm surge, burst pipe, or flooding"}
    weather_other:  {what: "Hail, wind, lightning, or falling-tree damage", not_for: "Flooding, which is `water_or_flood`"}
    glass_only:     {what: "Damage confined to glazing", not_for: "Glass broken as part of a larger impact"}
    vandalism:      {what: "Deliberate damage by a third party with no theft described"}
    liability_only: {what: "The insured caused damage or injury to a third party and no own damage is described"}
    other:          {what: "A cause none of the above describes"}
```

`other` is mandatory. A Choice is relative and will always name something, so without it an
unusual loss lands in the nearest peril at high confidence (failure mode 8: the Choice
settles *which*, never *whether any*).

Ride the rest of the intake decision along in the same call, since extra questions cost
tokens and little extra latency: `injury_reported` (Noul), `third_party_involved` (Noul),
`vehicle_drivable` (Noul, auto only), `police_or_emergency_attended` (Noul).

Bands: `confidence >= 0.85` write the peril code and continue; `0.6-0.85` write it as a
suggestion the intake handler confirms; `< 0.6` leave the field null and queue for a human.
The classification-with-confidence cookbook offers a better middle option than abstention —
answer one level coarser. Report `motor_damage` rather than `collision` vs `glass_only`
when the leaf is uncertain, and let the adjuster narrow it.

## What stays in code

Line of business, if it is derivable from the policy record, is a lookup and must not be a
model call. Coverage eligibility, deductible application, per-incident limits, reporting
windows and every date comparison (failure modes 2 and 3) stay in code — the date
extraction cookbook's rewrite applies if a date must come out of prose: jev picks the
components as a Choice over enumerated parts, code assembles and compares. Reserve setting,
peril-to-handler mapping, regulatory notifications and all writes are code.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free (`models.md`). A 1,200-character narrative plus ~300 characters of policy
context, the nine-option Choice with contrastive criteria (~2,200 characters) and four
ride-along Nouls (~700 characters) is about 4,400 / 4 ≈ 1,100 tokens, so **≈ $0.000046 per
FNOL**. For scale, the quickstart reports 312 input tokens for a 120-character ticket with
three questions. Latency 70-500 ms, "most queries about 100 ms"; the choice-consistency
cookbook measured a mean 114 ms round trip for an eight-Choice call on 2026-09-11. Accuracy
on peril codes: not published. Volume: your intake rate — do not multiply until you have
counted it.

## When the verdict flips

- The claimant already picks the peril in the FNOL form. Then the field is lexical and the
  model adds nothing; keep the form value.
- More than ~240 peril codes. The classification-with-confidence cookbook states a Choice
  "works reliably up to roughly 240 options" against a hard cap of 255; a deeper code set
  needs hierarchical classification, which changes the shape of the entry.
- The narrative arrives as a scanned form or a call recording with no transcript. Jev is
  text only; the verdict is `no` until something upstream produces text.
- Non-English intake at volume, without your own evaluation.

## Alternatives considered

- **Regex / keyword table.** Free and exact, but encodes vocabulary rather than cause, and
  the list grows with every new phrasing. Wins where the trigger is a literal code.
- **Small LLM (Haiku-class).** Closest competitor; the consistency cookbooks measured
  `claude-haiku-4-5` at 1,780 ms and $0.001798 per 14-question rubric call against 111 ms
  and $0.000043 for jev on the same rubric. Accuracy on your perils: measure it.
- **Frontier LLM.** Seconds and cents per claim, plus parse failures; the reasons to switch
  are schema safety, latency and calibration, not accuracy.
- **Fine-tuned classifier.** Better with tens of thousands of coded claims and a frozen
  peril set; worse the moment a peril is added, because jev needs only an edited string.
- **Embeddings + centroid.** Threshold tuning without semantics of "cause of loss".
- **Human intake.** Stays, for the low-confidence band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (FNOL classification named),
`concepts/how-to-build-with-system-one.md` (contrastive criteria; decomposition),
`patterns/fan-out.md`, `cookbooks/classification_using_confidence.md` (240-option guidance;
coarser answer when unsure, jev-1.12, 2026-08-12), `cookbooks/consistency_noul_cookbook.md`
(111 ms, $0.000043, 2026-09-11), `models.md` (price, latency, limits).
