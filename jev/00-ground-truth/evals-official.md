---
id: gt-evals-official
title: Every published TypeSafe eval number, with its stated method and biases
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://evals.typesafe.ai/  (workflow evals: overview and four per-workflow charts, methodology)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (comparison table, nuance lists, 193.6x/444.6x provenance, benchmark FAQ)
  - https://typesafe.ai/  (homepage headline claims, side-by-side demo figures)
  - https://docs.typesafe.ai/primitives.md  (parallel-questions cookbook figures)
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (self-consistency agreement figures)
  - https://docs.typesafe.ai/cookbooks/consistency_noul_cookbook.md  (self-consistency variance figures)
---

## Position on public benchmarks

**Q: "How does Jev perform against public benchmarks?"** (blog FAQ, verbatim)

> "We deliberately chose *not* to publish performance against *public* benchmarks. In fact, we plan to only have one-off evals when we make product updates.
>
> Given that we are opening up a new frontier for models, we're pushing for more useful best practices:
>
> * Put no weight on public benchmarks.
> * Encourage users to create their own evals for their use cases (System One tasks are much easier to evaluate).
> * Disclose the nuance in your evals.
> * De-emphasizing benchmarks even when you're ahead.
>
> See this blog post about our philosophy around optimizing for benchmarks."

That post is https://typesafe.ai/blog/antibenchmaxxing ("Lies, Damned Lies, and Benchmarks",
Sep 11, 2026). **TypeSafe publishes no MMLU, no BBH and no public classification benchmark result
for jev.** Third parties have since run public classification benchmarks (Banking77, CLINC150, SST-5,
IMDB, AG News, 20 Newsgroups, Amazon ESCI and others) — those are collected in
`evidence-independent.md`, not here.

## The workflow evals (evals.typesafe.ai)

### Method, verbatim

> "Real world tasks can be executed via structured workflows or standalone prompts. Structure is always better."

> "To automate a task, we decompose the decisions into programmatic rules and intelligent judgments. Rather than ask a model to solve the entire problem in one shot (like the prompt examples in the plot), we ask independent narrow questions and defer to code where possible. We use three types: Noul, yes or no; Choice, one option among several; Score, a level on a scale. The results are then used programmatically to produce the output actions. Averaged across the four example tasks, every model is more accurate, cheaper and faster in the workflow than it is with the same policy as a prompt."

> "**Assume the harness is correct.** Instead of debating the correctness of the harness and labels, we assume that the code is correct, and measure against the current smartest large models. For this eval, the reference labels are generated via an average of the responses of GPT-6 Astra and Claude Fable 5.1, both at high thinking, answering every question in the harness. All other models are evaluated using the provider's default reasoning settings."

> "Each point averages one model configuration's accuracy, cost and time over the four workflows with equal weight, against the consensus labels. Every model runs at its provider's default reasoning setting. Up and to the left is better."

The blog restates it: "we assume there is a correct compute graph (a 'workflow' represented in code)
and use the predictions of the largest, smartest, and most expensive external models as reference
probabilities… every model gets the same workflow. We test how they compare to the average of the
smartest models (in this case, Astra and Fable)."

### Overview — mean over the four workflows (agreement with the reference · cost per case · seconds per case)

Every "accuracy" percentage in the tables below — jev's 67.8% included — is **agreement with the
reference (average of GPT-6 Astra and Claude Fable 5.1 at high thinking), not human-labelled
correctness**. That is TypeSafe's own stated method, quoted above. The column heading "accuracy"
below is the eval site's word, kept verbatim.

| Model | workflow | prompt |
| --- | --- | --- |
| haiku 4.5 | 53.6% · $0.0195 · 12.5 s | 18.1% · $0.0363 · 21.2 s |
| opus 5 | 73.1% · $0.1761 · 37.8 s | 64.8% · $0.3417 · 70.5 s |
| sonnet 5 | 67.8% · $0.1174 · 78.1 s | 60.4% · $0.2251 · 149.2 s |
| DS v4 flash | 64.4% · $0.0059 · 51.9 s | 59.3% · $0.0132 · 120.1 s |
| DS v4 pro | 65.5% · $0.0413 · 86.5 s | 59.7% · $0.0907 · 192.1 s |
| luna | 66.8% · $0.0033 · 12.9 s | 51.9% · $0.0079 · 27.3 s |
| sol | 74.1% · $0.0836 · 23.3 s | 63.4% · $0.2005 · 48.6 s |
| terra | 67.9% · $0.0304 · 10.1 s | 61.6% · $0.0750 · 25.1 s |
| **Jev** | **67.8% · $0.0004 · 0.4 s** | — (no prompt configuration; Jev does not do prompts) |

Read plainly: **jev is mid-table** — 67.8% agreement with the reference (average of GPT-6 Astra and
Claude Fable 5.1 at high thinking), not human-labelled correctness — ahead of haiku 4.5, DS v4 flash, DS v4 pro and
luna; equal to sonnet 5; behind terra (67.9%), opus 5 (73.1%) and sol (74.1%) — **and far cheaper and
faster than every LLM configuration here.** Against the workflow rows, jev's $0.0004 is between about
8× (luna, $0.0033) and about 440× (opus 5, $0.1761) cheaper, and its 0.4 s is between about 25×
(terra, 10.1 s) and about 215× (DS v4 pro, 86.5 s) faster — my own arithmetic on the rounded published
figures, not published ratios. That mid-tier-agreement / huge-efficiency shape is exactly what the
corpus editorial rule means by "accuracy is not a claimable property" — and note that the 67.8%
is not an accuracy figure at all, only agreement with two frontier models.

### Security Incidents

> "A security alert fires on a laptop or a server. Given the alert and everything on file about that machine, we decide whether to close it, pass it to an analyst, or contain it now."

| Model | workflow | prompt |
| --- | --- | --- |
| haiku 4.5 | 58.8% · $0.0047 · 3.4 s | 17.1% · $0.0068 · 4.6 s |
| opus 5 | 66.2% · $0.0574 · 15.1 s | 62.9% · $0.0619 · 13.5 s |
| sonnet 5 | 60.8% · $0.0271 · 18.9 s | 51.7% · $0.0506 · 37.5 s |
| DS v4 flash | 37.9% · $0.0032 · 37.4 s | 44.6% · $0.0037 · 41.9 s |
| DS v4 pro | 41.7% · $0.0234 · 60.0 s | 37.1% · $0.0267 · 66.3 s |
| luna | 52.1% · $0.0013 · 7.0 s | 29.6% · $0.0021 · 13.4 s |
| sol | 62.5% · $0.0295 · 8.5 s | 45.8% · $0.0472 · 14.0 s |
| terra | 51.2% · $0.0119 · 5.7 s | 45.4% · $0.0140 · 7.1 s |
| **Jev** | **61.7% · $0.0001 · 0.3 s** | — |

### Agent Trace Observability

> "A support agent has just finished with a customer. Given the whole run, every tool call included, we decide whether a person needs to look at it, and how soon."

| Model | workflow | prompt |
| --- | --- | --- |
| haiku 4.5 | 57.2% · $0.0100 · 7.1 s | 29.3% · $0.0163 · 9.3 s |
| opus 5 | 75.2% · $0.1033 · 27.4 s | 63.5% · $0.1642 · 37.5 s |
| sonnet 5 | 68.0% · $0.0545 · 38.0 s | 65.8% · $0.0863 · 53.0 s |
| DS v4 flash | 73.0% · $0.0043 · 51.7 s | 68.5% · $0.0063 · 62.7 s |
| DS v4 pro | 71.6% · $0.0357 · 90.1 s | 72.1% · $0.0424 · 92.6 s |
| luna | 76.1% · $0.0025 · 14.5 s | 66.2% · $0.0038 · 15.1 s |
| sol | 76.6% · $0.0575 · 40.3 s | 73.9% · $0.0907 · 37.0 s |
| terra | 73.0% · $0.0209 · 11.4 s | 72.5% · $0.0350 · 14.9 s |
| **Jev** | **71.6% · $0.0003 · 0.5 s** | — |

### Invoice Processing

> "A vendor's bill arrives. Given the bill, the order behind it, and what was actually delivered, we decide whether it gets paid, held, or sent back."

| Model | workflow | prompt |
| --- | --- | --- |
| haiku 4.5 | 42.9% · $0.0558 · 30.8 s | 6.0% · $0.0763 · 63.4 s |
| opus 5 | 78.4% · $0.4856 · 92.1 s | 66.9% · $0.7699 · 188.7 s |
| sonnet 5 | 72.9% · $0.3616 · 241.3 s | 62.4% · $0.5548 · 409.4 s |
| DS v4 flash | 69.8% · $0.0133 · 84.1 s | 58.2% · $0.0288 · 281.7 s |
| DS v4 pro | 72.7% · $0.0830 · 137.4 s | 63.8% · $0.2039 · 474.4 s |
| luna | 67.8% · $0.0081 · 21.4 s | 55.1% · $0.0160 · 61.5 s |
| sol | 79.1% · $0.2152 · 34.3 s | 65.1% · $0.4338 · 118.4 s |
| terra | 74.7% · $0.0778 · 17.3 s | 64.0% · $0.1618 · 62.0 s |
| **Jev** | **61.8% · $0.0011 · 0.5 s** | — |

**This is jev's weakest published workflow** — last but one on accuracy, 17 points below sol. Invoice
processing is dense in dates, amounts and arithmetic, which is precisely failure modes 2 and 3.

### Customer Service

> "A customer writes in. Given the thread so far and the state of their account, we decide what the assistant should say and do next."

| Model | workflow | prompt |
| --- | --- | --- |
| haiku 4.5 | 55.4% · $0.0074 · 8.8 s | 19.9% · $0.0459 · 7.6 s |
| opus 5 | 72.4% · $0.0579 · 16.6 s | 66.0% · $0.3710 · 42.2 s |
| sonnet 5 | 69.3% · $0.0264 · 14.3 s | 61.6% · $0.2085 · 96.7 s |
| DS v4 flash | 76.8% · $0.0029 · 34.6 s | 65.8% · $0.0139 · 93.9 s |
| DS v4 pro | 76.1% · $0.0232 · 58.6 s | 65.8% · $0.0898 · 134.9 s |
| luna | 71.4% · $0.0013 · 8.8 s | 56.9% · $0.0094 · 19.2 s |
| sol | 78.3% · $0.0323 · 10.1 s | 69.0% · $0.2303 · 24.9 s |
| terra | 72.7% · $0.0111 · 6.0 s | 64.4% · $0.0894 · 16.3 s |
| **Jev** | **76.0% · $0.0001 · 0.4 s** | — |

**Jev's strongest published workflow** — fourth of nine on accuracy, 2.3 points behind sol and within
0.8 points of DS v4 flash and DS v4 pro, at roughly 1/300th of sol's cost and 1/25th of its time.

### Reference models and the model roster

Reference labels: **GPT-6 Astra and Claude Fable 5.1, both at high thinking**, averaged. Evaluated
configurations span TypeSafe (Jev), OpenAI, Anthropic and Fireworks-served models: `haiku 4.5`,
`opus 5`, `sonnet 5`, `DS v4 flash`, `DS v4 pro`, `luna`, `sol`, `terra`. Astra and Fable do not
appear as evaluated points because they define the labels.

### Stated biases and nuances, verbatim (blog)

> "This is where the claims of 193.6x faster, 444.6x cheaper on our home page comes from, and we expect that these are on the higher end of real world gains."

> "These content of these workflows were not deliberately chosen nor constructed to make our model look good, and are not in our training distribution. However, they were made by individuals on our model capabilities team, so some bias could exist."

> "We use the average of GPT-6 Astra and Fable 5.1 as the reference answer, which biases answers towards OpenAI and Anthropic's models. We likely underestimate the relative performance of our model and DeepSeek's models."

> "The LLMs use our System One LLM wrapper, which constrains LLMs to output structured decisions compatible with our API. We have found this to be the most accurate way to get decisions from LLMs, but this tends to be slower and more expensive than giving decisions without probabilities."

The wrapper is open source: https://github.com/typesafe-ai/system-one-adapter-python.

Self-declared limits on the three "easily verifiable" claims: speed — "our published evals are
generally run from our laptops on the West Coast (this is where our service is currently based)";
cost — "We can't prove it isn't subsidized"; type errors — "This would be an easy thing to falsify
with just a single counter-example, but it is mathematically impossible."

## The 193.6x / 444.6x provenance

The homepage headline reads "193.6x Faster, 444.6x Cheaper. *based on workflows for System One tasks".
The blog attributes both numbers to the workflow evals section (quote above) and adds "we expect that
these are on the higher end of real world gains."

**The exact pairing is not stated.** The eval site publishes agreement/cost/time per configuration
rounded to 1 decimal place (accuracy, seconds) and 4 decimal places (dollars), and those rounded
figures do not reproduce 193.6 and 444.6 exactly. The nearest like-for-like reading — jev's overall
67.8% (agreement with the reference, not human-labelled correctness) matches `sonnet 5 · workflow`
at 67.8%, $0.1174, 78.1 s against jev's $0.0004, 0.4 s — gives
roughly 195× on time and 294× on cost by my own arithmetic on the rounded published values. Treat the
derivation of the exact headline figures as **could not verify**; cite 193.6x / 444.6x only with the
company's own qualifier that they are "on the higher end of real world gains."

## The side-by-side demo (homepage)

| | TypeSafe | LLMs |
| --- | --- | --- |
| Cost | $0.000081 | $0.013880 |
| Completed in | 0.114 s | 8.566 s |

Stated caveats (blog, "Nuance"): "The query is highly simplified"; "The state is also a short, dense,
and detailed paragraph, to emphasize the difference in sampling methodology. The relatively shorter
input paints our model in an advantageous light"; "the only disagreement with GPT-5.6 Terra is on
'Churn likelihood level'. The actual answer seems genuinely ambiguous to us"; "We used GPT-5.6 Terra
with default reasoning for this example, because we've found it to be the most comparable at
intelligence to Jev on average."

## Hallucination and type-error claims — and exactly how they are defined

The blog publishes two bar charts (image
https://framerusercontent.com/images/KEoJ6ZaJkOZG6mcjBsOlB3NCqek.png).

**Structured output error rate (lower is better):** Jev **0%**; luna 0.58%; terra 0.58%; sol 0.83%;
astra 1.43%; gemini 3.1 pro 1.94%; gemini 3.8 flash 3.15%; opus 5 5.73%; fable 5.1 8.25%;
sonnet 5 13.2%; haiku 4.5 45.5%.

**Tool call error rate (lower is better):** Jev **0%**; opus 5 0.67%; fable 5.1 1.38%; haiku 4.5 1.76%;
sonnet 5 2.07%; gemini 3.8 flash 2.15%; gemini 3.1 pro 3.17%; terra 5.5%; luna 7.67%; astra 16.6%;
sol 17.0%.

The definitional caveats are the whole story, verbatim:

> "The numbers for LLMs are from OpenRouter i.e., there almost certainly is bias here: more complex queries might be routed to better models."
>
> "Our number is not empirical. Schema matching is guaranteed, thus we can confidently add 0% into the plots."

So: **jev's 0% is an analytic claim about schema conformance, not a measurement.** It says the output
cannot violate the declared type — "The model never makes type errors" (blog comparison table) — and
it says nothing about whether the chosen option is the right one. The LLM figures come from a third
party (OpenRouter aggregate statistics), not from a controlled run by TypeSafe, and are not
like-for-like with jev's analytic 0%.

The surrounding argument: "Hallucination and type-safety are intrinsically related, and we think the
latter is table stakes for automation… Existing models, *no matter how smart*, still hallucinate and
have type errors."

And the launch sentence: "While Jev gives up string generation, it's optimized for structured outputs
and *can't* hallucinate." Read against the homepage FAQ — "Jev guarantees the shape of its answers,
not that every decision is correct" — "can't hallucinate" means "cannot emit a value outside the
declared answer space", not "cannot be wrong".

## Other official numbers

* **Batching:** "batching 13 questions into one call is 11.5x cheaper and 9.6x faster than 13 separate calls, with no change in the answers" — https://docs.typesafe.ai/primitives.md, citing https://docs.typesafe.ai/cookbooks/parallel_questions.md. The cookbook itself reports **12.2x cheaper and 10.0x faster** for the same experiment ($0.000497 / 0.27 s in one call against $0.006090 / 2.71 s in 13), so TypeSafe publishes two different ratio pairs for one run; cite whichever page you are quoting and say which.
* **Self-consistency (nouls, 15 repeats, sampled 2026-09-11):** "TypeSafe's mean per-question probability standard deviation is `0.0102`, below all LLM probability conditions here."
* **Self-consistency (choices, 15 repeats, sampled 2026-09-11):** "the LLM distribution settings repeat their plurality labels 87.5% to 100% of the time, compared with TypeSafe's 90.8%… TypeSafe flips on 2 of the 8 questions." With a 0.60 top-probability abstention gate: "TypeSafe's agreement then rises to 99.2%, with automatic labels on 74.2% of answers."
* **Doom demo cost:** "The engineer behind it was worried about making 10 queries a second (which ends up costing ~$7/hour)."
* **Wikiracing caveat:** "Our speedups here tend to be a lot less than in previous demos. That's because this is against the non-reasoning modes of the models (except Astra which was set to the lowest reasoning setting)… The LLMs look much worse at this task than with reasoning enabled."

## What is not published

No per-task precision/recall, no confusion matrices, no calibration curves, no confidence-vs-accuracy
plots, no abstention-rate curves for the workflow evals, and no raw eval data download link found.
TypeSafe's official eval site includes no independent validation; independent evaluations are
collected in `evidence-independent.md`. The eval site does say it publishes "examples,
disagreements, full queries, and each workflow" — those detail pages exist on the site's per-workflow
tabs but were not machine-extracted for this file.
