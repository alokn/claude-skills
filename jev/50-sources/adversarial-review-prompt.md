You are an adversarial technical reviewer. The directory `jev/` in this repo is a ground-truth corpus about "jev", TypeSafe AI's System One model (docs: https://docs.typesafe.ai/llms.txt). A consumer product will let people ask an LLM "is it a good idea to use jev for X?" and the LLM will answer from this corpus only. Your job is to find everything that would make such an answer wrong, misleading, unsupported, or over-confident.

Scope for this pass: `jev/CORPUS-SCHEMA.md`, `jev/README.md`, everything under `jev/00-ground-truth/`, `jev/10-decision-framework/`, and `jev/40-cookbooks/`. (Use-case entries under 20-/30- are reviewed in a later pass; you may sample them for consistency with the ground truth.)

Check specifically:
1. Factual claims about jev (price, limits, latency, primitives, failure modes, versions, company facts): are they consistent across files? Do they match the cited source? Flag any number that appears with different values in different files.
2. Over-claiming: any sentence that asserts accuracy, consistency, or superiority without a named measured source. Any place the launch post's marketing multipliers are presented as expectations.
3. Under-claiming or unfair negativity: any place the corpus dismisses jev where the evidence actually supports it.
4. Logical gaps in the decision framework (fit-test, rewrites, alternatives, cost-model, rollout): missing cases, contradictions between files, rules that would produce a wrong verdict for a realistic question. Give 5 concrete "is it a good idea to use jev for X?" questions where you believe the framework would give the wrong or an ambiguous answer, and say what the right answer is.
5. Source hygiene: claims with no URL, URLs that do not support the claim, second-hand claims presented as first-hand, cookbook numbers copied wrongly.
6. Retrieval usability: would a retriever find the right file for common phrasings? Missing glossary terms, inconsistent vocabulary, ids that do not match paths.
7. Anything a TypeSafe engineer would object to as inaccurate about their product, and anything a sceptical CTO would object to as credulous.

Do not rewrite files. Output a single markdown report with: (A) a severity-ranked findings table (severity critical/major/minor, file, line or quote, problem, suggested fix), (B) the five adversarial questions with your expected corpus answer vs correct answer, (C) a short overall verdict on whether the corpus is fit to be "ground truth", with the top 5 changes that would most improve it. Be specific and quote the offending text. Aim for 1500-3000 words.
