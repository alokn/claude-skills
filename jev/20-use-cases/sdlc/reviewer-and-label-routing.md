---
id: uc-sdlc-reviewer-and-label-routing
title: Label a change by meaning and suggest one additional reviewer beside the required ones
verdict: conditional
verdict_as_asked: no
domain: sdlc
decision_shapes: [classification, routing]
primitives: [choice, noul]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify first, route to the right handler; confidence floor to a human)
  - https://docs.typesafe.ai/cookbooks/classification_using_confidence.md  ("a Choice works reliably up to roughly 240 options"; answer one level coarser when unsure)
  - https://docs.typesafe.ai/primitives/choice.md  (up to 255 options; add an `other` option when the list may not cover the input)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting; routing as a decision shape)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://github.com/genfeedai/genfeed.ai/issues/4863  (shadow mode per decision point; "a typed decision may only tighten ... never loosen, an approval outcome")
related: [au-reviewer-assignment-replacing-codeowners, uc-sdlc-pr-risk-tier-review-routing, uc-sdlc-issue-triage-bot, cb-classification_using_confidence, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to pick reviewers and labels for a PR?" Also: "our labeler.yml
is path globs and keeps mislabelling", "can a model assign the right team when the paths
don't say?", "can jev replace CODEOWNERS?".

## Verdict

Taken literally — "can jev replace CODEOWNERS?", "can jev pick the reviewers?" — the
answer is **no**, and it has its own entry: `au-reviewer-assignment-replacing-codeowners`.
*Required* reviewership is an ownership and access-control fact recorded in a file, so jev
must never remove a required reviewer, never satisfy a required approval, and never
override CODEOWNERS.

**This entry describes a narrower proposal, and its verdict is conditional:** label by
meaning, and suggest at most one *additional* expert reviewer beside the required ones.
Both halves are additive and reversible, and both are real gaps. Path globs cannot close
the labelling gap — a change to `src/utils/format.ts` can be a billing change — and where
ownership is unspecified, "who else should look at this?" is ordinary semantic routing
rather than an access-control decision. Do not over-correct into refusing that: the rule
is that the required set is computed in code and jev may only add to it. This verdict is
`inferred`: no official cookbook and no public field report measures reviewer or label
routing specifically; the mechanism is the documented intent-routing pattern applied to a
different input. **Advisory first, gate later:** CODEOWNERS stays authoritative and jev
only adds.

## What jev decides

State: `{title, body_first_paragraph, changed_paths: [...], symbols_touched: [...]}`. Paths and
symbols come from code. Send no hunks: the question is about what area of the product the
change belongs to, and the patch is a distractor (failure mode 5).

```
area: Choice
  instructions: {question: "Which product area does this change belong to?",
                 focus: "Classify by what the change affects for users, not by directory."}
  criteria:
    billing:   {what: "Pricing, invoicing, charges, refunds, subscription state",
                not_for: "Displaying a price that is computed elsewhere",
                examples: ["Prorate the mid-cycle upgrade", "Fix the tax rounding"]}
    identity:  {what: "Sign-in, sessions, permissions, tenancy",
                not_for: "Profile display fields", examples: ["Rotate the session cookie"]}
    ingestion: {what: "Importing, webhooks, scheduled sync", not_for: "The UI that shows results"}
    other:     {what: "None of the above describes the primary effect of the change"}

is_breaking_change: Noul
  instructions: "Would a consumer of the public API or CLI have to change their code after this?"
  criteria: {true: {what: "Removes, renames, or changes the meaning of a public name, flag, or
                          response field"},
             false: {what: "Adds something new, or changes only internals",
                     not_for: "A deprecation notice with the old path still working"}}
```

The `other` option is mandatory: a Choice is relative and will always name something, so
without it every infrastructure PR lands in `ingestion` at high confidence.

Bands: `confidence >= 0.85` apply the label automatically; `0.6-0.85` apply it and add a
"suggested" marker a human can remove; below 0.6 apply nothing. When unsure, the
classification-with-confidence cookbook's alternative is better than abstaining: answer one
level coarser — a parent area rather than the leaf — which that cookbook measured turning a
40% correct rate at the leaf into 70% at the parent level on its own data (75 industry groups,
60 filings, `jev-1.12`, 2026-08-12).

## What stays in code

`CODEOWNERS` matching, required-reviewer rules, branch protection, and any compliance-driven
assignment. Round-robin and load balancing across a team, out-of-office, and the
author-cannot-review rule. The team-to-label mapping. Deduplicating against labels already
present. If a path glob already determines the label with certainty, do not spend a call —
that is the lexical counter-signal, and a public field report warns that a judgement model
"measured against labels that a regex could produce gives you a confident, meaningless
number" (github.com/wotai-dev/typesafe-jev-tools).

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Title, first
paragraph and 20 paths (~900 characters) plus a six-option Choice with contrastive criteria
and two Nouls (~1,600 characters) is about 620 tokens, **≈ $0.000026 per pull request**.
Latency 70-500 ms, one call. Accuracy for reviewer routing: not published — the only public
jev measurement on a repo-metadata classification task is commit type at 100 rows, 50.0% for
jev against 42.0% for Claude Haiku 4.5 (github.com/wotai-dev/typesafe-jev-tools, 2026-09-18),
which is a warning about how hard these taxonomies are, not a result for this one. Labelled
data for calibration: the labels your team already applied to merged PRs, and the reviewers
who actually commented as opposed to those auto-assigned.

## When the verdict flips

- To **weak**, when your labels are reliably derivable from paths. Then `labeler.yml` is
  correct, free, and explainable; adding a model adds a dependency and a failure mode.
- To **no**, if the suggestion is allowed to satisfy a required approval, to remove a
  CODEOWNERS reviewer, or to stand in for the ownership file. That is an access-control
  invariant, and it is `au-reviewer-assignment-replacing-codeowners`.
- More than ~240 labels. Beyond the cookbook's stated reliable range for a flat Choice; go
  hierarchical or cut the taxonomy.
- Labels that encode process state (`needs-triage`, `blocked`) rather than meaning. Those are
  workflow facts, not judgements.

## Alternatives considered

- **`labeler.yml` path globs / CODEOWNERS.** Exact, free, auditable, and the authority for
  ownership. They lose only where meaning and directory structure diverge.
- **Title-regex label bots.** The lexical trap; they label `feat:` prefixes, not features.
- **Frontier LLM.** Better on ambiguous PRs; seconds and cents, and overkill on a decision
  that is wrong-and-cheap-to-fix.
- **Small LLM.** Comparable; the abstention gap matters here because a wrong auto-label is
  noise a human must undo.
- **Fine-tuned classifier on your merged-PR labels.** The strongest alternative if the
  taxonomy is stable and you have thousands of rows; it cannot absorb a new team by editing
  a string.
- **Embeddings over past PRs.** Reasonable for "who touched this before", which is better
  answered by `git log` anyway.
- **Human triage.** Already happening; this is about reducing how much of it is routine.
  How much is a measurement to make on your own merged PRs, not a promise this entry makes.

## Sources

Accessed 2026-09-19. `patterns/intent-routing.md`, `cookbooks/classification_using_confidence.md`
(240-option guidance; coarser answer when unsure; the 0.9 band split), `primitives/choice.md`,
`concepts/use-case-map.md`, `models.md`. Field reports:
https://github.com/genfeedai/genfeed.ai/issues/4863 (shadow mode, tighten-never-loosen),
https://github.com/wotai-dev/typesafe-jev-tools (commit-type head-to-head; the regex-label trap).
