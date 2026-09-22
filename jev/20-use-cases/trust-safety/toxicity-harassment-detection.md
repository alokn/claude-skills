---
id: uc-trust-safety-toxicity-harassment-detection
title: Detect toxicity and harassment against your own written criteria
verdict: good
domain: trust-safety
decision_shapes: [detection, classification, scoring]
primitives: [noul, choice, score]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/consistency_choice_cookbook.md  (an 8-question moderation rubric over one borderline post — category, primary_risk, target, action, queue, link_handling, review_path, severity — run 15 times; 114 ms and $0.000046 per call; 0.60 abstain band lifts decision agreement 90.8% to 99.2% at 25.8% abstention)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (moderation: "Apply company-specific, nuanced criteria to decide which posts meet your moderation standards"; "Detect toxicity, harassment...")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6: state is not treated as hostile by default)
  - https://docs.typesafe.ai/models.md  (English strongest; other languages accepted with lower accuracy)
related: [uc-trust-safety-policy-violation-bands, uc-trust-safety-user-report-triage, uc-support-frustration-scoring]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev for toxicity and harassment detection?" Also "can jev replace
Perspective API / our toxicity classifier?", "can we moderate to our own community
standards rather than a vendor's?", and "can jev decide what to remove?".

## Verdict

**Good** for producing the signals and the triage decision, with the removal itself
staying a policy decision in code — the shape is demonstrated by the choice-consistency
cookbook, which measures repeatability and not correctness; no task-matched labelled
accuracy is published; shadow-evaluate against the incumbent before acting. The pull is
not accuracy — it is that the taxonomy is *yours*. An off-the-shelf toxicity model
scores an abstract notion of toxicity and cannot be told that in your community, blunt
technical criticism is fine and any comment about someone's employer is not. Jev's
criteria are strings you edit. The choice-consistency cookbook runs a close variant of
this rubric — eight moderation Choices over one borderline post — and publishes the
properties that matter for moderation: 114 ms per call, $0.000046 per call, 0% parse
failures, and a designed uncertain band.

## What jev decides

State: the post text, plus only the context your criteria actually reference — the parent
comment if the criteria mention replies, the community's stated norms if they differ per
space. Author history is a separate signal; keep it in code (see below).

```
harassment_directed_at_person: Noul
  instructions: "Does `post.text` attack, demean, or threaten a specific identifiable person?"
  criteria:
    true:  {what: "Targets an individual, named or clearly identified, with insult or threat"}
    false: {what: "No individual target",
            not_for: "Criticism of an argument, a product, or a public policy"}

slur_or_identity_attack: Noul
  instructions: "Does `post.text` demean a person or group on the basis of a protected
                 characteristic such as race, religion, gender, disability, or nationality?"

credible_threat: Noul
  instructions: "Does `post.text` express intent to cause physical harm to a person or group?"
  criteria:
    true:  {what: "States or implies the author or someone else will inflict physical harm"}
    false: {what: "No such intent",
            not_for: "Hyperbole with no target, quoted violence, or fiction"}

sexual_content_involving_minor: Noul
  instructions: "Does `post.text` sexualise a person described or implied to be under 18?"

severity: Score
  criteria: ["Nothing a reasonable member would report",
             "Rude or hostile but within robust discussion",
             "Personal attack, sustained hostility, or targeted pile-on",
             "Threat, identity-based attack, or content that endangers someone"]

action: Choice
  criteria: {allow: "...", warn: "...", remove: "...", strike: "...", escalate: "..."}
```

Multi-label means one Noul per label, not a Choice — the primer's rule, and the reason the
distinct harms above are separate questions. The `action` Choice exists so the whole triage
is one call, but code is free to override it from the Nouls: a `credible_threat` above 0.5
escalates regardless of what `action` says.

Bands: the cookbook's illustrative rule is a top-probability gate at `0.60` over the
returned distribution, with everything below routed to `uncertain`, and it explicitly warns
that this is "an illustrative application policy, not a calibrated guarantee". Choose yours
from labelled examples and the cost of a wrong removal versus a review.

## What stays in code

Removal, striking, and banning. Author history, strike counts, account age and report counts
are structured data and belong in the rule that combines them — the cookbook's own post
carries `prior_strikes: 1` and `user_reports: 4` as state, but counting and comparing them is
arithmetic (failure mode 2). Appeals, audit logs, and legal-hold paths are code. Deterministic
blocklists for the unambiguous cases stay: they are exact, free, and instant.

## Numbers

Measured, from the cookbook (one post, 8 Choice questions, 15 repeats, `jev-latest` resolving
to `jev-1.13.0`, sampled 2026-09-11): **114 ms** mean round trip and **$0.000046** per call,
against 826 ms to 13.0 s and $0.00094 to $0.041 for the six LLM conditions. Mean probability
standard deviation 0.0098 for jev; the LLM probability conditions ranged 0.0245–0.0543, except
`claude-haiku-4-5` at temperature 0 which was *more* stable at 0.0012. Applying the 0.60
abstain rule took jev's decision agreement from 90.8% to 99.2%, with 25.8% of answers
uncertain and 74.2% automatic, and produced zero conflicting concrete labels across the 15
repeats. Method for your own estimate: `(chars(state) + chars(questions)) / 4 × $0.042/1e6`.
**Accuracy is not measured anywhere in that cookbook** — its own annotation reads "100%
repeatability does not imply correctness. This experiment does not measure accuracy." Treat
these as stability and cost numbers only.

## When the verdict flips

- Jev is the sole gate on content reaching users at scale, with no human review band and no
  deterministic layer. Failure mode 6 — state is not treated as hostile by default, and
  content written to argue for its own classification can move the answer.
- Your community is largely non-English or relies on evolving coded language. English is the
  strongest language; run a per-locale evaluation before trusting it, and expect coded terms to
  need explicit criteria.
- Images, video, or audio carry the harm. Text only.
- A regulator requires a documented deterministic rule. Then the rule is authoritative and jev
  is a second opinion.

## Alternatives considered

- **Perspective-style toxicity API / open toxicity classifier.** Cheap, fast, and locked to
  someone else's definition; no per-community criteria, and its score is on a scale you did
  not set, so any threshold policy has to be refitted to it.
- **Slur and keyword lists.** Keep them for the unambiguous cases. They cannot read context,
  reclamation, or quotation.
- **Frontier LLM moderator.** Best nuance, worst economics at moderation volume, and the
  consistency cookbook measured reasoning models at 10.4–13.0 s per rubric call.
- **Small LLM.** Genuinely competitive on this rubric — and on this single post Haiku at
  temperature 0 was the most repeatable condition. The case for jev is cost, latency, the
  typed output with 0% parse failures, and the middle band you can route on, not accuracy.
- **Fine-tuned classifier on your moderation log.** Strong if you have the labels; a new
  policy means a retrain, where jev means an edited sentence.
- **Human moderation of everything.** What the 25.8% uncertain band preserves.

## Sources

Accessed 2026-09-19. `cookbooks/consistency_choice_cookbook.md` (rubric, latency, cost,
std dev, agreement, abstention; sampled 2026-09-11; accuracy explicitly not measured),
`concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md`, `models.md`.
