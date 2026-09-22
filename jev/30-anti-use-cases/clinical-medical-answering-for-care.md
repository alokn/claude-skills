---
id: au-clinical-medical-answering-for-care
title: Do not use jev to answer clinical or medical questions that inform care
verdict: no
domain: product
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/mahlernim/jev-korean-benchmark  (100 items per condition; MedQA EN jev 89 vs gpt-5.6-luna 84; KorMedMCQA jev 80 vs gpt-5.6-luna 88; author states a ±8-point margin at n=100)
  - https://docs.typesafe.ai/confidence.md  ("Jev guarantees the shape of its answers, not that every decision is correct")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 4, indirection; failure mode 8, structural invariants and out-of-distribution overconfidence; state is not treated as hostile by default)
  - https://docs.typesafe.ai/models.md  (English is strongest; other languages accepted with lower accuracy)
related: [au-legal-determinations-without-counsel, au-non-english-at-scale-unevaluated, au-confidence-as-correctness-gate, au-decisions-that-need-an-explanation, au-exact-grade-prediction-high-stakes]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to answer medical questions?" Also: "can jev triage symptoms?",
"can jev pick the right answer on a clinical multiple-choice question?", "it scored well on MedQA
— can we put it in the patient app?"

## Verdict

**No**, wherever the answer reaches a patient or a clinician as guidance. A care decision is a
safety invariant: it must hold every time, it must be explainable, and a wrong answer harms
someone. Jev gives none of those — it "guarantees the shape of its answers, not that every
decision is correct", it returns no reasoning at all, and its confidence is a probability trained to be
calibrated, not a permission to act.

The only independent medical measurement makes the point without needing the safety argument. On
KorMedMCQA, **jev scored 80 against gpt-5.6-luna's 88** over 100 items, and on the English MedQA
set the order reversed, **jev 89 against 84** — with the author stating a **±8-point margin** at
that sample size. So the two exams disagree, neither result is separable from noise, and the
Korean result is 8 points *behind* a general-purpose model on the language where the deficit was
predicted. Nothing in that supports clinical deployment, in either language.

**Separate proposal: conditional, away from care.** Non-clinical text handling around a clinical
workflow is a different question — routing a message to the right department, detecting that a
referral letter is missing a required field, flagging that a note mentions a red-flag symptom *for
a clinician to read*. Those are reversible, human-terminated, and never the decision itself.

## What jev would get wrong

A clinical question is rarely single-hop. "Is this drug safe for this patient" chains a
contraindication list, a renal function value, a dose and an interaction — indirection (failure
mode 4) plus arithmetic, in a domain where each hop must be right. The model is also strongest in
English and accepted "with lower accuracy" elsewhere, and KorMedMCQA is exactly the case where
that showed. Most damaging, a benchmark score is out-of-distribution evidence for a real patient
message: multiple-choice exams supply four curated options, and a real presentation supplies
none. Overconfidence on out-of-distribution input is failure mode 8, and confidence has already
been rejected publicly as a correctness gate.

## What stays in code

Everything, including the decision. Drug interactions, dosing, contraindications and eligibility
come from a maintained clinical database with a version and an audit trail. Escalation paths, red
flags and consent are deterministic rules. A clinician signs. If jev appears at all, it reads
unstructured text into a structured field a human then verifies — never the recommendation.

## Numbers

From `mahlernim/jev-korean-benchmark`, 100 items per condition: MedQA (English) jev **89** against
gpt-5.6-luna **84**; KorMedMCQA (Korean) jev **80** against **88**. The author states a **±8-point
margin**, and this corpus's source-reliability table rates the study "sample check only" with the
note that the two medical exams are not comparable to each other. No precision, recall, harm
analysis or abstention curve exists for any clinical task, from any source.

## When the verdict flips

- It does not, for care guidance — regulation, liability and the safety invariant sit above the
  numbers.
- To **conditional** for administrative text work beside the clinic: department routing, referral
  completeness, coding assistance, all human-confirmed.
- To **conditional** for research-only screening of published literature, where the output is a
  reading list.

## Alternatives considered

- **A maintained clinical decision-support system.** Versioned, auditable, regulated. The answer.
- **Frontier LLM with retrieval over guidelines.** Cites its sources and writes the reasoning a
  clinician can check; still not the decision-maker.
- **Deterministic rules from the guideline text.** Exact where the guideline is a table.
- **Clinician.** The decision, and the accountable party.

## Sources

- https://github.com/mahlernim/jev-korean-benchmark — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
