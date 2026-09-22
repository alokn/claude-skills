---
id: cb-citation_check
title: Double-checking citations
url: https://docs.typesafe.ai/cookbooks/citation_check.md
decision_shapes: [verification, classification]
primitives: [choice]
related: [uc-verification-citation-supports-claim, uc-verification-llm-output-policy-check, uc-agents-harness-tool-call-trace-verification, uc-support-policy-supports-request, au-exact-lookup-and-id-matching]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Catch wrong or hallucinated citations attached to an LLM's answer. Each citation names a
section of a source document and the quote a claim rests on. The check is two stages: an
ordinary string match finds quotes that are not in the document at all, then one `Choice`
question reads the surviving quote's context and decides whether it supports the claim.
`check_citation()` returns one of four verdicts - `verified`, `unsupported`,
`contradicted`, `fabricated` - plus a confidence that flags cases for human review.

Dataset: RFC 7519 (JSON Web Token), "fetched from rfc-editor.org and committed next to this
cookbook as `rfc7519.txt`", plus eight citations in `citations.json` "written by an LLM
against the RFC. Four are accurate; we edited the other four to fail the check." Parsed
size: "58,365 characters, 45 numbered sections, 8 citations". "Numbers below came from
`jev-1.12` on 2026-08-16."

## Decomposition (state, questions, how answers are combined)

State is two fields, the claim and the section text the string match located:

```python
state={"claim": claim, "section": section}
```

One question, `relation`, a `Choice` with three criteria:

```python
"relation": Choice(
    instructions="How does the section relate to the claim?",
    criteria={
        "supports": "The section states the claim or directly implies that it is true",
        "contradicts": "The section states the opposite of the claim or implies it is false",
        "says_nothing": "The section does not address what the claim asserts, either way",
    },
)
```

Code does the locating and the mapping. `locate()` returns `"missing"` (quote not found
anywhere after whitespace and curly-quote normalization), `"found"` (with the section that
contains it), or `"section-only"` (the citation quotes nothing, so the named section is
passed straight through). A `"missing"` citation never reaches jev: it is marked
`fabricated` with `"confidence": None`, "no model was called, so there is no model
confidence to report". Otherwise the highest-probability option maps through
`RELATION_TO_VERDICT = {"supports": "verified", "contradicts": "contradicted",
"says_nothing": "unsupported"}`.

Confidence band: one threshold, `AUTO_ACCEPT = 0.8`, with the comment "start high for more
human review as you build trust in the model". The rule is `answer["confidence"] >=
AUTO_ACCEPT`: "confidence at or above 0.8: the verdict stands on its own; below 0.8: a
human confirms the verdict before anything acts on it. Start high, and lower the threshold
as you see how the model does on your own documents."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Run: `jev-1.12`, 2026-08-16. Client `timeout=120.0`.

| citation | quote | relation | conf | verdict | action |
|---|---|---|---|---|---|
| epoch_seconds | found | supports | 0.93 | verified | auto |
| aud_reject | found | supports | 0.95 | verified | auto |
| sig_reporting | missing | - | - | fabricated | auto |
| clock_skew | found | supports | 0.99 | verified | auto |
| exp_required | found | contradicts | 0.99 | contradicted | auto |
| pii_encryption | found | says_nothing | 0.27 | unsupported | review |
| iat_future | section-only | says_nothing | 0.56 | unsupported | review |
| duplicate_names | found | supports | 0.99 | verified | auto |

"Four citations came back `verified`, one `fabricated`, one `contradicted`, and two
`unsupported`." The four accurate ones "came back `verified` at confidence 0.93 or higher,
well above `AUTO_ACCEPT`". "All four planted failures were caught: a fabricated quote, a
contradicted claim, and two unsupported citations sent to a human." Section sizes fed to
the model ranged from 270 to 3,122 characters. `exp_required` "is `contradicted`, at
confidence 0.99"; `pii_encryption` and `iat_future` "came back `unsupported` at 0.27 and
0.56, both under the threshold".

Cost: not reported. Latency: not reported (per-call `seconds`, `input_tokens` and
`output_tokens` are captured in the cached record but no figure is printed). Number of
repeats: not reported - each citation is checked once. No comparison against any named LLM
is run.

## Caveats the cookbook itself states

- The sample is eight citations on one document, with the four failures planted by the
  authors rather than observed in the wild.
- "The string match is exact after normalization: a quote that is truncated or lightly
  reworded comes back as `fabricated`. A production system that tolerates sloppy quoting
  would need fuzzy matching instead."
- "`load_source()` and `split_sections()` are written for an RFC's layout, so a document of
  another shape needs its own parsing."
- The 0.8 threshold is not tuned: "start high for more human review as you build trust in
  the model", and lower it "as you see how the model does on your own documents".
- The string match alone is not sufficient: `pii_encryption` "shows why the string match is
  not enough on its own: its quote is in the source word for word, and the section it came
  from says nothing about the claim."

## Lessons transferable to other use cases

- Cheap deterministic filter first, model second. An exact substring match after
  normalization decides `fabricated` with no API call; jev is only asked the question code
  cannot answer.
- One `Choice` with mutually exclusive criteria replaces a three-way judgment. The three
  options are the three ways a section can relate to a claim, so the verdict map is a
  dictionary lookup.
- Confidence as a routing signal, not an accuracy claim: a fixed band splits auto-accept
  from human review, and the low-confidence cases here (0.27, 0.56) were exactly the
  ambiguous ones.
- Pass the surrounding context, not the quote. The quote's presence is already established
  by code; what the model reads is the section, which is what makes `contradicted`
  detectable.
- Does not generalise: the document parser, and the assumption that legitimate quotes are
  verbatim. Paraphrased citations break the first stage before jev sees them.

## Use-case entries this supports

- `uc-verification-citation-supports-claim` - verify a quoted citation supports the claim it is attached to
- `uc-verification-llm-output-policy-check` - check a generated answer against the source it cites
- `uc-support-policy-supports-request` - confirm a cited policy clause actually says what a summary claims
- `uc-agents-harness-tool-call-trace-verification` - verify an agent's stated evidence against the source it cites

**Anti-use-case implied:** `au-exact-lookup-and-id-matching` - do not ask jev whether a quote
appears in a document; that is a string match, and here it is done in code before any call.
