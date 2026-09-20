---
id: gt-rlcd-and-training
title: RLCD, the architecture claims, and what TypeSafe has and has not disclosed
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://docs.typesafe.ai/introduction/machine-learning-primer.md  (RLHF/RLVR/RLCD, mode dropping, calibration)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (new stack, parallel sampler, FAQ answers)
  - https://typesafe.ai/blog/bitterest-lesson  (the bitterest lesson argument)
  - https://typesafe.ai/manifesto  (mission, three steps)
  - https://typesafe.ai/  (homepage FAQ: parallel computation, not a smaller LLM)
  - https://docs.typesafe.ai/models.md  (not fine-tuned, same weights every account)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (100x target, self-consistency)
---

## The three post-training approaches

The AI primer presents RLCD as a third branch off pretrained language models, alongside RLHF and RLVR.
Verbatim card text (https://docs.typesafe.ai/introduction/machine-learning-primer.md):

* **RLHF** — "**Reinforcement learning from human feedback** turned pretrained models into chatbots. It trains models to produce responses people prefer."
* **RLVR** — "**Reinforcement learning with verifiable rewards** created reasoning models that are strong at tasks such as mathematics, but slower and more expensive."
* **RLCD** — "**Reinforcement learning for calibrated decisions** trains TypeSafe to return decisions and calibrated probabilities instead of generated text."

> "RLHF was used to train InstructGPT and ChatGPT and was co-invented by Diogo Almeida, cofounder of TypeSafe."
> — same page (linking https://scholar.google.com/citations?user=0T4y07QAAAAJ&hl=en)

### The RLCD output contract, verbatim

> "RLCD optimizes for a different output contract:
>
> * The model does not generate text.
> * It returns decisions and probabilities.
> * Higher probability should correspond to a greater chance that the answer is correct."

### The stated problems with RLHF

> "RLHF teaches a model to say things that people prefer. That objective works well for chatbots, but it can also reward sycophancy and confident-sounding hallucinations.
>
> Preference optimization also causes **mode dropping**: the model learns to favor a particular style, such as instruction following, while reducing the probability of other possible outputs."

> "An output can be compelling to a person without being reliable enough for unattended automation. Human preference and machine trustworthiness are different optimization targets."

> "Mode dropping is a milder version of **mode collapse**. In the classic generative-adversarial-network failure mode, a generator learns to produce the same kind of output repeatedly because that output continues to fool the discriminator."

> "RLHF remains a good fit for conversational models. TypeSafe's position is that production automation needs a different training objective—one centered on constrained decisions and calibrated uncertainty."

### Why a new algorithm — the blog FAQ, verbatim

**Q: "Why was a new training algorithm needed?"**

> "Every lab optimizes for the same task during Reinforcement Learning with Human Feedback (RLHF): *produce the text that a human rater prefers*. That was the right task for a chat product, but it is the wrong task for automation. This is what we call the bitterest lesson: optimizing for the right task matters more than data, compute, or algorithms.
>
> RLVR is great for tasks with simple programmatic verification, but most real-world judgement tasks don't fit into that shape. This tends to cause spikey / non-robust intelligence."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

## The "bitterest lesson"

The referenced post (https://typesafe.ai/blog/bitterest-lesson, dated Sep 10, 2026) argues:

> "TL;DR: Compute drives progress in AI, but what good is progress if you are not doing the right task!"

> "Rich Sutton's bitter lesson states that compute beats algorithms."

> "My experience is that Sutton's bitter lesson is the tip of an iceberg of bitterer lessons: beyond compute and algorithms, there's data and even picking the right task to do ML on."

> "The bitterest lesson in ML is that doing the right task > data > compute > algorithms."

> "At the end of the day, machine learning makes reward go up or loss go down. Someone still has to decide the objective to optimize though. Getting this right requires understanding the external system in which the model will operate. Without the right task, everything can work perfectly, with the most beautiful loss and scaling curves, but the model may still be useless!"

> "This is not an argument against scale. Once the task and data are right, scale is incredible. It is an argument against treating scale as the be-all and end-all."

> "We learned this lesson at OpenAI when making InstructGPT/RLHF: GPT-3 was an incredible model trained to predict the next token on internet text, but people wanted something that followed instructions more than they wanted a super-powered autocomplete. GPT-2-sized models (>100x smaller than GPT-3) trained on the right task, even with the dumbest algorithm and barely any compute, destroyed GPT-3."

> "You get what you optimize for and the bitterest lesson in ML is that the most important part of it isn't ML at all."

## The stack: architecture, sampler, training method

> "We built a new stack entirely focused on automation: with a new model architecture, parallel sampler for maximum efficiency, and training method we call Reinforcement Learning for Calibrated Decisions (RLCD)."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

The blog's comparison table puts the sampler difference plainly:

> "Sampling — Existing LLMs: Sequential. Generates one token at a time, each conditioned on the last. System One + Jev: Parallel. Generates all outputs in a single query. Incredibly efficient and hardware-aware."

> "Our side-by-side demo shows a key difference between our models and LLMs: Jev outputs all probabilities in parallel instead of autoregressively generating by token. Strings are extremely powerful and general, but costly. 'Giving up' strings actually gives us a lot of superpowers!"

Homepage FAQ, "How can Jev be so fast and inexpensive?":

> "Jev replaces sequential generation with parallel computation, answering multiple structured questions in a single request. That makes it fast and efficient enough to bring intelligence to everyday decisions in your software, including ones that never justified the cost before.
>
> Fun fact: the jump from sequential to parallel is similar to that made by the transformer over RNNs (the breakthrough underlying today's AI revolution)."
> — https://typesafe.ai/

## "Neither small nor an LLM"

**Q: "Is Jev just a smaller LLM?"** (blog FAQ)

> "Jev is neither small nor an LLM, hence being off the intelligence Pareto curve."

Homepage expansion of the same question:

> "Jev's efficiency comes from optimizing for a different task. It's built for structured decisions inside software, with an interface and training approach designed for that purpose. It understands language, but doesn't generate free-form text or function as a chatbot."

Related positioning, homepage FAQ "How is this different from JSON mode or structured outputs?":

> "Valid JSON gives software a format it can read. But forcing an LLM into that format can leave some of its intelligence on the table. System One Models are trained for structured decisions from the start, returning typed answers with calibrated probabilities. Your code can use those probabilities to decide when to act, request more information, or escalate."

## Training data origin

**Q: "Where does our training data come from?"** (blog FAQ, verbatim)

> "TypeSafe is primarily a data research lab, which is how the biggest results in AI get made. We make all the data ourselves. We wouldn't train on your data even if you asked us to (no offense). We do some pretty sophisticated stuff, but if you want to find out more, we'd have to hire you."

**Q: "These are results are kinda crazy - how is it possible?"** (blog FAQ, verbatim)

> "See our blog post on AI's bitterest lesson. The short answer is that you get what you optimize for. LLMs optimized for being incredible chatbots and copilots, which made them superhuman at those humans-in-the-loop tasks. We're optimizing for the System One interface."

The docs reinforce the customer-data position: "Jev is not trained on customer requests or responses."
(https://docs.typesafe.ai/models.md) and the Legal page points at the Privacy Policy for "our
commitment not to train models on user data" (https://docs.typesafe.ai/legal.md).

## What is NOT disclosed

From all official surfaces reviewed on 2026-09-19:

* **Parameter count** — not published. The only statement is "neither small nor an LLM."
* **Model architecture** — described only as "a new model architecture"; no details, no diagram, no name.
* **Sampler mechanism** — described only as a "parallel sampler"; no algorithm, no paper.
* **RLCD algorithm details** — named and characterised by its objective; no loss function, no reward model description, no training recipe. **No paper, preprint, or technical report is published.**
* **Training corpus** — "We make all the data ourselves." No dataset names, sizes, licences, or provenance detail. The full answer explicitly declines to say more.
* **Training compute, hardware, or cost** — not published. The Models page's rate-limit warning mentions "upcoming large GPU deals" but gives no training-compute figure.
* **Calibration measurements** (ECE, reliability diagrams) — not published; calibration is stated as an objective, not evidenced with a curve.
* **Evaluation on any public benchmark** — deliberately withheld; see `evals-official.md`.
* **Whether jev is built on a pretrained base model** — the AI primer's diagram shows "Pretrained language models" branching into RLHF, RLVR, and RLCD paths, which implies a pretrained starting point, but no text states this for jev specifically. Treat as **could not verify**.

## Stated plans

* **Release cadence / evals:** "we plan to only have one-off evals when we make product updates." (blog FAQ)
* **Jaggedness:** "Here are some jagged edges we are aware of with jev-1.13. Many of these will be fixed in later versions." (https://docs.typesafe.ai/model-jaggedness/jev-1.13.md). On adversarial robustness specifically: "We expect to improve on this in the future."
* **Modalities:** images, audio and video are "not supported (yet)" (https://docs.typesafe.ai/concepts/system-one.md). The Doom demo notes "The demo is on structured state as a data structure with text, not on images (yet…)".
* **Reliability of System One models:** "For reasons we will get into in the future, we believe System One Models can be made more reliable than its alternatives." (blog FAQ)
* **Speed headroom:** "Nobody has actually asked us because nobody thinks this is possible... but yes we can. If you have a use case that needs a speedier Jev, contact us at sales@typesafe.ai and tell us more." (homepage FAQ, "Can you make Jev even faster?")
* **Price direction:** "which we expect to go down, not up" (blog); "Our goal is to make intelligence more affordable over time as we improve the technology." (homepage FAQ)
* **Confidence cookbook:** a separate cookbook on alternative confidence computations is promised but not yet published (https://docs.typesafe.ai/confidence.md).
* **Company target ratio:** "TypeSafe's target is a greater than 100× intelligence-to-speed-and-cost ratio; the underlying bet is that cheaper intelligence will create much more demand." (https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md)

## The manifesto's three steps

The manifesto (https://typesafe.ai/manifesto) states a mission and a three-step roadmap:

> "Our mission is to pave the shortest path to an AI-based economic revolution by making intelligence composable to catalyze a Cambrian explosion of intelligent software."

* step one — "Ship the shape of machine-native composable AI with the highest possible intelligence-per-dollar."
* step two — "Make our AI reliable enough to transform the economy via real automation."
* step three — "Empower the world with higher-level intelligence abstractions that are stable enough to compose and layer upon, for a collaborative, emergent future."

Supporting argument: "the bottleneck isn't raw intelligence. It's that today's intelligence is hard to
build on." And: "Intelligence today is like databases before SQL: powerful, but every use is bespoke."
Safety is framed as a precondition for composition: "You let a component run unattended if it's
reliable; you only build on top of it if it's trustworthy."
