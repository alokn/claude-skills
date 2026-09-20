---
id: uc-data-ml-structure-recovery-autoformat
title: Recover document structure from plain text by classifying blocks, without rewriting the words
verdict: good
domain: data-ml
decision_shapes: [classification, detection, extraction]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/autoformat.md  (two passes over a 28-line memo; 16 + 62 questions; 10,211 tokens, 0.8s; per-block confidences; wording A/B)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9: generation is not a jev task)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Structured Data Extraction: "Known fields must be recovered from unstructured input")
related: [uc-data-ml-pre-parsed-value-selection, uc-data-ml-date-part-extraction, uc-search-retrieval-semantic-find-in-document]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to restore formatting to plain text?" Also: "our pasted and emailed
documents lost their markdown", "hard-wrapped text is breaking our chunker — can jev rejoin the
lines?", "can we add structure without an LLM rewriting the content?"

## Verdict

**Good**, because the task is select-not-generate — the shape is demonstrated by the
`autoformat` cookbook; no task-matched labelled accuracy is published; shadow-evaluate
against the incumbent before acting. "A text-generation model could rewrite the text
into Markdown, but a rewrite can also change the words. Here the model never generates
text: it answers narrow questions about the document... and code does the rendering, so
every character of the output comes from the input, and every judgment carries a
probability." The condition is that code reads the direct evidence first — blank lines,
`- `, `1.`, `#`, terminal punctuation "are read in code, never sent to the model to
reconsider".

## What jev decides

Two requests in sequence over a tagged document (`L014| `, then `B000| ` for blocks).

**Pass 1, stitch hard-wrapped lines.** One Noul per adjacent pair, all in one request:

```python
Noul(instructions=f"Does line {line_id(i)} pick up mid-sentence, continuing a sentence "
                  f"left unfinished at the end of line {line_id(i-1)}?",
     criteria=NoulCriteria(
       true="The line starts in the middle of a sentence that began on the previous line "
            "- the line break tore the sentence apart",
       false="The line begins a new sentence, item, heading, or thought of its own"))
```

**Pass 2, classify blocks.** One Choice for type plus three companion questions per block, all
asked up front:

```python
f"type_{bid}":    Choice("What kind of content is block {bid}?", TYPE_CRITERIA)   # heading|paragraph|list_item|quote|code|callout
f"hlevel_{bid}":  Choice("As a heading, what level would block {bid} occupy...", HLEVEL_CRITERIA)  # only if len(text) <= 90
f"step_{bid}":    Noul("Is block {bid} an instruction in a sequence where the order of the items matters?")
f"callout_{bid}": Choice("What kind of aside is block {bid}?", CALLOUT_CRITERIA)  # note|tip|warning
```

Sample criteria, verbatim: `"heading": "A short label or title that names the document or the
section that follows it - not a full sentence of content"`; `"code": "Computer code, a shell
command, terminal output, or a config snippet meant to be read verbatim"`.

Most companion answers are discarded — "the step probability of a paragraph means nothing and is
simply ignored" — and that is deliberate: "An extra question adds little, since the state is most
of the tokens and is sent once either way, while an extra round trip adds a full request of
latency."

## What stays in code

Tagging, the punctuation test, the merge thresholds, all rendering, and the group-level
arithmetic:

```python
JOIN_AFTER_DANGLING, JOIN_AFTER_TERMINAL = 0.2, 0.5
bar = JOIN_AFTER_TERMINAL if i and ends_terminal(LINES[i-1]["text"]) else JOIN_AFTER_DANGLING
HEADING_MAX_CHARS = 90   # longer blocks can't render as headings, so don't ask
STEP_THRESHOLD = 0.5     # mean of per-item step probabilities decides ordered vs unordered
```

The ordered-list decision is "a group-level decision no single question asked directly".

## Numbers

From `autoformat.md`, `jev-1.12`, one team memo of `28 non-blank lines` stitching into `17 blocks`:
pass 1 is "16 pair questions, one request, 0.32s"; pass 2 is "62 questions about 17 blocks, one
request, 0.51s"; totals print as `total 10,211 tokens 0.8s $0.0003`, though the prose states
"$0.0015" — the page disagrees with itself, so quote the token count rather than the dollar figure.
Stitching: "28 lines -> 17 blocks (11 line breaks healed)".

Classification confidences: B004 code 1.00, B008 list_item 1.00, B000 heading 0.99 (level=title),
B015 quote 0.99, B014 callout 0.65 (kind=warning), and the lowest at "confidence 0.43: paragraph
0.53, list_item 0.24, callout 0.19". Step probabilities separated cleanly: three team lines at
0.15 / 0.16 / 0.12 against three Monday tasks at 0.86 / 0.87 / 0.90.

The wording A/B is the most transferable number here. Same document, same request shape, two
phrasings of the join question: mid-sentence vs same paragraph gave L015 0.22 vs 0.77, L016 0.11
vs 0.81, L020 0.08 vs 0.88, and "blocks after merge: 17 (mid-sentence) vs 12 (same paragraph)".
"Here the wording is the difference between 17 blocks and 12." Accuracy against a labelled set:
**not reported** — one memo.

Closest jaggedness mode: **9, generation**, avoided structurally; and **1**, which the A/B
quantifies.

## When the verdict flips

- **The source has markup you can parse** — HTML, DOCX, PDF tags, a mail part with `text/html`.
  Parse it; this is for text that genuinely lost its structure.
- **Rendering may change the words.** If your pipeline lets a model rewrite, you have lost the
  property that makes this safe.
- **The thresholds are inherited.** "the specific cutoffs (0.2 / 0.5 / 0.5 / 0.55) and the
  90-character heading gate were tuned on one memo and would need re-derivation on other
  documents."
- **The document also lost its blank lines.** "this memo kept its blank lines but lost every
  marker" — without them the block boundaries are a harder problem than the one measured.
- **Very long documents.** Cost per document is small but the state must fit in 32k tokens
  alongside the longest question; process by section.

## Alternatives considered

- **Regex and heuristics on indentation, capitalisation and line length** — free, and they should
  run first; they cannot tell a one-line paragraph from a heading.
- **LLM rewrite into Markdown** — the incumbent and the documented risk: "a rewrite can also
  change the words."
- **Layout models (LayoutLM, document-AI services)** — the right tool when you still have the PDF
  or the image, because they see geometry; irrelevant once the input is plain text.
- **Pandoc / format converters** — exact where a source format exists.
- **Hand-tuned classifiers on block features** (length, punctuation, case) — cheap and decent for
  heading detection, and they do not know what a callout is.

## Sources

- https://docs.typesafe.ai/cookbooks/autoformat.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
