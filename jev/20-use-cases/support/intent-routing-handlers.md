---
id: uc-support-intent-routing-handlers
title: Route a customer message to deterministic code, a specialist LLM, or a human
verdict: good
domain: support
decision_shapes: [classification, routing]
primitives: [choice, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/intent-routing.md  (the worked customer-service router: `intent` Choice + `complexity` Score, routing to a lookup, two specialist LLMs, or a human)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; a confidence floor beneath which everything goes to a human)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (model routing: "classify intent and domain", "estimate difficulty and risk", "escalate requests that need a more expensive model")
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-support-ticket-team-routing, uc-support-response-quality-check, uc-commerce-seller-message-intent]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide which handler answers a customer message?" Also
"can jev be our model router?", "how do we stop sending every message to the expensive
LLM?", and "can jev decide when to hand off to a human?".

## Verdict

**Good** — the shape is demonstrated by the intent-routing pattern page; no task-matched
labelled accuracy is published; shadow-evaluate against the incumbent before acting.
TypeSafe publishes this as a pattern with working code: classify intent and complexity
in one fast call, then send simple lookups to deterministic code, domain questions to a
specialist LLM with the right context loaded, and anything complex or uncertain to a
person. The economics are the argument — the router costs a fraction of the cheapest
handler it can avoid invoking, so it pays for itself the first time it answers an
order-status question from the database. Code owns every branch, the low-confidence path
is built into the pattern, and all seven fit-test questions pass.

Closest failure mode: **indirection** — "which handler should take this?" is a two-hop
question, so jev answers what the message asks for and how complex it is, and code maps those
answers to a branch.

## What jev decides

State: the customer's message, plus a compact list of what the deterministic handlers can
actually answer (so "order status" means what your code can do, not what the phrase suggests).

```
intent: Choice
  instructions: "The primary intent of this customer message"
  criteria:
    order_status:      "Asking about an existing order"
    product_question:  "Asking about a product before buying"
    return_exchange:   "Wants to return or exchange something"
    complaint:         "Unhappy with experience, wants resolution"
    other:             "None of the above"

complexity: Score
  instructions: "How complex is this request to resolve"
  criteria: ["Simple lookup or standard procedure",
             "Requires some judgment or multi-step process",
             "Unusual situation, edge case, or escalation needed"]

requires_account_action: Noul
  instructions: "Would answering this message require changing something on the customer's account?"

self_service_answerable: Noul
  instructions: "Could this be answered entirely from `available_handlers` without any new information?"
```

The docs' routing code reads: below `intent.confidence < 0.5`, go to a human regardless;
`order_status` to a database lookup with no LLM; `product_question` and `return_exchange` to
different specialist LLMs; `complaint` to a human when `complexity.score > 1` **or**
`complexity.confidence < 0.5`. That second disjunct is the part teams forget — low confidence
*about the complexity* is itself a reason to escalate.

The confidence-routing pattern adds the other half: thresholds scale with the stakes of the
branch. A balance read-out is safe at 0.6; an action that moves money needs 0.85 and a
confirmation step below that.

## What stays in code

The router. Every handler, every side effect, every fallback. A timeout with a deterministic
default path (send to the general queue) is mandatory — the cost model suggests budgeting
300–600 ms end to end for an inline decision with a hard timeout above it. Business rules
that pre-empt the router (VIP accounts always reach a human; an open P1 incident routes
everything to the incident queue) run before the call, not after.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 600-character message plus
these four questions with criteria (~1,200 characters) is ≈ 450 tokens, **≈ $0.000019 per
message**. Compare with what it avoids: the consistency cookbooks price a single multi-question
call at $0.00095–$0.0035 for a small LLM and $0.028–$0.041 for a reasoning model (prices as of
2026-07, sampled 2026-09-11) — so routing one message in twenty away from a reasoning handler
pays for a thousand routing calls. Latency: jev measured at 111–114 ms mean round trip in those
same runs, against 826 ms to 13.9 seconds for the LLM conditions. Do not quote a monthly saving
without your own message volume and your own handler mix.

- Field evidence (community-report): a LangGraph workflow uses jev as the intent node to split inbound email into invoice versus general inquiry before the handler runs; no accuracy published, 2026-09. Source: https://github.com/GiesN/typesafe-jev-workflow
- Field evidence (community-report): booking-inquiry routing across four languages, 60 synthetic cases over 3 rounds against gpt-4o-mini and claude-sonnet-4.5, main run "~$0.03 vs ~$0.62"; single annotator, synthetic data, and the headline accuracy is not published in the README, 2026-09. Source: https://github.com/Shogo-nfrealmusic/jev-eval
- Field evidence (community-report): reply-bot intent classification is one of 5+ typed decision points in a public production epic, with a "≤600 ms" budget, a 0.85 default confidence threshold, and the rule that "every migration must carry its own labelled set", 2026-09. Source: https://github.com/genfeedai/genfeed.ai/issues/4863

## When the verdict flips

- The handler can be chosen from structured metadata (channel, form type, product) already
  attached to the message. Then routing is a lookup and jev adds latency for nothing.
- A misroute is expensive and irreversible. Raise the thresholds, add the confirmation step
  the confidence-routing page uses for transfers, and keep a human floor.
- You let the router pick tools and then act on its own results in a loop. That is an agent;
  the docs are explicit that jev "does not generate code or choose its own next action".
- Intents overlap heavily and a message routinely has two. A Choice is relative and picks one;
  use Nouls per intent as well, or split the message.

## Alternatives considered

- **if/else on keywords.** Fast and free, and it is what you are replacing; it encodes
  vocabulary and breaks on paraphrase.
- **Send everything to a frontier LLM and let it decide.** Simplest to build, most expensive
  to run, and the routing decision becomes unauditable prose.
- **Small LLM router.** The mainstream choice, and the direct comparison above is the case
  against it: roughly an order of magnitude on both latency and cost, plus parse failures
  (the noul-consistency cookbook notes one model wrapping replies in a code fence that strict
  `json.loads` rejects, despite being told not to).
- **Fine-tuned intent classifier.** Excellent for a stable intent set with labelled data; no
  complexity estimate, no typed per-ticket probability to escalate on, and a retrain per new intent.
- **Embedding nearest-neighbour over past tickets.** Cheap and decent; no confidence you can
  reason about, and it inherits every historical misroute.

## Sources

Accessed 2026-09-19. `patterns/intent-routing.md` (worked router, verbatim questions and
thresholds), `patterns/confidence-routing.md`, `concepts/use-case-map.md`,
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`
(latency and cost per condition, sampled 2026-09-11), `models.md`, `jev/10-decision-framework/cost-model.md`.
