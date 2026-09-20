---
id: uc-legal-compliance-regulatory-requirement-verification
title: Verify a document against explicit regulatory requirements, one Noul per requirement
verdict: good
domain: legal-compliance
decision_shapes: [verification, detection]
primitives: [noul, choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (eight citations against RFC 7519; string match first, then a three-option Choice; AUTO_ACCEPT = 0.8; verdicts and confidences verbatim; jev-1.12 on 2026-08-16)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (legal and compliance: "Verify documents against explicit legal or compliance requirements")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (atomic questions; name the state path)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 4 indirection; failure mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 32k state limit)
related: [uc-legal-compliance-contract-clause-presence, uc-legal-compliance-regulatory-briefing-parallel-questions, uc-legal-compliance-policy-violation-detection, cb-citation_check, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to verify a document meets a list of regulatory
requirements?" Also asked as "can jev check our filing against the rule's checklist?", "can
jev tell us whether the cited passage actually supports the claim we made?", and "can we
automate the evidence check in our compliance sign-off?".

## Verdict

**Good** — the shape is demonstrated by the `citation_check` cookbook; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
TypeSafe publishes a worked version of exactly this shape: the citation-check cookbook
takes eight citations against RFC 7519, uses an ordinary string match to catch quotes
that are not in the source at all, and then asks one `Choice` per surviving citation
about how the source section relates to the claim. That is requirement verification with
the parts in the right places — code does the exact matching, jev does the reading
comprehension, and a confidence threshold decides whether a human confirms. The decision
is single-hop per requirement, the answer space is three options, and the low-confidence
path is a person. All seven fit-test questions pass.

## What jev decides

State per requirement: the requirement text and the one document section code selected for
it. The cookbook's state is `{"claim": ..., "section": ...}` and nothing else, which is the
whole reason it works — failure mode 5 is what you get if you paste the regulation and the
filing together and ask once.

```
relation: Choice
  instructions: "How does the section relate to the requirement?"
  criteria:
    supports:     "The section states the requirement is met or directly implies that it is"
    contradicts:  "The section states the opposite, or implies the requirement is not met"
    says_nothing: "The section does not address what the requirement asserts, either way"
```

The cookbook's own criteria are the same three, phrased for a claim rather than a
requirement: `supports` — "The section states the claim or directly implies that it is
true"; `contradicts` — "The section states the opposite of the claim or implies it is
false"; `says_nothing` — "The section does not address what the claim asserts, either way".
Code maps them onto verdicts via `RELATION_TO_VERDICT`: `verified`, `contradicted`,
`unsupported`; a fourth verdict, `fabricated`, never reaches the model at all.

Bands: the cookbook sets `AUTO_ACCEPT = 0.8` with the comment "start high for more human
review as you build trust in the model". At or above 0.8 "the verdict stands on its own";
below 0.8 "a human confirms the verdict before anything acts on it".

Where a requirement is really several conditions ("discloses X, in the same document, within
Y days"), split it. Three literal questions combined in code beat one question that needs
two hops (failure mode 4); the date part is arithmetic and never goes to the model.

## What stays in code

The exact match. In the cookbook, "A quote that is not in the source is fabricated, and no
model is needed to find that out" — `normalize()` collapses whitespace and folds curly
quotes, `find_quote()` looks for the substring, and a miss is decided without an API call.
Section splitting. The requirement register itself. Statutory deadlines, filing windows and
notice periods — all date arithmetic. Monetary and percentage thresholds. The sign-off
record, and the sign-off itself.

## Numbers

From the cookbook, `jev-1.12` on 2026-08-16, source RFC 7519 at "58,365 characters, 45
numbered sections, 8 citations". The full run, verbatim:

```
epoch_seconds     found         supports        0.93  verified        auto
aud_reject        found         supports        0.95  verified        auto
sig_reporting     missing       -                  -  fabricated      auto
clock_skew        found         supports        0.99  verified        auto
exp_required      found         contradicts     0.99  contradicted    auto
pii_encryption    found         says_nothing    0.27  unsupported   review
iat_future        section-only  says_nothing    0.56  unsupported   review
duplicate_names   found         supports        0.99  verified        auto
```

"Four citations came back `verified`, one `fabricated`, one `contradicted`, and two
`unsupported`." The four accurate ones "all of them came back `verified` at confidence 0.93
or higher, well above `AUTO_ACCEPT`"; `pii_encryption` and `iat_future` "came back
`unsupported` at 0.27 and 0.56, both under the threshold, so both went to a human". Note
`pii_encryption` — "its quote is in the source word for word, and the section it came from
says nothing about the claim" — which is why the string match alone is not enough.

Cost for your own run: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free.
A 3,000-character section plus a 200-character requirement and this Choice (~400 characters)
is about 900 tokens, so **≈ $0.00004 per requirement-section pair**. Latency 70–500 ms per
call; the pairs parallelise. No accuracy figure beyond this eight-row demonstration exists —
measure it on your own register.

## When the verdict flips

- Compliance turns on a calculation (capital ratios, thresholds, accrual periods). Compute
  in code; jev may select the candidate figure, never compare it.
- The requirement needs synthesis across five sections and an external rulebook. That is
  multi-hop; retrieve the sections in code and ask one question each, or escalate to a
  reasoning model.
- Verification is the sole gate on a regulatory filing. Keep a human sign-off; a probability
  trained to be calibrated is not an attestation.
- Your citations are paraphrased rather than quoted. The cookbook warns that "a quote that
  is truncated or lightly reworded comes back as `fabricated`", and "a production system
  that tolerates sloppy quoting would need fuzzy matching instead" — that fuzzy matching is
  code you have to write.

## Alternatives considered

- **Regex / string match.** Already in the design, and it does the job it is good at. It
  cannot tell `supports` from `says_nothing`, which is the whole point of the second step.
- **Small LLM (Haiku-class).** Can produce the same three labels, at seconds and with a
  parse step; the cookbook's per-call latency for jev on this shape is inside the same
  request path as your UI.
- **Frontier LLM.** Better where the requirement needs synthesis; that is the escalation
  target for the sub-0.8 band, not the default path.
- **Fine-tuned entailment model (NLI).** A genuine competitor — this is textual entailment.
  It wins if you have labelled pairs and a fixed requirement set; jev wins on being editable
  and on returning a confidence you can gate on — probabilities trained to be
  calibrated, with calibration measured on your data.
- **Embeddings.** Retrieve the candidate section, yes. Decide support, no: similarity does
  not distinguish "supports" from "contradicts", which the cookbook's `exp_required` row
  shows at 0.99.
- **Human reviewer.** Stays for everything under the threshold and for the final
  attestation. The measured effect is that 6 of 8 rows in the cookbook needed no human.

## Sources

Accessed 2026-09-19. `cookbooks/citation_check.md` (run table, AUTO_ACCEPT, verdict mapping,
string-match step, fuzzy-quote caveat; `jev-1.12` on 2026-08-16),
`concepts/use-case-map.md` (verify documents against explicit requirements),
`concepts/how-to-build-with-system-one.md`, `model-jaggedness/jev-1.13.md` (modes 3, 4, 5),
`models.md` (price, limits).
