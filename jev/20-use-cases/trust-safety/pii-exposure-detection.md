---
id: uc-trust-safety-pii-exposure-detection
title: Detect personal-data exposure in user content and AI output
verdict: conditional
domain: trust-safety
decision_shapes: [detection, verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (guardrails: "Identify policy violations and sensitive-data exposure"; moderation: "personal-data exposure")
  - https://docs.typesafe.ai/cookbooks/pre_parsed_value_extraction_cookbook.md  (a regex finds candidates, jev picks and classifies; "it cannot invent a value or transpose a digit")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9: extraction is not a jev task; failure mode 6: not the sole security gate)
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (screen every message in and out; thresholded routing)
related: [uc-trust-safety-policy-violation-bands, uc-support-response-quality-check, uc-commerce-attribute-extraction]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect PII?" Also "can jev find personal data in support
tickets before we log them?", "can jev stop our AI agent leaking someone's address?", and
"can jev replace our PII scanner?".

## Verdict

**Conditional**, and the condition splits the problem in two. *Finding and masking* the
strings is deterministic work — a regex or a named-entity recogniser locates a 16-digit
number, code redacts it, and jev must not be asked to return the value because free-form
extraction is failure mode 9. *Judging exposure* is where jev earns its place: whether a
detected identifier belongs to a third party rather than the author, whether a passage
identifies someone without containing a formal identifier ("the night nurse on ward 4 last
Tuesday"), and whether an AI reply has disclosed account data that was not in the requester's
own record. Build it as detector-plus-judge and it is a good fit; build it as "ask jev for
the PII" and it is the wrong tool.

## What jev decides

Code runs the detectors first and passes their findings as structured candidates.

```
state = {"text": "...",
         "detected": [{"kind": "email", "span": "dana.personal@gmail.com"},
                      {"kind": "number16", "span": "4111 1111 1111 1111"}],
         "requester_record_fields": ["name", "order_id", "shipping_city"]}

third_party_subject: Noul
  instructions: "Does `text` disclose personal details about someone other than the author?"
  criteria:
    true:  {what: "Names or identifies another living person and states something about them"}
    false: {what: "Only the author's own details, or a public figure in a public capacity"}

identifies_without_identifier: Noul
  instructions: "Could a reader identify a specific individual from `text` even though no name,
                 email, or account number appears?"

special_category: Choice
  instructions: "Which category of sensitive personal data does `text` reveal, if any?"
  criteria: {none: "...", health: "...", financial: "...", biometric_or_genetic: "...",
             political_religious_or_union: "...", sexual_life_or_orientation: "...",
             criminal_record: "...", other: "..."}

reply_discloses_beyond_record: Noul
  instructions: "Does `draft_reply` state personal information that is absent from
                 `requester_record_fields`?"

consent_or_publication_evident: Noul
  instructions: "Does `text` state that the person consented to sharing, or that the information
                 is already public?"
```

Bands: the guardrails shape applies — above the action threshold, block or redact and log;
in the middle, hold for review; below, pass. For `reply_discloses_beyond_record` in an AI
support agent, treat the review band as a block, because the cost of a wrong send is
asymmetric.

## What stays in code

Detection, masking, hashing, retention and deletion. Luhn checks, IBAN checksums, national
ID formats and email syntax are exact and must not be delegated. So is the redaction itself:
jev selects among spans the regex found (the pre-parsed extraction cookbook's guarantee is
that the answer is a copy of a span, never a re-typed value), and code performs the
substitution. Access control, encryption, and the legal basis for processing are not
semantic questions.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 1,500-character message plus
detector findings plus these five questions (~1,500 characters) is ≈ 750 tokens,
**≈ $0.000032 per item**. Running it on every outbound AI reply adds well under a tenth of a
percent to the cost of generating that reply. Latency 70–500 ms. The pre-parsed extraction
cookbook is the closest published run and reports per-pick confidences rather than a metric —
`receipt -> dana.personal@gmail.com (conf 0.98)`, `sender -> dana.whit@acme-corp.com (conf
1.00)` on a four-candidate email document under `jev-1.12`. **No precision or recall for PII
detection is published anywhere in the docs.** Measure yours against a labelled corpus; for a
compliance control, an unmeasured detector is not a control.

## When the verdict flips

- You use jev as the PII detector, with no regex or NER layer. Then a missed identifier is a
  breach and the verdict is **no**.
- The obligation is regulatory and requires demonstrable coverage. Deterministic detectors
  are auditable; a probability is not, and the fit test's counter-signal on safety and legal
  invariants applies.
- The content is adversarial — someone deliberately splitting an identifier across lines to
  evade detection. Failure mode 6; normalise in code first.
- Scanning whole documents in one call. Context rot (failure mode 5) plus the 32k state limit;
  chunk, and use a relevance Noul to filter, as the RAG-passage cookbook does.

## Alternatives considered

- **Regex and checksum detectors.** The backbone, and unbeatable on structured identifiers.
  Blind to "the patient in room 12" and to whose data it is.
- **NER model (spaCy, Presidio).** Good at names, places and organisations, and the right
  partner for jev: it produces the candidates, jev judges the exposure.
- **Frontier LLM.** Reads context best, and asking an LLM to *return* the PII means sending it
  the PII and getting a generated string back — which is both a cost and a risk surface.
- **Small LLM.** Same shape, seconds and cents per document, and it can hallucinate a
  redaction that changes the meaning.
- **Human DPO review.** The destination for the middle band; this sizes that band.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`,
`cookbooks/pre_parsed_value_extraction_cookbook.md` (select-don't-generate guarantee;
confidences under `jev-1.12`), `model-jaggedness/jev-1.13.md` (modes 5, 6, 9),
`cookbooks/llm_guardrails.md`, `models.md`.
