---
id: uc-legal-compliance-prohibited-marketing-claims
title: Detect prohibited marketing claims in ad copy and landing pages
verdict: good
domain: legal-compliance
decision_shapes: [detection, verification]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (advertising: "Check regulatory compliance and prohibited claims"; legal: "Detect missing clauses, prohibited claims, and policy violations")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (one Noul per property; contrastive true/false criteria)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 1 literal reading; failure mode 6 adversarial content, "don't make jev the sole gate")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (semantic checks alongside deterministic filters, not instead of them)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-legal-compliance-policy-violation-detection, uc-legal-compliance-regulatory-requirement-verification, uc-legal-compliance-contract-clause-presence, df-fit-test, cb-llm_guardrails]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to catch prohibited claims in our marketing copy?" Also asked
as "can jev replace the banned-phrase list our legal team maintains?", "can we screen
paid-search ad variants for regulated claims before they go live?", and "can jev check
landing pages for unsubstantiated health or financial claims?".

## Verdict

**Good.** A prohibited claim is a property of a short piece of text, and "does this copy
assert X" is a single-hop semantic judgement — one Noul per claim type, fanned out in one
call. The use-case map names it directly for advertising and for legal and compliance. The
reason this is *good* rather than *strong* is that no official cookbook measures it and the
design has a standing constraint: the deterministic banned-phrase list stays authoritative
and jev is added on top of it, because a compliance list is a rule that must fire every time
and failure mode 6 says state is not treated as hostile by default. Jev's job is the
paraphrase the list misses — "clinically shown to melt fat" when the list only holds "cures".

## What jev decides

State: the ad's headline, body, disclaimer text and the landing-page copy it links to, as
separate fields. Not the whole HTML page; not the CSS; not the nav. Failure mode 5 is the
one this walks into, and the fix is that code extracts the visible copy first.

```
claims_guaranteed_outcome: Noul
  instructions: {question: "Does `copy` promise a specific outcome the reader will achieve?",
                 inspect: "`copy.headline`, `copy.body`",
                 focus: "A promise about the reader's result, not a description of the product."}
  criteria:
    true:  {what: "States or strongly implies a guaranteed, typical, or certain result",
            examples: ["Lose 10 pounds in 30 days", "You will double your returns",
                       "Guaranteed approval"]}
    false: {what: "Describes the product, a feature, or an individual's experience that is
                   framed as individual",
            not_for: "Aspirational language with no promised result",
            examples: ["Designed to support healthy weight management",
                       "Results vary. Sarah lost 10 pounds in 30 days."]}

claims_health_benefit_without_qualifier: Noul
  instructions: {question: "Does `copy` assert a health or medical benefit?", ...}
compares_to_named_competitor: Noul
superlative_without_substantiation: Noul   # "the best", "#1", "fastest"
targets_vulnerable_audience: Noul
disclaimer_present_and_proximate: Noul     # supports, rather than accuses
```

One severity Score rides along so code can rank the queue rather than treat every hit alike:

```
regulatory_exposure: Score
  criteria: ["No regulated claim; ordinary puffery",
             "Regulated claim made but adequately qualified in the same view",
             "Regulated claim with a distant or absent qualifier",
             "Regulated claim of a type that is prohibited outright in this category"]
```

Bands: any deterministic list hit blocks, full stop, independent of jev. Above that, a Noul
at `P ≥ 0.8` on any prohibited-claim question routes to legal review before publish;
`0.3–0.8` publishes with a flag on the review queue; below `0.3` publishes. Use the Score to
order the review queue, not to decide it — the jaggedness page is explicit that a Score
expectation is for thresholding and ranking, not for reconstructing a magnitude.

## What stays in code

The banned-phrase list and any regulator-published prohibited-term list, evaluated first and
treated as authoritative — a semantic model does not get a vote on whether "FDA approved"
appears verbatim. Category routing (a supplement ad and a consumer-credit ad get different
question sets). Jurisdiction selection. The publish gate itself. Disclaimer *proximity*, if
your rule is expressed in pixels or DOM distance — that is measurement, not judgement.
Record-keeping of what was screened and when.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 1,200-character
ad plus six Nouls with true/false criteria and one four-level Score (~4,500 characters of
questions) is about (1,200 + 4,500) / 4 ≈ 1,425 tokens, so **≈ $0.00006 per creative**.
Latency 70–500 ms, "most queries about 100 ms" — fast enough to run in the copy editor as
the marketer types, which is where it is most valuable. Agreement with your legal team's past
decisions: not published; the last few hundred approved and rejected creatives in your
review tool are the labelled set, so measure it there.

## When the verdict flips

- The prohibited claims really are a fixed vocabulary that your regulator publishes as a
  word list. Then the regex is correct and complete, and jev only adds cost.
- Jev is proposed as the publish gate with no deterministic list behind it. That is a
  compliance invariant; per the fit test's counter-signals, keep the gate in code.
- The judgement requires substantiation review — "is this claim supported by the study in
  the annex?" is a multi-hop question over a document jev has not been given. Put the study
  excerpt in the state and ask a verification question, or escalate.
- Non-English markets without a separate evaluation per language.

## Alternatives considered

- **Regex / banned-phrase list.** Exact, free, and it must stay. It cannot see paraphrase,
  which is the entire gap jev fills.
- **Small LLM (Haiku-class).** Similar quality on this shape, at seconds and cents; it also
  cannot be run on every keystroke. Jev's advantage here is latency and a schema that cannot
  be violated, not accuracy.
- **Frontier LLM.** The right tool for substantiation review and for drafting the compliant
  rewrite — which jev cannot do at all, since generation is failure mode 9.
- **Fine-tuned classifier.** Viable if you have thousands of labelled creatives per claim
  type and the prohibited set is stable; adding a new prohibited claim to jev is editing a
  string.
- **Embeddings against a corpus of rejected copy.** Finds near-duplicates of past rejections,
  misses novel phrasings, and needs a threshold. Useful as a complement, not a replacement.
- **Human legal review.** Stays for the high band. The measurable win is the share of
  creatives that never reach a lawyer, which you can compute from shadow-mode logs.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (advertising and legal entries),
`concepts/how-to-build-with-system-one.md` (decomposition; contrastive criteria),
`model-jaggedness/jev-1.13.md` (modes 1, 5, 6; "Math using score"),
`cookbooks/llm_guardrails.md` (semantic checks beside deterministic ones), `models.md`
(price, latency).
