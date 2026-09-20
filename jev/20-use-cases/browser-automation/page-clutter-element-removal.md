---
id: uc-browser-automation-page-clutter-element-removal
title: Classify page containers as content or clutter so a reader mode can hide them
verdict: good
domain: browser-automation
decision_shapes: [classification, detection]
primitives: [choice, noul]
evidence_level: community-report
sources:
  - https://github.com/kitze/unclutter  (jev decides which page elements are clutter; no numbers published)
  - https://github.com/realZachi/typesafe-adblock  (semantic ad and clutter removal as a browser extension; no numbers published)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 large state full of irrelevant detail; mode 6 adversarial content)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input; 70-500 ms)
related: [uc-browser-automation-action-selection-from-accessibility-tree, uc-media-content-page-and-seo-section-grading, uc-realtime-ui-component-selection, au-whole-document-in-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to strip the junk off a web page?" Also: "can jev be a semantic
ad blocker?", "our reader mode keeps eating the article and keeping the newsletter box — can a
model fix it?", "can jev catch the ads that EasyList missed?".

## Verdict

**Good.** The answer set is small and fixed, the input is text you already have in the DOM, the
work is one batched call per page rather than per node per keystroke, and a wrong answer hides a
paragraph or leaves an advert visible — cheap and reversible in both directions. Two public
extensions ship exactly this. It is `good` and not `strong` because neither publishes a
precision or recall figure, so the verdict rests on the shape of the problem, not on a
measurement.

## What jev decides

Code extracts candidate containers first and computes everything numeric: tag, class and id
hints, word count, link density, position in the document, whether the node is sticky or fixed,
whether it sits inside `<article>`. Each container contributes a ~200-character text excerpt.
Twenty to sixty containers go into one call as an enumerated list — never the raw HTML, which is
failure mode 5 with the volume turned up.

```
container_role: Choice (asked once per container)
  instructions: {question: "What is `excerpt` doing on this page, given `page_title`?",
                 focus: "Judge the purpose of the block, not whether it is well written."}
  criteria:
    main_content:    {what: "Part of the article, product description or documentation the
                             reader came for",
                      not_for: "A teaser for a different article"}
    advertising:     {what: "Promotes a third party's product or service, including sponsored
                             placements and affiliate blocks"}
    subscription_wall: {what: "Asks for an email, a login or a payment to continue"}
    consent_banner:  {what: "Cookie, privacy or regional consent notice"}
    related_links:   {what: "Navigation, recirculation, 'you may also like', tag clouds"}
    site_chrome:     {what: "Header, footer, breadcrumbs, legal boilerplate"}

is_load_bearing: Noul
  instructions: "Would hiding this block make the page unusable (the login form, the checkout
                 button, the search box)?"
```

`is_load_bearing` is the safety valve: it is the difference between a tidy page and a broken
one, and it must veto a hide even when `container_role` is confident.

Bands: hide only at `container_role != main_content` above your fitted floor AND
`is_load_bearing` low. Everything else stays visible. The default when jev is unavailable or
slow is "show" — the page renders unchanged.

## What stays in code

Filter-list matching runs first and stays authoritative: EasyList and friends are exact, free
and already correct for the overwhelming majority of known ad networks. Jev is for the unlisted
and the freshly renamed. Also in code: DOM extraction, link density, word counts, the hide
itself, the per-site user override, and the cache. **Cache the verdict per `(domain, selector
path, container_role)`** so a site is paid for once and subsequent visits are free and instant;
without the cache the latency lands in the render path and the economics get worse the more the
user reads.

## Numbers

Neither public project publishes accuracy, latency or cost, so there is no measured result to
quote here. Cost method: `input_tokens ~= chars/4`, `cost = tokens x $0.042 / 1e6`, output free.
A 40-container page at ~200 characters of excerpt plus ~60 characters of code-computed metadata
each (10,400 characters) plus the criteria block (~1,600 characters) is about 3,000 tokens,
**~$0.000126 per page, paid once per site layout** if the cache works. Latency, from the models
page: "70 to 500 ms", "most queries about 100 ms" — acceptable off the critical path, which is
why the design classifies after first paint and hides progressively.

Closest failure mode: **5, large state full of irrelevant detail**, avoided by sending excerpts
of extracted containers rather than HTML. **6, adversarial content** is live too: page text is
written by the party whose adverts you are hiding, and an advert that says "this is the main
article" is a one-line attack. Never let page text change the criteria.

## When the verdict flips

- **The filter list already covers your traffic.** Measure the residue first. If EasyList
  handles 99% of what your users see, this is weak.
- **You need per-frame or per-keystroke decisions.** A network call per DOM mutation is the
  wrong shape; batch and cache or do not do it.
- **The decision must be provably conservative** — an accessibility tool, a compliance archive.
  A probabilistic hide is not acceptable there.
- **The page is an app, not a document.** Container roles stop meaning anything.

## Alternatives considered

- **Filter lists (EasyList, uBlock rules).** Free, exact, community-maintained, and the right
  first stage. Blind to a block that was renamed yesterday.
- **Readability-style heuristics.** Link density and text-to-markup ratio already work well on
  articles; they are the incumbent and they are cheap. Jev wins on the categories heuristics
  cannot name (a subscription wall versus a related-links rail).
- **Frontier LLM over the page.** Better judgement, seconds of latency and cents per page — not
  viable in a browser extension at browsing speed.
- **Trained classifier on DOM features.** Strong once you have labels, and the hide/unhide
  overrides your users generate are exactly those labels. Compare it after a month.
- **Manual per-site selectors.** What power users do today; exact and unmaintainable at scale.

## Sources

- https://github.com/kitze/unclutter — accessed 2026-09-19
- https://github.com/realZachi/typesafe-adblock — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
