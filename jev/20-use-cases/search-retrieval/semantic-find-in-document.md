---
id: uc-search-retrieval-semantic-find-in-document
title: Point at the line or clause inside one document that answers a plain-language query
verdict: good
domain: search-retrieval
decision_shapes: [search, ranking, retrieval]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/semantic_find.md  (218-line GitHub ToS; Choice over line ids plus an exists Noul; per-query scores)
  - https://docs.typesafe.ai/primitives/choice.md  (255-option cap)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Search: "find items that match a natural-language query")
related: [uc-search-retrieval-document-answers-query-gate, uc-search-retrieval-rerank-keyword-shortlist, uc-verification-document-completeness-checklist]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to find the clause in this contract that answers my question?"
Also: "we have one long document and no index — can we do semantic search inside it without
embeddings?", "can jev give me a quotable line instead of a generated answer?"

## Verdict

**Good**, for documents that fit in one request — the shape is demonstrated by the
`semantic_find` cookbook; no task-matched labelled accuracy is published;
shadow-evaluate against the incumbent before acting. Tag every line or clause with an
id, put the tagged document in `state`, and make a `Choice` whose options are those ids.
The model never writes text: it points at a line, so every result is quotable and
checkable against the source. The hard condition is the primitive's cap — "A `Choice`
question accepts up to 255 options, so this recipe searches documents of up to 255 lines
in one request."

## What jev decides

State is the whole tagged document as one string, unchanged between searches:

```python
DOCUMENT = "\n".join(f"L{i:03d}| {line}" for i, line in enumerate(LINES))
```

Two questions in one call. The ranker:

```python
Choice(instructions=f'Which line of the document contains the answer to: "{query}"?',
       criteria={f"L{i:03d}": None for i in range(len(LINES))})
```

Option descriptions are `None` "because the document already contains the text for each ID.
The query goes in `instructions`; the state stays unchanged between searches."

The existence check, because "Choice probabilities always add up to 1, so some line ranks
first even when the document doesn't answer the question":

```python
Noul(instructions=f'Does any line of the document address or answer: "{query}"?',
     criteria=NoulCriteria(
       true="At least one line of the document states or directly implies the answer",
       false="No line of the document addresses this"))
```

Bands are two thresholds in code, giving an uncertain middle: `FOUND, ABSENT = 0.7, 0.35` —
at or above 0.7 "answered in this document", below 0.35 "not in this document", between them
"partially addressed". "The ranking tells you where to look; the `exists` score tells you
whether the result answers the question."

## What stays in code

Splitting into lines or clauses, assigning ids, the 255-line windowing when the document is
longer ("one Choice question picks a window of lines, and a second ranks the lines inside
it"), sorting by the returned probabilities, defaulting omitted ids to 0.0, and the two
thresholds. Nothing about the answer's content is generated.

## Numbers

From `semantic_find.md` — GitHub's Terms of Service at a pinned gist commit, "218 lines,
43,980 characters", `jev-1.12`, four illustrative queries:

| Query | `exists` | Verdict | Top line |
|---|---|---|---|
| who owns the code I upload? | 0.98 | answered | L052 at 0.95 |
| can GitHub kick me off without warning? | 0.97 | answered | L168 at 0.97 |
| do I have to take disputes to arbitration? | 0.14 | not in this document | L205 at 0.86 |
| can minors use GitHub with parental permission? | 0.46 | partially addressed | L029 at 0.90 |

The arbitration row is the whole argument for the second question: the top line scores 0.86
while `exists` reads 0.14. Cost, tokens, latency and any scored accuracy: **not reported** —
four queries, no labelled evaluation. The thresholds come with a warning: "tune them against
your own documents before using them in production"; the observed bands were "present answers
typically read >=0.9, absent <=0.05".

Closest jaggedness mode: **8, structural invariants** — a relative Choice and an absolute Noul
answer different questions and must not be traded for one another. The design asks both.

## When the verdict flips

- **More than ~255 candidate lines and you will not window.** The cap is hard; without the
  two-pass scheme this becomes **no**.
- **A corpus rather than a document.** This is within-document search. Corpus retrieval needs
  an index first; then see the re-ranking entry.
- **The user wants a written answer, not a location.** Generation is mode 9. Jev picks the
  line; an LLM may phrase it afterwards.
- **Lines are near-duplicates of each other** (boilerplate clause libraries). The Choice will
  split probability across them and the top-1 becomes arbitrary; ask one Noul per clause
  instead and accept several.
- **The document is hostile** (a contract drafted to mislead a classifier). Mode 6 applies.

## Alternatives considered

- **Regex / keyword search over lines** — wins when the query names a term that appears in the
  clause; loses on "can they kick me off", where no keyword overlaps.
- **Chunk embeddings + cosine** — the standard alternative and cheap at scale, but needs an
  index, a chunking policy and a threshold, and gives no "the document does not cover this"
  signal. Jev needs no index and provides the existence probability in the same call.
- **Frontier LLM reading the document** — will answer well, but generates prose you must then
  ground, costs seconds, and can quote a line that is not there.
- **Small LLM** — same generation problem with worse grounding.
- **Human review** — the current process this replaces for contract and policy Q&A; keep the
  "partially addressed" band pointed at it.

## Sources

- https://docs.typesafe.ai/cookbooks/semantic_find.md — accessed 2026-09-19
- https://docs.typesafe.ai/primitives/choice.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
