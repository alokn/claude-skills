---
id: uc-realtime-game-decision-from-structured-state
title: Choose the next action in a game or simulation from code-serialised state
verdict: conditional
domain: realtime
decision_shapes: [classification, routing, scoring]
primitives: [choice, score, noul]
evidence_level: official-docs
sources:
  - https://typesafe.ai/blog/introducing-system-one-models-and-jev  (Doom demo at 10 queries a second, "which ends up costing ~$7/hour"; "The demo is on structured state as a data structure with text, not on images (yet…)"; "A non-AI doom bot could play better"; Wikiracing: "Each step can mean choosing between hundreds to thousands of links!", two-stage score-then-choose above the 255 cap)
  - https://docs.typesafe.ai/concepts/use-case-map.md  (Real-time applications: "Frontier intelligence at real-time speeds (150ms) means AI can make decisions faster than human perception. Fast and smart enough to be programmed to play games or embedded into a UI.")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (numeric representations; counting; "Math using score"; large state)
  - https://docs.typesafe.ai/models.md  (text only; 255-option cap context; 1,200 requests per minute; $0.042 per Mtok, output free)
  - https://docs.typesafe.ai/patterns/fan-out.md  (many questions per call; latency "barely changes" as questions are added)
related: [uc-realtime-ui-component-selection, uc-realtime-voice-command-intent-risk-scaled-thresholds, df-fit-test, df-cost-model, cb-skill_suggestion, cb-function_calling]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to drive a game bot or a simulation agent?" Also asked as
"can jev pick the next move each tick?" and "can we run a model inside a 10 Hz loop?".

## Verdict

**Conditional.** TypeSafe's launch post runs a Doom bot on jev at ten queries a second, so
the latency and the price work. The condition is structural: **code must enumerate the legal
actions and jev must only pick among them.** The post is explicit that the demo "is on
structured state as a data structure with text, not on images (yet…)", and equally explicit
about the ceiling — "A non-AI doom bot could play better, but we wanted a bot that was
reactive to different representations of game state". Use jev for a bot that reads a
situation and follows instructions, not one that wins. Closest jaggedness failure mode: #2,
math and numeric representations — raw coordinates and health deltas are what jev reads
worst, so the serialiser must bucket them into words before they reach the state.

## What jev decides

State is whatever your serialiser writes. Positions become bearings and distance bands;
numbers become words:

```
{"self": {"health": "wounded", "ammo": "low", "cover": "none"},
 "threats": [{"id": "t1", "bearing": "ahead-left", "distance": "close", "facing_me": true}],
 "items":   [{"id": "medkit_2", "bearing": "behind", "distance": "medium"}],
 "legal_actions": ["advance_t1", "retreat_to_corridor", "grab_medkit_2", "reload", "hold"]}
```

```
action: Choice
  instructions: {question: "Which action in `legal_actions` best serves the standing order?",
                 focus: "Prefer survival while the bot is wounded and low on ammo."}
  criteria:
    advance_t1:          {what: "Close on the threat and fight now",
                          not_for: "When health is 'wounded' and ammo is 'low' at once"}
    retreat_to_corridor: {what: "Break line of sight and reposition",
                          not_for: "When no threat can reach the bot"}
    grab_medkit_2:       {what: "Move to a reachable healing item",
                          not_for: "When a threat is 'close' and 'facing_me'"}
    reload:              {what: "Spend a turn restoring ammo in relative safety"}
    hold:                {what: "Do nothing this tick"}

urgency: Score
  instructions: "How urgent is the bot's situation this tick?"
  criteria: ["Safe: no threat can reach the bot.",
             "Pressed: a threat is engaging but the bot can absorb it.",
             "Critical: the next hit likely ends the run."]
```

Option keys are strings code generated this tick, so the answer is always an executable
action. Bands: `confidence >= 0.7` execute; `0.45–0.7` execute the conservative default
(`hold` or `retreat`) and log; `< 0.45` fall back to the scripted behaviour tree. The Score
rides along for free — fan-out adds tokens, not latency.

## What stays in code

Legality, always — the engine enumerates `legal_actions`, so an illegal move is
unrepresentable. Also physics, pathfinding, line-of-sight, hit resolution, cooldowns, damage
arithmetic, the tick clock, the score, and the bucketing of every raw number into a word.
Anything with a solvable search space stays an algorithm. Jev never mutates game state.

## Numbers

Method: `input_tokens ≈ chars(state + questions) / 4`; `cost = tokens × $0.042 / 1e6`,
output free. The sketch is ~900 characters of state and ~1,200 of questions, so ≈ 525
tokens ≈ **$0.000022 per tick**. At an assumed 10 ticks per second — an assumption about
your loop, not a measured volume — that is 36,000 calls per hour ≈ $0.79/hour. The launch
post's own Doom figure is higher, 10 queries a second "which ends up costing ~$7/hour",
which back-solves to roughly 4,600 input tokens per call: a much larger state than this
sketch. Treat theirs as the ceiling and yours as the floor. Latency: 70–500 ms, "most
queries about 100 ms"; the consistency cookbooks measured 111 ms (14 Nouls) and 114 ms (8
Choices) mean round trips on 2026-09-11, a ~9 Hz ceiling before your own network hop. Rate
limits bite before cost does: 1,200 requests per minute is 20 per second, so two 10 Hz bots
saturate a default account. No accuracy figure exists for game play.

- Field evidence (community-report): three game harnesses generate the legal moves in code and let jev pick among them - Mario, StarCraft and Pokemon Red. The Pokemon Red run reports "~1.3 decisions/sec, median 621 ms (mean 759, n=6, range 479-1470), ~$0.14/hour" at ~725 input tokens per call, and its author deliberately withheld calibration numbers because rate limiting cut the study to "n=5 turns with wide confidence intervals", 2026-09. Source: https://github.com/valentynkit/jev-plays-pokemon-red

## When the verdict flips

- **The game is solvable.** Minimax, MCTS or A* beat a judgement model on quality and
  latency both. Flips to weak.
- **The loop needs more than ~10 Hz**, or the p99 tail matters. A 500 ms outlier at 10 Hz is
  five dropped ticks; without a scripted fallback, no.
- **State is pixels or audio** with no text serialisation. Text only: no.
- **You ask jev to compute** distances or damage rather than read buckets — modes #2 and #3.
- **Legal actions exceed 255**, as in Wikiracing where "each step can mean choosing between
  hundreds to thousands of links". The post's fix is a two-stage Score-then-Choice, adding a
  round trip and "the occassional slowdown"; re-time the loop first.

## Alternatives considered

- **Behaviour tree / state machine.** Faster, free, better where the situation is
  enumerable — keep it as the fallback and the baseline you must beat.
- **Search algorithm (minimax, MCTS, A*).** Wins outright on any tractable search space.
- **Small LLM.** Sub-second is rare and a parse failure is a dropped tick; Haiku ran
  992–3,860 ms per rubric call in the consistency cookbooks.
- **Frontier LLM.** Seconds per call. Fine turn-based, impossible in a loop.
- **Fine-tuned policy / RL agent.** Right if you can simulate millions of episodes and the
  rules are frozen; jev is right when the instruction changes weekly.
- **Embeddings.** No decision boundary here; not applicable.
- **Human.** The player, not a substitute for the bot.

## Sources

Accessed 2026-09-19. `typesafe.ai/blog/introducing-system-one-models-and-jev` (Doom at 10
q/s ≈ $7/hour; text state not images; "A non-AI doom bot could play better"; Wikiracing
cardinality), `concepts/use-case-map.md`, `model-jaggedness/jev-1.13.md`, `models.md`,
`patterns/fan-out.md`, `cookbooks/consistency_noul_cookbook.md` and
`cookbooks/consistency_choice_cookbook.md` (111 ms and 114 ms, sampled 2026-09-11).
