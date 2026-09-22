---
id: cb-skill_suggestion
title: Skill suggestion
url: https://docs.typesafe.ai/cookbooks/skill_suggestion.md
decision_shapes: [ranking, routing, classification, detection]
primitives: [choice, noul]
related: [uc-agents-harness-skill-or-tool-selection, uc-agents-harness-skill-description-collision-detection, uc-support-intent-routing-handlers, uc-search-retrieval-rerank-keyword-shortlist, au-open-ended-agent-loop]
last_verified: 2026-09-19
jev_version: jev-1.13.0
source_model_version: jev-1.12
---

## Task

Pick at most one skill for an agent turn out of a 182-skill roster, using two jev requests
in front of the agent's own decision. Request one ranks every skill and asks whether the
turn needs a skill at all; request two re-reads only the top three with fuller text and may
reject all of them. The winner's name is appended to the system prompt as one line; the
roster itself is unchanged "so any prefix caching over it still holds".

Datasets: `hermes_roster.json`, "the 182 skills of NousResearch/hermes-agent (MIT) at one
pinned commit", each record holding name, category, index description, full description and
the opening of its `SKILL.md`. `requests.json` holds "488 single-turn requests, 315 of them
covered by exactly one skill and the other 173 covered by nothing" (315 covering 171
distinct skills). The covered requests "were written by Claude Sonnet 5 from each skill's
own `SKILL.md`". The 173 uncovered ones are "85 everyday requests, 42 technical questions no
skill serves... and 46 that ask for something specific the roster has no skill for".
Models: `TYPESAFE_MODEL = "jev-1.12"`, agent under test `AGENT_MODEL =
"claude-haiku-4-5-20251001"`. Run date: "The published run used `jev-1.12` and
`claude-haiku-4-5-20251001`, rendered 2026-07-31."

## Decomposition (state, questions, how answers are combined)

State is the same two keys for both requests:

```python
def build_state(request: str) -> dict:
    return {"request": request, "recent_context": ""}
```

**Request 1 (`rank_wide`)** - one `Choice` plus three `Noul`s:

```python
"which": Choice(
    instructions=("Which of these skills, if any, is the right one to load to help with "
                  "the user's latest request?"),
    criteria={skill["name"]: skill["description"] for skill in ROSTER},  # 182 options
)
```

The three gate nouls (verbatim instructions, trimmed), keyed `gate::<name>`:

- `acts_on_user_system` - "Is the assistant being asked to act on the user's files,
  accounts, devices, or online services, rather than only to explain or advise?"
- `would_follow_documented_procedure` - "Would a careful expert answering this consult a
  specific documented procedure or set of commands, rather than answering from general
  understanding?"
- `prose_suffices` - "Could a knowledgeable generalist fully satisfy this request in prose,
  with no tools, no documentation, and no access to the user's files or accounts?"

`INVERTED = {"prose_suffices"}`; code flips it (`1.0 - v`) and averages the three. The
Choice probabilities are sorted descending and the top 12 kept.

**Request 2 (`rerank`)** - a `Choice` over the shortlist whose criteria are
`description_full` plus `body[:700]`, with instructions "Exactly one of these skills is the
right one to load for the user's latest request. Which one? Read what each actually does,
not just its name."; plus one `Noul` per candidate, keyed `fits::{name}`: "Does the skill
'{name}' do the specific thing the user's request asks for? It is described as:
{description_full}".

Thresholds and combination, all in code:

```python
SHORTLIST = 3           # candidates carried into the second request
EXCERPT_CHARS = 700     # SKILL.md characters per candidate (roster file stores 1600)
GATE_THRESHOLD = 0.30   # mean of the three request nouls, below which nothing is suggested
FITS_THRESHOLD = 0.30   # a shortlist whose best "does this fit" noul is under this is dropped

def suggest(request):
    wide = rank_wide(request)
    if wide["gate"] < GATE_THRESHOLD:
        return ()
    shortlist = tuple(name for name, _ in wide["ranked"][:SHORTLIST])
    result = rerank(request, shortlist, EXCERPT_CHARS)
    if max(result["fits"].values()) < FITS_THRESHOLD:
        return ()
    return (result["winner"],)
```

The abstain path is explicit at both stages: `()` means nothing is suggested, and the prompt
block then says "No skill in the roster appears relevant to this request." The suggestion is
deliberately soft: "Relevant to the current request: {names}. Ignore this if it does not fit
what the user actually asked for." - "because pushing harder wins compliance on wrong
suggestions too, and a wrong one is worse than none."

## Numbers reported (verbatim, with what they compare against and the run date if given)

Roster: `182 skills in 33 categories`, `roster prompt: 16,089 characters`, `index
description: 54 characters on average, 60 at most`. Hermes "cuts it to 60 characters by
default". Requests: `488 requests: 315 covered by a skill (171 distinct skills), 173 covered
by none`.

Main result, 488 requests against `claude-haiku-4-5-20251001`, both columns error rates
(lower is better):

| run | wrong loads | needless loads |
|---|---|---|
| agent alone, with just its roster (baseline) | 16.8% | 9.8% |
| agent with a TypeSafe suggestion | 7.3% | 4.0% |
| agent handed the right answer (oracle) | 2.5% | 1.2% |

`baseline -> TypeSafe:  2.3x fewer wrong loads, 2.4x fewer needless ones`.

Baseline error analysis: `of 36 wrong first picks, 10 came from the right skill's own
category`. Churn: `of 315 covered requests: 37 the suggestion fixed, 7 it broke`.

Per-request latency, printed for the three demo requests (`seconds` measured with
`perf_counter` around each `system_one` call):

| demo request | request 1 (182-way rank) | request 2 (rerank 3) |
|---|---|---|
| Apple Notes recipe | 0.31s | 0.12s |
| pitch deck `.pptx` | 0.16s | 0.09s |
| post to Mastodon | 0.16s | 0.09s |

Demo gate scores: 0.75, 0.76, 0.78 (all "-> suggest"). Demo Choice probabilities include
`0.990 apple-notes`, `0.700 powerpoint` / `0.300 pptx-author`, `0.550 xurl`. Demo `fits`
nouls: `0.60 apple-notes` / `0.54 computer-use` / `0.01 concept-diagrams`; `0.73 powerpoint`
/ `0.38 pptx-author` / `0.02 chroma`; `0.56 xurl` / `0.38 computer-use` / `0.05 openhands`.

Cost: not reported. Token counts: collected in code (`input_tokens`, `output_tokens`) but no
totals or dollar figures are printed. Number of repeats / `NUM_SAMPLES`: not reported - one
measured turn per request per arm. Standard deviations: not reported.

## Caveats the cookbook itself states

- The floor is not zero: "an agent given the right skill still does not always load it, and
  no selection method, however good, gets past that" - the oracle arm still shows 2.5% and
  1.2%.
- The labelled requests are easy: they "were written by Claude Sonnet 5 from each skill's own
  `SKILL.md`, so the labels are trustworthy and the requests are easier than the ones users
  send."
- The suggestion breaks things it did not need to: "Some requests the agent had right on its
  own come back wrong once a suggestion is attached... A confident wrong suggestion is more
  persuasive than no suggestion at all, which is the price of putting one in front of the
  turn." (37 fixed, 7 broken.)
- Stage two is bounded by stage one: "The second pass can only reject what the wide ranking
  hands it".
- A missing capability cannot be ranked around: for the Mastodon request, "Nothing a ranking
  can do will save the Mastodon one... with a skill for posting to X and nothing for Mastodon
  the closest skill wins anyway." Its best `fits` noul lands above 0.30 and the wrong skill
  is suggested.
- The oracle arm "is not achievable; it is the ceiling the other two get measured against."
- Roster size limit: "One `Choice` question holds a roster this size comfortably. A few times
  larger and you would split it into chunks and rank each one, then run this same shortlist
  step over the winners."
- The suggestion wording is a measured input: "Editing a word here silently invalidates the
  shipped results and costs a live re-run to restore them."

## Lessons transferable to other use cases

- Two-stage rank-then-judge: a cheap wide ranking over everything, then a close read of two
  or three with fuller evidence. "Either step may come back empty-handed."
- Separate "which" from "whether": the Choice settles which candidate, the nouls settle
  whether to say anything. The cookbook shows them disagreeing on the deck request and
  explains why that is correct - "They are deciding different things."
- Choice probabilities are relative and sum to 1, so a top pick always exists; an
  independent noul gate is what lets the system stay silent.
- Gate on request properties, not subject matter: the three gate nouls ask whether an action
  is wanted, because "A question about subject matter will not separate *explain what a monad
  is* from a request that needs a skill, since both are software."
- Progressive disclosure over truncation: leave the index alone and spend the extra tokens
  only on the shortlist (700 body characters each), so prefix caching over the roster holds.
- Advisory, not authoritative: the injected line is one sentence, explicitly ignorable, and
  the downstream agent keeps its own judgement.
- What does not generalise: the 16.8% -> 7.3% figures are for this roster, these synthetic
  requests and this agent model. Thresholds (0.30 / 0.30), shortlist size (3) and excerpt
  length (700) are tuning knobs, not defaults.

## Use-case entries this supports

- `uc-agents-harness-skill-or-tool-selection` - suggest at most one skill for an agent turn from a large roster
- `uc-agents-harness-skill-description-collision-detection` - find colliding descriptions in the roster the ranker has to choose between
- `uc-support-intent-routing-handlers` - route a request to one of many handlers, with a no-route option
- `uc-search-retrieval-rerank-keyword-shortlist` - rank wide on short text, rerank few on full text

**Anti-use-case implied:** `au-open-ended-agent-loop` - the suggestion must stay advisory.
A confident wrong suggestion is "more persuasive than no suggestion at all"; it broke 7
requests the agent had right, so jev should not be the only thing deciding what the agent
loads.
