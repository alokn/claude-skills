---
id: cb-semantic_find
title: Line-by-line search
url: https://docs.typesafe.ai/cookbooks/semantic_find.md
decision_shapes: [search, ranking, detection]
primitives: [choice, noul]
related: [uc-search-retrieval-semantic-find-in-document, uc-legal-compliance-contract-clause-presence, uc-support-policy-supports-request, uc-search-retrieval-document-answers-query-gate, uc-verification-citation-supports-claim, au-flat-choice-over-255-options]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Semantic search inside one document, without an index or embeddings. Every line of the
document is tagged with an id, a `Choice` question over those ids ranks the lines against a
plain-language query, and a `Noul` question in the same request says whether the document
answers the query at all. The result is a `find()` function that "returns the `exists`
probability and one relevance score per line".

Dataset: GitHub's Terms of Service, fetched from a pinned raw gist
(`gist.githubusercontent.com/eugene-shvarts/900632789a24983d5678ffd508dd01f6`, raw commit
`cf9c2ab422d568deade949ef0a06bed6896964b9`), "split into 218 clauses". Printed size: `218
lines, 43,980 characters`. The document's own effective date line reads `Effective date:
April 27, 2026`. Model: `TYPESAFE_MODEL = "jev-1.12"`. Four queries are run. Date sampled:
not reported.

## Decomposition (state, questions, how answers are combined)

State is the whole tagged document as a single string - not a dict:

```python
def line_id(i: int) -> str:
    return f"L{i:03d}"

DOCUMENT = "\n".join(f"{line_id(i)}| {line}" for i, line in enumerate(LINES))
```

Two questions, both sent in one `system_one` call. First, a `Choice` over all 218 line ids:

```python
def where_question(query: str) -> Choice:
    return Choice(
        instructions=f'Which line of the document contains the answer to: "{query}"?',
        criteria={line_id(i): None for i in range(len(LINES))},
    )
```

"The option descriptions are `None` because the document already contains the text for each
ID. The query goes in `instructions`; the state stays unchanged between searches."

Second, a `Noul` existence check, because "Choice probabilities always add up to 1, so some
line ranks first even when the document doesn't answer the question":

```python
def exists_question(query: str) -> Noul:
    return Noul(
        instructions=f'Does any line of the document address or answer: "{query}"?',
        criteria=NoulCriteria(
            true="At least one line of the document states or directly implies the answer",
            false="No line of the document addresses this",
        ),
    )
```

The response is unpacked into `exists` (the noul) and `relevance` (one Choice probability
per line, in document order, defaulting to `0.0` for any id the model omits).

Confidence bands are two thresholds in local code, with an uncertain middle:

```python
FOUND, ABSENT = 0.7, 0.35  # present answers typically read >=0.9, absent <=0.05

def verdict(exists: float) -> str:
    if exists >= FOUND:
        return "answered in this document"
    return "not in this document" if exists < ABSENT else "partially addressed"
```

Ranking is done in code by sorting line indices on `relevance`, descending. The abstain path
is the `exists` score, not the ranking: "The ranking tells you where to look; the `exists`
score tells you whether the result answers the question."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Document: `218 lines, 43,980 characters`. Limit stated for the primitive: "A `Choice`
question accepts up to 255 options, so this recipe searches documents of up to 255 lines in
one request."

| Query | `exists` | Verdict | Top line and score |
|---|---|---|---|
| "who owns the code I upload?" | 0.98 | answered in this document | L052 0.95 (then L046 0.02, L051 0.02, L217 0.01) |
| "can GitHub kick me off the platform without warning?" | 0.97 | answered in this document | L168 0.97 (then L167 0.03, L000 0.00, L001 0.00) |
| "do I have to take disputes to arbitration?" | 0.14 | not in this document | L205 0.86 (then L168 0.02) |
| "can minors use GitHub with parental permission?" | 0.46 | partially addressed | L029 0.90 (then L012 0.07) |

Thresholds: `FOUND, ABSENT = 0.7, 0.35`, with the comment "present answers typically read
>=0.9, absent <=0.05".

Cost: not reported. Token counts: not reported. Latency: not reported. Accuracy or
agreement over a labelled set: not reported - there are four illustrative queries and no
scored evaluation. Comparison against a named LLM or an embedding baseline: not reported.
Number of repeats: not reported. Run date: not reported.

## Caveats the cookbook itself states

- The thresholds are not universal: "These thresholds separate the examples below, but tune
  them against your own documents before using them in production."
- Hard ceiling on document size: "A `Choice` question accepts up to 255 options, so this
  recipe searches documents of up to 255 lines in one request. Past that, search in two
  passes: one Choice question picks a window of lines, and a second ranks the lines inside
  it."
- The ranking alone is not a relevance signal: "Choice probabilities always add up to 1... 
  The ranking alone can't distinguish a real answer from the closest irrelevant line." The
  arbitration query demonstrates it - 0.86 on the top line while `exists` is 0.14.
- Ranking first does not mean answering: on parental permission, "The age rule ranks first,
  but it doesn't answer whether parental permission changes the rule."
- The published figures are cache replays: "`JsonCache` replays the included API responses,
  so the steps below run without an API key or any spend."

## Lessons transferable to other use cases

- Point-at-the-answer instead of generating it: ids in the state plus a `Choice` over those
  ids turns "extract the answer" into "select a line", and every result is quotable and
  verifiable against the source.
- Always pair a normalised ranker with an absolute check: a `Choice` is relative and sums to
  1, a `Noul` is independent, "so it can fall near zero when the document has no answer".
  One question cannot do both jobs.
- Fan-out: ranking and the existence check ride in one request, so "adding the existence
  check requires only a small amount of extra output" because the state is sent once.
- Confidence bands with an uncertain middle: two thresholds give three outcomes - answered,
  partially addressed, not in this document - rather than forcing a binary.
- Query in the question, corpus in the state: the state is identical between searches, so
  the document text is reusable across queries and only the instructions change.
- What does not generalise: the 255-option cap makes this a within-document technique, not a
  corpus search. Above ~255 lines it needs a two-pass windowing scheme, and the 0.7/0.35
  thresholds are tuned to this one document.

## Use-case entries this supports

- `uc-search-retrieval-semantic-find-in-document` - point at the line or clause inside one document that answers a plain-language query
- `uc-legal-compliance-contract-clause-presence` - check whether a required clause appears in a document
- `uc-support-policy-supports-request` - find the policy line that answers a customer question, or say there is none
- `uc-search-retrieval-document-answers-query-gate` - detect when a document does not cover a query
- `uc-verification-citation-supports-claim` - return the source line a generated answer must cite

**Anti-use-case implied:** `au-flat-choice-over-255-options` - a `Choice` caps at 255 options, so
this shape does not scale to corpus-wide retrieval or to any label set larger than that
without a windowing pass in code.
