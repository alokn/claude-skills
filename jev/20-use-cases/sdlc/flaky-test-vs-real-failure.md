---
id: uc-sdlc-flaky-test-vs-real-failure
title: Decide whether one failing test is flaky or a real regression, per test rather than per run
verdict: conditional
domain: sdlc
decision_shapes: [classification, detection]
primitives: [noul, choice]
evidence_level: community-report
sources:
  - https://github.com/2001Y/jev-axi  (`triage` returns "the root-cause line, failure category, whether it looks flaky, and severity")
  - https://github.com/Nishfleet/fleet-ops/issues/7392  (advisory-first; "once 100 rows compare against the actual outcome (rerun passed = flaky), a go row lets 'real' at p >= threshold skip the rerun")
  - https://github.com/devagrawal09/jev-code  ("Failure triage splits a saved test or CI log into separate failures, groups duplicates, and relates each one to the diff ... It also says what rerun would settle the question")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 2 counting)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sdlc-ci-failure-triage-before-rerun, uc-sdlc-test-asserts-behaviour, df-rollout, df-cost-model]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to tell a flaky test from a real failure?" Also: "can a model
decide whether to quarantine this test?", "our suite has 30 known-flaky tests and nobody
updates the list", "should this failure block the merge?".

## Verdict

**Conditional**, because a historical pass-rate database usually beats it and should be built
first. A test that has failed on 40 unrelated commits and passed on rerun each time is flaky
by arithmetic, not by judgement, and that computation is exact, free, and offline. Jev earns a
place on the cases the history cannot cover: a test that is new, was recently changed, or has
never failed before, where the only evidence is the assertion message and the diff. Two public
tools ship the per-failure shape — `jev-axi triage` reports "whether it looks flaky" alongside
the root-cause line, and `jev-code` "splits a saved test or CI log into separate failures,
groups duplicates, and relates each one to the diff". Neither publishes an accuracy figure.
**Advisory first, gate later:** annotate the failure; do not quarantine, do not auto-merge.

Closest failure mode: **math and counting** — flakiness is a pass-rate computation, so the
history database does the arithmetic in code and jev reads only the assertion message and the
diff, on the cases history cannot cover.

## What jev decides

One call per distinct failing test, not per run. Code extracts the assertion, the failing
line, and the relevant part of the diff.

```
failure_nature: Choice
  instructions: {question: "What does `failure` indicate about the code under test?",
                 focus: "Judge the failure message and the change together."}
  criteria:
    real_regression: {what: "An assertion about behaviour failed in a way the change would explain",
                      not_for: "A timeout or a resource error",
                      examples: ["expected 3 items, got 2, after a change to the filter"]}
    timing_or_order: {what: "The failure is about waiting, ordering, concurrency, or a shared
                             fixture, not about the asserted behaviour",
                      examples: ["Timeout waiting for selector", "Address already in use"]}
    environment:     {what: "The failure is about the machine, network, or external service"}
    test_is_wrong:   {what: "The test encodes an expectation the change deliberately changed"}
    unclear:         {what: "The evidence shown does not settle which of the above applies"}

change_could_cause_this: Noul
  instructions: {question: "Could the change in `diff_excerpt` plausibly produce `failure`?",
                 compare: ["`diff_excerpt`", "`failure.message`"],
                 focus: "Judge plausibility of a causal link, not certainty."}
  criteria:
    true:  {what: "The change touches code the failing assertion depends on"}
    false: {what: "The change is in unrelated code, or touches only docs, config, or other tests"}
```

`unclear` is load-bearing. A Choice always names an option, and a failure message with no
distinguishing content must be allowed to say so — `jev-axi` makes the same point about logs
with no failure in them.

Bands: `real_regression` at `confidence >= 0.85` **and** `change_could_cause_this >= 0.7` →
annotate "likely real, do not rerun". `timing_or_order` at `confidence >= 0.85` and
`change_could_cause_this < 0.3` → annotate "likely flaky". Everything else → today's
behaviour. Combine the two answers in code; do not ask one question that hides both
judgements.

## What stays in code

The flake history: pass/fail counts per test per branch, rerun outcomes, first-seen date, and
the quarantine list. All of it is counting and date arithmetic, both documented weaknesses,
and all of it is exact. Also in code: parsing the JUnit XML, grouping duplicate failures,
selecting the diff excerpt for the failing file, the rerun call, and the merge gate. The
ground truth for calibration — "the rerun passed" — is computed, never judged.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A failure
message plus stack excerpt (~1,200 characters) plus a diff excerpt (~1,200 characters) plus two
questions with criteria (~1,700 characters) is about 1,030 tokens, **≈ $0.000043 per failing
test**. A run with 15 failures is **≈ $0.00065**, in 15 parallel calls. The nearest published
latency for a jev CI-triage deployment is "~600 ms"
(github.com/Nishfleet/fleet-ops/issues/7392). Accuracy for per-test flake classification: not
published. Labelled data for calibration is the cleanest in this whole domain and costs
nothing: rerun the failure and record whether it passed. The same public spec sets the bar at
"100 rows compare against the actual outcome" before any gate flips.

## When the verdict flips

- To **weak**, once your flake database has enough history. Arithmetic on pass rates is a
  better answer than a text judgement, and you should build it first.
- To **no**, if the answer auto-quarantines a test. A quarantined real regression ships the
  bug; quarantine stays a human decision or a deterministic rule with a review.
- If you send whole logs rather than the extracted failure. Context rot, and a large suite's
  log will not fit the 32k state budget.
- Suites where every failure message is `AssertionError` with no detail. There is nothing to
  read; fix the test output first.

## Alternatives considered

- **Historical pass-rate / flake-detection services.** The primary alternative and usually the
  right one. Deterministic, per-test, improves with time; blind on new and changed tests.
- **Rerun twice and believe the second run.** The incumbent. Cheap per run, expensive in
  aggregate, and it launders real regressions into green builds.
- **Test-impact analysis (which tests the diff can reach).** Deterministic and far stronger
  than `change_could_cause_this` where the tooling exists for your language. Prefer it.
- **Frontier LLM.** Reads the test and the change properly and can explain the regression;
  seconds and cents per failure, and failures come in bursts.
- **Small LLM.** Comparable; on a 100-row public head-to-head of a different SDLC
  classification task jev scored 50.0% against Haiku 4.5's 42.0% at 468 ms against 695 ms
  (github.com/wotai-dev/typesafe-jev-tools, 2026-09-18) — a reminder that both are modest at
  this kind of labelling.
- **Fine-tuned classifier on your rerun outcomes.** Once you have thousands of labelled rows
  from the shadow log, this becomes the serious competitor. Measure it.
- **The engineer who broke the build.** Stays, and is the audience.

## Sources

Accessed 2026-09-19. Field reports: https://github.com/2001Y/jev-axi (`triage` output fields),
https://github.com/Nishfleet/fleet-ops/issues/7392 (~600 ms, advisory-first, 100-row flip
rule), https://github.com/devagrawal09/jev-code (per-failure splitting, relating failures to
the diff, "what rerun would settle the question"), https://github.com/wotai-dev/typesafe-jev-tools.
Docs: `model-jaggedness/jev-1.13.md`, `models.md`.
