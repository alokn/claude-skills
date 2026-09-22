---
id: uc-insurance-claim-complexity-and-missing-info
title: Score claim complexity and detect which required details a claim is missing
verdict: good
domain: insurance
decision_shapes: [scoring, detection, verification]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (insurance claims: "Detect claim complexity, missing information, and potential fraud indicators")
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (14-Noul claim rubric including `docs_sufficient`; 111 ms, $0.000043 per call; band with an explicit uncertain middle)
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (atomic scores combined with weights owned by code)
  - https://docs.typesafe.ai/patterns/fan-out.md  (many independent questions in one request add tokens, not latency)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (counting is unreliable: "iterate in code over the candidates and ask one question for each, then add up the answers yourself")
related: [uc-insurance-fnol-classification, uc-insurance-rubric-claim-triage-uncertain-band, uc-insurance-straight-through-vs-adjuster-routing, cb-consistency_noul_cookbook, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to work out how complex a claim is and what is missing from
it?" Also asked as "can jev tell us which documents the claimant still owes us?", "can we
auto-generate the follow-up checklist for an adjuster?", and "can jev score claim
complexity so we can staff the queue?".

## Verdict

**Good.** The use-case map names it — "Detect claim complexity, missing information, and
potential fraud indicators" — and the official self-consistency cookbook's auto-claim rubric
already carries a question of exactly this shape (`docs_sufficient`: "Is the attached
documentation sufficient to adjudicate the claim as-is?"). The design that works is
multi-label, not a single "what's missing" question: one Noul per required detail, plus a
separate Score for complexity, combined in code. The single most important reason it fits
is that "missing" is a property of a named thing you can enumerate in advance, which turns a
generation task into a fixed set of yes/no reads.

## What jev decides

State: the claim narrative, the adjuster note if there is one, and a list of the document
filenames and types already attached. Do not send the documents themselves unless a question
reads them — failure mode 5. Do not ask jev to *count* what is missing; the jaggedness page
is explicit that you "iterate in code over the candidates and ask one question for each,
then add up the answers yourself".

```
complexity: Score
  instructions: {question: "How much adjuster work will `claim` require to settle?",
                 focus: "Judge the work the file implies, not the amount claimed."}
  criteria:
    - "Routine: one party, one clear cause, damage described in the narrative, no injury."
    - "Some judgement: minor disputed detail, a second party's account needed, or one
       missing document."
    - "Investigation: disputed liability, injury described, multiple parties, or conflicting
       accounts in the file."
    - "Specialist: suspected coverage dispute, litigation mentioned, or a loss type this
       team does not routinely handle."

has_incident_datetime: Noul
  instructions: "Does `claim.narrative` state when the incident happened, to at least a day?"
  criteria: {true:  {what: "A calendar date or an unambiguous relative day is stated",
                     examples: ["on 3 June", "last Tuesday morning"]},
             false: {what: "No day is identifiable",
                     not_for: "A stated date you consider implausible - that is a different question",
                     examples: ["recently", "a while back"]}}

has_location, has_third_party_details, has_damage_description,
has_police_or_incident_reference, has_witness_details, has_repair_estimate: Noul
  (one per required item, each phrased so true means "the detail is present")
```

Phrase every Noul in the same direction. The consistency cookbook's rubric is written that
way on purpose — "phrased so a yes means the thing we are checking for is true. That keeps
every row comparable" — and it lets one band rule cover all of them instead of one per
question. Failure mode 7 (contradictory instructions and criteria) is what you avoid by
never writing a `missing_x` Noul whose true means "absent".

Bands, following the cookbook: below 0.30 treat the detail as absent and add it to the
follow-up list; above 0.70 treat it as present; 0.30 to 0.70 inclusive is uncertain and the
item goes on the adjuster's "check" list rather than into an automated chaser email.

## What stays in code

The checklist itself — which details a given peril and jurisdiction require — is policy and
belongs in a table, not in a prompt. Counting how many items are missing, the weighted
complexity band, any SLA or reporting-window arithmetic, whether a document of type X exists
in the DMS, and the sending of the chaser are all code. Reporting-window and expiry
comparisons in particular stay in code (failure modes 2 and 3); if a date must come out of
prose, use the date extraction rewrite — Choice over enumerated components, code assembles.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. A 2,000-character claim narrative plus an attachment manifest (~400
characters), one four-level Score (~450 characters) and seven Nouls with criteria (~1,600
characters) is about 4,450 / 4 ≈ 1,110 tokens, so **≈ $0.000047 per claim**. Directly
comparable published figure: the consistency cookbook's 14-Noul rubric over one auto claim
cost **$0.000043** per call at a mean **111 ms** round trip, sampled 2026-09-11 — the same
order, because the questions dominate neither the tokens nor the latency. Run-to-run
stability on that rubric: "TypeSafe's mean per-question probability standard deviation is
`0.0102`, below all LLM probability conditions here." Accuracy against adjuster judgement
on your checklist: not published; calibrate against files an adjuster has already
completed, which is a free labelled set.

## When the verdict flips

- The required documents are already tracked as structured checkboxes in the claims system.
  Then presence is a database lookup and the model adds nothing.
- The "missing" judgement depends on reading a scanned attachment. Jev is text only; the
  answer is `no` until OCR produces text, and then it is a different entry.
- You want a free-text summary of what is missing for the chaser email. That is generation
  (failure mode 9) — jev decides *which* items are missing, a template or an LLM writes the
  email.
- The complexity score is used to set reserves. Then it is an input to an arithmetic
  decision, and the jaggedness page warns against reconstructing a magnitude by
  interpolating between Score levels; use it to band and route, not to price.

## Alternatives considered

- **Regex / deterministic.** Good at "is there a file of type estimate attached", useless at
  "does the narrative say where it happened". Keep it for the structured half.
- **Small LLM (Haiku-class).** Comparable answers; the same cookbook measured
  `claude-haiku-4-5` at 1,780 ms and $0.001798 per equivalent rubric call, and noted it
  "wraps nearly every reply in a ` ```json ... ``` ` fence that strict `json.loads` rejects".
- **Frontier LLM.** Can produce the checklist and the email in one go, at seconds and cents;
  worth it only when the prose output is genuinely needed.
- **Fine-tuned classifier.** Needs a labelled corpus per checklist item and freezes the
  checklist; the checklist changes with regulation, so this ages badly.
- **Embeddings.** No sensible notion of "absent".
- **Human adjuster triage.** Stays for the uncertain band; the point is to shrink the band,
  not remove the adjuster.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (complexity and missing-information
detection named), `cookbooks/consistency_noul_cookbook.md` (`docs_sufficient` question, the
0.30-0.70 band, 111 ms, $0.000043, std dev 0.0102, run sampled 2026-09-11),
`patterns/composite-scoring.md`, `patterns/fan-out.md`,
`model-jaggedness/jev-1.13.md` (counting in code; Score magnitude warning),
`models.md` (price, latency).
