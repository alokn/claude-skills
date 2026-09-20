---
id: uc-sdlc-release-notes-bucketing
title: Decide whether a merged change deserves a release note and which audience section it belongs in
verdict: good
domain: sdlc
decision_shapes: [classification, detection, scoring]
primitives: [choice, noul, score]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/fan-out.md  (one call answers the category and the speculative follow-ups; code decides which answers matter)
  - https://docs.typesafe.ai/primitives/choice.md  (Choice is relative and always names an option; add `other`/`none`)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  (confidence band split; report one level coarser when unsure)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 9 generation: jev does not write the note; mode 2 counting)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
related: [au-commit-type-classification-unattended, uc-sdlc-pr-title-matches-diff, cb-classification_using_confidence, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to build the release notes?" Also: "our changelog is 200 commits
of 'chore: bump deps' and three things users care about", "which merged PRs belong in the
customer-facing notes?", "can we bucket the release by audience automatically?".

## Verdict

**Good**, with one boundary drawn hard: **jev decides which bucket, an LLM or a human writes
the sentence**. Generation is failure mode 9 and not a System One task at all. What remains —
"is this worth telling a user about" and "which section" — is a bounded classification over
text you already have, run once per merged PR at release time, with an obvious low-confidence
path (the "review these" pile the release manager already keeps). This is distinct from
commit-type classification, which infers a `feat`/`fix` prefix; here the taxonomy is your
*audience*, and the load-bearing question is the yes/no about whether to mention it at all.
**Advisory first, gate later:** produce a draft grouping for a few releases before anything
publishes unattended.

## What jev decides

State per merged PR: `{title, body_first_paragraph, labels, diff_summary: {paths, public_api_touched}}`.
One call per PR; all questions in parallel.

```
worth_a_release_note: Noul
  instructions: {question: "Would a user of this product notice or care about this change?",
                 focus: "Judge user-visible effect, not engineering significance."}
  criteria:
    true:  {what: "Changes what a user can do, see, or must do differently",
            examples: ["Adds a CSV export", "Fixes a crash when the file has no header row"]}
    false: {what: "Internal only: refactors, dependency bumps, CI, tests, formatting",
            not_for: "A dependency bump that fixes a user-visible bug",
            examples: ["Bump eslint to 9.2", "Split the parser into two files"]}

note_section: Choice
  instructions: {question: "Which section of the release notes does this change belong in?"}
  criteria:
    breaking:    {what: "A consumer must change their code, config, or workflow to keep working",
                  not_for: "A deprecation where the old path still works"}
    added:       {what: "New capability that did not exist"}
    fixed:       {what: "Existing behaviour now matches what it was supposed to do"}
    improved:    {what: "Same capability, better: faster, clearer, fewer steps",
                  not_for: "A bug fix"}
    deprecated:  {what: "Something still works but is announced as going away"}
    security:    {what: "Addresses a vulnerability or hardens a security property"}
    none:        {what: "Not for the release notes"}

user_impact: Score
  criteria: ["Niche: affects one uncommon workflow.",
             "Common: most users will meet it.",
             "Headline: the reason to upgrade."]
```

Bands: `worth_a_release_note >= 0.8` and `note_section` `confidence >= 0.85` → place it in the
draft. `0.5-0.8` on either → place it in a "check these" list. Below → leave it out of the
draft but list it, because a silently dropped breaking change is the expensive failure here.
When `note_section` is uncertain, the classification-with-confidence cookbook's coarser-answer
move applies: put it under a generic "Changes" heading rather than guessing `improved`.

Order the section by `user_impact` in code. Do not ask jev to rank the PRs against each other
or to count them — one Score each, sort in code, which is the remedy the jaggedness page
prescribes for counting.

## What stays in code

The release range and tag comparison, semver arithmetic, the version bump, deduplicating
reverts and merge commits, the label and `CHANGELOG` writes, and honouring explicit author
signals: a `release-note: ...` block in the PR body or a `no-changelog` label is a declaration,
not a judgement, and it overrides the model every time. Breaking-change detection from an
API-surface diff is deterministic where you have the tooling — use it, and let the Choice only
*add* a breaking entry, never remove one.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Title, first
paragraph, labels and a diff summary (~1,000 characters) plus three questions with criteria
(~2,200 characters) is about 800 tokens, **≈ $0.000034 per merged PR**. A release of 200 PRs is
**≈ $0.0068**, in 200 parallel calls, well inside the published rate limits. Latency is
irrelevant; this is a batch job at tag time. Accuracy: not published for release-note
bucketing. The nearest published jev measurement on a repository-metadata taxonomy is commit
type at 100 rows, 50.0% against Claude Haiku 4.5's 42.0%
(github.com/wotai-dev/typesafe-jev-tools, 2026-09-18) — which is the reason this design leans
on a binary include/exclude Noul rather than on the eight-way section Choice. Labelled data for
calibration: your own past releases. Every published `CHANGELOG` entry maps back to a PR, and
every PR absent from it is a labelled negative.

## When the verdict flips

- To **weak**, if you enforce a `release-note:` block in the PR template. The author has
  already answered both questions, better than any model can.
- To **no**, if it publishes unattended. A missed breaking change in customer-facing notes is a
  support incident; keep a human on the "check these" list.
- Monorepos where one PR spans several published packages. The question becomes "which
  package's notes", which needs the package graph — compute that in code and ask per package.
- Releases with fewer than about twenty PRs, where the release manager reads all of them
  anyway.

## Alternatives considered

- **Conventional-commit prefixes + `semantic-release`.** The standard answer and the right one
  if you enforce prefixes. Free, deterministic, auditable.
- **Label-driven changelog generators** (`release-drafter` with label mappings). Exact, and
  only as good as the labels; pairs naturally with the label-suggestion entry.
- **Frontier LLM.** Writes the actual sentence, which is the part jev cannot do. The productive
  split is jev for the include/exclude and section decisions, the LLM for prose on the
  shortlist it produced — which also cuts the LLM's input to the PRs that matter.
- **Small LLM.** Same decisions, higher latency; at 200 PRs per release the cost difference is
  pennies either way. A small LLM that exposes logprobs can implement the same below-threshold
  "unsure" policy, so the reason to prefer jev is the typed output and a probability trained to
  be calibrated, not an exclusive ability to be unsure.
- **Fine-tuned classifier on past changelog membership.** Genuinely good for a long-lived
  project, and it learns your editorial taste rather than a generic one.
- **Embeddings.** No notion of "worth telling a user about".
- **Release manager reading every PR.** The incumbent. This shrinks the reading list; it does
  not replace the editor.

## Sources

Accessed 2026-09-19. `patterns/fan-out.md`, `primitives/choice.md`,
`cookbooks/classification_using_confidence.md`, `model-jaggedness/jev-1.13.md` (modes 2 and 9),
`models.md`. Field report: https://github.com/wotai-dev/typesafe-jev-tools (commit type, 100
rows, Jev 50.0% / Haiku 4.5 42.0%, 468 ms / 695 ms, 2026-09-18).
