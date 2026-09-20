---
id: uc-legal-compliance-policy-violation-detection
title: Detect violations of an internal policy by putting the policy text in the state
verdict: conditional
domain: legal-compliance
decision_shapes: [detection, scoring, routing]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  ("Do not rely on knowledge stored in model weights when current information can come from your own knowledge base"; the refund-policy example puts the policy in the state)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (legal and compliance: "Detect missing clauses, prohibited claims, and policy violations"; moderation: combine severity and confidence to allow, warn, review, or block)
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (semantic policy checks on inputs, outputs and tool calls; deterministic filters stay)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6 adversarial content; failure mode 1 literal reading; "Math using score")
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; higher stakes, higher threshold)
related: [uc-legal-compliance-prohibited-marketing-claims, uc-legal-compliance-regulatory-requirement-verification, uc-legal-compliance-contract-clause-presence, cb-llm_guardrails, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to detect policy violations?" Also asked as "can jev check
whether an employee's expense narrative breaches our T&E policy?", "can jev flag messages
that violate our communications policy?", and "does jev know our policy, or do we have to
tell it?".

## Verdict

**Conditional**, and the condition answers the last phrasing: the policy text must be in the
`state`. Jev has no knowledge of your internal policy, and the docs are explicit — "Do not
rely on knowledge stored in model weights when current information can come from your own
knowledge base." Put the specific policy clause and the artefact side by side, ask whether
the artefact does the thing the clause forbids, and the task becomes an ordinary
single-hop comparison that jev is good at. The second condition is that jev is never the
sole gate: policy enforcement that must hold every time stays deterministic, and jev adds a
semantic flag on the long tail. Get both conditions and this is a solid design; miss either
and it is a liability.

## What jev decides

State: the artefact (message, expense narrative, submitted document) plus the one or two
policy clauses code retrieved for it. The docs' own worked example is this exact shape —
`{ticket_message: "My flight was cancelled. Can I get a refund?", refund_policy: "Cancelled
flights are eligible for a full refund."}` with the question "Does the refund policy support
the refund requested in the ticket?".

```
violates_clause: Noul
  instructions: {question: "Does `artefact.text` do the thing `policy.clause` prohibits?",
                 compare: ["`artefact.text`", "`policy.clause`"],
                 focus: "Judge the described conduct against the clause as written. Do not
                         apply any rule that is not in `policy.clause`."}
  criteria:
    true:  {what: "The artefact describes or performs conduct the clause prohibits",
            examples: ["Expensed a $400 dinner for two with no client named, where the
                        clause caps unattributed meals at $75"]}
    false: {what: "The conduct is outside what the clause addresses, or the clause permits it",
            not_for: "Conduct that feels wrong but is not covered by this clause — a
                      different clause is a different question",
            examples: ["Expensed a $400 dinner with three named client attendees"]}

severity: Score
  instructions: "How serious is the departure from `policy.clause`?"
  criteria: ["No departure from the clause",
             "Technical or procedural departure with no harm",
             "Substantive departure requiring correction",
             "Departure of a kind the policy treats as a reportable or disciplinary matter"]
```

The `focus` line matters: without it, failure mode 1 delivers the model's general sense of
what a reasonable policy says rather than what yours says.

Bands, scaled to the action, following the confidence-routing pattern: `P ≥ 0.85` with
`severity ≥ 2` opens a case; `P ≥ 0.6` flags for a reviewer; below 0.4 nothing happens and
the row is logged for calibration. Nothing auto-escalates to a person's manager. Use the
Score to order the queue, not to compute a magnitude — the jaggedness page's "Math using
score" warns that score levels are "weak in numerical calibration".

## What stays in code

Clause retrieval — which clauses apply to this artefact is your policy engine's job, and
sending the whole handbook is the fastest way to lose accuracy (failure mode 5). Every
monetary threshold, headcount limit, percentage and day count in the policy: extract the
candidate figure, have jev select it, compare in code. Approval chains and who is notified.
The deterministic rules that must always fire — a blocked payee list, an embargoed
jurisdiction, a hard spend cap — evaluated before jev and unaffected by its answer. The
audit record, with the model version from the response.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,000-character artefact plus two 600-character clauses plus one Noul with criteria and one
four-level Score (~1,800 characters) is about (2,200 + 1,800) / 4 = 1,000 tokens, so
**≈ $0.00004 per artefact-clause pair**. Latency 70–500 ms, "most queries about 100 ms".
Agreement with your compliance team: not published. Every closed case in your GRC tool is a
labelled row; the rollout note in this corpus describes waiting for roughly 100 labelled
rows before flipping any band.

## When the verdict flips

- The policy text is not supplied and you expect the model to know it. Then this is **no** —
  a judgement that depends on knowledge not in the state and not common sense has no System
  One form.
- The artefact is user-controlled and adversarial. State is not treated as hostile by default
  (failure mode 6); a message that argues for its own compliance can move the answer. Keep
  the deterministic controls and treat jev's flag as advisory.
- The violation is defined arithmetically (over a limit, outside a window). Compute it.
- The detection triggers an automatic adverse action against a person. Then it is an input to
  a human decision, never the decision.

## Alternatives considered

- **Deterministic rule engine.** Correct and required wherever the policy is expressible as a
  rule over structured fields. It wins outright there; jev is for the free-text narrative the
  rule engine cannot read.
- **Keyword lists.** Cheap, high false-positive rate, and they encode last year's vocabulary.
- **Small LLM (Haiku-class).** Can do the comparison; costs seconds and a parse step, and
  gives no typed probability to band on unless you read logprobs.
- **Frontier LLM.** Right for "which clauses might apply and how do they interact" — the
  multi-hop version. Route the uncertain band there rather than running it on everything.
- **Fine-tuned classifier.** Needs labelled violations per policy clause, and policies change
  faster than you can relabel. Jev's advantage is that a policy amendment is a state change,
  not a retraining run.
- **Embeddings.** The right tool for retrieving which clause applies; not for deciding
  whether it was breached.
- **Human compliance review.** Stays, and owns every case that opens. The target is triage
  order and coverage, not replacement.

## Sources

Accessed 2026-09-19. `concepts/how-to-build-with-system-one.md` (policy in the state; "do not
rely on knowledge stored in model weights"), `concepts/use-case-map.md` (policy violations;
severity × confidence bands), `cookbooks/llm_guardrails.md`, `model-jaggedness/jev-1.13.md`
(modes 1, 5, 6; "Math using score"), `patterns/confidence-routing.md` (per-action
thresholds), `models.md` (price, latency).
