---
id: uc-sdlc-doc-drift-local-check
title: Detect that a documentation section no longer matches the code excerpt it describes
verdict: conditional
domain: sdlc
decision_shapes: [verification, detection]
primitives: [noul, choice]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (a Choice over supports / contradicts / says_nothing on a (claim, section) pair; AUTO_ACCEPT = 0.8; exact string match first)
  - https://docs.typesafe.ai/cookbooks/semantic_find.md  (score line ids against a plain-language query in one request; Noul for "does the document address it at all")
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting; Universal Verification)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 4 indirection; mode 5 context rot)
  - https://docs.typesafe.ai/models.md  (32k state budget; $0.042 per million input tokens, output free)
related: [uc-sdlc-semantic-lint-team-conventions, uc-legal-compliance-regulatory-requirement-verification, cb-citation_check, cb-semantic_find, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect documentation drift?" Also: "our README still documents
a flag we removed", "can CI tell us which doc sections a PR invalidated?", "can a model check
the docs against the code?".

## Verdict

**Conditional**, on keeping every check **local**: one documented claim against one code
excerpt that code has already paired. "Do the docs match the code" over a whole repository is
multi-hop retrieval plus reasoning, which is failure mode 4 and 5 together and is not a System
One task. The narrow version has an official worked shape — the citation-check cookbook runs
exactly this pattern on a source document and a claim, with a Choice over supports /
contradicts / says_nothing and a confidence gate at 0.8. That cookbook is the evidence level
here; the transposition from RFC citations to code documentation is mine, and the retrieval
half (finding which doc section describes which code) is the part with no published shape.
**Advisory first, gate later:** a comment listing the sections to re-read.

## What jev decides

Code pairs a doc claim with a code excerpt before any call. The cheapest reliable pairing
mechanism is not semantic at all: docs that reference a symbol, a flag, a path, or a config
key by name can be paired with an exact string match, exactly as the citation cookbook finds
quotes in the source "with an ordinary string match" before it asks the model anything. A
symbol that no longer exists is drift, detected with no model.

State: `{doc_claim: "<one sentence or one code fence from the docs>", code: {path, excerpt}}`.

```
relation: Choice
  instructions: {question: "How does `code.excerpt` relate to `doc_claim`?"}
  criteria:
    supports:     {what: "The code does what the claim says, or directly implies it is true"}
    contradicts:  {what: "The code does the opposite, or makes the claim false",
                   examples: ["Doc: 'defaults to 30 seconds'. Code: `timeout = 5`"]}
    says_nothing: {what: "The excerpt does not address what the claim asserts, either way"}

claim_is_checkable_here: Noul
  instructions: "Is `doc_claim` the kind of statement `code.excerpt` could settle?"
  criteria:
    true:  {what: "A statement about a default, a name, a signature, an order, or a behaviour
                   this excerpt implements"}
    false: {what: "A statement of intent, rationale, or roadmap", 
            examples: ["We chose this design for readability"]}
```

Bands, following the cookbook: `confidence >= 0.8` the verdict stands and `contradicts` becomes
a comment; below 0.8 a human confirms before anything is posted. The cookbook's own run gives
the shape of what to expect from that gate: four accurate citations came back verified "at
confidence 0.93 or higher", a contradicted one at 0.99, and the two genuinely ambiguous cases
at 0.27 and 0.56 went to review.

## What stays in code

Pairing, and it is most of the work: which doc sections mention a symbol the PR touched; the
exact-match check for removed flags, renamed functions, and changed defaults where the default
is a literal; doc-to-code links you maintain explicitly (a `<!-- ref: src/x.ts:parse -->`
comment is worth more than any model); chunking; version and date arithmetic; and posting the
comment. Numeric defaults are the interesting boundary — "does 5 match 30 seconds" is a
comparison and the jaggedness page says keep it in code; jev is for "does this paragraph still
describe this function", not for the number.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. One doc claim
(~300 characters) plus a code excerpt (~1,500 characters) plus two questions with criteria
(~1,300 characters) is about 780 tokens, **≈ $0.000033 per (claim, excerpt) pair**. A PR that
touches symbols named in 20 doc claims is **≈ $0.00066**. Latency 70-500 ms per pair, all
parallel. Accuracy: not published for doc drift. The cookbook's own eight-citation run is the
nearest measured behaviour and it is on RFC text, not code — do not carry it across as an
accuracy claim. Labelled data for calibration: commits that changed documentation and code
together are your positive pairs; commits that changed code and then needed a follow-up docs
fix are your drift examples, and `git log --follow` on your docs directory will find them.

## When the verdict flips

- To **no**, if you send the whole document and the whole module and ask "are these
  consistent". Context rot plus multi-hop; the answer will be confident and useless.
- To **weak**, where a doc test, a doctest, or a literate example can execute the claim.
  Executing the documentation is strictly better than judging it.
- Generated API reference documentation. It is derived from the code and cannot drift; a
  regeneration check in CI is the correct mechanism.
- Conceptual or rationale documentation, which `claim_is_checkable_here` exists to filter out
  and which no amount of code excerpt will settle.

## Alternatives considered

- **Doctests / executable examples / snippet compilation.** The right answer wherever the
  claim can be run. Deterministic, and it fails loudly.
- **Generated reference docs.** Removes the drift class entirely for API surfaces.
- **Exact-match symbol checks** (does every symbol named in the docs still exist). Free,
  catches the most common real drift, and must run first.
- **Frontier LLM.** Can do the retrieval half as well as the judgement, and can draft the fix,
  which jev cannot (failure mode 9). Seconds and cents per pair, so use it on what jev flags.
- **Small LLM.** Comparable on the pair question and slower. On a check whose output is "go
  re-read this section" a low false-positive rate is the entire product, so give both models
  the same below-threshold route (logprobs are enough) before comparing; in one 149-row public
  run they differed only in how often they fell below it (34.7% against 2.7%).
- **Embeddings between doc sections and code.** Reasonable for the *pairing* step and worth
  trying there; useless for "contradicts", which is the actual question.
- **A human rereading the docs each release.** The incumbent, and it does not happen.

## Sources

Accessed 2026-09-19. `cookbooks/citation_check.md` (supports / contradicts / says_nothing;
AUTO_ACCEPT 0.8; string match before the model; the eight-citation run at 0.93-0.99 auto and
0.27 / 0.56 to review; `jev-1.12`, 2026-08-16), `cookbooks/semantic_find.md`,
`concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` (modes 4, 5, 9), `models.md`.
