---
id: uc-sales-marketing-ad-landing-page-alignment
title: Check that an ad's promise is delivered by its landing page
verdict: conditional
domain: sales-marketing
decision_shapes: [verification]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (advertising: "Evaluate creative assets, campaign copy, landing pages, and placement context"; "Evaluate creative quality and ad-to-landing-page alignment")
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (does the supplied context support the claim; confidence flags for review)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5: large state full of irrelevant detail; failure mode 4: one hop per question)
  - https://docs.typesafe.ai/cookbooks/classifying_rag_passages.md  (score retrieved passages, drop the irrelevant ones before the decision)
related: [uc-sales-marketing-brand-safety-ad-copy-compliance, uc-sales-marketing-creative-quality-rubric, uc-support-policy-supports-request]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check ad-to-landing-page alignment?" Also "the ad promises a
free trial and the page asks for a demo — can we catch that automatically?", "can jev audit
our whole campaign for message match?", and "can jev predict quality score?".

## Verdict

**Conditional**, and the condition is state discipline. The judgement itself — does this page
deliver what this ad promised — is a clean single-hop comparison of two texts, and it is named
in the docs' advertising list. The difficulty is that a landing page is a whole HTML document,
and sending it raw is the textbook version of failure mode 5: navigation, footers, cookie
banners and unrelated product blurbs swamp the part that matters. With code extracting the
headline, subhead, primary call to action and the first content section, the comparison is
tight and cheap. Without that extraction it is unreliable and expensive. Note also what this
is not: it does not predict a platform quality score, which is a proprietary number driven
mostly by click-through behaviour.

## What jev decides

State: the ad's headline, description and call-to-action, and the page reduced to
`{title, h1, subhead, primary_cta_text, first_section_text, offer_terms}`.

```
page_delivers_ad_promise: Noul
  instructions: {question: "Does `page` provide what `ad` promises?",
                 compare: ["`ad.headline`", "`ad.description`", "`page.h1`",
                           "`page.first_section_text`"],
                 focus: "Judge whether the specific thing offered in the ad is available here."}
  criteria:
    true:  {what: "The page offers the same product, offer, or content the ad named"}
    false: {what: "The page offers something else, or is a generic homepage",
            not_for: "Different wording for the same offer"}

cta_matches_ad_action: Noul
  instructions: "Does `page.primary_cta_text` invite the same action `ad.cta` promised —
                 for example both a free trial, or both a demo booking?"

offer_terms_consistent: Noul
  instructions: "Do `page.offer_terms` contradict any offer stated in `ad.description` —
                 a different discount, duration, eligibility, or price?"

message_match: Score
  instructions: "How closely does the page's opening message echo the ad's promise?"
  criteria: ["The page is about something else entirely",
             "Same product area, different promise",
             "Same promise, different framing and language",
             "The page opens with the ad's promise, recognisably"]

audience_mismatch: Noul
  instructions: "Does `page` address a different audience than `ad` targets — for example the
                 ad speaks to individuals and the page to enterprise buyers?"
```

`offer_terms_consistent` is the one with commercial teeth: an ad promising 30 days landing on
a page offering 14 is the kind of discrepancy that draws a regulator's attention, and it is
invisible to any automated check that compares similarity rather than terms. Bands: block a
new ad from going live on `page_delivers_ad_promise < 0.4`; for a scheduled audit across
existing ads, rank by the composite and give a human the worst 50.

## What stays in code

Fetching, rendering and extraction. The crawl, the JavaScript render if needed, the
boilerplate strip, and the selection of which blocks to send are all code, and they are most
of the engineering. So are the exact checks: HTTP status, redirect chains, the presence of the
tracking parameter, page-load time, and whether the URL in the ad is even the URL that serves.
Those are the most common real faults and none of them is a semantic question. Pausing an ad
is a spend decision and stays a rule with a human.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 300-character ad plus a
2,000-character extracted page bundle plus these five questions (~1,800 characters) is ≈ 1,025
tokens, **≈ $0.000043 per ad-page pair**. Auditing 2,000 live ads is about **$0.09** of
inference — the point being that an alignment audit becomes continuous rather than quarterly.
Sending the raw page instead of the extract would roughly quadruple that and cost accuracy;
the classifying-RAG-passages cookbook's approach of scoring and dropping irrelevant blocks
before the decision is the fallback when clean extraction is not possible. Latency 70–500 ms.
No accuracy figure is published for alignment checking; the closest published shape is the
citation-check cookbook, which flags low confidence for review and reports no metric. Validate
against pairs your marketing team has already judged.

## When the verdict flips

- You send whole pages. Context rot; the answers become noisy and the bill grows with the
  footer.
- The mismatch is structural — a 404, a redirect to the homepage, a dead offer code. Code
  detects those exactly and should, before any call.
- The promise is carried by an image, a video, or a hero graphic with text baked in. Text only.
- You expect it to predict Google's quality score or a conversion rate. Different quantity,
  needs outcome data, and the fit test's "accuracy is the only argument" counter-signal applies.
- Pages are localised and you audit across markets without per-language validation.

## Alternatives considered

- **Manual spot checks.** What most teams do, quarterly, on a sample; this is the thing being
  scaled.
- **Exact-match rules (does the page contain the ad's keyword).** Cheap and easily satisfied by
  a keyword in the footer, which is precisely the failure that makes the check worthless.
- **Embedding similarity between ad and page.** Measures topical relatedness; a page about the
  same product with a different offer scores high, and the offer is what matters.
- **Frontier LLM comparing the two.** Better on subtle mismatch and able to explain it; seconds
  and cents per pair, which is fine for 50 ads and not for a continuous audit of thousands.
- **Small LLM.** Roughly an order of magnitude more cost and latency per multi-question call
  on the consistency cookbooks' figures.
- **A/B testing and conversion data.** The ground truth, and far slower — it tells you the page
  underperformed, not that the offer was contradicted.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/citation_check.md`,
`cookbooks/classifying_rag_passages.md`, `model-jaggedness/jev-1.13.md` (modes 4 and 5),
`models.md`.
