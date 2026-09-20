---
id: au-generate-code-and-patches
title: Do not use jev to write code, patches, or SQL
verdict: no
domain: sdlc
decision_shapes: [classification, verification]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 9; assembly/binary underperform high-level languages)
  - https://docs.typesafe.ai/concepts/system-one.md  ("do not ... produce code")
  - https://empryo.com/blog/jev-and-the-harness  (review-loop false passes; deterministic code wins where an index captures the signal)
related: [au-generate-ticket-summaries, au-review-loop-pass-fail-gate, au-open-ended-agent-loop]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to generate the fix for this failing test?" Also "can jev write the
migration", "use jev to produce the SQL for a natural-language question", "have jev autofix lint
findings".

## Verdict

**No.** Code is text, and the System One page says these models "do not write replies, produce code, or
generate explanations of their reasoning." The jaggedness page adds a second, independent reason to keep
jev away from low-level code even as a judge: "questions about high-level programming languages will
perform better than questions about low level assembly, or binary encoded instructions." A model that
cannot emit a token stream cannot emit a patch, and a model that reads bytecode poorly should not be the
authority on it either.

## What jev would get wrong

The tempting near-miss is "let jev pick the right patch from N candidates a coding agent produced". That
is a valid Choice in shape, and it is worth trying — but it is selection, not authoring, and the
published evidence says do not make it the gate. Empryo's harness evaluation found that in automated
self-correction loops, "a model that misidentifies a failure report as a pass prematurely closes the run
on broken code. Jev agreed with human reviewer classifications in 12 of 20 ambiguous cases, but false
passes are unacceptable when verifying code correctness." Twelve of twenty on ambiguous cases is not a
merge gate.

## What stays in code

Compilation, the test suite, the type checker, the linter, and the diff itself. These are exact and they
are already correct; Empryo's own conclusion is that "when an exact index, graph traversal, or
deterministic heuristic already captures the signal, deterministic code remains faster, cheaper, and
more reliable."

Jev's honest role in an SDLC pipeline is advisory semantic judgement over text a parser has already
produced: a Noul "Does `pr.body` explain why the change was made, not only what changed?"; a Noul "Does
`diff` touch a file outside the directories named in `pr.body`?"; a Score over three described levels of
test-coverage narrative. None of these block a merge on their own.

## Numbers

TypeSafe's own workflow evals put jev at 67.8% combined accuracy versus Opus 5 at 73.1%
(https://evals.typesafe.ai, read 2026-09-19); its agent-trace-observability category scores 71.6%. Those
are decision tasks. For generation there is no number because there is no capability. A PR-review fan-out
over a 3,000-token diff excerpt with eight questions costs roughly 4,000 input tokens, about $0.00017 at
$0.042 per million input tokens with output free (https://docs.typesafe.ai/models.md).

- Field evidence (community-report): `fdsimms/todo#2781` — 7 of 15 planned AI features generate text, which ruled jev out for them regardless of price or latency, 2026-09-17. Source: https://github.com/fdsimms/todo/issues/2781

## When the verdict flips

For authoring code, **no rewrite exists**. Two adjacent designs are worth building: (1) a coding model
produces k candidate patches, code runs the tests on each, and jev's Choice breaks ties among the
patches that already pass — the deterministic filter comes first, always; (2) jev as an advisory
semantic lint that comments but never blocks, with the blocking gates left to CI. The verdict on a
jev-only "did this run succeed?" gate does not flip; see `au-review-loop-pass-fail-gate`.

## Alternatives considered

- **Regex / deterministic**: the compiler, tests, and linters are the authority. Keep them.
- **Small LLM**: fine for mechanical refactors under test coverage.
- **Frontier LLM / coding agent**: the correct tool for writing patches.
- **Fine-tuned classifier**: useful for triaging flaky tests from real failures if you have history.
- **Embeddings**: retrieve similar past fixes; cannot write one.
- **Human**: reviews the patch. Jev's advisory signals decide which patches get scrutiny first.

## Sources

- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19
- https://evals.typesafe.ai — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
