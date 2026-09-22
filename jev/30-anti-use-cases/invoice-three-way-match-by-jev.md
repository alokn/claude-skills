---
id: au-invoice-three-way-match-by-jev
title: Do not run the invoice three-way match through jev
verdict: no
domain: verification
decision_shapes: [verification, classification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 2 arithmetic, "Jev is not a calculator"; mode 3 "Reads dates as text, not as ordered quantities")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input)
  - https://pearpages.com  (second-hand, via 00-ground-truth/evidence-independent.md: TypeSafe's own invoice number reported as "61.8% vs Terra 74.7%", 2026-09-16)
related: [uc-verification-invoice-three-way-match, au-numeric-thresholds-and-arithmetic, au-date-ordering-and-overdue, au-payments-and-access-control-decision, au-free-form-value-extraction]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for invoice matching?" Also: "can jev do our three-way match
against the PO and the goods receipt?", "can it check the totals line up?", "can jev approve
the invoice if everything matches?".

## Verdict

**No.** An accounts-payable three-way match is arithmetic wearing a document costume —
amounts, tax, totals, quantities, unit prices, tolerance bands and dates — and those are the
two failure modes the docs name outright: jev "is not a calculator", and it "Reads dates as
text, not as ordered quantities". A deterministic matcher already does this exactly, for
free, and produces an auditable trail an AP control can rest on. What is left *after* code
has done the sums — does this line describe the goods the PO ordered, does the contract's
scope cover this charge — is a genuine semantic residue with a different verdict:
`uc-verification-invoice-three-way-match` (`conditional`, advisory only).

## What jev would get wrong

Every comparison you would most like it to make. "Is $4,812.40 close enough to $4,810.00
given a 2% tolerance?" is subtraction and a threshold; "is this invoice inside the contract
term?" is date ordering; "does the sum of the lines equal the header total?" is addition over
a list, which also involves counting. A wrong answer here is not a mis-sorted queue, it is a
payment made twice or a duplicate invoice cleared.

The one task-adjacent accuracy figure available is unflattering and weak in equal measure: a
public comparison put TypeSafe's own invoice number at **"61.8% vs Terra 74.7%"**, reported
**second-hand** via pearpages.com (2026-09-16), with no method or sample size available. It
is not evidence of a specific defect; it is a reason not to lean on the model for the part
that a matcher already gets right every time.

There is also a shape problem: a real invoice, PO, goods receipt and master services
agreement will not fit in the 32k state (failure mode 5), and scanned invoices do not fit at
all — input is text only.

## What stays in code

The entire match: PO lookup by number, goods-receipt reconciliation, unit price times
quantity, tax, totals, currency conversion, the tolerance band, and whether the invoice date
falls inside the contract term. Duplicate detection by invoice number and by
(supplier, amount, date) hash. The approval, the ledger posting, the payment run, and
segregation-of-duties controls.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. An exception
line with its PO line, contract extract and prior lines (~5,000 characters with questions) is
about 1,250 tokens, ≈ **$0.0000525 per line** — cheap, and irrelevant: the deterministic
matcher costs nothing and is right by construction on the numeric part. **No first-party or
independent accuracy figure exists for jev on three-way matching**; the only adjacent number
is the second-hand "61.8% vs Terra 74.7%" above, which has no stated method or sample size.
Your own labelled set is the AP team's disposition history.

## When the verdict flips

It flips to **conditional** for the residue only, once code owns every number and date:
does the invoice line describe the same goods as the PO line, does the contract permit a
charge of this kind, is this narrative the same work as last month's. Call jev only on the
lines the matcher could not clear, treat the answers as notes for the AP clerk, and keep the
approval with a human or a rule — `uc-verification-invoice-three-way-match`. It never flips
to jev releasing payment (`au-payments-and-access-control-decision`).

## Alternatives considered

- **Deterministic three-way match with tolerances.** The incumbent and the authority; clears
  the large majority of lines exactly and for free.
- **Fuzzy string match on descriptions.** Decent on abbreviations; cannot separate a different
  model number from a different wording.
- **Supplier catalogue / item-code mapping.** Better than both where the mapping exists.
- **AP automation vendors.** Purpose-built, with the arithmetic correctly placed in code.
- **Frontier LLM.** Can explain an exception; no better at the arithmetic, seconds per line.
- **The AP clerk.** The approver of record.

## Sources

- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
- https://pearpages.com — second-hand via `00-ground-truth/evidence-independent.md`, accessed
  2026-09-20 (original post dated 2026-09-16)
