---
id: uc-media-content-prose-style-linting
title: Run a house style guide as parallel Boolean conditions over each paragraph
verdict: good
domain: media-content
decision_shapes: [classification, detection, verification]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/DanRWilloughby/snifftest  (ten Boolean style conditions per paragraph in one jev call; no numbers published)
  - https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/  (339 hard-benign documents: dimensions flag "37.2%" vs a single direct question "1.5%")
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (several questions about the same state in one request)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 7 contradictory instructions and criteria; mode 9 generation)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-media-content-ai-writing-slop-detection, uc-sdlc-semantic-lint-team-conventions, uc-media-content-page-and-seo-section-grading, au-rewrite-and-translate-text]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev as a prose linter?" Also: "can jev enforce our style guide?", "Vale
only catches words we listed — can a model catch the rules we can only describe?", "can it flag
passive voice and unsupported claims in the same pass?".

## Verdict

**Good.** A style guide is already a list of independent yes/no conditions written in English;
jev takes them almost verbatim, answers all of them about the same paragraph in one request, and
returns a probability per condition. Parallel questions cost tokens and little extra latency — the docs say latency "barely
changes" — and
the criteria are plain text a writer or editor can edit without touching code — that is the
whole advantage over a rule-based linter. A public implementation runs ten conditions per
paragraph. It is `good`, not `strong`, because that project publishes no precision or recall,
and because decomposition is not free (see Numbers).

## What jev decides

State is one paragraph plus, where a rule needs it, the section heading and the document's
declared audience. One Noul per rule, all in the same call:

```
claim_without_evidence: Noul
  instructions: {question: "Does `paragraph` assert a factual or numeric claim with no source,
                            figure or citation attached?"}
  true:  "A claim of fact, scale or outcome is stated as settled with nothing supporting it."
  false: "The claim is hedged, attributed, sourced, or is the author's stated opinion."

hedged_to_meaninglessness: Noul  ("may, might, could" stacked until nothing is asserted)
buries_the_point:          Noul  ("the paragraph's main assertion arrives after its supporting detail")
undefined_jargon:          Noul  ("a term is used that `audience` would not know and it is not defined here")
marketing_register:        Noul  ("superlatives and vendor language rather than description")
second_person_drift:       Noul  ("switches between you / we / the user within the paragraph")
...
```

Each rule needs its own `false` criterion naming the near-miss the writers actually produce,
or the rule will fire on correct prose. Keep the rules mutually independent: overlapping
criteria are failure mode 7 (contradictory instructions and criteria) and produce correlated
noise rather than ten signals.

Output is a suggestion list ordered by probability, shown to a human. There is no gate.

## What stays in code

Paragraph splitting, code-block and quotation exclusion, word and sentence counts, reading-level
arithmetic, terminology and spelling lists (a banned-word list is a regex and should stay one),
link checking, and the diff that decides which paragraphs changed and therefore need re-linting.
Jev never rewrites the sentence — it cannot generate text (failure mode 9); the suggested
rewrite, if you want one, comes from a generative model triggered by the flag.

## Numbers

No accuracy, latency or cost is published by https://github.com/DanRWilloughby/snifftest, so
there is no measured result for this task. Cost method: `input_tokens ~= chars/4`,
`cost = tokens x $0.042 / 1e6`, output free. A 900-character paragraph plus ten rules with
criteria (~2,600 characters) is about 875 tokens, **~$0.000037 per paragraph**; a 40-paragraph
article is **~$0.0015** for all ten rules, because the rules share one call rather than costing
ten. Latency, from the models page: "70 to 500 ms", "most queries about 100 ms" — one round trip
for all ten rules, which is what makes an in-editor experience viable.

The measured warning that belongs here is about decomposition itself. An independent experiment
over 339 hard-benign documents found that replacing one well-written question with 12-14
dimensions raised the false-positive rate to **"37.2%" against "1.5%"** for the single direct
call (https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/). Ten independent rules
are not the same construction as ten dimensions feeding one verdict — but the lesson transfers:
every rule you add is another chance to flag clean prose, and a linter that cries wolf gets
turned off. Fit a threshold per rule against your own labelled paragraphs and delete the rules
that do not earn their place.

Closest failure mode: **7, contradictory instructions and criteria**, avoided by keeping each
rule's criteria disjoint from every other rule's.

## When the verdict flips

- **The rule is lexical.** Banned words, product-name capitalisation, Oxford comma, heading
  case. A regex is exact and free; jev is worse and slower. Vale already does this.
- **You wanted the rewrite, not the flag.** Generation is mode 9; use a generative model.
- **The rules are blocking CI.** A probabilistic style check that fails a build will be
  disabled within a week. Advisory only.
- **Non-English copy without a per-language check.** Unmeasured; see the non-English
  anti-use-case.
- **One question already works.** If a single "does this paragraph meet the house style"
  question performs as well, the 339-document result says prefer it.

## Alternatives considered

- **Vale / write-good / textlint.** Free, instant, deterministic, and right for every rule that
  can be written as a pattern. They stay; jev handles the rules that cannot.
- **Frontier LLM editor.** Better judgement and it can rewrite; seconds per paragraph and cents
  per article, which rules it out of the editing loop and into the review pass.
- **Grammar SaaS (Grammarly and friends).** Strong on mechanics, and it cannot be taught your
  house rules.
- **Trained classifier per rule.** Needs labelled paragraphs per rule, which nobody has at the
  start. Revisit once the editor's accept/reject clicks have accumulated.
- **A human editor.** The ground truth and the actual consumer of this output.

## Sources

- https://github.com/DanRWilloughby/snifftest — accessed 2026-09-19
- https://agentjournal.dev/blog/llm-judge-vs-feature-extraction/ — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
