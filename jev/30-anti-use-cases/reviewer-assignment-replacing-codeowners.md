---
id: au-reviewer-assignment-replacing-codeowners
title: Do not let jev pick the required reviewers or stand in for CODEOWNERS
verdict: no
domain: sdlc
decision_shapes: [routing, classification]
primitives: [choice, noul]
evidence_level: inferred
sources:
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify first, route to the right handler; confidence floor to a human)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6, adversarial content; state is data, not treated as hostile by default)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
  - https://github.com/genfeedai/genfeed.ai/issues/4863  (shadow mode per decision point; "a typed decision may only tighten ... never loosen, an approval outcome")
  - https://github.com/wotai-dev/typesafe-jev-tools  (commit type over 100 rows: jev 50.0% vs Claude Haiku 4.5 42.0%; the regex-label trap)
related: [uc-sdlc-reviewer-and-label-routing, au-payments-and-access-control-decision, au-sole-security-gate, uc-sdlc-pr-risk-tier-review-routing]
last_verified: 2026-09-20
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to pick the reviewers for a PR?" Also: "can jev replace
CODEOWNERS?", "can the model decide who has to approve this?", "can it drop a reviewer the
change doesn't really need?".

**This entry is `inferred`.** No cookbook and no public field report measures reviewer
selection. The objection is structural, not empirical.

## Verdict

**No**, for *required* reviewership. Who must approve a change is an ownership and
access-control fact recorded in a file, not a judgement over text, so there is nothing for a
typed decision to add and a great deal for it to break: jev must never remove a required
reviewer, never satisfy a required approval, and never override CODEOWNERS. A field report
from a public evaluation states the rule in general form — a typed decision "may only
tighten ... never loosen, an approval outcome" (genfeedai issue 4863).

This is narrower than "jev cannot help with reviewers". Suggesting an *additional* expert
beside the required approvers, where ownership is unspecified and the suggestion is
advisory and reversible, is a legitimate semantic routing problem with a different verdict:
see `uc-sdlc-reviewer-and-label-routing` (`conditional`), which also covers labelling by
meaning.

## What jev would get wrong

The premise, mostly. CODEOWNERS is exact, versioned and already correct; a model asked the
same question can only agree or be wrong, and its wrong answers are invisible because a
plausible reviewer name looks like a right one. The costly case is the intersection with
access control: an approval requirement exists because someone decided a human with context
must look, and a probability is not a person. Failure mode 6 compounds it — the PR title and
body are written by the author, who benefits from lenient routing, and state "is data, and
`jev-1.13` does not treat it as hostile by default". A branch-protection rule cannot be talked
out of itself; a question can. Load balancing, out-of-office and the author-cannot-review rule
are the other half of real reviewer assignment, and all three are arithmetic and lookups.

## What stays in code

`CODEOWNERS` matching, required-reviewer rules, branch protection, compliance-driven
assignment, round-robin and load balancing, out-of-office, the author-cannot-review rule,
and the team-to-label mapping. If a path glob already determines the owner, do not spend a
call: a judgement model "measured against labels that a regex could produce gives you a
confident, meaningless number" (wotai-dev/typesafe-jev-tools).

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. Title, first
paragraph and 20 paths plus a Choice with contrastive criteria and two Nouls is about
620 tokens, ≈ **$0.000026 per pull request**, 70-500 ms, one call. **Accuracy for reviewer
routing: not published.** The only public jev measurement on a repo-metadata classification
task is commit type at 100 rows, 50.0% for jev against 42.0% for Claude Haiku 4.5
(wotai-dev/typesafe-jev-tools, 2026-09-18) — a warning about how hard these taxonomies are,
not a result for this one.

## When the verdict flips

- To **conditional** when the suggestion is strictly additive: CODEOWNERS approvals remain
  mandatory and unmodified, and jev proposes one *extra* reviewer a human may ignore. That is
  the proposal in `uc-sdlc-reviewer-and-label-routing`.
- To **conditional** for labels rather than people, where path globs and directory structure
  genuinely diverge from meaning — same entry.
- It does not flip while the output can satisfy, remove or weaken a required approval.

## Alternatives considered

- **CODEOWNERS / `labeler.yml` path globs.** Exact, free, auditable, authoritative for ownership.
- **`git log` / blame.** The honest answer to "who knows this code", with no model.
- **Review-load bots.** Solve the scheduling half deterministically.
- **Frontier LLM.** Better at reading an ambiguous diff, equally unable to hold an access rule.
- **Human tech lead.** The fallback when ownership is unclear; the right place to fix CODEOWNERS.

## Sources

- https://docs.typesafe.ai/patterns/intent-routing.md — accessed 2026-09-20
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-20
- https://docs.typesafe.ai/models.md — accessed 2026-09-20
- https://github.com/genfeedai/genfeed.ai/issues/4863 — accessed 2026-09-20
- https://github.com/wotai-dev/typesafe-jev-tools — accessed 2026-09-20 (commit type 50.0% vs 42.0%, 2026-09-18)
