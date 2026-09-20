---
id: uc-devices-control-physical-actuator-action-selection
title: Choose a robot's next high-level action from code-serialised state while the control loop stays in code
verdict: conditional
domain: devices-control
decision_shapes: [classification, routing]
primitives: [choice, noul, score]
evidence_level: community-report
sources:
  - https://github.com/grmkris/robo-harness  (SO-101 robot arm action selection with jev; no accuracy published)
  - https://github.com/RomanSlack/jev-drone  (quadrotor tactical decisions at 2.5 Hz with control in code; no accuracy published)
  - https://github.com/AboveColin/HA-Jev  (author's own exclusion: not for locks, heaters, alarms, or tight loops; latency "slower from Europe than the published 70 to 500 ms")
  - https://docs.typesafe.ai/model-jaggedness/jev-1.13.md  (mode 2 math and numbers; mode 5 large state)
  - https://docs.typesafe.ai/models.md  ($0.042 per million input tokens, output free; text-only input; 70-500 ms, most queries about 100 ms)
related: [uc-realtime-game-decision-from-structured-state, uc-devices-control-mobile-action-selection-accessibility-tree, uc-realtime-voice-command-intent-risk-scaled-thresholds, au-real-time-from-raw-pixels, au-numeric-thresholds-and-arithmetic]
last_verified: 2026-09-19
jev_version: jev-1.13.0
---

## The question

"Is it a good idea to use jev to control a robot?" Also: "can jev pick the next move for a robot
arm?", "can a drone use jev to decide what to do?", "is 100 ms fast enough for a control loop?".

## Verdict

**Conditional**, and the condition is a hard architectural split: jev may run only at the
*tactical* layer, at single-digit Hz, choosing among actions that code has already proved safe
to execute. The control loop, kinematics, collision and envelope checks, and the failsafe stay
entirely in code. Two public projects run this shape — an SO-101 arm harness and a quadrotor
making "tactical decisions at 2.5 Hz with control in code" — and neither publishes an accuracy
number, so the verdict rests on the architecture, not on evidence that the model chooses well.
Get the split right and a wrong-but-valid answer is a suboptimal move; get it wrong and it is a
crash.

## What jev decides

Code serialises the world into a short, typed state: object poses relative to the gripper,
gripper open/closed, which of the enumerated actions are currently legal, battery or torque
headroom, the goal, and the outcome of the last action. Code then enumerates **only** the legal,
envelope-respecting actions and jev chooses among them.

```
next_action: Choice over the code-generated legal-action list
  instructions: {question: "Which listed action best advances `goal` from `world_state`?",
                 focus: "Choose among the listed actions only; they are all safe to execute."}
  criteria: one line per enumerated action, generated from the same table code used to
            filter for legality

situation_is_unexpected: Noul
  instructions: "Does `world_state` show something the listed actions were not designed for -
                 an object that is not in the object list, a sensor reading marked stale,
                 a grasp that reported success but shows the gripper empty?"

progress: Score
  criteria: ["No closer to `goal` than the previous step.",
             "Measurably closer.",
             "`goal` is satisfied."]
```

`situation_is_unexpected` is the one that earns its place: it is the cheap way to notice that
the enumerated action set no longer describes the world, and it should trigger the same stop
path as a low-confidence answer.

Bands: execute above your fitted floor; below it, hold position and hand to the scripted policy
or the operator. Never "pick the best of a bad set" — a stop is always in the option list.

## What stays in code

Everything that can hurt someone or break something. Inverse kinematics, trajectory generation,
joint and velocity limits, collision checking, geofence and altitude envelope, torque limits,
the watchdog, and the failsafe on lost connectivity. Also: all arithmetic and all comparison of
quantities. Distances, angles, battery percentages and timings are computed and thresholded in
code and enter the state already interpreted ("object is within reach", not "0.412 m") —
failure mode 2 is not negotiable on a machine that moves.

## Numbers

**No accuracy is published by either project.** What is published is the cadence: the quadrotor
harness runs jev for "tactical decisions at 2.5 Hz", i.e. a 400 ms budget per decision, against
a documented model envelope of "70 to 500 ms", "most queries about 100 ms". That is a fit with
little headroom, and a hosted API means a network round trip sits inside it — the Home Assistant
integration author reports latency "slower from Europe than the published 70 to 500 ms". Budget
for the p95, not the median, and define what the vehicle does when the call does not return.

Cost method: `input_tokens ~= chars/4`, `cost = tokens x $0.042 / 1e6`, output free. A compact
state of ~800 characters plus an enumerated action list and criteria (~1,200 characters) is
about 500 tokens, **~$0.000021 per decision**; at 2.5 Hz that is about **$0.19 per hour** of
flight. For comparison, a game harness in the same family measured "~1.3 decisions/s, median
621 ms" and "~$0.14/hour".

Closest failure mode: **2, math and numbers** — avoided by never putting a distance, angle or
timing comparison inside a question. Runner-up **5**, avoided by serialising a filtered world
state rather than a sensor dump.

## When the verdict flips

- **Jev is inside the stabilising loop.** Anything above roughly 10 Hz, or anything where a
  missed response is unsafe, is a `no`. Control is a solved deterministic problem.
- **The action list is not pre-filtered for safety.** If jev can name an unsafe action, the
  architecture is wrong, not the model.
- **Input is pixels or point clouds.** Jev is text-only; perception belongs to a perception
  model that emits the typed state.
- **The environment has people in it and no independent guard.** A probabilistic chooser must
  never be the only thing between an actuator and a person.
- **Connectivity is unreliable and the failsafe is undefined.** Then the network call itself is
  the hazard.

## Alternatives considered

- **Scripted state machine / behaviour tree.** The incumbent, deterministic, auditable, and
  correct for every situation it anticipated. Jev is for the unanticipated tactical branch, and
  the state machine stays as the fallback.
- **Learned policy (RL, imitation learning).** Better at continuous control and trained on the
  real dynamics; needs data and a simulator. Jev needs neither, which is its only real edge here.
- **Frontier LLM planner.** Fine at 0.1 Hz for task-level planning above jev; far too slow at
  2.5 Hz.
- **Classical planner / solver.** Where the problem is search or optimisation, use the solver —
  a public probe found jev matched a game-theory solver's top action only 63% of the time on 30
  solved spots, which is the general warning against asking it to optimise.
- **Human teleoperation.** The low-confidence path, and the right answer for anything novel.

## Sources

- https://github.com/grmkris/robo-harness — accessed 2026-09-19
- https://github.com/RomanSlack/jev-drone — accessed 2026-09-19
- https://github.com/AboveColin/HA-Jev — accessed 2026-09-19
- https://docs.typesafe.ai/model-jaggedness/jev-1.13.md — accessed 2026-09-19
- https://docs.typesafe.ai/models.md — accessed 2026-09-19
