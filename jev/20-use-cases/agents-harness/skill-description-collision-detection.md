---
id: uc-agents-harness-skill-description-collision-detection
title: Detect colliding skill or tool descriptions in a catalog before an agent has to choose between them
verdict: good
domain: agents-harness
decision_shapes: [detection, classification, verification]
primitives: [noul]
evidence_level: community-report
sources:
  - https://github.com/bestdan/workflow-skills/pull/757  (skill-description collision detection: "zero collisions across 22+ runs over 16 descriptions"; also confidence swing 0.16-0.48 between runs)
  - https://empryo.com/blog/jev-and-the-harness  (skill suggestion over 136 installed skills shipped; the runtime decision this check protects)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 5 context rot; mode 1 relative comparison)
related: [uc-agents-harness-skill-or-tool-selection, uc-sdlc-semantic-lint-team-conventions, uc-sdlc-duplicate-review-comment-detection, uc-verification-contradiction-between-records, au-flat-choice-over-255-options]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to find overlapping skill descriptions?" Also: "our agent keeps
picking the wrong tool — are two of our descriptions saying the same thing?", "can CI tell me
when a new skill collides with an existing one?", "how do we keep a growing tool catalog
selectable?"

## Verdict

**Good.** This is a bounded pairwise judgement over short, self-contained text, run at build
time where latency does not matter and a false positive costs a human thirty seconds. A public
assessment implemented it and reported **"zero collisions across 22+ runs over 16
descriptions"** (github.com/bestdan/workflow-skills/pull/757).

Be precise about what that result is. It is a **stability** result on a catalog that had no
known collisions: the check did not fire, repeatedly. It is **not** a measured detection rate,
because no true positives were exercised — nothing tells you what it does when two descriptions
really do overlap. Before you trust it, plant two deliberately colliding descriptions in a
fixture and confirm it fires on those.

The reason to run it at all is downstream: skill selection is a shipped, working jev use case
over catalogs as large as 136 skills (empryo.com/blog/jev-and-the-harness), and a collision is
precisely the input that degrades it. This check protects that decision at the point where the
fix is cheap — the pull request that adds the skill.

## What jev decides

State is two descriptions, nothing else: `{"description_a": ..., "description_b": ...}`. Names
excluded on purpose; if the names disambiguate but the descriptions do not, the agent still has
a problem.

```
would_confuse_selector: Noul
  instructions: {question: "Reading only these two descriptions, could a caller be unable to
                            tell which one to use for some task?",
                 focus: "Overlap in the triggering situation, not similarity of wording."}
  true:  "There is a plausible task for which both descriptions read as the correct choice."
  false: "Every task that fits one clearly does not fit the other, even if they share
          vocabulary or operate on the same objects."

overlap_kind: Choice
  criteria:
    same_trigger:      {what: "Both claim the same situation"}
    subset:            {what: "One is a special case of the other and does not say so"}
    vague_one_side:    {what: "One is so broad it swallows the other"}
    none:              {what: "No overlap"}
```

`overlap_kind` tells the author what to fix, which is the difference between a useful CI
failure and an annoying one. Bands: fail the check only above a threshold fitted on your own
planted-collision fixture; below it, comment on the pull request and move on.

Closest jaggedness mode: **1, relative comparison**. A Choice over "which is better" would be
relative and meaningless; asking an absolute yes/no about one *pair* keeps every judgement
independent, which is also what makes the O(n^2) fan-out parallelisable.

## What stays in code

Pair enumeration — `n*(n-1)/2`, arithmetic, not a question. Caching by content hash so only
pairs touching a changed description are re-run. Exact-duplicate and near-duplicate detection
(normalised string equality, shingle overlap) *before* the call: identical text needs no model.
The threshold, the CI exit code, the allowlist of pairs a human has already ruled acceptable,
and the report grouping results by the new skill.

## Numbers

From github.com/bestdan/workflow-skills/pull/757: **16 descriptions, 22+ runs, zero collisions
reported.** No precision, recall, or detection rate is published, because no known-colliding
pair was in the set.

Two numbers from the same source bound how much a single run is worth: confidence on the same
item swung **0.16-0.48 between runs**, and elsewhere in the same assessment the model was
"overconfident by 16 points" on a different task. For a check that fires rarely, run the
borderline pairs twice and require both.

Cost method: `input_tokens = chars/4`, `cost = tokens x $0.042 / 1e6`, output free. Two
400-character descriptions plus the question block (~1,100 characters) is about 475 tokens,
**= $0.00002 per pair**. A 16-description catalog is 120 pairs, about **$0.0024 per full
sweep**; a 136-skill catalog is 9,180 pairs, about **$0.18** for a full sweep and about
$0.003 for the incremental check of one new skill against all others. Latency is irrelevant
here — this runs in CI, and the pairs fan out in parallel.

## When the verdict flips

- **You never test it on a real collision.** Then the only evidence is that it stays quiet, and
  a check that only ever passes is not a check.
- **The catalog is large and fully swept on every commit.** O(n^2) grows fast; at a few thousand
  descriptions, incremental checking is mandatory and a cheap embedding pre-filter should
  shortlist the pairs worth asking about.
- **You make it a blocking gate.** A shipped rule from a related assessment is "never blocking,
  never mandatory" for jev in CI; a false positive that stops a release will get the check
  deleted. Comment, do not block.
- **Descriptions are templated or auto-generated.** Then they are similar by construction and
  the check fires on everything.
- **The real problem is a missing skill, not a colliding one.** This detects overlap, not gaps.

## Alternatives considered

- **Embedding cosine similarity between descriptions.** Free, instant, and the right pre-filter.
  It finds descriptions that *sound* alike; it cannot tell a genuine subset relationship from
  two distinct tools that share a domain vocabulary. Use both: embeddings to shortlist, jev to
  judge.
- **Exact and near-duplicate string matching.** Catches copy-paste, which is a real failure
  mode. Free. Run first.
- **A frontier LLM reviewing the whole catalog at once.** Better at spotting a structural
  problem across many skills, and it can explain and propose a rewrite — which jev cannot,
  since generation is out of scope. Slow and expensive per sweep, but a sweep is rare. A good
  pairing: jev flags, the LLM drafts the fix.
- **Measuring the runtime selector directly.** The strongest signal of all — log which skill was
  selected against which should have been, and look for confusion pairs. Requires traffic and
  labels; this check is what you run before you have them.
- **A human reviewing every new skill description.** The incumbent, and it stays for the flagged
  pairs.

## Sources

- https://github.com/bestdan/workflow-skills/pull/757 — accessed 2026-09-19 ("zero collisions
  across 22+ runs over 16 descriptions"; confidence swing 0.16-0.48 between runs; "overconfident
  by 16 points" on a separate task; "never blocking, never mandatory")
- https://empryo.com/blog/jev-and-the-harness — accessed 2026-09-19 (skill suggestion over 136
  installed skills, shipped)
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
