---
id: uc-commerce-prohibited-counterfeit-signals
title: Flag prohibited and counterfeit signals in a marketplace listing
verdict: conditional
domain: commerce
decision_shapes: [detection, scoring, routing]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce: "Detect prohibited listings, counterfeit signals, review abuse, and policy violations"; "route uncertain listings for human review")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (hazard Nouls plus a severity Score, thresholded into pass / review / block by a policy object)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6: adversarial content; state is not treated as hostile by default)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (decomposition: atomic questions over one broad one)
related: [uc-trust-safety-policy-violation-bands, uc-commerce-listing-category-normalisation, uc-trust-safety-review-abuse-signals]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect counterfeit or prohibited listings?" Also "can jev
screen new listings before they go live?", "can we catch replica sellers?", and "can jev
enforce our restricted-items policy?".

## Verdict

**Conditional**: strong as a screening and triage layer, wrong as the enforcement gate. The
use-case map names both tasks, and the text signals are real — a listing that says "inspired
by", one that prices a luxury item at a twentieth of retail, one that ships a "tester" or
"unbranded OEM" version. But counterfeit and prohibited-goods sellers are adversaries who
read your rejection messages, and failure mode 6 states plainly that jev does not treat state
as hostile by default. The condition: deterministic brand-and-keyword gates, seller
reputation and image hashing stay in front, jev scores the residue, and a human owns takedown.
Two further constraints: the price comparison is arithmetic and belongs in code, and
counterfeits are mostly detected from images, which jev cannot read.

## What jev decides

State: title, description, the declared brand, the category, and — as a named fact computed
in code, not as a raw number to reason about — `price_vs_category_median: "below_20_percent"`.

```
replica_language: Noul
  instructions: "Does the listing describe the item as a replica, copy, or imitation of a
                 branded product?"
  criteria:
    true:  {what: "Uses replica, copy, dupe, inspired-by, mirror-quality, or equivalent",
            examples: ["1:1 mirror quality", "inspired by the original"]}
    false: {what: "No such framing",
            not_for: "A generic unbranded product sold as its own brand"}

brand_claim_inconsistent: Noul
  instructions: "Does the listing claim a brand that conflicts with how the item is described
                 or sold — unbranded packaging, no warranty, bulk 'tester' units?"

prohibited_category: Choice
  instructions: "Which restricted category, if any, does the listing describe?"
  criteria: {none: "...", weapons: "...", regulated_medical: "...", live_animals: "...",
             recalled_goods: "...", counterfeit_currency_or_documents: "...",
             age_restricted: "...", other_restricted: "..."}

evades_detection: Noul
  instructions: "Does the listing use altered spelling, spacing, or code words that appear
                 intended to avoid an automated filter?"

severity: Score
  criteria: ["No policy concern",
             "Technical breach; the seller can fix the listing",
             "Clear breach requiring removal",
             "Safety, legal, or intellectual-property risk requiring immediate removal"]
```

Bands, in the guardrails shape: a hazard above the action threshold or `severity >= 3` holds
the listing from publication and creates a review item; the middle band publishes and queues;
below, publish. Thresholds live in a per-category policy object, because a false positive on
handbags costs a seller a sale and a false negative on medical devices costs more.

## What stays in code

Takedown, seller sanctions, and appeals. Brand-owner blocklists, GTIN validation, image
perceptual hashing against known counterfeits, seller age, chargeback and return rates, and
the price-versus-median computation all stay deterministic and run first. Restricted-category
gates required by law are hard rules, not probabilities — the fit test's counter-signal on
legal invariants applies directly.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 1,000-character listing plus
these five questions with criteria (~1,800 characters) is ≈ 700 tokens, **≈ $0.000029 per
listing**, which is what makes screening every new listing rather than a sample viable.
Latency 70–500 ms, inside a publish-path budget. The nearest published run of this exact
shape is the guardrails cookbook: 15 individual routed decisions under `jev-1.12`
(2026-08-15), including the case that matters most here — `novelist_poison`, a benign
fiction request, passing at jailbreak 0.05 where a keyword filter would block it — and it
states that **no aggregate accuracy, precision or recall is reported**. Nothing is published
for counterfeit detection; measure precision at your hold threshold against adjudicated
takedowns, and recall against the listings brand owners later reported.

## When the verdict flips

- Jev is the only screen. Adversarial text plus a sole gate is the disqualifying combination.
- The signal is in the photographs. Text only; keep image hashing and visual matching.
- You compare prices with a question. Numeric closeness is failure mode 2; bucket in code and
  pass the bucket.
- Sellers see the rejection reason and iterate against it. Rotate criteria, keep the
  deterministic layer, and do not publish which signal fired.
- Listings are largely non-English. Evasive spellings are locale-specific; validate per market.

## Alternatives considered

- **Brand keyword and blocklist rules.** Essential and exact for named brands and banned
  terms; blind to paraphrase and to "inspired by the Italian original".
- **Image hashing and visual similarity.** The strongest counterfeit signal there is, and
  orthogonal to everything here. Run both.
- **Seller-level reputation models.** The highest-yield layer at scale; jev adds the
  first-listing case, where there is no history.
- **Frontier LLM per listing.** Better on novel evasion, unaffordable across a catalogue, and
  it returns prose where you need a typed flag.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' measurements, for the same shape.
- **Brand-owner reporting.** The backstop; this reduces how much it has to catch.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/llm_guardrails.md` (band
structure, per-policy thresholds, the 15 decisions, `jev-1.12`, 2026-08-15; no aggregate
metric), `model-jaggedness/jev-1.13.md` (modes 2 and 6),
`concepts/how-to-build-with-system-one.md`, `models.md`.
