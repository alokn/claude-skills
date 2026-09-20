---
id: uc-financial-crime-kyc-document-classification
title: Classify an uploaded KYC document by type from its extracted text
verdict: conditional
domain: financial-crime
decision_shapes: [classification, routing, extraction]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (financial crime: "Evaluate transaction narratives, KYC documents, and alert histories")
  - https://docs.typesafe.ai/models.md  (text only: string, JSON object, array of text; no images; 64k context; $0.042 per million input tokens, output free)
  - https://docs.typesafe.ai/cookbooks/date_extraction_cookbook.md  (date parts as Choice over enumerated components; code assembles and compares; 5 auto-accept / 1 review over six examples)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (confidence band at 0.9: 27/30 right when confident, 12/30 when not; answer one level coarser instead of abstaining)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (small model extracts, jev verifies each field, only failures escalate)
related: [uc-financial-crime-entity-matching-inconsistent-names, uc-financial-crime-alert-prioritisation-by-evidence-quality, cb-date_extraction_cookbook, cb-sde_cascade, df-rewrites]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify KYC documents?" Also asked as "can jev tell a
utility bill from a bank statement?", "can jev read a passport?", and "can we auto-file
onboarding uploads by document type?".

## Verdict

**Conditional**, and the condition is the whole answer: jev is text only — "Text only:
string, JSON object, array of text. No images/audio/video" — so something upstream must turn
the upload into text before jev sees anything. Given OCR output or an extracted text layer,
classifying the document into a closed set of KYC types is a clean Choice and a good fit.
Without it there is no use case at all, and "can jev read a passport?" is answered **no**.
The second half of the condition is that expiry and validity are date arithmetic: jev may
select the date components, code must do every comparison (failure mode 3). The closest
other failure mode is 5 — an OCR dump of a ten-page bank statement is mostly irrelevant
detail, so truncate to the first page or the header block in code.

## What jev decides

State: the first ~2,000 characters of extracted text plus the filename and page count. Not
the whole OCR dump.

```
document_type: Choice
  instructions: {question: "Which kind of document is `upload.text` extracted from?",
                 focus: "Classify the document itself, not what it is being used to prove."}
  criteria:
    passport:          {what: "A machine-readable travel document issued by a state",
                        not_for: "A visa or residence permit",
                        examples: ["P<GBRSMITH<<JOHN header line present"]}
    national_id_card:  {what: "A state-issued identity card", not_for: "A driving licence"}
    driving_licence:   {what: "A licence to drive issued by a state or region"}
    bank_statement:    {what: "A periodic statement of account transactions and balances",
                        not_for: "A single payment confirmation or receipt"}
    utility_bill:      {what: "A bill for electricity, gas, water, or fixed-line services at
                               a named address",
                        not_for: "A mobile phone bill, which many policies exclude",
                        examples: ["Account, meter reading, supply address, amount due"]}
    mobile_phone_bill: {what: "A bill for a mobile service"}
    tenancy_or_mortgage_statement: {what: "A tenancy agreement or mortgage account statement"}
    company_registry_extract: {what: "An extract from a corporate registry showing officers
                                      or ownership"}
    other:             {what: "A document none of the above describes"}
    unreadable:        {what: "The extracted text is too sparse or garbled to identify"}

text_is_garbled: Noul
  instructions: "Is `upload.text` mostly unreadable, for example dense strings of characters
                 that do not form words?"
address_is_present: Noul
name_is_present: Noul
```

`other` and `unreadable` are both needed: `other` because a Choice always names something,
`unreadable` because a bad scan should be diagnosed rather than guessed. `text_is_garbled` as
a separate Noul gives you an absolute signal to route on even when the Choice is confident,
which the Choice alone cannot provide.

Bands, following the classification-with-confidence cookbook, which measured "27/30 right"
above `confidence >= 0.9` and "12/30 right" below it on a 75-option taxonomy: at or above
0.90 file the document automatically; 0.60-0.90 file it under the coarser parent category
(`identity_document` / `proof_of_address` / `corporate_document`) and let an onboarding agent
confirm the leaf; below 0.60 queue it. Reporting one level up is the cookbook's own
alternative to abstaining, and it turned 40% correct into 70% useful on that dataset.

## What stays in code

OCR and text extraction. The acceptability policy — which types satisfy which requirement in
which jurisdiction — is a table, not a prompt. Expiry: jev picks day, month and year as a
Choice over enumerated components with an explicit "not stated" option, exactly as the date
extraction cookbook does with a year list spanning 1900 to 2050, and code assembles the date
and compares it to today. Document authenticity, tamper detection, MRZ checksum validation,
and any comparison of the document against sanctions or watch lists stay deterministic and
authoritative. Storage, retention and the audit record are code.

## Numbers

Method: `input_tokens ≈ (chars(state) + chars(questions)) / 4`; `cost = tokens × $0.042 /
1e6`, output free. 2,000 characters of extracted text plus a ten-option Choice with
contrastive criteria (~1,900 characters) and three Nouls (~400 characters) is about 4,300 / 4
≈ 1,075 tokens, so **≈ $0.000045 per document**. Adding the seven date-component Choices from
the date extraction cookbook in the same call costs tokens and little extra latency
("barely changes" in the docs, not zero). Published
comparators: the classification-with-confidence run used 60 filings, 75 industry groups,
`jev-1.12`, 2026-08-12, and reported "forced to name a group every time 39/60 right / of
those, the 30 it was sure about 27/30 right / and the 30 it was not 12/30 right / letting it
answer coarsely when unsure 48/60 useful answers". That is a different taxonomy and is not an
accuracy claim for KYC types — **accuracy on your document set is not published; measure it**
against the types your onboarding team has already filed. The date cookbook's six examples
routed as "auto-accept (5)" and "send to review (1)", the review case being "the date of the
kickoff call (conf 0.46 / absolute date incomplete)"; cost and latency there: not reported.

## When the verdict flips

- To `no` with no OCR or text layer. Text only, no exceptions.
- To `no` if the question is really "is this document genuine". Forgery detection is a
  pixel-level and cryptographic problem; jev sees only what the text says.
- To `weak` if your upload widget already asks the customer which document they are
  uploading and your false-declaration rate is low. Then it is a form field, not a judgement
   — though a cheap disagreement check ("does the type the customer selected match the text?")
  is a legitimate small win.
- To `conditional` on tighter terms for non-Latin scripts and non-English documents; run your
  own evaluation per language before trusting the band.

## Alternatives considered

- **Regex on the extracted text.** Genuinely strong here: MRZ prefixes, IBAN patterns and
  issuer strings are lexical and exact. Run them first and only call jev when they miss.
- **Document-AI services (Textract, Document AI, Azure DI).** Purpose-built, handle the image
  and the classification together, and return field-level boxes. Where you already pay for
  one, jev's role shrinks to verifying its output — the SDE cascade shape.
- **Small LLM with vision.** Solves the input-modality problem jev cannot; slower and dearer,
  and its free-text output needs parsing.
- **Fine-tuned image classifier.** Best pure accuracy on a fixed document set, and blind to
  the text content.
- **Embeddings over extracted text.** Workable for near-duplicate detection, weak on type.
- **Human onboarding review.** Stays for the low band and for anything `unreadable`.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (KYC documents named), `models.md` (text
only; price; context), `cookbooks/date_extraction_cookbook.md` (components as Choice, year
range 1900-2050, 5 auto-accept / 1 review), `cookbooks/classification_using_confidence.md`
(60 filings, 75 groups, jev-1.12, 2026-08-12, band figures), `cookbooks/sde_cascade.md`
(extract then verify), `model-jaggedness/jev-1.13.md` (dates; context rot).
