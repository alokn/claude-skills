---
id: uc-sdlc-semantic-lint-team-conventions
title: Run a team's written conventions as semantic lints in CI
verdict: good
domain: sdlc
decision_shapes: [detection, verification]
primitives: [noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting: "Define checks for your team's coding conventions and writing guidelines. Run these checks in CI and flag violations for review.")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (one atomic question per property; criteria as an extension of the instruction)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 1 literal reading; mode 5 context rot; mode 7 contradictory instructions and criteria)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 32k state budget)
  - https://github.com/devagrawal09/jev-code  (rules file: "Only `semantic` rules are judged; `deterministic` and `process` rules are listed as not checked, because linters and people handle those better")
related: [uc-sdlc-pr-description-explains-why, uc-sdlc-test-asserts-behaviour, uc-sdlc-doc-drift-local-check, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to lint our coding conventions in CI?" Also: "half our style
guide can't be expressed in ESLint — can a model check it?", "can we enforce 'errors must
carry context' automatically?", "semantic lint rules for our repo".

## Verdict

**Good.** TypeSafe names this category directly — "define checks for your team's coding
conventions and writing guidelines, run these checks in CI and flag violations for review" —
and a public tool ships the design with the right boundary: `jev-code`'s rules file judges
only rules marked `semantic`, and lists `deterministic` and `process` rules as *not checked*,
"because linters and people handle those better". It is `good` not `strong` because the docs
describe the category without a worked example or a measurement. **Advisory first, gate
later:** each rule earns its gate separately, on its own labelled set.

## What jev decides

One Noul per rule, one call per changed hunk. Never one question per file with a list of
rules inside it — that hides several judgements behind one answer, and the guide calls
decomposition "probably the most important concept".

State: `{rule: {text, rationale}, change: {path, hunk}}`. The rule text goes in the state, not
only in the instruction, because the model must not be relied on for knowledge of your
private conventions.

```
violates_rule: Noul
  instructions: {question: "Does `change.hunk` break the rule stated in `rule.text`?",
                 compare: ["`rule.text`", "`change.hunk`"],
                 focus: "Judge only the lines added or changed in this hunk."}
  criteria:
    true:  {what: "Added or changed code does the thing the rule forbids, or omits what it requires",
            examples: ["Rule: errors returned from a handler must name the operation that
                        failed. Hunk: `return err`"]}
    false: {what: "The hunk complies, or the rule does not apply to this kind of code",
            not_for: "Pre-existing violations in unchanged context lines",
            examples: ["Rule about handlers; hunk changes a test fixture"]}

rule_applies_here: Noul
  instructions: "Is `change.hunk` the kind of code `rule.text` is about?"
```

The second Noul is what keeps the false-positive rate survivable: most rules apply to a
minority of hunks, and a rule that fires on unrelated code gets the whole check disabled
within a week. Flag only when `rule_applies_here >= 0.7 AND violates_rule >= 0.7`; combine in
code, never in one question.

Failure mode 7 is the specific hazard: if the rule text is phrased as a prohibition and the
question asks about compliance, `true` means opposite things in the two halves. Phrase every
rule so that `true` means "violation", consistently, across the whole rule file.

## What stays in code

Everything a linter, formatter, type checker, or AST query can decide — naming patterns, import
order, forbidden identifiers, cyclomatic complexity, banned APIs. These are exact and cheaper,
and one field report's central warning is about measuring a judgement model against labels a
regex could produce. Also in code: which rules apply to which paths (a glob in the rule file),
hunk splitting, the combination logic, the threshold per rule, and the CI annotation.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. One hunk of
~1,600 characters plus a rule of ~300 characters plus two Nouls with criteria (~900
characters) is about 700 tokens per (rule, hunk) pair, **≈ $0.00003**. Cost scales with
`rules × hunks`, which is the number to watch: 8 rules over a 12-hunk PR is 96 pairs, **≈
$0.0028 per PR** — still trivial, but batch the rules for a single hunk into one call, since
questions over the same state run in parallel and add little latency ("barely changes" in the
docs, not zero). That turns it into 12 calls
of ~2,400 tokens, **≈ $0.0012**. Accuracy: not published. Labelled data for calibration: your
own review comments — past PR comments that cite a convention are the positive class, and
that corpus already exists in your repository's review history.

- Field evidence (community-report): four independent project-rule and preference linters run a team's written conventions against a diff; none publishes numbers, 2026-09. Source: https://github.com/doeixd/jev-pref

## When the verdict flips

- The rule is expressible in a linter. Then write the lint rule; it is exact, fast, and
  offline.
- The rule requires whole-file or cross-file reasoning ("this class should have been a
  function", "this duplicates the helper in another module"). That is multi-hop, and the
  hunk-local framing that makes this work no longer applies.
- You gate the build on day one, or on a rule with no labelled set. Expect the check to be
  disabled after the first confident false positive on a release-blocking PR.
- Generated code, vendored directories, or a migration that rewrites thousands of lines.
  Filter in code.

## Alternatives considered

- **ESLint / clippy / custom AST rules.** The right tool for anything structural; free, fast,
  deterministic. Most of a style guide belongs here.
- **Frontier LLM code review.** Reads the whole file, finds real bugs, and explains itself —
  things jev cannot do. Cost and latency make per-rule-per-hunk coverage impractical, which is
  the trade: jev covers everything cheaply, the LLM goes deep on what jev flags.
- **Small LLM.** Same shape at higher latency. On an advisory lint "unsure" is a feature, and a
  small LLM that exposes logprobs can be given the same below-threshold route; in one 149-row
  public run the models differed only in how often they fell below the chosen threshold
  (34.7% against 2.7%), a coverage trade-off rather than a capability.
- **Fine-tuned classifier per rule.** A model per rule, retrained whenever the rule is
  reworded. Jev's advantage is that a rule change is a string edit.
- **Embeddings.** No notion of "violates".
- **Human code review.** Stays. This exists to stop reviewers repeating the same comment.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md` (semantic code linting),
`concepts/how-to-build-with-system-one.md`, `model-jaggedness/jev-1.13.md` (modes 1, 5, 7),
`models.md`. Field reports: https://github.com/devagrawal09/jev-code (semantic vs
deterministic rule classes), https://github.com/wotai-dev/typesafe-jev-tools (the
regex-label trap).
