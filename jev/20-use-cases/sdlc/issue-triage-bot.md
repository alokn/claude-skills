---
id: uc-sdlc-issue-triage-bot
title: Triage a new issue into bug, feature request, question, or duplicate on creation
verdict: good
domain: sdlc
decision_shapes: [classification, routing, detection]
primitives: [choice, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/fan-out.md  (ticket triage as the canonical fan-out example: category Choice plus speculative Nouls and Scores in one call)
  - https://docs.typesafe.ai/patterns/intent-routing.md  (classify intent and complexity, then route to code, a specialist model, or a human)
  - https://docs.typesafe.ai/primitives/choice.md  (Choice is relative and always names an option; add `other`)
  - https://docs.typesafe.ai/cookbooks/rerank_typesafe.md  (code shortlists candidates, one question per (query, candidate) pair)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; 70-500 ms)
related: [uc-sdlc-issue-needs-repro, uc-sdlc-reviewer-and-label-routing, uc-support-ticket-team-routing, cb-rerank_typesafe, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to triage incoming GitHub issues?" Also: "can a bot label new
issues bug / feature / question?", "can it spot that this is a duplicate of an open issue?",
"can we stop maintainers reading every drive-by report?".

## Verdict

**Good.** Issue intake is the support-ticket triage shape the docs use to teach the model,
pointed at a different queue: one short free-text item, a small closed set of destinations,
a confidence value, and an existing human queue for the uncertain band. The fan-out pattern
page uses exactly this decomposition. It is `good` rather than `strong` because the official
worked example is a support ticket, not a repository issue, and no public measurement exists
for an issue taxonomy. **Advisory first, gate later:** post labels as suggestions a maintainer
can accept for a few hundred issues, then auto-apply only the band that agreed.

## What jev decides

State: `{issue: {title, body}, template_fields: {...}}` — nothing else. Not the repository
README, not the comment thread (there is none yet).

```
issue_kind: Choice
  instructions: {question: "What is `issue.body` asking for?",
                 focus: "Classify the author's request, not the subject area."}
  criteria:
    bug:      {what: "Reports that existing behaviour is wrong or broken",
               not_for: "Asking how to do something that was never supported",
               examples: ["Export writes an empty file when the name has a comma"]}
    feature:  {what: "Asks for capability that does not exist",
               not_for: "Asking for a bug to be fixed faster",
               examples: ["Please add a --json flag"]}
    question: {what: "Asks how to use the project, or why it behaves as documented",
               not_for: "A bug report phrased politely as a question",
               examples: ["How do I configure the cache directory?"]}
    docs:     {what: "Reports that the documentation is missing, wrong, or unclear"}
    other:    {what: "None of the above: an announcement, a thank-you, spam, an empty issue"}

is_actionable_as_written: Noul
  instructions: "Could a maintainer begin work from `issue.body` without asking the author anything?"
mentions_version:  Noul  "Does `issue.body` state which version of the software was used?"
severity: Score
  criteria: ["Cosmetic; no impact to functionality.",
             "Broken or degraded feature; a workaround exists.",
             "Blocking; no workaround exists.",
             "Data loss or a security concern."]
```

Duplicate detection is a *second* shape and must not be a Choice over all open issues. Code
shortlists 20-30 candidates with the search you already have, then asks one Noul per
candidate — "Do `issue` and `candidate` describe the same underlying problem, as opposed to
the same symptom from different causes?" — in a single call. This is the rerank cookbook's
structure: code retrieves, jev judges each pair.

Bands: `confidence >= 0.85` apply the label; `0.6-0.85` apply it with a "suggested" marker;
below that apply `needs-triage` only. Duplicates: `noul >= 0.85` post a link as a comment;
never close an issue automatically.

## What stays in code

Template field parsing (the author ticked a radio button; that is the answer), spam and rate
limiting, first-time-contributor detection, the search that produces duplicate candidates,
the label write, and the close/lock actions. Version-string extraction and comparison — a
version is a semver comparison, which is arithmetic, and the jaggedness page is explicit that
this belongs in code; the Noul only detects whether a version was *mentioned*.

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A
1,500-character issue plus a five-option Choice with criteria and three companion questions
(~1,900 characters) is about 850 tokens, **≈ $0.000036 per issue**. Duplicate detection adds
one call with 25 candidate titles and one-line summaries (~3,000 characters) plus 25 short
questions (~2,500 characters), about 1,400 tokens, **≈ $0.000059 per issue**. Latency 70-500
ms per call, both calls in parallel with issue creation. Accuracy: not published for this
taxonomy. Labelled data for calibration: your own closed issues — the labels maintainers
applied, and the `duplicate` closures with their linked target, which is a ready-made
positive set for the pair question.

## When the verdict flips

- The issue template already forces the author to pick a type from a dropdown. That field is
  the answer; classifying it again is the lexical trap.
- You let the bot close issues. Closing a real bug as a duplicate costs you a contributor;
  keep the close deterministic or human.
- Very low issue volume with an attentive maintainer. Nothing is saved.
- Predominantly non-English issues without your own evaluation.

## Alternatives considered

- **Issue templates and forms.** The best answer where they apply: free, exact, and they
  improve the report itself. Use them first; jev handles the issues that ignore them.
- **Title-keyword label bots.** Brittle in the usual way; "crash" appears in feature requests.
- **Frontier LLM.** Better at writing the "can you provide a reproduction?" reply, which jev
  cannot do at all (failure mode 9). Pair them: jev decides, the LLM writes.
- **Small LLM.** Comparable labels; the public 150-row head-to-head put jev and Haiku 4.5 at
  the same accuracy with jev unsure on 34.7% of rows against 2.7%, which for an auto-labeller
  is the difference between a useful `needs-triage` and a confident wrong label.
- **Fine-tuned classifier on your closed issues.** Strong for a repo with tens of thousands
  of labelled issues and a stable taxonomy.
- **Embeddings for duplicates.** Genuinely competitive and cheaper for the retrieval half —
  which is why code should do the retrieval and jev only the judgement on the shortlist.
- **Maintainer triage.** Stays for the low band and every close.

## Sources

Accessed 2026-09-19. `patterns/fan-out.md`, `patterns/intent-routing.md`,
`primitives/choice.md`, `cookbooks/rerank_typesafe.md` (shortlist-then-judge),
`model-jaggedness/jev-1.13.md` (modes 2 and 9), `models.md`. Field report:
https://github.com/wotai-dev/typesafe-jev-tools (abstention rates, 150 passages, 2026-09-18).
