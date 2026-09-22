---
id: uc-support-policy-supports-request
title: Verify that the written policy supports what the customer is asking for
verdict: good
domain: support
decision_shapes: [verification]
primitives: [noul, choice]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Example: send only relevant context" — state is `{ticket_message, refund_policy}` and the question is the Noul `policy_supports_refund`)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Verify support responses against policies and the customer's request"; legal: "Verify documents against explicit requirements")
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (does the quoted context support the claim; confidence flags for review)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 5: filter first, send only what the question needs)
related: [uc-support-response-quality-check, uc-support-refund-request-detection, uc-trust-safety-policy-violation-bands]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether our policy covers what the customer is
asking for?" Also "can jev decide if this refund is within policy?", "can we pre-check
entitlement before an agent reads the ticket?", and "can jev read our help-centre article
and tell us if it applies?".

## Verdict

**Good**, as an advisory verification with the relevant policy clause supplied in the
state — the shape is demonstrated by the how-to-build guide's worked example; no
task-matched labelled accuracy is published; shadow-evaluate against the incumbent
before acting. TypeSafe uses this as its worked example of decomposing input: state is
exactly `{ticket_message, refund_policy}` and the question is the Noul "Does the refund
policy support the refund requested in the ticket?". Two short texts, one comparison,
one hop. The non-negotiable condition is that the policy text must be *in the state* —
the corpus rule is that jev has no access to your private rules unless you put them
there, and asking it what your policy says from memory is the fastest way to a confident
wrong answer.

## What jev decides

Code retrieves the one or two clauses that could apply (by product, plan and topic — a
lookup, or a retrieval step) and sends only those. Sending the whole 40-page policy is
failure mode 5 and measurably costs accuracy.

```
state = {"ticket_message": "My flight was cancelled. Can I get a refund?",
         "policy_clauses": ["Cancelled flights are eligible for a full refund.",
                            "Refunds are not available for no-shows."]}

policy_supports_request: Noul
  instructions: {question: "Do `policy_clauses` support the remedy the customer requests in
                            `ticket_message`?",
                 compare: ["`ticket_message`", "`policy_clauses`"],
                 focus: "Judge only against the supplied clauses. Ignore what is customary."}
  criteria:
    true:  {what: "A supplied clause grants the requested remedy for the situation described"}
    false: {what: "No supplied clause grants it, or a clause excludes this situation",
            not_for: "A case the clauses do not mention at all"}

policy_is_silent: Noul
  instructions: "Do `policy_clauses` fail to address the situation described in
                 `ticket_message` either way?"

exclusion_applies: Noul
  instructions: "Does any supplied clause exclude the situation described in `ticket_message`?"
```

The second and third questions matter: "the policy does not cover this" and "the policy
forbids this" lead to different replies, and a single Noul conflates them. Bands: both
`policy_supports_request >= 0.8` and `policy_is_silent <= 0.2` before showing the agent a
green "within policy" badge; anything else shows the retrieved clause and no verdict.

## What stays in code

Clause retrieval and the authoritative decision. Whether the remedy is actually granted is
your entitlement engine's job — plan, purchase date, prior refunds, regional consumer law.
Every date comparison ("within 30 days of purchase") and every amount is code. Jev's answer
is a badge on the agent's screen and a routing hint, never an approval.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 400-character message plus
two 300-character clauses plus these three questions (~1,000 characters) is ≈ 500 tokens,
**≈ $0.000021 per check**. The cost scales with how much policy you send, which is the
argument for retrieving two clauses instead of ten: ten clauses at 300 characters each adds
~600 tokens and about $0.000025, and costs accuracy as well. Latency 70–500 ms, fast enough
to run while the agent is still reading. The citation-check cookbook covers the same
verification shape (does supplied context support a claim) and flags low confidence for
review; it does not publish an accuracy figure for policy support, so treat this as
unmeasured on your own policy text and build an evaluation set from decided tickets.

## When the verdict flips

- The policy is not supplied in the state. Then the question is about model memory and the
  verdict is **no**.
- The applicable clause depends on chained conditions ("if the plan is X and the purchase was
  before Y, clause 4.2 supersedes 3.1"). That is multi-hop indirection, failure mode 4. Resolve
  the precedence in code and send the winning clause.
- The output gates a payment or a legal commitment with no human. Advisory only.
- Policy language is heavy with dates, thresholds and currency. Put the *evaluated* outcome
  of those tests in the state as a named fact ("purchase_within_refund_window: true") and let
  jev judge only the semantic part.

## Alternatives considered

- **Rules engine over structured entitlements.** Wins outright where the policy is already
  encoded — and it should be, for anything that touches money. Jev is for the unstructured
  residue: free-text policies, edge cases, judgement clauses.
- **RAG with a frontier LLM.** Same shape, plus a generated explanation the agent can read;
  seconds and cents per ticket, and the explanation is itself a new thing to verify. A good
  combination is jev to decide, an LLM to explain only when jev says review.
- **Keyword matching between ticket and policy.** Fails on paraphrase, which is the entire
  problem.
- **Embeddings similarity.** Measures relatedness, not support; a clause that *excludes* the
  request is highly similar to it.
- **Human reading the policy.** The current state, and the band this leaves in place.

## Sources

Accessed 2026-09-19. `concepts/how-to-build-with-system-one.md` (worked example, verbatim
state and question), `concepts/use-case-map.md`, `cookbooks/citation_check.md`,
`model-jaggedness/jev-1.13.md` (modes 4 and 5), `models.md`.
