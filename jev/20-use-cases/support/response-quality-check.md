---
id: uc-support-response-quality-check
title: Check a drafted support reply against the policy and the customer's request
verdict: good
domain: support
decision_shapes: [verification]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (customer support: "Verify support responses against policies and the customer's request"; verification: "response quality")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (screen every message in and out of an LLM app with one request; pass / review / block / route on thresholded probabilities)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (weighted composition example: `0.4*answers_request + 0.4*citations_are_supported + 0.2*(1 - contradicts_context)`)
  - https://docs.typesafe.ai/cookbooks/citation_check.md  (does the supplied context support the claim; confidence flags for review)
related: [uc-support-policy-supports-request, uc-trust-safety-policy-violation-bands, uc-support-intent-routing-handlers]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check support replies before they are sent?" Also "can jev
guardrail our AI support agent?", "can we catch replies that ignore the question?", and
"can jev QA a sample of agent responses?".

## Verdict

**Good.** This is the guardrail shape the docs describe for LLM applications, applied to a
support reply: one request, several atomic checks over the draft plus the customer's message
plus the retrieved policy, and thresholds that decide send / review / block. The docs even
publish the composition formula for exactly these three dimensions. It is `good` rather than
`strong` because the published cookbook screens LLM inputs and outputs generally rather than
support replies specifically, and because it only works if the ground truth for the check —
the policy clause, the customer's question — is supplied in the state. If your AI support
agent is generating replies, this is the highest-value single jev integration available to
you: it costs a small fraction of the generation call it is checking.

## What jev decides

State: `{customer_message, draft_reply, policy_clauses}` — nothing else. The conversation
history is a distractor unless the check needs it.

```
answers_request: Noul
  instructions: "Does `draft_reply` address the request made in `customer_message`?"
  criteria:
    true:  {what: "Responds to what was asked, even by refusing it"}
    false: {what: "Answers a different question, or only acknowledges receipt"}

contradicts_policy: Noul
  instructions: "Does `draft_reply` state or promise anything that `policy_clauses` contradict?"

promises_unsupported_remedy: Noul
  instructions: "Does `draft_reply` commit to a refund, credit, replacement, or deadline that
                 `policy_clauses` do not authorise?"

unsupported_factual_claim: Noul
  instructions: "Does `draft_reply` state a fact about the customer's account or order that is
                 not present in the supplied state?"

tone: Score
  criteria: ["Dismissive or blaming the customer",
             "Neutral and correct but impersonal",
             "Clear, acknowledges the customer's situation, and states the next step"]

next_step_stated: Noul
  instructions: "Does `draft_reply` tell the customer what happens next or what they should do?"
```

Composition in code, following the docs' example:
`quality = 0.4*answers_request + 0.4*(1 - unsupported_factual_claim) + 0.2*next_step_stated`.
Routing, following the guardrails cookbook's band structure: block on
`promises_unsupported_remedy >= 0.7` or `contradicts_policy >= 0.7`; review on either above
0.35, or `quality < 0.6`; otherwise send. The guardrails cookbook makes the point that these
thresholds are a *policy object* — it shows the same assessment (jailbreak 0.74, severity
0.51) blocking under a strict policy and going to review under a permissive one.

## What stays in code

Sending. Also: which policy clauses to retrieve, redaction, the template layer, and any
compliance text that must appear verbatim (check for it with a string comparison, not a
question). For human agents this is a QA sample and a coaching signal, never a gate on a
person's work without their knowing the criteria.

## Numbers

Method: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`. A 400-character customer
message, an 800-character draft, two 300-character clauses and these six questions (~1,300
characters) is ≈ 775 tokens, **≈ $0.000033 per reply**. Against a generation call that cost
cents, the check is a rounding error — the guardrails argument in one line. Latency 70–500 ms
added to the send path; the choice-consistency cookbook measured 114 ms mean round trip for
an 8-question call on 2026-09-11. The guardrails cookbook publishes 15 individual routing
decisions under `jev-1.12` (2026-08-15) — for instance an output `jailbroken` at
broke_policy 0.94, severity 2.3, blocked; a `good_refusal` at 0.07, passed — and states
explicitly that it reports no aggregate accuracy, precision or recall. Build your own set
from replies your QA team has already graded.

## When the verdict flips

- The check is the only thing preventing a harmful reply from reaching a customer. State is
  not treated as hostile by default (failure mode 6); keep deterministic filters and a human
  escalation path, and do not let jev be the sole gate.
- You ask one question: "is this reply good?". That hides five judgements in one number and
  is the anti-pattern the docs open with. Decompose.
- You want the fix, not the flag. Rewriting the reply is generation; route it back to the LLM
  or the agent with the failing checks attached.
- Replies are long documents with citations across many sources. Then it is a per-claim
  verification job; chunk and ask per claim, as the citation-check and RAG-passage cookbooks do.

## Alternatives considered

- **LLM-as-judge.** The incumbent. Same judgement, at the cost and latency of a second
  generation call, and self-inconsistent: the consistency cookbooks found LLM probabilities
  moving between repeats at temperature 0, while jev's mean per-question standard deviation
  was 0.0102 (Noul) and 0.0098 (Choice) over 15 repeats.
- **Regex for banned phrases and missing disclaimers.** Keep it — it is exact, free, and
  catches the compliance strings jev should never be asked about.
- **Second, stronger LLM reviewing everything.** Best quality, worst economics; use it on the
  band jev flags, which is the cascade shape.
- **Human QA sampling 2% of replies.** What this scales: jev screens 100%, humans read the
  flagged ones.
- **Rules on reply length and response time.** Measures effort, not correctness.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `cookbooks/llm_guardrails.md` (band
structure, policy objects, the 15 published decisions, `jev-1.12`, 2026-08-15),
`concepts/how-to-build-with-system-one.md` (the weighted composition), `cookbooks/citation_check.md`,
`cookbooks/consistency_noul_cookbook.md` and `cookbooks/consistency_choice_cookbook.md`,
`models.md`.
