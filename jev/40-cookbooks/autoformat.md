---
id: cb-autoformat
title: Structure recovery
url: https://docs.typesafe.ai/cookbooks/autoformat.md
decision_shapes: [classification, detection, feature-extraction]
primitives: [choice, noul]
related: [uc-data-ml-structure-recovery-autoformat, au-rewrite-and-translate-text]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Reconstruct Markdown structure (headings, paragraphs, lists, quotes, code, callouts) from
plain text whose markup was stripped, without generating any text. The cookbook's summary:
"Reconstructs Markdown from plain text that lost its formatting in two requests: one
stitches hard-wrapped lines back together, one classifies every block (heading, list,
code, callout) with companion questions read only when relevant."

The framing is select-not-generate: "A text-generation model could rewrite the text into
Markdown, but a rewrite can also change the words. Here the model never generates text: it
answers narrow questions about the document... and code does the rendering, so every
character of the output comes from the input, and every judgment carries a probability."

Dataset: one document — a team memo about a build-system migration, fetched from a pinned
GitHub gist (`build-memo.txt`), `28 non-blank lines`, which stitch into `17 blocks`. No
labelled corpus, no held-out set, no accuracy evaluation. Model:
`TYPESAFE_MODEL = "jev-1.12"`; `PRICE = (0.042, 0.00)  # $ per 1M tokens (input, output);
TypeSafe jev-1.12 as of 2026-09`. Run date of the calls: not reported; all calls are
cached in `json_cache.json` shipped with the cookbook.

## Decomposition (state, questions, how answers are combined)

Two requests in sequence. State is the whole document as one tagged string, lines given
short ids (`L014| `) so questions and answers can refer to them; blocks are re-tagged
`B000| ` for pass 2. Blank lines and explicit markers stay in code: "Blank lines and
explicit markers (`- `, `1.`, `#`) are read in code, never sent to the model to
reconsider".

Pass 1 — one `Noul` per adjacent pair of lines (pairs separated by a blank line are
skipped), all in one request:

```python
Noul(instructions=f"Does line {line_id(i)} pick up mid-sentence, continuing a sentence
     left unfinished at the end of line {line_id(i - 1)}?",
     criteria=NoulCriteria(
       true="The line starts in the middle of a sentence that began on the previous line
             - the line break tore the sentence apart",
       false="The line begins a new sentence, item, heading, or thought of its own"))
```

Merge thresholds depend on punctuation that code reads directly:

```python
JOIN_AFTER_DANGLING, JOIN_AFTER_TERMINAL = 0.2, 0.5
bar = JOIN_AFTER_TERMINAL if i and ends_terminal(LINES[i-1]["text"]) else JOIN_AFTER_DANGLING
if blocks and not line["gap"] and joins[i] >= bar:  # merge into previous block
# ends_terminal: re.search(r'[.!?:;…]["\')\]]*$', text)
```

Pass 2 — per block, one `Choice` for type plus three companion questions asked up front:

```python
f"type_{bid}": Choice(instructions=f"What kind of content is block {bid}?",
                      criteria=TYPE_CRITERIA)   # heading|paragraph|list_item|quote|code|callout
f"hlevel_{bid}": Choice("As a heading, what level would block {bid} occupy...",
                        HLEVEL_CRITERIA)        # title|section|subsection; only if len(text) <= 90
f"step_{bid}": Noul("Is block {bid} an instruction in a sequence where the order of the
                     items matters?", true="It is one step of a procedure...",
                     false="Order is irrelevant - it is a loose collection...")
f"callout_{bid}": Choice("What kind of aside is block {bid}?", CALLOUT_CRITERIA)  # note|tip|warning
```

Sample criteria text, verbatim: `"heading": "A short label or title that names the
document or the section that follows it - not a full sentence of content"`; `"code":
"Computer code, a shell command, terminal output, or a config snippet meant to be read
verbatim"`; `"callout": "A warning, tip, or important note that interrupts the flow to
flag something the reader must not miss"`. `HEADING_MAX_CHARS = 90  # longer blocks can't
render as headings, so don't ask`.

The companion answers are read only when the type makes them relevant: "Most of these
answers are never read: the step probability of a paragraph means nothing and is simply
ignored." The stated reason for asking anyway: "An extra question adds little, since the
state is most of the tokens and is sent once either way, while an extra round trip adds a
full request of latency."

Rendering arithmetic is in code. Consecutive `list_item` blocks become one list, numbered
when `sum(b["step"] for b in items) / len(items) >= STEP_THRESHOLD` with
`STEP_THRESHOLD = 0.5` — "a group-level decision no single question asked directly".

Low-confidence path: no abstain in the pipeline, but the cookbook suggests a UI can
"underline for review any block whose type confidence (the probability behind the winning
choice) is under 0.55."

**Inherited terminology defect:** the parenthetical conflates two different fields. `confidence`
is computed from how `probabilities` is spread; the probability behind the winning choice is the
maximum of `probabilities`. This cookbook's own worked example prints them differing on the same
block — `confidence 0.43: paragraph 0.53, list_item 0.24, callout 0.19`, a 0.53 winning
probability at 0.43 confidence. A 0.55 gate therefore means different things depending on which
number the code actually reads. (https://docs.typesafe.ai/confidence.md)

## Numbers reported (verbatim, with what they compare against and the run date if given)

- Pass 1: `16 pair questions, one request, 0.32s`. Pass 2: `62 questions about 17 blocks,
  one request, 0.51s`.
- Totals: `total   10,211 tokens  0.8s  $0.0003`, followed by the prose line "Two round
  trips, 10,211 tokens, 0.8s, \$0.0015." **The cost is stated inconsistently ($0.0015 prose /
  $0.0003 appendix) and this corpus headlines neither.** The appendix figure is the one the stated
  inputs support: 10,211 tokens at the published $0.042 per 1M input tokens with free output is
  $0.00043 — the same order as the printed $0.0003 (the small remaining gap is unexplained; the
  10,211 figure is a total, and only input tokens bill) and about 3.5x below the prose $0.0015,
  which the stated inputs cannot produce. Cite the token count, not either dollar figure.
- Stitching: `28 lines -> 17 blocks (11 line breaks healed)`.
- Join probabilities: true continuations "score 0.39 and up" (lowest observed `0.39` at
  `L004`), breaks the author meant "score close to zero"; `L015| The platform team`
  follows a colon and scores `0.22`; `L016` 0.11, `L017` 0.12; `L002` 0.77, `L003` 0.62,
  `L007` 0.42, `L008` 0.59, `L011` 0.48, `L012` 0.40, `L014` 0.50.
- Wording A/B, same document and same request shape: mid-sentence vs same paragraph —
  L015 0.22 vs 0.77, L016 0.11 vs 0.81, L017 0.12 vs 0.78, L020 0.08 vs 0.88, L021 0.05
  vs 0.91; `blocks after merge: 17 (mid-sentence) vs 12 (same paragraph)`.
- Classification confidences: B004 code 1.00, B008 list_item 1.00, B000 heading 0.99
  (level=title), B007 0.99, B009 0.99, B012 0.99, B001 paragraph 0.98, B011 0.98
  (step=0.86), B010 heading 0.96, B015 quote 0.99, B013 0.92 (step=0.90), B016 0.92, B005
  0.90, B003 0.89, B002 heading 0.75, B014 callout 0.65 (kind=warning), B006 paragraph
  0.43. Step probabilities: the three team lines 0.15 / 0.16 / 0.12, the three Monday
  tasks 0.86 / 0.87 / 0.90.
- Lowest-confidence block: `confidence 0.43: paragraph 0.53, list_item 0.24, callout 0.19`.
- Accuracy against a labelled set: not reported. Comparison against a named LLM: not
  reported.

## Caveats the cookbook itself states

- One document only: "The input is a team memo in exactly that state." All numbers,
  including the thresholds, come from this single memo.
- The document keeps one advantage: "this memo kept its blank lines but lost every
  marker."
- Thresholds are derived from the observed bands on this memo, and no single threshold
  works: "a single cautious cutoff at 0.5 would break up healthy paragraphs"; "No single
  threshold works for both cases; once code checks the punctuation first, the two bands
  separate."
- Question wording is load-bearing and the first attempt failed: "Asked about paragraphs,
  the model says yes to every pair, and the stitch pass merges the whole list into one
  long block... Here the wording is the difference between 17 blocks and 12."
- One block is genuinely ambiguous rather than wrong: the list-introducing sentence "names
  what follows (heading-like), is a complete sentence (paragraph-like), and sits where a
  callout would go."
- Prices are historical (`as of 2026-09`), and calls replay from the shipped cache.

## Lessons transferable to other use cases

- Select-not-generate: the model chooses "boundaries, types, and markup" and code renders,
  so "Every word above is from the input." This is the transferable pattern for any
  reformat/restructure task where changing the words is unacceptable.
- Companion questions read only when relevant: ask dependent follow-ups (heading level,
  step order, callout kind) up front in the same request and discard the irrelevant ones,
  because the state dominates tokens and a third round trip costs a full request of
  latency. Generalises whenever state is large relative to question count.
- Direct evidence stays in code: never ask the model what a regex already knows (blank
  lines, `- `, `1.`, `#`, terminal punctuation). Code picking the threshold by punctuation
  is what separates two overlapping probability bands.
- Ask the narrowest fact that decides the threshold: "When a judgment call feeds a
  threshold, the question should name the narrowest fact that decides it." Prefer an
  objective textual fact ("picks up mid-sentence") over an interpretive one ("same
  paragraph").
- Group-level arithmetic belongs in code: the ordered/unordered list decision is a mean of
  per-item step probabilities against `0.5`, a decision no single question was asked.
- Does not generalise: the specific cutoffs (0.2 / 0.5 / 0.5 / 0.55) and the 90-character
  heading gate were tuned on one memo and would need re-derivation on other documents.

## Use-case entries this supports

- `uc-data-ml-structure-recovery-autoformat` — recover headings, lists and callouts from
  unformatted plain text by classifying blocks, without rewriting the words

**Anti-use-case implied:** `au-rewrite-and-translate-text` — having a generative model
rewrite text to add formatting, which "can also change the words"; also, do not ask the
model to re-decide facts code can read directly (blank lines, existing markers,
punctuation).
