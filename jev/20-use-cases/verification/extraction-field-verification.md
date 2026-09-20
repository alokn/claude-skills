---
id: uc-verification-extraction-field-verification
title: Verify each extracted field against the source document before accepting a record
verdict: good
domain: verification
decision_shapes: [verification, detection]
primitives: [noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (field::metric Nouls, FIRE_T 0.7, holistic 0.56 vs localised 0.95/0.85, price table)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9: extraction as selection; weakest on precise extraction)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: "Verify ... extractions")
related: [uc-verification-structured-extraction-cascade, uc-verification-citation-supports-claim, uc-data-ml-pre-parsed-value-selection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check the fields another model extracted?" Also: "our
extractor returns schema-valid nonsense", "how do we catch a hallucinated description without
re-reading every document?", "can jev tell us an empty field should not be empty?"

## Verdict

**Good** — the shape is demonstrated by the `sde_cascade` cookbook; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
Verification is a bounded judgement over text that is already in front of the model,
which is the shape jev is built for, and it is the half of structured extraction jev can
do well — TypeSafe's own evals report jev "weakest on invoice-style precise extraction",
so extract with something else and verify with jev. The design rule the cookbook proves:
one Noul per field per failure mode, never a single "is this record good?" question.

## What jev decides

The whole battery rides one call. State carries the extractor's own context plus the record:

```python
state = {"system_message": EXTRACT_SYSTEM, "instruction": "Extract the structured record from this document",
         "source_text": row["content"], "schema": schema, "extraction": record}
```

Question keys are `field::metric`, and every Noul is framed so **`true` means something is
wrong** — "so the threshold has one meaning across all heads". Seven per-field heads (verbatim
instructions, trimmed):

- `hallucinated` — "Is the `extracted_field` unsupported by, or absent from, the source text?"
  (`true`: "the `extracted_field` is a hallucination — not supported by, or absent from, the
  source text")
- `off_target` — "Does the source text fail to genuinely report the thing the `field_spec`
  describes, so the value was pulled from incidental text?"
- `name_desc_mismatch` — "Does the `extracted_field` fail to match the field at `path` or the
  `description` in the `field_spec`?"
- `type_mismatch` — violates the declared `type` (skipped when the type is `unknown`)
- `unreasonable` — a value "a reasonable person would not have extracted"
- `incomplete` — "wrongly empty, null, or missing a value the source supports"
- `format_violation` — violates format or constraints implied by the description and type

Empty fields get one head only, `absence_wrong`: "Does the source text contain the information
the `field_spec` describes, making the empty result wrong?"

Conditional question sets and a max gate, both in code:

```python
FIRE_T = 0.7
fired = {qid: p for qid, p in checks.items() if not qid.startswith("__overall__") and p > FIRE_T}
```

"this is a `max`-style gate (escalate if *any* field fires), not a mean, so one confident red
flag is enough instead of being averaged into silence."

## What stays in code

Schema validation (necessary, not sufficient), the gate threshold, which heads apply to which
field type, and what happens to a flagged record. The cookbook presents an unparseable
extraction becoming `{}` as a fail-safe — "every field reads as absent, which the verifier
flags and the gate escalates" — but that is not what its code does, as the next paragraph
sets out; you must supply the escalation yourself.

Parse failures and missing required fields are code's job and must be handled
deterministically *before* jev verification runs: an empty or unparseable extraction, or
a record missing a required key, has to escalate on the schema check alone. The
`sde_cascade` cookbook's own loop iterates `record.items()`, so `{}` produces no field
checks at all and a missing key is never asked about. Code also owns a separate
uncertainty policy for middling error probabilities — a `P(wrong)` near 0.5 is neither a
pass nor a fire under a one-sided gate, so route that band to review explicitly rather
than letting the default carry it.

## Numbers

From `sde_cascade.md`, `jev-1.12` verifying `gpt-5.4-mini` output on the `scrapegraphai-100k`
dataset. Worked example (an NYU events page where the extractor fabricated a description),
`P(wrong)` per head, gate 0.7:

```
description::hallucinated              0.95  <== FIRES
description::off_target                0.85  <== FIRES
description::unreasonable              0.58
__overall__::judge                     0.56
description::incomplete                0.16
registration_open_date::absence_wrong  0.14
description::format_violation          0.10
description::name_desc_mismatch        0.08
description::type_mismatch             0.02
```

The holistic head at 0.56 versus the localised heads at 0.95 and 0.85 is the measured case
against a single whole-record judge — it "would have sat under the 0.7 gate". Prices, "standard
rates checked September 15, 2026": verifier `jev-1.12` at $0.042 / $0.00 per million tokens
against `gpt-5.4-mini` at $0.75 / $4.50 and `gpt-5.5` at $5.00 / $30.00. Per-case verifier cost,
escalation rate, latency and accuracy: **not reported**. The 100-prompt aggregate results are
"internal TypeSafe results".

Closest jaggedness mode: **9, generation** — avoided by having jev judge a value rather than
produce one. Also **2**: the cookbook's schema-valid fabrication is why validation is not the
check.

## When the verdict flips

- **You copy the cookbook's escalation gate verbatim.** That is a known defect, not a starting
  point: `sde_cascade` iterates `record.items()`, so an empty `{}` produces no field checks and
  the escalation flag stays `false`; missing required keys evade the per-field checks the same
  way; and a `P(wrong)` of 0.5 does not escalate under the `> 0.7` gate. Schema-validate first and
  add an explicit uncertain band, or the cascade silently passes exactly the records it exists to
  catch.
- **The field is machine-checkable.** A regex, a checksum, a foreign-key lookup, a range test.
  Assert it; asking is **weak** and slower.
- **Your extractor is already accurate enough.** Measure the error rate first; a verifier over
  a 0.5%-error extractor mostly produces false positives.
- **The questions are vague.** "The cascade is only as good as its verifier"; a loose question
  gives "mushy, uncalibrated scores" and the gate becomes noise.
- **Source documents exceed the context budget** once paired with the record (32k tokens for
  state plus the longest question). Verify field by field against the relevant span.
- **You make the verifier the sole quality gate with no escalation path.** The point is routing
  spend, not certifying correctness.

## Alternatives considered

- **JSON-schema / Pydantic validation** — mandatory and free, and the cookbook's fabricated
  record printed `schema-valid: True`: "it catches structural errors, never semantic ones."
- **Re-extract with a second model and diff** — a strong, simple baseline; it costs a second
  extraction and disagreement does not tell you which side is wrong.
- **LLM-as-judge on the whole record** — the incumbent, and the measured wrong shape here (0.56
  vs 0.95/0.85), besides costing a full call.
- **Confidence / logprobs from the extractor** — free where available; they measure token
  likelihood, not support in the source, and a fluent fabrication scores high.
- **Human QA sampling** — where flagged records go; unaffordable as the primary gate at volume.

## Sources

- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
