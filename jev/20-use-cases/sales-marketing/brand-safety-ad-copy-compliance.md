---
id: uc-sales-marketing-brand-safety-ad-copy-compliance
title: Screen ad copy for prohibited claims and check placement brand safety
verdict: conditional
domain: sales-marketing
decision_shapes: [detection, verification, routing]
primitives: [noul, score, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (advertising: "Classify brand safety and audience suitability"; "Check regulatory compliance and prohibited claims"; legal: "Detect ... prohibited claims")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (hazard Nouls plus a severity Score thresholded by a policy object into pass / review / block; the same assessment routed differently under strict and permissive policies)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6: not the sole gate; failure mode 2: numbers and percentages belong in code)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (thresholds scale with the stakes of the action)
related: [uc-sales-marketing-ad-landing-page-alignment, uc-trust-safety-policy-violation-bands, uc-sales-marketing-creative-quality-rubric]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check ad copy for compliance?" Also "can jev catch
unsubstantiated claims before an ad goes live?", "can we screen placements for brand
safety?", and "can jev enforce our claims policy across 4,000 creatives?".

## Verdict

**Conditional**: strong as a pre-flight screen and a review router, wrong as the sign-off.
Ad compliance is a legal exposure, and the fit test's counter-signal on legal invariants says
the authoritative rule stays in code and with a reviewer. What jev adds is coverage — a claims
review that currently samples 5% of creatives can screen 100% of them at a cost per creative
of a few thousandths of a cent, and surface the ones a lawyer should read. The guardrails
cookbook's structure transfers exactly: hazard Nouls, a severity Score, and a policy object of
thresholds that can differ by market. Two conditions: keep the regulated-category rules
deterministic, and never let jev evaluate the truth of a numeric claim.

## What jev decides

State: the ad copy and headline, the product's approved claims list, and the category.
For placement brand safety, the page or content description instead.

```
claim_not_in_approved_list: Noul
  instructions: "Does `ad.copy` make a product claim that is absent from `approved_claims`?"
  criteria:
    true:  {what: "States a benefit, result, or comparison not present in the approved list"}
    false: {what: "Every claim maps to an approved claim",
            not_for: "Generic brand language with no product claim"}

superlative_or_absolute_claim: Noul
  instructions: "Does `ad.copy` use an absolute or superlative claim such as best, safest,
                 guaranteed, number one, or cures?"

implies_guaranteed_outcome: Noul
  instructions: "Does `ad.copy` imply a specific result the customer will achieve?"

targets_protected_or_vulnerable_audience: Noul
  instructions: "Does `ad.copy` address children, or people in medical, financial, or legal
                 distress?"

regulated_category: Choice
  criteria: {none: "...", health_claims: "...", financial_promotion: "...", alcohol: "...",
             gambling: "...", employment_housing_credit: "...", political: "...", other: "..."}

compliance_risk: Score
  instructions: "How much regulatory or reputational risk would running this copy as written create?"
  criteria: ["None: no product claim or a fully approved one",
             "Minor: wording to tighten, no substantive claim issue",
             "Material: an unsupported claim or a category rule likely engaged",
             "Serious: a prohibited claim, or a regulated category with no approval on file"]
```

For placement: `adjacent_content_category` (Choice over your suitability taxonomy) and
`brand_conflict_present` (Noul against a supplied list of things your brand must not sit
beside). Bands, per the guardrails shape: `compliance_risk >= 3` or any hazard above the
action threshold blocks the creative from going live and creates a legal review; the middle
band goes to marketing review; below, it ships. The thresholds are per-market data, because
what is permissible copy differs by jurisdiction and you want that diff in version control,
not in a rewritten prompt.

## What stays in code

Approval, publication, and the claims substantiation file. The approved-claims list, the
regulated-category gate, the mandatory disclosure text, and the record of who signed off are
deterministic; a string comparison confirms the disclaimer is present, and a question must
not. Numeric claims ("40% faster") are checked against the substantiation document by a
human or a lookup — failure mode 2 puts numeric reasoning outside the model entirely.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 400-character creative plus a
1,000-character approved-claims list plus these seven questions (~2,200 characters) is ≈ 900
tokens, **≈ $0.000038 per creative**. Screening 4,000 creatives is about **$0.15** of
inference, against a review process that currently samples. Latency 70–500 ms, so it can run
as the copywriter types. The closest published run is the guardrails cookbook (`jev-1.12`,
2026-08-15), which shows the severity Score turning a review into a block at severity 2.02,
a benign fiction request passing at jailbreak 0.05 where a keyword filter would not, and the
same assessment going to block under `strict` and review under `permissive` — and states
that **no aggregate accuracy, precision or recall is reported**. Nothing is published on ad
compliance; build a set from your own rejected creatives.

## When the verdict flips

- Jev signs off. Never — the review it triggers is the product, the pass is not.
- The rule is a checkable string (a mandated disclaimer, a banned term). Regex; exact beats
  probable and costs nothing.
- The claim is numeric or comparative against measurable data. Substantiation is a document
  lookup, not a judgement.
- Creatives are images or video with copy baked in. Text only; OCR first and accept that you
  are now screening the OCR.
- Markets outside English without per-market validation, which for ad law is where the rules
  differ most.

## Alternatives considered

- **Banned-term and required-disclaimer regex.** Keep it, run it first; it is exact and free.
- **Platform ad-review systems.** They enforce the platform's rules, not yours, and they tell
  you after rejection — which is the cost this removes.
- **Frontier LLM review of each creative.** Reads nuance best and can suggest compliant
  wording, which is generation and outside jev's remit; seconds and cents per creative, so
  reserve it for the flagged band.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures, with prose you must parse into a decision.
- **Fine-tuned compliance classifier.** Strong per regulated category with labelled history;
  a new market or a new rule is a retrain, where here it is an edited criterion.
- **Legal review of everything.** Accurate, slow, expensive, and the reason only a sample gets
  reviewed today.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/llm_guardrails.md` (band
structure, policy objects, the 15 published decisions; `jev-1.12`, 2026-08-15; no aggregate
metric), `model-jaggedness/jev-1.13.md` (modes 2 and 6), `patterns/confidence-routing.md`,
`models.md`, `jev/10-decision-framework/fit-test.md` (legal-invariant counter-signal).
