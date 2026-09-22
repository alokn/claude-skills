---
id: uc-financial-crime-sar-narrative-element-presence
title: Check that a SAR narrative contains every required element before it is filed
verdict: good
domain: financial-crime
decision_shapes: [verification, detection]
primitives: [noul, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (a fixed rubric of 14 Nouls over one document in a single call; 111 ms, $0.000043; mean per-question probability standard deviation 0.0102; a 0.30-0.70 inclusive review band)
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (verification as a typed decision with a confidence gate; exact string match before the model)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Financial crime: evaluate narratives and alert histories; "Route ambiguous cases to investigators for review")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9 generation; mode 3 dates; mode 2 counting)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-financial-crime-alert-prioritisation-by-evidence-quality, uc-financial-crime-transaction-narrative-suspicious-characteristics, cb-consistency_noul_cookbook, cb-citation_check, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check a SAR narrative before filing?" Also: "does this
narrative actually say who, what, when, where and why?", "can we catch an incomplete
suspicious activity report before the regulator does?", "can a model draft the SAR?" — no to
the last one.

## Verdict

**Good.** A filing-completeness check is a fixed rubric of yes/no questions over one document,
which is precisely the shape the self-consistency cookbook runs: 14 Nouls over a single
insurance claim in one call, "phrased so a yes means the thing we are checking for is true",
with a three-way band that sends the middle to a human. Transposed to a SAR narrative, each
required element is one Noul, the analyst sees which ones are missing, and nothing is filed on
the model's word. It is `good` rather than `strong` because the cookbook's rubric is an
insurance claim, not a SAR, and no public measurement exists on regulatory narratives.
Critically, jev **verifies** the narrative; it cannot write it — generation is failure mode 9.

## What jev decides

State: `{narrative: "<the drafted text>", case_facts: {subject_names, account_ids, date_range,
instrument_types, total_amount}}`. The case facts come from your case management system so the
questions can compare the narrative against them rather than against the model's assumptions.

```
states_who: Noul
  instructions: {question: "Does `narrative` identify the subject or subjects of the suspicious
                            activity by name or by account?",
                 compare: ["`narrative`", "`case_facts.subject_names`"]}
  criteria:
    true:  {what: "Names at least one subject, or identifies them by an account or customer id"}
    false: {what: "Refers only to 'the customer' or 'the subject' with no identifier",
            not_for: "A named subject introduced once and then referred to generically"}

states_what: Noul   "Does `narrative` describe the transactions or conduct that is suspicious,
                     rather than only labelling it suspicious?"
states_when: Noul   "Does `narrative` state the period over which the activity occurred?"
states_where: Noul  "Does `narrative` state the branches, channels, or jurisdictions involved?"
states_why: Noul    "Does `narrative` explain what makes the activity suspicious, as opposed to
                     merely unusual?"
states_how: Noul    "Does `narrative` describe the method or instruments used to move the funds?"

conclusory_only: Noul
  instructions: "Does `narrative` assert a conclusion without describing the facts that support it?"
  criteria:
    true:  {what: "Says the activity is structuring, laundering, or fraud without describing
                   the pattern that shows it"}
    false: {what: "Describes the observed pattern and then characterises it"}

self_contained: Score
  criteria: ["A reader outside the institution could not follow what happened.",
             "Followable, but requires attachments or system access to verify.",
             "Followable and verifiable from the narrative alone."]
```

All in one call; questions over the same state run in parallel and add little latency (the docs say latency
"barely changes", not that it is free). Banding
follows the cookbook's explicit uncertain middle — "`no` below `0.30`; `uncertain` from `0.30`
through `0.70`, including both boundaries; `yes` above `0.70`" — so an element scoring 0.49
and one scoring 0.51 do not produce opposite automatic outcomes. Any element in `no` or
`uncertain` is surfaced to the analyst as a checklist item; nothing is auto-approved.

## What stays in code

The filing itself, the deadline clock, and every date comparison — a 30-day filing window is
date arithmetic and failure mode 3 says keep it in code. Also: the presence of mandatory
structured fields (subject TIN, account numbers, amount totals, SAR type codes), which is a
schema check, not a judgement; cross-footing the amounts against the transaction records,
which is arithmetic; exact-match checks that every subject name in `case_facts` appears
somewhere in the narrative, which a string match does perfectly and the citation cookbook runs
before its model call for exactly this reason; and the record of who approved the filing.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
4,000-character narrative plus case facts (~600 characters) plus eight questions with criteria
(~2,400 characters) is about 1,750 tokens, **≈ $0.000074 per narrative**. The nearest measured
comparison is the cookbook's own: a 14-question rubric over one claim at "111ms" and
"$0.000043" per call, against 1,485-13,886 ms and $0.00095-$0.034 for the LLM conditions in
the same run (sampled 2026-09-11), with jev's "mean per-question probability standard
deviation" at "0.0102". Run-to-run stability matters here specifically because a filing
decision that flips between two reviews of the same draft is indefensible — though the
cookbook is explicit that "low variance is not correctness". Accuracy on SAR completeness: not
published; measure it. Labelled data for calibration: your own quality-assurance history —
narratives returned by QA or by the regulator, with the element that was missing, is a small
but exactly-labelled set.

## When the verdict flips

- To **no**, if the check is the filing gate. A SAR is a regulatory obligation; the analyst and
  the compliance officer stay the authority, and a probability cannot sign a filing.
- To **no**, if you ask jev to write or improve the narrative. Generation is not a System One
  task; use a generative model and then run this rubric over its output.
- To **conditional**, for narratives longer than the 32k state budget. Chunk by section and ask
  per section, or the accuracy loss from context rot lands on exactly the long, complex cases.
- Non-English narratives, without your own evaluation.

## Alternatives considered

- **Field-presence and schema validation.** Mandatory and exact for the structured part of the
  filing. It cannot tell whether the prose explains anything.
- **Word-count and keyword checklists.** The common incumbent; they measure typing, and a
  narrative can contain the word "structuring" while explaining nothing.
- **Frontier LLM as reviewer.** Better at saying *how* the narrative falls short, and it can
  draft the missing sentence — which jev cannot. Seconds and cents per narrative; reasonable
  given SAR volumes. The noul cookbook measured its conditions moving between runs; that result is
  specific to the tested configuration, so measure it on your narratives.
- **Small LLM.** Comparable checks, an order of magnitude slower in the cookbook's run, and in
  the same run the LLM conditions "disagree with *themselves*" on the judgement calls at
  temperature 0.
- **Fine-tuned classifier.** Eight elements means eight models, and the labelled corpus from QA
  returns is small.
- **Embeddings.** No notion of "explains why this is suspicious".
- **Analyst and compliance-officer review.** Stays, and stays the authority. This turns their
  first read into a checklist rather than a hunt.

## Sources

Accessed 2026-09-19. `cookbooks/consistency_noul_cookbook.md` (14-Noul rubric in one call, 111
ms, $0.000043, std dev 0.0102, the 0.30-0.70 inclusive band, "low variance is not
correctness"; sampled 2026-09-11), `cookbooks/citation_check.md` (string match before the
model; confidence gate), `concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` (modes 2,
3, 9), `models.md`.
