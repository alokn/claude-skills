---
id: uc-commerce-attribute-extraction
title: Extract product attributes as a choice over candidates found in code
verdict: conditional
domain: commerce
decision_shapes: [extraction, classification]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  ("A regex finds the candidate values, TypeSafe picks the one the question asks for, and code copies it verbatim"; "it cannot invent a value or transpose a digit"; worked picks at conf 0.98 and 1.00 under `jev-1.12`)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9: "when the answer space is bounded, turn extraction into a Choice over the options rather than asking for the value itself"; failure mode 2: numeric representations)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (e-commerce: "Extract product attributes from titles and descriptions"; structured data extraction: "candidate attributes")
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (small model extracts, jev verifies each field, reasoning model only on failures)
related: [uc-commerce-listing-category-normalisation, uc-support-call-transcript-action-extraction, uc-trust-safety-pii-exposure-detection]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to extract product attributes from listings?" Also "can jev
pull the colour, size and material out of a title?", "can we fill the attribute grid
automatically?", and "can jev read the spec table?".

## Verdict

**Conditional**, and the condition is non-negotiable: jev selects, it does not extract. Ask
"what is the colour?" as an open question and you are asking for generation, which is failure
mode 9 and the one shape the model is explicitly not trained for. Rewritten as a Choice over
an enumerated value set — which for a marketplace attribute grid you already have — or over
spans a regex found in the text, it becomes a good fit, and the pre-parsed extraction
cookbook gives the guarantee that makes it safe: the answer is one of the spans you supplied,
copied unchanged, so the model "cannot invent a value or transpose a digit". Numeric
attributes need the further split: the regex finds `500ml`, jev decides which number is the
capacity, code parses and converts.

## What jev decides

Code prepares the answer space first, per attribute.

```
state = {"title": "Acme Trail 40L Hiking Backpack - Slate Grey, Ripstop Nylon",
         "description": "...",
         "amount_candidates": ["40L", "1.2kg", "60cm"]}

colour: Choice
  instructions: "Which colour does the listing state for the item itself?"
  criteria: {black: "...", grey: "...", blue: "...", ..., multicolour: "...",
             not_stated: "The listing does not state a colour for the item"}

material_primary: Choice
  criteria: {nylon: "...", polyester: "...", leather: "...", ..., not_stated: "..."}

capacity_value: Choice
  instructions: "Which of `amount_candidates` is the item's capacity?"
  criteria: {"40L": null, "1.2kg": null, "60cm": null, none: "No candidate is the capacity"}

is_for_children: Noul
  instructions: "Does the listing state the item is intended for children?"

colour_refers_to_accessory: Noul
  instructions: "Does the stated colour describe an accessory or the packaging rather than the item?"
```

Every Choice carries `not_stated` or `none`. Without it a Choice is relative and will name a
colour for a listing that mentions none — the single most common failure of this design.
Confidence gates whether the attribute is written to the grid or queued for the seller to
confirm; the cookbook's worked picks came back at 0.98 and 1.00, and low confidence on a
pick is the signal that the candidate list was wrong, not that the model was.

## What stays in code

Candidate generation (regex, unit parsers, the attribute value dictionary), unit conversion,
normalisation, and the write. Every numeric comparison — "is 40L within the cabin-bag
allowance" — is arithmetic and stays in code, per failure mode 2, which also warns that
numeric and coded representations (hex colour codes, size codes) perform worse than their
English names. If you hold `#708090`, convert it to "slate grey" before asking.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 700-character listing plus
six attribute questions whose option lists total ~2,500 characters is ≈ 800 tokens,
**≈ $0.000034 per listing** for all six attributes in one call. Attributes are the classic
fan-out case: the parallel-questions cookbook measured 13 questions in one call at 12.2x
cheaper and 10.0x faster than 13 calls, with identical means on 11 of 13. Latency 70–500 ms.
Published accuracy: none for product attributes. The nearest signal is TypeSafe's own eval
note that jev is "weakest on invoice-style precise extraction", which is a direct warning for
spec tables — build a labelled set of a few hundred listings before trusting the grid.

## When the verdict flips

- The attribute is open-ended (a model number, a free-text feature). No enumerable answer
  space, no Choice; use the cascade shape — a small LLM extracts, jev verifies each field
  against the source with a Noul, and only failures reach a reasoning model.
- The data is a dense spec table with dozens of numeric fields. This is the documented weak
  spot; keep a parser, use jev to verify.
- You need many attributes at high precision with no review. Precision extraction with no
  human band fails fit-test question 6.
- The value must be exact for pricing or compliance (net weight, alcohol content, voltage).
  Parse it; do not select it.

## Alternatives considered

- **Regex and dictionary matching alone.** Already half the solution, and it cannot decide
  which of three matches is the capacity, or that "grey strap" is not the item's colour.
- **Frontier LLM with a JSON schema.** Genuinely good at this and the default today; seconds
  and cents per listing, with a real risk of a plausible invented value — the failure mode
  that quietly corrupts a catalogue.
- **Small LLM.** Same risk, lower cost; the SDE cascade cookbook's answer is to keep it for
  extraction and put jev in front as the verifier, which is the best combination here.
- **Fine-tuned sequence tagger.** Highest precision per attribute with annotated listings;
  one model per attribute family and an annotation project to match.
- **Seller-supplied attributes.** Free and frequently wrong; jev is useful precisely for
  checking them against the title and description.

## Sources

Accessed 2026-09-19. `cookbooks/pre_parsed_value_extraction_cookbook.md` (find/pick/copy,
the no-invention guarantee, confidences under `jev-1.12`), `model-jaggedness/jev-1.13.md`
(modes 2 and 9), `concepts/use-case-map.md`, `cookbooks/sde_cascade.md`,
`cookbooks/parallel_questions.md`, `models.md`, `jev/00-ground-truth` eval note on
invoice-style extraction.
