---
id: uc-agents-harness-skill-or-tool-selection
title: Suggest at most one skill or tool for an agent turn, with the option to suggest none
verdict: strong
domain: agents-harness
decision_shapes: [ranking, routing, classification, detection]
primitives: [choice, noul]
evidence_level: official-cookbook
sources:
  - https://docs.typesafe.ai/cookbooks/skill_suggestion.md  (182-skill roster, 488 requests; 16.8% -> 7.3% wrong loads, 9.8% -> 4.0% needless)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (Choice is relative, Noul is absolute — both used on the same shortlist)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Harness Engineering)
related: [uc-agents-harness-function-call-argument-filling, uc-search-retrieval-document-answers-query-gate, au-context-compaction-by-relevance-scoring]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to pick which skill or tool the agent should load?" Also: "our
agent has 180 tools and picks the wrong one", "can jev decide that no tool is needed?", "how
do we cut tool-definition tokens without losing coverage?"

## Verdict

**Strong.** This is a measured cookbook result on a real roster, and it is the clearest
illustration of the Choice/Noul split: a Choice always produces a winner, so an independent
Noul gate is what lets the system stay silent. Two conditions the cookbook insists on: the
suggestion must stay **advisory** — "A confident wrong suggestion is more persuasive than no
suggestion at all" — and stage two "can only reject what the wide ranking hands it".

## What jev decides

State is the same two keys for both requests: `{"request": request, "recent_context": ""}`.

**Request 1, rank wide.** One Choice over the whole roster (`{name: short_description}`, 182
options) — "Which of these skills, if any, is the right one to load to help with the user's
latest request?" — plus three gate Nouls that ask about the *request*, not the subject matter:

- `acts_on_user_system`: "Is the assistant being asked to act on the user's files, accounts,
  devices, or online services, rather than only to explain or advise?"
- `would_follow_documented_procedure`: "Would a careful expert answering this consult a specific
  documented procedure or set of commands, rather than answering from general understanding?"
- `prose_suffices`: "Could a knowledgeable generalist fully satisfy this request in prose, with
  no tools, no documentation, and no access to the user's files or accounts?" (inverted in code)

The reason they are framed that way: "A question about subject matter will not separate
*explain what a monad is* from a request that needs a skill, since both are software."

**Request 2, re-judge the top three** with fuller text (`description_full` plus 700 characters
of the skill body), as a Choice — "Exactly one of these skills is the right one ... Read what
each actually does, not just its name" — plus one `fits::{name}` Noul per candidate.

```python
SHORTLIST, EXCERPT_CHARS, GATE_THRESHOLD, FITS_THRESHOLD = 3, 700, 0.30, 0.30
if wide["gate"] < GATE_THRESHOLD: return ()
if max(result["fits"].values()) < FITS_THRESHOLD: return ()
```

## What stays in code

The roster and its ordering, both thresholds, the shortlist size, the excerpt length, the
empty-result path, and the wording of the injected line — kept deliberately soft: "Relevant to
the current request: {names}. Ignore this if it does not fit what the user actually asked for."
The roster text is left untouched so prefix caching over it still holds.

## Numbers

From `skill_suggestion.md` — 182 skills in 33 categories (roster prompt 16,089 characters, index
descriptions 54 characters on average), 488 single-turn requests (315 covered by exactly one
skill, 173 by none), `jev-1.12` with `claude-haiku-4-5-20251001`, rendered 2026-07-31:

| run | wrong loads | needless loads |
|---|---|---|
| agent alone with its roster | 16.8% | 9.8% |
| agent with a TypeSafe suggestion | 7.3% | 4.0% |
| agent handed the right answer (oracle) | 2.5% | 1.2% |

"baseline -> TypeSafe: 2.3x fewer wrong loads, 2.4x fewer needless ones." Churn: "of 315
covered requests: 37 the suggestion fixed, 7 it broke." Measured latency per demo request:
request 1 (182-way rank) 0.31s / 0.16s / 0.16s; request 2 (rerank 3) 0.12s / 0.09s / 0.09s.
Cost and token totals: **not reported**.

Sample size and label provenance, which is what the `strong` rests on: **n = 488 single-turn
requests** over a 182-skill roster. The requests and their labels are **synthetic, not human**
— they "were written by Claude Sonnet 5 from each skill's own `SKILL.md`, so the labels are
trustworthy and the requests are easier than the ones users send". Correct-by-construction
labels over easier-than-real inputs is a real limitation: expect the measured gap to narrow on
your own traffic, and keep the suggestion advisory.

Closest jaggedness mode: **8, structural invariants** — the Choice and the Nouls are deciding
different things and the cookbook shows them disagreeing correctly.

- Field evidence (community-report): Empryo shipped skill suggestion over 136 installed skills in its agent harness, one of five accepted jobs out of eight tested, 2026-09-16. Source: https://empryo.com/blog/jev-and-the-harness
- Field evidence (community-report): a tool-selection harness measures steps-to-completion with jev picking ahead of the LLM over 100 mocked tools with deliberate distractors and Portuguese prompts; the method is published but the headline numbers are not in the README, 2026-09. Source: https://github.com/vinilana/jev-eval-agent
- Field evidence (community-report): skill and plugin catalogue ranking shipped as a standalone ranker over an installed catalogue; no numbers published, 2026-09. Source: https://github.com/Dicklesworthstone/skillranker

## When the verdict flips

- **The roster is small (under ~15 tools) and all definitions fit in the prompt.** The agent
  picks well already; a router adds latency and a new way to be wrong — **weak**.
- **Tool choice is determined by the input type** (a PDF arrives, run the PDF tool). Keep the
  deterministic dispatch.
- **You let the suggestion decide instead of advise.** It broke 7 requests the agent had right;
  making it authoritative turns those into hard failures.
- **A roster a few times larger than 182.** "you would split it into chunks and rank each one,
  then run this same shortlist step over the winners."
- **The capability is simply missing.** "with a skill for posting to X and nothing for Mastodon
  the closest skill wins anyway" — the `fits` noul cleared 0.30 and the wrong skill was
  suggested. Raise `FITS_THRESHOLD` or accept the miss.

## Alternatives considered

- **Keyword match on tool names and descriptions** — free, and independent evaluations rejected
  jev for keyword-frequency tool prediction; keep it where tool choice is lexical.
- **Embedding nearest-neighbour over tool descriptions** — the common incumbent; it ranks but
  has only a cosine score to threshold (an abstain policy is possible but needs its own
  calibration), and the 54-character index descriptions give it very little to embed.
- **Let the agent read the whole roster** — the measured baseline: 16.8% wrong, 9.8% needless,
  plus 16,089 characters in every prompt.
- **A small LLM router** — a full extra call in the turn's critical path for one selection.
- **Fine-tuned tool classifier** — plausible once you have logged (turn, correct tool) pairs;
  jev is what produces them, and it survives roster edits without retraining.

## Sources

- https://docs.typesafe.ai/cookbooks/skill_suggestion.md — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/use-case-map.md — accessed 2026-09-19
