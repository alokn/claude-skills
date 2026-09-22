---
id: au-commit-type-classification-unattended
title: Do not let jev classify commit type for an unattended changelog or an automatic version bump
verdict: weak
domain: sdlc
decision_shapes: [classification]
primitives: [choice, noul]
evidence_level: independent-benchmark
sources:
  - https://github.com/wotai-dev/typesafe-jev-tools  (head-to-head, run 2026-09-18: "commit type | 100 | 50.0% | 42.0% | 468ms | 695ms" for Jev vs Claude Haiku 4.5; "Accuracy splits. Latency does not."; the regex-label trap)
  - https://github.com/2001Y/jev-axi  (`commit` "checks each commit's message against its diff")
  - https://docs.typesafe.ai/primitives/choice.md  (Choice is relative and always picks an option; add `other`)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (confidence band split; answer one level coarser when unsure)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [uc-sdlc-pr-title-matches-diff, uc-sdlc-release-notes-bucketing, au-confidence-as-correctness-gate, cb-classification_using_confidence, df-fit-test]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to classify commits as feat / fix / chore for the changelog?"
Also: "can a model fix our conventional-commit prefixes?", "can we generate release notes
buckets without commitlint?", "does the commit message match what the commit did?".

## Verdict

**Weak** for the unattended case the question is really about — a changelog, release
notes or a version bump produced from jev's label without a human confirming it. This is
the one SDLC task with published independent measurement, and the measurement is what
decides the verdict: on 100 rows jev scored **50.0%** against Claude Haiku 4.5's
**42.0%**, at 468 ms p50 against 695 ms (github.com/wotai-dev/typesafe-jev-tools, run
2026-09-18), and a separate internal assessment measured **62.9% agreement over 43
commits at 0.79 mean confidence** — overconfident by 16 points
(github.com/bestdan/workflow-skills/pull/757). Jev wins the head-to-head and both
numbers are poor. A coin-flip-adjacent label at a confidence that overstates it cannot
drive a published changelog, and `commitlint` or a path heuristic does the job exactly
and for free wherever the prefix exists.

**Separate proposal: conditional, and only as an advisory gap-filler.** Where no prefix
exists and a human reviews the release notes, the same call can *suggest* a bucket and
flag a subject that disagrees with its diff. Narrowing the taxonomy to three buckets
(user-visible / fix / internal) makes the question much easier than the eight-way one
that was measured. **Advisory first, gate later**; on this evidence, "later" may be
never for the gate.

## What jev would get wrong

Run unattended, the failure is not a crash: it is a confident, wrong bucket in a published
changelog. On the measured set half the labels were wrong, `feat` was misread as `fix` 18 times
among the misses, and the mean confidence on that run was 0.79 — high enough to clear most
automation thresholds. The decomposition below is the best available version of the question, and
it is still only good enough to suggest.

State: `{subject, body, diff_summary: {paths, added, removed, public_api_touched}}`.
`public_api_touched` is computed in code from your export surface.

```
commit_type: Choice
  instructions: {question: "What kind of change does this commit make?",
                 focus: "Classify by effect on the shipped product, not by the words in the subject."}
  criteria:
    feat:  {what: "Adds capability a user or caller can invoke that did not exist before",
            not_for: "Making an existing capability faster or correct",
            examples: ["Add --json output to the export command"]}
    fix:   {what: "Makes existing behaviour match what it was supposed to do",
            not_for: "Changing what it was supposed to do", examples: ["Stop truncating UTF-8 names"]}
    perf:  {what: "Same behaviour, measurably less time or memory"}
    refactor: {what: "No change to behaviour, capability, or performance characteristics"}
    docs:  {what: "Only documentation, comments, or examples"}
    test:  {what: "Only tests or test infrastructure"}
    chore: {what: "Build, CI, dependencies, tooling, release plumbing"}
    other: {what: "None of the above describes the primary effect"}

is_breaking: Noul
  instructions: "Would a consumer of the public API have to change their code after this commit?"
  criteria: {true:  {what: "Removes, renames, or changes the meaning of a public name or field"},
             false: {what: "Adds something new, or changes only internals",
                     not_for: "A deprecation with the old path still working"}}

subject_matches_change: Noul
  instructions: "Does `subject` describe what `diff_summary` shows the commit actually did?"
```

Bands, given the measured accuracy: `confidence >= 0.9` fill a missing prefix as a *suggestion*
in the release-notes draft; anything lower goes to the "unclassified" bucket a human sorts.
The classification-with-confidence cookbook's coarser-answer trick applies well here — bucket
into "user-visible" vs "internal" when the leaf type is uncertain, rather than guessing
`chore`.

## What stays in code

The prefix parse itself. If `subject` starts with `fix(scope):`, that is the *declared* type —
reading it is lexical, exact, and free. Keep that separate from the question of whether the
declaration is true of the diff, which is a semantic check with its own labels and its own
error rate; do not let a valid prefix stand in for a verified one. The field report that ran the benchmark is blunt about why this
matters: "The trap the hook exists to prevent is band one. A judgment model measured against
labels that a regex could produce gives you a confident, meaningless number." Also in code:
semver arithmetic, the release range, tag comparison, dedup of reverts and merge commits,
and writing the CHANGELOG file. Breaking-change detection from an API-surface diff is a
deterministic computation where you have the tooling; prefer it and use the Noul only as a
second opinion that can *add* a warning, never remove one.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Subject, body
and diff summary (~800 characters) plus an eight-option Choice with criteria and two Nouls
(~1,900 characters) is about 680 tokens, **≈ $0.000029 per commit**. Batch a release's
commits as separate calls; they parallelise. Measured latency on this exact task: 468 ms p50
(jev) against 695 ms (Haiku 4.5), 100 rows, 2026-09-18. Measured accuracy on that set: 50.0%
against 42.0%. That report also notes "TypeSafe has not published pricing. `/pricing` and
`/limits` both 404 as of 2026-09-18" — the $0.042 figure here comes from
docs.typesafe.ai/models.md, which is the source to re-check. Labelled data for calibration:
your own repository's history of correctly-prefixed commits, which is a free labelled set of
whatever size your git log allows.

- Field evidence (community-report): an internal assessment measured commit-message and diff classification at 62.9% agreement over 43 commits at 0.79 mean confidence - "overconfident by 16 points" - with `feat` misread as `fix` 18 times among the misses; a community commit-miner ships the same decision without published numbers, 2026-09. Source: https://github.com/bestdan/workflow-skills/pull/757

## When the verdict flips

- To **no** *for prefix extraction*, if `commitlint` is enforced on your repo. The prefix is
  then present and syntactically valid by construction, and reading it is a parse, not a
  judgement. Note what commitlint does not check: it validates the *form* of the prefix, not
  whether `fix:` truthfully describes the diff. That second question — does the message match
  the change? — survives commitlint and is a separate, evaluable task (`subject_matches_change`
  above); it has its own labels and its own accuracy, and nothing here measures it.
- To **no**, if the classification drives an automatic semver bump and a publish. At 50% on a
  public 100-row set, that ships wrong versions.
- To **conditional**, if you narrow the taxonomy *and* a human confirms the release notes. Three
  buckets (user-visible / fix / internal) is a much easier question than eight, and the same call
  can answer it — but the eight-way 50.0% is the only figure anyone has published, so re-measure
  the three-way version before relying on it.
- If your commits are one-line squashes with no body and no diff summary, there is nothing to
  read; accuracy will be worse than the published figure, not better.

## Alternatives considered

- **`commitlint` / conventional-commit prefixes.** The right answer for prefix syntax. Enforce
  them and the extraction half of this entry becomes unnecessary; the message-versus-diff half
  does not, because commitlint never reads the diff.
- **Path and file-type heuristics** (only `docs/**` → docs, only `*_test.go` → test). Exact
  and covers a real share of commits for free. Run them first.
- **Small LLM (Haiku-class).** Measured at 42.0% on the same 100 rows against jev's 50.0%, at
  695 ms against 468 ms. Jev wins on both axes here; that is the honest read of the only
  published head-to-head.
- **Frontier LLM.** Not measured on this set; it also writes the release-note sentence, which
  jev cannot do at all (failure mode 9, generation).
- **Fine-tuned classifier on your own prefixed history.** Likely the best option for a repo
  with tens of thousands of conventional commits, because it learns *your* convention rather
  than the general one.
- **Embeddings.** No; the distinction between `fix` and `refactor` is not lexical distance.
- **Human release manager.** Stays, and on these numbers stays in charge.

## Sources

Accessed 2026-09-19. Field reports: https://github.com/wotai-dev/typesafe-jev-tools (commit
type 100 rows, Jev 50.0% / Haiku 42.0%, 468 ms / 695 ms, 2026-09-18; the 150-passage
calibration table; the regex-label trap; pricing pages 404 on that date),
https://github.com/2001Y/jev-axi (`commit` message-vs-diff check). Docs:
`primitives/choice.md`, `cookbooks/classification_using_confidence.md`, `models.md`.
