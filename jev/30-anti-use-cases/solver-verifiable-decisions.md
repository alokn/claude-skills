---
id: au-solver-verifiable-decisions
title: Do not use jev where a solver or exact algorithm already defines the right answer
verdict: no
domain: games
decision_shapes: [classification, routing, scoring]
primitives: [choice, score]
evidence_level: independent-benchmark
sources:
  - https://backnotprop.com/blog/jev-poker/  (30 solver-verified hold'em spots; 63% agreement; 62% all-in on the nuts)
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (failure modes 2 and 4, math and indirection)
  - https://docs.typesafe.ai/concepts/system-one.md  (System One is fast judgement, not deliberation)
related: [au-numeric-thresholds-and-arithmetic, au-multi-hop-and-double-negatives, au-open-ended-agent-loop, uc-realtime-game-decision-from-structured-state]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to pick the game-theory-optimal action in this poker spot?" Also "let jev
choose the opening move", "replace our optimiser with a jev call", "jev for route selection / bin packing
/ scheduling", "can jev approximate the solver cheaply?".

## Verdict

**No** where a solver exists and can run in your latency budget. backnotprop measured it against ground
truth: over 30 solved Texas hold'em spots jev "matched solver top action 63%", and on one nut hand it
chose all-in in 62% of runs (16/16 runs showing the pattern) where TexasSolver, at 0.59% exploitability,
checks 100% of the time. A 63% match to a known-correct answer is not a cheap approximation of the
solver; it is a different, worse policy that happens to be fast.

## What jev would get wrong

Solver domains are exactly the shape the jaggedness page warns about: the right answer comes from search
and arithmetic over a game tree or a constraint set, not from reading a situation. Failure mode 2 says
"Jev is not a calculator. We strongly recommend implementing any mathematical logic in code", and mode 4
says multi-hop reasoning "costs accuracy". Worse, the errors are not random: the nut-hand result shows a
systematic bias toward the intuitively aggressive line, which is the kind of exploitable pattern an
adversary in a game domain will find and punish. The confidence value does not rescue it, because the
model is confidently playing a different strategy, not hedging.

## What stays in code

The solver, and the decision. Run the exact algorithm — the CFR solve, the MILP, the shortest path, the
scheduler — and let it own the action. Jev's remaining jobs in such a system are all upstream of the
maths: classify the free-text situation into the structured inputs the solver needs, decide which
abstraction or solve profile to load, detect that the observed state has drifted from the modelled one,
or triage which of a thousand positions a human should review. Those are System One tasks; the optimum is
not.

## Numbers

63% agreement with the solver's top action over 30 spots; 62% all-in frequency on a nut hand where the
solver checks 100%; TexasSolver run at 0.59% exploitability
(https://backnotprop.com/blog/jev-poker/, accessed 2026-09-19). The sample is small and the domain narrow,
but the ground truth is genuine, which is rare in this corpus. Cost is not the issue on either side: a
structured 400-token spot with four questions is roughly 600 input tokens, about $0.000025 at $0.042 per
million input tokens with output free (https://docs.typesafe.ai/models.md) — cheaper than a solve, and
wrong 37% of the time.

## When the verdict flips

It flips to **conditional** when no solver can run in the loop — the state space is unsolved, the
opponent model is unknown, or the latency budget is tens of milliseconds and the solve takes minutes — and
the alternative is a hand-written heuristic rather than an exact answer. Then benchmark jev against that
heuristic, on solver-verified positions where any exist, and keep the solver as an offline oracle for
regression tests. It also flips when jev's output is a *feature* for the solver rather than a substitute:
classifying player type or table dynamics into the model's inputs is legitimate.

## Alternatives considered

- **Regex / deterministic**: the solver itself; exact and auditable.
- **Small LLM**: worse and slower on the same task.
- **Frontier LLM**: better at explaining the theory, still not a solver; far too slow per decision.
- **Fine-tuned classifier**: a network distilled from solver outputs is the standard approach and is
  trained on the ground truth jev never sees.
- **Embeddings**: no.
- **Human**: the expert reviews strategy, not every hand.

## Sources

- https://backnotprop.com/blog/jev-poker/ — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/concepts/system-one.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
