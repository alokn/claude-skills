---
id: gt-what-jev-is
title: What jev is, and what it is not
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/introduction.md  (definition, primitives table, atomic questions)
  - https://docs.typesafe.ai/concepts/system-one.md  (System One class, Kahneman note, text-only)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (three architectures, composability cards)
  - https://docs.typesafe.ai/introduction/machine-learning-primer.md  (RLHF/RLVR/RLCD, Machine Native Intelligence)
  - https://docs.typesafe.ai/models.md  (not fine-tuned or LoRA-adapted)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (launch post, FAQ)
  - https://typesafe.ai/  (homepage FAQ)
  - https://typesafe.ai/manifesto  (mission framing)
---

## Definition

> "Jev is TypeSafe's flagship model and the first System One model. Send state and typed questions; get structured answers your code can use directly."
> — https://docs.typesafe.ai/introduction.md

> "System One models are a class of AI models built to make fast, structured decisions that software can use directly. A System One model evaluates a [state] and returns typed answers and probabilities."
> — https://docs.typesafe.ai/concepts/system-one.md

> "Jev evaluates typed *questions* against a *state* and returns structured results directly. No text generation, no parsing. You get typed values and probability distributions that your code can branch on, sort by, and route with."
> — https://docs.typesafe.ai/introduction.md

The launch post frames it as a function call:

> "Think of Jev as a frontier-intelligence function call: unstructured state in, typed probabilistic decisions out."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

The current version at the time of verification is `jev-1.13.0`, reachable through the aliases
`jev-latest` and `jev-preview` (https://docs.typesafe.ai/models.md).

## The three primitives, in one line each

| Question type | Goal | Returns |
| --- | --- | --- |
| Choice | Choose an option from a list | `choice`, `probabilities`, `confidence` |
| Score | Score the state on a rubric | `score`, `probabilities`, `confidence` |
| Noul | Is this statement true? | `noul` (0–1) |

— verbatim table from https://docs.typesafe.ai/introduction.md (the Score row also returns `legend`,
per https://docs.typesafe.ai/primitives.md).

> "All three *question* types can be mixed in a single API call. Every *question* is evaluated in parallel and in isolation against the same *state* in one go. Adding questions barely changes the response time. Each question is evaluated independently, so adding more questions does not create context-rot."
> — https://docs.typesafe.ai/introduction.md

## What jev is NOT

**Not an LLM.** The blog FAQ answer to "Is Jev just a smaller LLM?" is:

> "Jev is neither small nor an LLM, hence being off the intelligence Pareto curve."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

The homepage FAQ adds:

> "Jev's efficiency comes from optimizing for a different task. It's built for structured decisions inside software, with an interface and training approach designed for that purpose. It understands language, but doesn't generate free-form text or function as a chatbot."
> — https://typesafe.ai/ (FAQ, "Is Jev just a smaller LLM?")

**Not a generator.**

> "`jev-1.13` is not trained to generate text. While you can force it to by chaining choices, this will not work well and will be very slow."
> — https://docs.typesafe.ai/model-jaggedness/jev-1.13.md

> "System One models do not write replies, produce code, or generate explanations of their reasoning."
> — https://docs.typesafe.ai/concepts/system-one.md

**Not an agent.**

> "System One is TypeSafe's model for building AI-powered software, not agents. It does not generate code or choose its own next action."
> — https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md

**Not fine-tunable.**

> "Jev is not fine-tuned or LoRA-adapted with customer data. It is trained with [RLCD] to return calibrated decisions, and the same weights serve every account."
> — https://docs.typesafe.ai/models.md

You adapt it through the request instead: proprietary content in `state`, domain rules in
`instructions` and `criteria`, and decomposition plus code-side composition.

**Not multimodal.**

> "Jev currently accepts text input only. It evaluates strings, JSON objects, and arrays of text. Images, audio, and video are not supported (yet)."
> — https://docs.typesafe.ai/concepts/system-one.md

**Not guaranteed correct.** Typed output is guaranteed; correctness is not:

> "Yes. Jev guarantees the shape of its answers, not that every decision is correct. If you provide a list of categories, it can't invent a category outside that list, but it can choose the wrong one. Uncertainty is a feature!"
> — https://typesafe.ai/ (FAQ, "Can Jev still get things wrong?")

**Not deterministic — consistent.**

> "Determinism means returning the same result for an identical input. This is less valuable than consistency. We define consistency as making similar decisions when the meaning stays similar, even if the wording changes. Jev is designed for consistency."
> — https://typesafe.ai/ (FAQ, "Is Jev deterministic?")

## The three-architectures framing

The docs place jev inside a three-way taxonomy of software architectures
(https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md):

1. **Traditional software** — "Traditional code is a complex decision tree made from simple software primitives. Because each primitive is reliable, developers can compose them into higher-level abstractions."
2. **LLM agents** — "An agent processes instructions and chooses its next step. This works well when a person is monitoring the process, but every loop introduces another opportunity to go off the rails."
3. **AI-powered software** — "Code handles deterministic work and owns the control flow. The model appears only where the system needs programmable common sense or needs to interpret unstructured data. Each AI task is kept atomic and constrained."

TypeSafe positions jev for the third. The page's summary box: "build a normal software workflow and
insert System One only where AI is needed."

Six stated properties make System One composable: **Structured**, **Parallel**, **Comparable**,
**Fast** ("Most queries complete in about 100 ms"), **Calibrated confidence**, and **Self-consistent**
("designed to return stable answers across repeated evaluations"). The same page states the company
target: "TypeSafe's target is a greater than 100× intelligence-to-speed-and-cost ratio; the underlying
bet is that cheaper intelligence will create much more demand."

## Where the names come from (blog FAQ, verbatim)

**Q: "Where do the names 'System One Models' and 'Jev' come from?"**

> "We were inspired by Daniel Kahneman, Thinking, Fast and Slow. The model class name draws on the distinction between fast, intuitive System 1 thinking and slow, deliberate System 2 reasoning.
>
> 'System 1 thinking' has also implied error-prone. For reasons we will get into in the future, we believe System One Models can be made more reliable than its alternatives.
>
> We named Jev after William Stanley Jevons. We expect machine intelligence to follow a similar path to coal, after steam-engine efficiency led to an increase in demand. Every order of magnitude drop in the cost of intelligence unlocks orders of magnitude more use cases."

The docs repeat the Kahneman half: "The System One name comes from the concept Daniel Kahneman
popularized in his book *Thinking, Fast and Slow*. System 1 thinking is fast and intuitive. System 2 is
slower and more deliberate. Here, the emphasis is on fast, focused judgments."
(https://docs.typesafe.ai/concepts/system-one.md)

**Q: "What use cases is Jev good for?"**

> "We've found diverse use cases for Jev across industries. We outline some in our docs, and are excited to see what else developers build."

**Q: "Is Jev just a smaller LLM?"**

> "Jev is neither small nor an LLM, hence being off the intelligence Pareto curve."

The remaining blog FAQ answers (training algorithm, benchmarks, training data, how the results are
possible) are quoted verbatim in `rlcd-and-training.md` and `evals-official.md`.

## Positioning language from the manifesto and primer

> "We call this Machine Native Intelligence: AI with software-like properties such as structure, reliability, observability, testability, speed, consistency, and low cost."
> — https://docs.typesafe.ai/introduction/machine-learning-primer.md

> "TypeSafe is not trying to build a model that does everything. It is designed for production systems where code needs a narrow decision it can inspect and act on."
> — same page

> "the bottleneck isn't raw intelligence. It's that today's intelligence is hard to build on."
> — https://typesafe.ai/manifesto

## Related

`api-and-primitives.md`, `confidence-and-calibration.md`, `failure-modes.md`,
`rlcd-and-training.md`, `glossary.md`.
