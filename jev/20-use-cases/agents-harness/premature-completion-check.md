---
id: uc-agents-harness-premature-completion-check
title: Check whether an agent actually finished the task before it reports done
verdict: good
domain: agents-harness
decision_shapes: [verification, detection, routing]
primitives: [noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  (per-field heads beat one holistic judge: 0.95 / 0.85 vs 0.56; max gate at 0.7; "Bad = TRUE")
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: "response quality"; Harness Engineering)
  - https://docs.typesafe.ai/cookbooks/parallel_questions.md  (a checklist of N questions in one call: 12.2x cheaper, 10.0x faster)
related: [uc-agents-harness-tool-call-trace-verification, uc-verification-document-completeness-checklist, uc-verification-llm-output-policy-check]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check whether the agent finished?" Also: "the agent says
'done' with three of five items missing", "can we detect a premature stop before it reaches the
user?", "can jev decide whether to send the agent back round the loop?"

**This entry is `inferred`.** No cookbook measures premature completion. It is the SDE cascade's
verify-then-escalate shape with the "record" replaced by the agent's final message and the
"fields" replaced by the request's stated requirements.

## Verdict

**Good.** The decomposition is the whole argument: "did the agent finish?" is one vague
question, and the cascade cookbook measured exactly why that fails — a holistic "should this be
escalated" head read 0.56 while the two correct per-field heads read 0.95 and 0.85, so "a
single whole-record judge would have sat under the 0.7 gate." Ask one Noul per requirement and
take a max in code. Keep it advisory or bounded: the retry it triggers must have a cap, or you
have built the loop jev is not meant to run.

## What jev decides

Code extracts the requirements list first — from the user's message, an issue template, an
acceptance-criteria field, or a plan the agent itself wrote at the start. Then one Noul per
requirement in a single request, framed so `true` is the failure:

```python
f"unmet::{i}": Noul(
  instructions=f"Does the agent's final message and the work it describes fail to satisfy requirement {i}: \"{req}\"?",
  criteria=NoulCriteria(
    true="The requirement is not addressed, or is addressed only by a promise to do it later.",
    false="The work described satisfies the requirement, or the requirement was withdrawn in the conversation."))
```

Plus three cross-cutting heads:

```python
"defers_work":   "Does the final message defer part of the task to the user or to a later run?"
"claims_untested": "Does the message claim something works without describing a check that was run?"
"silent_scope_cut": "Does the delivered work cover less than the request asked for, without saying so?"
```

Gate with a max, as the cascade does: `escalate = any(p > 0.7 for p in heads)`. Three outcomes:
accept, send the agent back with the specific unmet requirement named, or hand to a human.
Naming the failing requirement is why per-requirement heads matter — they "localize the error
and stay sparse and strong".

## What stays in code

Extracting the requirement list, the retry counter and its cap, the tests, the build, the
linter, the diff stats, and the accept/retry decision itself. Anything a test can decide should
be decided by the test: a failing suite is ground truth and a Noul is not. Jev covers the
requirements no test encodes — "also update the README", "explain the trade-off you chose".

## Numbers

Cost: the final message plus a diff summary plus eight questions is roughly 2,000-4,000 input
tokens, about $0.00008-$0.00017 per check at $0.042 per million input tokens, output free.
Latency 70-500 ms against an agent turn measured in tens of seconds, so it is free in practice.
Batching matters: the parallel-questions cookbook measured 13 questions over one document as
"12.2x cheaper, 10.0x faster" in one call than as 13 sequential calls, "with no change in
answers" — one call per completion check, not one per requirement.

No accuracy figure exists for this task. The transferable measured result is the cascade's, and
its caveat travels with it: a cascade "is only as good as its verifier", and vague questions
give "mushy, uncalibrated scores".

Closest jaggedness modes: **2, counting** — never ask "did it do all five things", ask five
questions and combine in code — and **5**, since agent transcripts are long and mostly
irrelevant to the check.

- Field evidence (community-report): three independent Stop-hook implementations verify an agent's "done" claim before the turn ends; none publishes a false-negative rate, which is the number that would decide whether this can ever gate rather than warn, 2026-09. Source: https://github.com/valentynkit/jev-belay

## When the verdict flips

- **Completion is testable.** Tests, type checks, schema validation, an exit code. Use them;
  the Noul is **weak** wherever a test exists.
- **The requirements are not written down anywhere.** With no list to check against, the head
  degenerates into the holistic judge the cascade cookbook warns about.
- **The retry has no cap.** An uncapped verify-retry loop is an agent design, and jev is not
  built to run one. Cap it and fall through to a human.
- **The transcript is huge.** Mode 5: summarise to the final message plus the diff, or verify
  per-requirement against the specific artifact rather than the whole trace.
- **The agent's own message is the only evidence.** Then you are checking a claim about work,
  not the work. Put the artifact (diff, output, file list) in state or the check is theatre.

## Alternatives considered

- **Tests and CI** — strictly better where they apply; this entry exists for the requirements
  they do not encode.
- **LLM-as-judge on the transcript** — the incumbent; accurate, seconds of latency, dollars at
  scale, and self-inconsistent between runs, which matters when the output gates a retry.
- **A second agent turn ("are you sure you're done?")** — cheap to build and biased: the same
  model that stopped early is the worst judge of whether stopping was right.
- **Checklist regex over the final message** — catches "TODO" and "left as an exercise"; blind
  to work quietly not done.
- **Human review of every completion** — the baseline; the point is to send only the flagged
  ones there.

## Sources

- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/parallel_questions.md — accessed 2026-09-19
