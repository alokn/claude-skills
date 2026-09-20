---
id: gt-glossary
title: Glossary of jev and System One terms
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/concepts/state.md
  - https://docs.typesafe.ai/concepts/system-one.md
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md
  - https://docs.typesafe.ai/concepts/use-case-map.md
  - https://docs.typesafe.ai/primitives.md
  - https://docs.typesafe.ai/primitives/choice.md
  - https://docs.typesafe.ai/primitives/score.md
  - https://docs.typesafe.ai/primitives/noul.md
  - https://docs.typesafe.ai/primitives/advanced.md
  - https://docs.typesafe.ai/confidence.md
  - https://docs.typesafe.ai/api.md
  - https://docs.typesafe.ai/models.md
  - https://docs.typesafe.ai/legal.md
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md
  - https://docs.typesafe.ai/patterns.md and /patterns/*
  - https://docs.typesafe.ai/introduction/machine-learning-primer.md
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev
  - https://typesafe.ai/
  - https://docs.typesafe.ai/cookbooks/function_calling.md
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md
  - https://docs.typesafe.ai/cookbooks/entity_alignment.md
  - https://docs.typesafe.ai/cookbooks/autoformat.md
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md
  - https://github.com/bestdan/workflow-skills/pull/757  (confidence collapse under injection; "tripwire")
---

One or two sentences each, with the source that supports it.

**Abstain / abstention** — Not an action jev takes. Every request returns a typed answer, so
"abstention" is a developer-defined policy: your code compares `confidence` (or a Noul probability)
against a threshold you chose and sends that case to a human, a coarser label or a second question.
TypeSafe's published recipe is to act automatically on high confidence and route low confidence
elsewhere. (https://docs.typesafe.ai/confidence.md; see **Confidence-gated routing**)

**AI-powered software** — The architecture TypeSafe designs for: "Code handles deterministic work and
owns the control flow. The model appears only where the system needs programmable common sense or
needs to interpret unstructured data." Contrasted with traditional software and LLM agents.
(https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md)

**Alias** — "a model name that resolves to a versioned model ID." `jev-latest` and `jev-preview` both
currently resolve to `jev-1.13.0`; an alias moves when a new release ships, so pin the versioned ID if
you have tuned thresholds. (https://docs.typesafe.ai/models.md)

**Answer** — The typed result returned under the question id you chose. Every answer carries a `type`
matching its question; Choice and Score also carry `confidence`. (https://docs.typesafe.ai/api.md)

**Binary classifier / boolean / yes-no question** — Alias for **Noul**, the primitive for this
shape: it returns a single number, the probability that the answer is yes, and has no `confidence`
and no `probabilities` field. One predicate per Noul; several Nouls can ride in one call.
(https://docs.typesafe.ai/primitives/noul.md)

**Brier score** — Mean squared error between a predicted probability and the 0/1 outcome; lower is
better, and unlike ECE it penalises poor calibration *and* lack of sharpness. TypeSafe publishes
none. One independent pilot reports jev at Brier 0.846 on DAIR Emotion against
fastino/gliner2.5-multi-v1's 0.668 on the same 300 held-out items — where jev had the *higher*
accuracy, so the two measures moved in opposite directions. (see `gt-evidence-independent`)

**Calibration** — The property that "Higher probability should correspond to a greater chance that the
answer is correct", measured across groups of predictions: outcomes given 0.8 should occur about 80%
of the time. It "does not guarantee that an individual answer is correct."
(https://docs.typesafe.ai/introduction/machine-learning-primer.md)

**Choice** — The primitive for "selecting one option from a defined set." Returns `choice`,
`probabilities` (summing to 1), and `confidence`; accepts up to 255 options.
(https://docs.typesafe.ai/primitives/choice.md)

**Composite scoring** — The pattern of breaking "a complex judgment into atomic scores, [combining]
with weights you control in code", normalising each score by `len(criteria) - 1` first.
(https://docs.typesafe.ai/patterns/composite-scoring.md, https://docs.typesafe.ai/primitives/score.md)

**Confidence** — "A number from 0 to 1 computed from how `probabilities` is spread. A flat shape …
means low confidence. A single peak on one option means high confidence." Returned on Choice and Score
only; the exact formula is not published. (https://docs.typesafe.ai/confidence.md)

**Confidence-gated routing** — The pattern of using confidence "as a second axis. The answer tells you
what; confidence tells you whether to act", with per-action thresholds scaled to the consequences of
being wrong. (https://docs.typesafe.ai/patterns/confidence-routing.md)

**Consistency** — TypeSafe's preferred property over determinism: "making similar decisions when the
meaning stays similar, even if the wording changes. Jev is designed for consistency."
(https://typesafe.ai/, FAQ)

**Context rot** — Accuracy loss from irrelevant material in the state: "Jev suffers from context rot,
so unrelated material in the `state` costs you accuracy." Note it applies to state size, not question
count. (https://docs.typesafe.ai/model-jaggedness/jev-1.13.md,
https://docs.typesafe.ai/introduction.md)

**Coverage** — In a confidence-gated design, the fraction of cases your code decides automatically
instead of routing away. It trades against accuracy on the accepted set and the two must always be
quoted together: the choices consistency cookbook reports agreement rising to 99.2% with "automatic
labels on 74.2% of answers" under a 0.60 gate.
(https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md; see **Selective prediction**)

**Criteria** — "The possible answers: a map of options for a Choice question, an ordered list of
levels for a Score, and an optional description of yes and no for a Noul."
(https://docs.typesafe.ai/primitives.md)

**Data residency** — Where requests are processed and stored. TypeSafe publishes no hosting-region
or data-residency policy in the sources reviewed; the only locality statement found is that its
published evals are "generally run from our laptops on the West Coast (this is where our service is
currently based)", which describes where the company sits rather than a commitment about your data.
Check the DPA. (https://typesafe.ai/blog/introducing-system-one-models-and-jev; see
`gt-limits-pricing-versions`, **ZDR**)

**Decision shapes** — The task taxonomy in the use-case map: classification, detection, scoring,
routing, search, retrieval, ranking, verification, ML feature extraction, structured data extraction.
(https://docs.typesafe.ai/concepts/use-case-map.md)

**ECE (expected calibration error)** — The usual scalar summary of calibration: the average gap
between stated probability and observed accuracy across confidence bins, where 0 is perfect.
TypeSafe publishes no ECE figure for jev; independent measurements range from 0.045 (20 Newsgroups
ORDER BY) through 0.121 (decision triage) to 0.242 (Amazon ESCI product relevance), which is why the
corpus treats calibration as something to measure on your own distribution rather than assume.
(see `gt-evidence-independent`, `gt-confidence-and-calibration`)

**Entity resolution** — Deciding whether two records describe the same thing. Not a whole-corpus jev
task, because the pair count is quadratic: blocking in code produces candidate pairs and jev judges
each pair. TypeSafe's cookbook routes 450 pairs with a 3-level Score — 40 merged, 50 to a curator
queue, 360 unlinked — and publishes no precision or recall against a string-similarity or embedding
baseline. (https://docs.typesafe.ai/cookbooks/entity_alignment.md)

**EntryType** — The union type accepted by `instructions` and every `criteria` value: "`string`,
`object`, `array`, or `null`." (https://docs.typesafe.ai/primitives/advanced.md)

**Enum / one-of / single-label classification** — Alias for **Choice**, the primitive for
"selecting one option from a defined set": up to 255 options, returning the chosen option, the full
`probabilities` distribution and a `confidence`. (https://docs.typesafe.ai/primitives/choice.md)

**Function calling** — Turning a natural-language request into a function name plus arguments. jev
does it without generating anything: the cookbook reads Python signatures and emits one Choice per
`Literal` argument and one Noul per `bool` flag, so every argument comes from a closed set and every
one carries a confidence. Arguments that are free text have no jev equivalent and must come from
code or an LLM. (https://docs.typesafe.ai/cookbooks/function_calling.md)

**Instructions** — "The question you are asking about the state. This is where your evaluation logic
goes. Write it as a clear, specific question, or as a statement for the model to judge."
(https://docs.typesafe.ai/primitives.md)

**Intent routing** — The pattern of classifying "incoming requests and [routing] each to the optimal
handler: deterministic logic, a specialist LLM, or a human."
(https://docs.typesafe.ai/patterns/intent-routing.md)

**Jaggedness** — TypeSafe's word for the model's known uneven capability; the `jev-1.13` page lists
nine failure modes "we are aware of with jev-1.13. Many of these will be fixed in later versions."
(https://docs.typesafe.ai/model-jaggedness/jev-1.13.md)

**Jev** — "TypeSafe's flagship model and the first System One model." Named after William Stanley
Jevons, on the expectation that cheaper intelligence unlocks disproportionately more demand.
(https://docs.typesafe.ai/introduction.md, https://typesafe.ai/blog/introducing-system-one-models-and-jev)

**JSON mode / structured output** — What LLM APIs offer, and not the same guarantee. OpenAI's
`strict: true` and Anthropic's structured outputs constrain decoding against a supplied JSON Schema;
Instructor and BAML validate or repair after the fact. All of them guarantee the *shape* of a
generated string and none attaches a meaningful probability to the value. jev's guarantee is
structural rather than a decoding constraint — "Schema matching is guaranteed" — and every Choice or
Score answer comes back with `probabilities` and `confidence`. The trade is that jev cannot fill a
free-text field at all. (https://typesafe.ai/blog/introducing-system-one-models-and-jev; see
`df-alternatives` §10)

**Legend** — The Score answer field mapping "Each level number mapped back to its description."
(https://docs.typesafe.ai/api.md)

**Level** — "one point on the spectrum of possible answers, described in words. A level's number is
its position in the `criteria` array, starting at 0." Two minimum, ten maximum.
(https://docs.typesafe.ai/primitives/score.md)

**Machine Native Intelligence** — TypeSafe's framing of its target: "AI with software-like properties
such as structure, reliability, observability, testability, speed, consistency, and low cost."
(https://docs.typesafe.ai/introduction/machine-learning-primer.md)

**Max option probability vs confidence** — Two different numbers on the same answer, easily
conflated. `probabilities` is the distribution, and its maximum is the winning option's probability;
`confidence` is separately "computed from how `probabilities` is spread". They are not equal — the
autoformat cookbook prints `confidence 0.43: paragraph 0.53, list_item 0.24, callout 0.19` for one
block, a 0.53 winning probability at 0.43 confidence. Say which one your threshold reads.
(https://docs.typesafe.ai/confidence.md, https://docs.typesafe.ai/cookbooks/autoformat.md)

**Mode dropping** — An RLHF side effect: "the model learns to favor a particular style, such as
instruction following, while reducing the probability of other possible outputs"; a milder form of
mode collapse. (https://docs.typesafe.ai/introduction/machine-learning-primer.md)

**Multilabel classification** — Assigning any number of labels to one item. jev has no multilabel
primitive; the shape is one Noul per label inside a single call, which loses the "exactly one of"
property Choice gives and, because of question independence, leaves the labels mutually
unconstrained. Encoders do this natively with independent sigmoid heads.
(https://docs.typesafe.ai/primitives/noul.md, https://docs.typesafe.ai/primitives.md)

**Noul** — The yes/no primitive. "A Noul answer is a single number, `noul`, the probability that the
answer is yes." It has no `confidence` and no `probabilities` field.
(https://docs.typesafe.ai/primitives/noul.md)

**OOD (out of distribution)** — Input unlike what the model's training distribution covers. jev
exposes no OOD detector, and confidence is not one: the published failure modes include confident
errors and adversarial content that "can move the answer". The available proxies are a shadow trial
on real traffic and per-class calibration checks.
(https://docs.typesafe.ai/model-jaggedness/jev-1.13.md; see **Shadow mode**)

**Parallel sampler** — The claimed architectural difference from LLMs: jev "Generates all outputs in a
single query", where LLMs generate "one token at a time, each conditioned on the last." No mechanism
detail is published. (https://typesafe.ai/blog/introducing-system-one-models-and-jev)

**PII (personally identifiable information)** — No jev-specific control for it was found in the
docs. State goes to a hosted API, there is no documented self-hosted or on-premises offering, and
zero data retention is an enterprise-only offering, so redaction or tokenisation before the call is
the developer's job. (https://docs.typesafe.ai/legal.md, https://docs.typesafe.ai/models.md; see
**ZDR**, **Data residency**)

**Primitive** — "the small, typed building blocks you compose in code. They come in pairs: a question
defines one judgment … and its answer is the typed value that comes back."
(https://docs.typesafe.ai/primitives.md)

**Probabilities** — The full distribution over your options (Choice) or levels (Score), as "floats
that sum to 1". Given so you can compute your own uncertainty measure if `confidence` does not suit.
(https://docs.typesafe.ai/api.md, https://docs.typesafe.ai/confidence.md)

**Question** — One typed judgment to make about the state, defined by an id you choose, a `type`,
`instructions`, and (for Choice and Score) `criteria`. Question ids "are not sent to the model."
(https://docs.typesafe.ai/primitives.md)

**Question independence** — "Every answer is independent. One question's answer is not hidden context
for another. You can add or remove questions without changing the others' results."
(https://docs.typesafe.ai/primitives.md)

**Rerank / re-ranking** — Reordering an already-retrieved shortlist, as distinct from retrieval
itself. jev cannot retrieve (32k-token state, 255-option Choice cap), so the supported shape is
BM25 or an embedding index first, then one Noul per query-passage pair used as a sort key: on 40
CLERC queries that moved top-1 from 5% to 18% and top-10 from 38% to 62% over 1,200 calls costing
$0.0645. (https://docs.typesafe.ai/cookbooks/rerank_typesafe.md)

**RLCD (Reinforcement Learning for Calibrated Decisions)** — TypeSafe's training method, which "trains
TypeSafe to return decisions and calibrated probabilities instead of generated text." No paper or
algorithm detail is published.
(https://docs.typesafe.ai/introduction/machine-learning-primer.md)

**RLHF (Reinforcement learning from human feedback)** — The method that "turned pretrained models into
chatbots. It trains models to produce responses people prefer." Co-invented by TypeSafe cofounder
Diogo Almeida. (https://docs.typesafe.ai/introduction/machine-learning-primer.md)

**RLVR (Reinforcement learning with verifiable rewards)** — The method that "created reasoning models
that are strong at tasks such as mathematics, but slower and more expensive"; TypeSafe's critique is
that "most real-world judgement tasks don't fit into that shape."
(https://docs.typesafe.ai/introduction/machine-learning-primer.md,
https://typesafe.ai/blog/introducing-system-one-models-and-jev)

**Score** — The primitive "for rating content against ordered, descriptive levels." Returns `score`
(a probability-weighted position that can land between levels), `legend`, `probabilities`, and
`confidence`. (https://docs.typesafe.ai/primitives/score.md)

**Selective prediction** — The general name for answer-or-decline: return a prediction only where a
confidence score clears a threshold, and evaluate the design on the accuracy/coverage curve rather
than on accuracy alone. jev has no decline mechanism of its own, so with jev this is entirely a
code-side policy over `confidence` or a Noul probability. (see **Abstain / abstention**,
**Coverage**, https://docs.typesafe.ai/confidence.md)

**Self-consistency** — The stated design property that System One "is designed to return stable
answers across repeated evaluations"; quantified in two cookbooks rather than as a headline number.
(https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md)

**Shadow mode** — Running jev beside the incumbent logic on real traffic while changing no
behaviour, logging `{state_hash, versioned model id, answers, probabilities, confidence,
incumbent_decision, timestamp}` so the comparison can be scored later. The corpus treats a shadow
trial as the step before any jev verdict is acted on. (see `df-rollout`)

**Speculative fan-out** — The pattern of sending "many questions in a single call, including
speculative ones, and [letting] your code decide what's relevant", since "adding more questions to a
call typically doesn't add any latency." (https://docs.typesafe.ai/patterns/fan-out.md)

**Speculative question** — A question "we ask … before we even know if it's relevant, allowing us to
evaluate all questions in parallel and rely on code to filter out the irrelevant results after the
fact." (https://docs.typesafe.ai/demos/smart-home.md)

**State** — "the content you ask a System One model to evaluate… You pass it in the `state` field of an
API request." A string, JSON object, or array of text. "Each request evaluates one state against one
or more questions." (https://docs.typesafe.ai/concepts/state.md)

**Structural invariant** — A relationship you might expect to hold between answers (a Noul and the
matching Choice, or P and not-P) that the model does not guarantee: "don't hold the model to
arithmetic identities between separate questions."
(https://docs.typesafe.ai/model-jaggedness/jev-1.13.md)

**System 1 vs System One** — "System 1" is Kahneman's term, in *Thinking, Fast and Slow*, for fast
automatic judgement. "System One" spelled out is TypeSafe's name for a model class: "a class of AI
models built to make fast, structured decisions that software can use directly". The corpus keeps
them distinct — one is the cognitive analogy, the other is the product category.
(https://docs.typesafe.ai/concepts/system-one.md)

**System One model** — "a class of AI models built to make fast, structured decisions that software
can use directly." Named from Kahneman's System 1 / System 2 distinction in *Thinking, Fast and Slow*.
(https://docs.typesafe.ai/concepts/system-one.md)

**System One LLM wrapper / system-one-adapter-python** — TypeSafe's open-source adapter "which
constrains LLMs to output structured decisions compatible with our API", used to run LLM baselines in
the workflow evals. (https://typesafe.ai/blog/introducing-system-one-models-and-jev,
https://github.com/typesafe-ai/system-one-adapter-python)

**Tripwire** — Using the *collapse* of confidence under adversarial input as a tamper signal rather
than as a correctness signal. One independent assessment found "Injection attacks via plausible
authority claims collapsed margins from 1.000 to 0.05-0.24" and concluded that confidence is
"useless as correctness gate" but "sharply responsive to injected pressure".
(https://github.com/bestdan/workflow-skills/pull/757; see `gt-evidence-independent`)

**Type-safe / typed output** — The guarantee that "Possible outputs and structure are defined in
advance. The model never makes type errors." It guarantees the shape, not the correctness, of an
answer. (https://typesafe.ai/blog/introducing-system-one-models-and-jev, https://typesafe.ai/)

**Usage** — The response object reporting `input_tokens` and `output_tokens`. Only input tokens are
billed; output tokens are free. (https://docs.typesafe.ai/api.md, https://docs.typesafe.ai/models.md)

**Workflow eval** — TypeSafe's own evaluation format: "every model gets the same workflow. We test how
they compare to the average of the smartest models", assuming the harness is correct rather than
debating labels. (https://evals.typesafe.ai/,
https://typesafe.ai/blog/introducing-system-one-models-and-jev)

**ZDR (zero data retention)** — An enterprise-only offering; general accounts are covered by the
statement that "Jev is not trained on customer requests or responses."
(https://docs.typesafe.ai/legal.md, https://docs.typesafe.ai/models.md)
