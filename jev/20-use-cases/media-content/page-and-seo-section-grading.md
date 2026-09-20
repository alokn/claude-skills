---
id: uc-media-content-page-and-seo-section-grading
title: Grade a web page section by section against written content criteria
verdict: good
domain: media-content
decision_shapes: [classification, scoring, verification]
primitives: [noul, score]
evidence_level: community-report
sources:
  - https://github.com/kitze/pagegrade  (section-by-section page grading with jev; no numbers published)
  - https://github.com/AkashPriyadarshii/jev-seo  (SEO checks as typed decisions; no numbers published)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (several questions about the same state in one request)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 2 math and numbers; mode 5 large state)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sales-marketing-creative-quality-rubric, uc-sales-marketing-ad-landing-page-alignment, uc-media-content-prose-style-linting, uc-browser-automation-page-clutter-element-removal, au-interpolate-magnitude-from-score]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to grade a page for SEO and content quality?" Also: "our SEO tool
only checks tags and word counts — can a model tell us whether the page actually answers the
query?", "can we score 10,000 landing pages against our content standards?", "can jev tell us
which section is thin?".

## Verdict

**Good.** An SEO and content audit is mostly a checklist of judgement questions applied to a
small, well-delimited chunk of a page, and existing tools already do the deterministic half
(tags, counts, link density, Core Web Vitals) and stop exactly where the judgement starts. Jev
answers the judgement half — does the H1 match the intent the page targets, does the first
paragraph answer the query, is this section thin, is the CTA specific — with a probability per
question and all questions in one call per section. Two public tools ship this. `Good` rather
than `strong`: neither publishes agreement with human graders, and there is no independent
benchmark on page quality.

## What jev decides

Code splits the page by heading, strips navigation and boilerplate, and passes each section with
the page's target query and audience. One call per section, several questions in it.

```
answers_target_query: Noul
  instructions: {question: "Does `section_text` answer `target_query`, or does it only
                            mention the subject?"}
  true:  "A reader with `target_query` would leave this section with the answer."
  false: "The section is about the topic but defers the answer, links elsewhere, or restates
          the question."

heading_matches_body: Noul   ("does `heading` describe what `section_text` actually covers")
section_is_thin: Noul        ("no specific detail, example, figure or step - only generalities")
cta_is_specific: Noul        ("names the action and what happens next, not 'learn more'")
duplicates_earlier_section: Noul  (given `earlier_headings`)

depth: Score
  criteria: ["Restates common knowledge.",
             "Explains the topic with at least one concrete specific.",
             "Gives something a reader could act on that they would not find on a competitor
              page."]
```

Each `false` criterion names the near-miss a content team actually ships. `duplicates_earlier_section`
is the one that catches the keyword-cannibalisation problem tooling usually misses.

Output is a per-section report ordered by the weighted score, for a human to work through. Low
confidence means "a human should look", not a neutral grade.

## What stays in code

Everything numeric and everything factual. Section extraction, word counts, heading levels,
title and meta length, internal and external link counts, image alt coverage, canonical and
schema markup, index status, and page speed. The **grade arithmetic is code's job**: jev returns
probabilities and a Score band, code multiplies by your weights and sums. Never read a Score as
a mark out of 100 or interpolate a magnitude from it — a Score names a band, and treating it as
a number is a known failure. Rankings, traffic and conversion data come from your analytics, not
from a question.

## Numbers

No accuracy, latency or cost is published by https://github.com/kitze/pagegrade or
https://github.com/AkashPriyadarshii/jev-seo, so there is no measured result to quote for this
task. Cost method: `input_tokens ~= chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A
1,500-character section plus target query, context and six questions with criteria (~2,800
characters) is about 1,075 tokens, **~$0.000045 per section**. A 10-section page is
**~$0.00045**; a 10,000-page audit is therefore on the order of **$4.50** in model cost, which
is the argument for doing this at site scale rather than sampling. Latency from the models page:
"70 to 500 ms", "most queries about 100 ms", and sections parallelise.

Closest failure mode: **5, large state full of irrelevant detail** — avoided by grading one
section at a time rather than pasting the page. Runner-up **2, math and numbers**: keep every
count and every weighted total in code.

## When the verdict flips

- **The check is mechanical.** Title length, missing alt text, broken links, duplicate meta
  descriptions. Existing crawlers do this exactly and free.
- **You want the fix, not the finding.** Rewriting the section is generation; jev cannot.
- **The grade drives an automatic action** — de-indexing, unpublishing, paying a freelancer.
  Keep a human between the score and the consequence.
- **You need to explain the grade to the author.** There is no chain of thought; you can show
  which question fired and its probability, and that is all.
- **Non-English pages without a per-language check.** Unmeasured.

## Alternatives considered

- **Crawlers and SEO suites (Screaming Frog, Lighthouse, Ahrefs).** Exact on everything
  countable, and the right first stage. They cannot answer "does this section answer the query".
- **Keyword-density and readability formulas.** Cheap proxies that content teams already
  distrust; they measure form, not whether the page is useful.
- **Frontier LLM audit.** Better and it can write the fix; seconds and cents per page, which is
  fine for 50 pages and not for 10,000. A sensible escalation for the worst-scoring sections.
- **Embeddings for query-page similarity.** Good at topical match, structurally unable to
  distinguish "mentions" from "answers" — the exact distinction this entry is for.
- **Human content audit.** The ground truth; collect the graders' verdicts and fit your
  thresholds against them.

## Sources

- https://github.com/kitze/pagegrade — accessed 2026-09-19
- https://github.com/AkashPriyadarshii/jev-seo — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
