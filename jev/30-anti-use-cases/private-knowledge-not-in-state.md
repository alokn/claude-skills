---
id: au-private-knowledge-not-in-state
title: Do not ask jev about private knowledge you have not put in the state
verdict: no
domain: data
decision_shapes: [classification, verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Do not rely on knowledge stored in model weights when current information can come from your own knowledge base")
  - https://docs.typesafe.ai/models.md  ("Jev is not fine-tuned or LoRA-adapted with customer data ... Put your proprietary content, records, and reference material in the `state` field")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5, context rot)
related: [au-expect-fine-tuning-from-feedback, au-whole-document-in-state, au-legal-determinations-without-counsel]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to ask jev whether this discount is allowed under our pricing policy?" Also "does jev
know our SLA tiers", "will it recognise our internal product codes", "can it tell if this customer is on
the enterprise plan".

## Verdict

**No** when the knowledge is private and absent from the request; **good** the moment you include it. Jev
has no access to your systems and no per-account memory: "Jev is not fine-tuned or LoRA-adapted with
customer data ... and the same weights serve every account." The design guide's instruction is direct:
"Do not rely on knowledge stored in model weights when current information can come from your own
knowledge base." Your price list, your SLA tiers, your product codes, and your policy exceptions are not
in the weights.

## What jev would get wrong

It answers from general knowledge and common sense, which is what it is good at — and that produces a
confident, well-typed answer about a policy it has never seen. "Is a 40% discount unusual?" will be
answered on ordinary commercial intuition, not on your approval matrix. The same failure appears with
internal vocabulary: a Choice between `tier_gold` and `tier_platinum` with no descriptions forces the
model to guess what those words mean in your company. The absence of the knowledge is not reported,
because the primitives give the model no way to say "this depends on something I was not shown" other
than a low confidence you may not be reading.

## What stays in code

Retrieval. Code looks up the customer's plan, the applicable policy clause, the current price, and the
account's history, and places them in the state as named fields — which is precisely what the models page
prescribes: "Put your proprietary content, records, and reference material in the `state` field." Code
also encodes the rules that are rules rather than judgements ("discounts above 30% require VP approval")
and applies them itself.

Two disciplines make this work. Include only the fields the question needs, because "accuracy falls as
the state grows with content unrelated to the decision" — do not solve absent knowledge by dumping the
whole handbook. And name the paths in the instructions with backticks, as the docs' own example does:
"Does the refund policy support the refund requested in the ticket?" with both the ticket message and the
policy text supplied side by side.

## Numbers

A ticket plus the one relevant policy clause runs roughly 600-1,200 input tokens, about
$0.00003-$0.00005 at $0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md),
typically about 100 ms. The state plus the longest single question must stay within 32k tokens, with 64k
for the whole request — enough for a clause, not for a policy library, which is another reason retrieval
belongs in code.

- Field evidence (independent-benchmark): bitnovus/jev-spam-eval, 5,733 messages — the same questions scored 93.62% on text alone and 98.64% once Reply-To, link hostnames and attachment metadata were added to the state (phishing recall 85.71% to 98.38%): "Evidence in the state matters more than the model", 2026-09-19. Source: https://github.com/bitnovus/jev-spam-eval

## When the verdict flips

It flips to **good** as soon as the knowledge is in the request. Concretely: code retrieves the governing
clause and the account record; the state contains `ticket`, `policy_clause`, and `account.plan`; the
question names them by path; and the criteria define any internal terms in plain language rather than
assuming the model knows them. That is the standard, documented shape, not a workaround. It stays **no**
where the knowledge cannot be retrieved at all — tacit institutional judgement, an unwritten norm, a
decision only a particular person can make. **No rewrite exists** for knowledge that exists nowhere; write
it down first, then it becomes state.

## Alternatives considered

- **Regex / deterministic**: a policy that is a rule should be a rule in code, not a question.
- **Small LLM / frontier LLM**: same limitation — they also need the policy in the prompt. Retrieval is
  the shared prerequisite.
- **Fine-tuned classifier**: can absorb your domain from labelled examples, which is the one way to get
  private knowledge into weights; it needs data and retraining.
- **Embeddings**: the right tool for the retrieval step that supplies the state.
- **Human**: holds the tacit knowledge. If the judgement depends on it, write it down or keep the human.

## Sources

- https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
