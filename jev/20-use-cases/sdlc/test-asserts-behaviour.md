---
id: uc-sdlc-test-asserts-behaviour
title: Flag tests that assert an implementation detail rather than a behaviour
verdict: conditional
domain: sdlc
decision_shapes: [detection, verification]
primitives: [noul, score]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting: checks for a team's conventions, run in CI and flagged for review)
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (atomic questions; criteria as an extension of the instruction)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 1 literal reading; mode 5 context rot)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://github.com/devagrawal09/jev-code  (deterministic checks catch added `test.skip`, deleted assertions and deleted test files; the semantic question is separate and advisory)
related: [uc-sdlc-semantic-lint-team-conventions, uc-sdlc-flaky-test-vs-real-failure, uc-sdlc-pr-title-matches-diff, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to tell whether a test asserts behaviour or an implementation
detail?" Also: "our AI-generated tests all mock everything and assert the mocks", "can we flag
snapshot tests that assert nothing meaningful?", "why does every refactor break 200 tests?".

## Verdict

**Conditional**, and the condition is that it stays a review comment on *new or changed*
tests. The judgement is real and hard to express in a linter — "this asserts that the function
called the repository, not that the record was saved" — but it is a matter of taste on which
competent engineers disagree, so there is no stable ground truth to gate on. This entry is
`inferred`: no cookbook or published measurement covers it, though the closest public tool
does the adjacent checks deterministically and keeps the semantic ones advisory. The value is
concentrated where tests arrive fastest and are least reviewed: the ones an agent wrote.
**Advisory first, gate later** — and for this check, honestly, advisory forever.

## What jev decides

One call per added or changed test function. State: `{test: {name, source}, subject:
{signature_of_the_unit_under_test}}`. Not the whole test file, not the implementation —
context rot is the failure mode that ruins this one.

```
asserts_observable_behaviour: Noul
  instructions: {question: "Do the assertions in `test.source` check an outcome a caller of
                            the unit could observe?",
                 inspect: "`test.source`",
                 focus: "An observable outcome is a return value, a raised error, or a change
                         a caller can read back. How the unit achieved it is not."}
  criteria:
    true:  {what: "Asserts on a returned value, a thrown error, or state read back through the
                   unit's own interface",
            examples: ["expect(save(u)).resolves.toEqual({id: 1}); expect(get(1)).toEqual(u)"]}
    false: {what: "Asserts that a collaborator was called, in what order, how many times, or
                   with which internal arguments; or asserts only on a private field",
            not_for: "Asserting a call to an external system that IS the behaviour, such as
                      'the webhook was sent'",
            examples: ["expect(repo.save).toHaveBeenCalledTimes(1)"]}

would_survive_refactor: Noul
  instructions: "Would `test.source` still pass if the unit were rewritten to produce the same
                 outputs by a different internal route?"
assertion_strength: Score
  criteria: ["Asserts only that nothing threw.",
             "Asserts a shape or a type, not a value.",
             "Asserts specific values for the outcome the test name claims to check."]
```

`would_survive_refactor` is the question that actually matters and it is the one most at risk
from failure mode 1: without the explicit "produce the same outputs by a different internal
route", a literal reader will answer about any rewrite at all.

Bands: comment only when `asserts_observable_behaviour < 0.3` **and** `would_survive_refactor
< 0.3`. Requiring both agreeing signals is what keeps the false-positive rate low enough that
the check survives contact with a real team. Never comment on unchanged tests.

## What stays in code

Everything structural, and `jev-code` shows the split: plain rules catch an added `test.skip`,
deleted assertions, deleted test files, and a test with no assertion at all. An AST query also
answers "does this test use a mock assertion API" exactly — `toHaveBeenCalled`,
`verify(mock)`, `assert_called_with` — and that is a large share of the signal for free. Run
it first; a Noul that duplicates a grep is the trap one field report warns about directly.
Also in code: identifying changed test functions, the diff, and posting the comment.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 900-character
test function plus a signature plus three questions with criteria (~1,900 characters) is about
720 tokens, **≈ $0.00003 per changed test**. A PR adding 25 tests is **≈ $0.00076**. Latency
70-500 ms, all calls parallel. Accuracy: not published, and this is a judgement where even
human agreement is low, so treat any number you produce as agreement-with-your-team, not
correctness. Labelled data for calibration: your own review history — past review comments
asking to "test the behaviour, not the mock" — and, better, the tests that had to be changed
during a refactor that changed no behaviour. The second set is an objective label and your
version control already holds it.

## When the verdict flips

- To **no**, if it gates CI. Mock-heavy tests are sometimes correct, and blocking on a
  contested style judgement teaches people to write `// lint-disable`.
- To **weak**, if an AST rule banning mock-call assertions in a given directory is acceptable
  to your team. Deterministic, free, and unarguable.
- Integration and contract tests, where asserting that a specific request was made to a
  specific collaborator *is* the behaviour under test. Scope the check to unit tests in code.
- Property-based or snapshot suites, where the shape of the assertion is generated and the
  question does not apply.

## Alternatives considered

- **AST lint rules** (ban `toHaveBeenCalled` outside `integration/`). Exact, free, and covers
  the common case. Do this first.
- **Mutation testing.** The rigorous answer to "does this test assert anything that matters":
  it measures what the test catches rather than guessing from its shape. Slow and expensive to
  run, which is exactly the gap a ~$0.00003 advisory check fills between mutation runs.
- **Coverage.** Measures execution, not assertion; a test that calls everything and asserts
  nothing scores perfectly. Not a substitute.
- **Frontier LLM review.** Reads the implementation too and gives a far better explanation;
  seconds and cents per test, and agent-generated PRs arrive with dozens of tests.
- **Small LLM.** Comparable and slower. On a contested style call a below-threshold "unsure"
  route is the more useful behaviour — and it is a threshold policy, not a model property: any
  model returning probabilities or logprobs can implement it, so compare the two with the same
  policy in place.
- **Fine-tuned classifier.** There is no agreed label to train on.
- **Human review.** The authority. This check exists to make the reviewer's first pass shorter.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `concepts/how-to-build-with-system-one.md`,
`model-jaggedness/jev-1.13.md` (modes 1 and 5), `models.md`. Field reports:
https://github.com/devagrawal09/jev-code (deterministic test checks; advisory semantic
findings; "An empty findings list is not an approval"),
https://github.com/wotai-dev/typesafe-jev-tools (the regex-label trap).
