---
id: au-unpinned-upstream-skill-fetch
title: Do not let an agent fetch jev's instructions from an unpinned upstream branch
verdict: no
domain: sdlc
decision_shapes: [verification, detection]
primitives: [choice, noul]
evidence_level: community-report
sources:
  - https://github.com/jon-devlapaz/jev-me/issues/7  (official skill instructs agents to fetch an unpinned main-branch SKILL.md before the first call)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure mode 6, adversarial content can move the answer)
  - https://docs.typesafe.ai/agent-skill.md  (the agent skill and how it is loaded)
related: [au-sole-security-gate, au-confidence-as-correctness-gate, au-open-ended-agent-loop, au-expect-fine-tuning-from-feedback]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to install the official jev agent skill as documented?" Also "our agent downloads
SKILL.md at runtime, is that fine?", "should we vendor the skill file?", "what's the supply-chain risk of
a decision model?".

## Verdict

**No** as shipped, if the fetch is unpinned. `jon-devlapaz/jev-me#7` flags that the official skill
instructs agents to fetch an unpinned `main`-branch `SKILL.md` from `typesafe-ai/skills` before the first
call. That is a remote file, resolved at runtime, whose contents become instructions inside an agent that
holds your credentials and tools. Whoever can change that branch — the vendor on a bad day, a compromised
maintainer account, or anyone who can intercept the fetch — changes your agent's behaviour without a
deploy, a review or a diff. The decision model itself is not the risk here; the loader is.

## What jev would get wrong

Nothing it evaluates. The failure is upstream of any question: the text that tells the agent how to call
jev is also text the agent obeys. Jaggedness mode 6 is the model-level version of the same property —
"State is data, and `jev-1.13` does not treat it as hostile by default" — and an unpinned instruction file
is that property lifted to the orchestration layer, where the blast radius includes tool calls and
secrets rather than a single label. The tell-tale is that nothing looks wrong: the integration works, the
answers are well-typed, and the only evidence of a swap is in a file nobody re-reads.

## What stays in code

The pin and the review. Vendor the skill file into your repository at a specific commit SHA, review it
like any dependency, and update it deliberately through a pull request that shows the diff. If a runtime
fetch is unavoidable, pin the tag or SHA, verify a checksum, and fail closed when verification fails.
Apply the same discipline to the model identifier: pin `jev-1.13.0` rather than `jev-latest`, because
"an alias moves when a new release ships, so the answers behind it can change without a change on your
side" — the same class of silent upgrade, one layer down. Keep the agent's credentials scoped so that a
compromised instruction file cannot reach anything irreversible.

## Numbers

One reported instance, no exploit observed: `jon-devlapaz/jev-me#7`, filed 2026-09-19, four days after
launch (https://github.com/jon-devlapaz/jev-me/issues/7). Cost of the mitigation: one file vendored and a
version string pinned — no API cost, no latency. Cost of the exposure: unbounded, and not quantifiable
from any published source. This is the one entry in this section where the honest evidence level is a
single community report; the reason to act on it anyway is that the fix is free.

## When the verdict flips

It flips to **good** the moment the fetch is pinned and reviewed: a vendored `SKILL.md` at a known SHA, a
pinned `jev-1.13.0`, a checksum check if fetched at runtime, and an upgrade path that goes through code
review. It also flips if TypeSafe publishes versioned, immutable skill releases — re-verify, since this
entry is pinned to 2026-09-19 and the ecosystem is days old.

## Alternatives considered

- **Regex / deterministic**: not applicable; this is a packaging decision, not a modelling one.
- **Small LLM / frontier LLM**: the same loader pattern is common across agent ecosystems; pin those too.
- **Fine-tuned classifier**: a local model has no runtime instruction fetch, which is one fewer moving
  part.
- **Embeddings**: not applicable.
- **Human**: the pull-request reviewer who sees the diff before it reaches the agent — which is the whole
  control.

## Sources

- https://github.com/jon-devlapaz/jev-me/issues/7 — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/agent-skill.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
