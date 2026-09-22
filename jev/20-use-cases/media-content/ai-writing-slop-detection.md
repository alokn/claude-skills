---
id: uc-media-content-ai-writing-slop-detection
title: Flag concrete prose defects across a corpus for a human editor
verdict: conditional
verdict_as_asked: no
domain: media-content
decision_shapes: [detection, classification, scoring]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds  (37 documents x 21 questions = 777 judgments in under 0.7 s for about $0.0025; Dan Shipper's run: 4 writing checks over 12 passages, jev 0.35 s average vs Fable 5.1 at 8.83 s, ~580x cheaper, jev caught 6 of 7 planted defects, Fable 7; the miss was an "unexplained action")
  - https://github.com/TKY-27/JevSlop  (community implementation of slop detection over a corpus)
  - https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/  (339 hard-benign security documents: many dimensions flag 37.2% vs a single direct question 1.5%)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [au-ai-authorship-detection, uc-media-content-prose-style-linting, uc-observability-evals-rubric-scoring-llm-judge-replacement, uc-sdlc-semantic-lint-team-conventions, uc-data-ml-map-reduce-corpus-labelling, au-rewrite-and-translate-text, au-generate-ticket-summaries]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect AI-generated writing or 'slop' in our content?" Also:
"can we scan the whole archive for the tells?", "can jev reject drafts that read as
machine-written?", "can it check my own writing before I publish?"

## Verdict

The question as usually asked — "can jev detect AI-generated writing?", establishing
authorship — is answered **no**, in `au-ai-authorship-detection`: none of the evidence for
how a text was produced is in the text, there is no published measurement, and a false
positive accuses a person of not writing their own work.

**This entry describes a different proposal, and its verdict is conditional:** editorial
flags for concrete, observable prose defects. The condition: **this flags passages for a
human editor and never rejects anything, and no question asks about authorship.** The
mechanism works and the throughput is remarkable — one public run put
"37 documents × 21 questions = 777 judgments in under 0.7 s for about $0.0025"
(every.to). But the evidence has no ground truth beyond the author's own judgement; the
corpus's source-reliability table rates that report's bias risk **high**. And the failure
mode is not a wasted API call, it is **accusing a person of not writing their own work**. A
false positive there costs more than a hundred misses, which is exactly the asymmetry that
rules out an automatic gate.

A second reason for caution is structural: the most detailed independent experiment found
that decomposing into many dimensions can be far *worse* than one direct question — 37.2%
false positives against 1.5% on 339 hard-benign documents (agentjournal.dev). Asking 21
questions per document is the same shape.

## What jev decides

Work at paragraph granularity, not document. State is one passage plus its section heading;
nothing else. Ask a small number of *concrete, observable* questions, not "is this AI":

```
unexplained_action: Noul
  instructions: "Does the passage assert that something happened without saying who did it
                 or how?"
  criteria: {false: "The agent and mechanism are named, even briefly."}

hedged_without_content: Noul
  instructions: "Does the passage qualify a claim so heavily that it states nothing
                 checkable?"

claim_without_source: Noul
  instructions: "Does the passage state a specific figure, date, or attributed opinion with
                 no source given anywhere in the passage?"

specificity: Score
  criteria: ["Entirely generic; would fit any subject.",
             "Some concrete detail, mostly restatement.",
             "Named specifics a reader could verify."]
```

Note what is absent: a question called `is_ai_generated`. There is no published evidence that
jev can answer it, and a confident wrong answer to that question is the worst output this
system can produce. Detect the *defects*; let the editor conclude.

Closest jaggedness mode: **8, overconfidence on out-of-distribution input** — an unusual but
good writer looks like an unusual and bad one. Mitigated only by keeping a human in the loop.

## What stays in code

Chunking into paragraphs, word and sentence counts, readability formulas, repeated-phrase
detection, n-gram overlap against a banned-phrase list, and the aggregation of per-paragraph
flags into a document view. All of that is exact and free; do not spend a question on
anything a `len()` answers (`au-count-items-in-text`). Also in code: the diff view the editor
reads, and the record of which flags the editor dismissed — that is your calibration set.

## Numbers

Verbatim from the Every write-up (Mike Taylor, 2026-09-15): **"37 documents × 21 questions =
777 judgments"** in **"under 0.7 s"** for **"about $0.0025"**. Dan Shipper's companion run in
the same piece: 4 writing checks over 12 passages, jev averaging **0.35 s** against Claude
Fable 5.1 at **8.83 s** (about 25x) and roughly **580x cheaper**; jev caught **6 of 7**
planted defects, Fable caught **7**. The one jev missed was an **"unexplained action"**, and
it missed it **across three attempts** — a repeatable blind spot, not a sampling wobble.

Treat all of that as a field report, not a benchmark: the defects were planted by the author,
the judgement of a catch is the author's, and n is 12 passages.

Your own estimate: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,200-character paragraph plus four questions with criteria (~1,500 characters) is about
675 tokens, **≈ $0.000028 per paragraph** — roughly $0.0006 for a 20-paragraph article.

## When the verdict flips

- **The flag blocks publication or fails a contributor.** Verdict becomes **no**. There is no
  explanation to appeal against (`au-review-loop-pass-fail-gate` is the same shape).
- **You ask "is this AI-generated" directly, or report the flags as evidence of authorship.**
  Then it is **no** — `au-ai-authorship-detection`. No source has measured it and the
  consequence of a false positive is a person accused. Do not ship that question.
- **You add twenty more dimensions because they are cheap.** The measured risk is a 37.2%
  false-positive rate against 1.5% for one question on hard-benign text. Add a dimension only
  after it earns its place on labelled examples.
- **The corpus is not English.** Unevaluated; `au-non-english-at-scale-unevaluated`.
- **You want the passage fixed, not flagged.** That is generation — `au-rewrite-and-translate-text`.

## Alternatives considered

- **Banned-phrase and n-gram lists.** Free, exact, instantly gameable, and genuinely useful
  for the crudest tells. Run them first.
- **Perplexity-based AI detectors.** Purpose-built and widely reported as unreliable on edited
  text; they also cannot be told what *your* publication considers a defect.
- **Frontier LLM (Fable 5.1).** Caught 7 of 7 in the same small run and can explain the
  problem to the writer, which is most of the value in an editorial workflow. 8.83 s and
  ~580x the cost per check, which only matters at corpus scale.
- **A style linter (vale, proselint).** Deterministic, reviewable, version-controlled. The
  right tool for rules you can state as patterns; see `uc-media-content-prose-style-linting`
  for the jev complement.
- **A human editor.** The ground truth and the destination. This system changes what lands on
  their desk first, nothing more.

## Sources

- https://every.to/also-true-for-humans/mini-vibe-check-typesafe-s-jev-judged-everything-i-ve-written-in-0-7-seconds
  — accessed 2026-09-19 (777 judgments in under 0.7 s for ~$0.0025; 0.35 s vs 8.83 s; ~580x
  cheaper; 6 of 7 vs 7 of 7; the "unexplained action" miss across three attempts)
- https://github.com/TKY-27/JevSlop — accessed 2026-09-19
- https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — accessed 2026-09-19
  (37.2% vs 1.5% false positives on 339 hard-benign documents)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
