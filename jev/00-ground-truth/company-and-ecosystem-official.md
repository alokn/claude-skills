---
id: gt-company-and-ecosystem-official
title: TypeSafe AI the company, and the official ecosystem
last_verified: 2026-09-19
jev_version: jev-1.13.0
sources:
  - https://typesafe.ai/team  (founders, roles, culture, funding language)
  - https://typesafe.ai/manifesto  (mission, three steps)
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (launch, early access, waitlist)
  - https://typesafe.ai/  (homepage, blog index, contact)
  - https://docs.typesafe.ai/agent-skill.md  (skills repo, install)
  - https://docs.typesafe.ai/sdk/python.md and /sdk/javascript.md  (SDK repos)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (Discord invite)
  - https://docs.typesafe.ai/introduction/quickstart.md  (console, playground, keys)
  - https://docs.typesafe.ai/legal.md  (legal documents)
  - https://pypi.org/project/typesafe-sdk/ , https://www.npmjs.com/package/@typesafe-ai/sdk
---

## The company

TypeSafe AI describes itself as "an AI lab building machine-native intelligence infrastructure for
automation, designed to make decisions within software" (site meta description, used across
typesafe.ai). The manifesto states the mission:

> "Our mission is to pave the shortest path to an AI-based economic revolution by making intelligence composable to catalyze a Cambrian explosion of intelligent software."
> — https://typesafe.ai/manifesto

with a three-step roadmap: "Ship the shape of machine-native composable AI with the highest possible
intelligence-per-dollar." → "Make our AI reliable enough to transform the economy via real
automation." → "Empower the world with higher-level intelligence abstractions that are stable enough
to compose and layer upon, for a collaborative, emergent future."

The launch post says the company spent "two years in stealth"
(https://typesafe.ai/blog/introducing-system-one-models-and-jev).

## Founders (roles only, from the team page)

| Role | Name | Stated background (verbatim) |
| --- | --- | --- |
| CEO | Diogo Almeida | "Diogo co-invented RLHF and InstructGPT, the methods that lead to ChatGPT and GPT4. Previously, he was at Google Brain. His research has helped shape modern language models, and he continues to push the frontier of AI systems." |
| COO | Sasha Sheng | "Sasha is an ex-research engineer from Meta/FAIR where she worked on the News Feed, AI Experiences, and AI Research. An avid builder, she has organized many hackathons and published work at NeurIPS and ECCV." |
| CTO | Erik Gafni | "Erik is a repeat founder (Ravel, multi-modal AI for dna-sequencing), an early employee at two unicorns (Invitae and Freenome), and an inventor with numerous publications and patents. He specializes in building production AI systems." |

— https://typesafe.ai/team

The AI primer adds: "RLHF was used to train InstructGPT and ChatGPT and was co-invented by Diogo
Almeida, cofounder of TypeSafe." (https://docs.typesafe.ai/introduction/machine-learning-primer.md).
The launch post is bylined "Diogo Almeida, founder, TypeSafe" and opens "At OpenAI, I helped build the
methods that made language models useful at following instructions and talking with people. That work
ended up as the research behind ChatGPT."

## Team, office, and funding

> "We're a close-knit, flat team from OpenAI, Google Brain, Meta/FAIR, Stripe, Airbnb, Plaid, Docker, and more. We're backed by top-tier investors who share our vision for building the foundation of truly transformative AI."
> — https://typesafe.ai/team

> "Our team works in-person five days a week in our San Francisco office near the Embarcadero station. We offer competitive salaries, equity, and benefits, as well as lunch and dinner."
> — https://typesafe.ai/team

**Funding:** no investor names, round size, valuation, or date are published on any official surface
reviewed. The only statement is "backed by top-tier investors." Round details are **not published**.

Stated values (team page headings): "Positive-Sum Games with Long-Term People", "Thinking in Bets",
"First Principles", "Prioritize Learning", "Passion", and "A working environment built for human
beings" — "We build machines; we don't try to be machines."

## Launch date and availability

The launch post "Introducing System One Models & Jev" is dated **Sep 15, 2026** on the blog index
(the page was last published Sep 18, 2026 per the Framer build comment). Jev is in **early access
behind a waitlist**:

> "Our first public model is Jev, available today in early access."
>
> "Today, we are opening early access and bringing developers off the waitlist as quickly as we can. We want to hear which decisions you need to automate, where Jev works, and where it falls short."
> — https://typesafe.ai/blog/introducing-system-one-models-and-jev

The homepage's primary call to action is "Join Waitlist"; the FAQ answer to "How do I get started or
ask a question?" is:

> "Join the waitlist! Jev is in its early days, and we'd love to hear how you're using it, what you're building, and any issues you run into. Join our Discord to ask questions, share feedback, and talk with our team."
> — https://typesafe.ai/

As of 2026-09-19 the waitlist is still the front door; there is no self-serve open signup documented.

## Official blog posts

| Date | Title | URL |
| --- | --- | --- |
| Mar 31, 2026 | Diogo Almeida - Founders You Should Know | https://typesafe.ai/blog/diogo-almeida---founders-you-should-know |
| Jun 19, 2026 | AI: too good to be true, too bad to be useful | https://typesafe.ai/blog/ai-too-good-to-be-true-too-bad-to-be-useful-typesafe-ai |
| Sep 10, 2026 | The Bitterest Lesson | https://typesafe.ai/blog/bitterest-lesson |
| Sep 11, 2026 | Lies, Damned Lies, and Benchmarks | https://typesafe.ai/blog/antibenchmaxxing |
| Sep 15, 2026 | Introducing System One Models & Jev | https://typesafe.ai/blog/introducing-system-one-models-and-jev |

Note: `https://typesafe.ai/blog/ai-too-good-to-be-true` and `/blog/the-bitterest-lesson` both return
404; the slugs above are the working ones. The body text of "AI: too good to be true, too bad to be
useful" and of the "Founders You Should Know" post is not present in the server-rendered HTML or the
site search index — **could not verify** its contents. Its listed summary is: "RLHF-trained language
models please humans and assist rather than make reliable autonomous decisions. What comes next?"

## Official repositories

| Repo | What it is |
| --- | --- |
| https://github.com/typesafe-ai/skills | The agent skill marketplace; `skills/typesafe-ai/SKILL.md` is the skill itself |
| https://github.com/typesafe-ai/typesafe-sdk-python | Python SDK (`typesafe-sdk` on PyPI) |
| https://github.com/typesafe-ai/typesafe-sdk-js | JavaScript/TypeScript SDK (`@typesafe-ai/sdk` on npm) |
| https://github.com/typesafe-ai/system-one-adapter-python | The "System One LLM wrapper" used to constrain LLMs to structured decisions in the workflow evals |

Package registries: https://pypi.org/project/typesafe-sdk/ (latest 0.7.0, 2026-09-18, requires Python
>= 3.10) and https://www.npmjs.com/package/@typesafe-ai/sdk (latest 0.6.0, 2026-09-15, `node >= 20`,
MIT). Cookbooks also reference a TypeSafe-hosted index at `https://pypi.typesafe.ai/` for the
`cooksafe` helper package.

The smart-home demo's code is not yet public: "The full source code will be available on GitHub at
release." (https://docs.typesafe.ai/demos/smart-home.md)

## Agent skill

Install for Claude Code:

```bash
claude plugin marketplace add typesafe-ai/skills
claude plugin install typesafe@typesafe-ai
```

Other agents: `npx skills add typesafe-ai/skills --skill typesafe-ai`. Raw skill file:
https://raw.githubusercontent.com/typesafe-ai/skills/main/skills/typesafe-ai/SKILL.md. Updates via
`claude plugin marketplace update typesafe-ai` + `claude plugin update typesafe@typesafe-ai`, or
`npx skills update`. (https://docs.typesafe.ai/agent-skill.md)

The skill exists partly to correct a specific agent failure: "Coding agents fall into the one question
per call habit more than people do. The TypeSafe agent skill tells your agent to put many questions in
each call, including ones that only matter for some inputs."
(https://docs.typesafe.ai/primitives.md)

Its stated review guidance is worth carrying into any jev proposal: "Put the constants (questions and
thresholds) in a single place so they're easy to review. Agents aren't great at writing questions, so
expect to edit collaboratively with them." and "The most important thing for humans to review is the
questions and any threshold constants used in your TypeSafe code."

## Console, playground, keys

* Console: https://console.typesafe.ai/
* Playground: https://console.typesafe.ai/playground — "Paste any text as the state… Add a question… Mix Noul, Choice, and Score in one call and see all results at once."
* API keys: https://console.typesafe.ai/keys
* Docs: https://docs.typesafe.ai/ (machine index at https://docs.typesafe.ai/llms.txt; every page is also served as `.md`)
* Workflow evals: https://evals.typesafe.ai/

## Community and contact

* Discord: https://discord.com/invite/WUujKYBp8s — the jaggedness page asks for failure-mode reports there; the homepage FAQ points new users there.
* General: hello@typesafe.ai
* Sales / higher rate limits / enterprise: sales@typesafe.ai
* Privacy, ZDR: privacy@typesafe.ai
* Careers: "Open roles" on https://typesafe.ai/team
* Social: LinkedIn and X are linked from the site footer (handles not extracted).

## Legal

* Data Processing Agreement — https://typesafe.ai/legal/data-processing
* Master Customer Agreement — https://typesafe.ai/legal/mca
* Privacy Policy — https://typesafe.ai/legal/privacy-policy
* Terms of Use — https://typesafe.ai/legal/terms

> "These documents cover how TypeSafe handles your data when you have an account with us, including data retention, our commitment not to train models on user data, and the general customer agreements that govern your use of TypeSafe."
> — https://docs.typesafe.ai/legal.md

Zero data retention is enterprise-only: "We also offer zero data retention (ZDR) for enterprise
customers. Contact privacy@typesafe.ai to learn more."

## Documentation surface (as of 2026-09-19)

Concepts (System One, State, How to build, Use case map); Primitives (index, Choice, Score, Noul,
Advanced: structure); Confidence; Patterns (index + 4); Models; API reference; Migrating to v1;
Model jaggedness (jev-1.13); SDKs (Python, JavaScript, with full API references); Agent skill;
Demos (smart home); Legal; and 18 cookbooks — autoformat, autoresearch_feature_discovery,
citation_check, classification_using_confidence, classifying_rag_passages,
consistency_choice_cookbook, consistency_noul_cookbook, date_extraction_cookbook, entity_alignment,
function_calling, hierarchical_classification, llm_guardrails, parallel_questions,
pre_parsed_value_extraction_cookbook, rerank_typesafe, sde_cascade, semantic_find, skill_suggestion.

No status page, uptime SLA, support SLA, or security/compliance certification (SOC 2, ISO 27001) is
published on any surface reviewed — **not published**.
