---
id: uc-sdlc-pr-title-matches-diff
title: Check whether a pull request title and description match what the diff actually changes
verdict: good
domain: sdlc
decision_shapes: [verification, detection]
primitives: [noul, choice]
evidence_level: community-report
sources:
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Universal Verification: "Verify the input prompt, extractions, reasoning traces, tool calls, or inputs of any other AI")
  - https://docs.typesafe.ai/concepts/how-to-build-with-system-one.md  (compare two named state paths in one question; `compare` field in instructions)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 4 indirection)
  - https://docs.typesafe.ai/models.md  (64k request / 32k state limit; $0.042 per million input tokens, output free)
  - https://github.com/2001Y/jev-axi  (`commit` "checks each commit's message against its diff"; `diff` asks five questions per changed file and returns ok / review / block)
  - https://github.com/devagrawal09/jev-code  (per-block question "How closely is this changed block related to the task?"; fixed thresholds in code; advisory report with no pass result)
related: [uc-sdlc-pr-description-explains-why, au-commit-type-classification-unattended, uc-sdlc-pr-risk-tier-review-routing, df-fit-test, cb-citation_check]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to check that a PR title matches its diff?" Also: "can a model
catch the PR that says 'fix typo' and rewrites the auth middleware?", "can we flag scope
creep in review?", "does the commit message describe the commit?".

## Verdict

**Good.** This is verification of one artefact against another — the category TypeSafe calls
universal verification — and two public tools ship it: `jev-axi commit` "checks each commit's
message against its diff", and `jev-code` asks per changed block "How closely is this changed
block related to the task?" and turns the answers into flags with thresholds owned by code,
not the model. It is `good` rather than `strong` because neither tool publishes an accuracy
number for the check. **Advisory first, gate later:** a review comment listing the blocks that
look off-topic, never a failed build, until the numbers exist.

## What jev decides

Do not send the patch. Ask one question per changed hunk, and let code aggregate — this is the
`jev-code` shape and it is what keeps failure mode 5 (large state full of irrelevant detail)
out of the design. State per hunk:
`{stated_intent: "<title + first paragraph of body>", change: {path, hunk}}`.

```
block_relates_to_intent: Score
  instructions: {question: "How closely does `change` relate to `stated_intent`?",
                 compare: ["`stated_intent`", "`change.hunk`"]}
  criteria: ["Unrelated: this change would make sense in a different pull request.",
             "Incidental: a rename, import, or formatting change dragged along by the work.",
             "Supporting: needed to make the stated change work, but not the stated change.",
             "Central: this is the change the title describes."]

changes_behaviour: Noul
  instructions: "Does `change.hunk` alter runtime behaviour, as opposed to only comments,
                 formatting, or tests?"
```

Aggregate in code: a PR is flagged when a hunk scores below 1.0 on `block_relates_to_intent`
*and* `changes_behaviour >= 0.7`. Do not ask jev "how many hunks are unrelated" — counting is
failure mode 2; the docs' own remedy is one question per item and a sum in code.

Bands: `confidence >= 0.8` list the hunk in the comment; `0.5-0.8` list it under "possibly";
below that, drop it silently. Low confidence here means *say nothing*, which is the right
default for an advisory reviewer.

## What stays in code

Hunk splitting and path filtering; excluding lockfiles, generated code and vendored
directories before any call; redacting credentials from the diff (jev-axi does this before
sending); the threshold arithmetic; posting the comment. Deterministic checks run first and
stay authoritative — `jev-code` catches added `test.skip`, deleted assertions, deleted test
files and lockfile/CI/config edits with plain rules, and only the semantic question goes to
the model. Its rules format makes the same split explicit: "Only `semantic` rules are judged;
`deterministic` and `process` rules are listed as not checked, because linters and people
handle those better."

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 40-line hunk
(~1,600 characters) plus a 200-character intent plus two questions (~700 characters) is about
630 tokens per hunk, **≈ $0.000026 per hunk**; a 12-hunk PR is **≈ $0.00032**, one call per
hunk. `jev-axi` prints a real usage line for a small Choice: `usage: 318in/38out 402ms
jev-1.13.0 $0.00001`. Latency is per hunk and hunks parallelise. Accuracy for this check: not
published. Labelled data for calibration: your own history — PRs where a reviewer asked to
split the change, and PRs later reverted for touching something the title never mentioned.

## When the verdict flips

- You send the whole diff in one state. Large PRs then blow past the 32k state budget and
  accuracy degrades on exactly the PRs that most need the check. Per-hunk or nothing.
- The repo squash-merges with generated titles from the branch name; there is no stated
  intent to compare against.
- You want the check to block. An unrelated-looking hunk is often a legitimate drive-by fix;
  blocking converts a helpful comment into a reason to disable the bot.
- Machine-generated diffs (codegen, formatter runs) dominate. Filter them in code first.

## Alternatives considered

- **Path globs / conventional-commit scope linting.** Deterministic and correct for what it
  measures; it cannot tell "fix typo" from "rewrite auth" because both touch the same paths.
  Keep it, it is free.
- **Frontier LLM review bot.** Reads the whole PR and writes prose; far better at explaining
  the mismatch, at seconds and cents per PR, and its wording varies run to run. Sensible split: jev
  finds the hunks, the LLM writes the paragraph about them.
- **Small LLM per hunk.** Same shape, roughly 1.4x-3.7x the latency in the public
  head-to-head; suppressing the weak flags needs a below-threshold route, which requires
  logprobs that not every small model exposes.
- **Fine-tuned classifier.** "Related to the stated intent" is defined by the intent string,
  which changes every PR; there is nothing stable to fine-tune on.
- **Embeddings (cosine between title and hunk).** Fails on the common case: a well-named
  function in an unrelated file is lexically close to the title and semantically irrelevant.
- **Human review.** The incumbent, and the consumer of the output.

## Sources

Accessed 2026-09-19. `concepts/use-case-map.md`, `concepts/how-to-build-with-system-one.md`,
`model-jaggedness/jev-1.13.md`, `models.md`. Field reports:
https://github.com/2001Y/jev-axi (`commit` and `diff` recipes, usage line, credential
redaction), https://github.com/devagrawal09/jev-code (per-block relatedness question, exact
checks first, "An empty findings list is not an approval").
