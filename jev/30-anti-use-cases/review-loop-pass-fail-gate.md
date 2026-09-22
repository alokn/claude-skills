---
id: au-review-loop-pass-fail-gate
title: Do not let jev decide whether an automated run passed or failed
verdict: no
domain: sdlc
decision_shapes: [verification]
primitives: [noul, choice]
evidence_level: independent-benchmark
sources:
  - https://empryo.com/blog/jev-and-the-harness  (agreed with human reviewers in 12 of 20 ambiguous cases; "false passes are unacceptable when verifying code correctness")
  - https://docs.typesafe.ai/confidence.md  ("Low confidence: Do not act")
  - https://docs.typesafe.ai/concepts/system-one.md  ("Calibration ... does not guarantee that an individual answer is correct")
related: [au-generate-code-and-patches, au-sole-security-gate, au-open-ended-agent-loop]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide whether the self-correction loop can stop?" Also "have jev read
the test output and tell us if it passed", "use jev as the exit condition for the fix-and-retry loop",
"jev as the reviewer that closes the ticket".

## Verdict

**No.** Empryo measured this exact design: "During automated self-correction loops, a model that
misidentifies a failure report as a pass prematurely closes the run on broken code. Jev agreed with human
reviewer classifications in 12 of 20 ambiguous cases, but false passes are unacceptable when verifying
code correctness." The failure is asymmetric — a false fail costs a wasted iteration, a false pass ships
a broken change — and 12 of 20 on the ambiguous cases is nowhere near the bar for an unattended gate.

Not a model failure: **governance** veto — the test runner's exit code is the pass/fail
authority; 12 of 20 on ambiguous cases is advisory at best.

## What jev would get wrong

Ambiguous runs are the only ones that reach the model, because the unambiguous ones are settled by the
exit code. So jev is asked to adjudicate precisely the population where it was measured at 12/20. It
returns a confident-looking typed answer either way; the System One page warns that "Calibration is
measured across groups of predictions; it does not guarantee that an individual answer is correct."
Calibration tells you the *distribution* of errors, not which run is the wrong one, and an unattended
loop consumes individual answers, not distributions.

## What stays in code

The gate. The process exit code, the test runner's structured report, the type checker, the linter, the
build. These are the ground truth for "did it pass", and they are exact. If the harness cannot tell pass
from fail deterministically, fix the harness — make the runner emit machine-readable results — rather
than inserting a judge.

Jev's honest role is advisory triage *within* the failing set, where being wrong costs an ordering rather
than a merge: a Choice over `compile_error`, `assertion_failure`, `timeout`, `flaky`, `environment`
given the log tail; a Noul "Does `log_tail` name a file the patch touched?"; a Score over described
levels of "how likely is this failure unrelated to the change". Code uses these to order the work and to
decide which failure the agent attacks first.

## Numbers

Measured agreement with human reviewers: 12 of 20 ambiguous cases
(https://empryo.com/blog/jev-and-the-harness, accessed 2026-09-19). A triage call over a 2,000-token log
tail with six questions is roughly 2,600 input tokens, about $0.00011 at $0.042 per million input tokens
with output free (https://docs.typesafe.ai/models.md), typically about 100 ms — cheap enough to run on
every failure, which is the point of using it for triage rather than for the gate.

- Field evidence (community-report): Empryo harness field report, review-loop pass/fail — 60% agreement (12/20) on ambiguous cases, rejected because false negatives are unacceptable for verification, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness

- Field evidence (community-report): `SathiaAI/adversarial-review#69` shipped jev with the explicit design rule "Jev output cannot dismiss findings" — jev may add or rank findings, never close them. Source: https://github.com/SathiaAI/adversarial-review/pull/69

## When the verdict flips

It flips to **conditional** in one direction only: jev may *fail* a run that the deterministic gate
passed, never pass one it failed. A semantic check that says "the tests pass but `diff` does not address
the issue described in `issue.body`" adds safety because its errors are false fails, which are cheap. It
also flips to good for ordering and routing within the failing set. It never flips to an unattended
pass authority — **no rewrite exists** for that, because the asymmetry of the cost function, not the
model's accuracy, is what disqualifies it. The confidence doc's own rule applies: "Low confidence: Do not
act. Route to a human, request clarification, or fall back to a different system."

## Alternatives considered

- **Regex / deterministic**: the test runner's exit code and structured report. This is the gate. Free,
  exact, already present.
- **Small LLM**: worse at the same task and equally unsuited to an asymmetric gate.
- **Frontier LLM**: better judgement, still probabilistic; usable as an advisory reviewer, not as the
  merge authority.
- **Fine-tuned classifier**: could learn your harness's log formats, but the same asymmetry applies.
- **Embeddings**: can cluster recurring failures for triage.
- **Human**: the reviewer of record. Jev's value is deciding which failures a human sees first.

## Sources

- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://docs.typesafe.ai/confidence.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
