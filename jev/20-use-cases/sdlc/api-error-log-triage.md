---
id: uc-sdlc-api-error-log-triage
title: Triage an API or service error into a cause class and an owning team
verdict: conditional
domain: sdlc
decision_shapes: [classification, routing, scoring]
primitives: [choice, score]
evidence_level: community-report
sources:
  - https://empryo.com/blog/jev-and-the-harness  ("Jev achieved 100% accuracy in 273 milliseconds, matching the accuracy of frontier reasoning models at one-fifth the latency and a fraction of the cost"; "Jev (TypeSafe) | 102 of 102 | 0 | 273 ms | $0.00002"; failure triage listed among the accepted decision points)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify, then route to deterministic code, a specialist model, or a human)
  - https://docs.typesafe.ai/patterns/fan-out.md  (ask category and severity in one call; ignore what the branch does not read)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 2 counting)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-sdlc-ci-failure-triage-before-rerun, uc-sdlc-dependency-alert-triage, df-cost-model, cb-classification_using_confidence]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage error logs?" Also: "can we route Sentry issues to the
right team automatically?", "can a model tell a client mistake from our bug?", "our on-call
runbook is a wall of if-statements on error strings".

## Verdict

**Conditional**, and the condition is: **only where no stable error-string table exists,
and only after fixing the regex you already have.** The strongest public evidence for
jev in an SDLC setting is this task — one harness report states "Jev achieved 100%
accuracy in 273 milliseconds, matching the accuracy of frontier reasoning models at
one-fifth the latency and a fraction of the cost", with the row "Jev (TypeSafe) | 102 of
102 | 0 | 273 ms | $0.00002" (empryo.com/blog/jev-and-the-harness) — but the same report
is the reason for the condition. The incumbent regex on that 102-item set scored 98/102
and reached **102/102, for free, once `429` was digit-bounded**: it had been matching
inside `text_editor_20250429`. Read as a bug found in the regex, not as a replacement
for it. That is one author's set on their own API failures, not an independent
benchmark, and the number is theirs, not a property you inherit. Where your errors carry
stable, enumerable signatures, a table beats jev on cost, latency and exactness; where
the wording drifts with every dependency upgrade, jev earns the residue. **Advisory
first, gate later:** attach the class and owner as metadata beside the existing rule's
answer before anything routes on it.

## What jev decides

Normalise in code first: message, exception type, the top few stack frames with your own
package prefix, the route, and the status code. Never the whole event, never the breadcrumb
trail — that is failure mode 5, and it is the difference between this working and not.

```
cause_class: Choice
  instructions: {question: "What kind of problem does `error` represent?",
                 focus: "Classify the cause, not the symptom or the HTTP status."}
  criteria:
    caller_error:   {what: "The request was malformed, unauthorised, or asked for something
                            that does not exist",
                     not_for: "A valid request our code failed to handle",
                     examples: ["Missing required field 'account_id'", "Unknown enum value"]}
    dependency:     {what: "An upstream service, database, or third-party API failed or timed out",
                     not_for: "Our own code throwing while parsing an upstream response"}
    our_bug:        {what: "Our code is wrong: a null dereference, an unhandled case, a type error"}
    capacity:       {what: "Resource exhaustion: pool exhausted, out of memory, rate limited by us"}
    config:         {what: "A missing or wrong setting, credential, or feature flag"}
    other:          {what: "None of the above fits the evidence in `error`"}

owning_area: Choice   # your service or team list, with `unclear`
user_impact: Score
  criteria: ["Invisible: retried or degraded silently.",
             "Degraded: a feature is slower or partly unavailable.",
             "Broken: the user cannot complete the action.",
             "Data at risk: something was written wrong or lost."]
```

Fan them out in one call; questions are evaluated in parallel and add little latency (the docs
say latency "barely changes", not that it is free). Bands:
`confidence >= 0.85` route and page per the existing policy for that class; `0.6-0.85` route
but do not page; `< 0.6` to the general on-call queue, which is today's behaviour. Do not ask
"how many times has this happened" — that is counting (failure mode 2) and your error tracker
already knows.

## What stays in code

The status code, the error type, and the service name are exact facts; anything derivable from
them is a lookup, not a judgement — the counter-signal list names status-code routing
explicitly as a case public evaluations rejected. Grouping and deduplication (your tracker's
fingerprint), rate thresholds, the paging policy, the escalation timer, and any severity
floor. Secret and PII redaction before the call. Known-signature rules you already trust stay
authoritative and short-circuit.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A normalised
event of ~1,500 characters plus three questions with criteria (~2,000 characters) is about
880 tokens, **≈ $0.000037 per distinct error group**. Call once per *group*, not per
occurrence — that is the difference between cents and dollars. Measured by the field report on
its own task: "273 ms" and "$0.00002" per call, with general performance given as "70 to 300
milliseconds for $0.042 per million input tokens". Labelled data for calibration: the team
that actually fixed each past issue, and the resolution label your tracker already stores
(`wont-fix`, `duplicate`, `upstream`). No accuracy figure applies to your taxonomy until you
run it.

- Field evidence (independent-benchmark): Empryo's transient-versus-permanent API error triage on a 102-item labelled set: jev 102/102 at 273 ms median and $0.00002 per decision, against GPT-5.6 Terra 102/102 at 1,387 ms and $0.00250, Claude Haiku 4.5 101/102 at 602 ms and $0.00125, and Union Alpha 96/97 at 8,685 ms. The incumbent regex scored 98/102 and reached 102/102 for free once `429` was digit-bounded - it had been matching inside `text_editor_20250429`. Read the result as a bug found in the regex, not a replacement for it, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness
- Field evidence (community-report): OpenTelemetry log triage shipped as a standalone jev tool over structured log records; no numbers published, 2026-09. Source: https://github.com/reachjalil/jevlogs

## When the verdict flips

- Your errors are already classified correctly by exception type. Determinism wins; do not
  replace it.
- You call jev per occurrence on a high-volume error. Group first.
- The routing decision pages a human at 03:00 on the model's word alone. Keep the paging
  policy deterministic and let the class only inform it.
- Logs contain user-supplied text that could steer the classification. State is not treated as
  hostile by default (failure mode 6); redact and constrain the criteria, and do not let a log
  line decide an access-control outcome.

## Alternatives considered

- **Error-string tables and exception-type maps.** The incumbent, free and exact for known
  signatures; they degrade into a maintenance queue as dependencies change wording.
- **Frontier LLM.** Better at suggesting a fix, which is a different job; seconds and cents
  per group, and the same field report notes it kept a reasoning model for the cases jev
  flagged rather than for all of them.
- **Small LLM.** Comparable labels at roughly 1.4x-3.7x the latency in the public
  head-to-head. The coverage gap in that 149-row run (34.7% below the chosen threshold against
  2.7%) is a trade-off, not a capability: a small LLM exposing logprobs can carry the same
  below-threshold route, and you should compare the two with one in place.
- **Fine-tuned classifier on historical issue assignments.** Very strong here — you have
  thousands of labelled rows already. Measure it against jev before committing.
- **Embedding similarity to past issues.** Good for "we have seen this before", which is
  really deduplication and belongs to your tracker's fingerprint.
- **Human on-call triage.** Stays for the low band; the point is to shrink it.

## Sources

Accessed 2026-09-19. Field report: https://empryo.com/blog/jev-and-the-harness (102 of 102,
273 ms, $0.00002; "70 to 300 milliseconds"; 8 candidate jobs evaluated, 5 integrated and 3
rejected, including grep-line ranking which "dropped top-3 accuracy from 78.6% to 74.1%").
Docs: `patterns/intent-routing.md`, `patterns/fan-out.md`, `model-jaggedness/jev-1.13.md`,
`models.md`.
