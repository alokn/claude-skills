---
id: uc-sdlc-ci-failure-triage-before-rerun
title: Classify a failed CI run as infrastructure, concurrency, flaky, or a real regression before auto-rerunning
verdict: good
domain: sdlc
decision_shapes: [classification, routing]
primitives: [choice, noul, score]
evidence_level: community-report
sources:
  - https://github.com/Nishfleet/fleet-ops/issues/7392  (CI failure triage spec: RUNNER-GONE / CONCURRENCY-BLOCKED / flaky / real; "$0.042/MTok in, $0 out; ~600 ms"; advisory-first JSONL logging; 100-row benchmark before the gate flips)
  - https://github.com/2001Y/jev-axi  (`triage` returns "the root-cause line, failure category, whether it looks flaky, and severity"; "When the log shows no failure it says so instead of guessing a root cause")
  - https://empryo.com/blog/jev-and-the-harness  (failure triage accepted as an integrated decision point; "Jev (TypeSafe) | 102 of 102 | 0 | 273 ms | $0.00002")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot: filter first, send only what the question needs)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify, then route to deterministic code, a specialist model, or a human)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input)
related: [uc-sdlc-api-error-log-triage, uc-sdlc-pr-risk-tier-review-routing, df-rollout, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage CI failures before auto-rerunning?" Also: "can we
stop burning runner minutes re-running real regressions?", "can a model tell a flaky test
from a broken one?", "our rerun bot greps the log for 'connection reset' — can we do better?".

## Verdict

**Good.** A public deployment specifies exactly this decision — "jev: CI failure triage —
RUNNER-GONE / CONCURRENCY-BLOCKED / flaky / real before any rerun" — and the input is text
you already have, the output is one of four labels, and the rerun is a cheap, reversible
action with an obvious low-confidence path (rerun anyway, as today). It is `good` not
`strong` because that deployment publishes a design and a cost, not an accuracy result:
"$0.042/MTok in, $0 out; ~600 ms". **Advisory first, gate later** — the same source is
categorical about it: "mode: ADVISORY FIRST ... No answer becomes a hard gate until the
matching benchmark records a go row with a threshold."

## What jev decides

Filter the log in code before the call. This is the single most important design decision:
raw CI logs are megabytes of irrelevant detail and failure mode 5 is the one that kills this
use case. Send the last N lines around the first error, plus run metadata. The public spec
sends exactly "log tail + run metadata".

```
failure_class: Choice
  instructions: {question: "What kind of failure does `log_tail` show?",
                 focus: "Classify the cause of the failure, not the job that failed."}
  criteria:
    runner_gone:  {what: "The runner or container vanished: lost connection, evicted, out of
                          disk, cancelled by the platform",
                   not_for: "A test that timed out while the runner kept running",
                   examples: ["The runner has received a shutdown signal", "No space left on device"]}
    concurrency_blocked: {what: "The job did not run its work: a lock, a queue, a concurrency
                          group, or another run holding the resource",
                   not_for: "A deadlock inside the code under test"}
    flaky:        {what: "The code under test is fine and the failure depends on timing,
                          ordering, network, or a shared fixture",
                   not_for: "A consistent failure in a test that is merely new",
                   examples: ["Timeout waiting for selector", "Address already in use"]}
    real:         {what: "The change under test is wrong: an assertion about behaviour failed,
                          a type error, a compile error"}
    no_failure:   {what: "The log shows no failure at all"}

same_as_previous_run: Noul
  instructions: "Does `log_tail` show the same failure as `previous_log_tail`?"
severity: Score
  criteria: ["One test.", "One suite or job.", "The whole pipeline, every branch."]
```

`no_failure` is not decoration — `jev-axi triage` makes the same point: "When the log shows
no failure it says so instead of guessing a root cause." Without that option, a Choice is
relative and will name a failure class for a green log.

Bands, once the gate flips: `real` at `confidence >= <threshold from your benchmark>` → skip
the rerun, file the fault. `flaky` / `runner_gone` / `concurrency_blocked` at high confidence
→ rerun once, as today. Anything below the floor → today's behaviour unchanged. The rollback
in the public spec is one per-site flag, and "advisory mode is inert by construction".

## What stays in code

Everything with a definite answer: the exit code, the job name, whether this SHA has failed
before, how many reruns have already happened, the retry budget, and the rerun call itself.
Log truncation and secret redaction. The comparison "did the rerun pass" — that is the ground
truth, not a judgement. Deterministic patterns you already trust (a known infrastructure
error string) stay authoritative and short-circuit before the call; the same spec says to
"delete the regex/heuristic it replaces once the gate flips", not before.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 4,000-character
log tail plus metadata plus three questions with criteria (~2,200 characters) is about 1,550
tokens, **≈ $0.000065 per failed run**. Measured latency from the public deployment: "~600 ms"
(github.com/Nishfleet/fleet-ops/issues/7392). A related harness report measured a different
failure-triage task at "102 of 102 | 0 | 273 ms | $0.00002"
(empryo.com/blog/jev-and-the-harness); that is API error triage, not CI logs, so do not carry
the accuracy across. Labelled data for calibration is free and unusually clean: **the rerun
outcome itself**. The public spec states the rule — "once 100 rows compare against the actual
outcome (rerun passed = flaky), a go row lets 'real' at p ≥ threshold skip the rerun".

## When the verdict flips

- You send whole logs instead of tails. Accuracy falls, cost rises, and a 20 MB log will not
  fit the 32k state budget at all.
- Your failures are already classified correctly by a short, stable list of error strings.
  Then the regex is right and jev adds a network call.
- The action is destructive — cancelling a deploy, marking a release bad. Rerunning is
  cheap and reversible, which is what makes this safe; a different action needs a different
  threshold, or a human.
- Logs are mostly non-English or mostly stack traces from a language the model handles
  poorly. Evaluate before trusting.

## Alternatives considered

- **Log greps / error-string tables.** The incumbent. Free, exact, and they work until the
  platform changes its wording. Keep the ones that are right.
- **Rerun everything twice.** The real incumbent in most repos. Costs runner minutes and
  hides real regressions behind green reruns; that is the problem being solved.
- **Frontier LLM.** Better at explaining the root cause in the PR comment; seconds and cents
  per failure, and CI failures are high volume.
- **Small LLM.** Comparable labels; roughly 1.4x-3.7x the latency in the public head-to-head.
  In that same 149-row run the models differed in how often they fell below the chosen
  threshold (34.7% against 2.7%) — a coverage trade-off, and one a small LLM exposing logprobs
  can be given too. Without such a policy it skips a rerun confidently.
- **Fine-tuned classifier on your own log history.** Strong candidate once you have the
  100+ labelled rows, and you will have them from the shadow log anyway. Compare it honestly.
- **Flaky-test databases (quarantine by historical pass rate).** Deterministic, per-test, and
  excellent — but it answers "is this test flaky in general", not "was this run flaky". Use
  both.
- **Human on-call.** Stays for the low band and for `real`.

## Sources

Accessed 2026-09-19. Field reports: https://github.com/Nishfleet/fleet-ops/issues/7392
(the four classes, ~600 ms, advisory-first JSONL logging, 100-row flip rule, per-site rollback
flag, "$1 per packet" spend cap), https://github.com/2001Y/jev-axi (`triage` output shape and
the no-failure case), https://empryo.com/blog/jev-and-the-harness (102 of 102, 273 ms, $0.00002
on API failure triage). Docs: `model-jaggedness/jev-1.13.md`, `patterns/intent-routing.md`,
`models.md`.
