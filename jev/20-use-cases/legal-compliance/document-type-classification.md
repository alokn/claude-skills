---
id: uc-legal-compliance-document-type-classification
title: Classify an inbound legal or regulatory document by type, with a coarser answer when unsure
verdict: good
domain: legal-compliance
decision_shapes: [classification, routing]
primitives: [choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (75 SIC industry groups over 60 filings; "a Choice works reliably up to roughly 240 options"; 0.9 band split; coarser answer when unsure; jev-1.12 on 2026-08-12)
  - https://docs.typesafe.ai/cookbooks/hierarchical_classification.md  (beam search over Choice probabilities for deep taxonomies)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (legal and compliance: "Classify contracts, policies, regulatory filings, and marketing claims")
  - https://docs.typesafe.ai/primitives/choice.md  (Choice up to 255 options; probabilities and confidence)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-legal-compliance-contract-clause-presence, uc-legal-compliance-policy-violation-detection, cb-classification_using_confidence, cb-hierarchical_classification, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify inbound legal documents by type?" Also asked as
"can jev tell an NDA from an MSA from a DPA in our contract intake?", "can jev label
regulatory filings by form type?", and "what do we do when the classifier is not sure?".

## Verdict

**Good** — the shape is demonstrated by the `classification_using_confidence` cookbook,
whose 60 labelled filings measure SIC industry group rather than document type; no
task-matched labelled accuracy is published; shadow-evaluate against the incumbent
before acting. TypeSafe publishes a cookbook on precisely this shape — a single `Choice`
over a large flat taxonomy of documents, with confidence used to decide whether to
report the leaf label or fall back one level up the hierarchy. It is measured, on 60
real filings, and the lesson it teaches is the one that makes document classification
safe in production: do not force a leaf label when the model is not sure; answer
coarsely instead. Code owns the intake routing; the confidence value gives a principled
abstention; the input is text and short after code selects the first page and the title
block.

## What jev decides

State: the document title, the first ~2,000 characters, any form number printed on it, and
the filename. Not the full document — the type is almost always decided in the first page,
and a 60-page annex is nothing but distractors (failure mode 5).

```
document_type: Choice
  instructions: {question: "What type of document is `doc`?",
                 focus: "Classify the instrument, not its subject matter."}
  criteria:
    nda:  {what: "A standalone confidentiality or non-disclosure agreement",
           not_for: "A confidentiality clause inside a larger commercial agreement",
           examples: ["Mutual Non-Disclosure Agreement", "Confidentiality Undertaking"]}
    msa:  {what: "A master agreement setting general terms for future orders or SOWs",
           not_for: "A single-scope services contract with no ordering mechanism",
           examples: ["Master Services Agreement", "Master Supply Agreement"]}
    dpa:  {what: "A data processing agreement or addendum governing personal data",
           not_for: "A privacy policy, which is a published notice rather than an agreement",
           examples: ["Data Processing Addendum", "Standard Contractual Clauses"]}
    sow:  {what: "A statement of work or order form issued under a master agreement", ...}
    policy: {what: "An internal or published policy document, not a bilateral agreement", ...}
    other:  {what: "Anything none of the above describes"}
```

`other` is mandatory. A Choice is relative and always names something, so without it a
shareholders' agreement lands in `msa` at high confidence — the structural-invariants note
on the jaggedness page is the general form of this trap.

Bands, following the cookbook: at `confidence ≥ 0.9` report the leaf type and route
automatically. Below 0.9, do not report the leaf — report the parent group (agreement /
notice / filing / internal document) and route to the generalist queue. That is the
cookbook's own policy, and it is what turns a wrong answer into a less precise but still
useful one. For a taxonomy deeper than two levels, use the hierarchical-classification
cookbook's beam search over Choice probabilities rather than one flat 200-option question.

## What stays in code

The parent-of-leaf mapping used for the coarse fallback. Any form number, EDGAR form type,
or document-management ID that already identifies the document — if a deterministic field
names the type, do not spend a call. Deduplication against documents already on file.
Retention schedules and statutory deadlines, which are date arithmetic. The routing itself
and every write to the DMS.

## Numbers

From `cookbooks/classification_using_confidence.md`, run on `jev-1.12`, 2026-08-12, over 75
SIC industry groups (within 10 divisions and 444 industries) across 60 filings, one request
per document. The cookbook states "a Choice works reliably up to roughly 240 options, and 75
is well inside that", against the hard cap of 255. A confidence cutoff of 0.9 "splits them
in half", and the result table, verbatim:

```
forced to name a group every time      39/60 right
  of those, the 30 it was sure about  27/30 right
  and the 30 it was not           12/30 right

letting it answer coarsely when unsure  48/60 useful answers
```

And in prose: "The confident half is right 90% of the time; the other half, 40%. Reported one
level up, that 40% becomes 70%." Those numbers are for SIC industry groups on SEC filings,
not for your document taxonomy; they are evidence for the *policy*, not a forecast of your
accuracy. Cost and latency are not reported in that cookbook.

Your cost: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
2,000-character excerpt plus a six-option Choice with contrastive criteria (~1,500
characters) is about 875 tokens, so **≈ $0.00004 per document**. Latency 70–500 ms, "most
queries about 100 ms". Your own accuracy: measure it against the type labels already in your
DMS, which are a free labelled set.

- Field evidence (community-report): a tax document classifier assigns IRS form type from extracted text as a flat Choice over the form catalogue; no numbers published, and the form number itself is an exact-match lookup that should stay in code where it is printed on the page, 2026-09. Source: https://github.com/kyotofin/tax-doc-classifier

## When the verdict flips

- The type is already in structured metadata (a form number, an intake form field, a
  template id). Lexical lookup wins; do not add a model.
- More than ~240 types. The cookbook's own ceiling; go hierarchical, which changes the shape
  of the integration.
- The type determines an irreversible retention or destruction action. Then the Choice is an
  input, and the deletion gate stays deterministic with a human.
- Scanned documents with no text layer. Jev is text only; OCR first, and expect the coarse
  fallback band to grow.

## Alternatives considered

- **Regex on the title / form number.** Exact and free where the title is standardised, which
  in contract intake it is not. Keep it as the first-pass short-circuit.
- **Small LLM (Haiku-class).** Comparable on this shape at seconds and cents; it gives no typed per-class
  probability to build the coarse-fallback policy on unless you read logprobs.
- **Frontier LLM.** Overqualified. Worth reserving for the documents that land in the coarse
  band and matter.
- **Fine-tuned classifier.** The strongest competitor if your type list is frozen and you have
  thousands of labelled documents — which, for a DMS, you probably do. Jev wins when types are
  added by editing a string, and on a per-class probability the coarse-fallback
  policy can threshold; the threshold policy itself is yours to define either way.
- **Embeddings + nearest centroid.** Workable, needs a threshold per class, and degrades on
  short or template-heavy documents that all look alike in embedding space.
- **Human intake clerk.** Stays for the coarse band. The number to track in shadow mode is the
  share of documents that clear 0.9, because that is the share that stops reaching them.

## Sources

Accessed 2026-09-19. `cookbooks/classification_using_confidence.md` (75 groups, 60 filings,
0.9 split, 27/30 vs 12/30, 48/60 useful answers, ~240-option guidance; `jev-1.12`,
2026-08-12), `cookbooks/hierarchical_classification.md` (deep taxonomies),
`concepts/use-case-map.md` (classify contracts, policies, filings), `primitives/choice.md`
(255-option cap, confidence), `models.md` (price, latency).
