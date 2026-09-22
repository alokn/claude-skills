---
id: uc-sdlc-pr-risk-tier-review-routing
title: Score a pull request's risk tier to decide how much review it needs
verdict: good
domain: sdlc
decision_shapes: [scoring, routing]
primitives: [score, noul]
evidence_level: official-docs
sources:
  - https://docs.typesafe.ai/patterns/composite-scoring.md  (atomic Scores combined with weights owned by code; normalise each dimension and weight it)
  - https://docs.typesafe.ai/patterns/confidence-routing.md  (per-action thresholds; a floor below which everything goes to a human)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Semantic code linting; Risk assessment: "Score severity and prioritize review")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  ("Math using score": use the expectation to threshold, not to reconstruct a magnitude)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://github.com/2001Y/jev-axi  (`diff` recipe: five questions per changed file — risk, needs a test, adds a secret, debug leftovers, changes behaviour — returning ok / review / block)
related: [uc-sdlc-pr-title-matches-diff, uc-sdlc-reviewer-and-label-routing, uc-sdlc-dependency-alert-triage, df-fit-test, df-rollout]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to decide how risky a PR is?" Also: "can we auto-approve
low-risk PRs and require two reviewers on high-risk ones?", "can a model tell when a change
touches something dangerous that CODEOWNERS globs miss?", "how do we prioritise a review
queue?".

## Verdict

**Good.** Risk tiering is composite scoring — several atomic judgements combined with weights
that code owns — which is a documented TypeSafe pattern, and the use-case map lists "score
severity and prioritize review" directly. One public tool ships almost exactly this shape:
`jev-axi diff` "asks five questions per changed file (risk, needs a test, adds a secret,
debug leftovers, changes behavior) plus scope and kind for the whole diff, and returns `ok`,
`review`, or `block`". No accuracy number is published, hence `good`. **Advisory first, gate
later:** publish the tier as a label for a quarter, then let it *raise* review requirements
only. It must never lower them.

Closest failure mode: **math and counting** — the tier is a weighted combination, so jev
answers atomic per-file questions and code owns the weights, the arithmetic and the mapping to
a review requirement.

## What jev decides

State per changed file: `{path, hunk, file_role: "<source|test|config|migration>"}` — the role
comes from code, not the model. Ask atomic Scores and Nouls, one call per file:

```
blast_radius: Score
  instructions: {question: "If `hunk` is wrong, how far does the damage reach?",
                 focus: "Judge reach, not likelihood."}
  criteria: ["Contained: one screen, one internal helper, or a test.",
             "Feature-wide: one user-visible feature or one service endpoint.",
             "System-wide: shared library, data model, or a path every request takes.",
             "Irreversible: data is deleted, migrated, or written in a form that cannot be undone."]

reversibility: Score
  criteria: ["Undone by reverting the commit.",
             "Undone by reverting plus a config change or cache flush.",
             "Requires a data repair or a customer-facing correction."]

touches_authnz:   Noul  "Does `hunk` change who is allowed to do something?"
touches_money:    Noul  "Does `hunk` change how an amount is calculated, charged, or refunded?"
handles_untrusted: Noul "Does `hunk` parse, render, or execute input that comes from outside the system?"
```

Code combines them: `risk = 0.4*blast/3 + 0.25*rev/2 + 0.15*authnz + 0.1*money + 0.1*untrusted`,
then buckets. Weights live in one module and are tuned without re-inference — the whole point
of the composite-scoring pattern.

Bands: `risk < 0.25` and every `confidence >= 0.7` → label `risk:low`; `0.25-0.6` → `risk:medium`;
above → `risk:high`, request the second reviewer. Any `confidence < 0.5` on any dimension →
treat as medium, never as low. Use the Score expectation to threshold and rank only; the
jaggedness page is explicit that score levels "are weak in numerical calibration" and you must
not interpolate a magnitude between them.

## What stays in code

Path globs for migrations, IaC, `CODEOWNERS`-covered directories, release branches and anything
your compliance regime already treats as high risk — these are lexical, exact, and they stay
authoritative. A deterministic high-risk match short-circuits before any call. Also in code:
diff size, number of files, whether tests exist for the touched module, the weights, the
bucket boundaries, and the branch-protection change itself. A public PRD for the same pattern
states the invariant plainly: a typed decision "may only tighten (e.g. force review), never
loosen, an approval outcome" (github.com/genfeedai/genfeed.ai/issues/4863).

## Numbers

Method: `input_tokens ≈ chars/4`, `cost = tokens × $0.042 / 1e6`, output free. A 2,000-character
file hunk plus five questions with criteria (~1,800 characters) is about 950 tokens, **≈
$0.00004 per changed file**; a 10-file PR is **≈ $0.0004**. Latency 70-500 ms per file, files
in parallel. Accuracy: not published for this task. Labelled data for calibration: your
incident history — PRs implicated in a postmortem, PRs reverted within 48 hours, and PRs that
required a hotfix are the positive class; plot `risk` against it and set the bucket boundaries
where the curve bends, not where they look tidy.

- Field evidence (community-report): a CI PR-triage job batches one Choice (ready / needs_human / broken) and a Noul into a single call and fails the build only when readiness is broken AND confidence or high_risk is >=0.8; the step is skipped when the API key is absent so forks stay green, 2026-09. Source: https://github.com/learn-ukrainian/learn-ukrainian.github.io/issues/8232
- Field evidence (community-report): a standalone PR risk-routing tool scores the diff before review to decide how much review it needs; no numbers published, 2026-09. Source: https://github.com/raihankhan-rk/diffjury

## When the verdict flips

- Your risk policy is already a correct path glob (`migrations/**` always gets a DBA). Do not
  replace working determinism with judgement; add jev only for the long tail outside the globs.
- You want the low band to auto-approve and auto-merge. That is a safety gate with a
  probabilistic input; the deterministic policy must remain the gate.
- Very large PRs where per-file scoring produces dozens of medium signals and the aggregate
  means nothing. Cap the file count and fall back to "needs human triage".
- A regulated change-control regime that requires a named human approver regardless.

## Alternatives considered

- **Path globs / CODEOWNERS / diff-size heuristics.** Cheap, exact, and they already catch most
  of it. They cannot see that a three-line change removed a permission check. Keep them.
- **Frontier LLM reviewer.** Reads the code properly and finds actual bugs, which jev cannot;
  seconds and cents per file. The right consumer of the high-risk band, not a replacement
  for it.
- **Small LLM.** Same questions, ~1.4x-3.7x the latency in the public head-to-head, and far
  less willing to say it is unsure (2.7% vs 34.7% of rows in one 150-row run), which is
  exactly the property a risk tier needs.
- **Fine-tuned classifier on incident history.** Genuinely competitive if you have hundreds of
  labelled incidents; it also cannot be re-weighted by editing a string.
- **Static analysis / CodeQL.** Better at the specific vulnerability classes it models; blind
  to "this changes billing".
- **Human triage.** Stays for the high band. That is the product.

## Sources

Accessed 2026-09-19. `patterns/composite-scoring.md`, `patterns/confidence-routing.md`,
`concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md` ("Math using score"), `models.md`.
Field reports: https://github.com/2001Y/jev-axi (five questions per changed file, ok/review/block),
https://github.com/genfeedai/genfeed.ai/issues/4863 (tighten-never-loosen invariant; shadow mode;
default threshold 0.85).
