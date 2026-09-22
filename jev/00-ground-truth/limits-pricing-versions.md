---
id: gt-limits-pricing-versions
title: Limits, price, rate limits, aliases, data handling, SDK versions
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/models.md  (price, rate limits, context, input, aliases, language, data handling)
  - https://docs.typesafe.ai/primitives.md  (token budget for questions)
  - https://docs.typesafe.ai/primitives/choice.md  (255 options)
  - https://docs.typesafe.ai/primitives/score.md  (2 to 10 levels)
  - https://docs.typesafe.ai/concepts/state.md  (text-only, language note)
  - https://docs.typesafe.ai/legal.md  (DPA, MCA, privacy policy, ZDR)
  - https://docs.typesafe.ai/sdk/python/changelog.md  (Python SDK releases)
  - https://docs.typesafe.ai/sdk/javascript/changelog.md  (JS SDK releases)
  - https://pypi.org/project/typesafe-sdk/  (versions, upload dates, Python requirement)
  - https://www.npmjs.com/package/@typesafe-ai/sdk  (versions, dates, Node requirement)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (pricing comparison, output free)
  - https://typesafe.ai/  (price headline, subsidy FAQ)
---

## The model card, verbatim

| Jev 1.13 | `jev-1.13.0` |
| :-- | :-- |
| Price (per Btok / per Mtok) | $42 / $0.042 |
| Rate limits | 250,000 tokens per second / 1,200 requests per minute |
| Context length | 64k tokens per request; 32k tokens for `state` plus the longest question |
| Input | Text only. String, JSON object, or array of text values. No image, audio, or video input. |

— https://docs.typesafe.ai/models.md

## Price

> "**Price:** Charged per input token. Output tokens are free. A Btok is a billion tokens and an Mtok is a million tokens."
> — https://docs.typesafe.ai/models.md

The launch post's comparison table states it against LLMs:

> "Input tokens: $0.042 / MTok ($42 per billion tokens). Output tokens: FREE (too cheap to meter)."
> versus, for existing LLMs, "Input tokens: from $0.20 to $10 / MTok. Output tokens: ~5x more expensive than input tokens."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

The homepage states "$42 Per Billion input tokens" and "238x Lower input price than Claude Fable 5.1"
(https://typesafe.ai/).

On sustainability, the homepage FAQ answer to "Are these prices temporary or subsidized?" is:

> "We can serve Jev profitably at our current prices. Our goal is to make intelligence more affordable over time as we improve the technology."

The blog is more hedged: "Cost per call: We make our pricing transparent. We can't prove it isn't
subsidized; we'll need the long-term to prove the sustainability of our pricing (which we expect to go
down, not up)."

## Context

_Adjudication: two official pages state the budget differently. The Models page (64k per request; 32k for state plus the longest question) is the operational reference, since it is the model card; the Primitives page's "around 32,000 tokens" for state and questions together is the more conservative planning figure. For planning, apply the stricter reading: keep state plus all questions under about 32k tokens and
any single request under 64k; a request that satisfies the Models page but exceeds the Primitives page's
32k combined figure may or may not be accepted, and the corpus has no test of that boundary._ budgets

> "**Context length:** Jev ingests the `state` once and evaluates every question against it in parallel. The 64k budget covers the `state` plus all questions combined; the 32k budget applies to the `state` plus the single longest question."
> — https://docs.typesafe.ai/models.md

The primitives page gives a rule of thumb for how many questions fit:

> "The number of questions in one request is limited only by the request's token budget, which the state and the questions share. The budget is around 32,000 tokens, roughly 150,000 characters of English text."
> — https://docs.typesafe.ai/primitives.md

## Per-question limits

* **Choice options:** "A Choice question accepts up to 255 options, and adding options costs a few tokens each, so give the model the full list of teams, categories, or products rather than a shortlist." (https://docs.typesafe.ai/primitives/choice.md). The blog confirms the cardinality ceiling: "Jev supports a cardinality up to 255. For the higher cardinality choices, we do a 2 stage-system of scoring independently then making an explicit choice, hence the occassional slowdown." (https://typesafe.ai/blog/introducing-system-one-models-and-jev)
* **Score levels:** `criteria` is "An ordered array of level descriptions, from the low end of the scale to the high end. Needs at least two levels and takes up to 10." (https://docs.typesafe.ai/primitives/score.md). The API reference states the floor: "You must include at least two levels." (https://docs.typesafe.ai/api.md). Guidance: "Use as many levels as you can describe distinctly, up to 10. Three is fine. Don't add levels you can't describe distinctly."

## Rate limits

> "**Rate limits:** Measured in tokens per second and requests per minute. A request over either limit returns `429 Too Many Requests`. Our [client SDKs] retry with backoff by default and honor the `retry-after` header when the response carries one."
> — https://docs.typesafe.ai/models.md

The dynamic-limits warning, verbatim:

> "**Rate limits are adjusting dynamically.** We are serving a very large volume of demand, and the limits above can change without notice while we do, as upcoming large GPU deals land and we let in more users. Once things settle down more, we'll be able to offer more stable limits. Higher limits are available on custom and enterprise plans. Contact sales@typesafe.ai."
> — https://docs.typesafe.ai/models.md

Practical consequence for corpus consumers: **do not treat 250,000 tok/s or 1,200 rpm as a stable
capacity plan.** They are the published numbers as of 2026-09-19 and TypeSafe reserves the right to
change them without notice.

## Text only

> "Jev accepts text only. State must be a string, JSON object, or array of text values. Images, audio, and video are not supported (yet)."
> — https://docs.typesafe.ai/concepts/state.md

> "Pre-process non-text inputs (images, audio, video, binaries) into text or structured fields before sending them as `state`."
> — https://docs.typesafe.ai/models.md

## Language support

> "Jev accepts natural-language text. English is the primary training language and where accuracy is currently best. Other languages, including CJK scripts, are handled but not equally well; test on your own content before relying on Jev for a non-English workload, and pay close attention to [Confidence] when routing."
> — https://docs.typesafe.ai/models.md

The State page repeats: "Jev's primary training language is English; other languages, including CJK
scripts, are accepted but currently have lower accuracy."

No per-language accuracy numbers are published — treat any non-English claim as **not published**.

## Aliases and pinning

| Alias | Points to | Meaning |
| :-- | :-- | :-- |
| `jev-latest` | `jev-1.13.0` | "The most recent stable, official release. The default in our client SDKs, and the name the examples in these docs use." |
| `jev-preview` | `jev-1.13.0` | "The most recent release, whether or not it is an official one. Moves ahead of `jev-latest` when a preview build is available." |

> "`jev-preview` currently points to the same model as `jev-latest`. There is no preview build available right now."

Pinning advice, verbatim:

> "An alias moves when a new release ships, so the answers behind it can change without a change on your side. The response's `model` field reports the versioned ID that answered, so you can log which model produced each result. If you have tuned confidence thresholds against a specific version, pin that version's ID instead of the alias and move to the new one on your own schedule."
> — https://docs.typesafe.ai/models.md

`GET /v1/models` "currently lists the aliases. Versioned IDs such as `jev-1.13.0` are accepted by the
`model` field whether or not they appear in the list."

## Customization

> "Jev is not fine-tuned or LoRA-adapted with customer data. It is trained with RLCD to return calibrated decisions, and the same weights serve every account."

The three supported adaptation levers are: proprietary content in `state`; domain rules and boundary
cases in `instructions` and `criteria`; and decomposition into atomic questions combined in code (or
fed as features to a downstream classical model).

## Data handling

> "Jev is not trained on customer requests or responses. See Legal for the Data Processing Agreement, the Privacy Policy, and details on zero data retention (ZDR) for enterprise customers."
> — https://docs.typesafe.ai/models.md

> "We also offer zero data retention (ZDR) for enterprise customers. Contact privacy@typesafe.ai to learn more."
> — https://docs.typesafe.ai/legal.md

Legal documents: Data Processing Agreement (https://typesafe.ai/legal/data-processing), Master
Customer Agreement (https://typesafe.ai/legal/mca), Privacy Policy
(https://typesafe.ai/legal/privacy-policy). Terms of Use is linked from the site footer
(https://typesafe.ai/legal/terms).

The training-data FAQ reinforces it: "We make all the data ourselves. We wouldn't train on your data
even if you asked us to (no offense)."
(https://typesafe.ai/blog/introducing-system-one-models-and-jev)

## Hosting region

No hosting region is published in the docs. The only related statement is from the launch post's
evidence section:

> "Speed per call: We truly are that fast, though our published evals are generally run from our laptops on the West Coast (this is where our service is currently based)."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

That is a statement about where the service is based, not a data-residency commitment. A formal
hosting region / data-residency policy is **not published** in the sources reviewed; check the DPA.

## Latency figures published

Three different numbers appear across official surfaces, all for different framings:

* "Most queries complete in about 100 ms." — https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md
* "End-to-end response time is 70ms-500ms for TypeSafe." — https://typesafe.ai/blog/introducing-system-one-models-and-jev
* "Frontier intelligence at real-time speeds (150ms)" — https://docs.typesafe.ai/concepts/use-case-map.md

On the eval site, the mean measured time per case for Jev across four workflows is 0.4 s (that is a
whole workflow of many calls, not a single call) — see `evals-official.md`.

## SDK versions and dates

**Python — `typesafe-sdk`** (PyPI, requires Python >= 3.10):

| Version | Date | Note |
| --- | --- | --- |
| `0.0.1a0` | 2026-09-09 | placeholder upload |
| `0.5.7` | 2026-09-11 (PyPI upload) / changelog dates it 2026-09-14 | "initial public release of TypeSafe Python SDK" |
| `0.6.0` | 2026-09-15 | breaking: "accept `Score.criteria` as an ordered sequence instead of a dictionary keyed by integers" |
| `0.7.0` | 2026-09-18 | breaking: "ser/de library has been changed from `msgspec` to `pydantic`"; new `response_model` argument |

Repository: https://github.com/typesafe-ai/typesafe-sdk-python.

**JavaScript / TypeScript — `@typesafe-ai/sdk`** (npm, `engines.node >= 20`, MIT):

| Version | Date |
| --- | --- |
| `0.0.0-bootstrap.0` | 2026-09-12 |
| `0.5.7` | 2026-09-12 — "initial public release of TypeSafe JavaScript and TypeScript SDK" (docs changelog dates it 2026-09-11) |
| `0.6.0` | 2026-09-15 — breaking: "accept `Score.criteria` as an ordered sequence instead of a dictionary keyed by integers" |

Repository: https://github.com/typesafe-ai/typesafe-sdk-js.

Both SDKs are pre-1.0. Expect breaking changes; both have already shipped one in a minor bump.

Cookbooks install extra packages from a private-ish index: `pip install ... cooksafe
--extra-index-url https://pypi.typesafe.ai/`
(https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md).
