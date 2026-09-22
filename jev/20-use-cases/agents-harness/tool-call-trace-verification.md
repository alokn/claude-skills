---
id: uc-agents-harness-tool-call-trace-verification
title: Verify an agent's tool call against the user's request before or after it runs
verdict: good
domain: agents-harness
decision_shapes: [verification, detection, routing]
primitives: [noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: "Verify the input prompt, extractions, reasoning traces, tool calls"; "Detect tool-call errors ... in real time")
  - https://docs.typesafe.ai/cookbooks/llm_guardrails.md  (per-side batteries, thresholds in code, pass/review/block/support precedence)
  - https://docs.typesafe.ai/cookbooks/sde_cascade.md  ("Bad = TRUE" framing; per-field heads then a max gate; 0.56 holistic vs 0.95/0.85 localised)
related: [uc-agents-harness-pre-tool-use-destructiveness, uc-agents-harness-premature-completion-check, uc-verification-llm-output-policy-check]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check the agent's tool calls?" Also: "the agent called the
right tool with the wrong arguments — can we catch that?", "can we verify a whole trace after
the fact instead of reading every log?", "how do we detect tool-call errors without an LLM
judge on every step?"

## Verdict

**Good.** The use-case map names tool-call verification as a headline category and lists
"Detect tool-call errors and response-quality failures in real time"; the guardrails and SDE
cascade cookbooks supply the shape (a battery of narrow Nouls in one call, framed so `true`
means something is wrong, thresholded in code) but neither measures tool-call checking
specifically. Build it as a battery of localised checks, never one "is this call good?"
question — the cascade cookbook measured a holistic head at 0.56 while the two correct
localised heads read 0.95 and 0.85.

## What jev decides

State is the pair: what was asked, and what the agent did. Include the tool's own contract so
the judgement is not about knowledge in weights.

```json
{"user_request": "...", "tool": {"name": "refund_order", "description": "...",
  "arguments": {"order_id": "A-104", "amount_usd": 49}},
 "prior_step_result": "..." }
```

Four to six Nouls, all framed so `true` is the failure ("Bad = TRUE ... so the threshold has
one meaning across all heads"):

```python
"wrong_tool":        "Does the chosen tool fail to do what the user's request asks for?"
"unrequested_scope": "Do the arguments act on something the user did not ask about?"
"arg_not_grounded":  "Is any argument value absent from, and unsupported by, the request and the prior step's result?"
"contradicts_prior": "Does this call contradict a constraint stated earlier in the conversation?"
"irreversible":      "Would this call change or delete data in a way the user could not undo?"
```

Plus one Score for blast radius, which can promote a review to a block the way `SEVERITY` does
in the guardrails cookbook.

Gate with a max over the heads, as the cascade does (`FIRE_T = 0.7`, "escalate if *any* field
fires ... not a mean, so one confident red flag is enough instead of being averaged into
silence"). Three outcomes: run, confirm with the user, block and re-plan.

## What stays in code

The tool registry and its permissions, argument schema validation, the allow/deny list, rate
and spend limits, idempotency, the audit log, and the thresholds. Schema validity is necessary
and not sufficient — the cascade cookbook's fabricated record printed `schema-valid: True`;
"it catches structural errors, never semantic ones."

## Numbers

Cost: a request plus a tool call plus six questions is roughly 800-1,500 input tokens, about
$0.00003-$0.00006 per check at $0.042 per million input tokens with free output. Latency 70-500
ms, typically about 100 ms, which is affordable per tool call but not per token. The guardrails
cookbook's argument against the alternative is the relevant comparison: a second LLM in front
of the first means "you pay a call's worth of latency and money on every turn, and an attacker
can talk that one past too."

No published accuracy for tool-call verification. The nearest measured evidence is the SDE
cascade's per-field verifier behaviour on extraction, and the caution that a cascade "is only
as good as its verifier": a vague question gives "mushy, uncalibrated scores".

Closest jaggedness modes: **4, indirection** (checking a call against a request is naturally
multi-hop — split it into the single-hop heads above) and **6, adversarial content**, since the
trace may contain text the agent was fed by an attacker.

- Field evidence (community-report): three independent pre-execution tool-call gates for coding agents shipped within days of launch, each checking the proposed call against the user's request before it runs; none publishes numbers, 2026-09. Source: https://github.com/y0usaf/pi-jev

## When the verdict flips

- **The tool is read-only and cheap to retry.** Verification costs more than the mistake —
  **weak**. Spend the checks on writes, payments, deletes and external messages.
- **The check would be the only thing preventing harm.** Permissions and spend limits stay
  authoritative in code; jev is a second semantic layer (mode 6). Otherwise this is **no**.
- **Correctness is decidable** — argument in an enum, id exists, amount within limit, path
  inside the workspace. Assert it; do not ask.
- **Per-token or per-thought-step checking.** The economics only work per tool call.
- **Traces run to tens of thousands of tokens.** Filter to the request, the call and the
  immediately relevant prior result (mode 5), or verify offline in a batch.

## Alternatives considered

- **Schema and permission validation** — mandatory, free, and catches the structural half; the
  documented gap is semantic errors in a well-formed call.
- **LLM-as-judge per step** — the incumbent for trace evaluation; accurate and the cost and
  latency the guardrails cookbook argues against, plus self-inconsistency between runs.
- **Deterministic policy engine (OPA, allow/deny rules)** — the right home for anything you can
  state as a rule, and it should stay in front. It cannot express "acts on something the user
  did not ask about".
- **Human review of the trace** — where the flagged calls go, not where the volume goes.
- **Post-hoc metrics only** (success rate, error rate) — cheap, and blind to the confidently
  wrong call that returned 200 OK.

## Sources

- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/llm_guardrails.md — accessed 2026-09-19
- https://docs.typesafe.ai/cookbooks/sde_cascade.md — accessed 2026-09-19
