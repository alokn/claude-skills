---
id: uc-legal-compliance-contract-clause-presence
title: Check a contract for the presence or absence of each required clause
verdict: good
domain: legal-compliance
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (legal and compliance: "Detect missing clauses, prohibited claims, and policy violations")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (decompose one broad judgement into atomic Nouls; NoulCriteria with true/false what/not_for/examples)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5 context rot; failure mode 1 literal reading)
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (filter sections in code or with a relevance Noul before asking the real question)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 32k state limit)
related: [uc-legal-compliance-regulatory-requirement-verification, uc-legal-compliance-policy-violation-detection, uc-legal-compliance-document-type-classification, df-fit-test, df-rewrites, cb-classifying_rag_passages]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether a contract contains the clauses we require?"
Also asked as "can jev flag missing indemnity or limitation-of-liability clauses in an
inbound MSA?", "can we replace our clause-keyword checklist with jev?", and "can jev do
first-pass contract review before counsel reads it?".

## Verdict

**Good.** Clause presence is a set of independent yes/no reading-comprehension judgements
over text, which is exactly the Noul shape, and the use-case map lists "Detect missing
clauses" under legal and compliance. No official cookbook runs this task end to end, so
ship it in shadow mode against past counsel decisions before it changes anyone's workflow.
The condition that makes it work is chunking: a 40-page agreement will not fit the 32k
state budget comfortably and, more importantly, accuracy falls as irrelevant material grows
(failure mode 5). Code selects candidate sections; jev answers one question per clause per
section; code aggregates.

## What jev decides

State: one code-selected section at a time, plus the section heading. Not the whole
agreement, not the exhibits, not the signature blocks.

```
has_limitation_of_liability: Noul
  instructions: {question: "Does `section.text` limit or cap one party's liability?",
                 inspect: "`section.text`",
                 focus: "A cap, exclusion, or ceiling on damages — not a general risk statement."}
  criteria:
    true:  {what: "States a monetary cap, a multiple of fees paid, or an exclusion of a
                   category of damages (consequential, indirect, lost profits)",
            examples: ["Supplier's aggregate liability shall not exceed the fees paid in
                        the preceding twelve months",
                       "Neither party shall be liable for indirect or consequential loss"]}
    false: {what: "Says nothing that caps or excludes damages",
            not_for: "An indemnity, an insurance requirement, or a warranty disclaimer,
                      which are different clauses and have their own questions",
            examples: ["Supplier shall maintain commercial general liability insurance of
                        $2,000,000"]}
```

Repeat one Noul per required clause — indemnity, governing law, assignment, confidentiality,
termination for convenience, data protection, audit rights — fanned out against the same
section in one call. Adding questions adds tokens and low incremental latency — the docs say latency "barely
changes" with more questions, which is not the same as zero.

Absence is the hard half, and it is bounded by retrieval, not by the model. A Noul returns
P(true), so "missing" is `max over sections of P(present) < threshold`, computed in code — and
that maximum is taken only over the sections code actually passed in. An absence verdict is
therefore only valid if every section of the document was inspected. Either run the clause
battery over full-document coverage (every chunk, with an explicit coverage assertion that the
chunks reconstruct the document), or return "not found in the inspected sections" and name
them. Retrieval recall is a separate thing to evaluate with its own labelled set: a section the
selector never returned produces a false "missing" no matter how good the Noul is. Write the `false` criteria
as carefully as the `true` criteria: failure mode 1 (literal reading) will call an insurance
covenant a liability cap if you only described what a cap looks like.

Bands, per clause: `P ≥ 0.75` in any section, present; `P ≤ 0.25` across every inspected
section, and only when coverage is complete, missing and raise the redline — with partial
coverage the same band means "not found in the inspected sections" and goes to the reviewer;
in between goes to the reviewer with the best-scoring section quoted. The
consistency-noul cookbook's `0.30`–`0.70` inclusive review band is the same idea on a claims
rubric (https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md).

## What stays in code

Section splitting and heading extraction, plus the coverage assertion that the sections passed
to jev account for the whole document — an absence verdict depends on it. The clause checklist itself, which is a policy
artefact counsel owns. Notice periods, cure periods, term lengths and renewal dates — every
one is date arithmetic and belongs nowhere near the model (failure mode 3); jev may pick the
month, day and year as a Choice over enumerated parts, and code assembles and compares
(https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md). Monetary thresholds
("is the cap below $1M?") are arithmetic: extract the candidate amount with a regex, have
jev select which candidate is the cap, then compare in code. The redline, the approval, and
the signature gate are side effects code owns.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free
(https://docs.typesafe.ai/models.md). A 4,000-character section plus twelve clause Nouls
with full true/false criteria (~7,000 characters of questions) is about
(4,000 + 7,000) / 4 ≈ 2,750 tokens, so **≈ $0.00012 per section**. A 25-section agreement is
therefore about $0.003 in one pass. Latency is 70–500 ms per call, "most queries about
100 ms", and the sections parallelise. Accuracy on your clause library: not published —
measure it against the last few hundred agreements counsel has already marked up.

## When the verdict flips

- The clause is identified by a standard numbering scheme or a template your own paper
  always uses. Then it is a lexical lookup and deterministic code wins.
- The question is "is this clause *acceptable*", not "is it present". Acceptability turns on
  the cap amount, the carve-outs, and the interaction with two other sections — that is
  multi-hop (failure mode 4) and arithmetic (failure mode 2). Decompose it or send it to
  counsel.
- The answer is the gate on execution with no human in the loop. Then it is a legal
  invariant and jev must not be the sole mechanism.
- Non-English contracts at volume, without your own evaluation.

## Alternatives considered

- **Regex / keyword checklist.** Free and exact on your own template; useless on counterparty
  paper, where the same obligation is written twenty ways. It wins where the wording is fixed.
- **Small LLM (Haiku-class).** Comparable labels, seconds of latency, parse failures on
  structured output; the consistency-noul cookbook measured `claude-haiku-4-5` at 1,485–1,780 ms
  and $0.00165–$0.0018 per 14-question rubric call against 111 ms and $0.000043 for jev.
- **Frontier LLM.** Better on "is this clause acceptable"; overqualified and slow for "is it
  present". Use it for the escalated band only.
- **Fine-tuned clause classifier (CUAD-style encoders).** Strong if your clause set is fixed
  and you have thousands of labelled spans; jev wins when the checklist changes by editing a
  string rather than retraining.
- **Embeddings + similarity to a model clause.** Tunes a threshold instead of stating the
  condition, and near-miss clauses score high. Useful only as the candidate-section shortlister.
- **Human review by counsel.** Stays, for the uncertain band and for every acceptability
  judgement. The point of the check is to shorten the list counsel reads, not to replace it.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (detect missing clauses),
`concepts/how-to-build-with-system-one.md` (atomic decomposition, NoulCriteria shape),
`model-jaggedness/jev-1.13.md` (modes 1, 3, 4, 5),
`cookbooks/classifying_rag_passages.md` (filter before asking),
`cookbooks/consistency_noul_cookbook.md` (review band, 111 ms / $0.000043 per 14-question
call, Haiku comparison, sampled 2026-09-11), `cookbooks/date_extraction_cookbook.md`
(dates as Choice over parts), `models.md` (price, 32k state limit).
