---
id: cb-sde_cascade
title: SDE cascade
url: https://docs.typesafe.ai/cookbooks/sde_cascade.md
decision_shapes: [verification, detection, routing]
primitives: [noul]
related: [uc-verification-structured-extraction-cascade, uc-verification-extraction-field-verification, uc-agents-harness-confidence-escalation-to-frontier-model, uc-agents-harness-tool-call-trace-verification, uc-verification-document-completeness-checklist, au-whole-document-in-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

A two-stage structured-data-extraction cascade: extract with a cheap model, verify each
extracted field with jev nouls, and escalate only the flagged records to an expensive
reasoning model. Stated goal: "get most of the quality of a big reasoning model at a
fraction of the cost."

Dataset: `scrapegraphai/scrapegraphai-100k` on Hugging Face, pinned at revision
`4bb9fba1dff9181c5acdb60a5a26fea62fa54fe9`, split `train`. The walkthrough uses one row,
index `[516]` - an NYU events-calendar page whose schema asks for `registration_open_date`
and `description`, where "there is no registration date, or description". The aggregate
section uses "100 scrapegraphai prompts". Models: `MINI = "gpt-5.4-mini"` (rung 0),
`REASONING = "gpt-5.5"` with `reasoning_effort="high"` (rung 1), `TS_MODEL = "jev-1.12"`
(verifier). Date sampled: not reported; prices are "standard rates checked September 15,
2026".

## Decomposition (state, questions, how answers are combined)

The whole battery runs in one `system_one` call. State carries the extractor's own context
plus the record under review:

```python
state = {
    "system_message": EXTRACT_SYSTEM,
    "instruction": "Extract the structured record from this document",
    "source_text": row["content"],
    "schema": schema,
    "extraction": record,
}
```

Question keys are `field::metric`. Every question is a `Noul` framed so `true` means
something is wrong. Seven per-field metrics in `MAIN_QUESTIONS` (verbatim instructions,
trimmed):

- `name_desc_mismatch` - "Does the `extracted_field` fail to match the field at `path` or
  the `description` in the `field_spec`?" (`true`: "the `extracted_field` does not match the
  field name or its `description`")
- `hallucinated` - "Is the `extracted_field` unsupported by, or absent from, the source
  text?" (`true`: "the `extracted_field` is a hallucination -- not supported by, or absent
  from, the source text")
- `off_target` - "Does the source text fail to genuinely report the thing the `field_spec`
  describes, so the value was pulled from incidental text?"
- `type_mismatch` - violates the declared `type` (skipped when the type is `unknown`)
- `unreasonable` - a value "a reasonable person would not have extracted"
- `incomplete` - "wrongly empty, null, or missing a value the source supports"
- `format_violation` - violates format or constraints implied by the description and type

Empty fields (`None`, `""`, `[]`) get only one head, `absence_wrong`: "The
`extracted_field` is empty... Does the source text contain the information the `field_spec`
describes, making the empty result wrong?" (`true`: "a value was wrongly omitted").

One holistic head, `__overall__::judge`, asks whether the record "should be escalated to a
smarter model". It is computed and displayed "to contrast a whole-record judgment with the
per-field heads, but the gate in Step 4 does **not** use it".

The gate is a max over the per-field heads, `FIRE_T = 0.7`:

```python
fired = {qid: p for qid, p in checks.items()
         if not qid.startswith("__overall__") and p > FIRE_T}
escalate = bool(fired)
final_record = extract(REASONING, ...) if escalate else mini_record
```

"this is a `max`-style gate (escalate if *any* field fires), not a mean, so one confident
red flag is enough instead of being averaged into silence". There is no abstain path: the
low-confidence direction is escalation, and a record that fails `json.loads` returns `{}`,
which the cookbook claims means "every field reads as absent, which the verifier flags and the
gate escalates -- the safe direction."

**That claim does not hold against the cookbook's own code.** The question battery is built by
iterating the record's fields, so `{}` produces *no* per-field heads at all; `checks` is then
empty except for `__overall__::judge`, which the gate explicitly excludes; `fired` is empty and
`escalate` is `False`. A parse failure therefore passes the gate silently rather than escalating,
and the same hole applies to a record that parses but is missing keys — absent keys generate no
`absence_wrong` head either. Note also that the gate is `p > 0.7`, so a head sitting at exactly
0.5 — genuine uncertainty — does not escalate. **Deterministic parse and schema-completeness
handling has to be written in code before the gate; this cookbook does not provide it."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Prices, "\$ per 1M tokens, input / output; standard rates checked September 15, 2026":

| Rung | Model | Price |
|---|---|---|
| rung 0 (mini) | `gpt-5.4-mini` | $0.75 / $4.50 |
| rung 1 (reasoning) | `gpt-5.5` | $5.00 / $30.00 (roughly 7x the mini) |
| verifier | TypeSafe `jev-1.12` | $0.042 / $0.00 (output tokens are free) |

Verifier output on the worked example, `P(wrong)` per question, gate threshold 0.7:

```
description::hallucinated                    0.95  <== FIRES
description::off_target                      0.85  <== FIRES
description::unreasonable                    0.58
__overall__::judge                           0.56
description::incomplete                      0.16
registration_open_date::absence_wrong        0.14
description::format_violation                0.10
description::name_desc_mismatch              0.08
description::type_mismatch                   0.02
```

Aggregate run: "100 scrapegraphai prompts", the gate threshold "swept 0->1", plotted in
(cost, quality) space. The only numeric point given in prose is the strongest single model:
`gpt-5.5-reasoning` "sits top-right at ~0.81 quality for ~\$0.10/extraction". The other
three single-model points, the cascade's per-point costs and qualities, and the escalation
rate at any threshold are shown only in the chart image and are **not reported** numerically
in the text.

Escalation rate: not reported. Latency: not reported. Token counts: not reported.
Per-case jev cost: not reported. Number of repeats / `NUM_SAMPLES`: not reported. Standard
deviations: not reported. Run date: not reported for the 100-prompt run.

## Caveats the cookbook itself states

- The 100-prompt results are "**internal TypeSafe results**".
- "the chart is a historical snapshot; its costs have not been recalculated at the current
  Jev rate listed above".
- The worked example's mini extraction is hard-coded, not sampled live: "`gpt-5.4-mini` is
  very stochastic on this input -- even at `temperature=0` it invents a different
  `description` on nearly every run. For a reproducible walkthrough we **hard-code** the one
  canonical fabrication".
- The walkthrough shows only two gating heads; "the full pipeline also has a `spurious` head
  for whole containers and an overall `difficulty` score; not shown here".
- The extraction rungs use text-mode OpenAI, not structured outputs, tool calls or JSON
  mode, deliberately - "we encourage you to try them though!"
- Schema validation is necessary but not sufficient: the fabricated record prints
  `schema-valid: True`. "it catches structural errors, never semantic ones."
- The cascade "is only as good as its verifier"; a vague question gives "mushy,
  uncalibrated scores", and the verifier "has to be cheap, or there are no savings left to
  capture".

## Lessons transferable to other use cases

- Cascade with a verifier: cheap model first, typed verifier second, expensive model only
  on flagged items. The verifier decides spend, not quality directly.
- Bad = TRUE: frame every noul so the escalate case is the `true` case and state explicit
  `true`/`false` criteria, so the threshold has one meaning across all heads.
- Per-field then `max`, not one holistic judge: per-field flags "localize the error and stay
  sparse and strong". The worked example shows the holistic head at 0.56 while the two
  correct per-field heads read 0.95 and 0.85 - a single whole-record judge would have sat
  under the 0.7 gate.
- Fan-out: the whole battery (holistic head plus per-field heads) goes out in one call over
  one state.
- Conditional question sets: empty fields get only `absence_wrong`; `type_mismatch` is
  skipped when the type is unknown. Companion questions are asked only when relevant.
- **Not a transferable lesson — a defect.** The cookbook states that an unparseable extraction
  becomes `{}` "which flags and escalates". It does not: with no fields there are no per-field
  heads, the holistic head is excluded from the gate, and `escalate` evaluates to `False`. Missing
  keys evade their checks the same way. Treat parse failure and schema incompleteness as
  deterministic code checks *before* the verifier, not as something the noul battery catches.
- What does not generalise: the 0.7 threshold and the quality/cost point are specific to
  this dataset and this model pair. The cookbook itself sweeps the threshold rather than
  recommending one.

## Use-case entries this supports

- `uc-verification-structured-extraction-cascade` - cheap model, jev verifier, reasoning model only on failures
- `uc-verification-extraction-field-verification` - flag hallucinated, unsupported or schema-valid-but-wrong extracted fields
- `uc-agents-harness-confidence-escalation-to-frontier-model` - route only flagged records to a reasoning model
- `uc-agents-harness-tool-call-trace-verification` - gate a cheap agent's output before accepting it
- `uc-verification-document-completeness-checklist` - confirm an empty field is correctly empty against the source

**Anti-use-case implied:** `au-whole-document-in-state` - a single "is this whole thing
good?" question is the wrong shape; it gave 0.56 where the localised heads gave 0.95, and
"vague questions give mushy, uncalibrated scores".
