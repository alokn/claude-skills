---
id: uc-verification-invoice-three-way-match
title: Advise on the invoice lines a deterministic three-way match could not clear
verdict: conditional
verdict_as_asked: no
domain: verification
decision_shapes: [verification, detection, classification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 2 arithmetic, mode 3 "Reads dates as text, not as ordered quantities")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input)
  - https://pearpages.com  (second-hand, via 00-ground-truth/evidence-independent.md: TypeSafe's own invoice number reported as "61.8% vs Terra 74.7%", 2026-09-16)
related: [au-invoice-three-way-match-by-jev, au-numeric-thresholds-and-arithmetic, au-date-ordering-and-overdue, uc-verification-extraction-field-verification, uc-financial-crime-entity-matching-inconsistent-names, uc-verification-document-completeness-checklist]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for invoice matching?" Also: "can jev do our three-way match
against the PO and the goods receipt?", "can it tell us this line item is already on last
month's invoice?", "can jev check the contract allows this charge?".

## Verdict

The question as asked — "can jev do our three-way match against the PO and the goods
receipt?" — is answered **no**, in `au-invoice-three-way-match-by-jev`. An
accounts-payable match is arithmetic wearing a document costume, and arithmetic and
"Reads dates as text, not as ordered quantities" are the two jaggedness modes the docs
name outright. **Every amount, tax, total, quantity, unit price and date comparison stays
in code**, and jev never approves a payment.

**This entry describes the residue, and its verdict is conditional:** the small set of
genuinely semantic questions left after code has done the sums — does this line item
describe the goods the PO ordered, does the contract's scope clause cover this charge, is
this narrative the same work as last month's. Those are a good fit as an advisory layer
beside the deterministic match, on the exception lines only, never as the approval. Hold
it advisory: a public comparison put TypeSafe's own invoice-task number at "61.8% vs
Terra 74.7%", reported **second-hand** via pearpages.com (2026-09-16) and recorded in this
corpus's independent-evidence file, with no method or sample size available.

## What jev decides

Code has already extracted and matched the structured fields and computed every difference.
Jev is asked only what a comparison cannot answer, one call per unmatched invoice line:

```
same_goods_or_service: Noul
  instructions: {question: "Do `invoice_line_description` and `po_line_description` describe
                            the same goods or service?",
                 focus: "What was supplied, not how it is worded or coded."}
  true:  "The same item or service, in different words, abbreviations, a supplier's own
          catalogue name, or a different level of detail."
  false: "A related item from the same family, a different model, grade or period, or an
          add-on to the PO line rather than the line itself."
charge_type_permitted: Noul
  instructions: "Does `contract_extract` permit a charge of this kind?"
  false: "The contract is silent on it, or permits it only under a condition the extract does
          not show as met."
rebill_of_prior_line: Noul
  instructions: "Does this line describe work already billed on `prior_invoice_lines`?"
exception_reason: Choice
  criteria: [description_mismatch, quantity_or_price_variance_explained_by_text,
             charge_not_in_contract, possible_duplicate, no_exception_found]
```

`no_exception_found` must exist, or the Choice becomes relative and will name an exception on
a clean invoice.

## What stays in code

The entire match: PO lookup by number, goods-receipt reconciliation, unit price times quantity,
tax, totals, currency conversion, the tolerance band, and whether the invoice date falls inside
the contract term. Duplicate detection by invoice number and by (supplier, amount, date) hash.
The approval, the posting to the ledger, and the payment run. Segregation-of-duties controls.
None of this is a judgement and none of it goes near the model.

## Numbers

Cost by method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Per
exception line, a state of ~2,500 characters (invoice line, PO line, contract extract, prior
lines) plus four questions with criteria (~2,500 characters) is about 1,250 tokens, **≈
$0.0000525 per line**. Call only on lines code could not match, which on a typical AP ledger is
a small minority — that ratio, not the unit cost, is the economics.

The only task-adjacent accuracy figure available is second-hand and unmethodical: "61.8% vs
Terra 74.7%" for TypeSafe's own invoice number, via pearpages.com. Treat it as a reason for
advisory-only deployment, not as a measurement of this decomposition. Your own labelled set is
the AP team's disposition history: every exception they cleared and every one they returned.

## When the verdict flips

- **Any number goes into the question.** "Is $4,812.40 close enough to $4,810.00?" is
  arithmetic and belongs to code; asking it is `no` — `au-invoice-three-way-match-by-jev`.
- **Any date ordering goes into the question** ("is this invoice within terms?"). Mode 3.
- **It approves or releases payment.** Financial authorisation on a probability is not a
  supported use; keep a human or a deterministic rule on the release.
- **You send the whole invoice PDF text and the whole contract.** Mode 5, and the 32k state
  will not hold a master services agreement. Retrieve the clause in code first.
- **Scanned or image invoices.** Text-only input; OCR is a separate, earlier problem.

## Alternatives considered

- **Deterministic three-way match with tolerances.** The incumbent, and it stays. It clears
  the large majority of lines exactly and for free; jev only sees what it could not.
- **Fuzzy string match on descriptions.** Free and decent on abbreviations; cannot tell a
  different model number from a different wording, which is the expensive error.
- **Supplier catalogue / item-code mapping.** Better than both when the mapping exists; the
  work is maintaining it.
- **Frontier LLM.** Can read the contract clause and explain the exception, which matters for
  the AP reviewer's note; seconds and cents per line, and it is no better at the arithmetic.
- **AP automation vendors.** Purpose-built, with the arithmetic already correctly placed in
  code; the realistic competitor.
- **The AP clerk.** The control this prioritises for, and the approver it must not replace.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://pearpages.com — second-hand via `00-ground-truth/evidence-independent.md`, accessed 2026-09-19 (original post dated 2026-09-16)
